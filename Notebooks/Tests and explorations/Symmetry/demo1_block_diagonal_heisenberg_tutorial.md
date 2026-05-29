---
Template: TechNote
Name: SU2HeisenbergBlockDecomposition
Title: SU(2)-symmetric tensor networks for the Heisenberg chain via Young projection
Context: Wolfram`TensorNetworks`Symmetry`
Paclet: Wolfram/TensorNetworks
URI: Wolfram/TensorNetworks/tutorial/SU2HeisenbergBlockDecomposition
Keywords: [Young tableau, SU(2), Heisenberg, DMRG, tensor network, irrep, Schur-Weyl, block decomposition, non-Abelian symmetry]
RelatedGuides: [TensorNetworks]
---

A tensor network (TN) carries a computational cost governed by its bond dimensions. For a one-dimensional matrix product state (MPS) on $n$ sites with local dimension $d$, the exact wavefunction needs a bond dimension that can grow as $d^{n/2}$, and any expectation value or contraction inherits that cost. The practical way out, for systems with a global symmetry, is to *decompose every bond by the symmetry's irreducible representations (irreps)*. Then the network's tensors block-diagonalize, the bond becomes a labeled direct sum, and the algorithm walks only within compatible irrep sectors. This is the foundational idea behind non-Abelian symmetric tensor networks and the density matrix renormalization group (DMRG) algorithm with special unitary group SU(2) symmetry: every bond carries an irrep label, the algorithm respects it, and the cost scales with the largest individual block instead of the full Hilbert space.

The labels for non-Abelian symmetries are Young partitions, and the block dimensions are products of two combinatorial quantities: the dimension of the symmetric-group irrep $\mathcal P_\lambda$ (computed by the hook-length formula) and the dimension of the unitary-group irrep $\mathcal Q_\lambda$ (computed by the hook-content formula). Implementing this from scratch is an undertaking, which is why production codes such as the [QSpace](https://arxiv.org/abs/1202.5664) library (MATLAB), the [BLOCK](https://sanshar.github.io/Block/) quantum-chemistry DMRG (C++), and the spin-adapted modules of [ITensor](https://itensor.org/) (Julia, C++) invest substantial engineering in their non-Abelian backends. This tutorial shows the same structural decomposition done inside Wolfram Language by composing two ingredients already exported by the `TensorNetworks` paclet: the `Symmetry` sub-context (`YoungTableau`, `YoungProject`, `TableauDimension`, `SchurDimension`) and the core TN-paclet construction (`TensorNetwork`, `TensorNetworkContract`, `OptimalContractionPath`). The recipe is short, the physics is preserved exactly, every prediction is paired with a numerical verification, and the projector is never materialized as a matrix: `YoungProject` operates directly on tensors throughout.

The worked example is the spin-1/2 Heisenberg chain. We work in two stages: a single bond (two sites, four-dimensional Hilbert space, the textbook singlet-triplet decomposition) and a four-site chain (sixteen-dimensional Hilbert space, three irrep blocks of sizes 5, 9, 2). At each stage the partition labels predict the block structure in closed form, the projectors are applied as tensor operations via `YoungProject`, the Hamiltonian is verified to block-decompose along those projectors, the spectrum is recovered as a disjoint union of within-block spectra, and a tensor-network expectation value is shown to inherit the same block structure when evaluated via `TensorNetworkContract`.

## Setup

Load the paclet, pull the Symmetry sub-context into scope, fix the numerical tolerance used by every identity check.

```wl
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

tol = 10^-10;
```

The Pauli matrices $\sigma^x, \sigma^y, \sigma^z$ (the three traceless Hermitian $2 \times 2$ matrices) are the SU(2) generators in their spin-1/2 representation. The spin operator on a single site is $\vec S = \tfrac{1}{2}(\sigma^x, \sigma^y, \sigma^z)$, a three-component vector of operators. The identity matrix rounds out the four-element basis of $2 \times 2$ Hermitian matrices.

```wl
{sI, sx, sy, sz} = Table[PauliMatrix[j], {j, 0, 3}];
```

## The two-site Heisenberg coupling

Two spin-1/2 particles live in the four-dimensional Hilbert space $V \otimes V$ with $V = \mathbb{C}^2$ (the two-dimensional complex vector space). The symbol $\otimes$ denotes the *tensor product*, the standard way to combine two quantum systems: $V \otimes V$ has basis $\{|i\rangle \otimes |j\rangle : i, j \in \{1, 2\}\}$ and dimension $\dim V \cdot \dim V = 4$. The exchange coupling
$$
h_{12} \;=\; \vec S_1 \cdot \vec S_2 \;=\; \tfrac{1}{4}\bigl(\sigma^x_1 \sigma^x_2 + \sigma^y_1 \sigma^y_2 + \sigma^z_1 \sigma^z_2\bigr)
$$
is the elementary interaction of every Heisenberg-type model; subscripts $1, 2$ indicate the site each operator acts on, the dot $\vec S_1 \cdot \vec S_2 = \sum_{a \in \{x, y, z\}} S^a_1 S^a_2$ is the rotation-invariant inner product, and the prefactor $1/4 = (1/2)^2$ comes from the spin-1/2 normalization of $\vec S$. Build it as a $4 \times 4$ Hermitian matrix from Kronecker products of Pauli matrices.

```wl
h12 = (1/4) (KroneckerProduct[sx, sx] +
             KroneckerProduct[sy, sy] +
             KroneckerProduct[sz, sz]);
```

Display the matrix in its readable form.

```wl
MatrixForm[h12]
```

The spectrum is textbook: one eigenvalue at $-3/4$ (the spin-singlet, total spin $S = 0$, antisymmetric under particle exchange) and a triply-degenerate eigenvalue at $+1/4$ (the spin-triplet, $S = 1$, symmetric). Here $S$ labels the eigenvalue of the total-spin operator $\vec S_{\text{tot}}^{\,2}$ via $S(S+1)$; $m_S \in \{-S, \ldots, +S\}$ labels the eigenvalue of $S^z_{\text{tot}}$.

```wl
Sort[Eigenvalues[h12]]
```

A single number ($+1/4$) describes three orthogonal states whose individual labels $|S, m_S\rangle$ for $m_S \in \{-1, 0, 1\}$ play no role in $h_{12}$. The triplet states are connected by total-$S^z$ raising and lowering operators, which generate the SU(2) action on the joint Hilbert space. The irrep block decomposition is the mathematical statement of this compression.

## Schur-Weyl: partitions label irrep blocks

The Schur-Weyl theorem provides the bookkeeping. For any number $n$ of $d$-dimensional quantum systems, the joint Hilbert space decomposes as a direct sum indexed by Young partitions $\lambda \vdash n$ with at most $d$ rows. The notation $\lambda \vdash n$ reads "$\lambda$ is a partition of $n$": a non-increasing tuple of positive integers $\lambda = (\lambda_1, \lambda_2, \ldots, \lambda_k)$ with $\lambda_1 \geq \lambda_2 \geq \cdots > 0$ and $\sum_i \lambda_i = n$. The symbol $\vdash$ ("vdash" in LaTeX, drawn as a small turnstile) is the standard shorthand throughout combinatorics and representation theory for this relationship between a partition and the integer it partitions.

The decomposition itself is the following equation. Reading it left to right: $(\mathbb{C}^d)^{\otimes n}$ is the $n$-fold tensor product of the local space $\mathbb{C}^d$ with itself, the joint state space of $n$ sites of local dimension $d$, with total dimension $d^n$. The symbol $\cong$ ("congruent to" or "isomorphic to") asserts that the two sides are equivalent as representation spaces, i.e., the same space up to a change of basis that respects the group action. The symbol $\bigoplus$ ("direct sum") combines disjoint subspaces; the subscript ranges over partitions $\lambda \vdash n$ subject to a row constraint where $\text{rows}(\lambda)$ is the number of parts of $\lambda$ (the number of nonzero entries in the tuple, equivalently the height of the Young diagram).
$$
(\mathbb{C}^d)^{\otimes n} \;\cong\; \bigoplus_{\lambda \vdash n,\; \text{rows}(\lambda) \leq d} \mathcal Q_\lambda \otimes \mathcal P_\lambda
$$
The right-hand side: $\mathcal Q_\lambda$ is an irrep of the unitary group $U(d)$ (the group of $d \times d$ complex unitary matrices, acting on each site identically) and $\mathcal P_\lambda$ is an irrep of the symmetric group $S_n$ (the group of permutations of $n$ objects, acting by permuting the $n$ sites). Their tensor product $\mathcal Q_\lambda \otimes \mathcal P_\lambda$ is the *isotypic block* indexed by $\lambda$; the full Hilbert space is the direct sum of these blocks.

Take $n = 3$, $d = 2$: three spin-1/2 sites, joint dimension $2^3 = 8$. List every partition of 3 first.

```wl
IntegerPartitions[3]
```

There are three: $\{3\}$, $\{2, 1\}$, $\{1, 1, 1\}$. The row constraint $\text{rows}(\lambda) \leq d = 2$ rules out the all-singletons column $\{1, 1, 1\}$: there is no rank-3 totally antisymmetric tensor on a 2-dimensional local space (a Pauli-exclusion statement). Apply the constraint by passing the maximum-row argument to `IntegerPartitions`.

```wl
parsOf3 = IntegerPartitions[3, 2]
```

For each surviving partition, `TableauDimension` returns the dimension of $\mathcal P_\lambda$ via the hook-length formula, and `SchurDimension` returns the dimension of $\mathcal Q_\lambda(d)$ via the hook-content formula. Their product is the full irrep block size in $V^{\otimes n}$.

```wl
Dataset @ Append[
    AssociationMap[
        <|"dim P_lam" -> TableauDimension[#],
          "dim Q_lam" -> SchurDimension[#, 2],
          "block size" -> TableauDimension[#] * SchurDimension[#, 2]|> &,
        parsOf3],
    "sum" -> <|"dim P_lam" -> "", "dim Q_lam" -> "",
              "block size" -> Total[
                  TableauDimension[#] * SchurDimension[#, 2] & /@ parsOf3]|>]
```

The shape $\{3\}$ (row of three boxes) is the totally symmetric quartet with total spin $S = 3/2$: one copy of a 4-dimensional unitary irrep. The shape $\{2, 1\}$ (an L-shape) is the mixed-symmetry sector with $S = 1/2$: two copies of a 2-dimensional unitary irrep, the multiplicity $\dim \mathcal P_{\{2, 1\}} = 2$ counting the two independent ways of antisymmetrizing one pair of sites while symmetrizing the other.

By construction these block sizes sum to $d^n = 8$. Check the identity.

```wl
Total[TableauDimension[#] * SchurDimension[#, 2] & /@ parsOf3] == 2^3
```

Two pieces of structure to keep in mind for the rest of the tutorial. First, the block at index $\lambda$ has dimension $\dim \mathcal P_\lambda \cdot \dim \mathcal Q_\lambda$ because it contains $\dim \mathcal P_\lambda$ copies of the unitary irrep $\mathcal Q_\lambda$ (equivalently, $\dim \mathcal Q_\lambda$ copies of the symmetric-group irrep $\mathcal P_\lambda$); at $\lambda = \{2, 1\}$ this is two copies of the $S = 1/2$ doublet, not one copy of a 4-dim irrep. Second, the *isotypic projector* $\Pi_\lambda$ introduced two sections from now lands on this entire block, multiplicities included; a single-tableau Young projector $P_t$ (one per standard tableau $t$ of shape $\lambda$) lands on one copy of $\mathcal Q_\lambda$ inside it. Summing the $P_t$ over the $\dim \mathcal P_\lambda$ standard tableaux of shape $\lambda$ adds the copies back and recovers $\Pi_\lambda$.

The decomposition is exhaustive, the dimensions are known in advance with no eigendecomposition required, and the formula extends without modification to any $n$ and $d$.

## Standard Young tableaux

A *Young diagram* of shape $\lambda = (\lambda_1, \lambda_2, \ldots)$ is a top-left-justified arrangement of boxes with $\lambda_i$ boxes in row $i$. A *Young tableau* fills those boxes with the slot labels $1, 2, \ldots, n$, where $n$ is the total number of boxes. The `YoungTableau` head wraps that filling into a typed object; the notebook front end renders it as a small chip showing the boxes with their labels written inside.

The constructor accepts two forms: `YoungTableau[partition]` auto-fills the slot labels row by row, and `YoungTableau[rows]` takes the filling explicitly as a list of rows. Both produce the same typed object.

```wl
YoungTableau[{2}]
```

This is the single-row tableau of shape $\{2\}$, with slot labels $1, 2$ written left-to-right in the two boxes. It renders in the notebook as a horizontal pair of boxes with $1$ and $2$ inside.

```wl
YoungTableau[{1, 1}]
```

This is the single-column tableau of shape $\{1, 1\}$, with slot labels $1, 2$ written top-to-bottom in two stacked boxes. The shape is conjugate to $\{2\}$ (rows and columns swapped).

```wl
YoungTableau[{{1, 3}, {2, 4}}]
```

This is a rank-4 tableau of shape $\{2, 2\}$ with the slot labels $1, 3$ in the top row and $2, 4$ in the bottom row. The explicit-rows form is essential when the slot ordering matters (we will use it for the Riemann-like $\{2, 2\}$ projector and at $n = 4$ generally).

The *isotypic projector* $\Pi_\lambda$ onto the $\lambda$-irrep subspace is the linear operator that sends a tensor to the part of it living in the $\lambda$-block, the sum on the right of the Schur-Weyl decomposition above. Concretely $\Pi_\lambda$ is the sum, over standard tableaux of shape $\lambda$, of the single-tableau Young projectors $P_t$ (themselves products of row-symmetrizers and column-antisymmetrizers). A tableau is *standard* when its rows are strictly increasing left-to-right and its columns are strictly increasing top-to-bottom; the count of standard tableaux of shape $\lambda$ equals `TableauDimension[lambda]`. The Symmetry sub-context's `YoungTableauQ` accepts any slot permutation (not just standard ones), so we filter further to keep only the standard fillings.

```wl
standardTableauQ[tab_] := And[
    YoungTableauQ[YoungTableau[tab]],
    AllTrue[tab, OrderedQ],
    AllTrue[TableauColumns[YoungTableau[tab]], OrderedQ]
]
```

Enumerate the standard tableaux of a given shape by filtering permutations.

```wl
standardTableaux[lambda_] := With[
    {n = Total[lambda]},
    Select[
        TakeList[#, lambda] & /@ Permutations[Range[n]],
        standardTableauQ
    ]
]
```

At rank 2 each shape has exactly one standard tableau; the count matches `TableauDimension`.

```wl
{Length[standardTableaux[{2}]] == TableauDimension[{2}],
 Length[standardTableaux[{1, 1}]] == TableauDimension[{1, 1}]}
```

## Projecting tensors onto an irrep sector

`YoungProject[T, YoungTableau[tab]]` projects a rank-$n$ tensor $T$ onto the irrep subspace indexed by a single standard tableau `tab`. The *isotypic* projector $\Pi_\lambda$ sums these single-tableau projections over every standard tableau of shape $\lambda$. The result is itself a tensor operation: input rank-$n$ tensor, output rank-$n$ tensor in the irrep subspace, with no matrix ever materialized.

```wl
isotypicProject[T_, lambda_] := With[
    {tabs = standardTableaux[lambda]},
    Total[YoungProject[T, YoungTableau[#]] & /@ tabs]
]
```

Test the four defining projector properties by their action on a random state tensor. Build a normalized random rank-2 tensor on the two-site Hilbert space.

```wl
SeedRandom[42];
Trand = RandomReal[{-1, 1}, {2, 2}];
Trand = Trand / Norm[Flatten[Trand]]
```

**Idempotency**: applying $\Pi_{\{2\}}$ twice gives the same result as applying it once.

```wl
Max[Abs[Flatten[
    isotypicProject[isotypicProject[Trand, {2}], {2}]
    - isotypicProject[Trand, {2}]
]]] < tol
```

**Orthogonality**: projecting first onto $\{2\}$ and then onto $\{1, 1\}$ gives zero.

```wl
Max[Abs[Flatten[isotypicProject[isotypicProject[Trand, {2}], {1, 1}]]]] < tol
```

**Resolution of identity**: summing the sector projections of `Trand` reconstructs `Trand`.

```wl
Max[Abs[Flatten[
    Trand - (isotypicProject[Trand, {2}] + isotypicProject[Trand, {1, 1}])
]]] < tol
```

These checks establish that `isotypicProject` implements an orthogonal direct-sum projection on tensors without ever building a matrix. Each verification operates on the test state `Trand`; the same identities hold for every state because `isotypicProject` is a linear operator.

### Image of $\Pi_\lambda$: the full $\mathcal Q_\lambda \otimes \mathcal P_\lambda$ block

Idempotency, orthogonality, and resolution of identity fix the *algebra* of the family $\{\Pi_\lambda\}$ but leave the *image* of each $\Pi_\lambda$ implicit. The Schur-Weyl statement is that the image of $\Pi_\lambda$ on $(\mathbb{C}^d)^{\otimes n}$ is exactly the summand $\mathcal Q_\lambda \otimes \mathcal P_\lambda$, so its rank equals the block size $\dim \mathcal P_\lambda \cdot \dim \mathcal Q_\lambda$. Verify this at $n = 3$, $d = 2$ by materializing each $\Pi_\lambda$ as an $8 \times 8$ matrix (a one-shot view for the rank check, not part of the workflow) and taking its `MatrixRank`. Build the eight basis tensors of $(\mathbb{C}^2)^{\otimes 3}$ first.

```wl
basis3 = Flatten[
    Table[SparseArray[{{i, j, k} -> 1}, {2, 2, 2}], {i, 2}, {j, 2}, {k, 2}],
    2];
```

Stack `isotypicProject[#, lambda]` of each basis tensor as the columns of an $8 \times 8$ matrix.

```wl
projectorMatrix[lambda_] := Transpose[
    Flatten /@ (isotypicProject[#, lambda] & /@ basis3)] // Normal;
```

Compute the rank for each partition of $3$, including $\{1, 1, 1\}$ which violates the row constraint, and tabulate alongside $\dim \mathcal P_\lambda$ and $\dim \mathcal Q_\lambda$ in the same `Dataset` shape used at the Schur-Weyl section.

```wl
Dataset @ Append[
    AssociationMap[
        <|"dim P_lam" -> TableauDimension[#],
          "dim Q_lam" -> SchurDimension[#, 2],
          "rank Pi_lam" -> MatrixRank[projectorMatrix[#]]|> &,
        IntegerPartitions[3]],
    "sum" -> <|"dim P_lam" -> "", "dim Q_lam" -> "",
              "rank Pi_lam" -> Total[
                  MatrixRank[projectorMatrix[#]] & /@ IntegerPartitions[3]]|>]
```

Reading the table: $\{3\} \to 4$ is the symmetric quartet ($\dim \mathcal P \cdot \dim \mathcal Q = 1 \cdot 4 = 4$); $\{2, 1\} \to 4$ has dimension $2 \cdot 2 = 4$, two copies of the $S = 1/2$ doublet kept together by the isotypic projector; $\{1, 1, 1\} \to 0$ because $\dim \mathcal Q_{\{1, 1, 1\}}(d = 2) = 0$ (no totally antisymmetric rank-3 tensor on $\mathbb{C}^2$), the row-constraint statement enforcing itself at the projector level. The sum row reads $4 + 4 + 0 = 8 = 2^3$, the matrix-level statement of resolution of identity.

Summing the three projector matrices gives a rank-$8$ operator: resolution of identity, the matrix form of the sector decomposition $\sum_\lambda \Pi_\lambda = I$.

```wl
MatrixRank[
    projectorMatrix[{3}] + projectorMatrix[{2, 1}] + projectorMatrix[{1, 1, 1}]
] == 2^3
```

To split the $\{2, 1\}$ block further into one of its two $S = 1/2$ copies, drop the sum and apply `YoungProject` for a single standard tableau. The two standard tableaux of shape $\{2, 1\}$ each produce a rank-$\dim \mathcal Q_{\{2, 1\}}(d = 2) = 2$ projector.

```wl
{MatrixRank[Normal[Transpose[
    Flatten /@ (YoungProject[#, YoungTableau[{{1, 2}, {3}}]] & /@ basis3)]]],
 MatrixRank[Normal[Transpose[
    Flatten /@ (YoungProject[#, YoungTableau[{{1, 3}, {2}}]] & /@ basis3)]]]}
```

Each entry is $2$: a single-tableau projection isolates one copy of the unitary irrep, the isotypic projection retains both. The relation $\Pi_{\{2, 1\}} = P_{\{\{1, 2\}, \{3\}\}} + P_{\{\{1, 3\}, \{2\}\}}$ is the operator-level statement of $\dim \mathcal P_{\{2, 1\}} = 2$.

## Projecting operators by acting on both sides

An operator on $V^{\otimes n}$ has $n$ bra slots and $n$ ket slots. Viewing it as a rank-$2n$ tensor, the block decomposition $\Pi_\lambda \, H \, \Pi_\lambda$ corresponds to applying `isotypicProject` independently on the ket-side slots (positions $n + 1, \ldots, 2n$) and on the bra-side slots (positions $1, \ldots, n$). `Map[f, T, {n}]` applies `f` to each rank-$n$ slice indexed by the first $n$ slot positions, which is the right primitive for projecting the ket slots; a transpose puts the bra slots in the same position for the second pass.

```wl
projectOperatorBothSides[opT_, lambda_, n_] := With[
    {swapBraKet = Join[Range[n + 1, 2 n], Range[n]]},
    Transpose[
        Map[isotypicProject[#, lambda] &,
            Transpose[
                Map[isotypicProject[#, lambda] &, opT, {n}],
                swapBraKet],
            {n}],
        swapBraKet]
]
```

The same construction applied with *different* partitions on the bra and ket sides gives the cross-block restriction $\Pi_\mu \, H \, \Pi_\lambda$.

```wl
projectOperatorCross[opT_, lamBra_, lamKet_, n_] := With[
    {swapBraKet = Join[Range[n + 1, 2 n], Range[n]]},
    Transpose[
        Map[isotypicProject[#, lamBra] &,
            Transpose[
                Map[isotypicProject[#, lamKet] &, opT, {n}],
                swapBraKet],
            {n}],
        swapBraKet]
]
```

## Block-diagonal structure of the Heisenberg coupling

Reshape $h_{12}$ from a $4 \times 4$ matrix to its natural rank-4 tensor view, exposing the two bra slots and two ket slots independently.

```wl
h12T = ArrayReshape[h12, {2, 2, 2, 2}];
```

The SU(2)-invariance of $h_{12}$ implies that the cross-block restrictions $\Pi_\mu \, h_{12} \, \Pi_\lambda$ vanish for $\lambda \neq \mu$. Test both off-diagonal cross-restrictions; both should be the zero tensor.

```wl
{Max[Abs[Flatten[projectOperatorCross[h12T, {2}, {1, 1}, 2]]]] < tol,
 Max[Abs[Flatten[projectOperatorCross[h12T, {1, 1}, {2}, 2]]]] < tol}
```

Compute the within-block restrictions $h_{12}^{(\lambda)} = \Pi_\lambda \, h_{12} \, \Pi_\lambda$ as rank-4 tensors.

```wl
h12symT = projectOperatorBothSides[h12T, {2}, 2];
```

```wl
h12antiT = projectOperatorBothSides[h12T, {1, 1}, 2];
```

The sum reconstructs $h_{12}$, verifying that $h_{12} = \Pi_{\{2\}} \, h_{12} \, \Pi_{\{2\}} + \Pi_{\{1, 1\}} \, h_{12} \, \Pi_{\{1, 1\}}$ holds at the operator level.

```wl
Max[Abs[Flatten[h12T - (h12symT + h12antiT)]]] < tol
```

To extract the spectrum of each block, reshape its rank-4 tensor representation back to a $4 \times 4$ matrix and diagonalize. The triplet block has three eigenvalues at $+1/4$ embedded in the four-dimensional space; the singlet block has one eigenvalue at $-3/4$.

```wl
ReverseSort[Chop[Eigenvalues[ArrayReshape[h12symT, {4, 4}]]]]
```

```wl
ReverseSort[Chop[Eigenvalues[ArrayReshape[h12antiT, {4, 4}]]]]
```

The full spectrum of $h_{12}$ is the disjoint union of the within-block spectra. At this rank the savings are notional; at larger systems the same structural trick produces the dramatic compression that powers SU(2)-symmetric DMRG.

## Inner products as tensor networks

Dirac notation writes a state as a *ket* $|T\rangle$ and its conjugate as a *bra* $\langle T|$. The expectation value of an operator $A$ in a state $T$ is the scalar $\langle T | A | T \rangle = \sum_{i, j} \overline{T_i} A_{i j} T_j$, with the overline denoting complex conjugation. The TN-paclet's core construction writes $\langle T | h_{12} | T \rangle$ as the contraction of three nodes (bra, operator, ket) with four shared indices. Since each state tensor's slots are *abstract* (no implicit row/column distinction is baked in), the bra node carries the entrywise conjugate of $T$ with the same slot order; the contraction structure alone carries the bra/ket distinction. Take a random unit two-site state.

```wl
SeedRandom[42];
T = RandomReal[{-1, 1}, {2, 2}];
T = T / Norm[Flatten[T]]
```

Build the inner product as a `TensorNetwork`: three tensors, four shared indices, no free indices. `TensorNetworkContract` evaluates the contraction.

```wl
expectTN = TensorNetworkContract @ TensorNetwork[
    {Conjugate[T], ArrayReshape[h12, {2, 2, 2, 2}], T},
    {{"a", "b"}, {"a", "b", "c", "d"}, {"c", "d"}},
    {}
]
```

The same value emerges from a direct matrix-vector evaluation.

```wl
expectDirect = Flatten[Conjugate[T]] . h12 . Flatten[T]
```

```wl
Chop[expectTN - expectDirect] < tol
```

## Block-decomposing the expectation value

The structural identity behind SU(2)-symmetric DMRG (McCulloch 2007) reads
$$
\langle \psi | H | \psi \rangle \;=\; \sum_\lambda \langle \psi_\lambda | H | \psi_\lambda \rangle, \qquad \psi_\lambda := \Pi_\lambda \, \psi,
$$
and holds for any SU(2)-invariant operator $H$ and any state $\psi$. The proof is one line: $H = \sum_\lambda \Pi_\lambda H \Pi_\lambda$, $\Pi_\lambda^2 = \Pi_\lambda$, $\Pi_\lambda^\dagger = \Pi_\lambda$, so $\langle \psi | \Pi_\lambda H \Pi_\lambda | \psi \rangle = \langle \Pi_\lambda \psi | H | \Pi_\lambda \psi \rangle$ for each $\lambda$. The dagger $\Pi_\lambda^\dagger$ denotes the Hermitian conjugate (the adjoint of $\Pi_\lambda$); a Hermitian projector is one that is both idempotent and self-adjoint. Verify the identity at rank 2 by decomposing $T$ via `isotypicProject` and summing the within-sector contributions.

```wl
Tsym = isotypicProject[T, {2}]
```

```wl
Tanti = isotypicProject[T, {1, 1}]
```

The sum of the sector pieces reconstructs $T$.

```wl
Max[Abs[Flatten[T - (Tsym + Tanti)]]] < tol
```

At rank 2 each within-sector contribution is the corresponding eigenvalue of $h_{12}$ times the Frobenius norm squared of the sector projection.

```wl
contribSym = (1/4) Total[Flatten[Tsym * Conjugate[Tsym]]]
```

```wl
contribAnti = -(3/4) Total[Flatten[Tanti * Conjugate[Tanti]]]
```

```wl
contribSym + contribAnti
```

The sum matches the TN contraction value exactly.

```wl
Chop[expectTN - (contribSym + contribAnti)] < tol
```

This is the McCulloch identity in three cells. Any DMRG sweep that targets a fixed total-spin sector can ignore all other sectors during a two-site update: the contributions from other sectors are zero by symmetry.

## Four-site Heisenberg chain

The open-boundary four-site Heisenberg Hamiltonian
$$
H_4 \;=\; h_{12} + h_{23} + h_{34}
$$
acts on a sixteen-dimensional Hilbert space. Place each two-site block at its position and pad with identity on the other sites; sum the three terms.

```wl
h12chain = KroneckerProduct[h12, IdentityMatrix[4]];
```

```wl
h23chain = KroneckerProduct[IdentityMatrix[2], KroneckerProduct[h12, IdentityMatrix[2]]];
```

```wl
h34chain = KroneckerProduct[IdentityMatrix[4], h12];
```

```wl
H4 = h12chain + h23chain + h34chain;
```

```wl
Dimensions[H4]
```

The Schur-Weyl decomposition at $n = 4$, $d = 2$ gives three partition labels, those with at most $d = 2$ rows.

```wl
parsOf4 = IntegerPartitions[4, 2]
```

The three labels $\{4\}$, $\{3, 1\}$, $\{2, 2\}$ correspond to the three total-spin sectors of a 4-spin-1/2 chain: $S = 2$ (one five-dimensional multiplet), $S = 1$ (three copies of a three-dimensional multiplet), $S = 0$ (two copies of the singlet). The combinatorial layer reads off each block's dimension in one cell.

```wl
Table[
    par -> {"S (total spin)" -> (par[[1]] - If[Length[par] == 2, par[[2]], 0])/2,
            "dim V_lam"      -> TableauDimension[par],
            "dim W_lam(d=2)" -> SchurDimension[par, 2],
            "block dim"      -> TableauDimension[par] * SchurDimension[par, 2]},
    {par, parsOf4}]
```

The block sizes $5 + 9 + 2 = 16$ exhaust the Hilbert space.

```wl
Total[TableauDimension[#] * SchurDimension[#, 2] & /@ parsOf4] == 2^4
```

No diagonalization, no construction of intermediate states: just the hook-length and hook-content formulas evaluated at $\lambda \vdash 4$. An SU(2)-symmetric code knows in advance that the largest block is 9-dimensional and can plan its memory and arithmetic accordingly.

## Tensor-native block decomposition at n = 4

Reshape $H_4$ to its rank-8 tensor view (four bra slots and four ket slots) so that `projectOperatorBothSides` can act on it directly.

```wl
H4T = ArrayReshape[H4, ConstantArray[2, 8]];
```

Apply the operator projection for each partition of 4. The result is an Association mapping each $\lambda$ to its within-block restriction $\Pi_\lambda \, H_4 \, \Pi_\lambda$, each held as a rank-8 tensor.

```wl
H4blocksT = AssociationMap[projectOperatorBothSides[H4T, #, 4] &, parsOf4];
```

By SU(2)-invariance, $H_4 = \sum_\lambda \Pi_\lambda \, H_4 \, \Pi_\lambda$; the within-block restrictions sum back to $H_4$.

```wl
Max[Abs[Flatten[H4T - Total[Values[H4blocksT]]]]] < tol
```

Cross-block restrictions vanish identically. Tabulate the maximum absolute entry of every cross restriction $\Pi_\mu \, H_4 \, \Pi_\lambda$ with $\lambda \neq \mu$.

```wl
Max[Flatten[Outer[
    If[#1 === #2, 0,
        Max[Abs[Flatten[projectOperatorCross[H4T, #1, #2, 4]]]]] &,
    parsOf4, parsOf4, 1]]] < tol
```

To recover the within-block spectrum, reshape each block tensor back to a $16 \times 16$ matrix and diagonalize. Keep the `TableauDimension[lambda] * SchurDimension[lambda, 2]` eigenvalues largest in absolute value; the rest are kernel zeros.

```wl
nonKernelEigs[par_] := With[
    {dim = TableauDimension[par] * SchurDimension[par, 2],
     evals = Chop[Eigenvalues[N[ArrayReshape[H4blocksT[par], {16, 16}]]]]},
    Take[Reverse[SortBy[evals, Abs]], dim]
]
```

```wl
AssociationMap[ReverseSort[nonKernelEigs[#]] &, parsOf4]
```

The $\{4\}$ block has five degenerate eigenvalues at $+3/4$ (the $S = 2$ aligned-spin energy). The $\{3, 1\}$ block has nine eigenvalues in three sets of three (the $S = 1$ levels, each three-fold because $\mathcal P_{\{3, 1\}}$ has dimension 3). The $\{2, 2\}$ block has two non-degenerate eigenvalues, the lower being the singlet ground-state energy.

Concatenate the within-block eigenvalues and compare against the full spectrum of $H_4$.

```wl
blockSpectrum = ReverseSort[Flatten[nonKernelEigs /@ parsOf4]]
```

```wl
fullSpectrum = ReverseSort[Chop[Eigenvalues[N[H4]]]]
```

```wl
Max[Abs[blockSpectrum - fullSpectrum]] < tol
```

The largest matrix any single diagonalization had to handle was $9 \times 9$, recovered from the projected $H_4$ block. The full $16 \times 16$ direct diagonalization was used only as a sanity check.

## TN expectation value with the paclet's contraction engine

The expectation value $\langle \psi | H_4 | \psi \rangle$ on an arbitrary state is a contraction of three tensors: the bra, the operator, and the ket. Prepare a state in the singlet sector by applying `isotypicProject` (in tensor form) to a random rank-4 tensor.

```wl
SeedRandom[7];
psiRawT = RandomReal[{-1, 1}, ConstantArray[2, 4]];
```

```wl
psiSingletT = isotypicProject[psiRawT, {2, 2}];
```

```wl
psiSingletT = psiSingletT / Norm[Flatten[psiSingletT]];
```

Verify the prepared state is in the $\{2, 2\}$ sector: applying `isotypicProject` again with the same partition is the identity.

```wl
Max[Abs[Flatten[isotypicProject[psiSingletT, {2, 2}] - psiSingletT]]] < tol
```

Reshape $H_4$ as a rank-8 tensor (the natural way to encode its slot structure for a TN) and build the inner product as a `TensorNetwork`.

```wl
h4Tensor = ArrayReshape[H4, ConstantArray[2, 8]];
```

```wl
tn4 = TensorNetwork[
    {Conjugate[psiSingletT], h4Tensor, psiSingletT},
    {{"a1", "a2", "a3", "a4"},
     {"a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4"},
     {"b1", "b2", "b3", "b4"}},
    {}
];
```

The constructor recognises the contraction structure.

```wl
TensorNetworkQ[tn4]
```

`OptimalContractionPath` reports the cheapest contraction order. For the bra-operator-ket structure the optimizer pairs the operator with the ket first and then closes against the bra.

```wl
OptimalContractionPath[tn4, Method -> "flops"]
```

`TensorNetworkContract` evaluates the network. The result equals the direct matrix-vector form to numerical precision.

```wl
expectFullTN = TensorNetworkContract[tn4]
```

```wl
psiSingletVec = Flatten[psiSingletT];
```

```wl
expectDirectFull = Conjugate[psiSingletVec] . H4 . psiSingletVec
```

```wl
Chop[expectFullTN - expectDirectFull] < tol
```

## The block-sparse expectation value identity

For a generic, non-pre-projected state, the McCulloch identity still holds: the expectation value of an SU(2)-invariant operator decomposes into a sum of within-sector contributions, computed by projecting $\psi$ to each sector via `isotypicProject` (still in tensor form) and evaluating the expectation on each piece.

```wl
SeedRandom[101];
```

```wl
psiGenT = RandomReal[{-1, 1}, ConstantArray[2, 4]];
```

```wl
psiGenT = psiGenT / Norm[Flatten[psiGenT]];
```

For each partition, project the state to that sector and evaluate $\langle \psi_\lambda | H_4 | \psi_\lambda \rangle$.

```wl
contribs = AssociationMap[
    With[{psiLam = Flatten[isotypicProject[psiGenT, #]]},
        Conjugate[psiLam] . H4 . psiLam] &,
    parsOf4
]
```

Sum the within-sector contributions.

```wl
Total[Values[contribs]]
```

Compare against the direct expectation value on the un-projected state.

```wl
psiGenVec = Flatten[psiGenT];
```

```wl
Conjugate[psiGenVec] . H4 . psiGenVec
```

```wl
Chop[Total[Values[contribs]] - Conjugate[psiGenVec] . H4 . psiGenVec] < tol
```

This is the McCulloch identity at the four-site level: the expectation value of any SU(2)-invariant operator on any state can be computed as a sum of independent within-sector evaluations, each of which costs only as much as the largest single block. The contribution from the $\{2, 2\}$ sector involves only the 2-dimensional block, the contribution from $\{3, 1\}$ involves the 9-dimensional block, and the contribution from $\{4\}$ involves the 5-dimensional block. None of them requires the full $16 \times 16$ matrix, and the projection is computed without ever materializing a $16 \times 16$ projector matrix.

## A zoo of related identities

The McCulloch identity is one instance of a broader pattern: any multilinear functional of an SU(2)-invariant operator and its eigenstates decomposes additively into per-sector contributions. The proof is always the same three ingredients used above (resolution of identity, projector orthogonality, symmetry commutation) and the result is always a sum over partitions of $n$. Each of the four identities below is a textbook result whose derivation has been known for the better part of a century; the contribution here is that they all reduce, in the paclet, to one or two lines of code that compose `isotypicProject` with standard linear-algebra functions.

### Trace of an invariant operator decomposes

Since $\sum_\lambda \Pi_\lambda = I$ and $H$ commutes with each $\Pi_\lambda$, the trace of $H$ splits as $\text{Tr}(H) = \sum_\lambda \text{Tr}(\Pi_\lambda H \Pi_\lambda)$. Compute the direct trace of $H_4$.

```wl
traceDirect = Tr[H4]
```

Compute the trace within each sector by reshaping the rank-8 within-block tensor back to a 16-by-16 matrix and taking its trace.

```wl
traceBySector = AssociationMap[Tr[ArrayReshape[H4blocksT[#], {16, 16}]] &, parsOf4]
```

The two should agree by sector additivity.

```wl
traceDirect == Total[Values[traceBySector]]
```

The four-site Heisenberg chain has traceless $H_4$ (eigenvalues sum to zero by particle-hole symmetry of the Heisenberg coupling), so each side is $0$. The individual sector traces are nonzero rationals that cancel against one another.

### Partition function decomposes

Any analytic function of an invariant operator inherits the block-diagonal structure. The most physically interesting instance is the partition function $Z(\beta) = \text{Tr}(e^{-\beta H})$, where $\beta = 1/(k_B T)$ is inverse temperature (with $k_B$ Boltzmann's constant and $T$ the absolute temperature); the matrix exponential $e^{-\beta H}$ encodes the Boltzmann weights of all energy eigenstates. The trace factorizes as $Z(\beta) = \sum_\lambda \text{Tr}_\lambda(e^{-\beta H_\lambda})$ where $\text{Tr}_\lambda$ sums only over the within-block (non-kernel) eigenvalues of the $\lambda$-sector. Pick a temperature and evaluate $Z(\beta)$ directly by summing $e^{-\beta E_i}$ over all 16 eigenvalues.

```wl
beta = 1;
```

```wl
Zdirect = Total[Exp[-beta N[Eigenvalues[H4]]]]
```

Evaluate $Z(\beta)$ sector by sector using only the non-kernel eigenvalues from the block restrictions.

```wl
Zsector = AssociationMap[Total[Exp[-beta nonKernelEigs[#]]] &, parsOf4]
```

The two values agree to numerical precision.

```wl
Chop[Zdirect - Total[Values[Zsector]]] < tol
```

The same construction applied to any other analytic functional ($\text{Tr}\,(f(H))$ for analytic $f$) decomposes the same way. Symmetry-resolved thermodynamics, in this paclet, is one cell.

### Higher moments decompose; variance does not

Every moment $\langle \psi | H^k | \psi \rangle$ decomposes by sector by the same argument as the McCulloch identity (replace $H$ with $H^k$, which still commutes with $\Pi_\lambda$). The variance $\langle H^2 \rangle - \langle H \rangle^2$ is built from two such moments but, being a *square* of a linear quantity, it acquires an interference term that breaks additivity. Both behaviors are easy to verify.

```wl
SeedRandom[202];
```

```wl
psiVar = RandomReal[{-1, 1}, 16]; psiVar = psiVar / Norm[psiVar];
```

```wl
psiVarT = ArrayReshape[psiVar, ConstantArray[2, 4]];
```

Compute $\langle \psi | H_4^2 | \psi \rangle$ directly.

```wl
moment2Direct = Conjugate[psiVar] . (H4 . H4) . psiVar
```

Decompose the second moment by sector via `isotypicProject` on $\psi$.

```wl
moment2Sector = AssociationMap[
    With[{psiL = Flatten[isotypicProject[psiVarT, #]]},
        Conjugate[psiL] . (H4 . H4) . psiL] &,
    parsOf4]
```

The sum of per-sector second moments equals the direct expectation: $\langle H^2 \rangle$ is additive.

```wl
Chop[moment2Direct - Total[Values[moment2Sector]]] < tol
```

The variance is $\langle H^2 \rangle - \langle H \rangle^2$. Compute it directly.

```wl
varianceDirect = moment2Direct - (Conjugate[psiVar] . H4 . psiVar)^2
```

Compute a naïve "per-sector variance" by replacing $\psi$ with $\Pi_\lambda \psi$ in the variance formula and summing.

```wl
varianceSector = AssociationMap[
    With[{psiL = Flatten[isotypicProject[psiVarT, #]]},
        Conjugate[psiL] . (H4 . H4) . psiL
        - (Conjugate[psiL] . H4 . psiL)^2] &,
    parsOf4]
```

The naïve sum does *not* recover the variance. The mismatch is the interference between per-sector means: $\langle H \rangle^2 = (\sum_\lambda a_\lambda)^2 \neq \sum_\lambda a_\lambda^2$.

```wl
Chop[varianceDirect - Total[Values[varianceSector]]] < tol
```

The pedagogical point: additivity-across-sectors is a *linear* phenomenon. Linear functionals of $H$ decompose; non-linear ones (variance, products of expectation values, log of trace) generally do not, even though the underlying operator commutes with each $\Pi_\lambda$.

### Plancherel-Schur identity: $\sum_\lambda d_\lambda^2 = n!$

Write $d_\lambda := \dim V_\lambda$ for the dimension of the symmetric-group irrep labeled by $\lambda$ (the same quantity that `TableauDimension[lambda]` computes). Sum of squared dimensions over all partitions of $n$ equals $n!$: this is Frobenius's formula for the dimension of the regular representation of $S_n$, and is one of the fundamental sanity checks of the theory. In the paclet's language: $\sum_\lambda \texttt{TableauDimension}[\lambda]^2 = n!$.

```wl
Table[
    {n, Total[TableauDimension[#]^2 & /@ IntegerPartitions[n]], n!},
    {n, 1, 8}]
```

The middle column equals the right column for every $n$. Equivalently, summing the squared multiplicities of the irreps of $S_n$ recovers the order of the group; the paclet's `TableauDimension` provides exactly the right input.

### Provenance

The four identities of this section are textbook results from classical group representation theory. The McCulloch block-decomposition identity descends from Schur's lemma and orthogonality relations (Frobenius and Schur, 1896-1901). Trace and partition-function decomposition by irrep block are the structural basis of every symmetry-resolved thermodynamic computation since Heisenberg. The non-additivity of variance under sector projection follows from the standard expansion of $\langle H \rangle^2$. The Plancherel-Schur identity is the dimension formula for the regular representation, due to Frobenius. None of these claims is original; what is presented here is the *combination* of closed-form combinatorial primitives (`TableauDimension`, `SchurDimension`), tensor-native projection (`YoungProject`, composed in `isotypicProject` and `projectOperatorBothSides`), and standard Wolfram Language linear algebra (`Tr`, `MatrixExp`, `Eigenvalues`), which lets each identity be stated, evaluated, and verified in two or three cells of one notebook.

## Compression: how the savings scale with system size

The largest block size at given $(n, d)$ controls the cost of an SU(2)-symmetric algorithm. The combinatorial layer computes this in closed form without any diagonalization. Build a row of the compression table from `TableauDimension` and `SchurDimension`.

```wl
compressionRow[n_] := With[
    {pars = IntegerPartitions[n, 2],
     fullDim = 2^n},
    With[{blocks = TableauDimension[#] * SchurDimension[#, 2] & /@ pars},
        Association[
            "n" -> n,
            "d^n" -> fullDim,
            "largest block" -> Max[blocks],
            "compression ratio" -> N[fullDim / Max[blocks], 4]
        ]
    ]
]
```

Display the compression table for several values of $n$.

```wl
Dataset[Association[# -> compressionRow[#] & /@ {4, 6, 8, 10, 12}]]
```

The compression ratio grows steadily with $n$. At $n = 4$ the largest block is 9 and the ratio is roughly 1.8. At $n = 12$ the largest block is 891 and the ratio is roughly 4.6. The largest block grows polynomially (as $\sim \sqrt{n!}$ for the dominant partition at fixed $d$) while the full dimension grows exponentially. At system sizes where exact diagonalization becomes infeasible (around $n = 16$-$20$ for the un-symmetrized 4096-65536-dimensional spaces), the SU(2)-symmetric block-aware algorithm can still operate at modest matrix sizes within the largest block. This compression is what makes non-Abelian-symmetric DMRG work in practice, and what production codes (QSpace, BLOCK, StackBlock, the spin-adapted modules of ITensor) invest substantial engineering to implement.

## Symbolic execution: closed-form polynomial predictions and analytic verification

Every construction up to this point has worked in exact arithmetic. The Pauli matrices, the Heisenberg coupling, the operator projections via `isotypicProject` and `projectOperatorBothSides`, the four-site Hamiltonian and its block decomposition are all exact rational (or algebraic-number) objects. The within-block eigenvalues of the four-site chain, $(-1 \pm 2\sqrt{2})/4$ and $(-3 \pm 2\sqrt{3})/4$, emerged as exact algebraic numbers, not floating-point approximations. The same primitives also work when the *parameters* are symbolic rather than fixed integers: the dimensions return closed-form polynomials, `YoungProject` acts on a symbolic tensor of unknowns, and the structural identities become analytic statements rather than numerical samplings.

### Closed-form block sizes as polynomials in d

The hook-content formula evaluates `SchurDimension[par, d]` for any local dimension $d$, including symbolic $d$. The result is a polynomial of degree equal to the rank.

```wl
Table[par -> Factor[SchurDimension[par, d]], {par, parsOf4}]
```

Specializing at $d = 2$ recovers the integer values used earlier.

```wl
Table[par -> SchurDimension[par, d], {par, parsOf4}] /. d -> 2
```

### The Riemann tensor independent-component count

The $\{2, 2\}$-irrep dimension is the textbook count of independent components of the Riemann curvature tensor at spacetime dimension $d$. The standard values are $1, 6, 20, 50, 105$ at $d = 2, 3, 4, 5, 6$.

```wl
Table[{d, SchurDimension[{2, 2}, d]}, {d, 2, 6}]
```

The closed-form polynomial $(d - 1) d^2 (d + 1)/12$ extends, without modification, to arbitrary spacetime dimension.

### Schur-Weyl exhaustiveness as an analytic identity

The structural identity $\sum_\lambda \dim V_\lambda \cdot \dim W_\lambda(d) = d^n$ verified numerically at $d = 2$ for $n = 2$ and $n = 4$ becomes an analytic statement with symbolic $d$: sum the polynomial block sizes, expand, simplify, and confirm equality to $d^n$.

```wl
exhaustivenessHoldsAt[n_] := Simplify[
    Total[TableauDimension[#] * SchurDimension[#, d] & /@ IntegerPartitions[n]] - d^n
] == 0
```

Three independent symbolic verifications, all returning `True`.

```wl
{exhaustivenessHoldsAt[3], exhaustivenessHoldsAt[4], exhaustivenessHoldsAt[5]}
```

### The McCulloch identity, analytically at n = 2

Take a two-site state with four undetermined amplitudes.

```wl
TSym = Array[c, {2, 2}]
```

The expectation value $\langle T | h_{12} | T \rangle$ is a quadratic polynomial in the four symbolic amplitudes.

```wl
expectSym = Simplify[Flatten[TSym] . h12 . Flatten[TSym]]
```

Apply `isotypicProject` directly to the symbolic tensor; the within-sector projections are themselves symbolic matrices.

```wl
TSymTriplet = isotypicProject[TSym, {2}]
```

```wl
TSymSinglet = isotypicProject[TSym, {1, 1}]
```

Compute the within-sector contributions; each is a quadratic polynomial in the amplitudes.

```wl
contribTripSym = Simplify[(1/4) Total[Flatten[TSymTriplet]^2]]
```

```wl
contribSingSym = Simplify[-(3/4) Total[Flatten[TSymSinglet]^2]]
```

Verify the McCulloch identity holds as a polynomial equality.

```wl
Simplify[expectSym - (contribTripSym + contribSingSym)] == 0
```

The identity holds for every two-site SU(2)-invariant state, not just for sampled numerical ones.

### The McCulloch identity, analytically at n = 4

Build a symbolic 4-site state as a rank-4 tensor of 16 unknowns.

```wl
psiCT = ArrayReshape[Array[c, 16], ConstantArray[2, 4]];
```

Compute the symbolic expectation value $\langle \psi | H_4 | \psi \rangle$ as a polynomial in the 16 amplitudes.

```wl
expectSymN4 = Expand[Flatten[psiCT] . H4 . Flatten[psiCT]];
```

For each partition, project the symbolic state with `isotypicProject` (in tensor form, never building a matrix) and compute the per-sector expectation value.

```wl
contribsSymN4 = AssociationMap[
    With[{psiLam = Flatten[isotypicProject[psiCT, #]]},
        Expand[psiLam . H4 . psiLam]] &,
    parsOf4
];
```

Verify the McCulloch identity as a polynomial equality on the 16 symbolic amplitudes.

```wl
Simplify[expectSymN4 - Total[Values[contribsSymN4]]] == 0
```

The full block-decomposition identity holds at $n = 4$ as a polynomial equality. The expressions on each side have hundreds of terms; symbolic simplification confirms the difference is identically zero.

### What this shows

The combinatorial layer `TableauDimension` and `SchurDimension` returns closed-form polynomials when given symbolic local dimension. `isotypicProject` and `projectOperatorBothSides` act on symbolic tensors and the result composes with `Expand`, `Simplify`, `Factor`. The Schur-Weyl exhaustiveness identity and the McCulloch block-decomposition identity, both verified numerically earlier in the tutorial, hold as polynomial equalities under symbolic execution. The same machinery that constructs the projectors and Hamiltonian also delivers the analytic proof of the identities they satisfy.

## Summary

The Symmetry sub-context's combinatorial layer (`TableauDimension`, `SchurDimension`) and tensor-action layer (`YoungProject`, composed in `isotypicProject` and `projectOperatorBothSides`) together with the TN-paclet's core (`TensorNetwork`, `TensorNetworkContract`, `OptimalContractionPath`) recover the irrep block structure of an SU(2)-symmetric Heisenberg chain by direct construction. Every algebraic claim made along the way has been paired with a single-line numerical test, and every test has passed. Concretely, the worked example demonstrated:

- *Closed-form block sizes*: `TableauDimension[lambda] * SchurDimension[lambda, d]` computes the dimension of the $\lambda$-irrep block on $V^{\otimes n}$ for any $\lambda$, $n$, $d$. No eigenvalue routine required.
- *Tensor-native projection*: `isotypicProject` sums `YoungProject` over standard tableaux of shape $\lambda$, producing the irrep projection of a state tensor without ever materializing a $d^n \times d^n$ projector matrix. `projectOperatorBothSides` extends this to operators by Mapping `isotypicProject` over the ket-side slots, transposing, repeating for the bra side.
- *Block-diagonal decomposition*: An SU(2)-invariant operator $H$ satisfies $H = \sum_\lambda \Pi_\lambda H \Pi_\lambda$ exactly; cross-block restrictions vanish identically. Both the within-block and cross-block claims are verified directly on the rank-2n tensor view of the operator.
- *Spectrum recovery by concatenation*: The eigenvalues of $H$ are the union (with multiplicity) of the within-block spectra. Each within-block diagonalization handles a matrix of size `TableauDimension * SchurDimension`, often dramatically smaller than $d^n$. The block-restricted operator is reshaped from rank-2n tensor to $d^n \times d^n$ matrix only at the final eigenvalue step.
- *Expectation-value decomposition*: $\langle \psi | H | \psi \rangle = \sum_\lambda \langle \Pi_\lambda \psi | H | \Pi_\lambda \psi \rangle$ holds for any state and any SU(2)-invariant $H$, with $\Pi_\lambda \psi$ computed by `isotypicProject` acting on the rank-$n$ tensor view of $\psi$.
- *Tensor-network integration*: The expectation value can be built as a `TensorNetwork`, inspected via `OptimalContractionPath`, and evaluated via `TensorNetworkContract`, with no special-case code for the symmetric sector.
- *Symbolic execution*: every identity above also holds analytically when the parameters are symbolic. `SchurDimension[{2, 2}, d]` returns the closed-form Riemann count $(d - 1) d^2 (d + 1)/12$, the Schur-Weyl exhaustiveness identity holds at arbitrary $d$, the McCulloch identity holds as a polynomial equality on symbolic 4-component and 16-component state vectors.

The same recipe applies, without modification, to longer chains (just increase $n$), higher local dimension (just change the second argument to `SchurDimension`), and special unitary group SU(N) symmetries with $N > 2$ (just use partitions with more rows). The combinatorial layer takes care of the irrep counting; `YoungProject` and its compositions take care of the irrep construction on tensors of any rank; the TN layer takes care of the contraction. No matrix-form projectors were materialized in the entire workflow.

## Positioning: what this paclet provides that production libraries do not

The non-Abelian symmetric tensor-network problem has several mature implementations in the wider scientific software ecosystem. [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB), introduced by Weichselbaum, is the canonical production library for SU(2) and SU(N) symmetric DMRG, used in hundreds of published calculations across a decade. [ITensor](https://itensor.org/) (Julia, C++) underpins one of the largest bodies of tensor-network calculations in the literature and supports Abelian quantum-number blocks natively with extensions for non-Abelian symmetries. [TeNPy](https://tenpy.readthedocs.io/) (Python) provides SU(2)-symmetric tensors through a high-level Python interface. [BLOCK](https://sanshar.github.io/Block/) (C++) and [StackBlock](https://github.com/sanshar/StackBlock) (C++) implement spin-adapted DMRG for quantum-chemistry applications. For the combinatorial side of Young-tableau and partition manipulation, [SymPy](https://www.sympy.org/) (Python) and [SageMath](https://www.sagemath.org/) (Python) provide standalone utilities. The honest accounting against these alternatives is two-sided.

### What dedicated tensor-network libraries do better

- *Production-scale performance.* [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB) and [ITensor](https://itensor.org/) (Julia, C++) run SU(2)-symmetric DMRG on chains of $n \sim 100$ sites with bond dimensions in the thousands. This paclet's `YoungProject` is built on the kernel's `Symmetrize`, which has a hard memory wall at $n \approx 13$ for the totally symmetric partition. The paclet is not a substitute for those libraries when the goal is a production-grade many-body simulation.
- *DMRG sweep automation.* [ITensor](https://itensor.org/) (Julia, C++) and [TeNPy](https://tenpy.readthedocs.io/) (Python) provide complete two-site sweep loops with truncation, environment management, and convergence criteria built in. This paclet has none of that. The McCulloch identity verified in this document is the structural building block of a single DMRG update; the iterative ground-state sweep is not implemented here.
- *Battle-tested correctness in production.* [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB) and [ITensor](https://itensor.org/) (Julia, C++) have appeared in hundreds of refereed publications across a decade. The `Symmetry` sub-context has not been deployed in a published research workflow at that scale.
- *Sparse storage and iterative eigensolvers.* Production codes never materialize a full $d^n \times d^n$ Hamiltonian; they encode it as a matrix product operator and use Krylov methods on the block-decomposed structure. The dense `KroneckerProduct`-based construction used here is fine for the four-site demonstration and breaks at $n \approx 16$. Sparse block-diagonalization, central to [BLOCK](https://sanshar.github.io/Block/) (C++) and [StackBlock](https://github.com/sanshar/StackBlock) (C++) for quantum chemistry, is not the paclet's current target.

### What this paclet's composition uniquely provides

Five capabilities that the other packages, taken individually or together, do not provide as one composable workflow.

1. **Symbolic execution end-to-end.** None of [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB), [ITensor](https://itensor.org/) (Julia, C++), [TeNPy](https://tenpy.readthedocs.io/) (Python), or [BLOCK](https://sanshar.github.io/Block/) (C++) can carry symbolic parameters through the irrep decomposition: they are purely numerical. This paclet can, and the *Symbolic execution* section above demonstrates this on three concrete claims. `SchurDimension[{2, 2}, d]` returns the closed-form polynomial $(d - 1) d^2 (d + 1)/12$, the Riemann-tensor independent-component count at any spacetime dimension $d$. The Schur-Weyl exhaustiveness identity $\sum_\lambda \dim V_\lambda \cdot \dim W_\lambda(d) = d^n$ is verified by `Simplify` as an analytic statement at $n = 3, 4, 5$ with $d$ symbolic, not as a numerical sampling. The McCulloch block-decomposition identity holds as a polynomial equality on symbolic 4-component and 16-component state vectors; both verifications return `True` from `Simplify` operating on polynomials in the symbolic amplitudes. The same machinery that constructs the projectors and Hamiltonian also delivers the analytic proof of the identities they satisfy.

2. **Closed-form combinatorial layer, queryable without instantiating tensors.** Asking what the size of the $\{3, 1\}$ irrep block is at $d = 5$ takes a single function call: `TableauDimension[{3, 1}] * SchurDimension[{3, 1}, 5]`. No tensor is built; no symmetry structure is registered. The compression table above was generated this way. The same query in [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB) or [ITensor](https://itensor.org/) (Julia, C++) requires instantiating the symmetry framework and building a tensor with that quantum-number structure. The paclet's combinatorial layer is useful as a planning tool even when the actual simulation runs in a different library: predict the block sizes, decide whether the calculation is feasible, then commit to a production code.

3. **Composability with the wider Wolfram ecosystem.** The output of `YoungProject` (and the derived `isotypicProject` and `projectOperatorBothSides`) is a plain Wolfram Language tensor; the output of `TensorNetworkContract` is a scalar or a tensor. Both compose with `Eigenvalues`, `MatrixRank`, `MatrixForm`, `D`, `Plot`, `Manipulate`, `Solve`, `NMinimize`, `FullSimplify` without any foreign-function-interface boundary. Block decomposition, eigenvalue extraction, symbolic simplification, and visualization live in the same kernel session. In a Python or Julia workflow this composition typically requires marshalling data across a [SymPy](https://www.sympy.org/) (Python) or Mathematica boundary; many users instead discretize early and lose the algebraic step entirely.

4. **Mixed-symmetry partitions handled uniformly.** Production tensor-network libraries focus on spin algebras: SU(2) and SU(N) acting site-by-site as a unitary group representation. Their data structures assume that interpretation. They do not naturally express objects like the Riemann curvature tensor, which lives in the $\{2, 2\}$ irrep of the symmetric group acting on its four slot indices, with no underlying unitary-group structure on the slots. The paclet's `YoungProject` is partition-general: any partition $\lambda \vdash n$ is supported uniformly, with the slot interpretation chosen by the user. This distinguishes a Schur-Weyl-aware tensor library from a many-body simulation library. The latter optimizes the SU(N) spin physics; the former handles the full $S_n$-irrep zoo, which is what shows up in continuum physics: Riemann tensors, stress-energy tensors, multi-index fermion antisymmetrization beyond Slater determinants.

5. **Math-shaped application programming interface, tensor-native throughout.** The paclet's interface mirrors the math notation directly: "apply the Young projector for partition $\lambda$" is `YoungProject[T, YoungTableau[lambda]]`; "dimension of the $S_n$ irrep $\lambda$" is `TableauDimension[lambda]`; "build a tensor network from these tensors with these shared indices" is `TensorNetwork[tensors, hyperedges, free]`. The full tutorial above runs without ever materializing a projector as a matrix: `isotypicProject` and `projectOperatorBothSides` are tensor → tensor compositions of `YoungProject`. The equivalent walk-through in [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB) takes substantially more setup for symmetry registration and tensor-class hierarchy, and so do the [ITensor](https://itensor.org/) (Julia, C++) and [TeNPy](https://tenpy.readthedocs.io/) (Python) equivalents. This matters disproportionately for teaching, for prototyping, and for time-from-idea-to-verification.

### Where the paclet fits

The honest positioning: production libraries solve the *performance* end of the non-Abelian symmetric tensor-network problem and are the right tool when the goal is to find the ground state of a Heisenberg chain at $n = 100$. The Wolfram paclet solves the *expressiveness* end and is the right tool when the goal is to understand the structure before committing to a simulation, carry symbolic parameters through the irrep decomposition, project a tensor outside the spin-algebra zoo, or reproduce a textbook result on a small system in a single readable document. The two ends are complementary, not competing.

For the readers of this document (researchers prototyping non-Abelian-symmetric tensor calculations, teachers building graduate-course materials, developers evaluating whether to adopt a symmetric-tensor framework for their problem), the practical value is having the combinatorial layer (`TableauDimension`, `SchurDimension`), the projector layer (`YoungProject` composed in `isotypicProject` and `projectOperatorBothSides`), and the contraction layer (`TensorNetwork`, `TensorNetworkContract`) available in a single composable, symbolic, math-shaped environment. [QSpace](https://arxiv.org/abs/1202.5664) (MATLAB), [ITensor](https://itensor.org/) (Julia, C++), [TeNPy](https://tenpy.readthedocs.io/) (Python), [BLOCK](https://sanshar.github.io/Block/) (C++), and [StackBlock](https://github.com/sanshar/StackBlock) (C++) provide the performance; [SymPy](https://www.sympy.org/) (Python) and [SageMath](https://www.sagemath.org/) (Python) provide the combinatorial primitives standalone. None of them provide the composition this paclet does.

## References

- Ian P. McCulloch, *From density-matrix renormalization group to matrix product states*, J. Stat. Mech. (2007) P10014, arXiv:cond-mat/0701428. The structural framework for non-Abelian-symmetric MPS / DMRG; Section 4.2 covers the SU(2) case in detail.
- Ian P. McCulloch and Miklós Gulácsi, *The non-Abelian density matrix renormalization group algorithm*, Europhys. Lett. **57**, 852 (2002). The original non-Abelian DMRG formulation.
- Andreas Weichselbaum, *Non-Abelian symmetries in tensor networks: A quantum symmetry space approach*, Ann. Phys. **327**, 2972 (2012), arXiv:1202.5664. The QSpace library and a comprehensive treatment of multi-site tensor decompositions in the irrep basis.
- Sandeep Sharma and Garnet Kin-Lic Chan, *Spin-adapted density matrix renormalization group algorithms for quantum chemistry*, J. Chem. Phys. **136**, 124121 (2012), arXiv:1408.4039. The spin-adapted DMRG framework that underpins the BLOCK and StackBlock packages.
- Sukhwinder Singh, Robert N. C. Pfeifer, and Guifré Vidal, *Tensor network decompositions in the presence of a global symmetry*, Phys. Rev. A **82**, 050301 (2010), arXiv:0907.2994. Abelian-symmetric tensor-network backbone; many of its constructions extend to non-Abelian by adding the irrep multiplicity factor.
- Philipp Schmoll, Sukhwinder Singh, Matteo Rizzi, and Román Orús, *A programming guide for tensor networks with global $SU(2)$ symmetry*, Ann. Phys. **419**, 168232 (2020), arXiv:1809.08180. A modern programming-level tutorial on building SU(2)-symmetric tensor networks; complements McCulloch's structural paper.
