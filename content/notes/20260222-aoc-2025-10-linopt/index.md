+++
date = '2026-02-22T19:04:18+01:00'
draft = true
title = 'Advent of Code 2025, day 10: Linear programming.'
tags = ['golang']
+++

{{< badge >}}golang{{< /badge >}}

Last time, I wrote about [my implementation](https://gitlab.com/hyu/advent-of-code/-/tree/master/2025/golang-10) of a very elegant [Reddit solution](https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/) to [day 10](https://adventofcode.com/2025/day/10) of [Advent of Code 2025](https://adventofcode.com/2025).
I had already mentioned that [most solutions](https://www.reddit.com/r/adventofcode/comments/1pity70/2025_day_10_solutions/) resorted to integer linear programming.
In fact, because part 2 did not budge to dynamic programming, and I became pressed for time, I pulled out [Python and SciPy](https://gitlab.com/hyu/advent-of-code/-/tree/master/2025/python-10) to do the same.
However, I was unhappy for at least two reasons.
Firstly, I did not find a suitable Go library for integer linear programming.
Either they required bindings to heavyweight solvers, which I did not feel inclined to install.
Or, in the case of [Gonum](https://pkg.go.dev/gonum.org/v1/gonum/optimize/convex/lp), they struggled with overconstrained problems although they admitted solutions.
Secondly, many libraries involved floating-point arithmetics, which is prone to rounding errors for poorly conditioned problems.
Over the holiday break, I decided to implement my own solver without floating-point arithmetics.

The solver implements the [branch-and-cut algorithm](https://en.wikipedia.org/wiki/Branch_and_cut) for minimization:

1.  Solve the relaxed [linear programming](https://en.wikipedia.org/wiki/Linear_programming) problem without integer constraints via the [Simplex algorithm](https://en.wikipedia.org/wiki/Simplex_algorithm).
2.  If the Simplex algorithm returns an integer solution, this will be an upper bound.
3.  If the Simplex algorithm returns a non-integer solution, this will be a lower bound.
    If this lower bound is less than the best upper bound, introduce a [cutting plane](https://en.wikipedia.org/wiki/Cutting-plane_method).
    The cutting plane tightens the relaxed linear programming problem with an additional constraint.
    This introduces two branches of the original linear programming problem.

{{< gitlab projectID="59934121" >}}

## Scalar numbers


