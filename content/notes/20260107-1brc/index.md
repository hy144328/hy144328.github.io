+++
date = '2026-01-07T01:28:00+01:00'
draft = true
title = 'One-billion row challenge in Go'
+++

Whenever I run a large calculation in [Apache Spark](https://spark.apache.org/), I wonder if it really has to take so long.
I am familiar with [back-of-the-envelope estimation](https://abseil.io/fast/hints.html#estimation).
However, nothing beats real-life measurements.
Most recently, I remembered this when I popped an article from my [Instapaper](https://instapaper.com/u) backlog:
Two years ago, [Gunnar Morling](https://www.morling.dev/) called out the [one-billion row challenge](https://www.morling.dev/blog/one-billion-row-challenge/).
The winners have already been determined with the [fastest submissions](https://github.com/hy144328/1brc#results) finishing in under two seconds.
I would not have been a contender, in Java or any other programming language, so I am not feeling competitive one way or another.
Nevertheless, I want to give it a try!

Rules

Evaluation

https://www.youtube.com/watch?app=desktop&v=n-YK3B4_xPA

## Baseline implementation

`main.go`:

```go
package main

import (
	"bufio"
	"io"
	"strconv"
	"strings"
)

const maxCities = 10000

func run0(r io.Reader) map[string]*Statistics[float64] {
	scanner := bufio.NewScanner(r)

	counts := make(map[string]int, maxCities)
	maxs := make(map[string]float64, maxCities)
	mins := make(map[string]float64, maxCities)
	sums := make(map[string]float64, maxCities)

	for scanner.Scan() {
		lineIt := scanner.Text()
		words := strings.Split(lineIt, ";")

		city := words[0]
		temperature, err := strconv.ParseFloat(words[1], 64)
		if err != nil {
			panic(err)
		}

		counts[city] += 1
		sums[city] += temperature

		if counts[city] == 1 {
			maxs[city] = temperature
			mins[city] = temperature
		} else {
			maxs[city] = max(maxs[city], temperature)
			mins[city] = min(mins[city], temperature)
		}
	}

	res := make(map[string]*Statistics[float64], len(counts))

	for cityIt, countIt := range counts {
		res[cityIt] = &Statistics[float64]{
			Cnt: countIt,
			Max: maxs[cityIt],
			Min: mins[cityIt],
			Sum: sums[cityIt],
		}
	}

	return res
}
```

`types.go`:

```go
package main

type Statistics[T any] struct {
	Cnt int
	Max T
	Min T
	Sum T
}
```

The implementation is straightforward:

1.  Iterate over lines. (`bufio.Scanner`)
2.  Parse city name and temperature. (`strings.Split()`, `strconvParseFloat()`)
3.  Compare and set values. (`counts`, `maxs`, `mins`, `sums`)

Intuitively, I decided to provide a separate data structure for each metric, i.e. `counts`, `maxs`, `mins`, `sums`.
This is what I am used to from my day job as a data engineer working with column-oriented technologies such as Pandas, ClickHouse and Apache Parquet.
How bad will this be?

```
File: one-billion-row-challenge-golang.test
Build ID: d5df05dd99e5d2dcd493355c59cdbeec02a734c2
Type: cpu
Time: 2026-01-14 14:32:22 CET
Duration: 256.32s, Total samples = 265.86s (103.72%)
Showing nodes accounting for 247.03s, 92.92% of 265.86s total
Dropped 331 nodes (cum <= 1.33s)
      flat  flat%   sum%        cum   cum%
    30.40s 11.43% 11.43%     79.23s 29.80%  runtime.mapassign_faststr
    26.29s  9.89% 21.32%     26.29s  9.89%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
    17.40s  6.54% 27.87%     17.44s  6.56%  strconv.readFloat
    17.23s  6.48% 34.35%     51.38s 19.33%  runtime.mapaccess1_faststr
    13.94s  5.24% 39.59%     13.94s  5.24%  aeshashbody
    11.99s  4.51% 44.10%     11.99s  4.51%  memeqbody
     8.60s  3.23% 47.34%      8.60s  3.23%  runtime.nextFreeFast (inline)
     8.37s  3.15% 50.49%     48.72s 18.33%  strings.genSplit
     7.43s  2.79% 53.28%      7.43s  2.79%  strconv.atof64exact
     7.29s  2.74% 56.02%    256.32s 96.41%  github.com/hy144328/one-billion-row-challenge-golang.run0
```

The program takes 256.32 seconds.
It spends almost 30% on assigning to hash maps, and almost 20% on accessing from hash maps.
Let us do something about this.

## Optimization #1: Row-oriented data.

`main.go`:

```go
func run1(r io.Reader) map[string]*Statistics[float64] {
	res := make(map[string]*Statistics[float64], maxCities)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		lineIt := scanner.Text()
		words := strings.Split(lineIt, ";")

		city := words[0]
		temperature, err := strconv.ParseFloat(words[1], 64)
		if err != nil {
			panic(err)
		}

		resIt, ok := res[city]
		if !ok {
			res[city] = &Statistics[float64]{
				Cnt: 1,
				Max: temperature,
				Min: temperature,
				Sum: temperature,
			}
		} else {
			resIt.Cnt += 1
			resIt.Max = max(resIt.Max, temperature)
			resIt.Min = min(resIt.Min, temperature)
			resIt.Sum += temperature
		}
	}

	return res
}
```

There is a single data structure, `res`, to store all metrics.
Note that I am using pointers with `Statistics` in order to reduce allocation overhead on access and assignment.

```
File: one-billion-row-challenge-golang.test
Build ID: d5df05dd99e5d2dcd493355c59cdbeec02a734c2
Type: cpu
Time: 2026-01-14 14:36:39 CET
Duration: 189.98s, Total samples = 202.43s (106.56%)
Showing nodes accounting for 181.07s, 89.45% of 202.43s total
Dropped 332 nodes (cum <= 1.01s)
      flat  flat%   sum%        cum   cum%
    21.19s 10.47% 10.47%     21.32s 10.53%  strconv.readFloat
    10.58s  5.23% 15.69%     10.58s  5.23%  runtime.nextFreeFast (inline)
     9.84s  4.86% 20.56%     60.86s 30.06%  strings.genSplit
     9.48s  4.68% 25.24%      9.48s  4.68%  strconv.atof64exact
     9.32s  4.60% 29.84%     35.95s 17.76%  runtime.mapaccess2_faststr
     8.88s  4.39% 34.23%      8.88s  4.39%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     8.44s  4.17% 38.40%    191.57s 94.64%  github.com/hy144328/one-billion-row-challenge-golang.run1
     7.54s  3.72% 42.12%     29.82s 14.73%  runtime.mallocgcSmallScanNoHeader
     6.99s  3.45% 45.58%      6.99s  3.45%  indexbytebody
     6.73s  3.32% 48.90%      6.73s  3.32%  internal/runtime/syscall.Syscall6
```

The program takes 189.98 seconds, which is a 26% improvement!
Accessing from hash maps takes 35.95 seconds, which is a 30% improvement.
Assignment to hash maps does not even show up anymore in the top ten.

## Optimization #2: Floating-point arithmetics.

`main.go`:

```go
func run2(r io.Reader) map[string]*Statistics[int] {
	res := make(map[string]*Statistics[int], maxCities)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		lineIt := scanner.Text()
		words := strings.Split(lineIt, ";")

		city := words[0]
		word1 := words[1]
		word1len := len(word1)

		sgn := 1
		if word1[0] == '-' {
			sgn = -1
		}

		temperature10, err := strconv.Atoi(word1[:word1len-2])
		if err != nil {
			panic(err)
		}

		temperature1 := word1[word1len-1] - '0'
		temperature := 10*temperature10 + sgn*int(temperature1)

		resIt, ok := res[city]
		if !ok {
			res[city] = &Statistics[int]{
				Cnt: 1,
				Max: temperature,
				Min: temperature,
				Sum: temperature,
			}
		} else {
			resIt.Cnt += 1
			resIt.Max = max(resIt.Max, temperature)
			resIt.Min = min(resIt.Min, temperature)
			resIt.Sum += temperature
		}
	}

	return res
}
```

I replace `strconv.ParseFloat()` with three instructions:

1.  Check sign. (`-`)
2.  Read digits before decimal point. (`strconv.Atoi()`)
3.  Read digit after decimal point. (`0`)

```
File: one-billion-row-challenge-golang.test
Build ID: d5df05dd99e5d2dcd493355c59cdbeec02a734c2
Type: cpu
Time: 2026-01-14 14:39:50 CET
Duration: 167.06s, Total samples = 180.29s (107.92%)
Showing nodes accounting for 161.53s, 89.59% of 180.29s total
Dropped 341 nodes (cum <= 0.90s)
      flat  flat%   sum%        cum   cum%
    11.58s  6.42%  6.42%     42.05s 23.32%  runtime.mapaccess2_faststr
    10.66s  5.91% 12.34%     63.09s 34.99%  strings.genSplit
    10.50s  5.82% 18.16%     10.50s  5.82%  runtime.nextFreeFast (inline)
    10.30s  5.71% 23.87%    168.81s 93.63%  github.com/hy144328/one-billion-row-challenge-golang.run2
     9.70s  5.38% 29.25%      9.70s  5.38%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     8.46s  4.69% 33.95%      8.46s  4.69%  aeshashbody
     7.59s  4.21% 38.16%     53.09s 29.45%  runtime.mallocgc
     7.57s  4.20% 42.35%     29.02s 16.10%  runtime.mallocgcSmallScanNoHeader
     6.85s  3.80% 46.15%      6.85s  3.80%  indexbytebody
     6.81s  3.78% 49.93%      6.81s  3.78%  internal/runtime/syscall.Syscall6
```

The program takes 167.06 seconds, which is a 12% improvement.
This was easy enough.

## Optimization #3: Substrings.

`main.go`:

```go
func run3(r io.Reader) map[string]*Statistics[int] {
	res := make(map[string]*Statistics[int], maxCities)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		lineIt := scanner.Text()
		sepIdx := strings.IndexByte(lineIt, ';')

		sgn := 1
		if lineIt[sepIdx+1] == '-' {
			sgn = -1
		}

		temperature10, err := strconv.Atoi(lineIt[sepIdx+1 : len(lineIt)-2])
		if err != nil {
			panic(err)
		}

		temperature1 := lineIt[len(lineIt)-1] - '0'
		temperature := 10*temperature10 + sgn*int(temperature1)

		resIt, ok := res[lineIt[:sepIdx]]
		if !ok {
			res[lineIt[:sepIdx]] = &Statistics[int]{
				Cnt: 1,
				Max: temperature,
				Min: temperature,
				Sum: temperature,
			}
		} else {
			resIt.Cnt += 1
			resIt.Max = max(resIt.Max, temperature)
			resIt.Min = min(resIt.Min, temperature)
			resIt.Sum += temperature
		}
	}

	return res
}
```

I replace `strings.Split()` with `strings.IndexByte()` to identify the location of the semicolon, `sepIdx`.
Instead of generating a slice of strings, I extract substrings based on `sepIdx`.
Note that I pass a substring directly to the respective function call to give the the compiler the opportunity to optimize the conversions between strings and byte slices under the hood.

```
File: one-billion-row-challenge-golang.test
Build ID: d5df05dd99e5d2dcd493355c59cdbeec02a734c2
Type: cpu
Time: 2026-01-14 14:42:37 CET
Duration: 88.28s, Total samples = 89.65s (101.55%)
Showing nodes accounting for 82.65s, 92.19% of 89.65s total
Dropped 237 nodes (cum <= 0.45s)
      flat  flat%   sum%        cum   cum%
     8.36s  9.33%  9.33%     29.62s 33.04%  runtime.mapaccess2_faststr
     8.01s  8.93% 18.26%      8.01s  8.93%  indexbytebody
     7.59s  8.47% 26.73%     86.57s 96.56%  github.com/hy144328/one-billion-row-challenge-golang.run3
     7.27s  8.11% 34.84%      7.27s  8.11%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     6.11s  6.82% 41.65%      6.11s  6.82%  internal/runtime/syscall.Syscall6
     5.01s  5.59% 47.24%     18.31s 20.42%  bufio.(*Scanner).Scan
     4.86s  5.42% 52.66%      4.86s  5.42%  strconv.Atoi
     4.41s  4.92% 57.58%      4.41s  4.92%  aeshashbody
     4.20s  4.68% 62.26%      8.52s  9.50%  runtime.mallocgcTiny
     3.41s  3.80% 66.07%      3.41s  3.80%  memeqbody
     3.03s  3.38% 69.45%      3.03s  3.38%  runtime.nextFreeFast (inline)
     2.84s  3.17% 72.62%     18.43s 20.56%  runtime.slicebytetostring
     2.62s  2.92% 75.54%     13.72s 15.30%  runtime.mallocgc
     1.99s  2.22% 77.76%      6.01s  6.70%  bufio.ScanLines
     1.90s  2.12% 79.88%      1.90s  2.12%  runtime.memmove
     1.58s  1.76% 81.64%      1.58s  1.76%  internal/runtime/maps.(*groupReference).key (inline)
     1.19s  1.33% 82.97%      1.19s  1.33%  internal/runtime/maps.(*Map).directoryAt (inline)
     0.89s  0.99% 83.96%      2.33s  2.60%  runtime.mallocgcSmallNoscan
     0.79s  0.88% 84.84%     19.22s 21.44%  bufio.(*Scanner).Text (inline)
     0.68s  0.76% 85.60%      0.68s  0.76%  internal/bytealg.IndexByteString
```

The program takes 88.28 seconds, which is a 47% improvement!
This is the largest relative improvement so far.
By the way, I am now showing the top twenty instead of the top ten because the distributions are becoming flatter.

## Optimization #4: Byte slices.

`main.go`:

```go
func run4(r io.Reader) map[string]*Statistics[int] {
	res := make(map[string]*Statistics[int], maxCities)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		lineIt := scanner.Bytes()
		sepIdx := bytes.IndexByte(lineIt, ';')

		sgn := 1
		if lineIt[sepIdx+1] == '-' {
			sgn = -1
		}

		temperature10, err := strconv.Atoi(string(lineIt[sepIdx+1 : len(lineIt)-2]))
		if err != nil {
			panic(err)
		}

		temperature1 := lineIt[len(lineIt)-1] - '0'
		temperature := 10*temperature10 + sgn*int(temperature1)

		resIt, ok := res[string(lineIt[:sepIdx])]
		if !ok {
			res[string(lineIt[:sepIdx])] = &Statistics[int]{
				Cnt: 1,
				Max: temperature,
				Min: temperature,
				Sum: temperature,
			}
		} else {
			resIt.Cnt += 1
			resIt.Max = max(resIt.Max, temperature)
			resIt.Min = min(resIt.Min, temperature)
			resIt.Sum += temperature
		}
	}

	return res
}
```

I replace `scanner.Text()` with `scanner.Bytes()`, and `strings.IndexByte()` with `bytes.IndexByte()`.
The hash map is still working with string keys.
Again, I pass byte slices directly to functions to give the compiler opportunities for optimizations under the hood.

```
File: one-billion-row-challenge-golang.test
Build ID: d5df05dd99e5d2dcd493355c59cdbeec02a734c2
Type: cpu
Time: 2026-01-14 14:44:06 CET
Duration: 54.42s, Total samples = 51.99s (95.54%)
Showing nodes accounting for 51.01s, 98.12% of 51.99s total
Dropped 33 nodes (cum <= 0.26s)
      flat  flat%   sum%        cum   cum%
     6.18s 11.89% 11.89%     51.96s 99.94%  github.com/hy144328/one-billion-row-challenge-golang.run4
     5.56s 10.69% 22.58%     21.40s 41.16%  runtime.mapaccess2_faststr
     5.10s  9.81% 32.39%      5.10s  9.81%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     4.68s  9.00% 41.39%      4.68s  9.00%  internal/runtime/syscall.Syscall6
     4.25s  8.17% 49.57%     14.90s 28.66%  bufio.(*Scanner).Scan
     3.70s  7.12% 56.68%      3.70s  7.12%  aeshashbody
     3.67s  7.06% 63.74%      3.67s  7.06%  indexbytebody
     3.37s  6.48% 70.23%      3.37s  6.48%  strconv.Atoi
     2.11s  4.06% 74.28%      2.11s  4.06%  memeqbody
     1.79s  3.44% 77.73%      2.60s  5.00%  runtime.slicebytetostring
     1.72s  3.31% 81.03%      5.19s  9.98%  bufio.ScanLines
     1.45s  2.79% 83.82%      1.45s  2.79%  internal/runtime/maps.(*groupReference).key (inline)
     1.41s  2.71% 86.54%      5.96s 11.46%  bytes.IndexByte (inline)
     0.88s  1.69% 88.23%      0.88s  1.69%  internal/bytealg.IndexByte
     0.83s  1.60% 89.82%      0.83s  1.60%  internal/runtime/maps.(*Map).directoryAt (inline)
     0.83s  1.60% 91.42%      0.83s  1.60%  runtime.memmove
     0.69s  1.33% 92.75%      0.69s  1.33%  bufio.(*Scanner).Bytes (inline)
     0.51s  0.98% 93.73%      0.51s  0.98%  runtime.strhash
     0.44s  0.85% 94.58%      0.44s  0.85%  internal/runtime/maps.h1 (inline)
     0.42s  0.81% 95.38%      0.42s  0.81%  internal/runtime/maps.(*Map).directoryIndex (inline)
```

The program takes 54.42 seconds, which is a 38% improvement.

## Conclusion

Idiomatic Go.
Python
