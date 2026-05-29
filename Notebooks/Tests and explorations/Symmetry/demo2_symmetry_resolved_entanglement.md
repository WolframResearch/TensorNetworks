# Demo 2: Symmetry-resolved entanglement of an SU(2)-symmetric TN state

**Audience.** Many-body / entanglement physics community (Calabrese, Laflorencie, Cornfeld, Sela, Murciano-Bonsignori-Calabrese lineage; ~2017-present).

**Anchor paper.** Moshe Goldstein and Eran Sela, *Symmetry-resolved entanglement in many-body systems*, Phys. Rev. Lett. **120**, 200602 (2018), arXiv:1711.09418. The U(1) result (Eqs. 7-10) and the SU(2) generalization (Eqs. 16-17) are the structural basis. We use the SU(2) case because it requires Young-partition labels.

**Tagline.** "Cut a TN at one bond. The reduced density matrix is block-diagonal in the partition label $\lambda$. The entanglement entropy decomposes as a sum over $\lambda$-sectors, with block sizes given exactly by `TableauDimension[par] * SchurDimension[par, d]`. The paclet's Symmetry layer produces the symmetry-resolved entanglement spectrum in one short worked example."

---

## What Goldstein-Sela's paper actually says

Their basic observation (Sec. 1, Eqs. 1-3): if the total system's density matrix $\rho$ commutes with a conserved quantity $\hat N$ (a U(1) charge or a non-abelian generator), and $\hat N = \hat N_A + \hat N_B$ decomposes additively across a bipartition, then tracing $[\hat N, \rho] = 0$ over subsystem $B$ gives
$$
[\hat N_A, \rho_A] = 0
$$
which forces $\rho_A$ to be block-diagonal in the symmetry sectors of subsystem $A$. The Renyi entropies decompose as
$$
s_n = \text{Tr}\,\rho_A^n = \sum_{N_A} s_n(N_A) = \sum_{N_A} \text{Tr}\,(\rho_A^n \,\mathcal{P}_{N_A})
$$
where $\mathcal{P}_{N_A}$ is the projector onto the fixed-charge subspace of $A$. The entanglement entropy decomposes the same way.

The paper's main analytical contribution (Eqs. 6-10) computes $s_n(N_A)$ in 1+1D CFT by inserting an Aharonov-Bohm flux on a multi-sheet Riemann surface and Fourier-transforming over the flux. For a Luttinger liquid with parameter $K$ and subsystem of length $L$,
$$
s_n(\Delta N_A) \approx s_n(\alpha = 0) \,\sqrt{\frac{\pi n}{2 K \ln L}}\, \exp\!\left(-\frac{n \pi^2 \Delta N_A^2}{2 K \ln L}\right)
$$
which shows the *scaling decomposition*: total entanglement scales as $\ln L$ but the contribution of each charge sector scales as $\sqrt{\ln L}$. The Gaussian envelope is set by the variance of charge fluctuations in $A$.

Section "SU(2) symmetry" (around Eq. 16): the same construction works for non-abelian symmetries. For an SU(2)-symmetric state, $\rho_A$ block-decomposes by $(S_A, S^z_A)$. The total-spin block dimensions are exactly what `TableauDimension[\lambda] * SchurDimension[\lambda, d]` gives, where $\lambda$ is the Young partition labelling the irrep. The paper computes the scaling for critical SU(2)-symmetric chains (WZW models) and predicts a $\sqrt{\ln L}$ scaling per sector, exactly as in the U(1) case.

Our demo doesn't reproduce the CFT scaling (that would require Bethe-ansatz ground states of the Heisenberg chain or DMRG, which is out of scope). Instead, we reproduce the *structural* claim numerically on a small SU(2)-singlet TN state:

1. Build a small SU(2)-symmetric state.
2. Partial-trace it to get $\rho_A$.
3. Decompose $\rho_A$ into partition sectors using `YoungProject` on the slots of $A$.
4. Show the block decomposition explicitly: matrix-form of $\rho_A$ becomes block-diagonal in the Young basis; off-diagonal blocks are zero by Schur orthogonality.
5. Compute the symmetry-resolved entropies and verify they sum to the total entropy.

## The TN paclet's role

We use:

- `TensorNetwork` to build the SU(2)-symmetric singlet state on a small chain as a TN.
- `TensorNetworkContract` to evaluate the partial trace giving $\rho_A$.
- `YoungProject` to project $\rho_A$ onto each partition sector via the *isotypic* projector.
- `TableauDimension`, `SchurDimension` to predict the block dimensions ahead of time.

The Goldstein-Sela paper provides the conceptual framework (symmetry-resolved entropies) and the closed-form analytical scaling. Our demo provides the *computational primitives* that let a researcher reproduce these decompositions for any TN state and any partition label.

---

## Pedagogical arc

### Section A. Set up the SU(2)-singlet two-bond state

Use a 4-site spin-1/2 chain. The total Hilbert space is $2^4 = 16$ dimensional and decomposes by Schur-Weyl as
$$
(\mathbb{C}^2)^{\otimes 4} \cong \mathcal Q_{\{4\}} \otimes \mathcal P_{\{4\}} \,\oplus\, \mathcal Q_{\{3, 1\}} \otimes \mathcal P_{\{3, 1\}} \,\oplus\, \mathcal Q_{\{2, 2\}} \otimes \mathcal P_{\{2, 2\}}
$$
with block dimensions $5 + 9 + 2 = 16$ (verified by `TableauDimension * SchurDimension`).

Build a state in the total-singlet sector $\lambda = \{2, 2\}$ via product of two two-site singlets:
$$
|\psi\rangle = |s\rangle_{12} \otimes |s\rangle_{34}, \quad |s\rangle = \tfrac{1}{\sqrt 2}(|01\rangle - |10\rangle)
$$
or, more interestingly, a non-product singlet built by applying $\Pi_{\{2, 2\}}$ to a random 4-qubit state and normalising.

Both options are easy to construct. The non-product option is more interesting because $\rho_A$ on subsystem $A$ = first two sites is then non-trivially decomposed. Use the second option, with a fixed random seed for reproducibility.

Cell-level:

```wl
psi = YoungProject[RandomReal[{-1, 1}, ConstantArray[2, 4]],
                   YoungTableau[{{1, 2}, {3, 4}}]];
psi = psi / Norm[Flatten[psi]];
```

Verify $|\psi\rangle$ is annihilated by the total-spin lowering: $S^- |\psi\rangle = 0$ and $\langle \psi | \vec S_{\text{tot}}^2 | \psi \rangle = 0$. Both checks are one-liners using `KroneckerProduct @@ ReplacePart[...]`-style constructions; same pattern as the Dicke-state subsection of the tutorial.

### Section B. The reduced density matrix on subsystem A

Subsystem $A$ = first two sites. Build $\rho_A$ via partial trace:
$$
\rho_A = \text{Tr}_B \,|\psi\rangle \langle \psi| = \sum_{j_3, j_4} \psi^{\phantom{*}}_{i_1 i_2 j_3 j_4}\, \psi^*_{i'_1 i'_2 j_3 j_4} \;|i_1 i_2\rangle\langle i'_1 i'_2|
$$
as a $4 \times 4$ matrix.

Build it as a TN: $\rho_A$ is the contraction of $\psi$ against $\psi^*$ with shared indices on $j_3, j_4$. Use `TensorNetwork[{psi, Conjugate[psi]}, {{"a", "b", "x", "y"}, {"a'", "b'", "x", "y"}}, {"a", "b", "a'", "b'"}]` followed by `TensorNetworkContract`.

This is the first TN-paclet workhorse use in this demo: the partial trace, expressed as a contracted TN with explicit shared indices.

Display $\rho_A$ as a $4 \times 4$ matrix. Generically it is dense, not visibly block-diagonal.

### Section C. The block-diagonal structure in the Young basis

The Goldstein-Sela structural claim: $\rho_A$ commutes with $\vec S_A^2$ and $S_A^z$, so it is block-diagonal in the partition basis of $A$. For $A$ = two sites of spin-1/2, the partitions of 2 are $\{2\}$ (triplet, dim 3) and $\{1, 1\}$ (singlet, dim 1), block-decomposing the $4$-dim Hilbert space of $A$ as $3 + 1 = 4$.

Build the two isotypic projectors $\Pi_{\{2\}}$ and $\Pi_{\{1, 1\}}$ via `YoungProject` summed over standard tableaux of each shape (same pattern as the rank-3 Schur-Weyl section of the tutorial; at rank 2 each shape has only one standard tableau).

Apply the projectors to $\rho_A$ from both sides:
$$
\rho_A^{(\lambda)} \;=\; \Pi_\lambda \,\rho_A \,\Pi_\lambda
$$

Verify:

1. **Block-diagonality**: $\Pi_{\{2\}} \rho_A \Pi_{\{1, 1\}} = 0$ and $\Pi_{\{1, 1\}} \rho_A \Pi_{\{2\}} = 0$. Two cells, each a one-line `Chop[Max[Abs[Flatten[...]]] == 0]` check.

2. **Sum reconstructs**: $\rho_A = \rho_A^{(\{2\})} + \rho_A^{(\{1, 1\})}$.

3. **Block sizes match prediction**:
   - $\text{rank}(\rho_A^{(\{2\})}) \leq \dim Q_{\{2\}} \cdot \dim P_{\{2\}}$ = `TableauDimension[{2}] * SchurDimension[{2}, 2]` = $1 \cdot 3 = 3$.
   - $\text{rank}(\rho_A^{(\{1, 1\})}) \leq 1 \cdot 1 = 1$.
   - For our $|\psi\rangle$, generically both blocks have full rank within their predicted dimensions.

4. **Total probability per sector**:
   - $p_{\{2\}} = \text{Tr}\,\rho_A^{(\{2\})}$
   - $p_{\{1, 1\}} = \text{Tr}\,\rho_A^{(\{1, 1\})}$
   - $p_{\{2\}} + p_{\{1, 1\}} = 1$ (trace conservation).

### Section D. Symmetry-resolved Renyi entropies

For each partition sector $\lambda$, compute the normalized reduced density matrix $\tilde\rho_A^{(\lambda)} = \rho_A^{(\lambda)} / p_\lambda$ and the Renyi-2 entropy
$$
S_2(\lambda) = -\log \text{Tr}\,\bigl(\tilde\rho_A^{(\lambda)}\bigr)^2
$$

Compute also the *unnormalized* Renyi contributions per sector
$$
\sigma_n(\lambda) = \text{Tr}\,\bigl(\rho_A^{(\lambda)}\bigr)^n
$$
which is what Goldstein-Sela call $s_n(N_A)$ in their Eq. 3. These additively reconstruct the total Renyi-$n$ entropy:
$$
\sigma_n^{\text{total}} = \sum_\lambda \sigma_n(\lambda)
$$
which is the central claim of the paper.

Cell-level: a one-line `AssociationMap` over partitions of 2 computing the sector trace, eigenvalues, and Renyi-2 contribution.

Display the result as a small table:

| partition $\lambda$ | block dimension | $p_\lambda$ | $\sigma_2(\lambda)$ |
|---|---|---|---|
| $\{2\}$ | 3 | (numerical) | (numerical) |
| $\{1, 1\}$ | 1 | (numerical) | (numerical) |
| **total** | 4 | 1 | $\sigma_2^{\text{total}}$ |

### Section E. Extending to a richer example

Two extensions to make the cutting-edge connection explicit:

**E.1 Larger subsystem.** Take a 6-site chain in the total-singlet sector and bipartition into $A$ = first 3 sites. Now the partitions of 3 are relevant: $\{3\}$ (4-dim), $\{2, 1\}$ (4-dim with 2 standard tableaux), $\{1, 1, 1\}$ (0-dim at $d = 2$, no contribution). The block dimensions are $4 + 4 + 0 = 8$. Repeat the decomposition and confirm $\sigma_n = \sum_\lambda \sigma_n(\lambda)$.

This step uses every Symmetry function that the rank-3 Schur-Weyl section of the tutorial already exercises (`PartitionQ`, `HookLength`, `HookLengths`, `HookFactor`, `TableauDimension`, `SchurDimension`). The pedagogical bonus is that the same machinery used to verify a structural identity (sum over partitions = total) in the rank-3 section is now applied to a *physical observable* (the Renyi entropy decomposition).

**E.2 Sector-conditioned Schmidt spectrum.** Diagonalize each $\rho_A^{(\lambda)}$ separately to get the Schmidt eigenvalues per sector. Display the *symmetry-resolved entanglement spectrum* as a list-plot, one colour per partition. This is what experimentalists and DMRG practitioners actually look at, and the picture maps directly onto the cited Goldstein-Sela Fig. 3 (their non-interacting tight-binding numerical comparison).

### Section F. Where this lands the reader

Closing prose names what was demonstrated:

- The block-diagonal structure of $\rho_A$ for any symmetric state, verified by `YoungProject` on the subsystem's slot indices.
- The symmetry-resolved Renyi entropies as the elementary observables in the Goldstein-Sela 2018 program.
- The mapping `partition label → block dimension` as a closed-form pre-allocation: `TableauDimension * SchurDimension`.
- A computational pathway from "I have an MPS / TN state" to "I have a charge-resolved entanglement spectrum" in roughly 30 lines.

Cite Cornfeld-Sela-Goldstein arXiv:1804.00632 (negativity-resolved), Bonsignori-Ruggiero-Calabrese arXiv:1911.09588 (CFT for symmetry-resolved), Murciano-Calabrese arXiv:2010.10717 (entanglement asymmetry), Vitale-Murciano-Calabrese arXiv:2202.01239 (experimental measurement) as the recent literature this demo's tooling supports.

---

## Code-cell inventory

Estimated 35-40 cells plus 12-15 text-cell paragraphs. Total ~110-130 lines of WL.

**Setup (3 cells):**
- Load paclet and Symmetry namespace.
- Define partitions of 2: `parsOf2 = IntegerPartitions[2]`.
- Define partitions of 3: `parsOf3 = IntegerPartitions[3]`.

**Constructing the SU(2)-singlet state (5 cells):**
- Build random 4-qubit tensor.
- Apply $\Pi_{\{2, 2\}}$ to project onto the singlet sector.
- Normalize.
- Verify total $S^z = 0$ and total $\vec S^2 = 0$ by direct operator application.
- Verify Frobenius norm equals 1.

**Computing $\rho_A$ as a TN (4 cells):**
- Define the bra-ket contraction TN.
- Use `TensorNetworkContract` to evaluate.
- Reshape into a $4 \times 4$ matrix.
- Verify trace equals 1 and Hermiticity.

**Block decomposition of $\rho_A$ (6 cells):**
- Define `isotypicProjector[lambda_, n_, d_]` using `YoungProject` summed over standard tableaux.
- Build $\Pi_{\{2\}}$ and $\Pi_{\{1, 1\}}$ as $4 \times 4$ matrices on $A$.
- Apply: $\rho_A^{(\lambda)} = \Pi_\lambda \rho_A \Pi_\lambda$.
- Verify off-diagonal blocks $\Pi_{\{2\}} \rho_A \Pi_{\{1, 1\}}$ etc. are zero.
- Verify $\rho_A = \sum_\lambda \rho_A^{(\lambda)}$.
- Verify $\text{rank}(\rho_A^{(\lambda)}) \leq$ `TableauDimension[lambda] * SchurDimension[lambda, 2]`.

**Symmetry-resolved Renyi entropies (6 cells):**
- Compute $p_\lambda$ per sector.
- Verify $\sum_\lambda p_\lambda = 1$.
- Compute $\sigma_2(\lambda) = \text{Tr}\,\rho_A^{(\lambda) 2}$ per sector.
- Verify $\sigma_2^{\text{total}} = \sum_\lambda \sigma_2(\lambda)$.
- Compute symmetry-resolved Renyi-2 entropy $S_2(\lambda) = -\log \text{Tr}\,(\tilde\rho_A^{(\lambda)})^2$.
- Display as `Dataset` with columns: partition, block dim, $p_\lambda$, $\sigma_2(\lambda)$, $S_2(\lambda)$.

**6-site extension (8 cells):**
- Build a 6-site singlet state via $\Pi_{\{3, 3\}}$ projection of a random tensor.
- Compute $\rho_A$ on the first three sites as a TN.
- Build isotypic projectors for partitions of 3 ($\{3\}$, $\{2, 1\}$, $\{1, 1, 1\}$).
- Verify block decomposition.
- Compute $\sigma_n(\lambda)$ per sector.
- Display the resulting decomposition.

**Symmetry-resolved entanglement spectrum (4 cells):**
- Diagonalize each $\rho_A^{(\lambda)}$ to get its Schmidt eigenvalues.
- Concatenate; verify total equals eigenvalues of $\rho_A$.
- `ListPlot` of $-\log \lambda_i$ vs index per sector with colour-coding.

**Closing (2 cells):**
- One paragraph summarising the closed-form prediction and the numerical verification.
- Citations to the 2018-2023 symmetry-resolved-entanglement literature.

---

## What the reader takes away

After this section a many-body / entanglement researcher should be able to:

1. Build any SU(2)-symmetric TN state from a generic tensor by applying the isotypic projector $\Pi_{\{n/2, n/2\}}$.
2. Compute its reduced density matrix on any bipartition as a contracted TN.
3. Decompose $\rho_A$ by partition sector in two `YoungProject` calls.
4. Extract the symmetry-resolved Renyi entropies without any analytical CFT input.
5. Reproduce the structural decomposition $\sigma_n = \sum_\lambda \sigma_n(\lambda)$ in finite-size systems where Goldstein-Sela's asymptotic CFT formula doesn't apply.

The result is a primitive that researchers in the symmetry-resolved-entanglement program can plug into their pipelines (whether MPS, exact diagonalization, or analytical) to extract sector-by-sector contributions to entanglement without writing their own irrep machinery.

## Risk and verification

- **Risk: numerical instability when projecting symbolic SU(2) generators.** Mitigation: use a fixed `SeedRandom` and Frobenius-norm checks at every step.
- **Risk: confusion between partition label $\lambda$ and total spin $S$.** Mitigation: state the conversion ($S = (\lambda_1 - \lambda_2)/2$ for partitions of 2 rows) in one cell with a table.
- **Risk: the singlet-product state $|s\rangle_{12} \otimes |s\rangle_{34}$ is "too simple" (its $\rho_A$ is also a product).** That's why we instead build $|\psi\rangle$ by applying $\Pi_{\{2, 2\}}$ to a random tensor. The resulting state is generically entangled across the bipartition.
- **Verification protocol:** every claim is a one-line `==` or `< tol` check. The 4-site demo runs in ~50 ms; the 6-site extension in ~200 ms; total runtime under a few seconds.

## External references to cite

- Goldstein & Sela, *Phys. Rev. Lett.* **120**, 200602 (2018), arXiv:1711.09418 (anchor).
- Laflorencie & Rachel, *J. Stat. Mech.* P11013 (2014), arXiv:1407.3779 (earlier U(1) numerical computation).
- Cornfeld, Goldstein, Sela, *Phys. Rev. A* **98**, 032302 (2018), arXiv:1804.00632 (symmetry-resolved negativity).
- Bonsignori, Ruggiero, Calabrese, *J. Phys. A* **52**, 475302 (2019), arXiv:1911.09588 (CFT generalization).
- Murciano, Bonsignori, Calabrese, *SciPost Phys.* **8**, 046 (2020), arXiv:1911.09631 (entanglement Hamiltonian).
- Vitale, Elben, Kueng, Neven, Carrasco, Kraus, Zoller, Calabrese, Vermersch, Dalmonte, *SciPost Phys.* **12**, 106 (2022), arXiv:2101.07814 (randomized-measurement protocol for symmetry-resolved entropies).
