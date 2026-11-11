# Research questions: tensor symmetry in tensor-network computation

This note lists the questions worth answering before anything is built to make `TensorNetworkContract` use tensor symmetry. They are ordered by how much each one assumes: the first questions assume only that the tensors are symmetric, later ones assume a storage format, a contraction routine, or labelled bonds that earlier answers would have to supply. A question whose example is just as good without symmetry has been dropped.

## What is already measured

These facts were checked with `wolframscript` on Wolfram Language 15.0.1 and frame every question below.

- A `SymmetrizedArray` stores only one value per orbit of positions under a group of signed slot permutations. A fully symmetric rank-3 tensor at dimension 4 stores 20 values instead of 64.
- `Plus` (same symmetry only), scalar multiplication, `Transpose`, `TensorProduct` and `TensorContract` keep the `SymmetrizedArray` and attach the correct output symmetry. `Dot` and `ArrayDot` return a dense `List`.
- The kept route is not a fast route. Contracting two fully symmetric rank-3 tensors over one index with `TensorContract` keeps the output symmetry (symmetric in each remaining pair) but its time grows close to the sixth power of the dimension (fitted exponent about 5.9 over d = 6 to 14; about 2 s at dimension 10, 14 s at dimension 14), against under a millisecond for `ArrayDot` on the dense arrays.
- The paclet treats a `SymmetrizedArray` leaf as storage only and expands it before contracting, so a symmetric network and its dense copy cost the same (see `mono_term_symmetry_and_contraction.md`).
- When a tensor is contracted with itself, the result shows it: `TensorContract[TensorProduct[a, a], {{3, 4}}]` for a symmetric rank-3 `a` also carries the exchange of the two remaining pairs.
- Every symmetry that `SymmetrizedArray`, `TensorSymmetry` and `TensorReduce` can express says that the tensor equals one signed permuted copy of itself. `TensorReduce` cancels `R_bacd + R_abcd` but leaves the cyclic sum `R_abcd + R_acdb + R_adbc` unreduced. With the three Riemann pair symmetries `SymmetrizedIndependentComponents` counts 21 values at dimension 4, one more than the 20 independent Riemann components.
- `YoungProject` imposes relations among several permuted copies (the first Bianchi identity included) but returns a dense array, and on a 32 GB machine it runs out of memory at rank 12 for the fully symmetric shape (its memory grows about thirteenfold per rank, independent of the dimension: rank 10 needs 0.26 GB, rank 11 about 3.5 GB).
- Summing `YoungProject` over the standard tableaux of one shape does not give the orthogonal projector onto that shape's block from rank 5 on (`young_tableaux.md` uses `M . PseudoInverse[M]` instead). Demos 1 to 3 rely on the plain sum and are only safe up to rank 4.

---

## 1. At what rank and dimension does dense storage stop being an option for a symmetric tensor?

**What it would show.** Symmetry can only pay where the dense array is the thing that runs out: memory, or flops that do not fit the time budget. A fully symmetric rank-r tensor at dimension d holds `Binomial[d + r - 1, r]` values instead of `d^r`, a ratio near `r!` once d is large. The answer is a map of (r, d) showing where dense `ArrayDot` is fine, where it is slow, and where it cannot allocate, and so where every later question matters.

**Test in the paclet.** Evaluate `T(x, x, ..., x)`, the full contraction of a fully symmetric tensor with one vector on every leg, as a `TensorNetwork` of one tensor and r copies of the vector. Time it and record peak memory for the dense leaf, then compute the same number from the independent values with their multinomial weights (the value is a homogeneous polynomial in the entries of x). Sweep r = 3 to 8 and d = 5 to 40.

**Example.** Rank 6 at dimension 20: the dense tensor has 64 million entries (512 MB of machine reals), while the symmetric one has 177,100 values. At this size the dense array still fits in memory and contracts in about half a second, but expanding it from its independent values takes about 11 s, so the dense route spends nearly all its time building the tensor; at rank 8 and dimension 40 (6.6 times 10^12 entries) it cannot be allocated at all.

## 2. Is `TensorContract` on `SymmetrizedArray` operands slow by a constant factor, or does it scale worse than the dense contraction?

**What it would show.** Whether the paclet can build on the existing structure-keeping route or has to bypass it. Measured times for a single-index contraction of two rank-3 tensors grow with an exponent near 6 in d, above the dense flop count's `d^5`, not the reduced count the stored symmetry would allow. If the gap is a constant, a faster implementation of the same idea is enough; if the exponent is worse, the route does work proportional to the full orbits rather than the stored values, and tuning cannot fix it.

**Test in the paclet.** Fit time against d for `TensorContract[TensorProduct[a, b], pairs]` on `SymmetrizedArray` leaves, for ranks 2 to 4 and one or two contracted pairs, and compare with `ArrayDot` on `Normal` of the same leaves and with the independent-value count of the result.

**Example.** Two fully symmetric rank-3 tensors at dimension 10 contracted over one index: about 2 s on the symmetric route against a fraction of a millisecond dense, while the output has only 3,025 independent values out of 10,000.

## 3. For tensors that conserve a U(1) charge, does a block layout beat what `SparseArray` already does?

**What it would show.** Charge conservation forces most entries to zero, and the paclet already accepts `SparseArray` leaves. If sparse storage already captures the saving, abelian symmetry needs nothing new; if it does not (overhead of sparse products, fill-in of intermediates), a list of dense blocks labelled by charge is the missing piece. This question assumes only charge conservation, not any non-abelian structure.

**Test in the paclet.** Build matrix product state tensors for the spin-1/2 XXZ chain whose bond indices are sorted by total magnetization, so every tensor is block-diagonal in charge. Contract the transfer-matrix network for a norm or a two-point correlator three ways: dense leaves, `SparseArray` leaves, and one paclet contraction per charge block summed by hand. Sweep the bond dimension.

**Example.** A half-filled chain with bond dimension 200: each charge block is a small fraction of the bond, so the dense contraction does many times the needed arithmetic, and the comparison shows whether sparse leaves recover that factor or loses it to overhead.

## 4. Can the symmetry of a pairwise contraction's output be predicted from the operands' symmetries and the contracted slots alone, including the symmetry that appears when an operand meets itself?

**What it would show.** A symmetry-aware contraction needs the output symmetry before any value is computed, so that the result can be stored compactly and the planner can price it. `TensorContract` on `SymmetrizedArray` operands already attaches an output symmetry, so the rule can be read off its results and checked against `TensorSymmetry` of the dense result. The open points are whether contracting several pairs one at a time loses symmetry, and how often the extra exchange symmetry from repeated operands appears in real networks. In tests the pair exchange also appears when the second operand is a separately built copy with equal values; the open point is leaves equal only up to rounding, or symbolic leaves under different names.

**Test in the paclet.** For random networks of two to four symmetric leaves, compare the predicted tag of every intermediate with `TensorSymmetry` of the dense intermediate the paclet computes. Count the cases where the dense result has more symmetry than predicted, and classify where the extra symmetry comes from (equal leaves, several contracted pairs, cancellation to zero).

**Example.** `S_ijk S_ilm` with one symmetric S: the output is symmetric in (j, k), in (l, m), and under exchanging the two pairs, 1,540 independent values at dimension 10 instead of 10,000. If the second leaf is S plus rounding noise, a prediction that looks only at symmetry tags misses the pair exchange and stores 3,025.

## 5. If the planner priced each intermediate by its independent values and its reduced arithmetic, would it choose different contraction orders?

**What it would show.** A symmetric network and its dense copy cost the same today, so the paths the planner picks take no account of symmetry. With symmetry, a path that keeps symmetric intermediates can be cheaper than the path that is cheapest densely, and a path that breaks symmetry early can lose its advantage. The answer shows whether symmetry changes the plan or only shrinks the cost of the plan already chosen.

**Test in the paclet.** Write a small path search that prices each step by independent-value counts from the rule of question 4, and compare its paths, predicted costs and measured times with those of the paths `TensorNetworkContract` chooses, on a set of networks that contain symmetric leaves.

**Example.** Changing the basis of a fully symmetric rank-4 tensor, `T'_abcd = M_ai M_bj M_ck M_dl T_ijkl`, at dimension 40. Densely each of the four steps costs `d^5`. When the same M is applied to every leg, the intermediate after k steps is symmetric among the k transformed legs and among the 4 - k untouched legs, so step k needs only about `d^5 / (k! (4 - k)!)` multiplications: in total about `0.625 d^5` instead of `4 d^5`, a factor near 6. A planner that also has to choose between such a chain and contracting the M's with other partners first sees different costs from the dense one.

## 6. Can a contraction of two symmetric tensors use fewer multiplications than the output symmetry alone saves, and does that pay against optimized dense matrix products?

**What it would show.** Storing only independent output values saves a factor set by the output symmetry. Algorithms published by Solomonik and Demmel reorganize contractions of symmetric tensors so that sums of entries are formed first and the number of multiplications drops further, at the cost of more additions. In Wolfram Language the dense alternative is a highly tuned matrix product, so the question is whether any reduced-multiplication scheme, written with vectorized list operations, beats it, and at what rank and dimension.

**Test in the paclet.** Implement the reduced scheme for the smallest cases (symmetric matrix times vector; symmetric rank-3 tensor contracted with a symmetric matrix over two indices) as plain list arithmetic on independent values, and time it against `ArrayDot` on dense leaves for growing d, with `ClearSystemCache[]` between runs.

**Example.** A fully symmetric rank-4 tensor at dimension 30 contracted with a symmetric matrix over two indices. The output is symmetric in its remaining two slots, so storing it saves a factor of 2; the multiplication count of the reduced scheme decides whether the input symmetry buys anything beyond that.

## 7. How much do relations among several permuted copies save beyond the best single-permutation description, and for which Young shapes does the gap grow?

**What it would show.** A tensor in one Young irrep obeys relations such as the first Bianchi identity that no signed slot permutation can express. Its single-permutation symmetry (what `TensorSymmetry` finds) leaves extra values. At large d the ratio of the two counts tends to `n! / (f |G|)`, where f is `TableauDimension` of the shape and |G| is the order of the signed-permutation group the tensor has. For the Riemann shape {2, 2} this ratio tends to only 3/2 (at dimension 8 the counts are 406 against 336, a ratio of 1.21), so Bianchi alone is a small saving. For the two-row rectangle {k, k}, a symmetric product of k antisymmetric pairs, the ratio tends to `(k + 1)!/2^k` (1.5, 3, 7.5, 22.5 for k = 2 to 5); at dimension 200 the ratio measured with `SchurDimension` is still approaching these values from below, slowest for the largest k. The answer shows which multi-term symmetries are worth a storage format of their own and which are covered almost entirely by single-permutation symmetry.

**Test in the paclet.** For each shape up to rank 8, project a random tensor with `YoungProject` (with the orthogonal correction where several tableaux are involved), read its single-permutation symmetry with `TensorSymmetry`, count `SymmetrizedIndependentComponents` under it, and compare with `SchurDimension`. Then measure how large d must be before the asymptotic ratio is reached, since at small d the gap is smaller (the {3, 3} shape at dimension 4 gives 56 against 50).

**Example.** Rank 8 with shape {4, 4} at dimension 10: storing it by its single-permutation symmetry keeps 194,580 values where the irrep has 70,785, almost three times as many (the ratio approaches 7.5 as d grows), and a full contraction of two such tensors done over the stored values does about 2.75 times as many multiplications as one done in a basis of the irrep.

## 8. When two tensors of known Young shape are contracted, which shapes can appear in the result, and can the zero ones be skipped before computing?

**What it would show.** For single-permutation symmetry, question 4 gives the output group. For irrep-typed tensors the output is a sum of shapes fixed by the input shapes, the contracted slots and the trace structure (Littlewood-Richardson coefficients for products, branching rules from GL(d) to O(d) for traces with a metric). If those rules are computed in advance, a contraction can be stored by its nonzero shapes and pieces known to vanish can be skipped. A dense result gives the numbers but not this decomposition.

**Test in the paclet.** Compute the shape content of `R_abcd R_cdef`, of the Ricci contraction, and of products of two {2, 1} tensors by projecting the dense results onto every shape, and compare with the Littlewood-Richardson prediction (the `LRrule` and `Branch` functions in `Tableaux Jose Examples.nb` are a reference implementation). Then check whether contracting only the predicted nonzero pieces reproduces the dense result.

**Example.** The Ricci contraction of a Riemann tensor at dimension 6 lands entirely in the symmetric shape {2}: the antisymmetric part is known to be zero before any arithmetic, and the dense result shows this only after it is computed and inspected.

## 9. How many genuinely different full contractions does a set of symmetric tensors have, and can a network evaluation reuse values that symmetry makes equal?

**What it would show.** With symmetric tensors, most ways of wiring the same leaves give the same scalar up to sign. Canonicalizing each wiring under the slot symmetries and the relabelling of summed indices (what `TensorReduce` does term by term) reduces a large list of contractions to a few distinct graphs. For a tensor-network user this means fewer contractions to run; for a physicist it is the count of independent invariants, which a dense evaluation of each wiring cannot give.

**Test in the paclet.** Generate every pairing of the slots of k symmetric leaves, reduce the symbolic contractions with `TensorReduce` under `Arrays[..., Symmetric[...]]` assumptions, and evaluate only the distinct canonical forms with `TensorNetworkContract`. Compare the time with evaluating every pairing, and compare the count of distinct forms with the number of linearly independent values found numerically on random tensors (the second count can be smaller, because relations among several terms are invisible to `TensorReduce`).

**Example.** Four copies of a fully symmetric rank-3 tensor have 10,395 ways to pair their 12 slots but only eight distinct contraction graphs, so evaluating every pairing densely at dimension 30 repeats each distinct contraction more than a thousand times on average. The same count for two Riemann tensors gives the known three independent quadratic curvature scalars, provided the Bianchi relation is used.

## 10. Can the paclet compute an SU(2)-invariant operator on the multiplicity spaces of Schur-Weyl duality instead of on full-size projected copies?

**What it would show.** An operator that commutes with every collective rotation acts as an f-by-f matrix on the multiplicity space of each shape, where f is `TableauDimension`, repeated `SchurDimension` times. The Heisenberg Hamiltonian is a sum of transpositions (`S_i . S_j = (2 P_ij - 1)/4`), so it is an element of the symmetric-group algebra, and its matrix on each shape follows from Young's orthogonal form, independent of d. Demo 1 instead projects the operator onto each block and keeps full `d^n`-by-`d^n` tensors, which saves no storage. The answer shows whether the paclet's Young machinery can deliver the real reduction, and it needs Young's orthogonal form, which the Symmetry functions do not provide.

**Test in the paclet.** Build the transposition matrices on each shape from Young's orthogonal form, assemble the Heisenberg ring Hamiltonian per shape, and compare its eigenvalues (each repeated `SchurDimension[shape, 2]` times) with dense diagonalization at sizes where the dense route still works.

**Example.** The Heisenberg ring on 12 spins: dense diagonalization works on a 4096-by-4096 matrix, while the largest multiplicity space with at most two rows is 297-dimensional (shape {7, 5}), and the full spectrum follows from seven matrices no larger than that.

## 11. Can the orthogonal projector onto one Young shape be written as a tensor network small enough to go past the point where its dense or permutation-sum forms fail?

**What it would show.** Schur sampling, spectrum estimation from n copies of a state, and the check that an encoded state stays in a decoherence-free subspace all need the orthogonal projector onto one shape's block. The forms in use fail early: the sum over n! permutations with character weights, the dense correction `M . PseudoInverse[M]` on a `d^n`-dimensional space, and `YoungProject` itself at rank 12 on a 32 GB machine. Efficient circuits for the Schur transform (Bacon, Chuang and Harrow) imply that a polynomial-size network exists. The answer is the bond dimension of a matrix product operator for the projector as a function of n, and whether contracting it with a product state or a matrix product state stays cheap.

**Test in the paclet.** Construct the total-spin projector for n qubits as a matrix product operator that tracks the running total spin along the chain, check it against `M . PseudoInverse[M]` for n up to 8, then compute shape probabilities for product states and for `rho^{⊗ n}` at larger n through `TensorNetworkContract`.

**Example.** Spectrum estimation with 16 copies of a qubit state: the dense projector would act on a 65,536-dimensional space and the permutation sum has about 2 times 10^13 terms, while a network whose bond dimension grows only polynomially in n would give the probability of each shape directly.

## 12. Can symmetry-resolved entanglement be read from the charge labels on a bond instead of from projected reduced density matrices?

**What it would show.** For a state with a conserved charge, the reduced density matrix of a region is block-diagonal by the charge of that region, and its Rényi entropies split into per-sector contributions (Goldstein and Sela). These per-sector numbers, and related quantities such as the entanglement asymmetry of a state that breaks the symmetry, exist only once the symmetry is specified. Demo 2 obtains them by forming the full reduced density matrix and projecting it, which costs the full dimension of the region. If bonds carry charge labels (questions 3 and 10), the Schmidt values at a cut come already sorted by sector, and the resolved spectrum costs nothing extra. The answer shows whether labelled bonds give these quantities directly, and whether the non-abelian version (sectors labelled by shapes, with the `SchurDimension` degeneracy factored out) is consistent with the projector route.

**Test in the paclet.** For the XX chain, whose ground state is exactly solvable, compute charge-resolved Rényi-2 entropies of half the chain both by projecting the dense reduced density matrix and from the singular values of a charge-sorted matrix product state, and compare with the free-fermion result. Repeat for an SU(2) singlet state using the correct shape projectors.

**Example.** A 20-site XX chain cut in half: the dense route forms and projects a 1024-by-1024 reduced density matrix for each sector, while the labelled bond gives the resolved spectrum from singular values already computed. Without the charge labels the dense route still gives the total entropy but cannot tell which sector each Schmidt value belongs to.
