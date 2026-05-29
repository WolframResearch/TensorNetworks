# Demo 3: Schur sampling via Young projectors on a TN, with applications to spectrum estimation

**Audience.** Quantum information / quantum algorithms community (Schur-sampling, Keyl-Werner spectrum estimation, decoherence-free subspace, reference-frame-free communication). Recent quantum-learning work (Wright 2016, Acharya-Issa-Shende-Wright 2019, O'Donnell-Wright 2017) leans on this primitive.

**Anchor paper.** Dave Bacon, Isaac L. Chuang, and Aram W. Harrow, *Efficient Quantum Circuits for Schur and Clebsch-Gordan Transforms*, Phys. Rev. Lett. **97**, 170502 (2006), arXiv:quant-ph/0407082. The Schur decomposition (Eq. 4 of the paper) and the Schur-basis measurement protocol (Fig. 3 and surrounding text) are the structural basis.

**Tagline.** "The Schur transform is a unitary on $V^{\otimes n}$ that maps the computational basis into a basis labelled by `(Young partition, GT pattern, standard tableau)`. The probability that a state lies in irrep $\lambda$ is $\|\Pi_\lambda |\psi\rangle\|^2$, where $\Pi_\lambda$ is the isotypic projector. The paclet's Symmetry layer builds $\Pi_\lambda$ in one line via `YoungProject`, summed over standard tableaux of shape $\lambda$. This gives Schur sampling as a TN computation, and the Keyl-Werner spectrum-estimation protocol comes out as a direct application."

---

## What BCH's paper actually says

The paper's core mathematical statement (their Eq. 4) is Schur duality. For any $n$, $d$,
$$
\bigl(\mathbb{C}^d\bigr)^{\otimes n} \;\cong\; \bigoplus_{\lambda \in \text{Part}[n, d]} \mathcal Q_\lambda \otimes \mathcal P_\lambda
$$
where $\lambda$ ranges over partitions of $n$ with $\leq d$ parts. $\mathcal Q_\lambda$ is the $\mathcal U_d$ irrep (dimension equal to `SchurDimension[par, d]` in the paclet); $\mathcal P_\lambda$ is the $\mathcal S_n$ irrep (dimension equal to `TableauDimension[par]`). The Schur basis is $|\lambda, q, p\rangle$ with $q$ indexing $\mathcal Q_\lambda$ and $p$ indexing $\mathcal P_\lambda$.

The Schur transform $\bU_{\rm Sch}$ is the unitary that converts the computational basis into the Schur basis. BCH's main result is an efficient ($\text{poly}(n, d, \log 1/\epsilon)$) quantum circuit for $\bU_{\rm Sch}$ via a cascade of Clebsch-Gordan steps.

The applications they enumerate (intro paragraph) are striking:

- *Spectrum estimation of a density operator* (Keyl-Werner 2001): apply $\bU_{\rm Sch}$ to $n$ iid copies of an unknown $\rho$, measure $\lambda$, and the empirical distribution over $\lambda$ converges to the eigenvalue spectrum of $\rho$ as $n \to \infty$.
- *Optimal quantum hypothesis testing* (Hayashi 2002).
- *Universal quantum source coding* (Hayashi-Matsumoto 2002).
- *Distortion-free entanglement concentration* (Hayashi-Matsumoto 2002).
- *Decoherence-free subspaces* (Knill-Laflamme-Viola 2000): encode logical qubits into $\mathcal P_\lambda$ (which is invariant under collective $U \otimes \cdots \otimes U$).
- *Reference-frame-free quantum communication* (Bartlett-Rudolph-Spekkens 2003): same idea.

Crucial observation for our demo: most of these applications need only the *measurement* of $\lambda$, not the full Schur basis transformation. The Schur basis measurement (BCH's Fig. 3) is just the isotypic projector $\Pi_\lambda$:
$$
\text{Pr}(\lambda \mid \psi) = \|\Pi_\lambda |\psi\rangle\|^2 = \langle \psi | \Pi_\lambda | \psi \rangle
$$
The paclet builds $\Pi_\lambda$ as a sum of `YoungProject` over the standard tableaux of shape $\lambda$. This is the construction we already exercise in the rank-3 Schur-Weyl section of the tutorial: an isotypic projector = sum of single-tableau Young projectors. Applied to $|\psi\rangle$ followed by a norm-squared, it gives the Schur-sampling probability.

So the contribution of this demo is to recognize that the rank-3 isotypic-projection construction *is the Schur sampler*, and to use it as such on physically meaningful inputs.

## The TN paclet's role

We use:

- `YoungTableau` and `YoungProject` to construct the isotypic projector $\Pi_\lambda$ as `Total[YoungProject[*, YoungTableau[T]] & /@ standardTableaux[lambda]]`.
- `TableauDimension[par]` and `SchurDimension[par, d]` to predict block sizes and Schur-sampling probability bounds.
- `IntegerPartitions[n, d]` (built-in WL) to enumerate the partition labels that contribute at given $(n, d)$.
- `TensorNetwork`, `TensorNetworkContract` to evaluate the Schur sampler's outcome probability as a TN inner product $\langle \psi | \Pi_\lambda | \psi \rangle$.

The BCH paper provides the quantum-information context: Schur sampling, Keyl-Werner spectrum estimation, decoherence-free subspaces. Our demo provides the *computational primitives* that let a quantum-information researcher implement these protocols directly in WL.

---

## Pedagogical arc

### Section A. The Schur decomposition for 3 qubits

Set $n = 3$, $d = 2$. The relevant partitions are $\{3\}$ and $\{2, 1\}$ (the partition $\{1, 1, 1\}$ has more than $d = 2$ parts so contributes a zero-dimensional block). Block sizes:

- $\{3\}$: `TableauDimension[{3}] * SchurDimension[{3}, 2]` = $1 \cdot 4 = 4$. This is the totally symmetric / spin-$3/2$ sector.
- $\{2, 1\}$: `TableauDimension[{2, 1}] * SchurDimension[{2, 1}, 2]` = $2 \cdot 2 = 4$. This is the mixed-symmetry / spin-$1/2$ sector with 2 copies of the spin-$1/2$ irrep.
- $\{1, 1, 1\}$: 0 (Pauli exclusion on three fermions in a 2-level space).

Total: $4 + 4 + 0 = 8 = 2^3$. Verify in one cell.

State the BCH Eq. 4 explicitly for $(n, d) = (3, 2)$ and connect the partition labels to "total angular momentum $J$" terminology: $\lambda = \{3\}$ is $J = 3/2$, $\lambda = \{2, 1\}$ is $J = 1/2$.

### Section B. Building the isotypic projectors

For each $\lambda \vdash 3$ with at most 2 parts, build $\Pi_\lambda$:

```wl
isotypicProjector[lambda_, n_, d_] := With[
    {tableaux = standardTableaux[lambda]},
    Total[
        YoungProject[#, YoungTableau[#]] & /@ tableaux
    ]
]
```

Wait — the issue is that `YoungProject` acts on a *tensor*, not directly on a Hilbert-space vector. We need to apply $\Pi_\lambda$ to a state $|\psi\rangle = \sum_{i_1 i_2 i_3} \psi_{i_1 i_2 i_3} |i_1 i_2 i_3\rangle$, which is rank-3 tensor data. So the right construction is

```wl
applyIsotypicProjector[psi_, lambda_] := Total[
    YoungProject[psi, YoungTableau[#]] & /@ standardTableaux[lambda]
]
```

For $\lambda = \{3\}$ there is one standard tableau, $\{\{1, 2, 3\}\}$. For $\lambda = \{2, 1\}$ there are two, $\{\{1, 2\}, \{3\}\}$ and $\{\{1, 3\}, \{2\}\}$ (i.e., `TableauDimension[{2, 1}] = 2`). Enumerate them.

Verify by direct computation that:

1. $\Pi_\lambda^2 = \Pi_\lambda$ (idempotency) for each $\lambda$.
2. $\Pi_{\{3\}} + \Pi_{\{2, 1\}} = I$ (resolution of identity at $n = 3$, $d = 2$).
3. $\Pi_\lambda \Pi_\mu = 0$ for $\lambda \neq \mu$ (orthogonality of isotypic projectors).

The first two checks recover the rank-3 Schur-Weyl checks already present in the tutorial. The third is new but follows trivially from the projector identities. Each check is a one-line TN contraction.

### Section C. Schur sampling on physically meaningful inputs

Take three test states and compute the Schur-sampling probabilities $\text{Pr}(\lambda \mid \psi) = \langle \psi | \Pi_\lambda | \psi \rangle$:

**Input 1: GHZ-3.** $|\text{GHZ}\rangle = (|000\rangle + |111\rangle)/\sqrt 2$. The GHZ state is invariant under qubit permutations (totally symmetric), so all of its weight lies in $\mathcal Q_{\{3\}} \otimes \mathcal P_{\{3\}}$. Predict: $\text{Pr}(\{3\}) = 1$, $\text{Pr}(\{2, 1\}) = 0$.

Verify in one cell. Result must be exactly $\{1, 0\}$ up to numerical noise.

**Input 2: W-3.** $|W\rangle = (|001\rangle + |010\rangle + |100\rangle)/\sqrt 3$. Also totally symmetric (it's a Dicke state with one excitation). Same prediction: $\text{Pr}(\{3\}) = 1$.

Verify.

**Input 3: Random product state.** $|\psi\rangle = |a\rangle \otimes |b\rangle \otimes |c\rangle$ with three independently sampled qubits. This is generically *not* permutation-symmetric, so the Schur-sampling distribution spreads across $\{3\}$ and $\{2, 1\}$. Compute the empirical probabilities; verify they sum to 1.

This is the elementary verification that Schur sampling is sensitive to the permutation symmetry of the input state.

**Input 4: A Bell pair $\otimes$ one product qubit.** $|\psi\rangle = (|00\rangle + |11\rangle)/\sqrt 2 \otimes |0\rangle$. The first two qubits are symmetric (a $\{2\}$-shape state at $n = 2$), the third is generic. Predict: weight splits between $\{3\}$ and $\{2, 1\}$ in a way determined by the projection of the third qubit onto the symmetric vs mixed-symmetry sectors built atop the first two.

Compute and report. The result is non-trivial but checkable by direct calculation.

### Section D. Spectrum estimation (Keyl-Werner)

This is the cutting-edge application. The protocol is:

1. Choose a target density matrix $\rho$ on $\mathbb{C}^d$ with eigenvalue spectrum $(p_1, p_2, \ldots, p_d)$ in non-increasing order.
2. Prepare $n$ iid copies: $\rho^{\otimes n}$.
3. Apply the Schur sampler: measure $\lambda$ in the Schur basis.
4. The empirical distribution over $\lambda$ converges, as $n \to \infty$, to a distribution concentrated on the partition $\lambda^\star = (n p_1, n p_2, \ldots, n p_d)$ (suitably rounded). Equivalently: the "Young diagram of $\lambda^\star$" reads off the eigenvalue spectrum of $\rho$.

For $d = 2$ this means: given $n$ iid copies of a qubit $\rho$ with eigenvalues $(p, 1 - p)$ (so the Bloch sphere position), Schur sampling at $\rho^{\otimes n}$ returns $\lambda = (n p, n(1 - p))$ with high probability for large $n$.

Concretely we demonstrate this at $n = 4$ and $n = 6$ qubits, with $\rho = \text{diag}(p, 1 - p)$ for several values of $p$. The demo:

1. Build $\rho$ as a $2 \times 2$ density matrix.
2. Construct the $n$-copy density matrix $\rho^{\otimes n}$ (this is a rank-$2n$ tensor; for purity testing we can also use the pure-state version where each copy is $|\psi\rangle = \sqrt{p}|0\rangle + \sqrt{1 - p}|1\rangle$).
3. Build the isotypic projector $\Pi_\lambda$ for each partition $\lambda \vdash n$ with at most 2 rows.
4. Compute $\text{Pr}(\lambda) = \text{Tr}(\rho^{\otimes n} \Pi_\lambda)$ for each $\lambda$.
5. Show that the maximum-probability $\lambda^\star$ has $\lambda_1 / n \approx p$ as $n$ grows.

Display the result as a `BarChart` of $\text{Pr}(\lambda)$ vs $\lambda$ for several values of $p$ and $n$. The reader sees the empirical Young diagram of $\rho$ emerge.

This is the Keyl-Werner protocol in $\sim 30$ lines. Production quantum-info implementations require the full Schur transform circuit (BCH's main result); for spectrum estimation alone, the isotypic-projector approach suffices and is much simpler.

### Section E. The decoherence-free subspace

A second cutting-edge application: $\mathcal P_\lambda$ (the multiplicity space) is invariant under any collective unitary $U \otimes U \otimes \cdots \otimes U$. So encoding a logical qubit into $\mathcal P_\lambda$ gives a state immune to collective noise on the physical qubits.

The dimensions of $\mathcal P_\lambda$ for $n = 4$, $d = 2$:
- $\mathcal P_{\{4\}}$: `TableauDimension[{4}]` = 1.
- $\mathcal P_{\{3, 1\}}$: `TableauDimension[{3, 1}]` = 3.
- $\mathcal P_{\{2, 2\}}$: `TableauDimension[{2, 2}]` = 2.

So at $n = 4$, $d = 2$ we get a 2-dimensional decoherence-free subspace from the $\lambda = \{2, 2\}$ sector (one logical qubit on four physical qubits), and a 3-dimensional one from $\lambda = \{3, 1\}$ (one logical qutrit). This is what Knill-Laflamme-Viola identified as the DFS at $n = 4$.

Demo: build a 4-qubit state living entirely in $\mathcal P_{\{2, 2\}}$ via Young projection. Apply a collective unitary $U^{\otimes 4}$ (with $U$ a generic SU(2) element) and verify the within-$\mathcal P_{\{2, 2\}}$ structure is preserved (the state stays in $\mathcal P_{\{2, 2\}}$, possibly with a different vector inside that 2-dim space, but the "logical qubit" survives).

Verify: collective $U^{\otimes n}$ acts on the right (the $\mathcal Q_\lambda$ factor) and leaves the left (the $\mathcal P_\lambda$ factor) invariant. Numerically check that the partition-label distribution is unchanged by $U^{\otimes 4}$.

This is the encoding side of the Bartlett-Rudolph-Spekkens reference-frame-free communication scheme.

### Section F. Where this lands the reader

Closing prose names what was demonstrated:

- The Schur sampler as an isotypic projector built from $\sum_T \text{YoungProject}[\cdot, T]$ over standard tableaux of shape $\lambda$.
- Schur sampling probabilities for textbook quantum-info states (GHZ, W, Bell-times-product, random).
- The Keyl-Werner spectrum estimator: distribution over partition labels recovers the eigenvalue spectrum of an iid-copied density matrix.
- The decoherence-free subspace from $\mathcal P_\lambda$ as a collectively-invariant encoding.

Cite Keyl-Werner (Phys. Rev. A 64, 052311), Hayashi (J. Phys. A 35, 10759), Knill-Laflamme-Viola (Phys. Rev. Lett. 84, 2525), Bartlett-Rudolph-Spekkens (Phys. Rev. Lett. 91, 027901), and recent spectrum-estimation work (O'Donnell-Wright STOC 2017, Acharya-Issa-Shende-Wright arXiv:1907.06479) as the production-application references this demo's primitive serves.

---

## Code-cell inventory

Estimated 30-35 cells plus 10-12 text-cell paragraphs. Total ~80-100 lines of WL.

**Setup (3 cells):**
- Load paclet and Symmetry namespace.
- Define `standardTableaux[lambda]` (helper that enumerates standard tableaux of shape $\lambda$ via filtered `Permutations`).
- Pre-tabulate partition data for $n = 3, 4$ at $d = 2$.

**Constructing isotypic projectors (5 cells):**
- Define `applyIsotypicProjector[psi_, lambda_]`.
- Verify idempotency for each partition at $n = 3$, $d = 2$.
- Verify resolution of identity: $\sum_\lambda \Pi_\lambda = I$.
- Verify orthogonality: $\Pi_\lambda \Pi_\mu = 0$ for $\lambda \neq \mu$.

**Schur sampling on test states (8 cells):**
- Build GHZ-3, W-3, random product, and Bell-product states.
- For each, compute $\text{Pr}(\lambda) = \langle \psi | \Pi_\lambda | \psi \rangle$ for each $\lambda$.
- Verify normalisation $\sum_\lambda \text{Pr}(\lambda) = 1$.
- Display as a small `Dataset` table.

**Keyl-Werner spectrum estimation (10 cells):**
- Parametrise $\rho = \text{diag}(p, 1 - p)$ for $p \in \{0.3, 0.5, 0.7\}$.
- Build $|\psi_p\rangle^{\otimes n}$ as a rank-$n$ tensor for $n = 4$ and $n = 6$.
- Build $\Pi_\lambda$ for each $\lambda \vdash n$ with $\leq 2$ rows.
- Compute $\text{Pr}(\lambda \mid \psi_p)$.
- `BarChart` over $\lambda_1 / n$ axis showing the empirical Young-diagram-of-$\rho$ peak emerging at $\lambda_1 / n = p$.
- Verify the peak converges as $n$ grows.

**Decoherence-free subspace (5 cells):**
- At $n = 4$, $d = 2$, predict $\dim \mathcal P_{\{2, 2\}}$ via `TableauDimension[{2, 2}]`.
- Build a generic state in $\mathcal P_{\{2, 2\}}$ via `YoungProject` from a random tensor.
- Apply a random collective unitary $U^{\otimes 4}$ to the state.
- Verify partition distribution is unchanged.
- One paragraph noting that this is the Knill-Laflamme-Viola DFS at $n = 4$.

**Closing (2 cells):**
- One paragraph summarising the three applications.
- Citations to recent spectrum-estimation literature.

---

## What the reader takes away

After this section a quantum-information researcher should be able to:

1. Construct the Schur-basis measurement operator $\Pi_\lambda$ for any partition $\lambda$ and any $(n, d)$ as `Total[YoungProject[*, YoungTableau[T]] & /@ standardTableauxOfShape[lambda]]`.
2. Predict the Schur-sampling probability for any input state $|\psi\rangle$ as $\langle \psi | \Pi_\lambda | \psi \rangle$.
3. Implement the Keyl-Werner spectrum estimation protocol on simulated iid-copy data.
4. Identify decoherence-free subspaces $\mathcal P_\lambda$ from their dimensions $\text{TableauDimension}[\lambda]$ and verify their invariance under collective $U^{\otimes n}$.
5. Connect the paclet's Symmetry layer to the BCH quantum-circuit construction: BCH's Fig. 3 (the irrep-measurement circuit) is what the paclet implements as a TN expression.

This is the most quantum-information-flavoured of the three demos and lands best in a quantum-info venue (Quantum, npj Quantum Information, Phys. Rev. A). It connects representation-theoretic primitives to a concrete measurement protocol with applications spanning the entire quantum-information literature from 2001 to present.

## Risk and verification

- **Risk: `standardTableaux[lambda]` is not exported by the paclet.** It is generated by filtering `Permutations[Range[n]]` against `YoungTableauQ` (the same trick used in the Demo-1 plan and the rank-3 Schur-Weyl tutorial section). One helper function definition resolves this.
- **Risk: confusion between the Schur transform (a unitary) and the isotypic projector (a Hermitian projector).** Mitigation: state clearly in Section A that the demo implements only the *measurement* aspect of BCH's Fig. 3, not the full Schur transform circuit.
- **Risk: numerical instability of $\rho^{\otimes n}$ at large $n$.** Mitigation: cap $n = 6$ in the spectrum-estimation demo; the Keyl-Werner asymptotic is already visible at that size.
- **Verification protocol:** every probability is a one-line `Chop[Total[Pr] == 1]` check; the GHZ / W states are exact and give $\{1, 0\}$ exactly; the Keyl-Werner peaks are visually checked against the predicted $\lambda_1 / n = p$. Runtime under 5 seconds.

## External references to cite

- Bacon, Chuang, Harrow, *Phys. Rev. Lett.* **97**, 170502 (2006), arXiv:quant-ph/0407082 (anchor).
- Keyl & Werner, *Phys. Rev. A* **64**, 052311 (2001), arXiv:quant-ph/0102027 (spectrum estimation).
- Hayashi, *J. Phys. A* **35**, 10759 (2002), arXiv:quant-ph/0202003 (optimal hypothesis testing).
- Hayashi & Matsumoto, *Phys. Rev. A* **66**, 022311 (2002), arXiv:quant-ph/0202001 (universal source coding).
- Knill, Laflamme, Viola, *Phys. Rev. Lett.* **84**, 2525 (2000), arXiv:quant-ph/9908066 (decoherence-free subspaces).
- Bartlett, Rudolph, Spekkens, *Phys. Rev. Lett.* **91**, 027901 (2003), arXiv:quant-ph/0302111 (reference-frame-free).
- O'Donnell & Wright, *STOC 2017*, arXiv:1701.03953 (efficient spectrum estimation lower bounds).
- Acharya, Issa, Shende, Wright, arXiv:1907.06479 (recent spectrum-estimation algorithms).
- Wright, *PhD thesis* (2016), Carnegie Mellon (comprehensive Schur-Weyl-sampling overview).
