# Symmetry for Tensor Network Operations

The TensorNetworks paclet's `Symmetry` subcontext (`Wolfram`TensorNetworks`Symmetry``) exports 12 functions around Young tableaux, the hook-length formula, and the Young symmetrizer / projector. Standalone they are pure representation theory. Plugged into a tensor network they do three things you cannot do with built-in WL alone:

1. Predict bond multiplicities in closed form, before any tensor is allocated.
2. Block-diagonalise permutation-symmetric operators along Young irreps.
3. Enforce multi-term symmetry constraints (e.g. the first Bianchi identity), which `TensorReduce` cannot prove from slot-permutation generators.

Four runnable examples follow, ordered by how heavily each one leans on the Symmetry subcontext. Tier 1 examples sweep over partitions and use `TableauDimension`, `HookLengths`, `YoungTableau`, and `YoungProject` together. Tier 2 examples make a single, surgical `YoungProject` call that cannot be replaced by any built-in canonicalisation.

Every assertion below is verified by [symmetry_for_tn.wl](symmetry_for_tn.wl) (`wolframscript -file`, all green) and reproduced cell-by-cell in [SymmetryForTN.nb](SymmetryForTN.nb).

| Tier | Example | Symmetry-subcontext functions used | Pays off for |
|---|---|---|---|
| **1** | A. On-site irreps and MPS bond multiplicity | `YoungTableau`, `YoungProject`, `TableauDimension`, `HookLengths` (via `schurDim`) | Symmetry-resolved DMRG / TDVP: exact block sizes before allocation. |
| **1** | B. $V^{\otimes 3}$ block-diagonalisation under sum-of-pair-swaps | `YoungTableau`, `YoungProject`, `TableauDimension`, `HookLengths` | Diagonalising permutation-symmetric Hamiltonians one block at a time. |
| **2** | C. Riemann tensor as a TN node | `YoungTableau`, `YoungProject` | Curvature-scalar networks, Weyl contractions, rank-4 nodes with $(2,2)$ symmetry. |
| **2** | D. $V \otimes V$ Schur-Weyl on a single bond | `YoungTableau`, `YoungProject` | Symmetric / antisymmetric bonds without storing the wrong-parity sector. |

---

## Setup

Load the paclet and the Symmetry subcontext. The Symmetry subcontext exports
`YoungTableau`, `YoungTableauQ`, `PartitionQ`, `TransposePartition`,
`TableauShape`, `TableauSize`, `HookLength`, `HookLengths`, `HookFactor`,
`TableauDimension`, `YoungSymmetrize`, and `YoungProject`.

```wolfram
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];
```

A few helpers used throughout. `schurDim[par, d]` is the Weyl dimension of the
$\mathrm{GL}(d)$ irrep $S^\lambda(\mathbb{C}^d)$ via the Weyl formula

$$
\dim S^\lambda(\mathbb{C}^d) \;=\; \prod_{(i,j)\,\in\,\lambda} \frac{d + j - i}{h(i,j)}
$$

where $h(i,j)$ is the hook length at cell $(i,j)$. `contentSum[par]` is the
eigenvalue of $\sum_{i<j} P_{ij}$ on the irrep $V_\lambda$, namely

$$
c(\lambda) \;=\; \sum_{(i,j)\,\in\,\lambda} (j - i).
$$

`flattenProjector` materializes a Young projector (or a sum of them over the
standard tableaux of one shape) as a $d^n \times d^n$ matrix on
$V^{\otimes n}$. `irrepRank` reports its rank, i.e. the block dimension.
`standardTableaux` enumerates standard Young tableaux of a given shape (no
built-in equivalent in plain WL).

```wolfram
tol = 10^-10;

schurDim[par_List, d_Integer] := Module[{hooks},
    hooks = HookLengths[par];
    Product[
        Product[(d + j - i)/hooks[[i, j]], {j, par[[i]]}],
        {i, Length[par]}
    ]
];

contentSum[par_List] :=
    Total @ Flatten @ Table[j - i, {i, Length[par]}, {j, par[[i]]}];

flattenProjector[tableaux_List, d_Integer, n_Integer] := Module[
    {dims, idxList, basisTensors, projected},
    dims = ConstantArray[d, n];
    idxList = Tuples[Range[d], n];
    basisTensors = Map[Normal @ SparseArray[# -> 1, dims] &, idxList];
    projected = Map[
        Function[T,
            Flatten @ Total[
                Function[t, YoungProject[T, YoungTableau[t]]] /@ tableaux
            ]
        ],
        basisTensors
    ];
    Transpose @ projected
];

irrepRank[tableaux_List, d_Integer, n_Integer] :=
    MatrixRank @ flattenProjector[tableaux, d, n];

removableCorners[par_List] := Select[
    Table[{i, par[[i]]}, {i, Length[par]}],
    Function[c, c[[1]] == Length[par] || par[[c[[1]] + 1]] < c[[2]]]
];

shrinkAt[par_List, {i_, _}] := DeleteCases[MapAt[# - 1 &, par, i], 0];

standardTableaux[{}] = {{}};
standardTableaux[par_List] := standardTableaux[par] = Module[{n = Total[par]},
    Join @@ Map[
        Function[c,
            Map[
                Function[T,
                    Module[{rows = T},
                        While[Length[rows] < c[[1]], AppendTo[rows, {}]];
                        ReplacePart[rows, c[[1]] -> Append[rows[[c[[1]]]], n]]
                    ]
                ],
                standardTableaux[shrinkAt[par, c]]
            ]
        ],
        removableCorners[par]
    ]
];
```

---

# Tier 1: heavy Symmetry-subcontext usage

These two examples sweep over multiple partitions and dimensions, calling
`TableauDimension`, `HookLengths`, `YoungTableau`, and `YoungProject` many
times per run. Each is also the most operationally TN-actionable: the
formulas they validate are exactly what you need to size and populate
symmetry-resolved MPS / MPO blocks.

---

## Example A. On-site irreps predict MPS / MPO bond multiplicity

### Symmetry-subcontext functions used

- `TableauDimension[par]` — computes $\dim V_\lambda$ via the hook-length formula $n! / \prod h(i,j)$. This is the $S_n$-irrep factor.
- `HookLengths[par]` — the per-cell hook lengths used inside `schurDim` to evaluate $\dim S^\lambda(\mathbb{C}^d)$ via the Weyl formula.
- `YoungTableau[t]` — wraps each standard tableau into the structural type that `YoungProject` understands.
- `YoungProject[T, YoungTableau[t]]` — projects basis tensors onto the irrep subspace (inside `flattenProjector` / `irrepRank`), giving the *measured* block dimension as a verification of the closed-form prediction.

### Why Symmetry matters here, and how it helps

On a permutation-symmetric chain of $d$-dim sites, the MPS bond carries a representation of $S_n \times \mathrm{GL}(d)$. Schur-Weyl decomposes it as

$$
V^{\otimes n} \;=\; \bigoplus_{\lambda \,\vdash\, n} V_\lambda \,\otimes\, S^\lambda(\mathbb{C}^d).
$$

The size of the $\lambda$-isotypic block is the multiplicity

$$
m_\lambda \;=\; \dim V_\lambda \;\cdot\; \dim S^\lambda(\mathbb{C}^d).
$$

Both factors come from the Symmetry subcontext in closed form, without ever materialising the projector: `TableauDimension[par]` gives $\dim V_\lambda$ via the hook-length formula; `HookLengths[par]` feeds the Weyl formula for $\dim S^\lambda(\mathbb{C}^d)$. Computing $m_\lambda$ is O(r²) in the number of rows of $\lambda$, regardless of $d$ or $n$.

The payoff: a symmetry-resolved MPS sizes each sector exactly. Sectors with $m_\lambda = 0$ (e.g. $\{2,1,1\}$ and $\{1,1,1,1\}$ at $d = 2$) are skipped by formula. No truncation inside any sector; no slots wasted on empty ones.

The verification below also calls `YoungProject` (inside `flattenProjector` / `irrepRank`) to *measure* each block rank by projecting basis tensors. That confirms the closed-form prediction; in production only the closed form is needed.

### Code

```wolfram
cases = {<|"n" -> 2, "d" -> 2|>,
         <|"n" -> 3, "d" -> 2|>,
         <|"n" -> 3, "d" -> 3|>,
         <|"n" -> 4, "d" -> 2|>};

results = Map[
    Function[case,
        Module[{n, d, perShape},
            n = case["n"]; d = case["d"];
            perShape = Map[
                Function[par,
                    <|
                        "partition"    -> par,
                        "schurWeylDim" -> TableauDimension[par] * schurDim[par, d],
                        "irrepRank"    -> irrepRank[standardTableaux[par], d, n]
                    |>
                ],
                IntegerPartitions[n]
            ];
            <|
                "n"           -> n,
                "d"           -> d,
                "totalDim"    -> d^n,
                "sumOfBlocks" -> Total[#schurWeylDim & /@ perShape],
                "perShape"    -> perShape
            |>
        ]
    ],
    cases
];
```

Top-line summary: every Schur-Weyl block-dimension sum equals $d^n$.

```wolfram
Dataset[results /. assoc_Association :> KeyDrop[assoc, "perShape"]]
```

Per-shape breakdown. Every row has $\dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d) = \mathrm{irrepRank}$:

| $n$ | $d$ | partition $\lambda$ | $\dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$ | `irrepRank` |
|---|---|---|---|---|
| 2 | 2 | $\{2\}$         | 3  | 3  |
| 2 | 2 | $\{1, 1\}$      | 1  | 1  |
| 3 | 2 | $\{3\}$         | 4  | 4  |
| 3 | 2 | $\{2, 1\}$      | 4  | 4  |
| 3 | 2 | $\{1, 1, 1\}$   | 0  | 0  |
| 3 | 3 | $\{3\}$         | 10 | 10 |
| 3 | 3 | $\{2, 1\}$      | 16 | 16 |
| 3 | 3 | $\{1, 1, 1\}$   | 1  | 1  |
| 4 | 2 | $\{4\}$         | 5  | 5  |
| 4 | 2 | $\{3, 1\}$      | 9  | 9  |
| 4 | 2 | $\{2, 2\}$      | 2  | 2  |
| 4 | 2 | $\{2, 1, 1\}$   | 0  | 0  |
| 4 | 2 | $\{1, 1, 1, 1\}$| 0  | 0  |

The closed-form prediction and the explicit projector rank agree on every row, including the rows where the block is identically zero (so no allocation is wasted on those sectors).

---

## Example B. $V^{\otimes 3}$ block-diagonalisation under sum-of-pair-swaps

### Symmetry-subcontext functions used

- `YoungTableau[t]` — one per standard tableau, four times in this example (one for $\{3\}$, two for $\{2,1\}$, one for $\{1,1,1\}$).
- `YoungProject[T, YoungTableau[t]]` — projects $T$ onto each tableau; for the mixed-symmetry irrep we sum two `YoungProject` calls to form the isotypic projector $E_{\{2,1\}}$.
- `TableauDimension[par]` — gives the $S_n$-irrep dimension that equals the number of standard tableaux of shape $\lambda$.
- `HookLengths[par]` (via `schurDim`) — used to evaluate the GL(d) factor in the Schur-Weyl multiplicity.

### Why Symmetry matters here, and how it helps

The sum of pair-swaps $H = \sum_{i<j} P_{ij}$ is a class function of $S_n$. By Schur-Weyl it commutes with every isotypic projector and acts as a scalar on each block. For $n = 3$ that means $H$ has at most three distinct eigenvalues, one per partition of $3$, with multiplicity $m_\lambda = \dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$.

The eigenvalue on $V_\lambda$ is the content sum $c(\lambda) = \sum_{(i,j) \in \lambda} (j - i)$: a one-line formula that needs no diagonalisation. For $n = 3$: $c(\{3\}) = +3$, $c(\{2,1\}) = 0$, $c(\{1,1,1\}) = -3$. (The same formula gives the eigenvalue of any class-function Hamiltonian made from transpositions on any number of sites.)

The Symmetry subcontext provides the three pieces:

- `YoungProject` on each standard tableau of $\lambda$. Each call is a *minimal* idempotent; summing over all standard tableaux of a shape (two of them for $\{2,1\}$) gives the isotypic projector $E_\lambda$.
- `TableauDimension[par]` returns $\dim V_\lambda$, which by the RSK correspondence equals the number of standard tableaux of shape $\lambda$. Both meanings are used here: as a factor in $m_\lambda$, and as the count of `YoungProject` calls summed inside $E_\lambda$.
- `HookLengths[par]` feeds `schurDim` for the $\mathrm{GL}(d)$ factor.

The payoff: per-block diagonalisation costs $\sum_\lambda m_\lambda^3$ instead of $O(d^{3n})$. For class-function Hamiltonians the eigenvalues themselves come from the partitions, not from any numerical diagonalisation.

### Code

```wolfram
d = 2;
SeedRandom[7];
T = RandomReal[{-1, 1}, {d, d, d}];

e3   = YoungProject[T, YoungTableau[{{1, 2, 3}}]];
e21  = YoungProject[T, YoungTableau[{{1, 2}, {3}}]] +
       YoungProject[T, YoungTableau[{{1, 3}, {2}}]];
e111 = YoungProject[T, YoungTableau[{{1}, {2}, {3}}]];
```

Completeness ($E_{\{3\}} + E_{\{2,1\}} + E_{\{1,1,1\}} = \mathrm{id}$ on $V^{\otimes 3}$):

```wolfram
Max[Abs[Flatten[e3 + e21 + e111 - T]]] < tol
(* True *)
```

For $d = 2$ the antisymmetric piece vanishes identically (cannot
antisymmetrize three slots in two values):

```wolfram
Max[Abs[Flatten[e111]]] < tol
(* True *)
```

Predicted block dimensions $m_\lambda = \dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$, then measured projector ranks:

```wolfram
{
    TableauDimension[{3}]       * schurDim[{3}, d],         (* 4 *)
    TableauDimension[{2, 1}]    * schurDim[{2, 1}, d],      (* 4 *)
    TableauDimension[{1, 1, 1}] * schurDim[{1, 1, 1}, d]    (* 0 *)
}

{
    irrepRank[{{{1, 2, 3}}}, d, 3],                         (* 4 *)
    irrepRank[{{{1, 2}, {3}}, {{1, 3}, {2}}}, d, 3],        (* 4 *)
    irrepRank[{{{1}, {2}, {3}}}, d, 3]                      (* 0 *)
}
```

Build the operator $H = P_{12} + P_{13} + P_{23}$ as a $d^3 \times d^3$ matrix
and diagonalise:

```wolfram
applySwap[a_, b_] := Module[{perm = Range[3]},
    perm[[{a, b}]] = perm[[{b, a}]];
    ArrayReshape[
        Transpose[
            Normal @ SparseArray[
                Flatten[Table[{i, j, k, i, j, k} -> 1,
                    {i, d}, {j, d}, {k, d}], 2],
                {d, d, d, d, d, d}
            ],
            Join[perm, {4, 5, 6}]
        ],
        {d^3, d^3}
    ]
];

Hmat = applySwap[1, 2] + applySwap[1, 3] + applySwap[2, 3];

Sort[Eigenvalues[Hmat], Greater]
(* {3, 3, 3, 3, 0, 0, 0, 0} *)
```

Predicted spectrum from content sums: each irrep contributes $m_\lambda$ copies at eigenvalue $c(\lambda)$.

```wolfram
Sort[
    Flatten @ {
        ConstantArray[contentSum[{3}],       TableauDimension[{3}]       * schurDim[{3}, d]],
        ConstantArray[contentSum[{2, 1}],    TableauDimension[{2, 1}]    * schurDim[{2, 1}, d]],
        ConstantArray[contentSum[{1, 1, 1}], TableauDimension[{1, 1, 1}] * schurDim[{1, 1, 1}, d]]
    },
    Greater
]
(* {3, 3, 3, 3, 0, 0, 0, 0} *)
```

The numerical spectrum from `Eigenvalues[Hmat]` and the closed-form prediction
from Symmetry primitives agree exactly. The "diagonalisation" of $H$ never
actually needed `Eigenvalues`: it needed `TableauDimension`, `schurDim`, and
`contentSum`.

---

# Tier 2: foundational Symmetry-subcontext usage

These two examples make a single, surgical use of `YoungProject` (and the
`YoungTableau` that names the target irrep). The Symmetry-symbol count is
lower, but the use is *irreplaceable*: built-in WL canonicalisation cannot
do the same job. For multi-term symmetry constraints (Example C) and for
imposing exact parity on a bond (Example D), `YoungProject` is the only
WL primitive that does the right thing.

---

## Example C. Riemann tensor as a TN node

### Symmetry-subcontext functions used

- `YoungTableau[{{1,3},{2,4}}]` — encodes the $(2,2)$ Young diagram with the slot labelling that defines Riemann symmetry.
- `YoungProject[T, ...]` — projects a generic rank-4 tensor onto the (2,2) irrep subspace, in one call.

### Why Symmetry matters here, and how it helps

The Riemann curvature tensor $R_{abcd}$ satisfies four constraints:

1. antisymmetry in $(a, b)$: $\;R_{abcd} = -R_{bacd}$,
2. antisymmetry in $(c, d)$: $\;R_{abcd} = -R_{abdc}$,
3. pair-swap symmetry: $\;R_{abcd} = R_{cdab}$,
4. first Bianchi identity:

$$
R_{abcd} + R_{acdb} + R_{adbc} \;=\; 0.
$$

The first three are *single-term* slot symmetries: each has the form $T^\sigma = \phi T$ for one permutation $\sigma$ and sign $\phi$. Built-in WL canonicalisation (`TensorReduce` + `Arrays[..., sym]`) covers exactly this kind. The first Bianchi identity is **multi-term**: it asserts $R + R^{\sigma_1} + R^{\sigma_2} = 0$, where no single $(\sigma, \phi)$ pair reproduces $R$. No slot-permutation canonicalizer can prove a multi-term identity from single-term generators.

Riemann symmetry is in fact the full content of *one* $S_4$ irrep, the one labelled by the Young diagram $(2, 2)$. All four constraints follow from membership in that single irrep. `YoungProject` is the only WL primitive that projects onto an $S_n$ irrep, and one call enforces every Riemann constraint at once.

After projection, downstream TN operations (`TensorContract`, traces, index raising) preserve the irrep structure automatically. The Euclidean Ricci contraction $R_{bd} = \delta^{ac} R_{abcd}$ comes out symmetric because the source lived in the right subspace, not by a separate re-symmetrisation step.

The structural gap opens at $n = 4$. The true number of independent Riemann components is $n^2(n^2-1)/12$. `Arrays[{n,n,n,n}, sym]` over-counts this by the Bianchi degrees of freedom: 1 extra component at $n=4$ (orbit 21 vs. true 20), 5 extra at $n=5$ (orbit 55 vs. true 50), growing. For curvature-scalar networks, Weyl-tensor contractions, or any rank-4 TN node with Riemann symmetry, `YoungProject` is the only tool that produces the correct subspace.

### Code

Start with a generic rank-4 tensor and project onto the $(2,2)$ Riemann irrep:

```wolfram
SeedRandom[42];
T0 = RandomReal[{-1, 1}, {4, 4, 4, 4}];
R = YoungProject[T0, YoungTableau[{{1, 3}, {2, 4}}]];
```

Antisymmetry in slots $(1, 2)$:

```wolfram
Max[Abs[Flatten[R + Transpose[R, {2, 1, 3, 4}]]]] < tol
(* True *)
```

Antisymmetry in slots $(3, 4)$:

```wolfram
Max[Abs[Flatten[R + Transpose[R, {1, 2, 4, 3}]]]] < tol
(* True *)
```

Pair-swap symmetry $(1,2) \leftrightarrow (3,4)$:

```wolfram
Max[Abs[Flatten[R - Transpose[R, {3, 4, 1, 2}]]]] < tol
(* True *)
```

First Bianchi: $R + \mathrm{cyc} = 0$ over the last three slots. **This is the constraint `TensorReduce` cannot prove.**

```wolfram
Max[Abs[Flatten[
    R + Transpose[R, {1, 3, 4, 2}] + Transpose[R, {1, 4, 2, 3}]
]]] < tol
(* True *)
```

Wire $R$ into a TN: contract slots $1$ and $3$, i.e. the Euclidean Ricci
contraction $R_{bd} = \delta^{ac} R_{abcd}$. Because $R$ lives in the $(2,2)$
irrep, the Ricci tensor is automatically symmetric:

```wolfram
Ric = TensorContract[R, {{1, 3}}];
Max[Abs[Flatten[Ric - Transpose[Ric]]]] < tol
(* True *)
```

The scalar curvature is the trace of $R_{bd}$ (Euclidean signature):

```wolfram
Tr[Ric]
(* 1.1865504865364562 *)
```

Two `YoungTableau` / `YoungProject` calls in total, but each one does work that
no slot-permutation canonicalizer can do. Once $R$ is projected, the rest of
the TN proceeds with no further intervention.

---

## Example D. $V \otimes V$ Schur-Weyl on a single bond

### Symmetry-subcontext functions used

- `YoungTableau[{{1,2}}]` — the $\{2\}$ partition (symmetric).
- `YoungTableau[{{1},{2}}]` — the $\{1,1\}$ partition (antisymmetric).
- `YoungProject[T, ...]` — the normalised idempotent projector for each.

### Why Symmetry matters here, and how it helps

A single bond between two TN nodes is a rank-2 tensor in $V \otimes V$. Schur-Weyl gives

$$
V \otimes V \;=\; \mathrm{Sym}^2(V) \,\oplus\, \mathrm{Anti}^2(V),
$$

with dimensions $d(d+1)/2$ and $d(d-1)/2$. If the bond carries only one parity (an antisymmetric fermionic two-body bond; a symmetric permutation-invariant kernel), projecting onto the correct sector before SVD or contraction saves the whole orthogonal sector's worth of bond dimension.

For rank-2 this is the textbook formula $P_{\mathrm{sym}}(T) = (T + T^\top)/2$, $P_{\mathrm{anti}}(T) = (T - T^\top)/2$, which is easy to code by hand. Two reasons `YoungProject` is still the right tool:

1. **Rank generalisation.** Beyond rank 2 the hand-coded symmetriser is a sum of up to $n!$ signed permutations, and mixed-symmetry diagrams require sequential row-symmetrise + column-antisymmetrise. `YoungProject[T, YoungTableau[t]]` is the same one-line call for any rank and any Young diagram.

2. **Built-in normalisation.** `YoungProject` carries the $d_\lambda / n!$ prefactor that makes it idempotent ($P^2 = P$). The unnormalised Young symmetrizer (also exported, as `YoungSymmetrize`) satisfies $e_T^2 = (n!/d_\lambda)\, e_T$ instead; hand-rolled symmetrisers typically forget the prefactor. The idempotent form is what iterative TN algorithms (DMRG, TDVP) need when a projector is applied repeatedly.

This is the warm-up case: the mechanism on the simplest possible bond before Tier 1 scales it to general $V^{\otimes n}$.

### Code

A generic rank-2 tensor with $d = 3$:

```wolfram
d = 3;
SeedRandom[2026];
T = RandomReal[{-1, 1}, {d, d}];

Psym = YoungProject[T, YoungTableau[{{1, 2}}]];
Pant = YoungProject[T, YoungTableau[{{1}, {2}}]];
```

The two projectors recover the original tensor:

```wolfram
Max[Abs[Flatten[Psym + Pant - T]]] < tol
(* True *)
```

The antisymmetric piece has zero diagonal:

```wolfram
Max[Abs[Diagonal[Pant]]] < tol
(* True *)
```

Block dimensions match the closed-form predictions $d(d+1)/2 = 6$ and $d(d-1)/2 = 3$:

```wolfram
{irrepRank[{{{1, 2}}}, d, 2], d (d + 1)/2}     (* {6, 6} *)
{irrepRank[{{{1}, {2}}}, d, 2], d (d - 1)/2}   (* {3, 3} *)
```

---

## Recap

The tiers map to the operational ladder of a symmetry-resolved TN workflow:

1. **Tier 1: sizing and block-diagonalisation.** Examples A and B give (a) the size of each isotypic block on a bond, and (b) the full eigenstructure of any class-function Hamiltonian on that bond, both in closed form. `TableauDimension` and `HookLengths` carry the math; `YoungProject` only appears in the verification step.

2. **Tier 2: multi-term constraint enforcement.** Example C is the case built-in WL canonicalisation cannot reach: the first Bianchi identity. Example D is the rank-2 warm-up of the same mechanism.

Every assertion above is verified by [symmetry_for_tn.wl](symmetry_for_tn.wl) (green under `wolframscript -file`). [SymmetryForTN.nb](SymmetryForTN.nb) reproduces the same content with rendered TraditionalForm math.
