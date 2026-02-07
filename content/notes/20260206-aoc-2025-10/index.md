+++
date = '2026-02-06T23:45:03+01:00'
title = 'Advent of Code 2025, day 10: Diophantine equations.'
tags = ['golang']
+++

{{< badge >}}golang{{< /badge >}}

I like to participate in [Advent of Code](https://adventofcode.com/) to pick up new languages.
In [December](https://adventofcode.com/2025), I decided to solve the daily problems in Go.
Difficulty increased as the month progressed but I found it quite straightforward overall.
However, one problem stood out to me: [day 10](https://adventofcode.com/2025/day/10), part 2.
At first, it reminded me of the [coin change](https://leetcode.com/problems/coin-change/) problem, which has a dynamic programming solution.
Unfortunately, the state space proves too large.
Instead, [most solutions](https://www.reddit.com/r/adventofcode/comments/1pity70/2025_day_10_solutions/) resort to integer linear programming.
Alternatively, [u/tenthmascot](https://www.reddit.com/user/tenthmascot/) shared a really elegant solution on [Reddit](https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/).
This is the topic of this blog post.

{{< gitlab projectID="59934121" >}}

## Part one

I am going to keep this one short.
In essence, I implemented a breadth-first search:

```go
package main

func partOne(machines []Machine) (int, error) {
	var res int

	for _, machineIt := range machines {
		resIt, err := countPressesForLights(machineIt)
		if err != nil {
			return res, err
		}
		res += resIt
	}

	return res, nil
}

func countPressesForLights(machine Machine) (int, error) {
	lsLights := NewSet[IndicatorLights]()
	lsLights.Add(machine.TargetLights.Empty())

	seen := NewSet[IndicatorLights]()
	seen.Add(machine.TargetLights.Empty())

	for pressCt := 0; !lsLights.IsEmpty(); pressCt++ {
		lsLightsNext := NewSet[IndicatorLights]()

		for lightsIt := range lsLights.Iter() {
			for _, buttonIt := range machine.Buttons {
				lightsNext := lightsIt.Copy()
				buttonIt.ToggleLights(lightsNext)

				if seen.Contains(lightsNext) {
					continue
				}

				if machine.MatchesLights(lightsNext) {
					return pressCt + 1, nil
				}

				lsLightsNext.Add(lightsNext)
				seen.Add(lightsNext)
			}
		}

		lsLights = lsLightsNext
	}

	return -1, errNoSolution
}
```

It is noteworthy that the indicator lights are involuntary with respect to button presses.
Mathematically speaking, counters are congruent to 0 modulo n for a multiple of n button presses.
This will be useful in [part two](#part-two-theory).
For part one, it means that the optimal solution presses each button at most once.[^1]
The state space is the powerset over the set of buttons; the cardinality is 2 to the number of buttons.

[^1]: The proof is easy.
    If a single button were pressed more than once, pressing that single button two times fewer would be another, more optimal solution.
    Contradiction.

## Part two: Theory.

Before we jump into the code, I would like to share some preliminary thoughts.
Mathematically speaking, we are looking for integer solutions to the linear system of equations
{{< katex >}}
$$
\begin{equation}
\sum_l{\chi_{k,l} r_l} = j_k \quad ,
\end{equation}
$$
where the joltage level of the \\(k\\)-th counter is signified by \\(j_k\\), the number of presses of the \\(l\\)-th button by \\(r_l\\), and the increment of the \\(l\\)-th button on the \\(k\\)-th counter by
$$
\begin{equation}
\chi_{k,l} = \begin{cases}
1 & \text{if \\(l\\)-th button increments \\(k\\)-th counter} \\\\
0 & \text{if not}
\end{cases} \quad .
\end{equation}
$$

It follows that this system of equations has to hold modulo \\(p\\), too:
$$
\begin{equation}
\sum_l{\chi_{k,l} r_l} \equiv j_k \mod p \quad .
\end{equation}
$$
Note that the system of Diophantine equations is necessary but not sufficient.
It is possible to express \\(r_l\\) as
$$
\begin{equation}
r_l = p r_l^{(1)} + q_l^{(1)} \quad , \quad 0 \leq q_l^{(1)} < p \quad .
\end{equation}
$$
It follows from the observation at the end of [part one](#part-one) that
$$
\begin{equation}
\sum_l{\chi_{k,l} q_l^{(1)}} \equiv j_k \mod p \quad .
\end{equation}
$$
We substitute the expression for \\(r_l\\) in the linear system of equations:
$$
\begin{equation}
\sum_l{\chi_{k,l} r_l^{(1)}} = j_k^{(1)} \quad ,
\end{equation}
$$
$$
\begin{equation}
j_k^{(1)} = \frac{j_k - \sum{\chi_{k,l} q_l^{(1)}}}{p} \quad .
\end{equation}
$$
This recursion is the key insight.
We have a monotonically decreasing sequence \\(j_k^{(n)}\\) in \\(n\\) until \\(j_k^{(n)}\\) is non-positive for all \\(k\\).
The descent is exponential with base \\(1/p\\).
So we expect the state space to be more manageable than with depth-first-search.
The solution of the recursion is given by
$$
\begin{equation}
r_l = \sum_n{p^{n-1} q_l^{(n)}} \quad .
\end{equation}
$$

## Part two: Implementation.

This is a recursive implementation:

```go
package main

import (
	"errors"
	"fmt"
	"log/slog"
	"math"
)

var (
	errNotOptimal = errors.New("not optimal")
)

func partTwo(machines []Machine) (int, error) {
	var res int

	for machineCt, machineIt := range machines {
		slog.Info(
			"Attempt machine.",
			"machineCt",
			machineCt,
			"noMachines",
			len(machines),
		)

		resIt, err := countPressesForJoltages(machineIt)
		if err != nil {
			return res, err
		}

		slog.Info(
			"Processed machine.",
			"noPresses",
			resIt,
			"machineCt",
			machineCt,
			"noMachines",
			len(machines),
		)
		res += resIt
	}

	return res, nil
}

func countPressesForJoltages(machine Machine) (int, error) {
	res := math.MaxInt
	cache := cacheLights(machine)

	if err := countPressesForJoltagesRec(
		machine,
		machine.TargetJoltages.Empty(),
		0,
		0,
		&res,
		cache,
	); err != nil {
		return res, err
	}

	if res == math.MaxInt {
		return res, errNoSolution
	}

	return res, nil
}

func countPressesForJoltagesRec(
	machine Machine,
	joltages JoltageLevels,
	depth int,
	noPresses int,
	minPresses *int,
	cache *Dict[IndicatorLights, [][]bool],
) error {
	if machine.MatchesJoltages(joltages) {
		*minPresses = min(*minPresses, noPresses)
		return nil
	}

	exceeded, err := machine.JoltagesExceeded(joltages)
	if err != nil {
		return err
	}
	if exceeded {
		return errNoSolution
	}

	if noPresses >= *minPresses {
		return fmt.Errorf("%w: %d, %d.", errNotOptimal, noPresses, *minPresses)
	}

	lights := machine.TargetLights.Empty()
	for lightCt := range lights {
		lights[lightCt] = (machine.TargetJoltages[lightCt]-joltages[lightCt])%2 == 1
	}

	for _, pressIt := range cache.Get(lights) {
		joltagesIt := joltages.Copy()
		noPressesIt := noPresses

		for buttonCt, buttonIt := range machine.Buttons {
			if pressIt[buttonCt] {
				joltagesIt = buttonIt.IncrementJoltages(joltagesIt)
				noPressesIt += pow(2, depth)
			}
		}

		for joltageCt, joltageIt := range joltagesIt {
			joltagesIt[joltageCt] = (joltageIt + machine.TargetJoltages[joltageCt]) / 2
		}

		err := countPressesForJoltagesRec(
			machine,
			joltagesIt,
			depth+1,
			noPressesIt,
			minPresses,
			cache,
		)

		if errors.Is(err, errNoSolution) {
			continue
		} else if errors.Is(err, errNotOptimal) {
			continue
		} else if err != nil {
			return err
		}
	}

	return nil
}
```

Note that we have already solved the system of Diophantine equations in [part one](#part-one) for \\(p = 2\\).
In order to avoid repeated calculations, we memoize the solutions of the Diophantine equations.
This is feasible because the number of buttons is not too large.

```go
package main

func memoizeLights(machine Machine) *Dict[IndicatorLights, [][]bool] {
	res := NewDict[IndicatorLights, [][]bool]()

	for pressIt := range iterateToggles(len(machine.Buttons)) {
		lightsIt := machine.TargetLights.Empty()

		for buttonCt, buttonIt := range machine.Buttons {
			if pressIt[buttonCt] {
				lightsIt = buttonIt.ToggleLights(lightsIt)
			}
		}

		resIt := res.Get(lightsIt)
		res.Set(lightsIt, append(resIt, pressIt))
	}

	return res
}

func iterateToggles(n int) <-chan []bool {
	res := make(chan []bool)

	go func() {
		for i := range pow(2, n) {
			resIt := make([]bool, n)

			for k := range n {
				resIt[k] = (i>>k)&1 == 1
			}

			res <- resIt
		}

		close(res)
	}()

	return res
}
```

Chances are that there is room for even more optimization.
For example, it is possible to memoize the linear equations, too, in addition to the Diophantine equations.
However, the performance is already decent:

```
goos: linux
goarch: amd64
pkg: gitlab.com/hyu/advent-of-code/2025/golang-10
cpu: Intel(R) Core(TM) i5-10400 CPU @ 2.90GHz
BenchmarkPartTwo-12    	       4	 309797988 ns/op
PASS
ok  	gitlab.com/hyu/advent-of-code/2025/golang-10	1.413s
```
