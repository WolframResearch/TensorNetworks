# A Working Tour of the `Symmetry` Sub-Context

This tutorial walks through every function the `Wolfram`TensorNetworks`Symmetry`` sub-context exports, in the order a tensor-network practitioner actually meets them. The goal is operational: after working through the document you should be able to (i) decide whether a partition or a tableau is the right object for a problem, (ii) predict the size of every block of a symmetry-resolved tensor in closed form, and (iii) project a real TN tensor onto the irrep subspace it physically belongs to. Every claim below is paired with a small Wolfram Language cell that you can rerun and modify; nothing is asserted without being computed.

We start where the physics starts: two indistinguishable particles. From there we walk up the ladder of rank, picking up one Symmetry-subcontext function per pedagogical step. By the end we will have used all fourteen exported functions, every one of them at least once on a tensor that has a tensor-network reason to exist.

## Inventory

The sub-context exports fourteen symbols. Six are about the *combinatorics* of Young diagrams (a counting layer that decides "how much room is there?"). Two are typed *accessors* for reading the row and column structure out of a tableau. Four are about *dimensions* of the irreducible-representation blocks. Two are about the *action on tensors* (the operational layer that produces a tensor in the right symmetry class).

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
| `TableauDimension` | dimensions | $\dim V_\lambda$, the irrep dimension. |
| `YoungSymmetrize` | tensor action | Unnormalised Young symmetriser $c_T \cdot T$. |
| `YoungProject` | tensor action | Idempotent projector $P_T = (d_\lambda/n!)\, c_T$. |

The tutorial is structured around four physical settings that successively bring more of these functions into play:

1. **Two-site bonds and identical particles** uses `YoungTableau`, `YoungTableauQ`, `TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`, `YoungSymmetrize`, `YoungProject`.
2. **Diagrams as combinatorial bookkeeping** picks up `PartitionQ` and `TransposePartition`.
3. **Counting before allocating** brings in `HookLength`, `HookLengths`, `HookFactor`, and `TableauDimension`.
4. **Three TN payoffs** revisits every function in working examples: Schur-Weyl block decomposition on three sites, the Riemann tensor as a rank-4 TN node, and the spectrum of a class-function Hamiltonian via content sums.

---

## Where this sub-context sits in WL's tensor stack

Before any code, the structural relationship between the sub-context and built-in Wolfram Language tensor symmetry. Built-in WL (since 9.0) ships a complete language for *mono-term* symmetries: relations of the form

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

This is everything you need to declare "this tensor is symmetric in slots 1, 2", "this matrix is Hermitian", "this rank-4 tensor antisymmetrises in $(1,2)$ and in $(3,4)$ and is invariant under swapping the pairs". It is not enough to declare "$R_{abcd} + R_{acdb} + R_{adbc} = 0$": that is a *multi-term* relation (three permuted copies summing to zero) and lies outside the mono-term language. The same gap is what blocks Young projection onto a mixed-symmetry irrep: those projectors are sums-with-signs over the group on each row and each column of a Young diagram, and the image is defined by satisfying *several* permutation relations together, not one.

The `Wolfram`TensorNetworks`Symmetry`` sub-context fills exactly this gap. Its `YoungProject` produces tensors that lie in *one $S_n$ irrep*, a condition that always implies extra multi-term identities. The Riemann curvature tensor is the canonical example: living in the $\{2,2\}$ irrep simultaneously satisfies pair-antisymmetry $R_{abcd} = -R_{bacd}$, pair-antisymmetry $R_{abcd} = -R_{abdc}$, pair-swap $R_{abcd} = R_{cdab}$, *and* the algebraic first Bianchi identity $R_{abcd} + R_{acdb} + R_{adbc} = 0$. The three pair conditions are mono-term and reachable by built-in `Symmetrize`; the Bianchi identity is multi-term and is not.

We make this concrete in §4.2 (with a numerical demonstration that built-in `Symmetrize` with the three Riemann pair generators *fails* to enforce Bianchi, while `YoungProject` *succeeds*). For now, the takeaway map:

| Operation | Built-in WL | Sub-context |
|---|---|---|
| Mono-term symmetrise (boson, fermion, Riemann pair) | `Symmetrize[T, sym]` | (sub-context wraps this) |
| Detect mono-term symmetry group | `TensorSymmetry[T]` | (no analogue) |
| Compressed storage by orbit | `SymmetrizedArray` | (no analogue; sub-context emits dense / `Normal`) |
| Single-tableau / mixed-symmetry projection (multi-term) | (not supported) | `YoungProject[T, tab]` |
| Irrep dimension $\dim V_\lambda$ via hook formula | (not supported) | `TableauDimension[par]` |
| Hook lengths for $S_n$ representation theory | (not supported) | `HookLength`, `HookLengths`, `HookFactor` |

The two layers compose. The sub-context's `YoungSymmetrize` is implemented as two calls to built-in `Symmetrize` (one with `Symmetric /@ rows`, one with `Antisymmetric /@ columns`) plus the row- and column-stabiliser normalisation factors. So the multi-term machinery sits as a direct extension of the mono-term machinery, not as a competitor.

---

## Setup

Load the paclet and pull the sub-context into scope. From this point every code cell in the tutorial assumes these two `Needs` have been run.

```wolfram
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

tol = 10^-10;
```

`tol` will be our numerical tolerance for "is this tensor identity satisfied?" checks.

---

# 1. Two indistinguishable particles on a bond

Picture the simplest non-trivial tensor in a tensor network: a rank-2 node $T_{ij}$ on a bond between two physical sites, with each index ranging over a $d$-dimensional local Hilbert space $V$, so $T \in V \otimes V$. This rank-2 bond is the elementary building block of every MPS, MERA, and PEPS, and the symmetry rule we work out here generalises slot-by-slot to every higher-rank tensor in the rest of the tutorial.

## 1.1 Identical particles and the exchange operator

Identical quantum particles cannot be distinguished by any measurement. There is no "particle 1" and "particle 2" in nature: photons in a cavity, electrons in an atom, helium-4 atoms in a superfluid, the labels we put on them are bookkeeping, not physics. Quantum mechanics enforces this with a sharp rule on the two-particle wavefunction $\Psi(x_1, x_2)$:

$$
\Psi(x_2, x_1) \;=\; \pm\, \Psi(x_1, x_2).
$$

The plus sign is the *bosonic* case (integer spin: photons, mesons, He-4, Cooper pairs). The minus sign is the *fermionic* case (half-integer spin: electrons, protons, He-3). The minus sign is the Pauli exclusion principle in disguise: setting $x_1 = x_2$ in the fermionic equation forces $\Psi = 0$, i.e. two identical fermions cannot share a state.

In tensor language, write the wavefunction as $|\Psi\rangle = \sum_{ij} T_{ij} \,|i\rangle \otimes |j\rangle \in V \otimes V$. The *exchange operator* (the SWAP gate in quantum computing) $P_{12}$ acts by relabelling the two factors,

$$
P_{12} \,(|i\rangle \otimes |j\rangle) \;=\; |j\rangle \otimes |i\rangle,
$$

which on coefficients sends $T_{ij}$ to $T_{ji}$. **This is the ordinary transpose $T^T$ of the matrix $T$, not the adjoint (conjugate-transpose) $T^\dagger$.** No complex conjugation enters: the SWAP only relabels which slot is which. So even when $T$ is complex, the bosonic and fermionic conditions are

$$
\text{boson}: \; T \,=\, T^T, \qquad \text{fermion}: \; T \,=\, -\,T^T,
$$

with $T^T$ the entry-by-entry transpose. Hermiticity, the condition $T = T^\dagger = (T^*)^T$, is a separate and independent constraint; we will come back to it later in this section and show that the Symmetry sub-context is the wrong tool for it. Built-in WL recognises this distinction: `Matrices[{n,n}, Reals, Hermitian[{1,2}]]` automatically collapses to `Matrices[{n,n}, Reals, Symmetric[{1,2}]]` because the imaginary part of the conjugation drops out on real entries.

## 1.2 The symmetric / antisymmetric decomposition

A generic complex matrix $T \in V \otimes V$ is neither symmetric nor antisymmetric. But it always splits cleanly into two pieces,

$$
T \;=\; \tfrac{1}{2}(T + T^T) \;+\; \tfrac{1}{2}(T - T^T),
$$

with $T_{\text{sym}} = (T + T^T)/2 \in \mathrm{Sym}^2 V$ (dimension $d(d+1)/2$) and $T_{\text{anti}} = (T - T^T)/2 \in \Lambda^2 V$ (dimension $d(d-1)/2$). In quantum-information terms these are the $+1$ and $-1$ eigenspaces of the SWAP gate, and their dimensions add to $d^2$: every two-site tensor has a unique splitting. The Symmetry sub-context names the two pieces by their *symmetry class* (the partition $\{2\}$ for boson, $\{1,1\}$ for fermion) and computes them with one function call. Let us see how.

Write a generic $T$ with symbolic entries:

```wolfram
T = {{a, b}, {c, d}};
```

This $T$ is our running test object for the rest of the section. The bosonic projection is $(T + T^T)/2$; the fermionic projection is $(T - T^T)/2$. We could write those by hand, but the Symmetry sub-context lets us name them by their symmetry class and apply the right operator without spelling out which transposition to take. That naming is what `YoungTableau` is for.

## `YoungTableau`: the named handle for a symmetry class

A *Young tableau* is a left-justified arrangement of boxes (the "shape") together with a labelling of those boxes by the slot indices $\{1, 2, \ldots, n\}$ of the tensor we plan to act on. **The labelling must be a permutation of $1, 2, \ldots, n$** (a *standard tableau*). For two indices there are exactly two shapes:

- one row of two boxes, written $\{2\}$, labels the *symmetric* class;
- one column of two boxes, written $\{1,1\}$, labels the *antisymmetric* class.

Build the two tableaux:

```wolfram
symTab  = YoungTableau[{2}];
antiTab = YoungTableau[{1, 1}];
```

Each call returns a typed `YoungTableau[...]` object with a summary display. The constructor accepts two forms. We just used the *partition* form, in which the argument is a non-increasing list of row lengths and the slot labels $1,2,\ldots,n$ are filled in row by row. The other form takes the rows of slot labels explicitly:

```wolfram
YoungTableau[{{1, 2}}]      (* same as YoungTableau[{2}] *)
YoungTableau[{{1}, {2}}]    (* same as YoungTableau[{1, 1}] *)
```

The explicit form will matter once we move beyond rank 2, because it lets us choose *which* slot goes in which row and column. For example, `YoungTableau[{{1, 3}, {2}}]` is a $\{2,1\}$-shape tableau on rank 3 where slot 3 is paired with slot 1 in the column (and slot 2 sits alone), not the default `YoungTableau[{{1, 2}, {3}}]` that fills row by row.

## What familiar matrices look like in each shape

Before continuing with the rest of the Symmetry-subcontext API, let us recognise the two rank-2 tableau classes in matrices the reader has surely met before. The point is that "$\{2\}$" and "$\{1,1\}$" are not exotic mathematical objects; they are *every symmetric matrix you have ever seen* and *every antisymmetric matrix you have ever seen*, respectively.

The four basic single-qubit operators (the identity and the three Pauli matrices) are a clean illustration. Each is a $2 \times 2$ matrix that lies *entirely* in one of the two shapes:

```wolfram
{Id, sx, sy, sz} = {IdentityMatrix[2], PauliMatrix[1], PauliMatrix[2], PauliMatrix[3]};
```

The identity, $\sigma_x$, and $\sigma_z$ equal their own transpose; $\sigma_y$ negates under transpose:

```wolfram
{Id == Transpose[Id], sx == Transpose[sx], sy == -Transpose[sy], sz == Transpose[sz]}
(* {True, True, True, True} *)
```

So the four-element Pauli basis splits as three matrices in the $\{2\}$ shape ($I, \sigma_x, \sigma_z$) and one in the $\{1,1\}$ shape ($\sigma_y$). That matches the Schur-Weyl dimensions exactly: $d(d+1)/2 = 3$ symmetric matrices plus $d(d-1)/2 = 1$ antisymmetric matrix gives $4 = d^2$ total.

`YoungProject` applied to a tensor that already lives in one shape is a sanity check: the right-shape projection is the identity on that tensor, the wrong-shape projection is zero. Verify on $\sigma_x$ and $\sigma_y$:

```wolfram
symTab  = YoungTableau[{2}];
antiTab = YoungTableau[{1, 1}];

{
    YoungProject[sx, symTab],     (* sx itself: it is symmetric *)
    YoungProject[sx, antiTab],    (* zero matrix *)
    YoungProject[sy, antiTab],    (* sy itself: it is antisymmetric *)
    YoungProject[sy, symTab]      (* zero matrix *)
}
(* {sx, {{0,0},{0,0}}, sy, {{0,0},{0,0}}} *)
```

A short census of rank-2 tensors the reader has seen and the shape each one lives in:

| Tensor | Shape | Why |
|---|---|---|
| Metric $g_{\mu\nu}$ in GR | $\{2\}$ | $g_{\mu\nu} = g_{\nu\mu}$ |
| Stress-energy $T^{\mu\nu}$ | $\{2\}$ | symmetric in $\mu \leftrightarrow \nu$ |
| Pauli $\sigma_x$, $\sigma_z$ | $\{2\}$ | manifestly symmetric |
| Spring-constant matrix $K_{ij}$ | $\{2\}$ | curvature of a scalar potential |
| Covariance matrix in statistics | $\{2\}$ | $\mathrm{Cov}(X_i, X_j)$ is symmetric |
| Spin-1 triplet wavefunction at $d=2$ | $\{2\}$ | symmetric under particle exchange |
| Electromagnetic field $F_{\mu\nu}$ | $\{1,1\}$ | $F_{\mu\nu} = -F_{\nu\mu}$ |
| 2D Levi-Civita $\varepsilon_{ij}$ | $\{1,1\}$ | $\varepsilon_{12} = -\varepsilon_{21}$ |
| Pauli $\sigma_y$ | $\{1,1\}$ | $\sigma_y = -\sigma_y^T$ |
| Spin-0 singlet wavefunction at $d=2$ | $\{1,1\}$ | $(\,|01\rangle - |10\rangle\,)/\sqrt{2}$ |

Every entry in the right column is "Young projector applied gives back the tensor"; everything not in the table is a sum of a $\{2\}$-piece and a $\{1,1\}$-piece, and the projector decomposes it.

## `YoungTableauQ`: validate before you commit

`YoungTableauQ` returns `True` if the argument is a `YoungTableau[...]` whose rows obey the standard-tableau rules: non-increasing row lengths and slot labels that are *exactly* the integers $1, 2, \ldots, n$ in some order. It returns `False` otherwise. We will rely on it implicitly: the other Symmetry-subcontext functions reject malformed tableaux with informative messages instead of crashing. Test it:

```wolfram
YoungTableauQ[symTab]                                (* True *)
YoungTableauQ[YoungTableau[{{1}, {2, 3}}]]           (* False: row 2 longer than row 1 *)
YoungTableauQ[YoungTableau[{{1, 2}, {2, 3}}]]        (* False: 2 appears twice *)
YoungTableauQ[YoungTableau[{{3, 5, 7}, {1, 2}}]]     (* False: slots {1,2,3,5,7} != Range[5] *)
YoungTableauQ[YoungTableau[{{1, 3, 5}, {2, 4}}]]     (* True:  slots {1,2,3,4,5} == Range[5] *)
YoungTableauQ["definitely not a tableau"]            (* False *)
```

The fourth call is the new strict check: even though `{3, 5, 7, 1, 2}` is a set of distinct positive integers, it is not a permutation of `{1, 2, 3, 4, 5}`, so it is not a valid standard tableau. The fifth call shows that custom slot orderings *within* the legal label set are still allowed.

## `TableauShape` and `TableauSize`: rank and partition

Two cheap accessors. `TableauShape` returns the partition (a list of row lengths), and `TableauSize` returns the total number of boxes $n$. The size is the *rank* of the tensor the tableau acts on. Confirm both for the symmetric two-box tableau:

```wolfram
TableauShape[symTab]    (* {2}   *)
TableauSize[symTab]     (* 2     *)
```

If you ever pass a tensor of the wrong rank to `YoungSymmetrize` or `YoungProject`, you will get an error message and a `$Failed` return. `TableauSize` is how you check rank ahead of time.

## `TableauRows` and `TableauColumns`: reading the structure

A `YoungTableau` is atomic: `First`, `Part`, and friends cannot reach inside. The two accessors `TableauRows` and `TableauColumns` are the way to read off the row and column slot lists. They are the inputs the kernel itself uses when calling `Symmetrize` internally (see the next subsection).

```wolfram
tab = YoungTableau[{{1, 2, 3}, {4, 5}, {6}}];

TableauRows[tab]
(* {{1, 2, 3}, {4, 5}, {6}} *)

TableauColumns[tab]
(* {{1, 4, 6}, {2, 5}, {3}} *)
```

`TableauColumns` handles ragged shapes correctly: column 1 has all three rows reaching it, column 2 only the first two, column 3 only the first one. For the `{2, 1}` standard tableau the same function gives:

```wolfram
TableauColumns[YoungTableau[{2, 1}]]
(* {{1, 3}, {2}} *)
```

You will use these accessors most often when you want to inspect a tableau's structure, build a custom symmetriser that mixes Young projection with other slot operations, or debug a projection that does not produce what you expected. The two functions are also what makes the next subsection (the implementation of `YoungSymmetrize`) directly auditable.

## `YoungSymmetrize`: the unnormalised action

The symmetric two-tableau encodes the operator "sum over both orderings of the two slots":

$$
c_{\{2\}} \cdot T_{ij} \;=\; T_{ij} + T_{ji}.
$$

Apply it to our generic $T$:

```wolfram
YoungSymmetrize[T, symTab]
(* {{2 a, b + c}, {b + c, 2 d}} *)
```

The result is manifestly symmetric, but it is *twice* the natural symmetric projection $(T + T^T)/2$. That factor of 2 is the size of the row, $|row|! = 2! = 2$. In general `YoungSymmetrize[T, tab]` is the Young symmetriser $c_T \cdot T$, which satisfies $c_T^2 = (n! / d_\lambda)\, c_T$ rather than $c_T^2 = c_T$. Useful when you want the *unnormalised* combination, e.g. for hand calculations.

**Implementation note.** Under the hood `YoungSymmetrize` is built directly on built-in WL's `Symmetrize`: it calls `Symmetrize[T, Symmetric /@ TableauRows[tab]]` (row symmetrisation) then `Symmetrize[..., Antisymmetric /@ TableauColumns[tab]]` (column antisymmetrisation), each scaled by the order of the row or column stabiliser to undo `Symmetrize`'s built-in $1/|G|$ normalisation. The two `Symmetrize` calls compose because rows and columns of a Young tableau touch disjoint slot sets, so the two `Symmetric` / `Antisymmetric` lists each describe a direct-product symmetry that `Symmetrize` handles natively. Concretely: for `T = Array[t, {2,2}]`,

```wolfram
2 * Normal @ Symmetrize[T, Symmetric[{1, 2}]] ==
    YoungSymmetrize[T, YoungTableau[{2}]]                            (* True *)
2 * Normal @ Symmetrize[T, Antisymmetric[{1, 2}]] ==
    YoungSymmetrize[T, YoungTableau[{1, 1}]]                         (* True *)
```

The factor of 2 is $2! = $ row-stabiliser (or column-stabiliser) size.

The antisymmetric two-tableau gives the operator $T_{ij} - T_{ji}$:

```wolfram
YoungSymmetrize[T, antiTab]
(* {{0, b - c}, {c - b, 0}} *)
```

The diagonal is zero (the fermionic Pauli principle for the indices) and the off-diagonals are equal and opposite. Verify:

```wolfram
ant = YoungSymmetrize[T, antiTab];
ant == -Transpose[ant]
(* True *)
```

## `YoungProject`: the idempotent

For iterative TN algorithms (DMRG, TDVP) you usually want the *projector* form, an operator $P$ with $P^2 = P$. That requires dividing by the prefactor $n!/d_\lambda$. `YoungProject` does it for you:

```wolfram
Psym = YoungProject[T, symTab];
Pant = YoungProject[T, antiTab];
{Psym, Pant}
(* {{{a, (b+c)/2}, {(b+c)/2, d}},  {{0, (b-c)/2}, {(c-b)/2, 0}}} *)
```

`Psym` is exactly $(T + T^T)/2$. `Pant` is exactly $(T - T^T)/2$. They sum back to $T$:

```wolfram
Simplify[Psym + Pant - T]
(* {{0, 0}, {0, 0}} *)
```

That sum-back-to-identity property is no accident. We will see in §4 that on $V^{\otimes n}$ the sum of the *isotypic* projectors (one per partition of $n$) is always the identity. For $n=2$ there are two partitions, $\{2\}$ and $\{1,1\}$, so we get an exact decomposition with two terms.

Idempotence is the operational reason to prefer `YoungProject` over `YoungSymmetrize` in iterative code. Project a random matrix twice; the second projection is the identity:

```wolfram
SeedRandom[1];
Mnum = RandomReal[{-1, 1}, {3, 3}];
P1 = YoungProject[Mnum, symTab];
P2 = YoungProject[P1, symTab];
Max[Abs[Flatten[P1 - P2]]] < tol
(* True *)
```

## The projection uses transpose, not adjoint (complex $T$)

A point worth re-stating, this time with a verification. The exchange operator $P_{12}$ does *not* introduce a complex conjugation; it only relabels slots. So the symmetric and antisymmetric projections work the same way for complex $T$ as for real $T$: the splitting is built from $T^T$ (transpose), not $T^\dagger$ (adjoint).

Take a complex $2 \times 2$ matrix and run the two projectors:

```wolfram
TC = {{1 + I, 2 - I}, {3 + 2 I, 4 + 5 I}};
PsymC = YoungProject[TC, symTab];
PantC = YoungProject[TC, antiTab];

PsymC == (TC + Transpose[TC])/2     (* True  *)
PantC == (TC - Transpose[TC])/2     (* True  *)
```

The Hermitian-symmetric part $(T + T^\dagger)/2$ is a *different* object that the Young projector does not touch:

```wolfram
PsymC == (TC + ConjugateTranspose[TC])/2     (* False *)
```

If you want a Hermitian decomposition $T = T_H + i\, T_A$ with $T_H = T_H^\dagger$ and $T_A = T_A^\dagger$, use `(T + ConjugateTranspose[T])/2` directly. That is not a Young-tableau operation, and *that one is what built-in `Symmetrize[T, Hermitian[{1,2}]]` computes*: Hermiticity lives in the mono-term language too, but with a complex phase. The Symmetry sub-context lives in the symmetric-group representation theory only; conjugation-by-phase symmetries are the built-in `Symmetrize` territory.

The takeaway:

- **Boson / fermion (exchange) symmetry** is about transpose: $T \,=\, \pm T^T$. Use `YoungProject` with shape $\{2\}$ or $\{1,1\}$, or built-in `Symmetrize` with `Symmetric` / `Antisymmetric`.
- **Hermiticity** is about adjoint: $T \,=\, T^\dagger$. Use built-in `Symmetrize[T, Hermitian[{1,2}]]` or `(T + ConjugateTranspose[T])/2` by hand.

So far we have used eight of the fourteen functions: `YoungTableau`, `YoungTableauQ`, `TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`, `YoungSymmetrize`, `YoungProject`. That covers everything you need to enforce boson / fermion parity on a single bond. Three quick TN-conventional applications follow, then we move on to the combinatorial machinery needed for higher rank.

## TN payoffs: singlet/triplet, SWAP gate, fermionic bond

### Two-spin singlet vs triplet (spin-$\tfrac12$ at $d = 2$)

A pair of spin-$\tfrac12$ particles has a 4-dimensional Hilbert space $V \otimes V$ with $d = 2$. The two-spin wavefunctions split into one singlet ($S = 0$, antisymmetric) and three triplet states ($S = 1$, symmetric). In coefficient-tensor form a state $|\Psi\rangle = \sum_{ij} \psi_{ij} |ij\rangle$ has a $2 \times 2$ coefficient matrix $\psi$: singlet iff $\psi$ is antisymmetric, triplet iff $\psi$ is symmetric.

Build the singlet and the $S_z = 0$ triplet as $2 \times 2$ coefficient matrices:

```wolfram
psiSinglet = {{0, 1}, {-1, 0}}/Sqrt[2];   (* (|01> - |10>)/Sqrt[2] *)
psiTriplet = {{0, 1}, { 1, 0}}/Sqrt[2];   (* (|01> + |10>)/Sqrt[2] *)
```

The Young projections route each to its right class and erase the other:

```wolfram
YoungProject[psiSinglet, antiTab]    (* same as psiSinglet *)
YoungProject[psiSinglet, symTab]     (* zero matrix: no triplet content *)

YoungProject[psiTriplet, symTab]     (* same as psiTriplet *)
YoungProject[psiTriplet, antiTab]    (* zero matrix *)
```

For an arbitrary two-spin coefficient matrix $\psi$, the *singlet amplitude* (the weight of the $S=0$ component in the total state) is the inner product of the normalised singlet with `YoungProject[psi, antiTab]`. This is the Schur-Weyl content of "is this state entangled along the singlet axis?" reduced to a single function call.

### SWAP gate as the symmetrise/antisymmetrise machine

In the two-qubit Hilbert space ($d = 2$ on each site, $V \otimes V = \mathbb{C}^4$) the SWAP gate is the $4 \times 4$ matrix realising $P_{12}$. Build it from a `SparseArray` with the rule $\langle k, l | \text{SWAP} | i, j \rangle = \delta_{kj}\delta_{li}$:

```wolfram
swapGate = Normal @ ArrayReshape[
    SparseArray[{{i_, j_, k_, l_} /; i == l && j == k -> 1}, {2, 2, 2, 2}],
    {4, 4}
];
(* {{1,0,0,0},{0,0,1,0},{0,1,0,0},{0,0,0,1}} *)
```

The Young projectors `YoungProject[*, {2}]` and `YoungProject[*, {1,1}]` are *exactly* the projectors onto the $+1$ and $-1$ eigenspaces of this SWAP:

$$
P_{\{2\}} \;=\; \tfrac{1}{2}(I + \text{SWAP}), \qquad P_{\{1,1\}} \;=\; \tfrac{1}{2}(I - \text{SWAP}).
$$

Acting on the coefficient tensor that statement reads $(T + T^T)/2$ and $(T - T^T)/2$, the formulas we have been using all along. The SWAP eigenspace dimensions are $3$ and $1$ at $d = 2$, matching $d(d+1)/2$ and $d(d-1)/2$. SWAP, transpose, Young projection, and built-in `Symmetrize[..., Symmetric[{1,2}]]` are the same operation written in four notations.

### A fermionic bond in a TN

Here the projection actually saves memory. Take a one-bond TN with two nodes $A, B$ describing identical fermions, joined by a bond tensor $T$:

$$
\text{value} \;=\; \sum_{i,j} A_i \, T_{ij} \, B_j.
$$

The physics demands $T \in \Lambda^2 V$. Storing both halves of $T$ wastes $d(d+1)/2$ slots on a sector that the Pauli principle forbids. One `YoungProject` before any contraction enforces the right sector:

```wolfram
SeedRandom[3];
d = 4;
T = RandomReal[{-1, 1}, {d, d}];
TFermi = YoungProject[T, antiTab];
A = RandomReal[{-1, 1}, d];
B = RandomReal[{-1, 1}, d];

A . TFermi . B
(* a scalar; equals 1/2 * (A.T.B - B.T.A) by direct expansion *)

(* The unprojected contraction overcounts by the symmetric piece, *)
(* which is physically forbidden for identical fermions:           *)
Abs[(A . T . B) - (A . TFermi . B)] > tol
(* True *)
```

After the projection, every downstream TN operation that respects index types (`TensorContract`, `Dot`, SVD on the paired index, partial trace) preserves the antisymmetric class. The orthogonal sector is gone for good, halving the bond's worth of stored numbers in the asymptotic limit. If memory matters more than evaluation speed, you can also store the projected bond as a `SymmetrizedArray[..., Antisymmetric[{1,2}]]`; built-in WL handles tensor-arithmetic on it without ever materialising the dense form.

The same project-first-then-contract pattern carries to higher-rank fermionic networks, to bosonic permutation-invariant Hamiltonians, and (with a different Young diagram) to objects like the Riemann curvature tensor that we will meet in §4.

---

# 2. Partitions: the bookkeeping layer

Before we walk up to rank 3 and beyond, we need two utilities that deal with the *shape* of a Young diagram independently of any slot labelling: `PartitionQ` (is this list a legal shape?) and `TransposePartition` (the mirror that swaps boson-symmetric and fermion-antisymmetric reps).

A *partition* of $n$ is a non-increasing list of positive integers summing to $n$. Geometrically it is the shape of a left-justified Young diagram with $n$ boxes. For $n=4$, for example, the partitions are $\{4\}, \{3,1\}, \{2,2\}, \{2,1,1\}, \{1,1,1,1\}$: five shapes, corresponding to the five irreducible representations of $S_4$.

## `PartitionQ`

A predicate that says "yes, this list is a partition (non-increasing, positive integers, non-empty)":

```wolfram
PartitionQ[{3, 2}]         (* True  *)
PartitionQ[{2, 3}]         (* False: not non-increasing *)
PartitionQ[{2, 2, 1}]      (* True  *)
PartitionQ[{}]             (* False: empty *)
PartitionQ[{1, 1, 0}]      (* False: zero is not positive *)
```

The combinatorial functions `HookLengths`, `HookFactor`, and `TableauDimension` all accept either a partition (via `PartitionQ` validation) or a `YoungTableau` (which they will internally reduce to its shape). When you only need *counting* information and have no tensor to act on, passing the bare partition is the cheapest path.

## `TransposePartition`

The *transpose* (or *conjugate*) of a partition swaps the roles of rows and columns. Visually, you flip the Young diagram across its main diagonal. Operationally, it relates the fully symmetric and fully antisymmetric representations: $\{n\}' = \{1,1,\ldots,1\}$. More generally it gives the parity-conjugate representation, where every box swaps "stay symmetric here" with "stay antisymmetric here".

Compute the transposes of a few familiar shapes:

```wolfram
TransposePartition[{4, 2, 1}]    (* {3, 2, 1, 1} *)
TransposePartition[{3}]          (* {1, 1, 1}    *)
TransposePartition[{1, 1, 1}]    (* {3}          *)
TransposePartition[{2, 2}]       (* {2, 2}       *)
```

Note that $\{2,2\}$ is self-conjugate. Self-conjugate shapes have special status in TN: they sit on the diagonal of the Schur-Weyl decomposition and carry their own peculiar mixed symmetry. The Riemann tensor's shape, which we meet in §4.2, is exactly this one.

The TN-relevant identity that uses `TransposePartition` is the *parity flip*: if your network is built from bosonic tensors at irrep $\lambda$, the same network rewritten with fermionic tensors lives at irrep $\lambda'$. In numerical TN codes this is how you cheaply swap statistics without rewriting the algorithm.

---

# 3. Counting before allocating: hook lengths and irrep dimensions

The combinatorial payoff of Young diagrams in tensor networks is that *they let you size every block of a symmetry-resolved tensor before allocating any memory*. The dimension formula is the *hook-length formula*, which is built from cell-by-cell quantities called *hook lengths*.

## `HookLength`: one cell at a time

At cell $(i,j)$ of a Young diagram, the *hook* consists of the cell itself, the cells directly to its right in row $i$, and the cells directly below it in column $j$. The *hook length* $h(i,j)$ is the number of cells in the hook.

The diagram of shape $\{3,2\}$ looks like

```
+---+---+---+
|   |   |   |
+---+---+---+
|   |   |
+---+---+
```

and the hook at $(1,1)$ contains the cell itself, the two cells to its right, and the one cell below: four cells in total. Verify:

```wolfram
HookLength[YoungTableau[{3, 2}], {1, 1}]    (* 4 *)
HookLength[YoungTableau[{3, 2}], {1, 2}]    (* 3 *)
HookLength[YoungTableau[{3, 2}], {2, 2}]    (* 1, bottom-right corner *)
```

The corners of a diagram always have hook length 1. The top-left always has the largest hook. Out-of-range positions are caught: `HookLength[YoungTableau[{3, 2}], {3, 1}]` emits a range message and returns `$Failed`.

## `HookLengths`: every cell at once

For dimension calculations you want all hook lengths in one shot. `HookLengths` returns the nested list whose $(i,j)$ entry is $h(i,j)$:

```wolfram
HookLengths[{3, 2}]
(* {{4, 3, 1}, {2, 1}} *)

HookLengths[{4, 2, 1}]
(* {{6, 4, 2, 1}, {3, 1}, {1}} *)
```

`HookLengths` is the function `TableauDimension` calls internally. It is also the input the Weyl dimension formula needs (see §4) for $\dim S^\lambda(\mathbb{C}^d)$, the multiplicity of the $S_n$ irrep $V_\lambda$ in $V^{\otimes n}$.

## `HookFactor`: the prefactor of the projector

The product of all hook lengths shows up as the denominator in the Young projector's prefactor. `HookFactor[par]` returns $1/\prod h(i,j)$, computed by the Frobenius determinant formula in $O(r^2)$ where $r$ is the number of rows (rather than $O(n)$ if you actually formed the product). It accepts a partition or a `YoungTableau`:

```wolfram
HookFactor[{3, 2}]      (* 1/24 *)
HookFactor[{4, 2, 1}]   (* 1/144 *)
```

You can confirm by reading off the entries of `HookLengths`: $4 \cdot 3 \cdot 1 \cdot 2 \cdot 1 = 24$ for $\{3,2\}$.

The irrep dimension is $n! \cdot \text{HookFactor}$, which is `TableauDimension`.

## `TableauDimension`: the size of an isotypic block

This is the function you call most often in symmetry-resolved TN. It returns the dimension of the irreducible representation $V_\lambda$ of the symmetric group $S_n$ labelled by partition $\lambda$. By the hook-length formula,

$$
\dim V_\lambda \;=\; \frac{n!}{\prod_{(i,j) \in \lambda} h(i,j)}.
$$

In a symmetry-resolved MPS, this dimension is the *multiplicity space* dimension for the block labelled by $\lambda$. The full block size factors as $\dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$ (we will see $\dim S^\lambda(\mathbb{C}^d)$ in §4), and `TableauDimension` is the easy factor.

Read off all the irrep dimensions of $S_5$:

```wolfram
TableauDimension /@ IntegerPartitions[5]
(* {1, 4, 5, 6, 5, 4, 1} *)
```

The pair of $1$s are the trivial (fully symmetric, $\{5\}$) and sign (fully antisymmetric, $\{1,1,1,1,1\}$) representations. The other five are the "interesting" irreps.

The sum of squares should equal $|S_5| = 5! = 120$ (a Plancherel identity that holds for every $S_n$):

```wolfram
Total[TableauDimension[#]^2 & /@ IntegerPartitions[5]]
(* 120 *)
```

That identity is what guarantees the Schur-Weyl decomposition $V^{\otimes n} = \bigoplus_\lambda V_\lambda \otimes S^\lambda(\mathbb{C}^d)$ uses every dimension. Nothing is missing, nothing is double-counted.

`TableauDimension` accepts either a partition or a tableau:

```wolfram
TableauDimension[{2, 1}]                          (* 2 *)
TableauDimension[YoungTableau[{{1, 2}, {3}}]]     (* 2 *)
```

### Summary of the combinatorial layer

- `PartitionQ`: shape is a non-empty non-increasing list of positive integers.
- `TransposePartition`: flips the diagram, mapping irrep $\lambda$ to its sign-twist $\lambda'$.
- `YoungTableau`, `YoungTableauQ`, `TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`: typed handle and accessors.
- `HookLength`, `HookLengths`: the cell quantities the dimension formula consumes.
- `HookFactor`: the $1/\prod h$ prefactor.
- `TableauDimension`: $n! \cdot \text{HookFactor}$, the block size in symmetry-resolved TN.

We can now leave the combinatorics behind and let `YoungProject` carry the load on real tensor-network problems.

---

# 4. Three TN payoffs

The three examples that follow are the operational core of this tutorial. Each one is small enough to inspect by hand and large enough that doing the same job without the Symmetry sub-context would be measurably worse. The first is the cleanest illustration of the *Schur-Weyl decomposition* on three sites. The second is the *Riemann tensor*, a classical-gravity rank-4 tensor whose symmetry is exactly the one $S_4$ irrep that built-in WL canonicalisation cannot enforce. The third is a *class-function Hamiltonian* whose entire spectrum comes from partition combinatorics, no diagonalisation needed.

## 4.1 Schur-Weyl on three sites: how a tensor decomposes by symmetry

Take $V = \mathbb{C}^2$ and look at the rank-3 tensor space $V \otimes V \otimes V$. It has dimension $d^n = 2^3 = 8$. The Schur-Weyl theorem says this space splits into pieces labelled by partitions of 3 (i.e. irreducible representations of $S_3$):

$$
V \otimes V \otimes V \;=\; \bigoplus_{\lambda \vdash 3} V_\lambda \otimes S^\lambda(\mathbb{C}^d).
$$

The three partitions are $\{3\}$ (fully symmetric, bosonic), $\{2,1\}$ (mixed symmetry), and $\{1,1,1\}$ (fully antisymmetric, fermionic). Each block has dimension $\dim V_\lambda \cdot \dim S^\lambda(\mathbb{C}^d)$. The first factor is `TableauDimension[par]`. The second factor is the Weyl dimension formula:

$$
\dim S^\lambda(\mathbb{C}^d) \;=\; \prod_{(i,j) \in \lambda} \frac{d + j - i}{h(i,j)}.
$$

`HookLengths` feeds the denominator. We write a tiny helper:

```wolfram
schurDim[par_List, d_Integer] := Module[{h = HookLengths[par]},
    Product[
        Product[(d + j - i)/h[[i, j]], {j, par[[i]]}],
        {i, Length[par]}
    ]
];
```

Predict the block sizes at $d=2, n=3$:

```wolfram
Table[
    par -> {TableauDimension[par], schurDim[par, 2],
            TableauDimension[par] * schurDim[par, 2]},
    {par, IntegerPartitions[3]}
]
(* {{3} -> {1, 4, 4},  {2, 1} -> {2, 2, 4},  {1, 1, 1} -> {1, 0, 0}} *)
```

Read row by row: the $\{3\}$ block has size $1 \cdot 4 = 4$ (a four-dimensional bosonic sector). The $\{2,1\}$ mixed block has size $2 \cdot 2 = 4$. The $\{1,1,1\}$ fermionic block has size $1 \cdot 0 = 0$, *exactly zero*, because you cannot antisymmetrise three slots over a two-dimensional space (the Pauli principle for three spin-$\tfrac12$ particles forbids it). The sum is $4 + 4 + 0 = 8 = d^n$. The decomposition exhausts the tensor space and tells you, without ever forming a projector, that any operation involving the $\{1,1,1\}$ sector can be skipped.

The construction generalises to higher $n$ and is the foundation of symmetry-resolved DMRG / TDVP: every bond carries an exact decomposition by partition $\lambda$ and the block dimensions are read off in closed form.

Now let us *measure* the decomposition explicitly, projector by projector. For each partition $\lambda \vdash 3$, the isotypic projector $E_\lambda$ on $V^{\otimes 3}$ is the sum of the Young projectors over the *standard tableaux* of shape $\lambda$. There is one standard tableau of shape $\{3\}$ (namely $\{\{1,2,3\}\}$), two of shape $\{2,1\}$ (namely $\{\{1,2\},\{3\}\}$ and $\{\{1,3\},\{2\}\}$, two equal to `TableauDimension[{2,1}]`), and one of shape $\{1,1,1\}$ (namely $\{\{1\},\{2\},\{3\}\}$).

Project a random rank-3 tensor in $d=2$:

```wolfram
SeedRandom[7];
T3 = RandomReal[{-1, 1}, {2, 2, 2}];

e3   = YoungProject[T3, YoungTableau[{{1, 2, 3}}]];
e21  = YoungProject[T3, YoungTableau[{{1, 2}, {3}}]] +
       YoungProject[T3, YoungTableau[{{1, 3}, {2}}]];
e111 = YoungProject[T3, YoungTableau[{{1}, {2}, {3}}]];
```

The three pieces sum to the original tensor (completeness of the isotypic decomposition):

```wolfram
Max[Abs[Flatten[e3 + e21 + e111 - T3]]] < tol
(* True *)
```

And the predicted vanishing of the fermionic piece holds identically:

```wolfram
Max[Abs[Flatten[e111]]] < tol
(* True *)
```

The decomposition is exact, computed without any eigenvalue routine. The role of each Symmetry-subcontext function here:

- `YoungTableau` names each block by its shape.
- `YoungProject` returns the projection of the input tensor onto that block.
- `TableauDimension` says *how many* standard tableaux there are per shape, which is how many `YoungProject` calls to sum into the isotypic $E_\lambda$.
- `HookLengths` feeds `schurDim` for the GL($d$) factor.

## 4.2 The Riemann tensor as a TN node

The Riemann curvature tensor $R_{abcd}$ is a rank-4 tensor with four classical symmetries:

1. Antisymmetric in the first pair: $R_{abcd} = -R_{bacd}$.
2. Antisymmetric in the second pair: $R_{abcd} = -R_{abdc}$.
3. Symmetric under pair swap: $R_{abcd} = R_{cdab}$.
4. *First Bianchi identity*: $R_{abcd} + R_{acdb} + R_{adbc} = 0$.

The first three are *single-term* slot symmetries (each says $T = \pm T^\sigma$ for one permutation $\sigma$). Standard WL canonicalisation via `TensorReduce[Arrays[..., sym]]` covers them. The fourth, the first Bianchi identity, is *multi-term*: a sum of three permutations is zero, and no single $(\sigma, \phi)$ pair tells you that. **This is the gap the Symmetry sub-context fills.**

But all four constraints are the content of a single $S_4$ irrep, the one labelled by the partition $\{2,2\}$. The Riemann tensor is *literally* the projection of a generic rank-4 tensor onto this irrep. One `YoungProject` call enforces everything at once.

### The mono-term-only attempt with built-in `Symmetrize`

Take a generic rank-4 tensor and try to make it Riemann-like with built-in WL alone. The three pair symmetries lift directly into a generator list:

```wolfram
SeedRandom[42];
T0 = RandomReal[{-1, 1}, {4, 4, 4, 4}];

riemannGens = {
    {Cycles[{{1, 2}}],         -1},   (* antisym in (1,2) *)
    {Cycles[{{3, 4}}],         -1},   (* antisym in (3,4) *)
    {Cycles[{{1, 3}, {2, 4}}],  1}    (* pair-swap *)
};
Rmono = Normal @ Symmetrize[T0, riemannGens];
```

Check the three pair conditions:

```wolfram
Max[Abs[Flatten[Rmono + Transpose[Rmono, {2, 1, 3, 4}]]]] < tol    (* True *)
Max[Abs[Flatten[Rmono + Transpose[Rmono, {1, 2, 4, 3}]]]] < tol    (* True *)
Max[Abs[Flatten[Rmono - Transpose[Rmono, {3, 4, 1, 2}]]]] < tol    (* True *)
```

All three pass. Now check Bianchi:

```wolfram
Max[Abs[Flatten[
    Rmono + Transpose[Rmono, {1, 3, 4, 2}] + Transpose[Rmono, {1, 4, 2, 3}]
]]]
(* approximately 0.68, clearly nonzero *)
```

Built-in `Symmetrize` produces a tensor with the three pair symmetries, but the Bianchi sum has $O(1)$ residual. No mono-term language can fix this: Bianchi asks three permuted copies to sum to zero, which is two relations short of the single-permutation form `Symmetrize` understands. The corresponding count is visible in `SymmetrizedIndependentComponents`: at dimension 4 with the three mono-term Riemann generators the kernel reports 21 independent components, whereas the true number of Riemann components (post-Bianchi) is $n^2 (n^2 - 1) / 12 = 20$. The single missing relation is Bianchi.

### The Young-projector solution

The slot labelling matters here. The two columns of the diagram contain the two antisymmetric pairs, and the two rows contain the slots that get pair-swap symmetry. So we choose

```
+---+---+
| 1 | 3 |
+---+---+
| 2 | 4 |
+---+---+
```

which is `YoungTableau[{{1, 3}, {2, 4}}]`. Project the same generic tensor:

```wolfram
R = YoungProject[T0, YoungTableau[{{1, 3}, {2, 4}}]];
```

Check the four symmetries in turn.

Antisymmetry in slots $(1,2)$:

```wolfram
Max[Abs[Flatten[R + Transpose[R, {2, 1, 3, 4}]]]] < tol
(* True *)
```

Antisymmetry in slots $(3,4)$:

```wolfram
Max[Abs[Flatten[R + Transpose[R, {1, 2, 4, 3}]]]] < tol
(* True *)
```

Pair-swap symmetry:

```wolfram
Max[Abs[Flatten[R - Transpose[R, {3, 4, 1, 2}]]]] < tol
(* True *)
```

First Bianchi identity. *This is the constraint built-in `Symmetrize` cannot reach.*

```wolfram
Max[Abs[Flatten[
    R + Transpose[R, {1, 3, 4, 2}] + Transpose[R, {1, 4, 2, 3}]
]]] < tol
(* True *)
```

All four hold, from one `YoungProject` call.

### Composition with built-in `TensorSymmetry`

After projection, the mono-term content of $R$ is detected by `TensorSymmetry`:

```wolfram
TensorSymmetry[R]
(* {{Cycles[{{3, 4}}], -1}, {Cycles[{{1, 2}}], -1}, {Cycles[{{1, 3}, {2, 4}}], 1}} *)
```

Built-in WL reports the three Riemann pair generators. It does *not* (and cannot) report Bianchi as a generator: Bianchi is not a `{perm, phase}` relation. But it is satisfied identically by the components of $R$, as the numerical check above confirms. The sub-context's job is "produce a tensor in this irrep"; the built-in `TensorSymmetry`'s job is "read off the mono-term subgroup of its slot symmetries". The two answers compose cleanly because `YoungProject` outputs a real array (or a `SymmetrizedArray`-compatible structure) that built-in WL handles directly.

### The TN reward

Once $R$ lives in the right irrep, downstream contractions preserve the structure for free. The Euclidean Ricci tensor is the partial trace $R_{bd} = \delta^{ac} R_{abcd}$, which we write as `TensorContract[R, {{1,3}}]`. It comes out symmetric automatically:

```wolfram
Ric = TensorContract[R, {{1, 3}}];
Max[Abs[Flatten[Ric - Transpose[Ric]]]] < tol
(* True *)
```

No separate re-symmetrisation step. The scalar curvature is the trace of the Ricci tensor:

```wolfram
Tr[Ric]
(* a scalar; here approximately 1.18655 with this random seed *)
```

If you wanted the Weyl tensor, you would project onto a *different* $S_4$ irrep (the traceless subspace of $\{2,2\}$), again with one `YoungProject` call. The Symmetry sub-context is exactly the tool that puts rank-4 curvature tensors into a TN-clean form.

## 4.3 A class-function Hamiltonian and content sums

Pure $\dim V_\lambda$ values are useful, but the Symmetry sub-context can also pre-compute *eigenvalues* of certain Hamiltonians without any diagonalisation. The relevant Hamiltonians are *class functions* of $S_n$: operators built from permutations whose value depends only on cycle structure. The classic example is the sum-of-all-pair-swaps

$$
H \;=\; \sum_{i < j} P_{ij}
$$

acting on $V^{\otimes n}$, where $P_{ij}$ is the swap of the $i$th and $j$th tensor factors. By Schur-Weyl, $H$ commutes with every isotypic projector $E_\lambda$ and is therefore *constant on each $\lambda$-block*. The constant is the *content sum* of the partition,

$$
c(\lambda) \;=\; \sum_{(i,j) \in \lambda} (j - i),
$$

a simple sum over diagram cells. For $n = 3$ the three partitions give $c(\{3\}) = 0 + 1 + 2 = 3$, $c(\{2,1\}) = 0 + 1 - 1 = 0$, $c(\{1,1,1\}) = 0 - 1 - 2 = -3$. Together with the block multiplicities from §4.1, *this is the full spectrum of $H$ with multiplicities*.

Encode the content sum:

```wolfram
contentSum[par_List] :=
    Total @ Flatten @ Table[j - i, {i, Length[par]}, {j, par[[i]]}];
```

For $d=2, n=3$ the predicted spectrum is

```wolfram
predicted = Sort[
    Flatten @ {
        ConstantArray[contentSum[{3}],       TableauDimension[{3}]       * schurDim[{3}, 2]],
        ConstantArray[contentSum[{2, 1}],    TableauDimension[{2, 1}]    * schurDim[{2, 1}, 2]],
        ConstantArray[contentSum[{1, 1, 1}], TableauDimension[{1, 1, 1}] * schurDim[{1, 1, 1}, 2]]
    },
    Greater
]
(* {3, 3, 3, 3, 0, 0, 0, 0} *)
```

Four eigenvalues equal to $3$ in the $\{3\}$ block (four-dimensional), four equal to $0$ in the $\{2,1\}$ block (also four-dimensional), and zero copies of $-3$ because the $\{1,1,1\}$ block is empty at $d=2$.

Cross-check against an explicit matrix diagonalisation. Build $H$ as an $8 \times 8$ matrix and call `Eigenvalues`:

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
Hmat = applySwap[1, 2] + applySwap[1, 3] + applySwap[2, 3];
spectrum = Sort[Eigenvalues[Hmat], Greater]
(* {3, 3, 3, 3, 0, 0, 0, 0} *)

Max[Abs[spectrum - predicted]] < tol
(* True *)
```

The two lists agree exactly. The numerical diagonalisation was a courtesy; the spectrum was already determined by the combinatorics of `TableauDimension`, `schurDim` (powered by `HookLengths`), and `contentSum`.

This pattern is what makes the Symmetry sub-context interesting for TN simulation of permutation-invariant systems. Hamiltonians that are class functions of the permutation group on the sites (e.g. all-to-all exchange interactions, certain $J_1$-$J_2$ symmetric models, collective spin models) have their entire spectrum determined by partitions of $n$ and block multiplicities. No exact diagonalisation, no Lanczos sweep, no SVD: just a sum over the rows of an $|\text{IntegerPartitions}[n]|$-entry table.

---

# 5. Where this leaves us

You have now used every function in the `Wolfram`TensorNetworks`Symmetry`` sub-context at least once on a tensor with a physical reason to exist.

Five concrete things you can now do:

- Decide, given a rank-$n$ tensor and a partition $\lambda \vdash n$, what the dimension of the corresponding block is: a single `TableauDimension[par] * schurDim[par, d]` call.
- Allocate a symmetry-resolved MPS / MPO with exact block sizes per sector, including correctly skipping sectors that vanish (the rank-3 fermionic sector at $d=2$, the rank-4 fully-antisymmetric sector at $d \leq 3$, and so on).
- Enforce multi-term symmetry constraints (Riemann tensor, Weyl tensor, mixed-symmetry curvature objects, higher-spin gauge fields) with a single `YoungProject` call, in cases where built-in `Symmetrize` reaches only the mono-term subset.
- Cleanly project a bond onto a single statistics sector (boson, fermion, or mixed), and trust that downstream TN operations (built-in `TensorContract`, `TensorTranspose`, `Dot`, SVD, `TensorReduce`, `TensorSymmetry`) preserve it.
- For class-function Hamiltonians, read off the entire spectrum from `TableauDimension`, `HookLengths`, and `contentSum` without any numerical diagonalisation.

Three traps worth flagging:

- `YoungSymmetrize` returns the *unnormalised* symmetriser $c_T$; if you want a projector ($P^2 = P$), call `YoungProject`. Iterative TN algorithms need the idempotent.
- The Young symmetriser is applied as "rows first, columns second": row symmetry can be broken by the subsequent column antisymmetrisation. For non-trivial mixed-symmetry diagrams (anything other than fully-row or fully-column), the *first* symmetry imposed is not generally preserved.
- The validator is strict: tableau slot labels must be a permutation of $1, 2, \ldots, n$. Older examples that used distinct positive integers outside this range (e.g. `{{3,5,7},{1,2}}`) are now rejected.

## Function-by-function quick reference

| Function | Input | Output | Used in |
|---|---|---|---|
| `PartitionQ[list]` | list | `True`/`False` | §2 |
| `TransposePartition[par]` | partition | partition | §2 |
| `YoungTableau[par]` or `YoungTableau[rows]` | partition or list-of-lists | typed tableau | §1, §4 |
| `YoungTableauQ[expr]` | anything | `True`/`False` | §1 |
| `TableauShape[tab]` | tableau | partition | §1 |
| `TableauSize[tab]` | tableau | integer $n$ | §1 |
| `TableauRows[tab]` | tableau | list of row-slot lists | §1 |
| `TableauColumns[tab]` | tableau | list of column-slot lists (ragged-safe) | §1 |
| `HookLength[tab, {r,c}]` | tableau + position | integer (or `$Failed`) | §3 |
| `HookLengths[par]` or `HookLengths[tab]` | partition or tableau | nested list | §3, §4 |
| `HookFactor[par]` or `HookFactor[tab]` | partition or tableau | rational | §3 |
| `TableauDimension[par]` or `TableauDimension[tab]` | partition or tableau | integer | §3, §4 |
| `YoungSymmetrize[T, tab]` | tensor of rank $n$ + tableau of size $n$ | tensor | §1 |
| `YoungProject[T, tab]` | tensor of rank $n$ + tableau of size $n$ | tensor | §1, §4 |

The four sections above sit on top of these fourteen calls. Anywhere a symmetry-resolved tensor network needs sizing, block enumeration, or constraint enforcement, the right call is one of them.

## Relationship to built-in WL surface, in one paragraph

For mono-term symmetries the right tool is built-in `Symmetrize[T, sym]` and friends; the sub-context's `YoungSymmetrize` is built on top of `Symmetrize` and exists to compose two such calls (rows symmetrise, columns antisymmetrise) into a Young symmetriser. For multi-term identities (the algebraic Bianchi identity, mixed-symmetry irreps, projection onto a *single* $S_n$ irrep rather than a slot-permutation subgroup) the sub-context is the only WL primitive that does the job: built-in `Symmetrize` with a Riemann generator list produces a tensor with the three pair symmetries but a Bianchi residual of order one, while `YoungProject[T, YoungTableau[{{1,3},{2,4}}]]` produces a tensor satisfying all four conditions. Once a tensor is in the right irrep, downstream WL machinery (`TensorContract`, `TensorTranspose`, `TensorSymmetry`, `SymmetrizedArray`, `TensorReduce`) sees and preserves the structure for free.
