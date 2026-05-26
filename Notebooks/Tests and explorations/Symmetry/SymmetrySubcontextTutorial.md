# A Working Tour of the Symmetry Functions

This tutorial walks through every function in `` Wolfram`TensorNetworks`Symmetry` `` in the order a tensor-network practitioner meets them. After it you can (i) decide whether a partition or a tableau is the right object for a problem, (ii) predict the size of every block of a symmetry-resolved tensor in closed form, and (iii) project a TN tensor onto the irreducible-representation subspace it physically belongs to. Every claim is paired with a Wolfram Language cell; nothing is asserted without being computed.

The arc starts at two indistinguishable particles and walks up the rank, picking up one Symmetry function per step. By the end all sixteen exported functions appear at least once on a tensor with a tensor-network reason to exist.

## Inventory

The Symmetry layer exports sixteen symbols. Six handle the *combinatorics* of Young diagrams. Two are typed *accessors* for the row and column structure of a tableau. Six are *dimensions* of the irreducible-representation blocks, split between the $S_n$ side ($\dim V_\lambda$) and the $GL(d)$ side ($\dim W_\lambda(d)$). Two are *tensor actions* that produce a tensor in a chosen symmetry class.

| Symbol | Layer | One-line role |
|---|---|---|
| `PartitionQ` | combinatorics | Is this list a valid Young-diagram shape? |
| `TransposePartition` | combinatorics | Swap rows and columns of the diagram. |
| `YoungTableau` | combinatorics | Wrap a diagram (with slot labels) into a typed object. |
| `YoungTableauQ` | combinatorics | Is this `YoungTableau[...]` well-formed? |
| `TableauShape` | combinatorics | Read off the partition from a tableau. |
| `TableauSize` | combinatorics | Total box count $n$ (the rank we will act on). |
| `TableauRows` | accessor | The list-of-rows out of an atomic `YoungTableau[...]`. |
| `TableauColumns` | accessor | The column-slot lists (handles ragged shapes). |
| `HookLength` | dimensions | One cell's hook length. |
| `HookLengths` | dimensions | All hook lengths in one nested list. |
| `HookFactor` | dimensions | $1/\prod h(i,j)$, the prefactor in the dimension formula. |
| `TableauDimension` | dimensions | $\dim V_\lambda$, the $S_n$ irreducible representation dimension. |
| `SchurDimension` | dimensions | $\dim W_\lambda(d)$, the $GL(d)$ Weyl module dimension via the hook-content formula. |
| `TableauWeylDimension` | dimensions | Same value as `SchurDimension`, but tableau-keyed (parallel to `TableauDimension`). |
| `YoungSymmetrize` | tensor action | Unnormalised Young symmetriser $c_T \cdot T$. |
| `YoungProject` | tensor action | Idempotent projector $P_T = (d_\lambda/n!)\, c_T$. |

The tutorial is structured around two physical settings that together bring every function into play:

1. **Familiar rank-2 tensors and their TN-bond payoffs** introduces `YoungTableau`, `YoungTableauQ`, the four accessors (`TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`), `YoungSymmetrize`, and `YoungProject` through symmetric / antisymmetric matrices from physics (metric, Pauli, EM tensor, ...) and operational TN constructs (singlet/triplet decomposition, SWAP-gate eigenspace, fermionic bond), closing with a block-sparse trace identity on a rank-2 bond.
2. **Beyond rank 2: three higher-rank payoffs** introduces `PartitionQ`, `TransposePartition`, `HookLength`, `HookLengths`, `HookFactor`, and `TableauDimension` through three larger examples: the Schur-Weyl block decomposition on three sites (with a block-sparse Frobenius contraction), the Riemann curvature tensor as a rank-4 TN node (with multi-term algebraic identities derived from the $\{2,2\}$ projector, including the first Bianchi identity), and the spectrum of a class-function Hamiltonian via content sums.

---

## Where the Symmetry functions sit in WL's tensor stack

Before any code, fix the structural relationship between the Symmetry functions and built-in Wolfram Language tensor symmetry. Built-in WL (since 9.0) ships a complete language for *mono-term* symmetries: relations of the form

$$
\phi\, \mathrm{TensorTranspose}[T, \sigma] \;=\; T
$$

for one permutation $\sigma$ and one root of unity $\phi$. The kernel surface for these is

- named heads `Symmetric[{slots}]`, `Antisymmetric[{slots}]`, `Hermitian[{1,2}]`, `Antihermitian[{1,2}]`, `ZeroSymmetric[{slots}]`,
- generic generators as lists `{ {Cycles[...], phase}, ... }`,
- the projector `Symmetrize[T, sym]` (group-averaging; the idempotent normalised form),
- the analyser `TensorSymmetry[T]`,
- the compressed-storage type `SymmetrizedArray[rules, dims, sym]`,
- the assumption-layer envelopes `Arrays[...]` / `Matrices[...]` / `Vectors[...]` that drive `TensorReduce` / `TensorExpand`.

This is everything you need to declare "this tensor is symmetric in slots 1, 2", "this matrix is Hermitian", "this rank-4 tensor antisymmetrises in $(1,2)$ and in $(3,4)$ and is invariant under swapping the pairs". It is not enough to declare "$R_{abcd} + R_{acdb} + R_{adbc} = 0$": that is a *multi-term* relation (three permuted copies summing to zero) and lies outside the mono-term language. The same gap is what blocks Young projection onto a mixed-symmetry irreducible representation: those projectors are sums-with-signs over the group on each row and each column of a Young diagram, and the image is defined by satisfying *several* permutation relations together, not one.

The Symmetry functions in `` Wolfram`TensorNetworks`Symmetry` `` fill exactly this gap. Its `YoungProject` produces tensors that lie in *one $S_n$ irreducible representation*, a condition that always implies extra multi-term identities. The Riemann curvature tensor is the canonical example: living in the $\{2,2\}$ irreducible representation simultaneously satisfies pair-antisymmetry $R_{abcd} = -R_{bacd}$, pair-antisymmetry $R_{abcd} = -R_{abdc}$, pair-swap $R_{abcd} = R_{cdab}$, *and* the algebraic first Bianchi identity $R_{abcd} + R_{acdb} + R_{adbc} = 0$. The three pair conditions are mono-term and reachable by built-in `Symmetrize`; the Bianchi identity is multi-term and is not.

The Riemann-tensor example later in the tutorial makes this concrete: built-in `Symmetrize` with the three Riemann pair generators leaves a finite Bianchi residual, while `YoungProject` zeroes it. The map between the two layers:

| Operation | Built-in WL | Symmetry functions |
|---|---|---|
| Mono-term symmetrise (boson, fermion, Riemann pair) | `Symmetrize[T, sym]` | (wrapped by the Symmetry functions) |
| Detect mono-term symmetry group | `TensorSymmetry[T]` | (no analogue) |
| Compressed storage by orbit | `SymmetrizedArray` | (no analogue; the Symmetry functions emit dense / `Normal`) |
| Single-tableau / mixed-symmetry projection (multi-term) | (not supported) | `YoungProject[T, tab]` |
| Irreducible representation dimension $\dim V_\lambda$ via hook formula | (not supported) | `TableauDimension[par]` |
| Hook lengths for $S_n$ representation theory | (not supported) | `HookLength`, `HookLengths`, `HookFactor` |

The two layers compose. `YoungSymmetrize` is two `Symmetrize` calls (`Symmetric /@ rows`, then `Antisymmetric /@ columns`) plus the row- and column-stabiliser normalisation factors. The multi-term machinery extends the mono-term machinery, not competes with it.

---

## Setup

Load the paclet and pull the Symmetry functions into scope; both `Needs` are assumed in every subsequent cell. The `tol` constant sets the numerical tolerance for "is this tensor identity satisfied?" checks throughout.

```wolfram
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

tol = 10^-10;
```

## Picturing a tensor as a diagram

*A rank-$n$ tensor is a node with $n$ labelled legs, one per slot. This is the visual vocabulary every tensor-network argument uses when an indexed sum reads more naturally as a diagram.*

Render a generic rank-$7$ tensor as a hypergraph.

```wolfram
TensorNetwork[{Range[7]}]["Hypergraph"]
```

The central blob is the tensor; the seven labelled legs are its slots. Shared legs become bonds between two such nodes, and a tensor network is a collection of these stars glued at common legs.

Two group actions live on this picture, and both recur throughout the tutorial:

- **$S_n$**, the *symmetric group* on $n$ letters, comprises the $n!$ permutations of the slots. It acts on the diagram by **permuting which leg is which**. For rank $7$, $|S_7| = 5040$.
- **$GL(d)$**, the *general linear group* of $d \times d$ invertible matrices, acts on a single leg of dimension $d$ by **basis change**, and on the full tensor by changing basis at every leg simultaneously. It is a continuous group of dimension $d^2$.

The two actions commute, and Schur-Weyl duality turns that commuting pair into a direct-sum decomposition of $V^{\otimes n}$ into blocks indexed by Young diagrams of size $n$. The Symmetry functions handle the $S_n$ side (`YoungProject` lands a tensor in a chosen block); `SchurDimension` reports the $GL(d)$ side (the block size at bond dimension $d$).

---

# Two indistinguishable particles on a bond

The simplest non-trivial tensor in a tensor network is a rank-2 node $T_{ij}$ on a bond between two physical sites, with each index ranging over a $d$-dimensional local Hilbert space $V$, so $T \in V \otimes V$. This rank-2 bond is the elementary building block of every MPS, MERA, and PEPS, and the symmetry rule worked out here generalises slot-by-slot to every higher-rank tensor in the rest of the tutorial.

## Identical particles and the exchange operator

Identical quantum particles carry no intrinsic labels: photons in a cavity, electrons in an atom, helium-4 atoms in a superfluid, the indices we attach are bookkeeping, not physics. Quantum mechanics enforces this with a sharp rule on the two-particle wavefunction $\Psi(x_1, x_2)$:

$$
\Psi(x_2, x_1) \;=\; \pm\, \Psi(x_1, x_2).
$$

The plus sign is the *bosonic* case (integer spin: photons, mesons, He-4, Cooper pairs). The minus sign is the *fermionic* case (half-integer spin: electrons, protons, He-3); setting $x_1 = x_2$ forces $\Psi = 0$, the Pauli exclusion principle.

Write the wavefunction in tensor form, $|\Psi\rangle = \sum_{ij} T_{ij} \,|i\rangle \otimes |j\rangle \in V \otimes V$. The *exchange operator* (the SWAP gate in quantum computing) $P_{12}$ acts by relabelling the two factors,

$$
P_{12} \,(|i\rangle \otimes |j\rangle) \;=\; |j\rangle \otimes |i\rangle,
$$

sending coefficients $T_{ij} \mapsto T_{ji}$. **This is the ordinary transpose $T^T$, not the adjoint $T^\dagger$.** SWAP relabels slots; no complex conjugation enters. So even for complex $T$, the bosonic and fermionic conditions are

$$
\text{boson}: \; T \,=\, T^T, \qquad \text{fermion}: \; T \,=\, -\,T^T.
$$

Hermiticity, $T = T^\dagger = (T^*)^T$, is a separate constraint outside the symmetric-group story; built-in WL captures it via `Hermitian[{1,2}]`. On real entries the kernel collapses `Matrices[{n,n}, Reals, Hermitian[{1,2}]]` to `Matrices[{n,n}, Reals, Symmetric[{1,2}]]` because the conjugation has no imaginary part to act on.

## The symmetric / antisymmetric decomposition

A generic complex matrix $T \in V \otimes V$ is neither symmetric nor antisymmetric, but it splits cleanly:

$$
T \;=\; \tfrac{1}{2}(T + T^T) \;+\; \tfrac{1}{2}(T - T^T),
$$

with $T_{\text{sym}} \in \mathrm{Sym}^2 V$ (dimension $d(d+1)/2$) and $T_{\text{anti}} \in \Lambda^2 V$ (dimension $d(d-1)/2$). These are the $+1$ and $-1$ eigenspaces of SWAP, and their dimensions sum to $d^2$. The Symmetry functions name the two pieces by their symmetry class (the partition $\{2\}$ for boson, $\{1,1\}$ for fermion) and produce each with a single call. The naming object is the `YoungTableau`.

## `YoungTableau`: the named handle for a symmetry class

A *Young tableau* is a left-justified arrangement of boxes (the "shape") together with a labelling of those boxes by the slot indices $\{1, 2, \ldots, n\}$ of the tensor we plan to act on. **The labelling must be a permutation of $1, 2, \ldots, n$** (a *standard tableau*). For two indices there are exactly two shapes:

- one row of two boxes, written $\{2\}$, labels the *symmetric* class;
- one column of two boxes, written $\{1,1\}$, labels the *antisymmetric* class.

Build the symmetric two-box tableau.

```wolfram
YoungTableau[{2}]
```

Build the antisymmetric two-box tableau.

```wolfram
YoungTableau[{1, 1}]
```

Each call returns a typed `YoungTableau[...]` with a summary display. The constructor accepts two forms. The *partition* form just used takes a non-increasing list of row lengths and fills slot labels $1, 2, \ldots, n$ row by row. The *explicit-rows* form takes the rows of slot labels directly; the symmetric two-tableau equivalent reads:

```wolfram
YoungTableau[{{1, 2}}]
```

The antisymmetric two-tableau equivalent reads:

```wolfram
YoungTableau[{{1}, {2}}]
```

The explicit form matters beyond rank 2 because it picks *which* slot lives in which row and column. For example, `YoungTableau[{{1, 3}, {2}}]` is a $\{2, 1\}$-shape tableau on rank 3 with slot 3 paired with slot 1 in the column, distinct from the default `YoungTableau[{{1, 2}, {3}}]` that fills row by row.

`YoungTableauQ` decides whether a `YoungTableau[...]` is well-formed, rejecting malformed input before it reaches `YoungProject`. Increasing row lengths violate the partition condition.

```wolfram
YoungTableauQ[YoungTableau[{{1}, {2, 3}}]]
```

Duplicate slot labels are rejected.

```wolfram
YoungTableauQ[YoungTableau[{{1, 2}, {2, 3}}]]
```

Slot labels that are not a permutation of `Range[n]` are rejected even when distinct and positive. Here the slots are $\{1, 2, 3, 5, 7\}$, missing $4$ and $6$.

```wolfram
YoungTableauQ[YoungTableau[{{3, 5, 7}, {1, 2}}]]
```

Custom slot orderings *within* the legal label set are allowed: the slots here are a permutation of `Range[5]`.

```wolfram
YoungTableauQ[YoungTableau[{{1, 3, 5}, {2, 4}}]]
```

Anything that is not a `YoungTableau[...]` is rejected by head.

```wolfram
YoungTableauQ["definitely not a tableau"]
```

## Familiar rank-2 tensors and their TN-bond payoffs

The two rank-2 tableau classes $\{2\}$ and $\{1,1\}$ are nothing exotic: they are every symmetric matrix and every antisymmetric matrix you have ever seen. The examples below confirm this on textbook tensors (metric, Pauli, EM, Levi-Civita, covariance) and then turn the same projection machinery on three operational TN constructs: singlet/triplet decomposition, the SWAP-gate eigenspace, and a fermionic bond inside a tensor-network contraction. All of them share the rank-2 tableaux `symTab` and `antiTab` and the same `YoungProject` workflow.

The four single-qubit operators (identity plus the three Pauli matrices) are a clean illustration. Each is a $2 \times 2$ matrix that lies entirely in one of the two shapes:

```wolfram
{Id, sx, sy, sz} = Table[PauliMatrix[j], {j, 0, 3}];
```

The identity, $\sigma_x$, and $\sigma_z$ equal their own transpose; $\sigma_y$ negates under transpose:

```wolfram
{Id == Transpose[Id], sx == Transpose[sx], sy == -Transpose[sy], sz == Transpose[sz]}
```

So the four-element Pauli basis splits as three matrices in the $\{2\}$ shape ($I, \sigma_x, \sigma_z$) and one in the $\{1,1\}$ shape ($\sigma_y$). That matches the Schur-Weyl dimensions exactly: $d(d+1)/2 = 3$ symmetric matrices plus $d(d-1)/2 = 1$ antisymmetric matrix gives $4 = d^2$ total.

`YoungProject` applied to a tensor that already lives in one shape is a sanity check: the right-shape projection is the identity on that tensor, the wrong-shape projection is zero. Name the symmetric two-box tableau.

```wolfram
symTab = YoungTableau[{2}];
```

Name the antisymmetric two-box tableau.

```wolfram
antiTab = YoungTableau[{1, 1}];
```

A `YoungTableau[...]` is atomic, so explicit accessors are the only way to read off its row and column structure. `TableauRows` returns the list of row-slot lists; `TableauColumns` returns the list of column-slot lists (correctly handling ragged shapes). These are the inputs `YoungSymmetrize` and `YoungProject` consume internally. Read the symmetric tableau's row and column lists.

```wolfram
{TableauRows[symTab], TableauColumns[symTab]}
```

Read the antisymmetric tableau's row and column lists.

```wolfram
{TableauRows[antiTab], TableauColumns[antiTab]}
```

Note the row-column swap between `symTab` and `antiTab`: transposing the partition (`{2}` ↔ `{1, 1}`) swaps the row and column slot lists, which is exactly the "exchange symmetric for antisymmetric" mirror visible at the structural level.

Before turning these tableaux loose on real tensors, sanity-check that both are well-formed standard tableaux. The `YoungTableauQ` predicate is the gatekeeper: it rejects ill-formed entries (already shown in the constructor section above) and accepts the well-formed ones. Check the symmetric tableau.

```wolfram
YoungTableauQ[symTab]
```

Check the antisymmetric tableau.

```wolfram
YoungTableauQ[antiTab]
```

Both pass. Next, read off the structural numbers each tableau carries. `TableauShape` returns the underlying partition; `TableauSize` returns the total box count, which is the rank of any tensor the tableau can act on. Read the symmetric tableau's partition.

```wolfram
TableauShape[symTab]
```

Read its box count.

```wolfram
TableauSize[symTab]
```

Read the antisymmetric tableau's partition.

```wolfram
TableauShape[antiTab]
```

Read its box count.

```wolfram
TableauSize[antiTab]
```

Both tableaux carry two boxes, so they act on rank-2 tensors. Every concrete example in the rest of this section is a rank-2 tensor, so this constraint is automatically met; later sections that work with rank-3 and rank-4 tensors will need different tableaux of the matching size.

Project $\sigma_x$ onto the symmetric shape; the result is $\sigma_x$ itself.

```wolfram
YoungProject[sx, symTab]
```

Project $\sigma_x$ onto the antisymmetric shape; the result vanishes.

```wolfram
YoungProject[sx, antiTab]
```

Project $\sigma_y$ onto the antisymmetric shape; the result is $\sigma_y$ itself.

```wolfram
YoungProject[sy, antiTab]
```

Project $\sigma_y$ onto the symmetric shape; the result vanishes.

```wolfram
YoungProject[sy, symTab]
```

Alongside the projector `YoungProject`, the Symmetry functions also expose the unnormalised Young symmetriser `YoungSymmetrize`, which returns $c_T \cdot T$ instead of the projector $P_T = (d_\lambda / n!)\, c_T$. For a rank-2 tensor and the symmetric tableau, $c_{\{2\}} = $ row-stabiliser order $= 2! = 2$, so the unnormalised version is twice the projection.

```wolfram
YoungSymmetrize[sx, symTab] == 2 * YoungProject[sx, symTab]
```

Under the hood `YoungSymmetrize` is built directly on built-in WL's `Symmetrize`: it calls `Symmetrize[T, Symmetric /@ TableauRows[tab]]` (row symmetrisation) then `Symmetrize[..., Antisymmetric /@ TableauColumns[tab]]` (column antisymmetrisation), scaled by the row- and column-stabiliser orders to undo `Symmetrize`'s built-in $1/|G|$ normalisation. The two `Symmetrize` calls compose because rows and columns of a Young tableau touch disjoint slot sets.

```wolfram
YoungSymmetrize[sx, symTab] == 2 * Normal @ Symmetrize[sx, Symmetric[{1, 2}]]
```

The two projections decompose any rank-2 tensor: their sum returns the original. This is the $n = 2$ instance of the general fact that on $V^{\otimes n}$ the sum of isotypic projectors over all partitions $\lambda \vdash n$ is the identity.

```wolfram
YoungProject[sx, symTab] + YoungProject[sx, antiTab] == sx
```

A short census of rank-2 tensors the reader has seen and the shape each one lives in follows. Each entry uses the same four-step pattern: build the tensor, project onto the symmetric shape and subtract the original, project onto the antisymmetric shape and subtract the original, and read the symmetry class with the built-in detector. A zero residual on a shape's projection means the tensor lies entirely in that shape; anything not in one shape is a sum of a $\{2\}$-piece and a $\{1,1\}$-piece that `YoungProject` decomposes.

### Minkowski metric $g_{\mu\nu}$

*The metric of flat spacetime is symmetric by definition: $g_{\mu\nu} = g_{\nu\mu}$ encodes distance, which is reciprocal. `YoungProject` lands $g$ entirely in the symmetric $\{2\}$ class with zero antisymmetric residue, the canonical first sanity check that the projector is wired correctly.*

The Minkowski metric is a diagonal matrix with signature $(-,+,+,+)$.

```wolfram
g = DiagonalMatrix[{-1, 1, 1, 1}]
```

Project $g$ onto the symmetric shape and subtract the original.

```wolfram
YoungProject[g, YoungTableau[{2}]] - g // Simplify
```

Project $g$ onto the antisymmetric shape and subtract the original.

```wolfram
YoungProject[g, YoungTableau[{1, 1}]] - g // Simplify
```

Read the symmetry class from the built-in detector.

```wolfram
TensorSymmetry[g]
```

### Stress-energy tensor $T^{\mu\nu}$ (perfect fluid)

*The stress-energy tensor of a perfect fluid encodes energy and momentum flow, which is reciprocal, so $T^{\mu\nu} = T^{\nu\mu}$ for any $\rho, p, u^\mu$. `YoungProject` confirms this symbolically, letting a TN library halve the stored components on a stress-energy bond.*

Build the stress-energy tensor of a perfect fluid, $T^{\mu\nu} = (\rho + p)\, u^\mu u^\nu + p\, g^{\mu\nu}$, from a generic 4-velocity and the Minkowski metric. Here $\rho$ is the energy density, $p$ the isotropic pressure, and $u^\mu$ the fluid's 4-velocity (normalised $u^\mu u_\mu = -1$ in the mostly-plus signature). In the rest frame $u^\mu = (1, 0, 0, 0)$ and $T^{\mu\nu}$ reduces to $\mathrm{diag}(\rho, p, p, p)$. The tensor is manifestly symmetric in $(\mu, \nu)$ for any $\rho, p, u^\mu$.

```wolfram
u = Array[uu, 4];
TSE = (rho + p) TensorProduct[u, u] + p g;
```

Project $T$ onto the symmetric shape and subtract.

```wolfram
YoungProject[TSE, YoungTableau[{2}]] - TSE // Simplify
```

Project $T$ onto the antisymmetric shape and subtract.

```wolfram
YoungProject[TSE, YoungTableau[{1, 1}]] - TSE // Simplify
```

Read the symmetry class.

```wolfram
TensorSymmetry[TSE]
```

### Spring-constant matrix $K_{ij}$ (Hessian of a scalar potential)

*Mixed partials of a smooth potential commute, so the spring-constant matrix is symmetric. `YoungProject` recasts that textbook identity as a $\{2\}$-projection statement: the antisymmetric remainder is identically zero, checkable in one line.*

The spring-constant matrix is the Hessian $K_{ij} = \partial_i \partial_j V$ of a scalar potential. For a purely quadratic $V(x, y) = \tfrac{1}{2}(3 x^2 + 2 y^2 + xy)$ the Hessian is a constant matrix with no $x, y$ dependence, so no equilibrium-point substitution is needed. The built-in second-order form `D[V, {{x, y}, 2}]` handles the partial-derivative bookkeeping.

```wolfram
K = D[(1/2) (3 x^2 + 2 y^2 + x y), {{x, y}, 2}]
```

Project onto the symmetric shape and subtract.

```wolfram
YoungProject[K, YoungTableau[{2}]] - K // Simplify
```

Project onto the antisymmetric shape and subtract.

```wolfram
YoungProject[K, YoungTableau[{1, 1}]] - K // Simplify
```

`YoungProject` is idempotent: projecting twice equals projecting once. This is why iterative TN algorithms (DMRG, TDVP) use the normalised projector rather than the unnormalised `YoungSymmetrize`, which would blow up by a factor of $n!/d_\lambda$ on every iteration.

```wolfram
YoungProject[YoungProject[K, symTab], symTab] == YoungProject[K, symTab]
```

Read the symmetry class.

```wolfram
TensorSymmetry[K]
```

### Symbolic covariance matrix of a bivariate normal distribution

*Covariance is symmetric in its two variables: $\mathrm{Cov}(X, Y) = \mathrm{Cov}(Y, X)$ by definition. `YoungProject` confirms this symbolically in the correlation parameter $\rho$, the structural reason a covariance bond carries $d(d+1)/2$ free entries rather than $d^2$.*

The covariance matrix of a multivariate distribution is symbolic when the distribution carries a symbolic parameter. For the bivariate normal `BinormalDistribution[ρ]` (unit variances, correlation parameter $\rho$), built-in `Covariance` returns the symbolic matrix $\bigl(\begin{smallmatrix}1 & \rho \\ \rho & 1\end{smallmatrix}\bigr)$, manifestly symmetric in $\rho$.

```wolfram
covMat = Covariance[BinormalDistribution[\[Rho]]]
```

Project onto the symmetric shape and subtract.

```wolfram
YoungProject[covMat, YoungTableau[{2}]] - covMat // Simplify
```

Project onto the antisymmetric shape and subtract.

```wolfram
YoungProject[covMat, YoungTableau[{1, 1}]] - covMat // Simplify
```

Read the symmetry class.

```wolfram
TensorSymmetry[covMat]
```

### Electromagnetic field tensor $F_{\mu\nu}$ (from a 4-potential)

*The electromagnetic field tensor is built as $F_{\mu\nu} = \partial_\mu A_\nu - \partial_\nu A_\mu$, antisymmetric by construction (three $E$-components, three $B$-components). `YoungProject` confirms it lives entirely in the $\{1, 1\}$ class, the structural reason the EM field has six independent components in 4D rather than sixteen.*

The EM field tensor is the antisymmetrised Jacobian of a 4-potential, $F_{\mu\nu} = \partial_\mu A_\nu - \partial_\nu A_\mu$.

```wolfram
coords = {t, x, y, z};
A = Through[Array[a, 4][Sequence @@ coords]];
J = Grad[A, coords];
F = Transpose[J] - J;
```

Project onto the symmetric shape and subtract.

```wolfram
YoungProject[F, YoungTableau[{2}]] - F // Simplify
```

Project onto the antisymmetric shape and subtract.

```wolfram
YoungProject[F, YoungTableau[{1, 1}]] - F // Simplify
```

Read the symmetry class.

```wolfram
TensorSymmetry[F]
```

### 2D Levi-Civita $\varepsilon_{ij}$

*The Levi-Civita symbol $\varepsilon_{ij}$ is the orientation tensor on a 2D plane: antisymmetric by definition. At $d = 2$ the antisymmetric sector is one-dimensional, so `YoungProject` plus `SchurDimension[{1,1}, 2] = 1` together prove $\varepsilon$ is the unique (up to scale) antisymmetric rank-2 tensor on a 2-qubit bond.*

The 2D Levi-Civita tensor is the canonical antisymmetric rank-2 object.

```wolfram
eps2 = LeviCivitaTensor[2, List]
```

Project onto the symmetric shape and subtract.

```wolfram
YoungProject[eps2, YoungTableau[{2}]] - eps2 // Simplify
```

Project onto the antisymmetric shape and subtract.

```wolfram
YoungProject[eps2, YoungTableau[{1, 1}]] - eps2 // Simplify
```

Read the symmetry class.

```wolfram
TensorSymmetry[eps2]
```

### Two-spin singlet vs triplet (spin-$\tfrac12$ at $d = 2$)

*Two spin-$\tfrac12$ particles couple into a spin-0 singlet (antisymmetric) plus a spin-1 triplet (symmetric), the Clebsch-Gordan decomposition $\tfrac12 \otimes \tfrac12 = 0 \oplus 1$. `YoungProject` onto $\{2\}$ and $\{1, 1\}$ separates them in one call, one projector per total-spin sector.*

A pair of spin-$\tfrac12$ particles has a 4-dimensional Hilbert space $V \otimes V$ with $d = 2$. The two-spin wavefunctions split into one singlet ($S = 0$, antisymmetric) and three triplet states ($S = 1$, symmetric). In coefficient-tensor form a state $|\Psi\rangle = \sum_{ij} \psi_{ij} |ij\rangle$ has a $2 \times 2$ coefficient matrix $\psi$: singlet iff $\psi$ is antisymmetric, triplet iff $\psi$ is symmetric.

Build the singlet $(|01\rangle - |10\rangle)/\sqrt{2}$ as a $2 \times 2$ coefficient matrix.

```wolfram
psiSinglet = {{0, 1}, {-1, 0}}/Sqrt[2];
```

Build the $S_z = 0$ triplet $(|01\rangle + |10\rangle)/\sqrt{2}$.

```wolfram
psiTriplet = {{0, 1}, {1, 0}}/Sqrt[2];
```

The antisymmetric projection of the singlet returns the singlet itself.

```wolfram
YoungProject[psiSinglet, antiTab]
```

The symmetric projection of the singlet vanishes (no triplet content).

```wolfram
YoungProject[psiSinglet, symTab]
```

The symmetric projection of the triplet returns the triplet itself.

```wolfram
YoungProject[psiTriplet, symTab]
```

The antisymmetric projection of the triplet vanishes.

```wolfram
YoungProject[psiTriplet, antiTab]
```

The same singlet-plus-symmetric-pair composition is the structural recipe for the 1D AKLT spin-1 chain: a virtual $\{1, 1\}$ singlet on each edge, then a $\{2\}$ symmetric projection on each site combining the two virtual spin-$\tfrac12$ legs into a single physical spin-$1$. The resulting bond-dimension-$2$ MPS matrices are $\sigma^\pm$ and $\sigma^z$ up to normalisation; East, van de Wetering, Chancellor & Grushin ([arXiv:2012.01219](https://arxiv.org/abs/2012.01219)) give the ZX-diagrammatic derivation. The next subsection takes the same $\{n\}$ symmetric projector to $n = 5$ qubits, producing a different family of physically meaningful states.

For an arbitrary two-spin coefficient matrix $\psi$, the *singlet amplitude* (the weight of the $S = 0$ component) is the inner product of the normalised singlet with `YoungProject[psi, antiTab]`: "is this state entangled along the singlet axis?" reduced to one function call.

### SWAP gate as the symmetrise/antisymmetrise machine

*The two-qubit SWAP gate has $+1$ and $-1$ eigenspaces of dimension 3 (triplet, symmetric) and 1 (singlet, antisymmetric). `YoungProject` onto $\{2\}$ and $\{1, 1\}$ realises those eigenspace projectors directly, showing that SWAP, transpose, Young projection, and built-in `Symmetrize` are the same operation written in four notations.*

In the two-qubit Hilbert space ($d = 2$ on each site, $V \otimes V = \mathbb{C}^4$) the SWAP gate is the $4 \times 4$ matrix realising $P_{12}$. Build it from a `SparseArray` with the rule $\langle k, l | \text{SWAP} | i, j \rangle = \delta_{kj}\delta_{li}$.

```wolfram
swapGate = Normal @ ArrayReshape[
    SparseArray[{{i_, j_, k_, l_} /; i == l && j == k -> 1}, {2, 2, 2, 2}],
    {4, 4}
];
```

The claim is that the Young projectors `YoungProject[*, symTab]` and `YoungProject[*, antiTab]` are exactly the projectors onto the $+1$ and $-1$ eigenspaces of this SWAP:
$$
P_{\{2\}} \;=\; \tfrac{1}{2}(I + \text{SWAP}), \qquad P_{\{1,1\}} \;=\; \tfrac{1}{2}(I - \text{SWAP}).
$$
Verify it. Form the two SWAP-eigenspace projectors as $4 \times 4$ matrices.

```wolfram
swapPlus  = (IdentityMatrix[4] + swapGate)/2;
swapMinus = (IdentityMatrix[4] - swapGate)/2;
```

Build a generic symbolic rank-2 coefficient tensor.

```wolfram
Tcoef = Array[t, {2, 2}];
```

Apply the $+1$-eigenspace projector to the flattened coefficient vector and reshape back, and compare with `YoungProject[Tcoef, symTab]`.

```wolfram
Simplify[
    ArrayReshape[swapPlus . Flatten[Tcoef], {2, 2}] == YoungProject[Tcoef, symTab]
]
```

Same comparison for the $-1$-eigenspace and the antisymmetric Young projector.

```wolfram
Simplify[
    ArrayReshape[swapMinus . Flatten[Tcoef], {2, 2}] == YoungProject[Tcoef, antiTab]
]
```

Both hold identically (not just numerically), so `YoungProject` and SWAP-eigenspace projection are the same linear map on rank-2 tensors. The eigenspace dimensions are the ranks of the two SWAP projectors.

```wolfram
{MatrixRank[swapPlus], MatrixRank[swapMinus]}
```

Three and one, matching $d(d+1)/2$ and $d(d-1)/2$ at $d = 2$: the symmetric block holds the spin-$1$ triplet, the antisymmetric block holds the spin-$0$ singlet. SWAP, transpose, `YoungProject`, and built-in `Symmetrize[..., Symmetric[{1,2}]]` are the same operation written in four notations; whichever one is most readable in context is the one to reach for.

### A fermionic bond in a TN

*A fermionic bond carries a tensor that must be antisymmetric under particle exchange (the Pauli principle on a single edge of a TN). One `YoungProject` onto $\{1, 1\}$ enforces this before any contraction; downstream `Dot`, `TensorContract`, and SVD preserve the sector automatically, halving the stored entries from $d^2$ to $d(d-1)/2$.*

Here the projection saves storage. A one-bond TN with two nodes $A, B$ describing identical fermions and bond tensor $T$ contracts to

$$
\text{value} \;=\; \sum_{i,j} A_i \, T_{ij} \, B_j.
$$

The physics demands $T \in \Lambda^2 V$. Storing both halves of $T$ wastes $d(d+1)/2$ slots on a sector the Pauli principle forbids; one `YoungProject` zeroes it. Start with a generic random bond tensor at $d = 4$.

```wolfram
SeedRandom[3];
d = 4;
T = RandomReal[{-1, 1}, {d, d}];
```

Project onto the antisymmetric (fermionic) shape.

```wolfram
TFermi = YoungProject[T, antiTab];
```

Build random vectors for the two surrounding nodes.

```wolfram
A = RandomReal[{-1, 1}, d];
B = RandomReal[{-1, 1}, d];
```

Contract the projected bond against $A$ and $B$. The scalar equals $\tfrac{1}{2}(A \cdot T \cdot B - B \cdot T \cdot A)$ by direct expansion.

```wolfram
A . TFermi . B
```

To see what the Young projection *does* to a tensor network, build the same three-node network with the **unprojected** bond $T$ and contract it through the paclet's contraction engine. Encode the three nodes and their shared indices as a hyperedge list (vector $A$ on index `i`, the bond on `i, j`, vector $B$ on `j`), then let `TensorNetworkContract` evaluate it.

```wolfram
bareTN = TensorNetwork[{A, T, B}, {{"i"}, {"i", "j"}, {"j"}}, {}];
TensorNetworkContract[bareTN]
```

Now apply `YoungProject` to the bond node *inside* the network: feed the antisymmetric projection of $T$ into the same hyperedge layout, then contract. This is the symmetry-to-core-TN handoff in one step: `YoungProject` rewrites the bond into the fermionic sector, and `TensorNetworkContract` evaluates the symmetry-restricted network.

```wolfram
fermionTN = TensorNetwork[
    {A, YoungProject[T, antiTab], B},
    {{"i"}, {"i", "j"}, {"j"}}, {}
];
TensorNetworkContract[fermionTN]
```

The two scalars differ. What the projection removes is exactly the symmetric piece $\tfrac{1}{2}(A \cdot T \cdot B + B \cdot T \cdot A)$ that the Pauli principle forbids for identical fermions.

```wolfram
Chop[(TensorNetworkContract[bareTN] - TensorNetworkContract[fermionTN]) -
     (A . T . B + B . T . A)/2] < tol
```

```wolfram
Abs[(A . T . B) - (A . TFermi . B)] > tol
```

After the projection, every downstream TN operation that respects index types (`TensorContract`, `Dot`, SVD on the paired index, partial trace) preserves the antisymmetric class. The orthogonal sector is gone for good, halving the bond's worth of stored numbers in the asymptotic limit. If memory matters more than evaluation speed, you can also store the projected bond as a `SymmetrizedArray[..., Antisymmetric[{1,2}]]`; built-in WL handles tensor-arithmetic on it without ever materialising the dense form.

The same project-first-then-contract pattern carries to higher-rank fermionic networks, to bosonic permutation-invariant Hamiltonians, and (with a different Young diagram) to the Riemann curvature tensor in the next section.

### Magnetization sectors on $n = 5$ qubits from a single $\{n\}$ Young projector

*A permutation-symmetric many-qubit state has well-defined total spin and magnetisation, and lives in a tiny $(n + 1)$-dim subspace of the $2^n$-dim full Hilbert space. One `YoungProject` onto $\{n\}$ builds W- and Dicke states with exact $S^z$ and $\vec{S}^2$ quantum numbers; `SchurDimension[{n}, 2]` gives the bond-dim compression, a 93-fold reduction at $n = 10$.*

Dicke states $|D_n^k\rangle$ are the totally symmetric $n$-qubit states with exactly $k$ down-spins. They form an $(n+1)$-dimensional orthonormal basis of the symmetric subspace of $(\mathbb{C}^2)^{\otimes n}$, label every magnetization sector inside that subspace, and underpin the symmetric many-qubit ansätze used in cavity QED, atomic-ensemble metrology (superradiance, spin squeezing), and permutation-invariant NISQ benchmarks. Construction recipe: feed the bit string $|1^k 0^{n-k}\rangle$ through the totally symmetric Young projector $\{n\}$ and normalise. One `YoungProject` call, one quantum many-body state.

Set the chain length and the relevant Young tableau.

```wolfram
n = 5;
nTab = YoungTableau[{n}];
```

Build the W-state $|W_5\rangle$ as the symmetric Young projection of the unsymmetrised single-excitation seed $|10000\rangle$, then unit-normalise.

```wolfram
seedW = Normal @ SparseArray[{2, 1, 1, 1, 1} -> 1, ConstantArray[2, n]];
wRaw = YoungProject[seedW, nTab];
wState = wRaw / Norm[Flatten[wRaw]];
```

The flattened state has exactly five non-zero amplitudes, each equal to $1/\sqrt{5}$, sitting at the five basis positions $|10000\rangle, |01000\rangle, |00100\rangle, |00010\rangle, |00001\rangle$.

```wolfram
Cases[Flatten[wState], x_ /; Abs[x] > 10^-10]
```

For magnetisation checks build the total-$S^z$ operator as a $32 \times 32$ matrix: a sum of single-site $\sigma^z/2$ insertions in an otherwise-identity Kronecker product. The same shape works for $S^x$ and $S^y$.

```wolfram
sumSpinOp[op_] := Sum[
    KroneckerProduct @@ ReplacePart[ConstantArray[IdentityMatrix[2], n], i -> op],
    {i, n}
];
sZtot = sumSpinOp[PauliMatrix[3]/2];
```

The W-state has one spin-down among five spin-ups, so its total magnetisation eigenvalue is $(n - 2)/2 = 3/2$.

```wolfram
Chop[sZtot . Flatten[wState] - 3/2 Flatten[wState]]
```

It also lives in the maximum-spin sector $S = n/2 = 5/2$, with $\vec S_\text{tot}^2$ eigenvalue $S(S+1) = 35/4$. Assemble $\vec S_\text{tot}^2$ from $S^x, S^y, S^z$ and apply.

```wolfram
sXtot = sumSpinOp[PauliMatrix[1]/2];
sYtot = sumSpinOp[PauliMatrix[2]/2];
s2tot = sXtot . sXtot + sYtot . sYtot + sZtot . sZtot;
Chop[s2tot . Flatten[wState] - 35/4 Flatten[wState]]
```

The W-state is one of $n + 1 = 6$ Dicke states. Building any other one is the same construction with a different bit-string seed; the symmetric Young projector pulls the symmetric component out and normalisation finishes the job.

```wolfram
dickeState[k_] := With[
    {raw = YoungProject[
        Normal @ SparseArray[
            Join[ConstantArray[2, k], ConstantArray[1, n - k]] -> 1,
            ConstantArray[2, n]],
        nTab]},
    raw / Norm[Flatten[raw]]
];
dicke = dickeState /@ Range[0, n];
```

The six Dicke states form an orthonormal basis of the symmetric subspace; their Gram matrix is the $6 \times 6$ identity.

```wolfram
Chop[Outer[Flatten[#1] . Flatten[#2] &, dicke, dicke, 1] - IdentityMatrix[n + 1]]
```

The TN compression payoff is the dimension of the symmetric subspace, which is exactly what `SchurDimension[{n}, 2]` returns. The Schur-Weyl decomposition isolates this $(n + 1)$-dimensional sector inside the $2^n$-dimensional full Hilbert space.

```wolfram
Table[
    {nn, SchurDimension[{nn}, 2], 2^nn,
     SetPrecision[2.^nn / (nn + 1), 3]},
    {nn, 4, 10}
]
```

Read the rightmost column: at $n = 10$ the symmetric subspace is 11-dimensional inside a 1024-dimensional Hilbert space, a 93-fold compression. Every TN algorithm that promises to stay in the symmetric sector (Dicke-state preparation, Lipkin-Meshkov-Glick spin models, permutation-invariant Ansätze) only needs to allocate and contract $O(n)$ amplitudes per bond, not $O(2^n)$. The `YoungProject` on $\{n\}$ produces the state, the `SchurDimension[{n}, 2]` produces the bond size, and built-in `TensorContract` / `Dot` see and preserve the symmetry sector automatically.

Time the W-state construction across a sweep of $n$. The builder below applies the $\{n\}$ Young projector to the single-excitation seed and normalises; the table reports $n = 4, 6, 8, 10, 12$.

```wolfram
buildW[nn_] := With[
    {raw = YoungProject[
        Normal @ SparseArray[
            Prepend[ConstantArray[1, nn - 1], 2] -> 1,
            ConstantArray[2, nn]],
        YoungTableau[{nn}]]},
    raw / Norm[Flatten[raw]]
];
Table[{nn, First @ AbsoluteTiming[buildW[nn]]}, {nn, {4, 6, 8, 10, 12}}]
```

The construction stays sub-second up to $n = 12$. At $n = 13$ and above the internal `SymmetrizedArray` that backs `Symmetrize` runs out of memory enumerating $S_n$ orbits, and the recipe stops. The output tensor would still fit ($2^{20} = 1$ M doubles $\approx 8$ MB even at $n = 20$); the wall is the symmetriser construction, not the storage. For $n \geq 13$, bypass `YoungProject` and build Dicke states directly in the $(n + 1)$-dimensional symmetric basis from one closed-form binomial amplitude per state. The bond size is `SchurDimension[{n}, 2] = n + 1` regardless of which route produces the state.

### Block-sparse trace: cross-shape contractions vanish identically

*Contracting two bond tensors block-diagonalises along symmetry classes: a symmetric tensor cannot 'see' an antisymmetric one. Projecting onto $\{2\}$ and $\{1, 1\}$ makes this explicit, and Schur orthogonality lets a contraction-path optimiser skip cross-shape products before any multiplication runs.*

The Frobenius trace $\operatorname{tr}(A \cdot B) = \sum_{ij} A_{ij} B_{ji}$ is the basic two-tensor contraction over a rank-2 bond. It admits a block-sparse decomposition along symmetry classes: the trace splits into pairs $(\lambda, \mu)$ and the two cross-shape pairs vanish identically. A symmetry-aware contraction-path optimiser skips them before any multiplication.

Build two random rank-2 tensors at $d = 6$.

```wolfram
SeedRandom[100];
d = 6;
M1 = RandomReal[{-1, 1}, {d, d}];
M2 = RandomReal[{-1, 1}, {d, d}];
```

Compute the dense Frobenius trace as a baseline.

```wolfram
fullTrace = Tr[M1 . M2]
```

Project $M_1$ onto the symmetric shape.

```wolfram
Ms1 = YoungProject[M1, symTab];
```

Project $M_1$ onto the antisymmetric shape.

```wolfram
Ma1 = YoungProject[M1, antiTab];
```

Project $M_2$ onto the symmetric shape.

```wolfram
Ms2 = YoungProject[M2, symTab];
```

Project $M_2$ onto the antisymmetric shape.

```wolfram
Ma2 = YoungProject[M2, antiTab];
```

The first cross-shape block, $\operatorname{tr}(M_{1,\{2\}} \cdot M_{2,\{1,1\}})$, vanishes.

```wolfram
Chop[Tr[Ms1 . Ma2]]
```

The other cross-shape block, $\operatorname{tr}(M_{1,\{1,1\}} \cdot M_{2,\{2\}})$, vanishes.

```wolfram
Chop[Tr[Ma1 . Ms2]]
```

The full trace equals the sum of only the two same-shape block traces.

```wolfram
Chop[fullTrace - (Tr[Ms1 . Ms2] + Tr[Ma1 . Ma2])]
```

The textbook identity $\operatorname{tr}(S \cdot A) = 0$ for $S$ symmetric and $A$ antisymmetric is the same Schur-orthogonality statement, in one line: $S_{ij} A_{ji} = S_{ji} A_{ji} = -S_{ji} A_{ij}$, then relabel $i \leftrightarrow j$ to get $\operatorname{tr}(S \cdot A) = -\operatorname{tr}(S \cdot A)$. The Symmetry functions turn this into a contraction-path skipping rule: whenever a bond connects a $\{2\}$-typed tensor to a $\{1, 1\}$-typed one, the contribution is zero by construction. At rank 2 this skips 50% of the block multiplications; the savings grow with rank, as the rank-3 example next shows (at $d = 2$ the $\{1, 1, 1\}$ block is empty, so its contraction is skipped before any data is touched).

---

# Beyond rank 2: three higher-rank payoffs

Rank 2 admits only two Young diagrams ($\{2\}$ and $\{1, 1\}$), so `IntegerPartitions[2]`, `HookLengths`, `HookFactor`, `TableauDimension`, and `SchurDimension` all return trivially small answers. At rank 3 and above the toolbox switches on: partitions of $n$ proliferate (three at $n = 3$, five at $n = 4$, seven at $n = 5$), each with its own physical interpretation (bosonic, parastatistical, fermionic, curvature-like) and bond-dimension growth in $d$. Enumeration, sizing, and projection now require the combinatorial layer in earnest. The three sections below exercise it on three orthogonal axes, each isolating a qualitative capability that the rank-2 examples could not show:

- The **Schur-Weyl decomposition on three sites** uses the full partition arithmetic at rank 3: how a generic $d=2$ three-qubit bond splits into bosonic, parastatistical, and fermionic blocks, and how `TableauDimension[par] * SchurDimension[par, d]` reads off block sizes before any contraction.
- The **Riemann curvature tensor** is the canonical rank-4 example where built-in `Symmetrize` falls short: the algebraic first Bianchi identity is a multi-term relation that no `{Cycles[...], phase}` generator list can express, and it is the explicit content of the $\{2,2\}$ Young projector. We derive the Bianchi identity from the projector itself rather than verifying it post-hoc.
- The **class-function Hamiltonian** $\sum_{i<j} P_{ij}$ closes the arc. Its full spectrum on $V^{\otimes n}$ is the content sum $c(\lambda)$ over partitions of $n$, with multiplicities $\dim V_\lambda \cdot \dim W_\lambda(d)$. No eigenvalue routine; every spectral line is a closed-form expression in the combinatorial functions above.

## Schur-Weyl on three sites: how a tensor decomposes by symmetry

*Three indistinguishable particles split into a bosonic block, a fermionic block, and a parastatistical mixed-symmetry block: the canonical Schur-Weyl decomposition of $V \otimes V \otimes V$. `IntegerPartitions`, `TableauDimension`, and `SchurDimension` deliver all three block sizes in closed form, and `YoungProject` produces the actual tensors in each block.*

Take $V = \mathbb{C}^2$ and look at the rank-3 tensor space $V \otimes V \otimes V$. It has dimension $d^n = 2^3 = 8$. The Schur-Weyl theorem says this space splits into pieces labelled by partitions of 3 (i.e. irreducible representations of $S_3$):

$$
V \otimes V \otimes V \;=\; \bigoplus_{\lambda \vdash 3} V_\lambda \otimes S^\lambda(\mathbb{C}^d).
$$

The three partitions are $\{3\}$ (fully symmetric, bosonic), $\{2,1\}$ (mixed symmetry), and $\{1,1,1\}$ (fully antisymmetric, fermionic). Each block has dimension $\dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$. The first factor is the $S_n$ irreducible representation dimension; the second is the Weyl dimension formula:

$$
\dim S^\lambda(\mathbb{C}^d) \;=\; \prod_{(i,j) \in \lambda} \frac{d + j - i}{h(i,j)}.
$$

Here $h(i, j)$ is the *hook length* of cell $(i, j)$: the number of cells in its hook (itself, the cells to its right in the same row, and the cells below it in the same column), computed below by `HookLength` and `HookLengths`.

Enumerate the partitions of $3$ with the built-in `IntegerPartitions[n]`, which returns them in reverse-lexicographic order (fully symmetric $\{n\}$ first, fully antisymmetric $\{1, \ldots, 1\}$ last). The list length is the partition counting function $p(n)$, equal to the number of $S_n$ irreducible representations.

```wolfram
parts = IntegerPartitions[3]
```

Validate each one is a legal Young-diagram shape (non-increasing, positive integers, non-empty).

```wolfram
PartitionQ /@ parts
```

For a bond of dimension $d$, only diagrams with at most $d$ rows contribute; the rest give zero-dimensional Weyl modules. The two-argument form `IntegerPartitions[n, d]` pre-filters to the irreducible representations that fit in the bond. At $n = 3$, $d = 2$ the fermionic $\{1, 1, 1\}$ drops out.

```wolfram
IntegerPartitions[3, 2]
```

`HookLength[tab, {r, c}]` reads a single hook value at one cell of the diagram. The mixed-symmetry shape $\{2, 1\}$ has three cells; the top-left cell has hook length $3$ (itself, the cell to its right, the cell below).

```wolfram
HookLength[YoungTableau[{2, 1}], {1, 1}]
```

The other two cells of $\{2, 1\}$ are corners; each has hook length $1$.

```wolfram
{HookLength[YoungTableau[{2, 1}], {1, 2}],
 HookLength[YoungTableau[{2, 1}], {2, 1}]}
```

`HookLengths[par]` returns all hook lengths in one nested list, matching the diagram's row structure.

```wolfram
HookLengths[{2, 1}]
```

`HookFactor[par]` is the reciprocal of the hook-length product, evaluated by the Frobenius determinant formula in $O(r^2)$ where $r$ is the number of rows.

```wolfram
HookFactor[{2, 1}]
```

The irreducible representation dimension is $n!$ times the hook factor, which is exactly what `TableauDimension` packages.

```wolfram
TableauDimension[{2, 1}] == 3! * HookFactor[{2, 1}]
```

Read off all three $S_3$ irreducible representation dimensions in one shot.

```wolfram
TableauDimension /@ parts
```

The sum of squared dimensions equals $|S_3| = 6$ (the Plancherel identity).

```wolfram
Total[TableauDimension[#]^2 & /@ parts]
```

`TransposePartition` is the boson↔fermion duality: flipping the diagram across its main diagonal swaps the symmetric and antisymmetric statistics. The mixed-symmetry $\{2, 1\}$ is self-conjugate at $n = 3$.

```wolfram
TransposePartition /@ parts
```

The GL($d$) factor of the Weyl dimension formula is exported as `SchurDimension[par, d]`, the Symmetry functions' hook-content-formula counterpart to `TableauDimension`: while `TableauDimension[par]` returns the $S_n$ irreducible representation dim $\dim V_\lambda$ (independent of $d$), `SchurDimension[par, d]` returns the $GL(d)$ Weyl module dim $\dim W_\lambda(d) = \prod_{(i,j) \in \lambda}(d + j - i)/h(i, j)$. The two together give the size of the $\lambda$-block of $V^{\otimes n}$.

Predict the block sizes at $d=2, n=3$:

```wolfram
Table[
    par -> {TableauDimension[par], SchurDimension[par, 2],
            TableauDimension[par] * SchurDimension[par, 2]},
    {par, parts}
]
```

Read row by row: the $\{3\}$ block has size $1 \cdot 4 = 4$ (a four-dimensional bosonic sector). The $\{2,1\}$ mixed block has size $2 \cdot 2 = 4$. The $\{1,1,1\}$ fermionic block has size $1 \cdot 0 = 0$, *exactly zero*, because you cannot antisymmetrise three slots over a two-dimensional space (the Pauli principle for three spin-$\tfrac12$ particles forbids it). The sum is $4 + 4 + 0 = 8 = d^n$. The decomposition exhausts the tensor space and tells you, without ever forming a projector, that any operation involving the $\{1,1,1\}$ sector can be skipped.

When the input is already a `YoungTableau`, `TableauWeylDimension[tab, d]` returns the same $\dim W_\lambda(d)$ by delegating to `SchurDimension[TableauShape[tab], d]`. Pair it with `TableauDimension[tab]` to read both Schur-Weyl factors off the same object.

```wolfram
TableauWeylDimension[YoungTableau[#], 2] & /@ parts
```

The construction generalises to higher $n$ and is the foundation of symmetry-resolved DMRG / TDVP: every bond carries an exact decomposition by partition $\lambda$ and the block dimensions are read off in closed form.

Measure the decomposition explicitly, projector by projector. For each $\lambda \vdash 3$, the isotypic projector $E_\lambda$ on $V^{\otimes 3}$ is the sum of single-tableau Young projectors over the standard tableaux of shape $\lambda$. There is one of shape $\{3\}$ (namely $\{\{1, 2, 3\}\}$), two of shape $\{2, 1\}$ ($\{\{1, 2\}, \{3\}\}$ and $\{\{1, 3\}, \{2\}\}$, matching `TableauDimension[{2, 1}] = 2`), and one of shape $\{1, 1, 1\}$ ($\{\{1\}, \{2\}, \{3\}\}$).

Build a random rank-3 tensor in $d = 2$.

```wolfram
SeedRandom[7];
T3 = RandomReal[{-1, 1}, {2, 2, 2}];
```

Project onto the fully symmetric block (one standard tableau of shape $\{3\}$).

```wolfram
e3 = YoungProject[T3, YoungTableau[{{1, 2, 3}}]];
```

Project onto the mixed-symmetry block (sum over the two standard tableaux of shape $\{2, 1\}$).

```wolfram
e21 = YoungProject[T3, YoungTableau[{{1, 2}, {3}}]] +
      YoungProject[T3, YoungTableau[{{1, 3}, {2}}]];
```

Project onto the fully antisymmetric block (one standard tableau of shape $\{1, 1, 1\}$).

```wolfram
e111 = YoungProject[T3, YoungTableau[{{1}, {2}, {3}}]];
```

The three pieces sum to the original tensor (completeness of the isotypic decomposition).

```wolfram
Max[Abs[Flatten[e3 + e21 + e111 - T3]]] < tol
```

And the predicted vanishing of the fermionic piece holds identically:

```wolfram
Max[Abs[Flatten[e111]]] < tol
```

The decomposition is exact, computed without any eigenvalue routine. Each Symmetry function plays a distinct role:

- `YoungTableau` names each block by its shape.
- `YoungProject` projects the input tensor onto that block.
- `TableauDimension` counts standard tableaux per shape: the number of `YoungProject` calls to sum into the isotypic $E_\lambda$.
- `HookLengths` feeds `SchurDimension` for the $GL(d)$ factor.

The projector is insensitive to complex entries: $P_{12}$ relabels slots, so $T \mapsto T^T$ is transpose with no conjugation. Repeat on a random complex rank-3 tensor.

```wolfram
SeedRandom[11];
T3c = RandomComplex[{-1 - I, 1 + I}, {2, 2, 2}];
```

Project the complex tensor onto the fully symmetric block.

```wolfram
e3c = YoungProject[T3c, YoungTableau[{{1, 2, 3}}]];
```

Project onto the mixed-symmetry block.

```wolfram
e21c = YoungProject[T3c, YoungTableau[{{1, 2}, {3}}]] +
       YoungProject[T3c, YoungTableau[{{1, 3}, {2}}]];
```

Project onto the fully antisymmetric block.

```wolfram
e111c = YoungProject[T3c, YoungTableau[{{1}, {2}, {3}}]];
```

The three complex pieces still sum to the original tensor.

```wolfram
Max[Abs[Flatten[e3c + e21c + e111c - T3c]]] < tol
```

Hermiticity is `ConjugateTranspose` (transpose composed with conjugation) and lives in built-in WL's `Hermitian[{1,2}]` symmetry head, not in the $S_n$ representation theory the Symmetry functions implement. The two layers compose without collapsing: a tensor can be Hermitian without being symmetric, and the Young projector touches only the symmetric / antisymmetric layer.

### Block-sparse Frobenius contraction on a rank-3 bond

*Contracting two rank-3 tensors splits cleanly along symmetry sectors: only same-sector pieces talk. `YoungProject` decomposes each tensor into its bosonic, parastatistical, and fermionic blocks; the six cross-block Frobenius products vanish identically by Schur orthogonality, telling the contraction engine which products to skip.*

The block decomposition is not just a vector-space identity: it makes inner products block-diagonal. The Frobenius (Hilbert-Schmidt) contraction $\langle T, S \rangle = \sum_{ijk} T_{ijk} S_{ijk}$ between two rank-3 tensors on the same bond splits into a sum of three within-block pieces, with every cross-block term zero. This is the rank-3 analogue of the rank-2 block-sparse trace, and it is the workhorse identity behind symmetry-resolved tensor-network contractions: a network of symmetric tensors decomposes into a direct sum of smaller networks, one per irreducible representation.

Build a second random rank-3 tensor $S$ on the same $d{=}2$ bond.

```wolfram
SeedRandom[200];
S3 = RandomReal[{-1, 1}, {2, 2, 2}];
```

Compute the full Frobenius contraction directly.

```wolfram
froFull = Total[Flatten[T3 * S3]]
```

Project $S$ onto the fully symmetric block.

```wolfram
f3 = YoungProject[S3, YoungTableau[{{1, 2, 3}}]];
```

Project $S$ onto the mixed-symmetry block.

```wolfram
f21 = YoungProject[S3, YoungTableau[{{1, 2}, {3}}]] +
      YoungProject[S3, YoungTableau[{{1, 3}, {2}}]];
```

Project $S$ onto the fully antisymmetric block.

```wolfram
f111 = YoungProject[S3, YoungTableau[{{1}, {2}, {3}}]];
```

Contract within the fully symmetric block.

```wolfram
b3 = Total[Flatten[e3 * f3]]
```

Contract within the mixed-symmetry block.

```wolfram
b21 = Total[Flatten[e21 * f21]]
```

Contract within the fully antisymmetric block.

```wolfram
b111 = Total[Flatten[e111 * f111]]
```

The same block-sparsity holds inside the paclet's TN flow. Build the unprojected two-node network over $T$ and $S$ with all three indices shared, contract it, and recover the full Frobenius product.

```wolfram
bareFro = TensorNetworkContract @
    TensorNetwork[{T3, S3}, {{"i", "j", "k"}, {"i", "j", "k"}}, {}]
```

Apply `YoungProject` to both nodes inside the network, restricting them to a chosen irrep sector before the contraction runs. The helper below sums over the standard tableaux of a given shape, projects both inputs into that sector, and contracts the resulting two-node TN.

```wolfram
sectorContract[U_, V_, syt_List] :=
    TensorNetworkContract @ TensorNetwork[
        {Total[YoungProject[U, YoungTableau[#]] & /@ syt],
         Total[YoungProject[V, YoungTableau[#]] & /@ syt]},
        {{"i", "j", "k"}, {"i", "j", "k"}}, {}
    ];
```

List the three standard-tableau sets and evaluate the three within-sector contractions through the paclet's contraction engine.

```wolfram
{syt3, syt21, syt111} = {
    {{{1, 2, 3}}},
    {{{1, 2}, {3}}, {{1, 3}, {2}}},
    {{{1}, {2}, {3}}}
};
{sectorContract[T3, S3, syt3],
 sectorContract[T3, S3, syt21],
 sectorContract[T3, S3, syt111]}
```

The three within-sector contractions sum to the bare Frobenius product.

```wolfram
Chop[bareFro - Total @ {
    sectorContract[T3, S3, syt3],
    sectorContract[T3, S3, syt21],
    sectorContract[T3, S3, syt111]
}] < tol
```

Mismatched-sector projections give zero by Schur orthogonality: $T_3$ projected onto one shape against $S_3$ projected onto a *different* shape vanishes for every cross-shape pair.

```wolfram
crossContract[U_, V_, sytU_List, sytV_List] :=
    TensorNetworkContract @ TensorNetwork[
        {Total[YoungProject[U, YoungTableau[#]] & /@ sytU],
         Total[YoungProject[V, YoungTableau[#]] & /@ sytV]},
        {{"i", "j", "k"}, {"i", "j", "k"}}, {}
    ];
Chop @ {
    crossContract[T3, S3, syt3,   syt21], crossContract[T3, S3, syt3,   syt111],
    crossContract[T3, S3, syt21,  syt3],  crossContract[T3, S3, syt21,  syt111],
    crossContract[T3, S3, syt111, syt3],  crossContract[T3, S3, syt111, syt21]
}
```

The sum of the three within-block contractions reproduces the full Frobenius product.

```wolfram
Chop[froFull - (b3 + b21 + b111)]
```

Now demonstrate that every cross-block term vanishes identically: the $\{3\}$ block of $T$ does not see the $\{2,1\}$ or $\{1,1,1\}$ block of $S$, and so on.

```wolfram
Chop[{Total[Flatten[e3 * f21]],   Total[Flatten[e3 * f111]],
      Total[Flatten[e21 * f3]],   Total[Flatten[e21 * f111]],
      Total[Flatten[e111 * f3]],  Total[Flatten[e111 * f21]]}]
```

At $d = 2$ the fully antisymmetric block $\{1, 1, 1\}$ is identically zero: three mutually orthogonal antisymmetric labels cannot fit in a two-dimensional space (Pauli exclusion for three fermions on a two-level bond).

```wolfram
Chop[b111]
```

That zero is exact, not numerical: the same Pauli-exclusion zero that killed the rank-2 antisymmetric singlet at $d = 1$, lifted by one slot. At $d = 2$ the full Frobenius product on a rank-3 bond is exhausted by only two within-block contractions, the $\{3\}$ and $\{2, 1\}$ pieces.

```wolfram
Chop[froFull - (b3 + b21)]
```

The payoff for TN code is concrete: with an $S_n$ symmetry constraint on the bond, only irreducible representations whose diagrams fit in dimension $d$ contribute. Diagrams with more than $d$ rows give the zero subspace and drop out of the bond enumeration before any contraction begins. `TableauDimension`, `HookFactor`, and the diagram itself are exactly the bookkeeping for this dimension-aware enumeration.

## The Riemann tensor as a TN node

*The Riemann curvature tensor obeys four algebraic symmetries: two pair-antisymmetries, a pair-swap symmetry, and the multi-term first Bianchi identity. One `YoungProject` onto the $\{2, 2\}$ tableau enforces all four simultaneously, including the Bianchi identity that built-in `Symmetrize` cannot reach with any single permutation generator.*

The Riemann curvature tensor $R_{abcd}$ is a rank-4 tensor with four classical symmetries:

1. Antisymmetric in the first pair: $R_{abcd} = -R_{bacd}$.
2. Antisymmetric in the second pair: $R_{abcd} = -R_{abdc}$.
3. Symmetric under pair swap: $R_{abcd} = R_{cdab}$.
4. *First Bianchi identity*: $R_{abcd} + R_{acdb} + R_{adbc} = 0$.

The first three are *single-term* slot symmetries (each says $T = \pm T^\sigma$ for one permutation $\sigma$). Standard WL canonicalisation via `TensorReduce[Arrays[..., sym]]` covers them. The fourth, the first Bianchi identity, is *multi-term*: a sum of three permutations is zero, and no single $(\sigma, \phi)$ pair tells you that. **This is the gap the Symmetry functions fill.**

All four constraints together are the content of a single $S_4$ irreducible representation, the one labelled by the partition $\{2, 2\}$. The Riemann tensor *is* the projection of a generic rank-4 tensor onto this irreducible representation, and one `YoungProject` call enforces every constraint at once.

Before doing the projection, inspect the combinatorial data of the $\{2, 2\}$ diagram. First, confirm $\{2, 2\}$ is a valid partition.

```wolfram
PartitionQ[{2, 2}]
```

Read off the hook-length nested list. The diagram has four cells arranged in a $2 \times 2$ square.

```wolfram
HookLengths[{2, 2}]
```

The hook-length product is $3 \cdot 2 \cdot 2 \cdot 1 = 12$, so the hook factor is $1/12$.

```wolfram
HookFactor[{2, 2}]
```

The irreducible representation dimension is $4!/12 = 2$: the Riemann irreducible representation is two-dimensional.

```wolfram
TableauDimension[{2, 2}]
```

The shape is self-conjugate (a square diagram is its own transpose), which is why the Riemann irreducible representation sits "on the diagonal" of the $S_4$ representation table and does not flip statistics under partition-conjugation.

```wolfram
TransposePartition[{2, 2}]
```

### The mono-term-only attempt with built-in `Symmetrize`

*Built-in `Symmetrize` with the three mono-term Riemann pair generators leaves an $O(1)$ Bianchi residue: the boundary the Symmetry functions exist to cross.*

Take a generic rank-4 tensor in $d = 4$.

```wolfram
SeedRandom[42];
T0 = RandomReal[{-1, 1}, {4, 4, 4, 4}];
```

The three pair symmetries (the mono-term part of the Riemann conditions) lift directly into a built-in `Symmetrize` generator list.

```wolfram
riemannGens = {
    {Cycles[{{1, 2}}],         -1},   (* antisym in (1,2) *)
    {Cycles[{{3, 4}}],         -1},   (* antisym in (3,4) *)
    {Cycles[{{1, 3}, {2, 4}}],  1}    (* pair-swap *)
};
```

Apply the built-in projector to obtain a mono-term-symmetrised rank-4 tensor.

```wolfram
Rmono = Normal @ Symmetrize[T0, riemannGens];
```

Check antisymmetry in the first pair $(1, 2)$.

```wolfram
Max[Abs[Flatten[Rmono + Transpose[Rmono, {2, 1, 3, 4}]]]] < tol
```

Check antisymmetry in the second pair $(3, 4)$.

```wolfram
Max[Abs[Flatten[Rmono + Transpose[Rmono, {1, 2, 4, 3}]]]] < tol
```

Check pair-swap symmetry $(1, 2) \leftrightarrow (3, 4)$.

```wolfram
Max[Abs[Flatten[Rmono - Transpose[Rmono, {3, 4, 1, 2}]]]] < tol
```

All three pass. Now check the first Bianchi identity.

```wolfram
Max[Abs[Flatten[
    Rmono + Transpose[Rmono, {1, 3, 4, 2}] + Transpose[Rmono, {1, 4, 2, 3}]
]]]
```

Built-in `Symmetrize` produces a tensor with the three pair symmetries, but the Bianchi sum has $O(1)$ residual. No mono-term language can fix this: Bianchi asks three permuted copies to sum to zero, which is two relations short of the single-permutation form `Symmetrize` understands. The corresponding count is visible in `SymmetrizedIndependentComponents`: at dimension 4 with the three mono-term Riemann generators the kernel reports 21 independent components, whereas the true number of Riemann components (post-Bianchi) is $n^2 (n^2 - 1) / 12 = 20$. The single missing relation is Bianchi.

### The Young-projector solution: discovering the algebraic identities

*The four classical Riemann symmetries are not separately *assumed* but *derived* from the $\{2, 2\}$ projector itself. Searching the right-annihilator of $R$ in the group algebra $\mathbb{C}[S_4]$ recovers the textbook first Bianchi identity as one specific kernel element, without naming it in advance.*

The $\{2,2\}$ Young projector *defines* the Riemann irreducible representation: every tensor in its image satisfies the four classical Riemann identities by construction. The more interesting move is the reverse direction, **deriving those identities from the projector**, without listing them in advance. The Symmetry functions make this constructive rather than verifying.

Begin by fixing a slot labelling: build the rank-4 Young tableau whose two columns hold the two antisymmetric pairs and whose two rows hold the pair-swap-symmetric slots.

```wolfram
YoungTableau[{{1, 3}, {2, 4}}]
```

Evaluating returns the typed tableau with its rendered $2 \times 2$ diagram filled with the slot labels `1, 3` (row 1) and `2, 4` (row 2); the same nested list `{{1, 3}, {2, 4}}` round-trips out via `TableauRows`. Name the tableau once and project the generic rank-4 tensor.

```wolfram
tab = YoungTableau[{{1, 3}, {2, 4}}];
R = YoungProject[T0, tab];
```

An element $\sum_k c_k\, \sigma_k \in \mathbb{C}[S_4]$ acts on $R$ as $\sum_k c_k\, \sigma_k(R)$, and is an algebraic identity of $R$ exactly when that sum is zero. The right-annihilator of $R$ in $\mathbb{C}[S_4]$ is the space of identities the $\{2, 2\}$ irreducible representation enforces, and it is searchable: precompute the 24 permuted copies of $R$ once and the relation predicate becomes a single dot product against a coefficient vector.

```wolfram
perms = Permutations[Range[4]];
permutedR = Transpose[R, #] & /@ perms;
isRelation[coefs_] := Max[Abs[Flatten[coefs . permutedR]]] < tol;
```

Sweep all two-term combinations $\sigma_a + \varepsilon\, \sigma_b$ over $a < b$ and $\varepsilon \in \{\pm 1\}$ using `Subsets` to enumerate ordered index pairs and `Cases` to keep only the annihilators, decoded as $(\sigma_a, \varepsilon, \sigma_b)$ triples.

```wolfram
twoTerm = Cases[
    Tuples[{Subsets[Range[24], {2}], {1, -1}}],
    {{a_, b_}, eps_} /; isRelation[SparseArray[{a -> 1, b -> eps}, 24]] :>
        {perms[[a]], eps, perms[[b]]}
];
Length[twoTerm]
```

The search returns 84 two-term identities, derived without input from the textbook. They include the three classical Riemann pair-symmetries plus every consequence (composing two pair-antisymmetries gives a pair-swap, etc.). Extract the textbook three from the discovered list by set intersection.

```wolfram
Intersection[twoTerm, {
    {{1, 2, 3, 4},  1, {2, 1, 3, 4}},
    {{1, 2, 3, 4},  1, {1, 2, 4, 3}},
    {{1, 2, 3, 4}, -1, {3, 4, 1, 2}}
}]
```

The three textbook generators (slot $(1,2)$ antisym, slot $(3,4)$ antisym, pair-swap) are present in the discovered list, but not privileged: the projector treats all 84 derived two-term identities on equal footing.

Now sweep three-term identities $\sigma_a + \sigma_b + \sigma_c$ supported on permutations that fix slot 1 (i.e. act non-trivially only on slots $\{2, 3, 4\}$). The Bianchi identity will appear here without our naming it. The slot-1-fixing positions come straight from `Position`; the subset enumerator is `Subsets[*, {3}]`.

```wolfram
fixSlot1 = Flatten @ Position[perms, {1, _, _, _}];
threeTerm = Cases[
    Subsets[fixSlot1, {3}],
    {a_, b_, c_} /; isRelation[SparseArray[{a -> 1, b -> 1, c -> 1}, 24]] :>
        perms[[{a, b, c}]]
];
Length[threeTerm]
```

Two three-term annihilators. One of them is precisely the cyclic permutations of slots $\{2, 3, 4\}$ acting on $R$: identity, $(2\,3\,4)$, and $(2\,4\,3)$. This is the **first Bianchi identity** $R_{abcd} + R_{acdb} + R_{adbc} = 0$, derived here from the projector definition with no textbook input.

```wolfram
Position[threeTerm, {{1, 2, 3, 4}, {1, 3, 4, 2}, {1, 4, 2, 3}}]
```

Bianchi appears at position 1; the second three-term identity is its image under the pair-swap-plus-(34)-antisym relations already in the two-term sweep. The multi-term constraint that `Symmetrize` could not reach has been generated from the $\{2, 2\}$ Young projector itself, not assumed, not looked up.

For completeness, point-check the four classical Riemann identities on $R$ directly (redundant now, since each is in the discovered list).

```wolfram
Max[Abs[Flatten[R + Transpose[R, {2, 1, 3, 4}]]]] < tol
```

```wolfram
Max[Abs[Flatten[R + Transpose[R, {1, 2, 4, 3}]]]] < tol
```

```wolfram
Max[Abs[Flatten[R - Transpose[R, {3, 4, 1, 2}]]]] < tol
```

```wolfram
Max[Abs[Flatten[
    R + Transpose[R, {1, 3, 4, 2}] + Transpose[R, {1, 4, 2, 3}]
]]] < tol
```

All four hold. The first three are mono-term and reachable by built-in `Symmetrize` (and built-in `TensorSymmetry` would report them); the last is the Bianchi identity, multi-term, *not* reachable by `Symmetrize`, and the very thing the discovery loop above just produced from scratch.

### Composition with built-in `TensorSymmetry`

*A `YoungProject`-output tensor is recognised by built-in `TensorSymmetry`, which reports the three mono-term Riemann pair generators (but not Bianchi, which is multi-term). The two layers compose cleanly: multi-term projection upstream, mono-term detection downstream.*

After projection, the mono-term content of $R$ is detected by `TensorSymmetry`:

```wolfram
TensorSymmetry[R]
```

Built-in WL reports the three Riemann pair generators. Bianchi is not a `{perm, phase}` relation so it cannot be a generator here, even though it is satisfied identically by the components of $R$. The roles divide cleanly: the Symmetry functions produce a tensor in the irreducible representation, `TensorSymmetry` reads off the mono-term subgroup of its slot symmetries. `YoungProject` outputs a plain array (or a `SymmetrizedArray`-compatible structure) that built-in WL handles directly.

### The TN reward

*Once $R$ sits in the $\{2, 2\}$ block, contracting one upper-lower pair via `TensorContract` produces the symmetric Ricci tensor with no separate re-symmetrisation step. Built-in tensor machinery sees and preserves the irreducible-representation structure automatically.*

Once $R$ lives in the right irreducible representation, downstream contractions preserve the structure for free. The Euclidean Ricci tensor is the partial trace $R_{bd} = \delta^{ac} R_{abcd}$, written `TensorContract[R, {{1, 3}}]`. It comes out symmetric automatically:

```wolfram
Ric = TensorContract[R, {{1, 3}}];
Max[Abs[Flatten[Ric - Transpose[Ric]]]] < tol
```

No separate re-symmetrisation step. The scalar curvature is the trace of the Ricci tensor:

```wolfram
Tr[Ric]
```

The Weyl tensor is *not* a separate $S_4$ irreducible representation: it is the trace-free part of the $\{2,2\}$ block under the $O(d)$ action on the four vector indices. Extracting it requires subtracting Ricci and scalar-curvature traces using the metric, which is $O(d)$ (or $GL(d)$) representation theory on the *indices*, not $S_n$ representation theory on the *slots*. The Symmetry functions handle the slot layer cleanly; the index-level $O(d)$ decomposition into Weyl + traceless Ricci + scalar lives on top of it.

### Component count at arbitrary spacetime dimension

*The Riemann tensor has $d^2(d^2-1)/12$ independent components in dimension $d$ (1, 6, 20, 50 at $d = 2, 3, 4, 5$). `SchurDimension[{2, 2}, d]` returns this textbook count in closed form via the hook-content formula, and a brute-force `MatrixRank` of the projector confirms it numerically at small $d$.*

How many independent Riemann components are there in dimension $d$? The textbook answer is $d^2(d^2-1)/12$ (so 1, 6, 20, 50 at $d = 2, 3, 4, 5$). That count is *exactly* the dimension of the $GL(d)$ Weyl module $W_{\{2,2\}}$, which is the value of the Schur polynomial $s_{2,2}(1^d)$ that our `HookLengths`-driven `SchurDimension` returns. Apply it at the four physically interesting dimensions.

```wolfram
Table[{d, SchurDimension[{2, 2}, d]}, {d, {2, 3, 4, 5}}]
```

Numerically verify the $d = 4$ count by computing the rank of the linear map $T \mapsto \mathrm{YoungProject}[T, \mathrm{YoungTableau}[\{\{1, 3\}, \{2, 4\}\}]]$ on the $4^4$-dimensional space of generic rank-4 tensors.

```wolfram
projectionRank[d_] := MatrixRank @ Transpose @ Map[
    Flatten[YoungProject[ArrayReshape[#, {d, d, d, d}],
                         YoungTableau[{{1, 3}, {2, 4}}]]] &,
    IdentityMatrix[d^4]
];
projectionRank[4]
```

Twenty, as expected. The full $S_4 \otimes GL(d)$ block dimension is twice this, since `TableauDimension[{2,2}] = 2` (there are two standard tableaux of shape $\{2,2\}$, hence two isomorphic copies of the irreducible representation living inside $V^{\otimes 4}$): the second standard tableau is `YoungTableau[{{1, 2}, {3, 4}}]`, projecting onto a separate 20-dimensional subspace orthogonal to the first.

### TN-bond enumeration for a rank-4 bond

*A rank-4 TN tensor at bond dimension $d = 4$ splits into five irreducible-representation blocks of sizes $\{35, 135, 40, 45, 1\}$, summing to $4^4 = 256$. `IntegerPartitions[4]`, `TableauDimension`, and `SchurDimension` together produce this table in closed form, which a symmetry-resolved TN library consults to pre-allocate block storage before any contraction runs.*

All five partitions of 4 together decompose the rank-4 tensor space at $d = 4$ block-by-block.

```wolfram
Table[
    par -> {TableauDimension[par], SchurDimension[par, 4],
            TableauDimension[par] * SchurDimension[par, 4]},
    {par, IntegerPartitions[4]}
]
```

Read the totals column ($\dim V_\lambda \cdot \dim W_\lambda(4)$): $35 + 135 + 40 + 45 + 1 = ?$. Sum it.

```wolfram
Total[TableauDimension[#] * SchurDimension[#, 4] & /@ IntegerPartitions[4]]
```

The total is $256 = 4^4$: the five sectors exhaust the space. A TN library can carry the same data either as a flat $256$-vector or as five block-sparse pieces of sizes $\{35, 135, 40, 45, 1\}$. When symmetry forbids transitions between sectors (e.g. only $\{2, 2\}$ is dynamical, as for a curvature tensor), the block-sparse form needs $40$ numbers instead of $256$: a $6.4\times$ compression at $d = 4$, $6.2\times$ at $d = 6$ ($\{2, 2\}$ block holds $2 \cdot 105 = 210$ out of $6^4 = 1296$), and so on.

The dimension counting itself costs only a few hook-length products, the cheapest pre-allocation step in a symmetry-resolved TN code.

### Block-sparse contraction on a rank-4 bond

*Contracting two rank-4 tensors at $d = 4$ splits into a $5 \times 5$ same-sector-only diagonal: 20 cross-sector products are zero by Schur orthogonality. When one tensor is symmetry-constrained (e.g. Riemann-like, $\{2, 2\}$-block only), the contraction collapses from 256 multiplications to 40, a $6.4\times$ FLOP saving per bond that compounds across a many-tensor network.*

The enumeration is more than bookkeeping. Every Frobenius contraction of two rank-4 tensors at $d = 4$ block-decomposes by Schur orthogonality: only same-sector pairs contribute, every cross-sector contribution is zero. Build two generic random rank-4 tensors.

```wolfram
SeedRandom[42];
T1 = RandomReal[{-1, 1}, {4, 4, 4, 4}];
SeedRandom[100];
T2 = RandomReal[{-1, 1}, {4, 4, 4, 4}];
```

The five partitions of 4 each have several standard tableaux (one per copy of the irreducible representation inside $V^{\otimes 4}$). Enumerate them in an `Association` keyed by partition.

```wolfram
syt = <|
    {4}          -> {{{1, 2, 3, 4}}},
    {3, 1}       -> {{{1, 2, 3}, {4}}, {{1, 2, 4}, {3}}, {{1, 3, 4}, {2}}},
    {2, 2}       -> {{{1, 2}, {3, 4}}, {{1, 3}, {2, 4}}},
    {2, 1, 1}    -> {{{1, 2}, {3}, {4}}, {{1, 3}, {2}, {4}}, {{1, 4}, {2}, {3}}},
    {1, 1, 1, 1} -> {{{1}, {2}, {3}, {4}}}
|>;
```

The *isotypic* projector $E_\lambda$ is the sum of single-tableau projectors over the standard tableaux of shape $\lambda$. It projects onto the full $\dim V_\lambda$ copies of the irreducible representation inside $V^{\otimes 4}$, and the five $E_\lambda$ together form a resolution of identity.

```wolfram
isotypic[T_, par_] := Total[YoungProject[T, YoungTableau[#]] & /@ syt[par]];
```

Project $T_1$ and $T_2$ block-by-block into associations keyed by partition.

```wolfram
T1blk = AssociationMap[isotypic[T1, #] &, IntegerPartitions[4]];
T2blk = AssociationMap[isotypic[T2, #] &, IntegerPartitions[4]];
```

The five blocks of $T_1$ sum back to $T_1$ (resolution of identity).

```wolfram
Max[Abs[Flatten[Total[Values[T1blk]] - T1]]] < tol
```

The full Frobenius contraction $\langle T_1, T_2 \rangle$ equals the sum of the five within-sector contractions.

```wolfram
{Total[Flatten[T1 * T2]],
 Total[Total[Flatten[T1blk[#] * T2blk[#]]] & /@ IntegerPartitions[4]]}
```

Form the $5 \times 5$ matrix of *cross-sector* contractions $\langle T_1^{(\lambda)}, T_2^{(\mu)} \rangle$. Every off-diagonal entry vanishes identically by Schur orthogonality.

```wolfram
Chop @ Outer[
    Total[Flatten[T1blk[#1] * T2blk[#2]]] &,
    IntegerPartitions[4], IntegerPartitions[4], 1
] // MatrixForm
```

The TN payoff is concrete: in block-sparse storage the off-diagonal terms are never computed. For two generic tensors the within-sector sums still total $256$ multiplications, so no savings. The win appears when a tensor is constrained to a single sector. A Riemann-like tensor lives only in the $\{2, 2\}$ block, so its contraction with any partner only sees the partner's $\{2, 2\}$ component: a $40$-multiplication contraction instead of $256$.

```wolfram
T2riemann = T2blk[{2, 2}];
{Total[Flatten[T1 * T2riemann]], Total[Flatten[T1blk[{2, 2}] * T2riemann]]}
```

Both contractions return the same scalar: only the $\{2, 2\}$ projection of $T_1$ contributes when its partner is Riemann-like. That is the $6.4 \times$ FLOP saving on this single bond contraction, with no approximation. In a many-tensor TN of symmetric or curvature-like tensors the per-bond savings compound multiplicatively, and the dimension table above tells the contraction-path optimiser which sector products to skip before any multiplication runs.

## A class-function Hamiltonian and content sums

*A permutation-invariant Hamiltonian $H = \sum_{i<j} P_{ij}$ on $n$ identical sites commutes with every isotypic projector, so its spectrum is the list of content sums $c(\lambda)$ over partitions of $n$ with multiplicities $\dim V_\lambda \cdot \dim W_\lambda(d)$. `TableauDimension`, `HookLengths`, and `SchurDimension` deliver every spectral line and degeneracy in closed form, no eigenvalue routine needed.*

The dimensions alone are useful, but the Symmetry functions also pre-compute eigenvalues of Hamiltonians that are *class functions* of $S_n$: operators built from permutations whose value depends only on cycle structure. The classic example is the sum of all pair-swaps,

$$
H \;=\; \sum_{i < j} P_{ij}
$$

acting on $V^{\otimes n}$, where $P_{ij}$ is the swap of the $i$th and $j$th tensor factors. By Schur-Weyl, $H$ commutes with every isotypic projector $E_\lambda$ and is therefore *constant on each $\lambda$-block*. The constant is the *content sum* of the partition,

$$
c(\lambda) \;=\; \sum_{(i,j) \in \lambda} (j - i),
$$

a simple sum over diagram cells. For $n = 3$ the three partitions give $c(\{3\}) = 0 + 1 + 2 = 3$, $c(\{2,1\}) = 0 + 1 - 1 = 0$, $c(\{1,1,1\}) = 0 - 1 - 2 = -3$. Together with the block multiplicities from the Schur-Weyl example earlier, *this is the full spectrum of $H$ with multiplicities*.

The eigenvalue $c(\lambda)$ depends only on the *partition*, not on any tensor data. Sanity-check that `IntegerPartitions[3]` produces legal Young-diagram shapes before consuming them in the formula.

```wolfram
AllTrue[IntegerPartitions[3], PartitionQ]
```

Encode the content sum:

```wolfram
contentSum[par_List] :=
    Total @ Flatten @ Table[j - i, {i, Length[par]}, {j, par[[i]]}];
```

For $d=2, n=3$ the predicted spectrum is

```wolfram
predicted = Sort[
    Flatten @ {
        ConstantArray[contentSum[{3}],       TableauDimension[{3}]       * SchurDimension[{3}, 2]],
        ConstantArray[contentSum[{2, 1}],    TableauDimension[{2, 1}]    * SchurDimension[{2, 1}, 2]],
        ConstantArray[contentSum[{1, 1, 1}], TableauDimension[{1, 1, 1}] * SchurDimension[{1, 1, 1}, 2]]
    },
    Greater
]
```

Four eigenvalues equal to $3$ in the $\{3\}$ block (four-dimensional), four equal to $0$ in the $\{2,1\}$ block (also four-dimensional), and zero copies of $-3$ because the $\{1,1,1\}$ block is empty at $d=2$.

Cross-check against an explicit matrix diagonalisation. First, build a helper that realises one pair-swap $P_{a, b}$ as a $d^3 \times d^3$ matrix at $d = 2$.

```wolfram
applySwap[a_, b_] := Module[{perm = Range[3]},
    perm[[{a, b}]] = perm[[{b, a}]];
    ArrayReshape[
        Transpose[
            Normal @ SparseArray[
                Flatten[Table[{i, j, k, i, j, k} -> 1,
                    {i, 2}, {j, 2}, {k, 2}], 2],
                {2, 2, 2, 2, 2, 2}
            ],
            Join[perm, {4, 5, 6}]
        ],
        {8, 8}
    ]
];
```

Assemble $H = P_{12} + P_{13} + P_{23}$ as an $8 \times 8$ matrix.

```wolfram
Hmat = applySwap[1, 2] + applySwap[1, 3] + applySwap[2, 3];
```

Diagonalise and sort the eigenvalues in descending order.

```wolfram
spectrum = Sort[Eigenvalues[Hmat], Greater]
```

The numerical spectrum agrees with the combinatorial prediction.

```wolfram
Max[Abs[spectrum - predicted]] < tol
```

The two lists agree exactly. The numerical diagonalisation was a courtesy; the spectrum was already determined by the combinatorics of `TableauDimension`, `SchurDimension` (powered by `HookLengths`), and `contentSum`.

That cross-check used an $8 \times 8$ matrix. The combinatorial path scales with the number of partitions $p(n)$, which grows slowly with $n$, while explicit diagonalisation scales with the matrix dimension $d^n$, which grows quickly. Generalise the helpers and time both paths on a larger system.

```wolfram
applySwapND[a_, b_, n_, d_] := Module[{perm = Range[n]},
    perm[[{a, b}]] = perm[[{b, a}]];
    ArrayReshape[
        Transpose[
            ArrayReshape[IdentityMatrix[d^n], ConstantArray[d, 2 n]],
            Join[perm, Range[n + 1, 2 n]]
        ],
        {d^n, d^n}
    ]
];

classFnH[n_, d_] :=
    Total[applySwapND[#[[1]], #[[2]], n, d] & /@ Subsets[Range[n], {2}]];

partitionSpectrum[n_, d_] := Sort[
    Flatten @ Map[
        ConstantArray[contentSum[#],
            TableauDimension[#] * SchurDimension[#, d]] &,
        IntegerPartitions[n]
    ],
    Greater
];
```

At $n = 6$, $d = 2$ the Hilbert space is 64-dimensional and the explicit Hamiltonian is a dense $64 \times 64$ matrix. Clear the cache and time both paths.

```wolfram
ClearSystemCache[];
{tCombi, sCombi} = AbsoluteTiming @ partitionSpectrum[6, 2];
ClearSystemCache[];
{tNaive, sNaive} = AbsoluteTiming @ Sort[Eigenvalues @ classFnH[6, 2], Greater];
{tCombi, tNaive}
```

```wolfram
Max[Abs[sCombi - sNaive]] < tol
```

The two spectra match to machine precision, and the combinatorial path finishes in sub-millisecond time while the dense diagonalisation takes orders of magnitude longer. The gap widens with $n$ and $d$, because the combinatorial cost is set by $p(n)$ partitions while the diagonalisation cost scales with $d^n$.

This is the payoff for permutation-invariant systems. Hamiltonians that are class functions of $S_n$ on the sites (all-to-all exchange, certain $J_1$-$J_2$ symmetric models, collective spin models) have their full spectrum determined by partitions of $n$ and block multiplicities. No exact diagonalisation, no Lanczos sweep, no SVD: a single sum over an $|\text{IntegerPartitions}[n]|$-entry table delivers every eigenvalue with multiplicity.

---

# Where this leaves us

Every Symmetry function in `` Wolfram`TensorNetworks`Symmetry` `` has appeared at least once on a tensor with a physical reason to exist. Five operational capabilities follow:

- **Block-size prediction.** For a rank-$n$ tensor and partition $\lambda \vdash n$, read the size of the $\lambda$-isotypic block at any bond dimension $d$ from `TableauDimension[par] * SchurDimension[par, d]`, and identify sectors that vanish identically (rank-3 fermionic at $d = 2$, rank-4 fully antisymmetric at $d \leq 3$, etc.). Demonstrated in the rank-3 Schur-Weyl table and the rank-4 enumeration.
- **Multi-term symmetry projection.** Enforce all classical Riemann symmetries (the three pair relations plus the multi-term first Bianchi identity) with a single `YoungProject` onto the $\{2, 2\}$ tableau, where built-in `Symmetrize` reaches only the mono-term subset. Demonstrated in the Riemann section, which also derives those identities by searching the right-annihilator of $R$ in $\mathbb{C}[S_4]$.
- **Statistics-sector projection that survives contraction.** Project a TN bond onto a chosen statistics sector (boson, fermion, or mixed); built-in `TensorContract` and `Dot` preserve the sector automatically downstream. Demonstrated on the fermionic bond and the Ricci partial trace.
- **Block-sparse contraction.** Replace a dense $d^n$-element bond contraction by the sum of within-sector contractions over the irreducible-representation blocks; cross-sector products are zero by Schur orthogonality. Demonstrated at rank 2 (block-sparse trace), rank 3 (block-sparse Frobenius), and rank 4 (the $5 \times 5$ same-sector-only diagonal; $6.4\times$ FLOP saving with one Riemann-like tensor).
- **Class-function Hamiltonian spectrum from combinatorics.** For $H = \sum_{i < j} P_{ij}$, every eigenvalue with multiplicity follows from `TableauDimension`, `HookLengths`, `SchurDimension`, and a one-line `contentSum` helper, with no diagonalisation. The class-function H section measures both paths, with the combinatorial path orders of magnitude faster at $n = 6, d = 2$.

Three traps worth flagging:

- `YoungSymmetrize` returns the *unnormalised* symmetriser $c_T$; for a projector ($P^2 = P$) call `YoungProject`. Iterative TN algorithms need the idempotent.
- The Young symmetriser is applied rows-first, columns-second: row symmetry can be broken by the subsequent column antisymmetrisation. For mixed-symmetry diagrams (anything other than fully-row or fully-column) the first symmetry imposed is not generally preserved.
- The validator is strict: tableau slot labels must be a permutation of $1, 2, \ldots, n$. Distinct positive integers outside that range (e.g. `{{3, 5, 7}, {1, 2}}`) are rejected.

## Function-by-function quick reference

| Function | Input | Output | Where it first appears |
|---|---|---|---|
| `PartitionQ[list]` | list | `True`/`False` | Schur-Weyl example (and class-function H) |
| `TransposePartition[par]` | partition | partition | Schur-Weyl example (and Riemann tensor) |
| `YoungTableau[par]` or `YoungTableau[rows]` | partition or list-of-lists | typed tableau | Rank-2 tensors (and Three TN payoffs) |
| `YoungTableauQ[expr]` | anything | `True`/`False` | Rank-2 tensors |
| `TableauShape[tab]` | tableau | partition | Rank-2 tensors |
| `TableauSize[tab]` | tableau | integer $n$ | Rank-2 tensors |
| `TableauRows[tab]` | tableau | list of row-slot lists | Rank-2 tensors |
| `TableauColumns[tab]` | tableau | list of column-slot lists (ragged-safe) | Rank-2 tensors |
| `HookLength[tab, {r,c}]` | tableau + position | integer (or `$Failed`) | Schur-Weyl example |
| `HookLengths[par]` or `HookLengths[tab]` | partition or tableau | nested list | Schur-Weyl example (and Riemann tensor) |
| `HookFactor[par]` or `HookFactor[tab]` | partition or tableau | rational | Schur-Weyl example (and Riemann tensor) |
| `TableauDimension[par]` or `TableauDimension[tab]` | partition or tableau | integer ($\dim V_\lambda$) | Schur-Weyl example (and Riemann tensor) |
| `SchurDimension[par, d]` or `SchurDimension[tab, d]` | partition (or tableau) + dimension | integer or polynomial in $d$ ($\dim W_\lambda(d)$) | Dicke-state subsection (and Schur-Weyl, Riemann, rank-4 enumeration) |
| `TableauWeylDimension[tab, d]` | tableau + dimension | integer or polynomial in $d$ ($\dim W_\lambda(d)$, tableau-keyed) | Schur-Weyl example |
| `YoungSymmetrize[T, tab]` | tensor of rank $n$ + tableau of size $n$ | tensor | Rank-2 tensors |
| `YoungProject[T, tab]` | tensor of rank $n$ + tableau of size $n$ | tensor | Rank-2 tensors (and Three TN payoffs) |

The sections above sit on top of these sixteen calls. Anywhere a symmetry-resolved tensor network needs sizing, block enumeration, or constraint enforcement, the right call is one of them.

