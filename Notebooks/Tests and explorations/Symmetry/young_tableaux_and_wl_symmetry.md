# Young Tableaux and the Built-in Symmetry of Wolfram Language

A Young tableau in the paclet's `` Wolfram`TensorNetworks`Symmetry` `` subcontext is best read as a compact *label* that the kernel expands into machinery the Wolfram Language already ships: an integer partition, a conjugacy class and irreducible representation of the symmetric group, a group-algebra element assembled from permutations and their signatures, and finally a call to `Symmetrize` with `Symmetric` and `Antisymmetric` specifications. This note builds each of those bridges explicitly, so that after working through it you can translate any `YoungTableau` into the corresponding `IntegerPartitions`, `SymmetricGroup`, `Permutations`, `Symmetrize`, and `TensorSymmetry` calls and back again. We start from the shape and its diagram, walk through the group theory one built-in at a time, and finish by reading a symmetrized tensor back into the language's own symmetry vocabulary.

## Loading the symmetry subcontext

The Young-tableau symbols live in a subcontext of the TensorNetworks paclet, so we load the paclet and pull both contexts into scope. Every later cell assumes these three lines have run.

```wl
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];
```

## A shape is an integer partition

The shape of a Young diagram of size $n$ is exactly a partition $\lambda \vdash n$: a weakly decreasing list of positive integers summing to $n$, which `IntegerPartitions[n]` enumerates and the paclet's `PartitionQ` validates. For $n = 4$ this returns the five shapes $\{4\}, \{3,1\}, \{2,2\}, \{2,1,1\}, \{1,1,1,1\}$, and feeding each to `YoungTableau` turns the bare partition into a labeled diagram. Mapping the constructor over the partition list is the cleanest way to see the correspondence "one partition, one diagram".

```wl
YoungTableau /@ IntegerPartitions[4]
```

## Drawing the diagram

Core Wolfram Language has no built-in Young-diagram object (the old `Combinatorica` had one, long since retired), so the paclet supplies the picture itself: `YoungTableau` carries a `MakeBoxes` rule that draws the boxes with `Graphics`, `Rectangle`, and `Text`. The summary box also reports a `Filling` label computed at display time: `Canonical` for the row-reading default $1,2,\ldots,n$, `Standard` for any other strictly increasing filling (a genuine standard Young tableau, the case `StandardTableauQ` accepts), and `Explicit` for a labeling whose rows or columns are not strictly increasing. Render one of each to see all three labels on the same shape.

```wl
{YoungTableau[{3, 2, 1}],
 YoungTableau[{{1, 2, 4}, {3, 5}}],
 YoungTableau[{{5, 1, 3}, {2, 4}}]}
```

## One shape per conjugacy class

The reason there are exactly as many diagram shapes as irreducible representations is a chain of equalities the language lets us check directly: partitions of $n$ are the same data as cycle types of permutations, and cycle types index the conjugacy classes of $S_n$, which (for any finite group) are equal in number to the irreducible representations. Taking every element of `Permutations[Range[n]]`, reading its cycle type with `PermutationCycles`, and discarding duplicates must reproduce `IntegerPartitions[n]` exactly. The padding with ones restores the fixed points that `PermutationCycles` omits.

```wl
cycleType[p_] := With[{c = Length /@ First[PermutationCycles[p], {}]},
   ReverseSort @ Join[c, ConstantArray[1, Length[p] - Total[c]]]];
{Sort @ DeleteDuplicates[cycleType /@ Permutations[Range[4]]],
 Sort @ IntegerPartitions[4]}
```

## Size n and the symmetric group

A tableau of size $n$ acts on the $n$ tensor slots that the symmetric group $S_n$ permutes, so `TableauSize` and `SymmetricGroup` are two views of the same $n$. The order of that group is $n!$, returned by `GroupOrder[SymmetricGroup[n]]`, and this is the normalizing constant behind every projector below. Read the size of a $\{3,2\}$ tableau and the order of its group side by side.

```wl
{TableauSize[YoungTableau[{3, 2}]], GroupOrder[SymmetricGroup[5]]}
```

## A shape names an irreducible representation

Each partition $\lambda \vdash n$ labels one irreducible representation $V_\lambda$ of $S_n$, whose dimension `TableauDimension` computes from the hook-length formula. These dimensions are not independent: summing their squares over all shapes of size $n$ recovers the group order, the Plancherel identity

$$\sum_{\lambda \,\vdash\, n} (\dim V_\lambda)^2 \;=\; n! \;=\; |S_n|.$$

For $n = 4$ the dimensions are $\{1,3,2,3,1\}$ and their squares sum to $24 = 4!$.

```wl
{TableauDimension /@ IntegerPartitions[4],
 Total[(TableauDimension /@ IntegerPartitions[4])^2],
 4!}
```

## A permutation acts on tensor slots

To turn a permutation into an operation on a tensor we permute its index slots, which is precisely what `Transpose[T, perm]` does when `perm` is given as an image list. The sign that distinguishes symmetrization from antisymmetrization is `Signature[perm]`, which is $+1$ for an even permutation and $-1$ for an odd one. Here the swap $\{2,1\}$ exchanges the two slots of a matrix (giving the ordinary transpose), and the two signatures show an odd transposition against an even 3-cycle.

```wl
With[{T = Array[a, {2, 2}]},
 {Transpose[T, {2, 1}], Signature[{2, 1}], Signature[{2, 3, 1}]}]
```

## Row and column groups are Young subgroups

The Young symmetrizer is built from two subgroups of $S_n$: the row stabilizer, which permutes slots within each row, and the column stabilizer, which permutes within each column. Each is a direct product of smaller symmetric groups (a *Young subgroup*), so its order is the product of the row or column factorials, equal to a product of `GroupOrder[SymmetricGroup[...]]`. The helpers below enumerate such a subgroup as explicit image-list permutations, taking the blocks from `TableauRows` or `TableauColumns`; for the $\{3,2\}$ rows the order is $3!\,2! = 12$.

```wl
fullPerm[blocks_, choice_] :=
  Values @ KeySort @ Association @ Thread[Flatten[blocks] -> Flatten[choice]];
stabilizer[blocks_] := fullPerm[blocks, #] & /@ Tuples[Permutations /@ blocks];
{Length @ stabilizer[{{1, 2, 3}, {4, 5}}],
 GroupOrder[SymmetricGroup[3]] GroupOrder[SymmetricGroup[2]]}
```

## The Young symmetrizer from Permutations and Signature

The Young symmetrizer is the group-algebra element $c_T = a_T\, b_T$, where $b_T$ sums over the row stabilizer and $a_T$ sums over the column stabilizer weighted by `Signature`. Acting on a tensor, the kernel applies $b_T$ first and $a_T$ second, so assembling the two sums by hand from `Transpose` and `Signature` must reproduce `YoungSymmetrize` bit for bit. For the simplest case $T = \{\{1,2\}\}$ the column group is trivial and $c_T = e + (1\,2)$, giving $c_T\cdot T = T + T^\top$; the cell below checks the general nontrivial $\{3,2\}$ tableau on an exact-integer tensor.

```wl
ct[T_, rows_] := With[
   {bT = Total[Transpose[T, #] & /@ stabilizer[rows]]},
   Total[Signature[#] Transpose[bT, #] & /@
      stabilizer[TableauColumns[YoungTableau[rows]]]]];
SeedRandom[42];
Tn = RandomInteger[{-3, 3}, {2, 2, 2, 2, 2}];
ct[Tn, {{1, 2, 3}, {4, 5}}] == YoungSymmetrize[Tn, YoungTableau[{{1, 2, 3}, {4, 5}}]]
```

## The built-in shortcut: Symmetrize, Symmetric, Antisymmetric

Rather than enumerate $n!$ permutations, the paclet delegates to the language's own `Symmetrize`, passing `Symmetric /@ rows` for the row pass and `Antisymmetric /@ cols` for the column pass. Because `Symmetrize` averages over the group, a single-row tableau reproduces a fully symmetric projector and a single-column tableau a fully antisymmetric one, with `YoungProject` matching `Normal @ Symmetrize` exactly. The two checks below confirm the symmetric and antisymmetric cases on a rank-2 tensor.

```wl
With[{T = Array[a, {3, 3}]},
 {YoungProject[T, YoungTableau[{2}]]    === Normal @ Symmetrize[T, Symmetric[{1, 2}]],
  YoungProject[T, YoungTableau[{1, 1}]] === Normal @ Symmetrize[T, Antisymmetric[{1, 2}]]}]
```

## SymmetrizedArray: the sparse carrier

`Symmetrize` does not return a dense array; it returns a `SymmetrizedArray` that stores only the independent components together with the symmetry that regenerates the rest. The paclet calls `Normal` on it to hand an ordinary array back to tensor contraction, which is why `YoungSymmetrize` ends in `Normal @ Symmetrize[...]`. Inspect the head and its dense form for an antisymmetric rank-2 tensor.

```wl
sa = Symmetrize[Array[a, {3, 3}], Antisymmetric[{1, 2}]];
{Head[sa], Normal[sa]}
```

## Reading the symmetry back: TensorSymmetry

The loop closes with `TensorSymmetry`, which inspects a concrete array and reports the symmetry it actually has. A symmetric projection reads back as `Symmetric[{1,2}]` and an antisymmetric one as `Antisymmetric[{1,2}]`, so the paclet produces tensors the language can re-recognize. For a mixed $\{2,1\}$ shape `TensorSymmetry` returns only `Antisymmetric[{1,3}]`, the column antisymmetry that survives as the last operation; the full irreducible "mixed" symmetry is exactly the structure the tableau encodes beyond what a single pairwise label can name.

```wl
TensorSymmetry /@ {
   YoungProject[Array[a, {3, 3}], YoungTableau[{2}]],
   YoungProject[Array[a, {3, 3}], YoungTableau[{1, 1}]],
   YoungProject[Array[a, {3, 3, 3}], YoungTableau[{2, 1}]]}
```

## Counting independent components: SchurDimension

The number of independent components of a tensor forced into a given symmetry class is a representation dimension, and for the pure symmetric and antisymmetric classes the language counts it directly with `SymmetrizedIndependentComponents`. That count matches the paclet's `SchurDimension[lambda, d]`, the hook-content dimension of the $\mathrm{GL}(d)$ module: $\binom{d+n-1}{n}$ for the symmetric shape $\{n\}$ and $\binom{d}{n}$ for the antisymmetric shape $\{1^n\}$. The table sweeps $d = 2,3,4$ for rank-3 tensors and shows both columns agreeing (the antisymmetric count is $0$ at $d=2$, the Pauli-exclusion vanishing).

```wl
Table[{d,
   Length @ SymmetrizedIndependentComponents[{d, d, d}, Symmetric[{1, 2, 3}]],
   SchurDimension[{3}, d],
   Length @ SymmetrizedIndependentComponents[{d, d, d}, Antisymmetric[{1, 2, 3}]],
   SchurDimension[{1, 1, 1}, d]},
  {d, 2, 4}]
```

## Conjugate shapes and the sign representation

Transposing a Young diagram (swapping its rows and columns) is the `TransposePartition` operation, and representation-theoretically it tensors the $S_n$ irrep with the sign representation, trading symmetrization for antisymmetrization. The extreme case makes this vivid: the fully symmetric shape $\{n\}$ and the fully antisymmetric shape $\{1^n\}$ are conjugates, differing in the symmetrizer only by the `Signature` factor on each permutation. Here the two extremes map to each other, and the signatures of an even and an odd permutation are the values that distinguish them.

```wl
{TransposePartition[{3}], TransposePartition[{1, 1, 1}],
 Signature[{2, 3, 1}], Signature[{2, 1, 3}]}
```

## Where this leaves us

A `YoungTableau` is a label that the paclet unfolds into objects the Wolfram Language already understands. The chain we built and verified runs in one direction, partition to projected tensor, and is readable in the other:

- The shape comes from `IntegerPartitions` and is validated by `PartitionQ`; there are as many shapes as conjugacy classes (cycle types) of `SymmetricGroup[n]`.
- The size is the $n$ of $S_n$, with `GroupOrder` giving $n!$, the normalizer in every projector, and `TableauDimension` satisfying the Plancherel sum $\sum_\lambda (\dim V_\lambda)^2 = n!$.
- The Young symmetrizer is a `Permutations`-plus-`Signature` element of the group algebra, which the paclet evaluates through `Symmetrize` with `Symmetric` and `Antisymmetric` and returns via `Normal` of a `SymmetrizedArray`.
- The result is legible to `TensorSymmetry`, and its independent-component count matches `SchurDimension` and `SymmetrizedIndependentComponents`.

The capstone runs the whole pipeline in one line: take the partition $\{2,1\}$, build its tableau, project a tensor with `YoungProject`, and read the symmetry back with the language's own `TensorSymmetry`.

```wl
TensorSymmetry @ YoungProject[Array[a, {3, 3, 3}], YoungTableau[First @ Rest @ IntegerPartitions[3]]]
```
