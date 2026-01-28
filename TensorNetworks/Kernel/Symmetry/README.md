# TensorNetworks Symmetry Functions - Complete Usage Guide & Test Plan

## Overview

The TensorNetworks Wolfram Language package provides symmetry operations via **Young tableaux** - mathematical objects that encode tensor symmetry properties. The symmetry module is located in:
- [YoungTableaux.wl](YoungTableaux.wl) - Main implementation
- [AUsage.wl](AUsage.wl) - Usage documentation
- [ArrayUtilities.wl](../IndexArray/ArrayUtilities.wl) - Array symmetry utilities

---

## Function Reference

### 1. `YoungTableau` - Constructor

**Purpose:** Creates a Young tableau data structure that defines tensor index symmetry properties.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `YoungTableau[{{i1,i2,...}, {j1,j2,...}, ...}]` | Explicit row specification - each sublist is a row of slot indices |
| `YoungTableau[{d1, d2, d3, ...}]` | Partition specification - creates standard tableau with `d1 >= d2 >= d3 >= ...` |

**Validation Rules:**
- Row lengths must be non-increasing (partition condition)
- All entries must be distinct positive integers
- All integers from 1 to n must appear exactly once (standard tableau)

**Examples (10+):**

```mathematica
(* Example 1: Simple partition - fully symmetric (1 row) *)
YoungTableau[{3}]
(* Creates: YoungTableau[{{1,2,3}}] - Shape {3}, Dimension 1 *)

(* Example 2: Simple partition - fully antisymmetric (1 column) *)
YoungTableau[{1,1,1}]
(* Creates: YoungTableau[{{1},{2},{3}}] - Shape {1,1,1}, Dimension 1 *)

(* Example 3: Mixed symmetry partition *)
YoungTableau[{2,1}]
(* Creates: YoungTableau[{{1,2},{3}}] - Shape {2,1}, Dimension 2 *)

(* Example 4: Explicit row specification *)
YoungTableau[{{1,2,3},{4,5}}]
(* Shape {3,2}, Dimension 5 *)

(* Example 5: Custom slot ordering *)
YoungTableau[{{1,3,5},{2,4}}]
(* Shape {3,2}, Dimension 5 - indices 1,3,5 symmetrized; 2,4 symmetrized *)

(* Example 6: Three-row tableau *)
YoungTableau[{4,2,1}]
(* Creates: YoungTableau[{{1,2,3,4},{5,6},{7}}] - Shape {4,2,1}, Dimension 35 *)

(* Example 7: Square tableau *)
YoungTableau[{2,2}]
(* Creates: YoungTableau[{{1,2},{3,4}}] - Shape {2,2}, Dimension 2 *)

(* Example 8: Large fully symmetric *)
YoungTableau[{5}]
(* Creates: YoungTableau[{{1,2,3,4,5}}] - Shape {5}, Dimension 1 *)

(* Example 9: Hook-shaped tableau *)
YoungTableau[{3,1,1}]
(* Shape {3,1,1}, Dimension 6 *)

(* Example 10: Staircase tableau *)
YoungTableau[{3,2,1}]
(* Creates: YoungTableau[{{1,2,3},{4,5},{6}}] - Shape {3,2,1}, Dimension 16 *)

(* Example 11: Explicit non-standard filling *)
YoungTableau[{{5,6,7},{3,4},{1,2}}]
(* Same shape {3,2,2} but with custom index assignment *)

(* Example 12: Single box *)
YoungTableau[{1}]
(* Creates: YoungTableau[{{1}}] - Shape {1}, Dimension 1 (trivial) *)
```

---

### 2. `YoungTableauQ` - Validation Predicate

**Purpose:** Tests whether an expression is a valid Young tableau.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `YoungTableauQ[expr]` | Returns `True` if expr is a valid YoungTableau, `False` otherwise |

**Validation Checks:**
- All rows are lists
- At least one row with at least one element
- Row lengths are non-increasing
- All entries are distinct positive integers

**Examples (10+):**

```mathematica
(* Example 1: Valid tableau from partition *)
YoungTableauQ[YoungTableau[{3,2}]]
(* Returns: True *)

(* Example 2: Valid explicit tableau *)
YoungTableauQ[YoungTableau[{{1,2},{3}}]]
(* Returns: True *)

(* Example 3: Invalid - increasing row lengths *)
YoungTableauQ[YoungTableau[{{1},{2,3}}]]
(* Returns: False - row 2 longer than row 1 *)

(* Example 4: Invalid - duplicate entries *)
YoungTableauQ[YoungTableau[{{1,2},{2,3}}]]
(* Returns: False - 2 appears twice *)

(* Example 5: Invalid - non-positive integer *)
YoungTableauQ[YoungTableau[{{0,1},{2}}]]
(* Returns: False - 0 is not positive *)

(* Example 6: Invalid - non-integer *)
YoungTableauQ[YoungTableau[{{1.5,2},{3}}]]
(* Returns: False - 1.5 is not an integer *)

(* Example 7: Not a tableau at all *)
YoungTableauQ["not a tableau"]
(* Returns: False *)

(* Example 8: Empty rows invalid *)
YoungTableauQ[YoungTableau[{{},{1}}]]
(* Returns: False - empty row *)

(* Example 9: Valid single element *)
YoungTableauQ[YoungTableau[{{1}}]]
(* Returns: True *)

(* Example 10: Valid large tableau *)
YoungTableauQ[YoungTableau[{5,4,3,2,1}]]
(* Returns: True *)

(* Example 11: Invalid - negative integer *)
YoungTableauQ[YoungTableau[{{-1,2},{3}}]]
(* Returns: False *)

(* Example 12: Valid custom filling *)
YoungTableauQ[YoungTableau[{{3,5,7},{1,2}}]]
(* Returns: True - distinct positive integers, non-increasing rows *)
```

---

### 3. `TableauShape` - Get Partition Shape

**Purpose:** Returns the shape (partition) of a Young tableau as a list of row lengths.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `TableauShape[YoungTableau[rows]]` | Returns `{d1, d2, ...}` where di is length of row i |

**Note:** `TableauShape` only accepts `YoungTableau` as input. Passing other types returns `$Failed` with an error message.

**Examples (10+):**

```mathematica
(* Example 1: Two-row tableau *)
TableauShape[YoungTableau[{{1,2,3},{4,5}}]]
(* Returns: {3, 2} *)

(* Example 2: From partition input *)
TableauShape[YoungTableau[{4,2,1}]]
(* Returns: {4, 2, 1} *)

(* Example 3: Single row (symmetric) *)
TableauShape[YoungTableau[{5}]]
(* Returns: {5} *)

(* Example 4: Single column (antisymmetric) *)
TableauShape[YoungTableau[{1,1,1,1}]]
(* Returns: {1, 1, 1, 1} *)

(* Example 5: Square shape *)
TableauShape[YoungTableau[{3,3,3}]]
(* Returns: {3, 3, 3} *)

(* Example 6: Custom slot assignment *)
TableauShape[YoungTableau[{{1,3,5},{2,4}}]]
(* Returns: {3, 2} - shape independent of slot values *)

(* Example 7: Single box *)
TableauShape[YoungTableau[{1}]]
(* Returns: {1} *)

(* Example 8: Staircase *)
TableauShape[YoungTableau[{4,3,2,1}]]
(* Returns: {4, 3, 2, 1} *)

(* Example 9: Error case - raw list input rejected *)
TableauShape[{{1,2},{3}}]
(* Returns: $Failed with message: "TableauShape accepts only YoungTableau as input" *)

(* Example 10: Two equal rows *)
TableauShape[YoungTableau[{2,2}]]
(* Returns: {2, 2} *)

(* Example 11: Large tableau *)
TableauShape[YoungTableau[{6,4,4,2,1}]]
(* Returns: {6, 4, 4, 2, 1} *)
```

---

### 4. `TableauSize` - Get Total Number of Boxes

**Purpose:** Returns the total number of boxes (size/weight) of a Young tableau. This equals the sum of the partition elements.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `TableauSize[YoungTableau[rows]]` | Returns the total number of boxes n |

**Note:** `TableauSize` only accepts `YoungTableau` as input. Passing other types returns `$Failed` with an error message.

**Examples (10+):**

```mathematica
(* Example 1: Two-row tableau *)
TableauSize[YoungTableau[{{1,2,3},{4,5}}]]
(* Returns: 5 *)

(* Example 2: From partition input *)
TableauSize[YoungTableau[{4,2,1}]]
(* Returns: 7 *)

(* Example 3: Single row (symmetric) *)
TableauSize[YoungTableau[{5}]]
(* Returns: 5 *)

(* Example 4: Single column (antisymmetric) *)
TableauSize[YoungTableau[{1,1,1,1}]]
(* Returns: 4 *)

(* Example 5: Square shape *)
TableauSize[YoungTableau[{3,3,3}]]
(* Returns: 9 *)

(* Example 6: Custom slot assignment *)
TableauSize[YoungTableau[{{1,3,5},{2,4}}]]
(* Returns: 5 *)

(* Example 7: Single box *)
TableauSize[YoungTableau[{1}]]
(* Returns: 1 *)

(* Example 8: Staircase *)
TableauSize[YoungTableau[{4,3,2,1}]]
(* Returns: 10 *)

(* Example 9: Error case - raw list input rejected *)
TableauSize[{{1,2},{3}}]
(* Returns: $Failed with message: "TableauSize accepts only YoungTableau as input" *)

(* Example 10: Two equal rows *)
TableauSize[YoungTableau[{2,2}]]
(* Returns: 4 *)

(* Example 11: Large tableau *)
TableauSize[YoungTableau[{6,4,4,2,1}]]
(* Returns: 17 *)

(* Example 12: Relates to symmetric group *)
(* TableauSize[tab] = n means the tableau relates to S_n *)
TableauSize[YoungTableau[{3,2,1}]]
(* Returns: 6 - relates to S_6 *)
```

---

### 5. `HookLength` - Compute Hook Length at Position

**Purpose:** Computes the hook length at a specific cell position. Used in the hook-length formula for irrep dimensions.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `HookLength[YoungTableau[rows], {row, col}]` | Hook length at position (row, col) |

**Note:** `HookLength` only accepts `YoungTableau` as input. Passing other types returns `$Failed` with an error message.

**Formula:** `hook(r,c) = (cells to right in row r) + (cells below in column c) + 1`

**Examples (10+):**

```mathematica
(* Setup tableau: YoungTableau[{3,2}] = {{1,2,3},{4,5}} *)
tab = YoungTableau[{3,2}];

(* Example 1: Top-left corner *)
HookLength[tab, {1,1}]
(* Returns: 4 (2 right + 1 below + 1 = 4) *)

(* Example 2: Position {1,2} *)
HookLength[tab, {1,2}]
(* Returns: 3 (1 right + 1 below + 1 = 3) *)

(* Example 3: Position {1,3} - corner *)
HookLength[tab, {1,3}]
(* Returns: 1 (0 right + 0 below + 1 = 1) *)

(* Example 4: Position {2,1} *)
HookLength[tab, {2,1}]
(* Returns: 2 (1 right + 0 below + 1 = 2) *)

(* Example 5: Position {2,2} - corner *)
HookLength[tab, {2,2}]
(* Returns: 1 *)

(* Example 6: Larger tableau {4,2,1} *)
tab2 = YoungTableau[{4,2,1}];
HookLength[tab2, {1,1}]
(* Returns: 6 (3 right + 2 below + 1 = 6) *)

(* Example 7: Hook at {2,1} in {4,2,1} *)
HookLength[tab2, {2,1}]
(* Returns: 3 (1 right + 1 below + 1 = 3) *)

(* Example 8: Hook at {3,1} in {4,2,1} *)
HookLength[tab2, {3,1}]
(* Returns: 1 *)

(* Example 9: Square tableau {2,2} *)
tab3 = YoungTableau[{2,2}];
HookLength[tab3, {1,1}]
(* Returns: 3 (1 right + 1 below + 1 = 3) *)

(* Example 10: Error case - raw list input rejected *)
HookLength[{{1,2,3},{4,5}}, {1,1}]
(* Returns: $Failed with message: "HookLength accepts only YoungTableau as input" *)

(* Example 11: Single row tableau *)
HookLength[YoungTableau[{4}], {1,2}]
(* Returns: 3 (2 right + 0 below + 1 = 3) *)

(* Example 12: Single column *)
HookLength[YoungTableau[{1,1,1}], {2,1}]
(* Returns: 2 (0 right + 1 below + 1 = 2) *)
```

---

### 6. `TableauDimension` - Irrep Dimension via Hook-Length Formula

**Purpose:** Computes the dimension of the irreducible representation corresponding to a Young tableau.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `TableauDimension[YoungTableau[rows]]` | Dimension using hook-length formula |

**Note:** `TableauDimension` only accepts `YoungTableau` as input. Passing other types returns `$Failed` with an error message.

**Formula:** `d = n! / Product[HookLength[tab,{r,c}], all cells]`

**Examples (10+):**

```mathematica
(* Example 1: Fully symmetric - single row *)
TableauDimension[YoungTableau[{3}]]
(* Returns: 1 (3!/6 = 1) - trivial symmetric representation *)

(* Example 2: Fully antisymmetric - single column *)
TableauDimension[YoungTableau[{1,1,1}]]
(* Returns: 1 (3!/6 = 1) - trivial antisymmetric representation *)

(* Example 3: Mixed symmetry {2,1} *)
TableauDimension[YoungTableau[{2,1}]]
(* Returns: 2 (3!/(3*1*1) = 6/3 = 2) *)

(* Example 4: Shape {3,2} *)
TableauDimension[YoungTableau[{3,2}]]
(* Returns: 5 (5!/(4*3*1*2*1) = 120/24 = 5) *)

(* Example 5: Shape {4,2,1} *)
TableauDimension[YoungTableau[{4,2,1}]]
(* Returns: 35 *)

(* Example 6: Square {2,2} *)
TableauDimension[YoungTableau[{2,2}]]
(* Returns: 2 (4!/(3*2*2*1) = 24/12 = 2) *)

(* Example 7: Large symmetric *)
TableauDimension[YoungTableau[{6}]]
(* Returns: 1 *)

(* Example 8: Staircase {3,2,1} *)
TableauDimension[YoungTableau[{3,2,1}]]
(* Returns: 16 *)

(* Example 9: Hook shape {3,1,1} *)
TableauDimension[YoungTableau[{3,1,1}]]
(* Returns: 6 *)

(* Example 10: Error case - raw list input rejected *)
TableauDimension[{{1,2},{3}}]
(* Returns: $Failed with message: "TableauDimension accepts only YoungTableau as input" *)

(* Example 11: Single box (trivial) *)
TableauDimension[YoungTableau[{1}]]
(* Returns: 1 *)

(* Example 12: Two boxes {2} vs {1,1} *)
TableauDimension[YoungTableau[{2}]]   (* Returns: 1 - symmetric *)
TableauDimension[YoungTableau[{1,1}]] (* Returns: 1 - antisymmetric *)
```

---

### 7. `YoungSymmetrize` - Tensor Symmetrization

**Purpose:** Projects a tensor onto the symmetry class defined by a Young tableau. First symmetrizes over rows, then antisymmetrizes over columns.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `YoungSymmetrize[tensor, YoungTableau[rows]]` | Apply Young symmetrizer to tensor |

**Requirements:**
- `tensor` must be an array (`ArrayQ` returns True)
- `ArrayDepth[tensor]` must equal total number of boxes in tableau (use `TableauSize`)

**Algorithm:**
1. Symmetrize over each row (operator b_T) - sum over all permutations
2. Then antisymmetrize over each column (operator a_T) - sum with signature

**Critical:** Operations are applied **sequentially**. The **last operation** (column antisymmetry) is **always preserved**. Earlier operations (row symmetry) may be **destroyed** by subsequent operations.

**Understanding Symmetry:**
- **Symmetric tensor**: `T[i,j] == T[j,i]` for all i,j. Verify: `T == Transpose[T]`
- **Antisymmetric tensor**: `T[i,j] == -T[j,i]` for all i,j. Verify: `T == -Transpose[T]`
- Antisymmetric tensors have zero diagonal: `T[i,i] == 0`
- **Mixed symmetry**: Result lies in an irreducible representation subspace. Only column antisymmetry is guaranteed; row symmetry is generally destroyed.

**Examples (10+):**

```mathematica
(* ============================================ *)
(* SYMMETRIC TENSORS: YoungTableau[{n}]         *)
(* Single row = fully symmetric over all indices *)
(* ============================================ *)

(* Example 1: Symmetrize a rank-2 tensor *)
(* YoungTableau[{2}] = single row with 2 boxes = symmetric in indices {1,2} *)
T = {{a, b}, {c, d}};
sym = YoungSymmetrize[T, YoungTableau[{2}]];
(* Result: {{2a, b+c}, {b+c, 2d}} *)

(* VERIFY: Symmetric means T == Transpose[T] *)
sym == Transpose[sym]
(* Returns: True *)

(* Example 2: Symmetrize numerical matrix *)
M = {{1, 2}, {3, 4}};
symM = YoungSymmetrize[M, YoungTableau[{2}]];
(* Result: {{2, 5}, {5, 8}} *)

(* VERIFY symmetry *)
symM == Transpose[symM]
(* Returns: True *)

(* Example 3: Already symmetric tensor is scaled by 2! = 2 *)
symTensor = {{1, 2}, {2, 4}};  (* symmetric: symTensor == Transpose[symTensor] *)
YoungSymmetrize[symTensor, YoungTableau[{2}]]
(* Result: {{2, 4}, {4, 8}} = 2 * symTensor *)
(* Factor of 2 comes from summing over 2! = 2 permutations *)


(* ============================================ *)
(* ANTISYMMETRIC TENSORS: YoungTableau[{1,1,...}] *)
(* Single column = fully antisymmetric            *)
(* ============================================ *)

(* Example 4: Antisymmetrize a rank-2 tensor *)
(* YoungTableau[{1,1}] = single column = antisymmetric in indices {1,2} *)
T = {{a, b}, {c, d}};
anti = YoungSymmetrize[T, YoungTableau[{1,1}]];
(* Result: {{0, b-c}, {c-b, 0}} *)

(* VERIFY: Antisymmetric means T == -Transpose[T] *)
anti == -Transpose[anti]
(* Returns: True *)

(* VERIFY: Diagonal is always zero for antisymmetric *)
Diagonal[anti]
(* Returns: {0, 0} *)

(* Example 5: Antisymmetrize numerical matrix *)
M = {{1, 2}, {3, 4}};
antiM = YoungSymmetrize[M, YoungTableau[{1,1}]];
(* Result: {{0, -1}, {1, 0}} *)

(* VERIFY antisymmetry *)
antiM == -Transpose[antiM]
(* Returns: True *)

(* Example 6: Already antisymmetric tensor is scaled by 2! = 2 *)
antiTensor = {{0, 1}, {-1, 0}};  (* antisymmetric *)
YoungSymmetrize[antiTensor, YoungTableau[{1,1}]]
(* Result: {{0, 2}, {-2, 0}} = 2 * antiTensor *)


(* ============================================ *)
(* RANK-3 TENSORS: More complex symmetries      *)
(* ============================================ *)

(* Example 7: Fully symmetric rank-3 tensor *)
(* YoungTableau[{3}] = symmetric in all 3 indices *)
T3 = Array[t, {2, 2, 2}];
sym3 = YoungSymmetrize[T3, YoungTableau[{3}]];

(* VERIFY: Symmetric under ANY transposition *)
sym3 == Transpose[sym3, {2, 1, 3}]  (* swap indices 1,2 *)
(* Returns: True *)
sym3 == Transpose[sym3, {1, 3, 2}]  (* swap indices 2,3 *)
(* Returns: True *)
sym3 == Transpose[sym3, {3, 2, 1}]  (* swap indices 1,3 *)
(* Returns: True *)

(* Example 8: Fully antisymmetric rank-3 tensor *)
(* YoungTableau[{1,1,1}] = antisymmetric in all 3 indices *)
T3 = Array[t, {2, 2, 2}];
anti3 = YoungSymmetrize[T3, YoungTableau[{1,1,1}]];

(* VERIFY: Antisymmetric under ANY transposition *)
anti3 == -Transpose[anti3, {2, 1, 3}]  (* swap indices 1,2 *)
(* Returns: True *)
anti3 == -Transpose[anti3, {1, 3, 2}]  (* swap indices 2,3 *)
(* Returns: True *)

(* Note: Fully antisymmetric rank-3 tensor in dimension 2 is zero! *)
(* (Can't have 3 antisymmetric indices with only 2 values each) *)


(* ============================================ *)
(* MIXED SYMMETRY: YoungTableau[{2,1}]          *)
(* ============================================ *)

(* IMPORTANT: Understanding the algorithm order:

   The Young symmetrizer c_T = a_T * b_T applies operations SEQUENTIALLY:
   1. FIRST: Symmetrize over rows (b_T)
   2. SECOND: Antisymmetrize over columns (a_T)

   KEY INSIGHT: The LAST operation (column antisymmetry) IS preserved.
                The FIRST operation (row symmetry) may be DESTROYED by the second!

   The result lies in an IRREDUCIBLE REPRESENTATION subspace - a "mixed symmetry"
   that is more complex than simple pairwise symmetry/antisymmetry.
*)

(* Example 9: Mixed symmetry {2,1} on rank-3 tensor *)
(* YoungTableau[{2,1}] = {{1,2},{3}}
   - Rows: {1,2} and {3}
   - Columns: {1,3} and {2}

   Algorithm:
   Step 1: Symmetrize over {1,2} -> intermediate result symmetric in 1,2
   Step 2: Antisymmetrize over {1,3} -> DESTROYS symmetry in 1,2!
*)
T3 = Array[t, {3, 3, 3}];
mixed = YoungSymmetrize[T3, YoungTableau[{2,1}]];

(* VERIFY: Column antisymmetry IS preserved (last operation) *)
mixed == -Transpose[mixed, {3, 2, 1}]
(* Returns: True *)

(* VERIFY: Row symmetry is NOT preserved! *)
mixed == Transpose[mixed, {2, 1, 3}]
(* Returns: False (or unevaluated - they are NOT equal) *)

(* The result satisfies a more complex "mixed symmetry" condition.
   It lies in the irreducible representation labeled by partition {2,1}. *)


(* Example 10: Custom index assignment - DETAILED ANALYSIS *)
(* YoungTableau[{{1,3},{2}}] means:
   - Rows: {1,3} and {2}
   - Columns: {1,2} and {3}

   Algorithm:
   Step 1: Symmetrize over {1,3} -> T + Transpose[T,{3,2,1}]
   Step 2: Antisymmetrize over {1,2} -> result - Transpose[result,{2,1,3}]
*)
T3 = Array[t, {2, 2, 2}];
custom = YoungSymmetrize[T3, YoungTableau[{{1,3},{2}}]];

(* VERIFY: Column antisymmetry in {1,2} IS preserved (last operation) *)
custom == -Transpose[custom, {2, 1, 3}]
(* Returns: True *)

(* VERIFY: Row symmetry in {1,3} is NOT preserved! *)
custom == Transpose[custom, {3, 2, 1}]
(* Returns: False - the antisymmetrization step destroyed it *)

(* Let's see what we actually get: *)
custom
(* The tensor has "mixed symmetry" - antisymmetric in {1,2} but NOT
   simply symmetric in {1,3}. It belongs to the irreducible subspace
   characterized by the Young tableau shape {2,1}. *)


(* Example 10b: Verify with explicit calculation *)
T = Array[t, {2, 2, 2}];
result = YoungSymmetrize[T, YoungTableau[{{1,3},{2}}]];

(* Check antisymmetry in indices 1,2 *)
Simplify[result + Transpose[result, {2, 1, 3}]]
(* Returns: zero tensor - confirms antisymmetry *)

(* Check symmetry in indices 1,3 *)
Simplify[result - Transpose[result, {3, 2, 1}]]
(* Returns: NON-zero - confirms symmetry is NOT preserved *)


(* ============================================ *)
(* WHAT MIXED SYMMETRY ACTUALLY MEANS           *)
(* ============================================ *)

(* For a {2,1} tableau, the result satisfies these properties:
   1. Antisymmetric in column indices (ALWAYS preserved - last operation)
   2. Satisfies a CYCLIC IDENTITY (not simple symmetry)

   For {{1,2},{3}}: T[i,j,k] + T[j,k,i] + T[k,i,j] = 0  (when also antisym in 1,3)
*)

(* Example 10c: The standard {2,1} tableau *)
T3 = Array[t, {3, 3, 3}];
std21 = YoungSymmetrize[T3, YoungTableau[{2,1}]];  (* = {{1,2},{3}} *)

(* Column antisymmetry: swap 1 and 3 *)
std21 == -Transpose[std21, {3, 2, 1}]
(* Returns: True *)

(* NOT symmetric in 1,2 (row symmetry destroyed): *)
std21 == Transpose[std21, {2, 1, 3}]
(* Returns: False *)

(* But satisfies: the cyclic sum vanishes *)
(* std21 + cycle(std21) + cycle(cycle(std21)) involves the irrep structure *)


(* ============================================ *)
(* ADDITIONAL EXAMPLES                          *)
(* ============================================ *)

(* Example 11: Identity on rank-1 (vectors have no symmetry to impose) *)
vector = {a, b, c};
YoungSymmetrize[vector, YoungTableau[{1}]]
(* Returns: {a, b, c} - unchanged *)

(* Example 12: Error case - rank mismatch *)
T2 = Array[t, {3, 3}];
YoungSymmetrize[T2, YoungTableau[{3}]]
(* Returns $Failed with message: "Tensor rank 2 does not match tableau size 3." *)

(* Example 13: Numerical verification of symmetry *)
M = RandomReal[{-1, 1}, {3, 3}];
symM = YoungSymmetrize[M, YoungTableau[{2}]];
Norm[symM - Transpose[symM]] < 10^-10
(* Returns: True - confirms numerical symmetry *)

antiM = YoungSymmetrize[M, YoungTableau[{1,1}]];
Norm[antiM + Transpose[antiM]] < 10^-10
(* Returns: True - confirms numerical antisymmetry *)

(* Example 14: Decomposition - any matrix = symmetric + antisymmetric *)
M = {{1, 2}, {3, 4}};
symPart = YoungSymmetrize[M, YoungTableau[{2}]] / 2;    (* {{1, 5/2}, {5/2, 4}} *)
antiPart = YoungSymmetrize[M, YoungTableau[{1,1}]] / 2; (* {{0, -1/2}, {1/2, 0}} *)
symPart + antiPart == M
(* Returns: True *)
```

---

### 8. `YoungProject` - Normalized Projection

**Purpose:** Returns the normalized projection of a tensor onto a Young tableau symmetry class. The result is idempotent: applying twice gives the same result.

**Input Patterns:**

| Pattern | Description |
|---------|-------------|
| `YoungProject[tensor, YoungTableau[rows]]` | Normalized projection: `(d/n!) * YoungSymmetrize[tensor, tab]` |

**Normalization:**
- Factor: `d/n!` where `d = TableauDimension[tab]` and `n = number of boxes`
- This makes the projector idempotent: `P[P[T]] = P[T]`

**Examples (10+):**

```mathematica
(* Example 1: Project onto symmetric subspace *)
tensor2 = Array[T, {3, 3}];
YoungProject[tensor2, YoungTableau[{2}]]
(* Normalized: (1/2!) * (T + T^T) = (T + T^T)/2 *)

(* Example 2: Project onto antisymmetric subspace *)
YoungProject[tensor2, YoungTableau[{1,1}]]
(* Normalized: (1/2!) * (T - T^T) = (T - T^T)/2 *)

(* Example 3: Mixed symmetry projection *)
tensor3 = Array[T, {2, 2, 2}];
YoungProject[tensor3, YoungTableau[{2,1}]]
(* Factor: 2/3! = 1/3 *)

(* Example 4: Verify idempotence numerically *)
numTensor = RandomReal[{-1, 1}, {2, 2, 2}];
proj1 = YoungProject[numTensor, YoungTableau[{2,1}]];
proj2 = YoungProject[proj1, YoungTableau[{2,1}]];
(* proj1 == proj2 should be True (within numerical precision) *)

(* Example 5: Project numerical tensor *)
numT = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
YoungProject[numT, YoungTableau[{2,1}]]

(* Example 6: Symmetric projection is average *)
sym = {{a, b}, {c, d}};
YoungProject[sym, YoungTableau[{2}]]
(* Returns: {{a, (b+c)/2}, {(b+c)/2, d}} *)

(* Example 7: Rank-4 mixed symmetry *)
tensor4 = Array[T, {2, 2, 2, 2}];
YoungProject[tensor4, YoungTableau[{2,2}]]
(* Factor: 2/4! = 1/12 *)

(* Example 8: Hook symmetry projection *)
YoungProject[tensor4, YoungTableau[{3,1}]]
(* Factor: 3/4! = 1/8 *)

(* Example 9: Fully symmetric large tensor *)
tensor5 = Array[T, {2, 2, 2, 2, 2}];
YoungProject[tensor5, YoungTableau[{5}]]
(* Factor: 1/5! = 1/120 *)

(* Example 10: Verify orthogonal projections *)
(* Different tableaux project onto orthogonal subspaces *)
t3 = RandomReal[{-1, 1}, {3, 3, 3}];
p1 = YoungProject[t3, YoungTableau[{3}]];     (* symmetric *)
p2 = YoungProject[t3, YoungTableau[{1,1,1}]]; (* antisymmetric *)
(* Inner product of p1 and p2 should be 0 *)

(* Example 11: Single element tensor *)
YoungProject[{x}, YoungTableau[{1}]]
(* Returns: {x} *)

(* Example 12: Compare with YoungSymmetrize *)
t = Array[a, {2, 2}];
ys = YoungSymmetrize[t, YoungTableau[{2}]];
yp = YoungProject[t, YoungTableau[{2}]];
(* yp == ys/2 *)
```

---

## Mathematical Background

### Young Tableaux

A Young tableau is a way of arranging n boxes into left-justified rows where:
- Row lengths form a non-increasing sequence (partition of n)
- Each box contains a distinct positive integer

**Visual Example - Shape {3,2}:**
```
┌───┬───┬───┐
│ 1 │ 2 │ 3 │
├───┼───┼───┘
│ 4 │ 5 │
└───┴───┘
```

### Young Symmetrizer

The Young symmetrizer c_T = a_T * b_T where:
- b_T: symmetrizes over each row (sum over permutations)
- a_T: antisymmetrizes over each column (sum with signatures)

This ordering ensures column antisymmetry is preserved in the final result.

### Hook-Length Formula

The dimension of the irreducible representation is:
```
d = n! / (product of all hook lengths)
```

Where hook length at position (r,c) = cells to right + cells below + 1.

---

## Quick Reference

| Function | Purpose | Example |
|----------|---------|---------|
| `YoungTableau[{d1,d2,...}]` | Create from partition | `YoungTableau[{3,2}]` |
| `YoungTableau[{{...},...}]` | Create with explicit slots | `YoungTableau[{{1,3},{2}}]` |
| `YoungTableauQ[t]` | Validate tableau | `YoungTableauQ[tab]` |
| `TableauShape[t]` | Get partition | `TableauShape[tab]` -> `{3,2}` |
| `TableauSize[t]` | Get number of boxes | `TableauSize[tab]` -> `5` |
| `HookLength[t,{r,c}]` | Hook at position | `HookLength[tab,{1,1}]` |
| `TableauDimension[t]` | Irrep dimension | `TableauDimension[tab]` |
| `YoungSymmetrize[T,t]` | Unnormalized symmetrization | `YoungSymmetrize[tensor,tab]` |
| `YoungProject[T,t]` | Normalized projection | `YoungProject[tensor,tab]` |
