+++
date = '2026-02-22T19:04:18+01:00'
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

1.  Solve the relaxed [linear program](https://en.wikipedia.org/wiki/Linear_programming) without integer constraints via the [Simplex algorithm](https://en.wikipedia.org/wiki/Simplex_algorithm).
2.  If the Simplex algorithm returns an integer solution, this will be an upper bound.
3.  If the Simplex algorithm returns a non-integer solution, this will be a lower bound.
    If this lower bound is less than the best upper bound, introduce a [cutting plane](https://en.wikipedia.org/wiki/Cutting-plane_method).
    The cutting plane tightens the relaxed linear program with an additional constraint.
    This introduces two branches of the original linear program.

{{< gitlab projectID="59934121" >}}

## Scalar numbers

Even if the problem only involves integer numbers, non-integer numbers will inevitably show up when we divide one integer number by another.
Floating-point division loses precision so we need to record the results as fractions.
I define a generic `Scalar` type that works with every built-in integer type `T`.
An instance of the `Scalar` type is represented by a numerator and a denominator.
They are always normalized such that (i) numerator and denominator have no divisors in common, and (ii) the denominator is always positive.
Afterwards, it will be straightforward to implement addition, multiplication, comparison, etc.

```go
type Scalar[T constraints.Integer] struct {
	Numerator   T
	Denominator T
}

func NewScalar[T constraints.Integer](
	num T,
	denom T,
) (Scalar[T], error) {
	var res Scalar[T]

	if denom == 0 {
		return res, ErrZeroDivisor
	} else if denom < 0 {
		num = -num
		denom = -denom
	}

	divisor := gcd(num, denom)
	if divisor == 0 {
		return res, ErrZeroDivisor
	}

	res.Numerator = num / divisor
	res.Denominator = denom / divisor

	return res, nil
}
```

## Linear algebra

We formulate linear systems of equations in terms of vectors and matrices:

```go
type Vector[T any] []T

type Matrix[T any] [][]T

type Problem[T constraints.Integer] struct {
	A Matrix[T]
	B Vector[T]
}

type Solution[T constraints.Integer] struct {
	Particular      Vector[Scalar[T]]
	HomogeneousBase []Vector[T]
}
```

In anticipation of Gauss elimination ([see below](#gauss-elimination)), we define a number of methods to facilitate row reduction.
It is more convenient to handle the left-hand side matrix and the right-hand side vector in a single tableau:

```go
func (problem *Problem[T]) ToTableau() Matrix[T] {
	noConstraints := problem.NoConstraints()
	noVariables := problem.NoVariables()

	res := NewMatrix[T](
		noConstraints,
		noVariables+1,
	)

	for rowCt, rowIt := range res {
		copy(rowIt, problem.A[rowCt])
		rowIt[noVariables] = problem.B[rowCt]
	}

	return res
}
```

The tableau is invariant to the following tableau transformations:

*   `ScaleRow()` multiplies every entry in a row by a constant factor.
*   `EliminateRow()` subtracts a multiple of one row from a multiple of another row such that the entry in a given column vanishes, and all entries in the row remain integer numbers.
*   `DeflateRow()` divides every entry in a row by their greatest common divisor.

```go
func ScaleRow[T constraints.Integer](a Matrix[T], idx int, fac T) {
	row := a[idx]

	for colCt := range row {
		row[colCt] *= fac
	}
}

func EliminateRow[T constraints.Integer](a Matrix[T], srcIdx int, dstIdx int, colIdx int) error {
	src := a[srcIdx]
	dst := a[dstIdx]

	facSrc := dst[colIdx]
	facDst := src[colIdx]

	if facDst == 0 {
		return fmt.Errorf("%w: a, %d, %d, %d.", ErrZeroPivot, srcIdx, dstIdx, colIdx)
	}

	for colCt, colIt := range src {
		dst[colCt] *= facDst
		dst[colCt] -= facSrc * colIt
	}

	return nil
}S

func DeflateRow[T constraints.Integer](a Matrix[T], idx int) error {
	row := a[idx]
	fac := gcd(row[0], row[1:]...)
	if fac == 0 {
		return fmt.Errorf("%w: a, %d.", ErrAllZeroes, idx)
	}

	for colCt := range row {
		row[colCt] /= fac
	}

	return nil
}
```

## Gauss elimination

Gauss elimination follows three steps:

1.  Forward elimination.
2.  Backward substitution.
3.  Solution identification.

```go
func Solve[T constraints.Integer](problem *Problem[T]) *Solution[T] {
	noConstraints := problem.NoConstraints()
	noVariables := problem.NoVariables()

	mat := problem.ToTableau()

	pivots := make([]int, 0, noConstraints)

	for rowCt, colCt := 0, 0; rowCt < noConstraints && colCt < noVariables; {
		pivotColumn(mat, rowCt, colCt)

		if mat[rowCt][colCt] == 0 {
			colCt++
			continue
		}

		pivots = append(pivots, colCt)

		if err := eliminateDown(mat, rowCt, colCt); err != nil {
			panic(err)
		}

		rowCt++
		colCt++
	}

	for rowCt := len(pivots); rowCt < noConstraints; rowCt++ {
		if mat[rowCt][noVariables] != 0 {
			return nil
		}
	}

	for rowCt, colCt := range pivots {
		if err := eliminateUp(mat, rowCt, colCt); err != nil {
			panic(err)
		}
	}

	part, err := extractParticular(mat, pivots)
	if err != nil {
		panic(err)
	}

	homs := make([]Vector[T], 0, noVariables - len(pivots))
	scaleDiagonal(mat, pivots)

	for varCt := range noVariables {
		if slices.Contains(pivots, varCt) {
			continue
		}

		homs = append(
			homs,
			extractHomogeneous(mat, pivots, varCt),
		)
	}

	res, err := NewSolution(part, homs...)
	if err != nil {
		panic(err)
	}

	return res
}
```

From the top left to the bottom right, forward elimination identifies the pivot, and eliminates the rows below.
If necessary, a row is swapped with a lower row if the lower row would have a larger pivot.
The result is an upper triangular matrix.

```go
func pivotColumn[T constraints.Integer](
	mat Matrix[T],
	rowIdx int,
	colIdx int,
) {
	for rowCt := rowIdx + 1; rowCt < mat.NoRows(); rowCt++ {
		if abs(mat[rowIdx][colIdx]) < abs(mat[rowCt][colIdx]) {
			mat[rowIdx], mat[rowCt] = mat[rowCt], mat[rowIdx]
		}
	}
}

func eliminateDown[T constraints.Integer](
	mat Matrix[T],
	rowIdx int,
	colIdx int,
) error {
	for rowCt := rowIdx + 1; rowCt < mat.NoRows(); rowCt++ {
		if err := EliminateRow(mat, rowIdx, rowCt, colIdx); err != nil {
			return err
		}

		if err := DeflateRow(mat, rowCt); errors.Is(err, ErrAllZeroes) {
		} else if err != nil {
			return err
		}
	}

	return nil
}
```

From the bottom right to the top left, backward substitution follows the pivots in reverse, and eliminates the rows above.
The result is a matrix that is diagonal on the pivot columns.

```go
func eliminateUp[T constraints.Integer](
	mat Matrix[T],
	rowIdx int,
	colIdx int,
) error {
	for rowCt := range rowIdx {
		if err := EliminateRow(mat, rowIdx, rowCt, colIdx); err != nil {
			return err
		}

		if err := DeflateRow(mat, rowCt); errors.Is(err, ErrAllZeroes) {
		} else if err != nil {
			return err
		}
	}

	return nil
}
```

Finally, we identify the particular solution and the base of homogeneous solutions.
The calculation of the particular solution inevitably involves division so the result is a vector of the rational numbers.
Whereas the base vectors of the homogeneous solutions are scale invariant so that it is possible to represent them in terms of integer numbers.

```go
func scaleDiagonal[T constraints.Integer](
	mat Matrix[T],
	pivots []int,
) {
	factors := make([]T, len(pivots))

	for rowCt, colCt := range pivots {
		if err := DeflateRow(mat, rowCt); err != nil {
			panic(err)
		}

		factors[rowCt] = mat[rowCt][colCt]
	}

	multiple := lcm(factors[0], factors[1:]...)

	for rowCt, colCt := range pivots {
		ScaleRow(mat, rowCt, multiple/mat[rowCt][colCt])
	}
}

func extractParticular[T constraints.Integer](
	mat Matrix[T],
	pivots []int,
) (Vector[Scalar[T]], error) {
	noVariables := mat.NoColumns() - 1
	res := NewScalarVector[T](noVariables)

	for rowCt, colCt := range pivots {
		scalarIt, err := NewScalar(
			mat[rowCt][noVariables],
			mat[rowCt][colCt],
		)
		if err != nil {
			return nil, err
		}

		res[colCt] = scalarIt
	}

	return res, nil
}

func extractHomogeneous[T constraints.Integer](
	mat Matrix[T],
	pivots []int,
	colIdx int,
) Vector[T] {
	noVariables := mat.NoColumns() - 1
	res := NewVector[T](noVariables)
	res[colIdx] = 1

	for rowCt, colCt := range pivots {
		res[colCt] = -mat[rowCt][colIdx]
	}

	return res
}
```

## Linear programming

In general, we consider a linear program in canonical form:

{{< katex >}}
$$
\begin{equation*}
\text{maximize} \quad c^\mathrm{T} x \quad ,
\end{equation*}
$$
$$
\begin{equation*}
\text{subject to} \quad Ax \leq b \quad , \quad x \geq 0 \quad .
\end{equation*}
$$

By introducing slack variables \\(s\\), we derive an equivalent standard form:

$$
\begin{equation*}
\text{maximize} \quad c_1^\mathrm{T} x_1 \quad ,
\end{equation*}
$$
$$
\begin{equation*}
\text{subject to} \quad A_1x_1 = b_1 \quad , \quad x_1 \geq 0 \quad ,
\end{equation*}
$$

where

$$
\begin{equation*}
x_1 = \begin{pmatrix}x \\\\ s\end{pmatrix} \quad , \quad A_1 = \begin{bmatrix}A & 1\end{bmatrix} \quad , \quad b_1 = b \quad , \quad c_1 = \begin{pmatrix}c \\\\ 0\end{pmatrix} \quad ,
\end{equation*}
$$

By scaling constraints with -1, we derive a stricter standard form with a non-negative right-hand side \\(b_2\\):

$$
\begin{equation*}
\text{maximize} \quad c_2^\mathrm{T} x_2 \quad ,
\end{equation*}
$$
$$
\begin{equation*}
\text{subject to} \quad A_2x_2 = b_2 \quad , \quad x_2 \geq 0 \quad ,
\end{equation*}
$$

where

$$
\begin{equation*}
x_2 = x_1 \quad , \quad \left(A_2\right)_{i,j} = \mathrm{sgn}((b_1)_i) (A_1)_i \quad , \quad (b_2)_i = \left|(b_1)_i\right| \quad , \quad c_2 = c_1 \quad .
\end{equation*}
$$

The simplex method (see below) requires an initial feasible solution to solve the standard form of the linear program.
A solution is feasible if (i) it satisifies the constraints, and (ii) the number of non-zero entries in the solution vector is less or equal to the number of linearly independent constraints.
This raises the question of bootstrapping.
How do we find an initial feasible solution?
We iterate as follows:

1.  Solve a modified, canonical formulation with a trivial feasible solution. (phase one)
2.  Solve the original standard formulation with an initial feasible solution from the modified, canonical formulation. (phase two)
3.  Branch and bound as necessary, and repeat.

Let us follow this up with an example.
Using the notation from [last time](http://localhost:1313/notes/20260206-aoc-2025-10/#part-two-theory), we formulate part two of the Advent of Code puzzle as a linear program:

$$
\begin{equation*}
\text{minimize} \quad \sum_l{r_l} \quad ,
\end{equation*}
$$
$$
\begin{equation*}
\text{subject to} \quad \sum_l{\chi_{k,l} r_l} = j_k \quad , \quad r_l \geq 0 \quad .
\end{equation*}
$$

This is a standard form in summation notation.
In phase one, we relax the constraints, and introduce slack variables \\(s_k\\).
The objective is to make the slack variables vanish.

$$
\begin{equation*}
\text{minimize} \quad \sum_k{s_k} \quad ,
\end{equation*}
$$
$$
\begin{equation*}
\text{subject to} \quad \sum_l{\chi_{k,l} r_l} + s_k = j_k \quad , \quad r_l \geq 0 \quad , \quad s_k \geq 0 \quad .
\end{equation*}
$$

Trivially, an initial feasible solution is \\(r_l = 0\\) and \\(s_k = j_k\\).
The original standard formulation admits feasible solutions if and only if the relaxed, canonical formulation has an optimal solution with \\(s_k = 0\\).
For both phase one and two, we use the Simplex method to drive the initial feasible solution to an optimal solution, respectively.

## Simplex method

For the simplex method, we arrange the vectors and matrices of the standard form in a tableau:

$$
\begin{equation*}
\begin{vmatrix}
1 & -c_2^\mathrm{T} & 0 \\\\
0 & A_2 & b_2
\end{vmatrix} \quad .
\end{equation*}
$$

Given an initial feasible solution, we identify a set of pivot columns.
The number of pivot columns is equal to the number of linearly independent constraints.
Without loss of generality, we assume that the pivot columns make up the left-most columns of \\(A_2\\).
[Gauss elimination](#gauss-elimination) in the pivot columns yields the following tableau:

$$
\begin{equation*}
\begin{vmatrix}
1 & 0 & -c_0^\mathrm{T} & z_0 \\\\
0 & 1 & D & b_0
\end{vmatrix} \quad .
\end{equation*}
$$

The simplex method moves from one feasible solution to another, neighboring feasible solution without decreasing the objective \\(z\\).
A feasible solution is a neighbor to another feasible solution if they share all but one pivot columns.
This raises the question how to determine the columns that exit and enter the set of pivot columns, respectively.
We make the following observations regarding the choice of neighbor:

*   A positive entry in \\(c_0\\) means that a non-negative value in the corresponding solution vector \\(x\\) will not decrease the objective.
*   A neighboring solution is feasible if and only if the right-hand side \\(b\\) remains non-negative after Gauss elimination.

It follows:

1.  For the entering column, pick any column where the corresponding entry in \\(c_0\\) is positive.[^1]
2.  The choice of the exiting column fixes the constraint that directly determines the value of the entering variable.
    Thus, for the exiting column, do not pick a column where the corresponding entry in the entering column is non-positive.[^2]
3.  A negative entry in the entering column will not lead to a decrease in the corresponding entry on the right-hand side after elimination.
    A positive entry in the entering column will not lead to a decrease in the corresponding entry on the right-hand side if the ratio between the entry on the right-hand side and the entry on the left-hand side of the entering column is minimally positive.
    This criterion is necessary and sufficient, and is called the [minimum-ratio test](https://en.wikipedia.org/wiki/Simplex_algorithm#Leaving_variable_selection).[^3]

[^1]: If no such column exists, then the solution is already optimal.

[^2]: If all entries in the entering column are negative, then the linear program is unbounded.

[^3]: Note that our implementation of the minimum-ratio test does not involve the calculation of any ratios in order to avoid division.

```go
func Run[T constraints.Signed](
	t *Tableau[T],
	pivots []int,
) error {
	if len(pivots) != t.NoConstraints() {
		return fmt.Errorf("%w: %d, %d, %v.", ErrIncompatibleSizes, t.NoConstraints(), t.NoVariables(), pivots)
	}

	initializeTableau(t, pivots)

	for {
		varCt, ok := chooseEntering(t)
		if !ok {
			break
		}
		colCt := varCt + 1

		conCt, ok := chooseExiting(t, varCt)
		if !ok {
			return ErrUnboundedAbove
		}
		rowCt := conCt + 1

		if err := eliminateUp(t.mat, rowCt, colCt); err != nil {
			panic(err)
		}
		if err := eliminateDown(t.mat, rowCt, colCt); err != nil {
			panic(err)
		}
		pivots[conCt] = varCt
	}

	return nil
}

func initializeTableau[T constraints.Signed](
	t *Tableau[T],
	pivots []int,
) {
	noColumns := t.mat.NoColumns()

	for conCt, varCt := range pivots {
		rowCt := conCt + 1
		colCt := varCt + 1

		pivotColumn(t.mat, rowCt, colCt)

		if err := eliminateDown(t.mat, rowCt, colCt); err != nil {
			panic(err)
		}
	}

	for conCt, varCt := range pivots {
		rowCt := conCt + 1
		colCt := varCt + 1

		if err := eliminateUp(t.mat, rowCt, colCt); err != nil {
			panic(err)
		}
	}

	for conCt := range pivots {
		rowCt := conCt + 1

		if t.mat[rowCt][noColumns-1] < 0 {
			linalg.ScaleRow(t.mat, rowCt, -1)
		}
	}

	if t.mat[0][0] < 0 {
		linalg.ScaleRow(t.mat, 0, -1)
	}
}

func chooseEntering[T constraints.Signed](
	t *Tableau[T],
) (int, bool) {
	for varCt, varIt := range t.mat[0][1:1+t.NoVariables()] {
		if varIt < 0 {
			return varCt, true
		}
	}

	return 0, false
}

func chooseExiting[T constraints.Signed](
	t *Tableau[T],
	varIdx int,
) (int, bool) {
	colCt := varIdx + 1

	var res int
	var ok bool

	for conCt := range t.NoConstraints() {
		rowCt := conCt + 1

		if t.mat[rowCt][colCt] <= 0 {
			continue
		}

		if !ok {
			res = conCt
			ok = true
			continue
		}

		if checkMinimumRatio(t.mat, colCt, res+1, rowCt) {
			res = conCt
			ok = true
		}
	}

	return res, ok
}
```

## Branch and bound

The simplex method does not necessarily result in integer solutions.
If the optimal solution \\(\bar{x}\\) has a non-integer entry \\(\bar{x}_l\\), two branches are spawned:

1.  Solve the linear program with the additional constraint \\(x_l \leq \mathrm{floor}(\bar{x}_l)\\).
2.  Solve the linear program with the additional constraint \\(x_l \geq \mathrm{ceil}(\bar{x}_l)\\).

Any solution introduces a local upper bound with respect to its branches
Any branch with an integer solution introduces a global lower bound.
This means that a branch with a non-integer solution does not have to spawn if it introduces a local upper bound below the current, global lower bound.

```go
func SolveInteger[T constraints.Signed](
	problem *StandardForm[T],
) (*Solution[T], error) {
	var sol Solution[linalg.Scalar[T]]

	if err := solveIntegerRec(problem, &sol, 0); err != nil {
		return nil, err
	}

	x := linalg.NewVector[T](problem.NoVariables())

	for xCt, xIt := range sol.X {
		x[xCt] = xIt.ToInteger()
	}

	return &Solution[T]{
		Residual: sol.Residual.ToInteger(),
		Pivots: sol.Pivots,
		X: x,
	}, nil
}

func solveIntegerRec[T constraints.Signed](
	problem *StandardForm[T],
	best *Solution[linalg.Scalar[T]],
	level int,
) error {
	sol, err := Solve(problem)
	if errors.Is(err, ErrNoSolution) {
		return nil
	} else if err != nil {
		return err
	}

	if best != nil && sol.Residual.LessThan(best.Residual) {
		return nil
	}

	for varCt, varIt := range sol.X {
		if varIt.IsInteger() {
			continue
		}

		if err := solveIntegerRec(
			branchLeft(problem, varCt, varIt),
			best,
			level + 1,
		); err != nil {
			return err
		}

		if err := solveIntegerRec(
			branchRight(problem, varCt, varIt),
			best,
			level + 1,
		); err != nil {
			return err
		}

		return nil
	}

	pivots := make([]int, 0, len(sol.Pivots))

	for _, varCt := range sol.Pivots {
		if varCt >= problem.NoVariables() - level {
			continue
		}

		pivots = append(pivots, varCt)
	}

	*best = Solution[linalg.Scalar[T]]{
		X: sol.X[:problem.NoVariables()-level],
		Pivots: pivots,
		Residual: sol.Residual,
	}

	return nil
}

func branchLeft[T constraints.Signed](
	problem *StandardForm[T],
	varCt int,
	varIt linalg.Scalar[T],
) *StandardForm[T] {
	noConstraints := problem.NoConstraints()
	noVariables := problem.NoVariables()

	a := linalg.NewMatrix[T](noConstraints+1, noVariables+1)
	b := linalg.NewVector[T](noConstraints+1)
	c := linalg.NewVector[T](noVariables+1)

	for rowCt, rowIt := range problem.A {
		copy(a[rowCt], rowIt)
		b[rowCt] = problem.B[rowCt]
	}

	a[noConstraints][varCt] = 1
	a[noConstraints][noVariables] = 1
	b[noConstraints] = varIt.Floor()

	copy(c, problem.C)

	res, err := NewStandardForm(a, b, c)
	if err != nil {
		panic(err)
	}

	return res
}

func branchRight[T constraints.Signed](
	problem *StandardForm[T],
	varCt int,
	varIt linalg.Scalar[T],
) *StandardForm[T] {
	noConstraints := problem.NoConstraints()
	noVariables := problem.NoVariables()

	a := linalg.NewMatrix[T](noConstraints+1, noVariables+1)
	b := linalg.NewVector[T](noConstraints+1)
	c := linalg.NewVector[T](noVariables+1)

	for rowCt, rowIt := range problem.A {
		copy(a[rowCt], rowIt)
		b[rowCt] = problem.B[rowCt]
	}

	a[noConstraints][varCt] = 1
	a[noConstraints][noVariables] = -1
	b[noConstraints] = varIt.Ceil()

	copy(c, problem.C)

	res, err := NewStandardForm(a, b, c)
	if err != nil {
		panic(err)
	}

	return res
}
```

---

I hope that this gives you an idea as to why Advent of Code problems involving linear algebra solutions are somewhat unpopular.
The implementation is so much less pithy than the data structures and algorithms found in the regular computer science curriculum.
This makes it unattractive to implement solutions from scratch without external libraries.
For comparison, this [linear programming solution](https://gitlab.com/hyu/advent-of-code/-/tree/master/2025/golang-10-linopt) has triple the number of lines of code than the [Diophantine equations solution](https://gitlab.com/hyu/advent-of-code/-/tree/master/2025/golang-10) (excluding tests).

This said, this is also my longest write-up so far.
Actually, I enjoyed it a little because it refreshed my memory on some of the edge cases.
Revisiting my work from three months ago, I am even relatively pleased with the structure of my code.
I am now considering turning this into a separate, open-source project.
Developers who want to avoid the imprecision of floating-point arithmetics and look for a pure Go implementation will possibly find this project useful.
The use cases are small to medium-sized integer linear programs.
It would be my first Go library!
