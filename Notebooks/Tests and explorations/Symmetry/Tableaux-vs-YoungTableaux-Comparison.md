# Comparison: Tableaux.nb vs Symmetry Functions (YoungTableaux.wl)

## Overview

This document provides a detailed comparison between:
- **Tableaux.nb**: Comprehensive Young tableaux library by José M. Martín-García (located in `Notebooks/Tests and explorations/Symmetry/Tableaux.nb`)
- **YoungTableaux.wl**: Current Symmetry functions in TensorNetworks (located in `TensorNetworks/Kernel/Symmetry/YoungTableaux.wl`)

---

## 1. Feature Comparison Table

| Feature | Tableaux.nb | YoungTableaux.wl | Gap |
|---------|-------------|------------------|-----|
| **Data Structure** ||||
| Tableau head | `Tableau[row1, row2, ...]` | `YoungTableau[rows_List]` | Similar |
| Partition validation | `PartitionQ` (standalone) | Inline in `youngTableauQ` | Missing standalone |
| Formatting | Blue-frame grid with `Format` | `SummaryBox` with icon | Different style |
| **Partition Operations** ||||
| Transpose partition | `TransposePartition[par]` | Not available | **Missing** |
| Shape extraction | `TableauPartition[tab]` | `TableauShape[yt]` | Equivalent |
| **Dimension Computation** ||||
| Hook factor | `HookFactor[par]` - determinant-based | N/A | **Missing** |
| Hook length | Computes all at once | `HookLength[yt, {r,c}]` per cell | Less efficient |
| Dimension | Via `n! * HookFactor[par]` | `TableauDimension[yt]` via product | Different algorithm |
| **Tableau Types** ||||
| General validation | `TableauQ` | `YoungTableauQ` | Equivalent |
| Disjoint tableau | `DisjointTableauQ` | Not available | **Missing** |
| Semistandard | `SemistandardTableauQ` | Not available | **Missing** |
| Standard | `StandardTableauQ` | Implicit in `YoungTableauQ` | Not explicit |
| Normal | `NormalTableauQ` | Not available | **Missing** |
| **Tableau Generation** ||||
| All tableaux | `Tableaux[par, set]` | Not available | **Missing** |
| Disjoint tableaux | `DisjointTableaux[par, set]` | Not available | **Missing** |
| Semistandard | `SemistandardTableaux[par, set]` | Not available | **Missing** |
| Standard | `StandardTableaux[par, set]` | Not available | **Missing** |
| First/Last lex | `FirstLexicographicStandardTableau` | Not available | **Missing** |
| Previous standard | `PreviousStandardTableau` | Not available | **Missing** |
| Counting | `NumberOfStandardTableaux`, etc. | Not available | **Missing** |
| **Transpose** ||||
| Transpose tableau | `TransposeTableau[tab]` | Not available | **Missing** |
| **Algorithms** ||||
| Schensted bumping | `RowBump[tab, x, n]` | Not available | **Missing** |
| Schensted product | `SchenstedProduct[tab1, tab2]` | Not available | **Missing** |
| Skew tableau slide | `SkewTableauSlide[skewtab]` | Not available | **Missing** |
| Rectify skew | `RectifySkewTableau[skewtab]` | Not available | **Missing** |
| **Littlewood-Richardson** ||||
| LR rule | `LRrule[tab1, tab2]` | Not available | **Missing** |
| LR number | `LRNumber[par1, par2, tpar]` | Not available | **Missing** |
| LR product | `LRProduct[par1, par2]` | Not available | **Missing** |
| **Orderings** ||||
| Dominance order | `DominanceOrder[par1, par2]` | Not available | **Missing** |
| Lexicographic order | `LexicographicOrder[tab1, tab2]` | Not available | **Missing** |
| Inclusion order | `InclusionOrder[par1, par2]` | Not available | **Missing** |
| **Symmetrization** ||||
| Young symmetrizer | Not explicit (uses Schur polys) | `YoungSymmetrize[tensor, yt]` | **YoungTableaux.wl better** |
| Young projector | Not explicit | `YoungProject[tensor, yt]` | **YoungTableaux.wl better** |
| **Representation Theory** ||||
| Branching GL→O | `Branch[par]` | Not available | **Missing** |
| Dimensional restriction | `DimensionalRestriction[par, dim]` | Not available | **Missing** |

---

## 2. Key Algorithmic Differences

### 2.1 Hook Length / Dimension Computation

**YoungTableaux.wl (Current):**
```mathematica
HookLength[YoungTableau[rows_], {row_, col_}] :=
    Module[{rowLen, colLen},
        rowLen = Length[rows[[row]]] - col + 1;
        colLen = Count[rows[[row + 1 ;;]], _?(Length[#] >= col &)];
        rowLen + colLen
    ]

TableauDimension[yt_] := n! / Times @@ (all hook lengths)
```
- **Complexity**: O(n) per cell, O(n²) total for dimension
- **Approach**: Per-cell computation, no caching

**Tableaux.nb (HookFactor - Frobenius Determinant):**
```mathematica
DET[list_] := Det[Outer[Binomial, list, Range[0, Length[list]-1]]]

HookFactor[par_] := Module[{tmppar},
    tmppar = With[{n = Length[par]}, par - Range[n] + n];
    DET[tmppar] / Apply[Times, Factorial /@ tmppar]
]
(* Dimension = Total[par]! * HookFactor[par] *)
```
- **Complexity**: O(r³) where r = number of rows (typically small)
- **Approach**: Partition-level determinant formula
- **Advantage**: Much faster for partitions with few rows (common case)

### 2.2 Tableau Transpose

**Tableaux.nb:**
```mathematica
TransposePartition[par_] := Table[Count[par, x_ /; x >= i], {i, par[[1]]}]

TransposeTableau[tab_] := (* Generalizes Transpose for ragged arrays *)
```

**YoungTableaux.wl:** Not implemented. Uses internal `getColumns` helper only.

### 2.3 Standard Tableau Generation

**Tableaux.nb:**
- `FirstLexicographicStandardTableau[par]`: Fills rows left-to-right with 1,2,3...
- `LastLexicographicStandardTableau[par]`: Fills columns top-to-bottom
- `PreviousStandardTableau[tab]`: Complex algorithm for lexicographic predecessor
- `StandardTableaux[par]`: Generates all standard tableaux

**YoungTableaux.wl:** Only has constructor `YoungTableau[partition]` which creates the first standard tableau.

---

## 3. Improvements for YoungTableaux.wl from Tableaux.nb

### Priority 1: Foundation (High Impact, Low Effort)

| Function | Purpose | From Tableaux.nb |
|----------|---------|------------------|
| `PartitionQ[par]` | Standalone partition validation | `PartitionQ` |
| `TransposePartition[par]` | Conjugate partition | `TransposePartition` |
| `TransposeTableau[yt]` | Swap rows/columns | `TransposeTableau` |
| `StandardTableauQ[yt]` | Explicit standard check | `StandardTableauQ` |
| `SemistandardTableauQ[yt]` | Rows weakly, cols strictly increasing | `SemistandardTableauQ` |

### Priority 2: Efficiency (Medium Impact)

| Function | Purpose | Benefit |
|----------|---------|---------|
| `HookFactor[par]` | Determinant-based hook computation | O(r³) vs O(n²) |
| `TableauDimensionFast[par]` | Direct from partition | Skip tableau construction |
| Hook length caching | Memoize computed values | Avoid recomputation |

### Priority 3: Generation (High Impact, Medium Effort)

| Function | Purpose | From Tableaux.nb |
|----------|---------|------------------|
| `StandardTableaux[par]` | All standard tableaux of shape | `StandardTableaux` |
| `NumberOfStandardTableaux[par]` | Count without enumeration | Uses hook formula |
| `FirstStandardTableau[par]` | First in lex order | `FirstLexicographicStandardTableau` |
| `LastStandardTableau[par]` | Last in lex order | `LastLexicographicStandardTableau` |
| `PreviousStandardTableau[yt]` | Lex predecessor | `PreviousStandardTableau` |

### Priority 4: Advanced Algorithms (High Impact, High Effort)

| Function | Purpose | From Tableaux.nb |
|----------|---------|------------------|
| `RowBump[tab, x, row]` | Schensted insertion | `RowBump` |
| `SchenstedProduct[tab1, tab2]` | Tableau multiplication | `SchenstedProduct` |
| `LRrule[tab1, tab2]` | Tensor product decomposition | `LRrule` |
| `LRNumber[par1, par2, tpar]` | Multiplicity coefficients | `LRNumber` |

### Priority 5: Extended Features (Lower Priority)

| Function | Purpose |
|----------|---------|
| Skew tableau support | `Skew`, `SkewTableauSlide`, `RectifySkewTableau` |
| Ordering functions | `DominanceOrder`, `LexicographicOrder` |
| Branching rules | `Branch[par]` for GL(d)→O(d) |
| Word operations | `WordOfTableau`, `TableauOfWord` |

---

## 4. What YoungTableaux.wl Does Better

The current implementation has advantages in:

1. **Tensor Symmetrization**: `YoungSymmetrize` and `YoungProject` are fully implemented and work directly on tensors - Tableaux.nb lacks this.

2. **Validation Caching**: Uses `System`Private`HoldValidQ` for efficient repeated validation.

3. **Modern SummaryBox Format**: Uses `BoxForm`ArrangeSummaryBox` with icon visualization.

4. **Clean API**: Focused on tensor network operations rather than pure combinatorics.

---

## 5. Implementation Roadmap

### Phase 1: Core Extensions (Immediate)
- Add `PartitionQ`, `TransposePartition`, `TransposeTableau`
- Add `StandardTableauQ`, `SemistandardTableauQ`
- Add `DisjointTableauQ`

### Phase 2: Efficiency Improvements
- Implement `HookFactor` using determinant formula
- Add optional `TableauDimensionFast[partition]`
- Consider hook length caching

### Phase 3: Generation Functions
- Implement `StandardTableaux[par]`
- Add `NumberOfStandardTableaux[par]`
- Add `FirstStandardTableau`, `LastStandardTableau`
- Implement `PreviousStandardTableau` for iteration

### Phase 4: Advanced Algorithms
- Implement Schensted algorithm (`RowBump`, `SchenstedProduct`)
- Implement Littlewood-Richardson rule

---

## 6. Critical Files

| File | Role |
|------|------|
| [YoungTableaux.wl](TensorNetworks/Kernel/Symmetry/YoungTableaux.wl) | Core module to extend |
| [Tableaux.nb](Notebooks/Tests and explorations/Symmetry/Tableaux.nb) | Reference implementation |
| [Symmetry.wl](TensorNetworks/Kernel/Symmetry/Symmetry.wl) | Loader (may need updates) |

---

## 7. Summary

**Tableaux.nb** is a comprehensive combinatorics library with:
- 40+ functions for Young tableaux
- Efficient determinant-based dimension computation
- Complete tableau generation and enumeration
- Schensted and Littlewood-Richardson algorithms

**YoungTableaux.wl** is focused on tensor operations with:
- Core data structure and validation
- Hook length formula implementation
- **Unique strength**: Direct tensor symmetrization (`YoungSymmetrize`, `YoungProject`)

**Key improvements to adopt**:
1. `TransposePartition` and `TransposeTableau` - fundamental operations
2. `HookFactor` determinant formula - more efficient dimension computation
3. `StandardTableaux` generation - needed for irrep basis enumeration
4. Schensted and LR algorithms - for advanced tensor decomposition
