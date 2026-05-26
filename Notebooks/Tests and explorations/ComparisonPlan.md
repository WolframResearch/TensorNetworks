# Wolfram/TensorNetworks: Comparison & Enhancement Plan

**Paclet:** `Wolfram/TensorNetworks` v1.0.4 (PrimaryContext `Wolfram`TensorNetworks``).
**Audit date:** 2026-05-25.
**Scope:** every exported kernel symbol across `Kernel/*.wl`, `Kernel/IndexArray/*.wl`, and `Kernel/Symmetry/*.wl`, scored against the cataloged external corpora at `Tests/external_validation/` (503 numerical entries) and `TN courses/External symbolic tensor/` (150 symbolic entries).

This document supersedes the earlier draft (which predated the IndexArray/MetricTensor subpackage, the Rust path optimizer, the Young-tableau module, the QuantumFramework downstream integration, and the external-validation suite). It is a planning document, not a tutorial; pair it with the existing tutorials under `TensorNetworks/Documentation/English/Tutorials/`.

---

## Part 1. Paclet surface area (audited)

Every symbol below is exported by the current kernel. Counts at the end of each subsection.

### 1.1 Core data structure (`Kernel/TensorNetwork.wl`, 692 LOC)

`TensorNetwork`, `TensorNetworkQ`, `TensorNetworkData`, `TensorNetworkSize`, `TensorNetworkContractions`, `BinaryTensorNetwork`, `BinaryTensorNetworkQ`, `SparseTensorNetwork`, `RandomTensorNetwork`, `TensorNetworkAdd`, `TensorNetworkDelete`. (11 symbols.)

Constructor forms: `TensorNetwork[tensors, hyperedges, output]`, `TensorNetwork[arrays, in -> out]`, `TensorNetwork[hypergraph -> out, dims]` (Association or List), `TensorNetwork[Inactive[TensorContract][TensorProduct[ts], cs]]`, `TensorNetwork[Transpose[expr, perm_Cycles]]`, and `TensorNetwork[graph]`.

`RandomTensorNetwork` named topologies, with `"Boundary" -> "Open" | "Periodic"`: `"MPS"[L, χ, d]`, `"TT"[L, χ]`, `"MPO"[L, χ, d]`, `"PEPS"[{rows, cols}, χ, d]`, `"TTN"[depth, χ, branching]`, `"MERA"[width, χ, layers]`. Tensors come from `RandomReal` or `RandomComplex` via `Method -> "Complex"`.

Property dispatch on a valid `TensorNetwork`: `"Tensors"`, `"Hyperedges"`, `"FreeIndices"`, `"Dimensions"`, `"Indices"`, `"Size"`, `"IndexDimensions"`, `"Ranks"`, `"Graph"`, `"GraphData"`, `"Data"`, `"Contractions"`, `"OutputDimensions"`, `"OutputDimension"`, `"Hypergraph"` (via `WolframInstitute/Hypergraph` paclet), `"BinaryQ"`, `"SparseQ"`, and `"Properties"`.

Validation uses `System`Private`HoldValidQ` caching with loud `TensorNetwork::length`, `::shape`, `::dim`, `::output` messages on the failure path; the silent path is preserved only for symbolic tensors with `TensorDimensions[t] === {}`.

### 1.2 Contraction path optimization (`Kernel/Paths.wl` + `Kernel/TensorNetworks.wl`, 397 LOC)

Two Rust-backed optimizers, loaded via `ExtensionCargo`/`CargoLoad` from `Cotengra/` (see `PacletInfo.wl`):

| Function | Method | Options |
|---|---|---|
| `GreedyContractionPath` | thermal sampler | `"MemoryWeight"`, `"Temperature"`, `"MaxNeighbors"`, `"RandomSeed"`, `"PreSimplify"`, `"FixedIndexing"` |
| `OptimalContractionPath` | dynamic programming | `Method -> "size" \| "flops" \| "max" \| "write" \| "combo" \| "limit"`, `"PruningThreshold"`, `"AllowOuterProducts"`, `"PreSimplify"`, `"FixedIndexing"` |

Both accept `{inputs, output, sizeDict}`, a `TensorNetwork`, a `Graph` satisfying `TensorNetworkGraphQ`, an `Association` matching `{"Dimensions", "Indices", "Contractions"}`, or an `Inactive[TensorContract[TensorProduct[...], ...]]`. The wrappers canonicalize the returned path unless `"FixedIndexing" -> True` (Rust SSA mode).

Path algebra: `PathQ`, `TreePathQ`, `CanonicalPathQ`, `TreePathToPath`, `PathToTreePath`, `CanonicalPath`, `PathIndexContractions`, `ContractIndices`. `TensorNetworkFindContractionPath` is retained as a deprecated alias.

### 1.3 Contraction execution (`Kernel/Contraction.wl`, 318 LOC)

`TensorNetworkContraction` (symbolic `Inactive[...]` expression), `TensorNetworkContract` (activated numeric form), `ContractionTree`, `$TensorNetworkContractionMethods`. (4 symbols.)

`$TensorNetworkContractionMethods = {"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}`. Each backend is implemented as a separate `einsum*` helper in `Contraction.wl:29-201`; the public surface routes through `contractTensorPair`. Path arguments may be either `_CanonicalPathQ` lists or `_TreePathQ` trees, or any of the symbolic strings `"Greedy"`, `"Optimal"`, `"flops"`, `"max"`, `"size"`, `"write"`, `"combo"`, `"limit"`.

`ContractionTree` returns a `Tree` whose nodes carry either dimensions (`"Labels" -> "Dimensions"`) or full named `Inactive[ArrayDot]`/`Inactive[Dot]`/`Transpose`/`TensorContract`/`TensorProduct` expressions on `ArraySymbol`s.

### 1.4 Einstein summation (`Kernel/EinsteinSummation.wl`, 131 LOC)

`EinsteinSummation`, `IndexedMultiply`, `ActivateTensors`. (3 symbols.)

Three call forms: list `EinsteinSummation[{i, j, k} -> out, {As}]`, list-auto `EinsteinSummation[{i, j, k}, {As}]`, string `EinsteinSummation["ij,jk->ik", {A, B}]`. The implementation handles scalar factors, repeated indices that need outer broadcasting (delegated to `IndexedMultiply`), multiplicity scaling via `GeneralizedPower[TensorProduct, ...]`, and full output permutation. `ActivateTensors` activates `TensorProduct`, `TensorContract`, and `Transpose` while normalizing `SymbolicIdentityArray` and `SymbolicDeltaProductArray` to dense form.

### 1.5 MPS algorithms (`Kernel/MPS.wl`, 630 LOC)

`MPSCanonicalForm`, `MPSCanonicalQ`, `MPSOverlap`, `MPSNorm`, `MPSNormalize`, `MPSSchmidtValues`, `MPSEntanglementEntropy`, `MPSTruncate`. (8 symbols.)

`MPSCanonicalForm[mps, "Left" | "Right" | {"Mixed", k}]` performs SVD-based gauging with `"MaxBond"` and `"Tolerance"` options. Boundary and bulk tensors are handled with explicit reshapes. `MPSCanonicalQ` runs Frobenius isometry checks with default tolerance `10^-10`. `MPSOverlap` uses transfer-matrix contractions through `EinsteinSummation`/`ActivateTensors`. `MPSEntanglementEntropy` is natural-log von Neumann entropy. `MPSTruncate[mps, maxBond, "Normalize" -> True]` re-canonicalizes and renormalizes.

### 1.6 Graph representation (`Kernel/ToTensorNetworkGraph.wl`, 532 LOC)

`TensorNetworkGraphQ`, `ToTensorNetworkGraph`, `TensorNetworkIndexGraph`, `TensorNetworkIndices`, `TensorNetworkTensors`, `TensorNetworkGraphData`, `TensorNetworkIndexDimensions`, `TensorNetworkFreeIndices`, `TensorNetworkRemoveCycles`, `TensorNetworkToNetGraph`, `TensorNetworkReplaceIndices`, `InitializeTensorNetwork`, and graph-flavored `TensorNetworkAdd`/`TensorNetworkDelete`. (14 symbols.)

`ToTensorNetworkGraph` accepts a `TensorNetwork`, a `DirectedGraph`, an undirected `Graph`, or the raw `(tensors, hyperedges)` pair. Hyperedges with arity > 2 are converted to spider vertices carrying `SymbolicDeltaProductArray`. Output vertices are annotated with `"Tensor"` and `"Index"` (lists of `Superscript`/`Subscript` labels). `TensorNetworkRemoveCycles` inserts cup/cap identity pairs to expose an acyclic skeleton.

`TensorNetworkToNetGraph` is the bridge to the Wolfram neural net layer: it compiles a contraction path into a `NetGraph` of `NetArrayLayer` + `TransposeLayer` + `ReshapeLayer` + `DotLayer` blocks. Symbolic tensors with free symbols are wrapped in `FunctionLayer` ports.

### 1.7 Index algebra (`Kernel/IndexArray/`, 1 651 LOC across 8 files)

`Dimension`, `DimensionQ`, `Shape`, `ShapeQ`, `IndexArray`, `IndexArrayQ`, `IndexTensor`, `IndexTensorQ`, `MetricTensor`, `MetricTensorQ`, `IndexPart`, `IndexContract`, `IndexJuggling`, `ArrayDimensions`, `ArrayRank`, `ArraySymmetry`, `ArrayName`, `ArrayPart`, `ArrayTranspose`, `ArrayContract`, `SimplifyArray`, `ZeroArrayQ`. (22 symbols.)

`Dimension[d, name, indices, position]` is a signed-integer-keyed index slot (sign encodes upper/lower variance). `Shape[d_1, ..., d_n]` is an ordered sequence of `Dimension`s with rich property dispatch (`"Indices"`, `"FreeIndices"`, `"Dimensions"`, `"SignedDimensions"`, `"Rank"`, `"Size"`, `"Variance"`, `"Names"`).

`IndexArray[tensor, shape, parameters, assumptions, name]` carries the named-index metadata; it overloads `Normal`, `Dimensions`, `SquareMatrixQ`, `Inverse`, `Transpose`, `D`, `Times`, `Plus`, `Equal`. Indexing syntax: `ia[[positions]]` triggers `IndexPart`, `ia[names...]` triggers `IndexJuggling`. `IndexContract` performs metric-aware contraction across a list of `IndexArray` or `IndexTensor` objects.

`MetricTensor[name | name[params], coordinates, assumptions, name]` ships 20 named metrics:
- Flat: `"Euclidean"[d]`, `"Minkowski"[d]`.
- Black-hole vacuum: `"Schwarzschild"[M]`, `"IsotropicSchwarzschild"[M]`, three Eddington-Finkelstein variants, three Gullstrand-Painleve variants, `"KruskalSzekeres"[M]`.
- Rotating/charged: `"Kerr"[M, J]`, `"KerrNewman"[M, Q, J]`, `"ReissnerNordstrom"[M, Q]`.
- Cosmological: `"Godel"[ω]`, `"FLRW"[k, a]`.
- Parametric stencils: `"Symmetric"[d, g]`, `"Asymmetric"[d, g]`, `"SymmetricField"[d, g]`, `"AsymmetricField"[d, g]`.

Properties: `"MatrixRepresentation"`, `"InverseMetricTensor"`, `"Determinant"`, `"LineElement"`, `"VolumeForm"`, `"Signature"`, `"RiemannianQ"`, `"LorentzianQ"`, `"PseudoRiemannianQ"`, `"Eigenvalues"`, `"Eigenvectors"`, `"CoordinateOneForms"`, `"CovariantQ"`, `"ContravariantQ"`, `"MixedQ"`, plus their `"Reduced..."` `FullSimplify`d variants. `IndexTensor` exposes `"ChristoffelSymbol"` via the `Prop[it, "ChristoffelSymbol"] := ChristoffelSymbols[it]` hook.

### 1.8 Symmetry / Young tableaux (`Kernel/Symmetry/YoungTableaux.wl`, 331 LOC)

`YoungTableau`, `YoungTableauQ`, `PartitionQ`, `TransposePartition`, `TableauShape`, `TableauSize`, `TableauRows`, `TableauColumns`, `HookLength`, `HookLengths`, `HookFactor`, `TableauDimension`, `YoungSymmetrize`, `YoungProject`. (14 symbols.)

`TableauDimension` uses the Frobenius determinant form (`n! · HookFactor[par]`), which is O(r^3) in the number of rows and far faster than the naive hook-product on tall partitions. `YoungSymmetrize` applies row-stabilizer then column-stabilizer (unnormalized sums); `YoungProject` adds the `d/n!` normalization so `P^2 = P`.

### 1.9 Infrastructure

- **Rust backend.** `optimize_greedy` and `optimize_optimal` are loaded via `ExtensionCargo` (`CargoLoad`/`CargoBuild`) from the `Cotengra/` Cargo crate. Build is driven by `build.wl` / `ci_build.wl`.
- **PacletExtensions.** Auto-installs `ExternalEvaluate >= 38.0.1` and `PacletExtensions >= 40.0.0` on first load.
- **Hypergraph plotting.** Bridge to `WolframInstitute/Hypergraph` paclet via `PacletSymbol` for `Hypergraph` and `SimpleHypergraphPlot` (used in `"Hypergraph"` property and the summary box icon for binary networks).
- **Documentation.** 80 reference pages under `TensorNetworks/Documentation/English/ReferencePages/Symbols/`, 6 tutorials (`TensorNetworksOverview`, `BuildingTensorNetworks`, `ContractionPathsAndExecution`, `MPSAlgorithms`, `IndexArrayAndMetrics`, `YoungSymmetries`), and the master `Guides/TensorNetworks.nb`.
- **Tests.** `Tests/test_mps.wl`, `Tests/test_add_delete.wl`, `Tests/test_random_tensor_network.wl`, `Tests/test_setup.wl`, `Tests/run_doc_examples.wl`, `Tests/run_tests.wl`. `Tests/external_validation/` adds 156 passing oracle-fixture tests against quimb/cotengra/ITensor* under `paclet_primitives/`, `baselines/`, `paclet_fuzz/`, driven by `run_external_validation.wl`. Project-wide pass at audit time: **2256/2256** with 10 skip-missing entries for documented feature gaps.
- **Downstream consumer.** `Wolfram/QuantumFramework` v1.6.5 auto-installs this paclet at exactly v1.0.4 and consumes `TensorNetwork`, `TensorNetworkQ`, `TensorNetworkGraphQ`, `TensorNetworkContract`, `TensorNetworkIndices`, `TensorNetworkFreeIndices`, `GraphTensorNetwork` as de facto public API. See `Audit/TensorNetworks-Capabilities-Audit-and-Quantum-Roadmap.md` §1.12.

**Total exported kernel surface: 76 symbols.**

---

## Part 2. Competitor landscape

### 2.1 Numerical packages

Local clones live under `tn-external/numerical/` (see `reference_external_tn_packages` memory). Per-package catalogs in `Tests/external_validation/`:

| Package | Language | Strengths | Local catalog |
|---|---|---|---|
| quimb | Python | Arbitrary-geometry TN, MPS/PEPS/TTN, MPI/DASK/JAX, sampling | `quimb_examples.md` (142 entries) |
| cotengra | Python | Path-search heuristics (HyperOptimizer), slicing, ChainRulesCore-style autodiff through trees | `cotengra_examples.md` (67) |
| ITensors.jl | Julia | Tagged-index primitives, decomposition, gauge | `itensors_examples.md` (41) |
| ITensorMPS.jl | Julia | DMRG / DMRG-X / TDVP / OpSum / AutoMPO, symmetry sectors | `itensormps_examples.md` (134) |
| ITensorNetworks.jl | Julia | PEPS, general-graph TN, BP/cluster-update gauge | `itensornetworks_examples.md` (41) |
| TeNPy | Python | DMRG, TEBD, model construction, correlation functions | `tenpy_examples.md` (78) |
| Google TensorNetwork | Python | TF/JAX backends. **Archived 2021.** | n/a |
| cuTensorNet (cuQuantum) | C++/CUDA | GPU contraction, slicing | n/a |

### 2.2 Symbolic packages

Local clones live under `TN courses/External symbolic tensor/`; catalog in `EXAMPLES_CATALOG.md` and audit in `WL_PILLAR_AUDIT.md` (see `reference_external_symbolic_packages` memory):

| Package | Language | Focus | Cataloged entries |
|---|---|---|---|
| xAct (xCore/xPerm/xTensor/xCoba/xPert + xTras) | Wolfram Language | GR-grade symbolic tensor calculus, Butler-Portugal canonicalization | 24 |
| Cadabra2 | C++ + Python | Multi-term canonicalization (`meld`), Bianchi, Fierz, γ-traces | 26 (46 substantive .cnb) |
| DisCoPy | Python | String diagrams as morphisms in monoidal categories | 7 |
| PyZX | Python | ZX-calculus rewriting catalog | 4 |
| tensorgrad | Python | Penrose-diagram autodiff, Isserlis Gaussian | 7 |
| SymbolicTensors.jl | Julia | SymPy backend, GR flavor (stalled) | 7 |
| EinExprs.jl | Julia | Einsum-as-symbolic, contraction-path-as-tree | 7 |
| Redberry | Java/Groovy | Tensor CAS (dormant since 2013) | 9 |

### 2.3 Downstream consumer (`Wolfram/QuantumFramework` v1.6.5)

Not a competitor; an integration partner that is already shipped:
- `QuantumTensorNetwork[qco]`, `TensorNetworkQuantumCircuit[tn]` (round-trip).
- `QuantumCircuitHypergraph[qc]`, `QuantumTensorNetworkGraph[qco]`.
- `TensorNetworkCompile[qco]`, `TensorNetworkApply[qco, qs]` (default circuit execution method when `Method -> Automatic`).
- `ZXTensorNetwork[qc]`, `ZXTensorNetworkQuantumCircuit[net]` (ZX bridge via pyzx).
- First-class circuit properties: `qco["TensorNetwork"]`, `qco["TensorNetworkGraph"]`, `qco["Hypergraph"]`, `qco["ZXTensorNetwork"]`, `qco["TensorNetworkInfo"]`, `qco["TensorNetworkBasis"]`.

---

## Part 3. Where the paclet leads or lags

Verdicts use the same legend as `WL_PILLAR_AUDIT.md`: 🟢 covered, 🟡 partial (substrate but no headline API), 🔴 gap, ⚪ out of scope.

### 3.1 Differentiators (🟢, no equivalent in any external package)

| Capability | Paclet entry points | Why unique |
|---|---|---|
| Symbolic tensors propagate through contraction | `EinsteinSummation`, `Inactive[TensorContract]` + `ActivateTensors`, `TensorNetworkContraction`, `ArrayContract`, `SymbolicDeltaProductArray` | Every numerical competitor stores machine-precision arrays. Symbolic results then feed `Simplify`, `Series`, `Limit`, `Integrate`, `DSolve`, `Eigensystem`. |
| 20 built-in spacetime metrics | `MetricTensor["Schwarzschild" \| "Kerr" \| ...]` with `"LineElement"`, `"VolumeForm"`, `"Signature"` properties | xAct ships metric-construction machinery; no other package ships 20 pre-built metrics with property dispatch in one expression. |
| Covariant/contravariant index variance integrated with raise/lower | `Dimension`, `Shape`, `IndexArray`, `IndexTensor`, `IndexJuggling`, `IndexContract`, `MetricTensor`, signed index names | xAct does it; no other package. The paclet is the only WL implementation that pairs variance with a hyperedge-`TensorNetwork` object. |
| Young-symmetrizer projector with hook-length irrep dimensions | `YoungTableau`, `YoungSymmetrize`, `YoungProject`, `TableauDimension`, `HookFactor` (Frobenius determinant) | xAct's `SymManipulator` and Cadabra's `young_project_*` cover the slot half; neither ships an idempotent projector with `P^2 = P` normalization on dense arrays. |
| 5 swappable contraction backends | `$TensorNetworkContractionMethods` = `{"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}` | `"TableSum"` emits a literal `Table[Sum[Part[a,...] Part[b,...]]]`, which preserves symbolic structure other libraries collapse. |
| Hyperedge-native TN object with `BinaryTensorNetwork` reduction | `TensorNetwork[tensors, {{i, j, k, ...}, ...}]`, `BinaryTensorNetwork` (spider insertion via `SymbolicDeltaProductArray`) | quimb and ITensorNetworks use multi-tensor delta tensors; the paclet keeps the hyperedge as the primary representation and treats binarization as an explicit, inspectable transform. |
| Round-trip with the Wolfram neural net stack | `TensorNetworkToNetGraph` (compiles a path into `NetArrayLayer`/`TransposeLayer`/`ReshapeLayer`/`DotLayer`) | Quimb-on-JAX is close; no Python package compiles to the same kind of differentiable layer graph backed by Wolfram's `NetTrain`. |
| Pinned downstream quantum stack | `Wolfram/QuantumFramework` v1.6.5 already routes `qco["TensorNetwork"]`, `QuantumTensorNetwork[qco]`, `ZXTensorNetwork[qc]` through this paclet | Stabilizer simulation, named QECCs, bosonic CV, multi-formalism execution, symbolic Schrödinger/Lindblad (`QuantumEvolve`) are all reachable from the same circuit object. Documented in `Audit/Wolfram-TN-Six-Wedges-Demos.md` (see §5.2 below). |

### 3.2 Parity (🟢, externally matched but paclet-side present)

| Capability | Paclet | Closest competitor |
|---|---|---|
| Contraction path search | `OptimalContractionPath` (6 cost methods), `GreedyContractionPath` (temperature/seed) via Rust backend | cotengra `HyperOptimizer`, EinExprs.jl |
| MPS canonical forms (left/right/mixed) with SVD truncation | `MPSCanonicalForm`, `MPSCanonicalQ` | ITensorMPS.jl, TeNPy |
| MPS observables (overlap, norm, normalize, Schmidt, entropy, truncate) | `MPSOverlap`, `MPSNorm`, `MPSNormalize`, `MPSSchmidtValues`, `MPSEntanglementEntropy`, `MPSTruncate` | quimb, TeNPy, ITensorMPS.jl |
| Random TN constructors (MPS, TT, MPO, PEPS, TTN, MERA) | `RandomTensorNetwork[...]` with open/periodic boundary | quimb `qtn.MPS_rand_state`, `qtn.PEPS_rand_state`, etc. |
| Graph view of TN with index annotations | `ToTensorNetworkGraph`, `TensorNetworkIndexGraph`, `TensorNetworkGraphData`, `tn["Graph"]`, `tn["Hypergraph"]` | quimb `TensorNetwork.draw()`, ITensorNetworks.jl |
| Path-tree algebra | `PathToTreePath`, `TreePathToPath`, `CanonicalPath`, `PathIndexContractions`, `ContractionTree` | EinExprs.jl path-as-tree |

### 3.3 Gaps (🟡 or 🔴, prioritized)

Pulled from `Audit/TensorNetworks-Capabilities-Audit-and-Quantum-Roadmap.md` §3 and `WL_PILLAR_AUDIT.md`:

| Gap | Verdict | Closest external | Where it would live |
|---|---|---|---|
| DMRG / variational MPS ground state | 🔴 | ITensorMPS.jl, TeNPy | New `Kernel/DMRG.wl` |
| TEBD / TDVP (TN-native large-system dynamics) | 🔴 | quimb, TeNPy | New `Kernel/Dynamics.wl` |
| MPO application & compression | 🟡 (structure exists; no `MPOApply`) | ITensorMPS.jl | Extend `Kernel/MPS.wl` |
| Hamiltonian → MPO compiler (Çakır-Milbradt-Mendl 2025) | 🔴 | none externally | New `Kernel/HamiltonianMPO.wl` |
| Multi-term canonicalization (`meld` outer loop, Bianchi) | 🟡 | Cadabra `meld` | Extend `Kernel/Symmetry/` |
| Symbolic contraction-cost expressions in (d, χ, N) | 🟡 (engine present, surface not) | EinExprs.jl | Extend `Kernel/Paths.wl` |
| Slicing as a symbolic operation | 🟡 | cotengra, EinExprs.jl | Extend `Kernel/Paths.wl` |
| ZX rewrite catalog (spider fusion, π-copy, color change, bialgebra, etc.) | 🔴 | PyZX | New `Kernel/Diagrams/ZX.wl` (or extend QF bridge) |
| Haar / Weingarten integration | 🔴 | tensorgrad Isserlis | New `Kernel/Haar.wl` |
| iTEBD / infinite MPS | 🔴 | TeNPy, ITensorMPS.jl | New `Kernel/Infinite.wl` |
| PEPS boundary-MPS / corner-transfer matrix | 🔴 | ITensorNetworks.jl, quimb | New `Kernel/PEPS.wl` |
| Symmetry-preserving tensors (abelian / non-abelian QN) | 🔴 | ITensors.jl QN, TeNPy charges | Hook into `IndexArray`/`Shape` variance |
| Fermion (Grassmann) parity tracking | 🔴 | ITensorMPS.jl, TeNPy | New `Kernel/Fermions.wl` (QF only has bosonic CV) |

### 3.4 Known bugs and limitations carried over (from memory)

- `Netcon` C++ library hangs on hyperedge networks and on disconnected networks; `TimeConstrained` cannot interrupt LibraryLink. Avoid for those topologies; the Rust optimizers are safe.
- `SymbolicDeltaProductArray` is not numerically evaluable directly by `ArrayDot`. Workaround: `Normal[s_SymbolicDeltaProductArray]`. The `numericBinaryNetwork` helper in `Tests/test_netcon_audit.wl` wraps this.
- `OptimalContractionPath` defaults to `Method -> "size"`, not `"flops"`. Pass `Method -> "flops"` for FLOP-cost comparisons against Netcon and cotengra benchmarks.
- `RandomTensorNetwork["PEPS"...]` and `RandomTensorNetwork["TTN"...]` use `AppendTo` in `Do` loops, costing time on large grids; refactor to `Reap`/`Sow` or `Table` if those constructors become hot.

---

## Part 4. Validation strategy

### 4.1 Already in place

`Tests/external_validation/` is a working, audit-clean suite:

```
Tests/external_validation/
├── PLAN.md                          # live status, skip log
├── SKIPPED_AND_MISSING.md           # 10 documented skip-missing entries
├── EXAMPLES_CATALOG.md              # 503 numerical-package examples
├── external_oracles/                # quimb / cotengra / ITensor* JSON fixtures
│   ├── extract_quimb.py
│   ├── extract_cotengra.py
│   └── .venv/
├── paclet_primitives/               # Tier-1 + Tier-2 paclet primitive checks
├── baselines/                       # Cross-checks against oracle fixtures
└── paclet_fuzz/                     # Property-based sweeps
```

Driver: `wolframscript -file Tests/external_validation/run_external_validation.wl`. Audit-time status: **156/156** with 10 documented skips.

Project-wide test status at audit time (from `reference_external_validation_suite` memory):
- Main suite: 36/36.
- Doc examples: 2064/2064 across 81 pages (2 Netcon-hibernated pages skipped).
- External validation: 156/156.
- **Grand total: 2256/2256.**

### 4.2 What the rewrite adds

For each new feature in Part 5, add (in priority order):

1. A unit test under `Tests/` exercising the public surface in isolation.
2. A primitive-level oracle test under `Tests/external_validation/paclet_primitives/` matching results against the closest external (quimb / cotengra / ITensorMPS.jl / EinExprs.jl / Cadabra / PyZX).
3. A doc-example pair (`Documentation/English/ReferencePages/Symbols/<Symbol>.nb` + entry in `Tests/run_doc_examples.wl`).
4. An entry in `EXAMPLES_CATALOG.md` cross-referenced to the originating external example.

---

## Part 5. Phased enhancement plan

### Phase 1. Surface polish (no new physics)

| Task | Files | Effort |
|---|---|---|
| 1.1 Resurrect & dust off comparison notebook | `Notebooks/Tests and explorations/TN-vs-BuiltinWL-report.nb` already exists; add a sibling `LibraryComparison.nb` covering numerical and symbolic competitors | 1-2 days |
| 1.2 Refactor `RandomTensorNetwork["PEPS"...]` and `["TTN"...]` to avoid `AppendTo`/`Do` (use `Reap`/`Sow` or `Table`) | `Kernel/TensorNetwork.wl:509-578` | 0.5 day |
| 1.3 Re-export `numericBinaryNetwork` (or a renamed equivalent) so users do not have to keep the `Normal[s_SymbolicDeltaProductArray]` workaround in their notebooks | `Kernel/TensorNetwork.wl` | 0.5 day |
| 1.4 Audit and (where useful) make `OptimalContractionPath` default `Method` discoverable from the summary box / docs warnings; default stays `"size"` for back-compat | docs only | 0.5 day |
| 1.5 Tighten kernel `Quiet`/`Print` audit (per global CLAUDE.md rules) | grep `Quiet`/`Print` in `Kernel/` | 0.5 day |

### Phase 2. Path algebra: symbolic surface

Maps to `WL_PILLAR_AUDIT.md` Pillar 3 (🟡, "mostly an API-surfacing job"):

| Task | Closest external | Surface |
|---|---|---|
| 2.1 Cost expressions: `ContractionCost[tn, path, "Symbolic" -> True]` returning a polynomial in dim variables | EinExprs.jl `flops(SizedEinExpr)` | New helper in `Kernel/Paths.wl` |
| 2.2 Slicing: `SliceContraction[tn, indices]` symbolic sum over slice values | cotengra slicing | `Kernel/Paths.wl` |
| 2.3 Tree mutations: rotation, reorder, subtree reconfiguration on `ContractionTree` | cotengra `ContractionTree.subtree_reconfigure` | `Kernel/Paths.wl` |
| 2.4 `PathComparison[tn, {path1, path2, ...}]` returning cost-and-shape comparison `Dataset` | EinExprs.jl `Pluto` notebooks | New helper |

Tests: cross-check 2.1 against EinExprs.jl symbolic costs for MPS norm O(d^N) vs O(N d χ³); 2.2 against cotengra slicing examples in `cotengra/examples/`.

### Phase 3. MPS / MPO algorithm extensions

Maps to `Audit/...Roadmap.md` §3.1 HIGH-priority entries.

| Task | Maps to | Surface |
|---|---|---|
| 3.1 `MPOApply[mpo, mps]` with bond-dimension control | ITensorMPS.jl `applyMPO`, TeNPy `apply_mpo` | `Kernel/MPS.wl` |
| 3.2 `ExpectationValue[mps, mpo]` (transfer-matrix path) | quimb `psi.H @ mpo @ psi`, ITensorMPS.jl `inner` | `Kernel/MPS.wl` |
| 3.3 `RenyiEntropy[mps, site, α]` (general α, currently only α=1 in TN paclet; QF has it for `QuantumState`) | QF `QuantumEntanglementMonotone` | `Kernel/MPS.wl` |
| 3.4 `MutualInformation[mps, regionA, regionB]` (currently in QF; lift to MPS-native efficient form) | QF `MutualInformationI` | `Kernel/MPS.wl` |
| 3.5 Two-site DMRG sweep (`Method -> "DMRG"` on a future `GroundState` API) | ITensorMPS.jl `dmrg`, TeNPy `engine.run` | New `Kernel/DMRG.wl` |
| 3.6 `TEBDStep[mps, gates, dt]` (Suzuki-Trotter, real and imaginary time) | quimb `tebd`, TeNPy `tebd_engine` | New `Kernel/Dynamics.wl` |

### Phase 4. Symbolic-TN pillars (from `Symbolic_TN_feature_pillars.md`)

| Pillar | Verdict | New surface |
|---|---|---|
| Pillar 1: Hamiltonian → optimal MPO/TTNO | 🟡 (centerpiece, zero external coverage) | `SymbolicHamiltonianMPO[H]`, 6 worked examples (TFIM, Heisenberg, AKLT parent, long-range XY, ΣZᵢ, TTNO chemistry) |
| Pillar 2: Multi-term canonicalization | 🟡 | `MeldCanonicalize[expr, declarations]`, `CanonicalTensorNetwork[tn]`, `TensorNetworkEqualQ[tn1, tn2]`, 3 worked identities (First Bianchi, Riemann polynomial, Wick on small fermionic product) |
| Pillar 3: Path algebra | 🟡 | Already covered in Phase 2 above |
| Pillar 4: Diagram rewrite (ZX) | 🔴 | `ZXRewrite[net, "SpiderFusion" \| "PiCopy" \| "ColorChange" \| "Bialgebra" \| "Pivot" \| "LocalComplementation"]`. Surface choice: (a) extend QF's existing `ZXTensorNetwork` bridge, (b) ship a paclet-native ZX layer in `Kernel/Diagrams/ZX.wl`. Recommendation: (a) for v1.x, (b) for a v2.0 cut. |
| Pillar 5: Haar / Weingarten | 🔴 | `HaarMoment[k, d]`, `Weingarten[π, d]`, `IsserlisContract[expr]`, 4 worked examples (random PEPS contraction average, OTOC bound, scrambling rate, decoupling). Substrate ready: `SymmetricGroupCharacters`, exact rationals, RTNI-Mathematica heritage. |

### Phase 5. Visualization (do not over-build)

Most of what the previous draft proposed already exists:

| Function | Status |
|---|---|
| `ToTensorNetworkGraph`, `TensorNetworkIndexGraph` | ✅ shipped |
| `tn["Graph"]`, `tn["Hypergraph"]` summary boxes | ✅ shipped |
| `ContractionTree` (with dimension or operation labels) | ✅ shipped |
| `TensorNetworkToNetGraph` (NetGraph render) | ✅ shipped |
| `YoungTableau` icon | ✅ shipped |
| `MetricTensor` icon (MatrixPlot, signature, line element) | ✅ shipped |
| `IndexArray` icon (signed dimensions, view) | ✅ shipped |

What is genuinely missing (and would land as a single `Kernel/Visualization/` subpackage if pursued):

1. **Tree layouts** matching cotengra's `tent` / `ring` / `circuit` / `rubberband` / `flat`. `ContractionTree` already returns a `Tree`; the work is `TreeLayout` rules and a thin `ContractionTreePlot` wrapper.
2. **Cost-profile plot** (peak memory, cumulative FLOPs, write size per step). Hook on `PathIndexContractions` + symbolic cost from Phase 2.
3. **Optimizer trial scatter** (`HyperOptimizer.plot_trials` analog). Needs `GreedyContractionPath` / `OptimalContractionPath` to optionally return trial history; today they only return the chosen path.
4. **Penrose / ZX diagram render** that goes beyond the hypergraph fallback. Wedded to Phase 4 Pillar 4.

Defer (1) and (2) until at least one of Phase 3 (MPO algorithms) or Phase 4 (Pillar 1 H → MPO) ships, so the visualizations have non-toy networks to plot.

### Phase 6. Export / interoperability

| Task | Notes |
|---|---|
| 6.1 `ExportTensorNetwork[tn, "Quimb"]` | Round-trip through quimb's `qtn.Tensor`/`TensorNetwork` JSON serialization. |
| 6.2 `ExportTensorNetwork[tn, "ITensor"]` | Tagged-index dump for ITensors.jl. |
| 6.3 `ExportTensorNetwork[tn, "TikZ"]` / `"PGFPlots"` | LaTeX figure source from `ToTensorNetworkGraph`. |
| 6.4 `ImportTensorNetwork["...", "Quimb" \| "ITensor"]` | The inverse direction. Useful for the oracle suite. |

---

## Part 6. Documentation and notebook deliverables

Existing notebooks under `TensorNetworks/Documentation/English/Tutorials/`:

- `TensorNetworksOverview.nb`
- `BuildingTensorNetworks.nb`
- `ContractionPathsAndExecution.nb`
- `MPSAlgorithms.nb`
- `IndexArrayAndMetrics.nb`
- `YoungSymmetries.nb`

What this plan adds (mapped to phases):

| Notebook | Phase | Purpose |
|---|---|---|
| `Notebooks/Tests and explorations/LibraryComparison.nb` | 1 | Side-by-side: same problem, paclet vs quimb, cotengra, ITensorMPS.jl, EinExprs.jl. Driven by `external_oracles` fixtures. |
| `Documentation/English/Tutorials/SymbolicComputation.nb` | 1 | Closed-form Schmidt, transfer-matrix eigenvalues, parametric entropies. Source for §3.1 wedge 1. |
| `Documentation/English/Tutorials/MPOAndDynamics.nb` | 3 | Once Phase 3 ships: `MPOApply`, `ExpectationValue`, `TEBDStep`. |
| `Documentation/English/Tutorials/HamiltonianToMPO.nb` | 4 (Pillar 1) | The headline symbolic-TN deliverable. |
| `Documentation/English/Tutorials/Canonicalization.nb` | 4 (Pillar 2) | First Bianchi, Riemann polynomial identity, Wick on small fermionic product. |
| `Documentation/English/Tutorials/ZXRewrites.nb` | 4 (Pillar 4) | If we extend the QF bridge: AKLT, GHZ, cluster state. |
| `Documentation/English/Tutorials/HaarIntegration.nb` | 4 (Pillar 5) | Isserlis, Weingarten, random-PEPS averages. |

Do **not** create the `Documentation/MathematicaAdvantages.nb` / `MigrationFromPython.nb` / `PhysicsApplications.nb` notebooks the earlier draft proposed. Their content is better folded into the audit document `Audit/Wolfram-TN-Six-Wedges-Demos.md` and the existing tutorials.

---

## Part 7. Positioning (one-screen summary)

| Use case | Recommendation |
|---|---|
| Closed-form / parametric results | **`Wolfram/TensorNetworks` is the only option.** |
| GR-style tensor algebra (covariance, metric, Christoffel) | `Wolfram/TensorNetworks` + xAct. Paclet wins on "20 metrics in one expression"; xAct wins on Butler-Portugal canonicalization. |
| Young symmetrization / irrep projection | **`Wolfram/TensorNetworks`** (`YoungProject` is normalized; xAct/Cadabra ship the unnormalized symmetrizer). |
| Hyperedge / symbolic-spider TN with `SymbolicDeltaProductArray` | **`Wolfram/TensorNetworks`** (quimb has hyperedges; only paclet keeps them inspectable). |
| Quantum-circuit ↔ TN ↔ ZX round-trip in one kernel | **`Wolfram/QuantumFramework` + this paclet** (six wedges in `Audit/Wolfram-TN-Six-Wedges-Demos.md`). |
| DMRG ground state, large iDMRG / iTEBD | ITensorMPS.jl or TeNPy until Phase 3.5/3.6 lands. |
| Path search for 100+ tensor networks | quimb + cotengra, or this paclet's Rust `OptimalContractionPath` (parity, with the `Method -> "size"` caveat). |
| GPU contraction | cuTensorNet (no equivalent here yet). |
| Production ML pipelines | Export via Phase 6, then run in PyTorch / JAX. |

---

## Part 8. References

Audit and source documents inside the repository:

- `Audit/TensorNetworks-Capabilities-Audit-and-Quantum-Roadmap.md` (rev 2, 2026-04-26): definitive capability + roadmap with QF cross-check.
- `Audit/Wolfram-vs-Numeric-TN-Assessment-2026-04-26.md`: six unique wedges, mapped to a real graduate TN syllabus.
- `Audit/Wolfram-TN-Six-Wedges-Demos.md`: runnable demonstrations of those wedges.
- `Audit/Decision-Diagram-Integration-Plan-2026-05-22.md`: DD integration plan.
- `TN courses/A course on symbolic Tensor Networks/Symbolic_TN_feature_pillars.md`: the 5-pillar symbolic-TN framework.
- `TN courses/External symbolic tensor/EXAMPLES_CATALOG.md`: 150 cataloged symbolic-tensor examples.
- `TN courses/External symbolic tensor/WL_PILLAR_AUDIT.md`: per-pillar audit of this paclet vs the symbolic corpus.
- `Tests/external_validation/EXAMPLES_CATALOG.md`: 503 numerical examples.
- `Tests/external_validation/PLAN.md`: live test-suite status.
- `TensorNetworks/PacletInfo.wl`: version, dependency, Cargo build wiring.

External documentation (no in-repo copy):

- Cotengra (`https://cotengra.readthedocs.io/`).
- Quimb (`https://github.com/jcmgray/quimb`).
- ITensor / ITensorMPS / ITensorNetworks (`https://itensor.org/`).
- TeNPy (`https://github.com/tenpy/tenpy`).
- EinExprs.jl (`https://github.com/bsc-quantic/EinExprs.jl`).
- PyZX (`https://github.com/Quantomatic/pyzx`).
- DisCoPy (`https://github.com/discopy/discopy`).
- tensorgrad (`https://github.com/thomasahle/tensorgrad`).
- xAct (`http://www.xact.es/`).
- Cadabra2 (`https://github.com/kpeeters/cadabra2`).
- NVIDIA cuQuantum / cuTensorNet (`https://developer.nvidia.com/cuquantum-sdk`).
- Wolfram symbolic tensors guide (`https://reference.wolfram.com/language/guide/SymbolicTensors.html`).
- Tensor network software list (`https://tensornetwork.org/software/`).

---

## Part 9. Verification checklist for this plan

Before any phase ships:

1. Every new public symbol has a `.nb` reference page under `Documentation/English/ReferencePages/Symbols/` and is exercised by `Tests/run_doc_examples.wl`.
2. The pipe through `wolframscript -file Tests/run_tests.wl` stays green.
3. `wolframscript -file Tests/external_validation/run_external_validation.wl` stays at 156+ passing (no regressions; new tests added for each new feature).
4. `Wolfram/QuantumFramework` v1.6.5's `QuantumTensorNetwork[qco]`, `TensorNetworkApply[qco, qs]`, `ZXTensorNetwork[qc]` still work end-to-end. The QF-consumed symbols (§1.9) are renamed only with a signed-off deprecation cycle.
5. `EXAMPLES_CATALOG.md` (numerical and symbolic) is updated when the new feature has an external counterpart.
6. `Notebooks/Tests and explorations/LibraryComparison.nb` runs end-to-end on the host machine.

---

*This document is plan-only. Implementation lives in `Kernel/` and is tracked through `Tests/`. For day-to-day "what does this symbol do" questions, prefer the reference pages or the tutorials over this document.*
