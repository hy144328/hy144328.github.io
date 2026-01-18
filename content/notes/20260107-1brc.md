+++
date = '2026-01-07T01:28:00+01:00'
title = 'One-billion row challenge in Go, part I: Sequential execution.'
+++

Whenever I run a large calculation in [Apache Spark](https://spark.apache.org/), I wonder if it really has to take so long.
I am familiar with [back-of-the-envelope estimation](https://abseil.io/fast/hints.html#estimation).
However, nothing beats real-life measurements.
Most recently, I remembered this when I popped an article from my [Instapaper](https://instapaper.com/u) backlog:
Two years ago, [Gunnar Morling](https://www.morling.dev/) called out the [one-billion row challenge](https://www.morling.dev/blog/one-billion-row-challenge/).
The winners have already been determined with the [fastest submissions](https://github.com/hy144328/1brc#results) finishing in under two seconds.
I would not have been a contender, in Java or any other programming language, so I am not feeling competitive one way or another.
Nevertheless, I want to give it a try!

## Baseline implementation

For the baseline implementation, I am attempting to write idiomatic Go without any premature optimization.
I use high-level functions from the standard library wherever possible.
If you ask me, the Go code ends up looking somewhat like Python code.

`main.go`:

```go
package main

import (
	"bufio"
    "bytes"
	"io"
	"strconv"
	"strings"
)

const maxCities = 10000
const noRegisters = 1048576

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
2.  Parse city name and temperature. (`strings.Split()`, `strconv.ParseFloat()`)
3.  Compare and set values. (`counts`, `maxs`, `mins`, `sums`)

Intuitively, I decided to provide a separate data structure for each metric, i.e. `counts`, `maxs`, `mins`, `sums`.
This is what I am used to from my day job as a data engineer working with column-oriented technologies such as Pandas, ClickHouse and Apache Parquet.
How bad will this be?

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:20:22 CET
Duration: 143.67s, Total samples = 154.48s (107.52%)
Showing nodes accounting for 145s, 93.86% of 154.48s total
Dropped 298 nodes (cum <= 0.77s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%    144.31s 93.42%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun0
     2.67s  1.73%  1.73%    144.31s 93.42%  github.com/hy144328/one-billion-row-challenge-golang.run0
         0     0%  1.73%    144.31s 93.42%  testing.(*B).run1.func1
         0     0%  1.73%    144.31s 93.42%  testing.(*B).runN
    18.34s 11.87% 13.60%     45.30s 29.32%  runtime.mapassign_faststr
    12.61s  8.16% 21.76%     31.56s 20.43%  runtime.mapaccess1_faststr
     0.08s 0.052% 21.82%     30.35s 19.65%  strings.Split (inline)
     3.91s  2.53% 24.35%     30.27s 19.59%  strings.genSplit
     2.03s  1.31% 25.66%     21.95s 14.21%  runtime.mallocgc
     0.50s  0.32% 25.98%     15.77s 10.21%  strconv.ParseFloat
    15.73s 10.18% 36.17%     15.73s 10.18%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     0.55s  0.36% 36.52%     15.27s  9.88%  strconv.parseFloatPrefix
     1.37s  0.89% 37.41%     14.72s  9.53%  strconv.atof64
     0.95s  0.61% 38.02%     14.36s  9.30%  runtime.makeslice
     2.43s  1.57% 39.60%     12.08s  7.82%  runtime.mallocgcSmallScanNoHeader
         0     0% 39.60%     10.62s  6.87%  bufio.(*Scanner).Text (inline)
     1.03s  0.67% 40.26%     10.62s  6.87%  runtime.slicebytetostring
     9.07s  5.87% 46.14%      9.07s  5.87%  memeqbody
     0.04s 0.026% 46.16%      9.06s  5.86%  runtime.systemstack
     1.65s  1.07% 47.23%      8.04s  5.20%  bufio.(*Scanner).Scan
```

The program takes 143.67 seconds.
It spends almost 30% on assigning to hash maps, and over 20% on accessing from hash maps.
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

There is a single data structure, `Statistics`, to store all metrics.
`Statistics` is generic because I want to leave the option open for later to optimize data types.
Note that I am using pointers with `Statistics` in order to reduce allocation overhead on access and assignment.

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:22:46 CET
Duration: 92.23s, Total samples = 104.79s (113.61%)
Showing nodes accounting for 94.13s, 89.83% of 104.79s total
Dropped 302 nodes (cum <= 0.52s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     92.99s 88.74%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun1
     3.39s  3.24%  3.24%     92.99s 88.74%  github.com/hy144328/one-billion-row-challenge-golang.run1
         0     0%  3.24%     92.99s 88.74%  testing.(*B).run1.func1
         0     0%  3.24%     92.99s 88.74%  testing.(*B).runN
     0.05s 0.048%  3.28%     33.80s 32.25%  strings.Split (inline)
     3.67s  3.50%  6.78%     33.75s 32.21%  strings.genSplit
     5.75s  5.49% 12.27%     22.89s 21.84%  runtime.mapaccess2_faststr
     2.41s  2.30% 14.57%     21.14s 20.17%  runtime.mallocgc
     0.58s  0.55% 15.13%     17.01s 16.23%  strconv.ParseFloat
     0.43s  0.41% 15.54%     16.43s 15.68%  strconv.parseFloatPrefix
     1.60s  1.53% 17.06%        16s 15.27%  strconv.atof64
        1s  0.95% 18.02%     15.92s 15.19%  runtime.makeslice
     2.95s  2.82% 20.83%     12.93s 12.34%  runtime.mallocgcSmallScanNoHeader
     0.02s 0.019% 20.85%     10.63s 10.14%  runtime.systemstack
     8.08s  7.71% 28.56%      8.17s  7.80%  strconv.readFloat
     0.10s 0.095% 28.66%      8.04s  7.67%  bufio.(*Scanner).Text (inline)
     0.94s   0.9% 29.55%      7.94s  7.58%  runtime.slicebytetostring
     1.17s  1.12% 30.67%      7.92s  7.56%  strings.Count
     0.01s 0.0095% 30.68%      7.87s  7.51%  runtime.gcBgMarkWorker
     1.97s  1.88% 32.56%      7.85s  7.49%  bufio.(*Scanner).Scan
```

The program takes 92.23 seconds, which is a 36% improvement.
Accessing from hash maps takes 22.89 seconds, which is a 27% improvement.
Assignment to hash maps does not even show up anymore in the top twenty.

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
		var temperature int
		if words[1][0] == '-' {
			temperature = -parseDigitsFromString(words[1][1:])
		} else {
			temperature = parseDigitsFromString(words[1])
		}

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

`parse.go`

```go
package main

import (
	"strconv"
)

func parseDigitsFromString(digits string) int {
	temperature10, err := strconv.Atoi(digits[:len(digits)-2])
	if err != nil {
		panic(err)
	}

	temperature1 := digits[len(digits)-1] - '0'
	return 10*temperature10 + int(temperature1)
}
```

I replace `strconv.ParseFloat()` with `parseDigitsFromString()`.
It consists of three instructions:

1.  Check sign. (`-`)
2.  Read digits before decimal point. (`strconv.Atoi()`)
3.  Read digit after decimal point. (`0`)

Instead of floating-point numbers with a single decimal digit, I keep track of metrics as integer numbers in tenths of a degree.
This will also streamline the arithmetics.

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:24:18 CET
Duration: 81.71s, Total samples = 94.55s (115.72%)
Showing nodes accounting for 84.37s, 89.23% of 94.55s total
Dropped 284 nodes (cum <= 0.47s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     83.30s 88.10%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun2
     3.66s  3.87%  3.87%     83.30s 88.10%  github.com/hy144328/one-billion-row-challenge-golang.run2
         0     0%  3.87%     83.30s 88.10%  testing.(*B).run1.func1
         0     0%  3.87%     83.30s 88.10%  testing.(*B).runN
     0.06s 0.063%  3.93%     34.29s 36.27%  strings.Split (inline)
     4.15s  4.39%  8.32%     34.23s 36.20%  strings.genSplit
     5.48s  5.80% 14.12%     23.88s 25.26%  runtime.mapaccess2_faststr
     2.36s  2.50% 16.62%     22.88s 24.20%  runtime.mallocgc
     1.33s  1.41% 18.02%     16.62s 17.58%  runtime.makeslice
     3.03s  3.20% 21.23%     13.43s 14.20%  runtime.mallocgcSmallScanNoHeader
     0.03s 0.032% 21.26%     10.39s 10.99%  runtime.systemstack
     0.03s 0.032% 21.29%      9.59s 10.14%  bufio.(*Scanner).Text (inline)
     1.04s  1.10% 22.39%      9.56s 10.11%  runtime.slicebytetostring
     1.72s  1.82% 24.21%      8.35s  8.83%  bufio.(*Scanner).Scan
     1.42s  1.50% 25.71%      7.68s  8.12%  strings.Count
         0     0% 25.71%      6.78s  7.17%  runtime.gcBgMarkWorker
     6.18s  6.54% 32.25%      6.18s  6.54%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
         0     0% 32.25%      6.01s  6.36%  runtime.gcBgMarkWorker.func2
     0.08s 0.085% 32.33%      5.99s  6.34%  runtime.gcDrain
     5.94s  6.28% 38.61%      5.94s  6.28%  runtime.nextFreeFast (inline)
```

The program takes 81.71 seconds, which is an 11% improvement.
The wall time goes down from 16.43 seconds for `strconv.ParseFloat()` to 3.53 seconds for `parseDigitsFromString()` (not shown).
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

		var temperature int
		if lineIt[sepIdx+1] == '-' {
			temperature = -parseDigitsFromString(lineIt[sepIdx+2:])
		} else {
			temperature = parseDigitsFromString(lineIt[sepIdx+1:])
		}

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
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:25:40 CET
Duration: 50.22s, Total samples = 54.89s (109.29%)
Showing nodes accounting for 50.46s, 91.93% of 54.89s total
Dropped 234 nodes (cum <= 0.27s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     50.54s 92.08%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun3
     3.79s  6.90%  6.90%     50.54s 92.08%  github.com/hy144328/one-billion-row-challenge-golang.run3
         0     0%  6.90%     50.54s 92.08%  testing.(*B).run1.func1
         0     0%  6.90%     50.54s 92.08%  testing.(*B).runN
     5.40s  9.84% 16.74%     19.75s 35.98%  runtime.mapaccess2_faststr
     0.18s  0.33% 17.07%      8.49s 15.47%  bufio.(*Scanner).Text (inline)
     1.11s  2.02% 19.09%      8.31s 15.14%  runtime.slicebytetostring
     1.71s  3.12% 22.21%      7.38s 13.45%  bufio.(*Scanner).Scan
     6.40s 11.66% 33.87%      6.40s 11.66%  indexbytebody
     0.07s  0.13% 34.00%      6.34s 11.55%  internal/stringslite.IndexByte (inline)
         0     0% 34.00%      6.34s 11.55%  strings.IndexByte (inline)
     0.97s  1.77% 35.76%      6.30s 11.48%  runtime.mallocgc
     5.02s  9.15% 44.91%      5.02s  9.15%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     1.79s  3.26% 48.17%      4.79s  8.73%  github.com/hy144328/one-billion-row-challenge-golang.parseDigitsFromString
     2.08s  3.79% 51.96%      3.91s  7.12%  runtime.mallocgcTiny
     0.02s 0.036% 51.99%      3.90s  7.11%  runtime.systemstack
     0.05s 0.091% 52.09%      3.26s  5.94%  os.(*File).Read
     0.01s 0.018% 52.10%      3.18s  5.79%  os.(*File).read (inline)
     0.03s 0.055% 52.16%      3.17s  5.78%  internal/poll.(*FD).Read
         0     0% 52.16%      3.09s  5.63%  internal/poll.ignoringEINTRIO (inline)
```

The program takes 50.22 seconds, which is a 39% improvement.
This is the largest relative improvement so far.

## Optimization #4: Byte slices.

`main.go`:

```go
func run4(r io.Reader) map[string]*Statistics[int] {
	res := make(map[string]*Statistics[int], maxCities)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		lineIt := scanner.Bytes()
		sepIdx := bytes.IndexByte(lineIt, ';')

		var temperature int
		if lineIt[sepIdx+1] == '-' {
			temperature = -parseDigitsFromBytes(lineIt[sepIdx+2:])
		} else {
			temperature = parseDigitsFromBytes(lineIt[sepIdx+1:])
		}

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

`parse.go`:

```go
func parseDigitsFromBytes(digits []byte) int {
	switch len(digits) {
	case 3:
		return 10*int(digits[0]-'0') + int(digits[2]-'0')
	case 4:
		return 100*int(digits[0]-'0') + 10*int(digits[1]-'0') + int(digits[3]-'0')
	default:
		panic(string(digits))
	}
}
```

The decision to work with byte slices instead of strings entails the following three changes:

*   Replace `scanner.Text()` with `scanner.Bytes()`.
*   Replace `strings.IndexByte()` with `bytes.IndexByte()`.
*   Replace `parseDigitsFromString()` with `parseDigitsFromBytes()`.

The implementation of `parseDigitsFromBytes()` is fundamentally different from the implementation of `parseDigitsFromString()`.
The implementation of `parseDigitsFromString()` relies on `strconv.Atoi()` accepting strings but not byte slices.
Alternatively, I leverage the specific format of the one-billion row challenge.
I unwrap all loops, and the control flow is simplified to two questions:

1.  Is there a negative sign?
2.  Is the temperature in the single-digit or double-digits range?

The hash map is still working with string keys.
Again, I pass byte slices directly to functions to give the compiler opportunities for optimizations under the hood.

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:26:31 CET
Duration: 27.17s, Total samples = 27.08s (99.68%)
Showing nodes accounting for 26.71s, 98.63% of 27.08s total
Dropped 28 nodes (cum <= 0.14s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     27.04s 99.85%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun4
     3.10s 11.45% 11.45%     27.04s 99.85%  github.com/hy144328/one-billion-row-challenge-golang.run4
         0     0% 11.45%     27.04s 99.85%  testing.(*B).run1.func1
         0     0% 11.45%     27.04s 99.85%  testing.(*B).runN
     4.95s 18.28% 29.73%     15.40s 56.87%  runtime.mapaccess2_faststr
     1.52s  5.61% 35.34%      6.27s 23.15%  bufio.(*Scanner).Scan
     3.75s 13.85% 49.19%      3.75s 13.85%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
     0.63s  2.33% 51.51%      2.50s  9.23%  bytes.IndexByte (inline)
     0.03s  0.11% 51.62%      2.49s  9.19%  os.(*File).Read
     0.02s 0.074% 51.70%      2.44s  9.01%  internal/poll.(*FD).Read
         0     0% 51.70%      2.44s  9.01%  os.(*File).read (inline)
         0     0% 51.70%      2.39s  8.83%  internal/poll.ignoringEINTRIO (inline)
     0.03s  0.11% 51.81%      2.39s  8.83%  syscall.Read (inline)
     0.03s  0.11% 51.92%      2.36s  8.71%  syscall.read
     0.06s  0.22% 52.14%      2.33s  8.60%  syscall.Syscall
     0.04s  0.15% 52.29%      2.19s  8.09%  syscall.RawSyscall6
     2.15s  7.94% 60.23%      2.15s  7.94%  internal/runtime/syscall.Syscall6
     0.55s  2.03% 62.26%      2.04s  7.53%  bufio.ScanLines
     1.52s  5.61% 67.87%      1.52s  5.61%  aeshashbody
     1.52s  5.61% 73.49%      1.52s  5.61%  indexbytebody
```

The program takes 27.17 seconds, which is a 46% improvement.
Again, this is the accumulation of multiple changes.
For instance:

*   The wall time goes down from 6.34 seconds for `strings.IndexByte()` to 2.50 seconds for `bytes.IndexByte()`.
*   The wall time goes down from 4.79 seconds for `parseDigitsFromString()` to 0.97 seconds for `parseDigitsFromBytes()` (not shown).

## Optimization #5. Buffered reader.

`main.go`:

```go
func run5(r io.Reader) map[string]*Statistics[int] {
	res := make(map[string]*Statistics[int], maxCities)
	reader := bufio.NewReader(r)

	for {
		lineIt, err := reader.ReadSlice('\n')
		if err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}

		sepIdx := bytes.IndexByte(lineIt, ';')

		var temperature int
		if lineIt[sepIdx+1] == '-' {
			temperature = -parseDigitsFromBytes(lineIt[sepIdx+2 : len(lineIt)-1])
		} else {
			temperature = parseDigitsFromBytes(lineIt[sepIdx+1 : len(lineIt)-1])
		}

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

I replace `bufio.Scanner` with `bufio.Reader`.
I expect there to be minimal differences in terms of performance.

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:26:58 CET
Duration: 24.98s, Total samples = 24.89s (99.64%)
Showing nodes accounting for 24.62s, 98.92% of 24.89s total
Dropped 33 nodes (cum <= 0.12s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     24.85s 99.84%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun5
     2.36s  9.48%  9.48%     24.85s 99.84%  github.com/hy144328/one-billion-row-challenge-golang.run5
         0     0%  9.48%     24.85s 99.84%  testing.(*B).run1.func1
         0     0%  9.48%     24.85s 99.84%  testing.(*B).runN
     4.71s 18.92% 28.40%     15.54s 62.43%  runtime.mapaccess2_faststr
     1.62s  6.51% 34.91%      4.82s 19.37%  bufio.(*Reader).ReadSlice
     3.99s 16.03% 50.94%      3.99s 16.03%  internal/runtime/maps.ctrlGroup.matchH2 (inline)
         0     0% 50.94%      2.26s  9.08%  bufio.(*Reader).fill
     0.04s  0.16% 51.10%      2.26s  9.08%  os.(*File).Read
         0     0% 51.10%      2.21s  8.88%  internal/poll.(*FD).Read
         0     0% 51.10%      2.21s  8.88%  os.(*File).read (inline)
     0.33s  1.33% 52.43%      2.20s  8.84%  bytes.IndexByte (inline)
         0     0% 52.43%      2.18s  8.76%  internal/poll.ignoringEINTRIO (inline)
     0.01s  0.04% 52.47%      2.18s  8.76%  syscall.Read (inline)
     0.01s  0.04% 52.51%      2.17s  8.72%  syscall.read
     0.03s  0.12% 52.63%      2.16s  8.68%  syscall.Syscall
     0.03s  0.12% 52.75%      1.97s  7.91%  syscall.RawSyscall6
     1.94s  7.79% 60.55%      1.94s  7.79%  internal/runtime/syscall.Syscall6
     1.75s  7.03% 67.58%      1.75s  7.03%  aeshashbody
     1.68s  6.75% 74.33%      1.68s  6.75%  memeqbody
```

The program takes 24.98 seconds, which is an 8% improvement.
This is modest but not too bad!
The wall time goes down from 6.27 seconds for `scanner.Scan()` to 4.82 seconds for `reader.ReadSlice()`.

<!--
## Optimization #6. Custom hash map.

`main.go`:

```go
func run6(r io.Reader) *BytesMap[Statistics[int]] {
	res := NewBytesMap[Statistics[int]](noRegisters)
	reader := bufio.NewReader(r)

	for {
		lineIt, err := reader.ReadSlice('\n')
		if err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}

		sepIdx := bytes.IndexByte(lineIt, ';')
		city := lineIt[:sepIdx]

		var temperature int
		if lineIt[sepIdx+1] == '-' {
			temperature = -parseDigitsFromBytes(lineIt[sepIdx+2 : len(lineIt)-1])
		} else {
			temperature = parseDigitsFromBytes(lineIt[sepIdx+1 : len(lineIt)-1])
		}

		resIt, ok := res.GetOrCreate(city)
		if !ok {
			resIt.Cnt = 1
			resIt.Max = temperature
			resIt.Min = temperature
			resIt.Sum = temperature
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

`hash_map.go`:

```go
package main

import (
	"bytes"
	"hash/maphash"
)

type Register[T any] struct {
	KeyLen int
	Hash   uint64
	Key    [100]byte
	Value  T
}

type BytesMap[T any] struct {
	noRegisters uint64
	registers   []Register[T]
	seed        maphash.Seed
}

func NewBytesMap[T any](noRegisters int) *BytesMap[T] {
	if noRegisters&(noRegisters-1) != 0 {
		panic("not power of 2")
	}

	return &BytesMap[T]{
		noRegisters: uint64(noRegisters),
		registers:   make([]Register[T], noRegisters),
		seed:        maphash.MakeSeed(),
	}
}

func (m *BytesMap[T]) GetOrCreate(k []byte) (*T, bool) {
	h := maphash.Bytes(m.seed, k)

	for i := h; i < h+m.noRegisters; i++ {
		idx := i & (m.noRegisters - 1)

		if klen := m.registers[idx].KeyLen; klen == 0 {
			m.registers[idx].KeyLen = len(k)
			m.registers[idx].Hash = h
			copy(m.registers[idx].Key[:], k)
			return &m.registers[idx].Value, false
		} else if h == m.registers[idx].Hash && bytes.Equal(m.registers[idx].Key[:klen], k) {
			return &m.registers[idx].Value, true
		}
	}

	panic("registers full")
}

func (m *BytesMap[T]) ToMap() map[string]*T {
	res := make(map[string]*T, maxCities)

	for i := range m.registers {
		if klen := m.registers[i].KeyLen; klen > 0 {
			res[string(m.registers[i].Key[:klen])] = &m.registers[i].Value
		}
	}

	return res
}
```

In short, I implemented a custom hash map with open addressing and linear probing.
City names are held by byte arrays with a fixed size of 100 in agreement with the rules and limits.
The hash function is taken from the `hash/maphash` standard library.
The number of registers is 1,048,576, which is significantly larger than 10,000, the number of cities, in order to minimize the number of hash collisions.
In general, we work with powers of two and binary operations where possible.

```
File: one-billion-row-challenge-golang.test
Build ID: 72bca091f466609dc907466886cde8910df298d4
Type: cpu
Time: 2026-01-15 21:27:23 CET
Duration: 26.56s, Total samples = 26.45s (99.57%)
Showing nodes accounting for 26.23s, 99.17% of 26.45s total
Dropped 29 nodes (cum <= 0.13s)
      flat  flat%   sum%        cum   cum%
         0     0%     0%     26.43s 99.92%  github.com/hy144328/one-billion-row-challenge-golang.BenchmarkRun6
         0     0%     0%     26.43s 99.92%  testing.(*B).run1.func1
         0     0%     0%     26.43s 99.92%  testing.(*B).runN
     2.65s 10.02% 10.02%     26.41s 99.85%  github.com/hy144328/one-billion-row-challenge-golang.run6
     7.14s 26.99% 37.01%     13.02s 49.22%  github.com/hy144328/one-billion-row-challenge-golang.(*BytesMap[go.shape.struct { Cnt int; Max int; Min int; Sum int }]).GetOrCreate
     1.79s  6.77% 43.78%      6.56s 24.80%  bufio.(*Reader).ReadSlice
     0.31s  1.17% 44.95%      4.61s 17.43%  bytes.IndexByte (inline)
     3.74s 14.14% 59.09%      3.74s 14.14%  indexbytebody
     0.26s  0.98% 60.08%      3.21s 12.14%  bytes.Equal (inline)
     2.80s 10.59% 70.66%      2.80s 10.59%  memeqbody
     0.42s  1.59% 72.25%      2.67s 10.09%  hash/maphash.Bytes
     0.06s  0.23% 72.48%      2.43s  9.19%  bufio.(*Reader).fill
     0.01s 0.038% 72.51%      2.36s  8.92%  os.(*File).Read
         0     0% 72.51%      2.34s  8.85%  internal/poll.(*FD).Read
         0     0% 72.51%      2.34s  8.85%  os.(*File).read (inline)
         0     0% 72.51%      2.33s  8.81%  internal/poll.ignoringEINTRIO (inline)
     0.02s 0.076% 72.59%      2.33s  8.81%  syscall.Read (inline)
     0.03s  0.11% 72.70%      2.31s  8.73%  syscall.read
     0.01s 0.038% 72.74%      2.28s  8.62%  syscall.Syscall
     0.14s  0.53% 73.27%      2.25s  8.51%  hash/maphash.rthash (inline)
```

The results are mixed.
On the one hand, the wall time goes down from 15.54 seconds for accessing from hash maps to 13.02 seconds for `BytesMap.GetOrCreate()`.
On the other hand, the program now takes 26.56 seconds in total, which is actually a decline of 6%.
More specifically:

*   The wall time for `reader.ReadSlice()` goes up from 4.82 seconds to 6.56 seconds.
*   The wall time for `parseDigitsFromBytes()` goes up from 0.87 seconds (not shown) to 1.91 seconds (not shown).

The fact that a changed line of code improved while unchanged lines deteriorated is evidence for register pressure and spill.
This is beyond the scope of the current blog post.
-->

## Conclusion

The following table summarizes the progress:

| | wall time \[seconds\] | improvement delta | improvement total |
|-|-----------|-------------------------|-------------------|
| [Baseline implementation](#baseline-implementation) | 143.67 | -0% | -0% |
| [Row-oriented data](#optimization-1-row-oriented-data) | 92.23 | -36% | -36% |
| [Floating-point arithmetics](#optimization-2-floating-point-arithmetics) | 81.71 | -11% | -43% |
| [Substrings](#optimization-3-substrings) | 50.22 | -39% | -65% |
| [Byte slices](#optimization-4-byte-slices) | 27.17 | -46% | -81% |
| [Buffered reader](#optimization-5-buffered-reader) | 24.98 | -8% | -83% |

Or in other words, the final version takes one sixth of the wall time of the initial version, which is less than 30 seconds.
In hindsight, row-oriented data makes more sense than column-oriented data because hash maps perform random access.
Reducing the number of allocations via substrings and byte slices is a game changer.
The impact of replacing floating-point numbers with integer numbers is less obvious but it contributes to the improvements when byte slices are introduced and in other places.
Replacing `bufio.Scanner` with `bufio.Reader` is less significant than the other optimizations, which speaks to the high-quality implementation of `bufio.Scanner`.
In summary, I am very optimistic about reaching wall times below 10 seconds once I transition to parallel execution -- another time!
