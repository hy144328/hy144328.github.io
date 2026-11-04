+++
date = '2026-11-03T23:59:47+01:00'
title = 'Foundations of analysis in Lean, I: Natural numbers'
tags = ['lean', 'math']
+++

{{< badge >}}lean{{< /badge >}} {{< badge >}}math{{< /badge >}}

This is a first post of multiple posts to formalize _Grundlagen der Analysis_ by Edmund Landau in Lean.
Last time, I explained where my fascination with Lean comes from.
This time, I get to share some actual code.

{{< gitlab projectID="74673125" >}}

## Basics

Last time, I have already shared my recommendations for introduction material.
I would like to elaborate a little on the depth of my own studies to make it clear that this is _not_ going to be an advanced tutorial.

[Functional programming in Lean](https://lean-lang.org/functional_programming_in_lean/).
To be honest, I only skimmed through the chapters.
I have already got a little experience in functional programming from professionally working with Scala in a production environment.
I plan to return to it when leveraging more advanced features to make my Lean code more ergonomic.

[Theorem proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/).
I read the first five chapters up to _Tactics_ line-by-line, and did all the exercises there.
I even re-read those chapters multiple times.
But this is partially because I had to repeatedly restart the book after losing the thread because of distractions.
I read the second half more cursorily.
Although I am aware that topics such as inductive types and recursion are highly relevant to the axiomatic formulation of natural numbers, I think that I need more hands-on experience to appreciate the finer nuances.
I hope that I am going to build up this experience in the upcoming weeks in parallel to writing my notes.

{{< gitlab projectID="68706177" >}}

[Natural number game](https://adam.math.hhu.de/).
I knew about its existence, and that it comes with recommendations from many places.
However, as a [Berlinian hedgehog](../20261021-peanuts-0), I preferred to pore over the two aforementioned online textbooks.

In hindsight, I possibly learnt the most from working through term-style proofs and tactic-style proofs for the same theorems.
In my own words, term-style proofs are bottom-up.
You compose propositions from existing propositions until you arrive at the statement in question.
Tactic-style proofs are top-down.
You begin with the statement in question, and break it down to conquer next.
Currently, I tend to prefer term-style proofs.
I find them less magical, and easier to follow the logic step-by-step.
However, I am slowly but surely picking up the ropes of tactic-style proofs.
I find them especially useful with more complex arguments because they preserve the structure better.
For example, I usually use tactics if the induction principle forms the backbone of the proof.
It is needless to say that the induction principle is going to feature quite prominently this time.

## Peano axioms

Landau introduces natural numbers from five axioms:

1.  There is a natural number `one`.
2.  For each natural number, there is exactly one natural number, also known as the successor.
3.  There is no natural number with successor `one`.
4.  If two natural numbers have equal successors, then the two natural numbers are equal, too.
5.  The following two properties combined are sufficient for a proposition to apply to all natural numbers:

    *   The proposition applies to `one`.
    *   If the proposition applies to a natural number, then it also applies to its successor.

My formalization in Lean looks as follows:

```lean
structure Natural where
  carrier: Type

  one: carrier
  succ (x: carrier): carrier
  one_not_succ {x: carrier}: succ x ≠ one
  succ_injective {x y: carrier}: succ x = succ y → x = y
  induction_principle {p: carrier → Prop}: (p one) → ({n: carrier} → p n → p (succ n)) → ∀ x, p x
```

It is a pretty straightforward translation from natural to mathematical language.
`Natural` introduces (i) `carrier`, the set of natural numbers, (ii) `one`, a special element in the natural numbers, and (iii) `succ`, the successor function.
Note that the remaining axioms make use of [implicit arguments](https://lean-lang.org/theorem_proving_in_lean4/Dependent-Type-Theory/#implicit-arguments), i.e. function arguments surrounded by curly braces.
Similar to contextual parameters in Scala, it is a thin line between ergonomics and obfuscation.
Nevertheless, this endeavour made me appreciate the importance of succint notation.

Before I began to streamline for ergonomics, I had explicitly formalized two more concepts that I am now taking for granted.
Firstly, instead of the built-in equality relation, `Natural` relied on its own equivalence relation for propositional equality.
In order to instantiate `Natural`, it was necessary to pass an instance of [`Equivalence`](https://lean-lang.org/doc/reference/latest/The-Type-System/Quotients/#Equivalence___mk) including proofs for reflexivity `refl`, symmetry `symm` and transitivity `trans`.
Unfortunately, equivalence unlike equality does not automatically enable substitution.
Thus, I would have to explicitly state congruence for every newly introduced operation, e.g. addition, order, multiplication.
Alternatively, universal substitutivity would come close to [Leibniz' notion of identity](https://en.wikipedia.org/wiki/Identity_of_indiscernibles), and amount to the same as the built-in equality relation.
Therefore, I decided to drop the pretense of an equivalence relation, and went with the built-in equality relation.
Secondly, `Natural` introduced a successor relation instead of a function.
The idea was to replace the definition of a successor function in the second axiom with [statements](https://en.wikipedia.org/wiki/Binary_relation#Types_of_binary_relations) about left-totality and univalence of a successor relation.
I dropped the idea, too, because every proposition about successors would require the introduction of a symbol representing the successor as well as a proof for the successor relationship.
At the same time, Lean apparently has no built-in way to assign a name to an object whose existence and uniqueness have been proven.

Outside the definition of `Natural`, it is convenient to conflate the notions of `Natural` and `Natural.carrier`.
Hence, I wrote a snippet of code, which does exactly that:

```lean
instance: CoeSort Natural Type where
  coe N := N.carrier
```

To demonstrate all of the above, this is what the first two theorems formalized in Lean look like:

```lean
variable {N: Natural}
variable {x y z: N}

theorem satz_001: x ≠ y → N.succ x ≠ N.succ y :=
  fun hxy_neq =>
  fun hxpyp_eq =>
    absurd (N.succ_injective hxpyp_eq) hxy_neq

theorem satz_002: N.succ x ≠ x := by
  revert x
  apply @N.induction_principle
  . exact N.one_not_succ
  . exact satz_001
```

The first theorem `satz_001` has a term-style proof.
The second theorem `satz_002`, which relies on the induction principle, applies `Natural.induction_principle` as a tactic.
I find the `revert` statement ugly.
And I do not fully understand why `Natural.induction_principle` requires the `@` sign.
Once it is there, however, Lean is able to derive the implicit argument `p`.
But overall, I am pleased with the presentation of the proofs.

## Alternatives considered: axiomatic versus structural definitions

`Natural` is defined as an [algebraic structure](https://lean-lang.org/theorem_proving_in_lean4/Inductive-Types/#inductive-types).
We declare a variable `N` as an instance of `Natural`, which shows up in virtually every proposition via `x`, `y`, `z`.
But we never prove that such an instance of `Natural` actually exists.

Alternatively, there exists a textbook [structural definition](https://lean-lang.org/theorem_proving_in_lean4/Inductive-Types/#defining-the-natural-numbers) of the natural numbers:

```lean
inductive PNat where
  | one: PNat
  | succ: PNat → PNat
```

Note that this definition is recursive in nature because the second constructor `succ` acts on elements of the type defined.
It is then straightforward to prove that `PNat` is consistent with `Natural`:

```lean
example: Natural := {
  carrier := PNat,

  one := PNat.one,
  succ := PNat.succ,
  one_not_succ := PNat.noConfusion,
  succ_injective := fun hcd => by
    injection hcd,
  induction_principle := fun h1 hn x => by
    induction x with
    | one => exact h1
    | succ _ ih => exact hn ih,
}
```

In my humble opinion, building on top of `PNat` instead of `Natural` would go against the spirit of the book.
For instance, both `one_not_succ` and `succ_injective` rely on a definitional interpretation of equality via `noConfusion` and `injection`.
Whereas, the axiomatic approach by Landau treats equality in a propositional sense.
Last but not least, the structural definition would turn all axioms into theorems.
The hedgehog inside me wants to build on top of the abstraction, not tied to any particular construction.
