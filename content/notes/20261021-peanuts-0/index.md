+++
date = '2026-10-21T22:17:01+02:00'
title = 'Foundations of analysis: Prelude'
tags = ['lean', 'math']
+++

{{< badge >}}lean{{< /badge >}} {{< badge >}}math{{< /badge >}}

Last week, I watched a [Numberphile interview](https://www.youtube.com/watch?v=bAnwMdfcMVw) with Terence Tao.
Probably, this is the most memorable quote:

>   We are seeing the end of the romantic era of mathematics, the age of heros.

Later, he refers to Isaiah Berlin and his distinction between [hedgehogs and foxes](https://en.wikipedia.org/wiki/The_Hedgehog_and_the_Fox).

>   A fox knows many things.
>   But a hedgehog knows one big thing.

Terence Tao states that he considers himself a fox, taking ideas from one field of mathematics and applying them to another.
This got me thinking:
Where do I stand, mathematically?
No worries, this is not going down a path of self-reflection.
I quickly found my answer (I am a hedgehog).
More interestingly, I was even able to pinpoint the earliest episode in my life to make my porcupine nature clear without a doubt.

This episode is about the first mathematical monograph that I read cover to cover.
Leading up to this episode was my first intellectual crisis.
After multiple years of maths club, I wanted to better understand the 'meta' mathematics behind the proofs to the puzzles that mini me was writing down with his fountain pen every week.
I had a mathematical handbook at home, that showed me the ropes of Boolean algebra and propositional logic.
This would have been enough for a secure footing to apply modus ponens, contraposition and contradiction.
However, instead of moving on, mini me was still stuck, and started wondering about the nature of the objects to which logical arguments are applied.
Moving past geometrical objects, I boiled the questions down to just numbers:
What is a natural number?
Do they really exist?
What do functions, operations and relations mean?

Somehow, I found the book that held the answers to my questions -- _Grundlagen der Analysis_, by Edmund Landau.
The _unforgiving telegram style_, as the author himself describes his own writing style, was a soothing antidote to those high school glossy-paper textbooks with their wishy-washy expositions.
Knowing nothing about hedgehogs, I reveled in the terse definitions, the wrestling with them to elicit the intuition behind them, and the wiggling only to eventually accept their unshakable perfection.
This set me on a happy path where I felt in full control of my intellectual destiny.
I would never rely on the teacher in front of me; textbooks were my ansible to the masters of the past.

However, there was one caveat.
Mathematical textbooks regularly come with exercises at the end of each chapter that are very much worth their while.
Unlike coding, there is no compiler, unit test or platform to provide feedback and close the loop.
Without a solution guide, proof attempts sometimes felt like feeble shouts into the void.

Fast forward, in the age of AI, human mathematicians are surpassed.
Machines produce proofs that are unintelligible at first but undeniable.
All this is powered by proof assistants like Lean.
On the one hand, I understand the sense of despair in the eyes of a fox.
Pessimists claim that AI does nothing more than form the convex hull of human knowledge.
Nevertheless, going back to Terence Tao's description of foxes, this is nonetheless original work!
Thus, machines and foxes are in direct competition now.
On the other hand, I am a hedgehog, and not a professional mathematician, either.
I am simply excited that I now have in Lean a companion to my mathematical self-study.

I would like to begin this path by revisiting the book with which everything started for me.
I am still learning Lean, and I want the formalization of _Grundlagen der Analysis_ to be my bachelor piece.
So far, I have studied the following materials:

*   [Functional programming in Lean](https://lean-lang.org/functional_programming_in_lean/).
*   [Theorem proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/).
*   [Natural number game](https://adam.math.hhu.de/).

Over the next weeks, I am going to share my experiences here.
Let the hedgehog games begin!
