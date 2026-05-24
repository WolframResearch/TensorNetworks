# TensorNetworks Package Comparison & Enhancement Plan

## Executive Summary

This plan outlines a comprehensive comparison between the Wolfram Mathematica TensorNetworks package and major competing tensor network libraries, identifying unique advantages and proposing enhancements to showcase Mathematica's strengths.

---

## Part 1: Competing Libraries Overview

### Primary Competitors

| Library | Language | Focus | Status |
|---------|----------|-------|--------|
| **Cotengra** | Python | Contraction path optimization | Active (v0.7.5, June 2025) |
| **Quimb** | Python | Quantum info & arbitrary geometry | Active, MPI/DASK/JAX support |
| **ITensor** | Julia | DMRG & quantum number conservation | Active (v0.9, March 2025) |
| **TeNPy** | Python | DMRG algorithms | Active, similar perf to ITensor |
| **Google TensorNetwork** | Python | ML/TensorFlow integration | Stale (last update 2021) |
| **cuTensorNet** | CUDA | GPU-accelerated contractions | Active, NVIDIA ecosystem |

---

## Part 2: Feature Comparison Matrix

### 2.1 This Package's Core Functions

| Category | Functions | Unique to Mathematica? |
|----------|-----------|----------------------|
| **Core** | `TensorNetwork`, `TensorNetworkContract` | Hyperedge-based representation |
| **Path Optimization** | `GreedyContractionPath`, `OptimalContractionPath` | Rust-integrated, 6 cost methods |
| **Contraction** | 5 methods: ArrayDot, ArrayDotTranspose, TensorContract, Dot, TableSum | **Yes** - TableSum for symbolic |
| **MPS** | `MPSCanonicalForm`, `MPSEntanglementEntropy`, `MPSSchmidtValues`, `MPSTruncate` | Full canonical forms |
| **Symmetry** | `YoungTableau`, `YoungSymmetrize`, `YoungProject` | **Yes** - No competitor has this |
| **Index Algebra** | `IndexArray`, `IndexJuggling`, `IndexContract` | **Yes** - Covariant/contravariant |
| **Einstein** | `EinsteinSummation`, `IndexedMultiply` | Both string and list notation |
| **Networks** | `RandomTensorNetwork` (MPS, TT, MPO, PEPS, TTN, MERA) | All standard architectures |
| **Graphs** | `ToTensorNetworkGraph`, `TensorNetworkIndexGraph` | Bidirectional conversion |

### 2.2 Comparison with Competitors

| Feature | Mathematica | Cotengra | Quimb | ITensor | cuTensorNet |
|---------|-------------|----------|-------|---------|-------------|
| **Symbolic tensors** | **YES** | No | No | No | No |
| **Young tableaux** | **YES** | No | No | No | No |
| **Covariant/contravariant** | **YES** | No | No | No | No |
| **Multiple contraction methods** | **5** | 1 | 1 | 1 | 1 |
| **Path optimization** | Greedy+Optimal | HyperOptimizer | Via Cotengra | Basic | Sliced |
| **MPS canonicalization** | Full | No | Yes | **Best** | No |
| **DMRG ground state** | No | No | Yes | **Best** | No |
| **GPU acceleration** | No | Via backend | JAX | Limited | **Best** |
| **Visualization** | **Native** | Limited | Jupyter | CLI | No |
| **Notebooks** | **Native** | Jupyter | Jupyter | No | No |

---

## Part 3: Unique Advantages of Mathematica Approach

### 3.1 Symbolic Computation (NO COMPETITOR HAS THIS)

**What it enables:**
- Exact algebraic results instead of floating-point approximations
- Parametric tensor analysis with symbolic parameters
- Lazy evaluation via `Inactive[TensorContract]`
- Algebraic simplification of tensor expressions

**Key files:** `Kernel/EinsteinSummation.wl`, `Kernel/Utilities.wl`

### 3.2 Young Tableaux Symmetries (ONLY THIS PACKAGE)

**What it enables:**
- `YoungSymmetrize[tensor, YoungTableau[{3,2}]]` - Apply arbitrary symmetry
- `YoungProject[tensor, tableau]` - Normalized projectors for irreps
- `TableauDimension` - Hook length formula for representation dimensions
- Decompose tensors by symmetry type

**Key file:** `Kernel/Symmetry/YoungTableaux.wl`

### 3.3 Covariant/Contravariant Index Algebra (ONLY THIS PACKAGE)

**What it enables:**
- Proper differential geometry-style tensor calculus
- `IndexJuggling` - Automatic index raising/lowering with metrics
- `IndexContract` - Automatic metric tensor insertion
- `Dimension` objects with sign, name, and dimension attributes

**Key file:** `Kernel/IndexArray/IndexJuggling.wl`

### 3.4 Multiple Contraction Methods (5 vs 1 in competitors)

**Methods:**
1. `"ArrayDot"` - Mathematica's optimized array operations
2. `"ArrayDotTranspose"` - Pre-transposed for cache efficiency
3. `"TensorContract"` - Standard tensor contraction
4. `"Dot"` - Matrix multiplication with reshaping
5. `"TableSum"` - Explicit summation for symbolic work

**Key file:** `Kernel/Contraction.wl`

### 3.5 Integrated Environment

- Native notebook interface with interactive graphics
- `ToTensorNetworkGraph` produces Mathematica `Graph` objects
- ContractionTree visualization with dimension annotations
- Seamless export to PDF, LaTeX, images

---

## Part 4: Implementation Plan (Phased)

### Phase 1: Documentation & Comparison Materials

#### Task 1.1: Create Comparison Notebook
**File:** `Documentation/LibraryComparison.nb`

**Sections:**
1. Introduction - Why Mathematica for tensor networks
2. Feature Matrix - Visual comparison table
3. Symbolic Computation Demo - Show exact vs approximate results
4. Young Tableaux Demo - Symmetry operations unavailable elsewhere
5. Index Algebra Demo - Covariant/contravariant operations
6. Performance Benchmarks - Where Mathematica excels

#### Task 1.2: Create "Mathematica Advantages" Tutorial
**File:** `Documentation/MathematicaAdvantages.nb`

**Content:**
```mathematica
(* 1. Symbolic parametric analysis *)
T = Array[Subscript[t, ##] &, {n, n}];
symbolicEigenvalues = Eigenvalues[T]  (* Exact formula! *)

(* 2. Young tableaux - UNIQUE feature *)
tensor = RandomReal[{-1,1}, {4,4,4}];
symmetric = YoungProject[tensor, YoungTableau[{3}]];
antisymmetric = YoungProject[tensor, YoungTableau[{1,1,1}]];
mixedSymmetry = YoungProject[tensor, YoungTableau[{2,1}]];

(* 3. Index juggling with metrics *)
metric = IndexArray[DiagonalMatrix[{1,1,1,-1}], Shape[{-μ, -ν}]];
vector = IndexArray[{E, px, py, pz}, Shape[{μ}]];
covector = IndexJuggling[IndexTensor[vector, metric], {-μ}]
```

#### Task 1.3: Create Migration Guide
**File:** `Documentation/MigrationFromPython.nb`

**Translations:**

| Python (Quimb/NumPy) | Mathematica |
|---------------------|-------------|
| `np.einsum('ij,jk->ik', A, B)` | `EinsteinSummation["ij,jk->ik", {A, B}]` |
| `tn.contract(...)` | `TensorNetworkContract[tn]` |
| `qtn.MPS_rand_state(L, bond)` | `RandomTensorNetwork["MPS"[L, bond, 2]]` |

---

### Phase 2: Benchmark Suite

#### Task 2.1: Create Benchmark Framework
**File:** `Tests/benchmark_comparison.wl`

**Benchmarks:**
1. Path Optimization Speed - Compare with Cotengra
2. Contraction Execution - Compare 5 methods
3. MPS Operations - Compare with ITensor-style operations
4. Symbolic vs Numerical - Unique to Mathematica

#### Task 2.2: Standard Test Networks
```mathematica
benchmarkNetworks = <|
    "SmallMPS" -> RandomTensorNetwork["MPS"[10, 16, 2]],
    "LargeMPS" -> RandomTensorNetwork["MPS"[50, 64, 2]],
    "SmallPEPS" -> RandomTensorNetwork["PEPS"[{3,3}, 4, 2]],
    "LargePEPS" -> RandomTensorNetwork["PEPS"[{5,5}, 8, 2]],
    "SmallMERA" -> RandomTensorNetwork["MERA"[8, 4, 2]],
    "LargeMERA" -> RandomTensorNetwork["MERA"[16, 8, 3]]
|>;
```

---

### Phase 3: Showcase Unique Capabilities

#### Task 3.1: Symbolic Tensor Networks Example
**File:** `Documentation/SymbolicTensorNetworks.nb`

**Demonstrations:**
- Parametric entanglement entropy formulas
- Exact MPS overlap calculations
- Symbolic contraction path analysis
- Algebraic tensor decompositions

#### Task 3.2: Physics Applications
**File:** `Documentation/PhysicsApplications.nb`

**Use Cases:**
1. **Quantum Chemistry** - Two-electron integrals with 8-fold symmetry
2. **General Relativity** - Riemann tensor with Young tableaux symmetry
3. **Particle Physics** - Lorentz covariant/contravariant indices

#### Task 3.3: Index Algebra Tutorial
**File:** `Documentation/IndexAlgebraAndMetrics.nb`

**Content:**
- Creating `IndexArray` with variance information
- Metric tensor operations
- Automatic index raising/lowering
- Contraction with mixed index types

---

### Phase 4: Feature Enhancements

#### Task 4.1: Add Symbolic MPS Operations
Extend MPS functions to work with symbolic tensors:
```mathematica
(* Symbolic MPS *)
symbolicMPS = Table[Array[Subscript[a, i, ##] &, {chi, d, chi}], {i, L}];
MPSEntanglementEntropy[symbolicMPS, site]  (* Returns exact formula *)
```

#### Task 4.2: Enhanced Visualization
Add comparison visualizations:
```mathematica
ContractionPathComparison[network, {"Greedy", "Optimal"}]
(* Side-by-side contraction tree comparison *)
```

#### Task 4.3: Export to Other Formats
```mathematica
ExportTensorNetwork[network, "ONNX"]  (* For ML frameworks *)
ExportTensorNetwork[network, "Quimb"]  (* Python interop *)
```

---

### Phase 5: Future Roadmap (Optional)

**Consider adding (based on competitor analysis):**

| Feature | Priority | Rationale |
|---------|----------|-----------|
| DMRG Ground State | High | ITensor's main advantage |
| GPU Backend | Medium | cuTensorNet integration |
| HyperOptimizer | Low | Cotengra's advanced search |
| Distributed | Low | Quimb's MPI/DASK support |

---

## Part 5: Key Messages for Marketing

### "Only in Mathematica" Features

1. **Symbolic Computation** - "Get exact algebraic results, not floating-point approximations"
2. **Young Tableaux** - "The only tensor network library with full group-theoretic symmetry support"
3. **Index Algebra** - "Proper differential geometry with covariant/contravariant indices"
4. **5 Contraction Methods** - "Choose the optimal method for your problem"
5. **Integrated Environment** - "From theory to visualization in one system"

### Recommended Positioning

| Use Case | Recommendation |
|----------|---------------|
| Exact symbolic results | **Mathematica (only option)** |
| Tensor symmetries | **Mathematica (only option)** |
| Rapid prototyping | **Mathematica** |
| Visualization | **Mathematica** |
| DMRG ground states | ITensor/TeNPy |
| GPU acceleration | cuTensorNet |
| Production ML | Export to PyTorch |

---

## Part 6: Files to Create/Modify

### New Documentation Files
1. `Documentation/LibraryComparison.nb`
2. `Documentation/MathematicaAdvantages.nb`
3. `Documentation/MigrationFromPython.nb`
4. `Documentation/SymbolicTensorNetworks.nb`
5. `Documentation/PhysicsApplications.nb`
6. `Documentation/IndexAlgebraAndMetrics.nb`
7. `Documentation/VisualizationGuide.nb` ← NEW

### New Visualization Files
1. `Kernel/Visualization/TensorDiagram.wl` - Penrose notation diagrams
2. `Kernel/Visualization/MPSVisualization.wl` - MPS/MPO chain diagrams
3. `Kernel/Visualization/ContractionPlots.wl` - Tree plots, cost analysis
4. `Kernel/Visualization/PathComparison.wl` - Multi-path comparison
5. `Kernel/Visualization/Interactive.wl` - Explorer, animator
6. `Kernel/Visualization/OptimizerPlots.wl` - Optimization progress
7. `Kernel/Visualization/Export.wl` - PDF, SVG, TikZ export

### New Test Files
1. `Tests/benchmark_comparison.wl`
2. `Tests/test_visualization.wl` ← NEW

### Key Existing Files (Reference)
- `Kernel/TensorNetwork.wl` - Core object
- `Kernel/Contraction.wl` - 5 methods
- `Kernel/ToTensorNetworkGraph.wl` - Existing graph visualization
- `Kernel/Symmetry/YoungTableaux.wl` - Unique symmetry
- `Kernel/IndexArray/IndexJuggling.wl` - Unique index algebra
- `Kernel/MPS.wl` - MPS algorithms

---

## Verification Plan

1. **Documentation Review** - Ensure all notebooks render correctly
2. **Benchmark Validation** - Run benchmarks on standard hardware
3. **Code Examples** - Verify all example code executes correctly
4. **Comparison Accuracy** - Cross-check feature claims against library docs

---

## Part 7: Comprehensive Visualization Plan

### 7.1 Current Visualization Capabilities

| Function | What It Does | Status |
|----------|--------------|--------|
| `ToTensorNetworkGraph` | Converts TensorNetwork to Graph object | ✅ Working |
| `TensorNetworkIndexGraph` | Shows index connectivity between tensors | ✅ Working |
| `TensorNetworkToNetGraph` | Converts to Neural NetGraph | ✅ Working |
| `ContractionTree` | Tree structure of contraction hierarchy | ✅ Basic |
| `TensorNetwork` MakeBoxes | Summary box with mini hypergraph | ✅ Working |
| `tn["Graph"]` | Quick access to graph visualization | ✅ Working |
| `tn["Hypergraph"]` | Hypergraph visualization (via external paclet) | ✅ Working |

### 7.2 Visualization Comparison with Competitors

| Visualization Type | Mathematica | Cotengra | Quimb | ITensor |
|-------------------|-------------|----------|-------|---------|
| **Network Graph** | ✅ Native Graph | ✅ HyperGraph.plot() | ✅ .draw() | ❌ ASCII only |
| **Contraction Tree** | ✅ Basic Tree | ✅ Multiple layouts | ✅ Via Cotengra | ❌ None |
| **Cost Analysis** | ❌ Missing | ✅ plot_contractions() | ✅ Via Cotengra | ❌ None |
| **Optimizer Progress** | ❌ Missing | ✅ plot_trials() | ❌ None | ❌ None |
| **MPS/MPO Diagrams** | ❌ Missing | ❌ None | ✅ .draw() | ❌ ASCII only |
| **Interactive** | ⚠️ Limited | ❌ Static | ❌ Static | ❌ None |
| **Publication Export** | ✅ PDF/SVG/LaTeX | ⚠️ matplotlib | ⚠️ matplotlib | ❌ None |
| **Penrose Notation** | ❌ Missing | ❌ None | ❌ None | ❌ None |

### 7.3 Cotengra Visualization Functions (Reference)

Cotengra provides these visualization functions we should match or exceed:

**1. HyperGraph.plot()** - Network geometry visualization
- Shows hyperedges as zero-size vertices
- 5 index types: standard inner, multi-indices, outer, hyper inner, hyper outer
- Color-coded nodes and indices

**2. ContractionTree.plot_flat()** - Complete tree for small networks
- All indices at each intermediate step
- Bottom-to-top contraction flow

**3. ContractionTree.plot_tent()** - "Most general purpose" layout
- Input network at bottom, intermediates above
- Edge width/color = intermediate tensor widths
- Node size/color = FLOPs per contraction

**4. ContractionTree.plot_circuit()** - Operation order emphasis

**5. ContractionTree.plot_ring()** - Ring layout for planar graphs
- Good for inspecting contraction "spines"

**6. ContractionTree.plot_rubberband()** - Hierarchical grouping

**7. ContractionTree.plot_contractions()** - Cost analysis
- Peak memory, write size, scalar operations per step

**8. HyperOptimizer.plot_trials()** - Optimization progress
- Score improvement across trials
- Supports time-based x-axis

**9. HyperOptimizer.plot_scatter()** - Cost vs width distribution

**10. HyperOptimizer.plot_parameters_parallel()** - Parameter distributions

### 7.4 Proposed New Visualization Functions

#### Category A: Penrose/Diagrammatic Notation (UNIQUE TO MATHEMATICA)

**A1. TensorNetworkDiagram** - Publication-quality Penrose notation
```mathematica
TensorNetworkDiagram[tn, opts]
(* Options:
   - "Style" -> "Penrose" | "Box" | "Circle"
   - "IndexLabels" -> True | False | Automatic
   - "IndexColors" -> Automatic | ColorFunction
   - "TensorLabels" -> True | False
   - "SymmetryIndicators" -> True  (* Show symmetrization bars *)
*)
```

**A2. ContractionDiagram** - Step-by-step diagrammatic equations
```mathematica
ContractionDiagram[tn, path, step]
(* Shows: before → contraction → after as diagram equation *)
```

**A3. IndexTypeDiagram** - Distinguish index types visually
```mathematica
(* Physical indices: solid lines
   Bond indices: dashed lines
   Contracted indices: connected
   Free indices: dangling *)
```

#### Category B: Contraction Analysis (Match Cotengra)

**B1. ContractionCostPlot** - Memory and FLOP analysis
```mathematica
ContractionCostPlot[tn, path]
(* Shows:
   - Peak memory at each step
   - Cumulative FLOPs
   - Write size per contraction
   - Interactive: click step to highlight in tree *)
```

**B2. ContractionTreePlot** - Multiple layout options
```mathematica
ContractionTreePlot[tn, path,
  "Layout" -> "Tent" | "Ring" | "Circuit" | "Rubberband" | "Flat"
]
(* Options:
   - "EdgeWeights" -> "Dimensions" | "FLOPs" | "Memory"
   - "NodeWeights" -> "FLOPs" | "Size"
   - "ColorFunction" -> colorFunc
   - "Labels" -> "Dimensions" | "Operations" | None
*)
```

**B3. PathComparisonPlot** - Compare multiple contraction paths
```mathematica
PathComparisonPlot[tn, {path1, path2, ...}]
(* Side-by-side or overlay comparison of:
   - Total cost
   - Memory profile
   - Tree structure *)
```

#### Category C: Optimizer Visualization (Match Cotengra)

**C1. OptimizationProgressPlot** - Trial progress
```mathematica
OptimizationProgressPlot[optimizerResults]
(* Options:
   - "Metric" -> "Score" | "FLOPs" | "Memory"
   - "XAxis" -> "Trial" | "Time"
   - "ShowBest" -> True *)
```

**C2. OptimizationScatterPlot** - Cost vs size distribution
```mathematica
OptimizationScatterPlot[optimizerResults]
(* X: contraction width/size, Y: FLOPs *)
```

#### Category D: MPS/MPO Visualization (UNIQUE STRENGTH)

**D1. MPSDiagram** - Chain visualization
```mathematica
MPSDiagram[mps]
(* Options:
   - "ShowBondDimensions" -> True
   - "ShowPhysicalDimensions" -> True
   - "CanonicalForm" -> "Left" | "Right" | "Mixed"[k]
   - "HighlightSite" -> k
   - "ColorByEntanglement" -> True *)
```

**D2. MPODiagram** - Operator chain visualization
```mathematica
MPODiagram[mpo]
(* Shows upper and lower physical indices *)
```

**D3. EntanglementProfile** - Entanglement across bonds
```mathematica
EntanglementProfile[mps]
(* Plot of entanglement entropy vs bond position *)
```

**D4. SchmidtSpectrumPlot** - Schmidt values at each bond
```mathematica
SchmidtSpectrumPlot[mps, bond]
(* Bar chart or line plot of Schmidt coefficients *)
```

**D5. BondDimensionPlot** - Bond dimensions across chain
```mathematica
BondDimensionPlot[mps]
(* Shows bond dimension profile *)
```

#### Category E: Interactive Visualization (MATHEMATICA ADVANTAGE)

**E1. TensorNetworkExplorer** - Interactive manipulation
```mathematica
TensorNetworkExplorer[tn]
(* Dynamic interface:
   - Click tensor to inspect dimensions, values
   - Drag to rearrange layout
   - Hover for index information
   - Click-to-contract simulation *)
```

**E2. ContractionAnimator** - Animated contraction sequence
```mathematica
ContractionAnimator[tn, path]
(* Animate step-by-step contraction with:
   - Cost accumulation
   - Network shrinking
   - Playback controls *)
```

**E3. PathSelector** - Interactive path building
```mathematica
PathSelector[tn]
(* Click pairs of tensors to build contraction path
   Real-time cost feedback *)
```

#### Category F: Network Analysis Visualization

**F1. NetworkStructurePlot** - Structural analysis
```mathematica
NetworkStructurePlot[tn, "Analysis" -> type]
(* Types:
   - "DegreeDistribution"
   - "Centrality"
   - "Communities"
   - "TreeWidth" *)
```

**F2. IndexConnectivityMatrix** - Heatmap of connections
```mathematica
IndexConnectivityMatrix[tn]
(* Matrix showing which tensors share which indices *)
```

#### Category G: Export & Publication

**G1. ExportDiagram** - Publication-quality export
```mathematica
ExportDiagram[diagram, "file.pdf"]
ExportDiagram[diagram, "file.tikz"]  (* LaTeX TikZ *)
ExportDiagram[diagram, "file.svg"]
```

**G2. DiagramToLaTeX** - Generate LaTeX/TikZ code
```mathematica
DiagramToLaTeX[TensorNetworkDiagram[tn]]
(* Returns string of TikZ commands *)
```

### 7.5 Visualization Implementation Plan

#### Phase V1: Core Diagram Functions (Priority: HIGH)

**Task V1.1**: Implement `TensorNetworkDiagram`
- Penrose-style notation with shapes for tensors
- Index lines with proper styling
- Support for symmetry indicators (zigzag for symmetric, bar for antisymmetric)
- Leverages Mathematica's `Graphics` primitives

**Task V1.2**: Implement `MPSDiagram` and `MPODiagram`
- Linear chain layout
- Bond dimension labels
- Physical index visualization
- Canonical form indicators

**Task V1.3**: Implement `ContractionTreePlot` with multiple layouts
- Port Cotengra's layout algorithms
- "Tent", "Ring", "Circuit", "Flat" layouts
- Cost-weighted edges and nodes

#### Phase V2: Cost Analysis (Priority: HIGH)

**Task V2.1**: Implement `ContractionCostPlot`
- Memory profile line plot
- FLOP accumulation
- Peak memory markers

**Task V2.2**: Implement `PathComparisonPlot`
- Multi-path overlay
- Cost comparison table

#### Phase V3: MPS-Specific Visualization (Priority: MEDIUM)

**Task V3.1**: Implement `EntanglementProfile`
- Line plot of S(i) vs bond i
- Area-under-curve shading

**Task V3.2**: Implement `SchmidtSpectrumPlot`
- Log-scale option for decay visualization
- Truncation threshold indicator

**Task V3.3**: Implement `BondDimensionPlot`
- Profile visualization
- Comparison between original and truncated

#### Phase V4: Interactive Features (Priority: MEDIUM)

**Task V4.1**: Implement `TensorNetworkExplorer`
- Use `DynamicModule` and `ClickPane`
- Tooltip information on hover
- Expandable tensor details

**Task V4.2**: Implement `ContractionAnimator`
- `Manipulate` with slider for step
- Animated transition option
- Export to GIF/video

#### Phase V5: Optimizer Visualization (Priority: LOW)

**Task V5.1**: Implement `OptimizationProgressPlot`
- Requires path optimizer to return trial history
- May need to extend `GreedyContractionPath`/`OptimalContractionPath`

**Task V5.2**: Implement `OptimizationScatterPlot`
- Scatter plot with best path highlighted

#### Phase V6: Export & Publication (Priority: MEDIUM)

**Task V6.1**: Implement `ExportDiagram`
- Leverage `Export` with vector formats
- Custom TikZ backend for LaTeX users

**Task V6.2**: Implement `DiagramToLaTeX`
- Generate standalone TikZ code
- Template system for different styles

### 7.6 Visualization Files to Create

| File | Functions | Priority |
|------|-----------|----------|
| `Kernel/Visualization/TensorDiagram.wl` | TensorNetworkDiagram, ContractionDiagram | High |
| `Kernel/Visualization/MPSVisualization.wl` | MPSDiagram, MPODiagram, EntanglementProfile | High |
| `Kernel/Visualization/ContractionPlots.wl` | ContractionTreePlot, ContractionCostPlot | High |
| `Kernel/Visualization/PathComparison.wl` | PathComparisonPlot | Medium |
| `Kernel/Visualization/Interactive.wl` | TensorNetworkExplorer, ContractionAnimator | Medium |
| `Kernel/Visualization/OptimizerPlots.wl` | OptimizationProgressPlot, ScatterPlot | Low |
| `Kernel/Visualization/Export.wl` | ExportDiagram, DiagramToLaTeX | Medium |
| `Documentation/VisualizationGuide.nb` | Tutorial notebook | High |

### 7.7 Mathematica Visualization Advantages

**Why Mathematica can EXCEED Cotengra's visualization:**

1. **Native Graphics System** - Full control over every visual element
2. **Dynamic Interactivity** - `Manipulate`, `DynamicModule`, `ClickPane` for true interactivity
3. **Vector Export** - Native PDF, SVG, EPS export at any resolution
4. **Symbolic Integration** - Visualize symbolic tensor networks (impossible in Python)
5. **Graph Theory Built-in** - `Graph`, `GraphLayout`, community detection, centrality
6. **Animation** - `Animate`, `ListAnimate`, export to GIF/video
7. **Notebook Integration** - Inline visualization with evaluation
8. **3D Graphics** - Potential for 3D tensor network visualization (PEPS, TTN)
9. **LaTeX Integration** - Direct TeXForm output for labels

### 7.8 Example Visualization Code

```mathematica
(* Penrose-style tensor diagram *)
TensorNetworkDiagram[
  RandomTensorNetwork["MPS"[5, 4, 2]],
  "Style" -> "Penrose",
  "IndexLabels" -> True,
  "ColorScheme" -> "Rainbow"
]

(* MPS with entanglement coloring *)
mps = RandomTensorNetwork["MPS"[10, 16, 2]];
MPSDiagram[mps,
  "ColorByEntanglement" -> True,
  "ShowBondDimensions" -> True
]

(* Contraction cost analysis *)
path = GreedyContractionPath[network];
ContractionCostPlot[network, path,
  "ShowPeakMemory" -> True,
  "ShowFLOPs" -> True
]

(* Interactive explorer *)
TensorNetworkExplorer[network]
(* Click any tensor to see:
   - Dimensions
   - Connected indices
   - Numerical values (if available)
   - Contraction cost if removed *)

(* Export to LaTeX *)
diagram = TensorNetworkDiagram[network];
Export["figure.pdf", diagram];
tikzCode = DiagramToLaTeX[diagram];
```

---

## Sources

- [Cotengra Documentation](https://cotengra.readthedocs.io/)
- [Cotengra Visualization](https://cotengra.readthedocs.io/en/latest/visualization.html)
- [Cotengra GitHub](https://github.com/jcmgray/cotengra)
- [Google TensorNetwork GitHub](https://github.com/google/TensorNetwork)
- [ITensor Documentation](https://itensor.org/)
- [Quimb GitHub](https://github.com/jcmgray/quimb)
- [Tensor Network Software List](https://tensornetwork.org/software/)
- [Tensor Network Diagrams](https://tensornetwork.org/diagrams/)
- [Penrose Graphical Notation](https://en.wikipedia.org/wiki/Penrose_graphical_notation)
- [Wolfram Symbolic Tensors](https://reference.wolfram.com/language/guide/SymbolicTensors.html)
- [NVIDIA cuTensorNet](https://developer.nvidia.com/cuquantum-sdk)
