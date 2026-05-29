# TensorNetworks Symmetry Subcontext: Young Tableaux

## Overview

The `` Wolfram`TensorNetworks`Symmetry` `` subcontext provides Young tableaux and the tensor symmetry operations built on them. A Young tableau encodes a symmetry type for the slots of a tensor with `n` indices; from it the module computes representation-theoretic dimensions (symmetric group and `GL(d)`) and applies the corresponding Young symmetrizer or normalized projector to a numeric or symbolic array.

Files in this directory:

| File | Role |
|------|------|
| `Symmetry.wl` | Subpackage loader (`Package["Wolfram`TensorNetworks`Symmetry`"]`). |
| `YoungTableaux.wl` | Implementation of all exported symbols. |
| `Usage.wl` | `::usage` strings for the exported symbols. |

A related but separate symbol, `ArraySymmetry`, lives in the `IndexArray` subcontext, not here.

All examples below were evaluated against the current kernel; the values shown in `(* ... *)` comments are the actual returns.

---

## Exported symbols

| Group | Symbols |
|-------|---------|
| Construction and predicates | `YoungTableau`, `YoungTableauQ`, `StandardTableauQ`, `PartitionQ` |
| Shape and structure | `TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`, `TransposePartition` |
| Hook lengths and dimensions | `HookLength`, `HookLengths`, `HookFactor`, `TableauDimension`, `SchurDimension`, `TableauWeylDimension` |
| Tensor operations | `YoungSymmetrize`, `YoungProject` |

---

## Conventions

**Two constructor forms.** `YoungTableau[partition]` takes a partition (a non-increasing list of positive integers) and auto-fills the boxes with `1, 2, ..., n` in reading order. `YoungTableau[rows]` takes an explicit list of rows of slot indices. The two agree when the explicit rows are the canonical reading-order filling.

```mathematica
YoungTableau[{3, 2}] === YoungTableau[{{1, 2, 3}, {4, 5}}]   (* True  *)
YoungTableau[{2, 1}] === YoungTableau[{{1, 2}, {3}}]         (* True  *)
```

**Slot-diagram model: row order is meaningful.** A `YoungTableau` is a labeled diagram, not only a standard tableau. The order of entries within a row defines the column sets, hence the Young symmetrizer, so a reordered row layout is a legitimate but *different* object with a *different* projector.

```mathematica
TableauColumns[YoungTableau[{{1, 2, 3}, {4, 5}}]]   (* {{1, 4}, {2, 5}, {3}} *)
TableauColumns[YoungTableau[{{1, 2, 3}, {5, 4}}]]   (* {{1, 5}, {2, 4}, {3}} *)
(* The two tableaux give different YoungSymmetrize results. *)
```

**`YoungTableauQ` is structural; `StandardTableauQ` is strict.** `YoungTableauQ` checks only that the shape is a partition and that the entries are exactly `1..n` used once each. It does *not* require the strict row/column increase of a standard Young tableau (SYT); that is what `StandardTableauQ` adds.

**Filling label in the summary box.** When a `YoungTableau` renders, its summary box reports a `Filling` of `Canonical` (the reading-order default `1..n`, which is always standard), `Standard` (a different strictly increasing SYT), or `Explicit` (rows or columns not strictly increasing). The label is computed from content at display time and does not change the stored object.

**Constructor validation.** Malformed input is rejected at construction with a message and `$Failed`, so you rarely hold an invalid `YoungTableau`. A bad partition triggers `YoungTableau::notpar`; a bad row layout triggers `YoungTableau::notslot`.

```mathematica
YoungTableau[{1, 2}]          (* $Failed, YoungTableau::notpar  (not non-increasing) *)
YoungTableau[{{1}, {2, 3}}]   (* $Failed, YoungTableau::notslot (row lengths increase) *)
YoungTableau[{{1, 2}, {2, 3}}](* $Failed, YoungTableau::notslot (entry 2 repeats)     *)
```

---

## Function reference

### Construction and predicates

#### `YoungTableau`

Creates a Young tableau. `YoungTableau[partition]` auto-fills the canonical reading-order tableau; `YoungTableau[rows]` stores an explicit slot layout. Renders as a summary box showing shape, filling, and dimension.

```mathematica
TableauRows[YoungTableau[{4, 2, 1}]]   (* {{1, 2, 3, 4}, {5, 6}, {7}} *)
TableauRows[YoungTableau[{3, 2, 1}]]   (* {{1, 2, 3}, {4, 5}, {6}}    *)
YoungTableauQ[YoungTableau[{{1, 3, 5}, {2, 4}}]]   (* True: valid non-canonical layout *)
```

#### `YoungTableauQ`

Tests whether an expression is a valid `YoungTableau` (partition shape, entries `1..n` once each). Structural only; non-tableau input returns `False` without a message.

```mathematica
YoungTableauQ[YoungTableau[{{1, 2, 3}, {4, 5}}]]   (* True  *)
YoungTableauQ[YoungTableau[{{5, 1, 3}, {2, 4}}]]   (* True: valid, though not an SYT *)
YoungTableauQ["not a tableau"]                     (* False *)
YoungTableauQ[42]                                  (* False *)
YoungTableauQ[{{1, 2, 3}, {4, 5}}]                 (* False: not wrapped in YoungTableau *)
```

#### `StandardTableauQ`

Tests the standard Young tableau property: rows and columns strictly increasing. Requires `YoungTableauQ` to pass first; any non-tableau input returns `False`.

```mathematica
StandardTableauQ[YoungTableau[{3, 2, 1}]]          (* True: canonical filling  *)
StandardTableauQ[YoungTableau[{{1, 2, 4}, {3, 5}}]](* True: non-canonical SYT   *)
StandardTableauQ[YoungTableau[{{5, 1, 3}, {2, 4}}]](* False: row not increasing *)
StandardTableauQ[YoungTableau[{{1, 4}, {2, 3}}]]   (* False: column not increasing *)
StandardTableauQ[{{1, 2}, {3}}]                    (* False: not a YoungTableau *)
```

#### `PartitionQ`

Tests whether a list is a valid integer partition: a non-empty list of positive integers in non-increasing order.

```mathematica
PartitionQ /@ {{3, 2, 1}, {3, 3, 1}, {1}, {1, 2, 3}, {3, 0, 1}, {-1, 1}, {3, 5/2, 1}, {}}
(* {True, True, True, False, False, False, False, False} *)
```

---

### Shape and structure

#### `TableauShape`

Returns the partition (list of row lengths). Accepts only a `YoungTableau`; other input gives `$Failed` with `TableauShape::noyt`.

```mathematica
TableauShape[YoungTableau[{{1, 2, 3}, {4, 5}}]]   (* {3, 2}    *)
TableauShape[YoungTableau[{4, 2, 1}]]             (* {4, 2, 1} *)
TableauShape[{{1, 2}, {3}}]                       (* $Failed, TableauShape::noyt *)
```

#### `TableauSize`

Returns the total number of boxes `n` (the sum of the row lengths), which is the tensor rank the tableau acts on and the `n` of the symmetric group `S_n`. Accepts only a `YoungTableau`.

```mathematica
TableauSize[YoungTableau[{{1, 2, 3}, {4, 5}}]]   (* 5 *)
TableauSize[YoungTableau[{4, 2, 1}]]             (* 7 *)
TableauSize[YoungTableau[{3, 2, 1}]]             (* 6 *)
```

#### `TableauRows`

Returns the inner row list as a list of lists of slot indices. `YoungTableau` is atomic, so this accessor (not `First` or `Part`) is how you read the rows. Accepts only a `YoungTableau`.

```mathematica
TableauRows[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]]   (* {{1, 2, 3}, {4, 5}, {6}} *)
TableauRows[YoungTableau[{4, 2, 1}]]                  (* {{1, 2, 3, 4}, {5, 6}, {7}} *)
```

#### `TableauColumns`

Derives the column slot lists from the row layout, stopping each column correctly on ragged shapes. Accepts only a `YoungTableau`.

```mathematica
TableauColumns[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]]   (* {{1, 4, 6}, {2, 5}, {3}} *)
TableauColumns[YoungTableau[{4, 2, 1}]]                  (* {{1, 5, 7}, {2, 6}, {3}, {4}} *)
TableauColumns[YoungTableau[{{5, 6, 7}, {3, 4}, {1, 2}}]](* {{5, 3, 1}, {6, 4, 2}, {7}} *)
```

#### `TransposePartition`

Returns the conjugate (transpose) of an integer partition: swapping rows and columns of the diagram. An involution that preserves the weight `Total`.

```mathematica
TransposePartition /@ {{4, 2, 1}, {3, 2, 2, 1}, {5}, {1, 1, 1}, {3, 3}}
(* {{3, 2, 1, 1}, {4, 3, 1}, {1, 1, 1, 1, 1}, {3}, {2, 2, 2}} *)
TransposePartition[TransposePartition[{4, 2, 1}]]   (* {4, 2, 1} : involution *)
TransposePartition["x"]                             (* $Failed, TransposePartition::notpar *)
```

The conjugate of the fully symmetric shape `{n}` is the fully antisymmetric shape `{1, ..., 1}`, and vice versa; representation-theoretically conjugation tensors the `S_n` irrep with the sign representation.

---

### Hook lengths and dimensions

#### `HookLength`

`HookLength[tableau, {row, col}]` is the hook length at one cell: cells to the right in the same row, plus cells below in the same column, plus one. Out-of-range cells give `$Failed` with `HookLength::range`; non-tableau input gives `HookLength::noyt`.

```mathematica
HookLength[YoungTableau[{3, 2}], #] & /@ {{1, 1}, {1, 2}, {1, 3}, {2, 1}, {2, 2}}
(* {4, 3, 1, 2, 1} *)
HookLength[YoungTableau[{4, 2, 1}], #] & /@ {{1, 1}, {2, 1}, {3, 1}}   (* {6, 3, 1} *)
HookLength[YoungTableau[{3, 2}], {5, 5}]   (* $Failed, HookLength::range *)
```

#### `HookLengths`

Returns all hook lengths at once as a nested list matching the shape. Accepts a partition or a `YoungTableau`; bad input gives `HookLengths::notpar`.

```mathematica
HookLengths[{3, 2}]                 (* {{4, 3, 1}, {2, 1}}    product 24, dim 120/24 = 5 *)
HookLengths[{4, 2}]                 (* {{5, 4, 2, 1}, {2, 1}} product 80, dim 720/80 = 9 *)
HookLengths[{2, 2, 1}]              (* {{4, 2}, {3, 1}, {1}}  product 24, dim 120/24 = 5 *)
HookLengths[YoungTableau[{3, 2}]]   (* {{4, 3, 1}, {2, 1}} : tableau overload *)
```

#### `HookFactor`

Returns `1 / (product of hook lengths)` evaluated by the Frobenius determinant formula, which is `O(r^3)` in the number of rows. Accepts a partition or a `YoungTableau`. The irrep dimension is `n! * HookFactor[partition]`.

```mathematica
HookFactor[{3, 2}]              (* 1/24 *)
HookFactor[{2, 2}]              (* 1/12 *)
Total[{3, 2}]! HookFactor[{3, 2}]   (* 5 : equals TableauDimension[{3,2}] *)
(* n! HookFactor[p] === TableauDimension[p] for every partition of 1..6 : True *)
```

#### `TableauDimension`

The dimension `dim V_lambda` of the irreducible representation of the symmetric group labeled by the shape, via the hook-length formula `d = n! / (product of hook lengths)`. Accepts a partition or a `YoungTableau`.

```mathematica
TableauDimension /@ {{3}, {1, 1, 1}, {2, 1}, {3, 2}, {4, 2, 1}, {2, 2}, {3, 2, 1}, {3, 1, 1}, {1}}
(* {1, 1, 2, 5, 35, 2, 16, 6, 1} *)
TableauDimension /@ IntegerPartitions[4]   (* {1, 3, 2, 3, 1} *)
(* Plancherel sum rule: *)
Total[(TableauDimension /@ IntegerPartitions[5])^2]   (* 120 == 5! *)
```

#### `SchurDimension`

`SchurDimension[partition, d]` is the dimension `dim W_lambda(d)` of the `GL(d)` Weyl module via Stanley's hook-content formula `prod (d + j - i) / hook(i, j)`. Accepts a partition or a `YoungTableau`; accepts numeric or symbolic `d`.

```mathematica
{SchurDimension[{3}, 2], SchurDimension[{2, 1}, 2], SchurDimension[{1, 1, 1}, 2],
 SchurDimension[{1, 1, 1}, 3], SchurDimension[{4, 2}, 3]}
(* {4, 2, 0, 1, 27} *)
```

The fully symmetric shape gives `Binomial[d + n - 1, n]` and the fully antisymmetric shape gives `Binomial[d, n]`. A shape with more rows than `d` vanishes (Pauli exclusion), as `SchurDimension[{1,1,1}, 2] == 0` above. Symbolic `d` returns a polynomial:

```mathematica
Simplify[SchurDimension[{2, 2}, x] - x^2 (x^2 - 1)/12]   (* 0 *)
```

Together with `TableauDimension` it satisfies the Schur-Weyl identity `Sum_{lambda |- n} dim V_lambda * dim W_lambda(d) == d^n` (verified for `n = 2..5`, `d = 2..4`).

#### `TableauWeylDimension`

The tableau-keyed companion to `SchurDimension`: `TableauWeylDimension[tableau, d]` is the `GL(d)` Weyl-module dimension for the partition underlying the tableau. Unlike `SchurDimension`, it accepts only a `YoungTableau`; a bare partition gives `$Failed` with `TableauWeylDimension::noyt`.

```mathematica
TableauWeylDimension[YoungTableau[{2, 2}], 3]   (* 6 : equals SchurDimension[{2,2},3] *)
TableauWeylDimension[{2, 2}, 3]                 (* $Failed, TableauWeylDimension::noyt *)
```

While `TableauDimension[tab]` gives the `S_n` multiplicity `dim V_lambda`, `TableauWeylDimension[tab, d]` gives the block size `dim W_lambda(d)`; their product is the size of the lambda-isotypic block of `(C^d)^(tensor n)`.

---

### Tensor operations

#### `YoungSymmetrize`

`YoungSymmetrize[tensor, tableau]` applies the unnormalized Young symmetrizer `c_T = a_T b_T`: it first symmetrizes over each row, then antisymmetrizes over each column. The tensor rank (`ArrayDepth`) must equal `TableauSize`; otherwise it returns `$Failed` with `YoungSymmetrize::rank`. Internally it delegates to the kernel's `Symmetrize` with `Symmetric /@ rows` and `Antisymmetric /@ cols`, scaled by the row and column stabilizer orders.

A single-row tableau is full symmetrization; a single-column tableau is full antisymmetrization.

```mathematica
YoungSymmetrize[{{a, b}, {c, d}}, YoungTableau[{2}]]     (* {{2 a, b + c}, {b + c, 2 d}} *)
YoungSymmetrize[{{1, 2}, {3, 4}}, YoungTableau[{2}]]     (* {{2, 5}, {5, 8}} *)
YoungSymmetrize[{{a, b}, {c, d}}, YoungTableau[{1, 1}]]  (* {{0, b - c}, {-b + c, 0}} *)
YoungSymmetrize[{{1, 2}, {3, 4}}, YoungTableau[{1, 1}]]  (* {{0, -1}, {1, 0}} *)
```

The operations are sequential, so the *last* one (column antisymmetry) is always preserved while the first (row symmetry) is generally destroyed. The mixed shape `{2, 1}` produces a tensor in the irreducible mixed-symmetry subspace, not a simply symmetric or antisymmetric one.

```mathematica
m = YoungSymmetrize[Array[t, {3, 3, 3}], YoungTableau[{2, 1}]];
{m === -Transpose[m, {3, 2, 1}],   (* True:  column antisymmetry preserved *)
 m === Transpose[m, {2, 1, 3}]}    (* False: row symmetry not preserved   *)
```

A rank-2 tensor splits into its symmetric and antisymmetric parts (the `n = 2` Schur-Weyl decomposition):

```mathematica
M = {{1, 2}, {3, 4}};
YoungSymmetrize[M, YoungTableau[{2}]]/2 + YoungSymmetrize[M, YoungTableau[{1, 1}]]/2 === M   (* True *)
```

#### `YoungProject`

`YoungProject[tensor, tableau]` is the normalized projection `(d / n!) * YoungSymmetrize[tensor, tableau]`, where `d = TableauDimension` and `n = TableauSize`. The normalization makes it idempotent (`P[P[T]] == P[T]`), so it is a genuine projector onto the tableau's symmetry class.

```mathematica
YoungProject[{{a, b}, {c, d}}, YoungTableau[{2}]]     (* {{a, (b + c)/2}, {(b + c)/2, d}} *)
YoungProject[{{a, b}, {c, d}}, YoungTableau[{1, 1}]]  (* {{0, (b - c)/2}, {(-b + c)/2, 0}} *)
```

For rank 2 the symmetric and antisymmetric projectors are complete (`P_sym + P_anti == identity`), and the normalization factors `d / n!` are small rationals:

```mathematica
T = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
YoungProject[T, YoungTableau[{{1, 2}}]] + YoungProject[T, YoungTableau[{{1}, {2}}]] === T   (* True *)

{TableauDimension[{2, 1}]/3!, TableauDimension[{2, 2}]/4!,
 TableauDimension[{3, 1}]/4!, TableauDimension[{5}]/5!}      (* {1/3, 1/12, 1/8, 1/120} *)
```

For the pure symmetric and antisymmetric shapes, `YoungProject` agrees with the kernel's own `Symmetrize` (which averages over the group):

```mathematica
YoungProject[Array[a, {3, 3}], YoungTableau[{2}]] ===
  Normal @ Symmetrize[Array[a, {3, 3}], Symmetric[{1, 2}]]   (* True *)
```

---

## Mathematical background

**Young diagram and partition.** A partition `lambda = {lambda_1, ..., lambda_k}` of `n` (non-increasing positive integers summing to `n`) is drawn as `k` left-justified rows of boxes. Shape `{3, 2}`:

```
+---+---+---+
| 1 | 2 | 3 |
+---+---+---+
| 4 | 5 |
+---+---+
```

**Young symmetrizer.** For a tableau `T`, the symmetrizer is `c_T = a_T b_T`, where `b_T` sums over the row stabilizer (symmetrizing rows) and `a_T` sums over the column stabilizer with signatures (antisymmetrizing columns). Applying `b_T` first and `a_T` second ensures the column antisymmetry survives in the result.

**Hook-length formula.** The hook length at cell `(i, j)` is `hook(i, j) = (lambda_i - j) + (lambda^T_j - i) + 1`. The symmetric-group irrep dimension is `dim V_lambda = n! / prod hook(i, j)`, evaluated here through `HookFactor` (Frobenius determinant).

**Hook-content formula.** The `GL(d)` Weyl-module dimension is `dim W_lambda(d) = prod (d + j - i) / hook(i, j)`, returned by `SchurDimension`.

**Schur-Weyl duality.** The space `(C^d)^(tensor n)` decomposes as a `GL(d) x S_n` bimodule into `direct sum over lambda of W_lambda(d) tensor V_lambda`, so `d^n = Sum_lambda dim W_lambda(d) * dim V_lambda`. The Plancherel special case at the level of `S_n` is `Sum_{lambda |- n} (dim V_lambda)^2 = n!`.

---

## Quick reference

| Function | Purpose | Example -> result |
|----------|---------|-------------------|
| `PartitionQ[list]` | Validate an integer partition | `PartitionQ[{3,1}]` -> `True` |
| `YoungTableau[part]` | Build canonical tableau from partition | `YoungTableau[{3,2}]` |
| `YoungTableau[rows]` | Build tableau from explicit slot rows | `YoungTableau[{{1,3},{2}}]` |
| `YoungTableauQ[expr]` | Structural tableau test | `YoungTableauQ[tab]` -> `True` |
| `StandardTableauQ[tab]` | Strict-increase (SYT) test | `StandardTableauQ[tab]` -> `True` |
| `TableauShape[tab]` | Partition (row lengths) | `TableauShape[tab]` -> `{3,2}` |
| `TableauSize[tab]` | Number of boxes `n` | `TableauSize[tab]` -> `5` |
| `TableauRows[tab]` | Inner row list | `TableauRows[tab]` -> `{{1,2,3},{4,5}}` |
| `TableauColumns[tab]` | Column slot lists | `TableauColumns[tab]` -> `{{1,4},{2,5},{3}}` |
| `TransposePartition[part]` | Conjugate partition | `TransposePartition[{4,2,1}]` -> `{3,2,1,1}` |
| `HookLength[tab,{r,c}]` | Hook length at one cell | `HookLength[tab,{1,1}]` -> `4` |
| `HookLengths[part]` | All hook lengths | `HookLengths[{3,2}]` -> `{{4,3,1},{2,1}}` |
| `HookFactor[part]` | `1 / prod(hooks)` | `HookFactor[{3,2}]` -> `1/24` |
| `TableauDimension[part]` | `S_n` irrep dimension | `TableauDimension[{3,2}]` -> `5` |
| `SchurDimension[part,d]` | `GL(d)` Weyl-module dimension | `SchurDimension[{4,2},3]` -> `27` |
| `TableauWeylDimension[tab,d]` | `GL(d)` dimension (tableau form) | `TableauWeylDimension[tab,3]` -> `6` |
| `YoungSymmetrize[T,tab]` | Unnormalized symmetrizer `c_T` | `YoungSymmetrize[T,tab]` |
| `YoungProject[T,tab]` | Normalized projector `P_T` | `YoungProject[T,tab]` |

---

## Further reading

Tutorials and notes that build on this subcontext:

- `TensorNetworks/Documentation/English/Tutorials/YoungSymmetries.nb`
- `TensorNetworks/Documentation/English/Tutorials/SymmetrySubcontextTutorial.nb`
- `Notebooks/Tests and explorations/Symmetry/young_tableaux.md` (physics applications: decoherence-free subspaces, Schur sampling, symmetric tensor networks)
- `Notebooks/Tests and explorations/Symmetry/young_tableaux_and_wl_symmetry.md` (how these symbols relate to the built-in `IntegerPartitions`, `SymmetricGroup`, `Permutations`, `Symmetrize`, and `TensorSymmetry`)

Reference pages for each symbol live under `TensorNetworks/Documentation/English/ReferencePages/Symbols/`.
