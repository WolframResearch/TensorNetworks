# Wolfram TensorNetworks

The **Wolfram TensorNetworks** paclet provides a general framework for Tensor Networks in the Wolfram Language. It integrates the **Cotengra** library (written in Rust) for high-performance contraction path optimization.

## Installation

### Paclet Repository

The paclet is available from the Wolfram Paclet Repository:
[Wolfram/TensorNetworks](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/TensorNetworks/)

### Development Version

You can install the latest development version directly from the cloud:

```wolfram
PacletInstall["https://www.wolframcloud.com/obj/wolframquantumframework/TensorNetworks.paclet"]
```

### From Source

To install from the source code locally:

1.  Clone the repository.
2.  Load the paclet directory:

```wolfram
PacletDirectoryLoad["paclet_path"]
Needs["Wolfram`TensorNetworks`"]
```

## Quick Start

### Contraction Path Optimization

```wolfram
net = ToTensorNetworkGraph[RandomGraph[{10, 20}], 
  Method -> "RandomComplex"]

TensorNetworkContract[net]

path = TensorNetworkFindContractionPath[net]

Activate /@ 
 AssociationMap[
  TensorNetworkContraction[net, path, 
    Method -> #] &, $TensorNetworkContractionMethods]
```

---

## API Reference

This section provides comprehensive documentation for all public functions.

---

### Core Tensor Network Construction

#### TensorNetwork

Creates a tensor network object with a summary box display.

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetwork[{A₁,A₂,…}, {h₁,h₂,…}]` | creates a tensor network from tensors Aᵢ with hyperedge index lists hᵢ |
| `TensorNetwork[{A₁,A₂,…}, {i₁,i₂,…} → out]` | creates a tensor network using Einstein summation notation |
| `TensorNetwork[expr]` | constructs from `TensorContract`, `Transpose`, or `TensorProduct` expressions |
| `TensorNetwork[graph]` | creates from a directed acyclic graph with tensor annotations |

#### TensorNetworkQ

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkQ[tn]` | yields `True` if `tn` is a valid `TensorNetwork` object, `False` otherwise |

#### RandomTensorNetwork

Creates random tensor networks of various architectures.

| Calling Form | Description |
|:-------------|:------------|
| `RandomTensorNetwork[{n,m}, maxDim]` | random network based on `RandomGraph[{n,m}]` with dimensions up to `maxDim` |
| `RandomTensorNetwork[{n,m}, {dim}]` | uses fixed dimension `dim` for all indices |
| `RandomTensorNetwork[graph, maxDim]` | creates from the specified graph |
| `RandomTensorNetwork["MPS"[length, bondDim, physicalDim]]` | Matrix Product State |
| `RandomTensorNetwork["TT"[length, bondDim]]` | Tensor Train (no physical indices) |
| `RandomTensorNetwork["MPO"[length, bondDim, physicalDim]]` | Matrix Product Operator |
| `RandomTensorNetwork["PEPS"[{rows,cols}, bondDim, physicalDim]]` | Projected Entangled Pair State |
| `RandomTensorNetwork["TTN"[depth, bondDim, branching]]` | Tree Tensor Network |
| `RandomTensorNetwork["MERA"[width, bondDim, layers]]` | Multi-scale Entanglement Renormalization Ansatz |

**Options:**
- `Method → Automatic` — `"Complex"` for complex-valued tensors
- `"Boundary" → "Open"` — `"Periodic"` for periodic boundary conditions

#### TensorNetworkData

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkData[tn]` | returns an `Association` with vertices, tensors, indices, dimensions, and contractions |

#### TensorNetworkSize

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkSize[tn]` | returns the total number of elements across all tensors |

#### TensorNetworkContractions

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkContractions[tn]` | returns the list of index contractions in the network |

---

### Network Manipulation

#### TensorNetworkAdd

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkAdd[tn, tensor, indices]` | adds a tensor to the network with specified indices |

Indices matching existing network indices create new contractions.

#### TensorNetworkDelete

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkDelete[tn, k]` | deletes the k-th tensor from the network |
| `TensorNetworkDelete[tn, -1]` | deletes the last tensor |

#### TensorNetworkReplaceIndices

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkReplaceIndices[net, {i₁→j₁, i₂→j₂, …}]` | replaces indices according to rules |

#### InitializeTensorNetwork

| Calling Form | Description |
|:-------------|:------------|
| `InitializeTensorNetwork[net, {t₁,t₂,…}]` | initializes a network graph with numerical tensors |

---

### Graph & Topology

#### ToTensorNetworkGraph

| Calling Form | Description |
|:-------------|:------------|
| `ToTensorNetworkGraph[graph]` | constructs a tensor network graph from a directed acyclic graph |
| `ToTensorNetworkGraph[tn]` | converts a `TensorNetwork` object to graph representation |

**Options:**
- `Method → "Symbolic"` — uses symbolic tensor representations

#### TensorNetworkGraphQ

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkGraphQ[net]` | yields `True` if `net` is a valid tensor network graph |
| `TensorNetworkGraphQ[net, True]` | prints diagnostic messages for invalid networks |

#### TensorNetworkIndexGraph

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkIndexGraph[net]` | returns a graph representing the index connectivity |

#### TensorNetworkRemoveCycles

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkRemoveCycles[net]` | inserts identity tensors to break cycles, making the graph acyclic |

#### TensorNetworkToNetGraph

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkToNetGraph[net]` | converts to a Wolfram Neural `NetGraph` object |

---

### Data & Extraction

#### TensorNetworkIndices

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkIndices[net]` | returns the list of index specifications for each tensor vertex |

#### TensorNetworkTensors

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkTensors[net]` | returns the list of tensors stored in the network vertices |

#### TensorNetworkGraphData

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkGraphData[net]` | returns an `Association` with raw data (tensors, indices, dimensions, contractions) |

#### TensorNetworkIndexDimensions

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkIndexDimensions[net]` | returns an `Association` mapping each index to its dimension |
| `TensorNetworkIndexDimensions[indices, tensors]` | computes dimensions from explicit lists |

#### TensorNetworkFreeIndices

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkFreeIndices[net]` | returns the list of uncontracted (free/open) indices |

---

### Contraction & Path Optimization

#### TensorNetworkContract

Contracts the tensor network to a single tensor.

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkContract[tn]` | contracts using the default (optimal) path |
| `TensorNetworkContract[tn, path]` | contracts using the specified contraction path |
| `TensorNetworkContract[data, path]` | contracts using pre-computed network data |

Returns an evaluated numerical tensor (not symbolic).

#### TensorNetworkFindContractionPath

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkFindContractionPath[tn]` | computes an optimized contraction path |
| `TensorNetworkFindContractionPath[tn, Method → "Greedy"]` | uses greedy optimization |
| `TensorNetworkFindContractionPath[tn, Method → "Optimal"]` | finds the optimal path (slower for large networks) |

#### TensorNetworkContraction

Returns a symbolic contraction expression.

| Calling Form | Description |
|:-------------|:------------|
| `TensorNetworkContraction[tn, path]` | symbolic expression along the given path |
| `TensorNetworkContraction[tn, treePath]` | uses a tree-structured contraction path |
| `TensorNetworkContraction[tn, "Greedy"]` | automatically computes a greedy path |
| `TensorNetworkContraction[tn, "Optimal"]` | automatically computes an optimal path |

**Options:**
- `Method → "ArrayDot"` — contraction method (`"ArrayDotTranspose"`, `"ArrayDot"`, `"Dot"`, `"TensorContract"`, `"TableSum"`)
- `"Inactive" → True` — returns inactive expressions

#### ContractionTree

| Calling Form | Description |
|:-------------|:------------|
| `ContractionTree[tn]` | returns a `Tree` representing the contraction hierarchy |
| `ContractionTree[tn, path]` | uses the specified contraction path |

#### $TensorNetworkContractionMethods

List of available contraction methods: `"ArrayDotTranspose"`, `"ArrayDot"`, `"Dot"`, `"TensorContract"`, `"TableSum"`.

---

### Matrix Product States (MPS)

#### MPSCanonicalForm

Transforms an MPS into canonical form.

| Calling Form | Description |
|:-------------|:------------|
| `MPSCanonicalForm[mps]` | left-canonical form (default) |
| `MPSCanonicalForm[mps, "Left"]` | left-isometric form where A†·A = I |
| `MPSCanonicalForm[mps, "Right"]` | right-isometric form where A·A† = I |
| `MPSCanonicalForm[mps, {"Mixed", k}]` | mixed canonical form centered at site k |

#### MPSCanonicalQ

| Calling Form | Description |
|:-------------|:------------|
| `MPSCanonicalQ[mps, "Left"]` | checks left-canonical form |
| `MPSCanonicalQ[mps, "Right"]` | checks right-canonical form |
| `MPSCanonicalQ[mps, {"Mixed", k}]` | checks mixed-canonical form at site k |

Uses tolerance 10⁻¹⁰ for numerical comparison.

#### MPSOverlap

| Calling Form | Description |
|:-------------|:------------|
| `MPSOverlap[mps₁, mps₂]` | computes the inner product ⟨Ψ₁\|Ψ₂⟩ between two MPS |

The second MPS is conjugated. `MPSOverlap[mps, mps]` returns the squared norm.

#### MPSNorm

| Calling Form | Description |
|:-------------|:------------|
| `MPSNorm[mps]` | computes the norm ‖Ψ‖ of an MPS |

Equivalent to `Sqrt[Abs[MPSOverlap[mps, mps]]]`.

#### MPSNormalize

| Calling Form | Description |
|:-------------|:------------|
| `MPSNormalize[mps]` | returns an MPS normalized to unit norm |

The physical state is preserved; only the overall scale factor changes.

#### MPSEntanglementEntropy

| Calling Form | Description |
|:-------------|:------------|
| `MPSEntanglementEntropy[mps, site]` | von Neumann entropy S = -∑ p log(p) at bond between site and site+1 |

Returns 0 for product states, log(D) for maximally entangled states with bond dimension D. Uses natural logarithm.

#### MPSSchmidtValues

| Calling Form | Description |
|:-------------|:------------|
| `MPSSchmidtValues[mps, site]` | normalized Schmidt coefficients λᵢ at the bond between site and site+1 |

Values satisfy ∑ λᵢ² = 1. Number of values equals the bond dimension at that cut.

#### MPSTruncate

| Calling Form | Description |
|:-------------|:------------|
| `MPSTruncate[mps, maxBond]` | compresses MPS by truncating all bonds to at most `maxBond` |

Result is in left-canonical form. Truncation error depends on discarded singular values.

---

### Einstein Summation

#### EinsteinSummation

Contracts tensors according to index specification.

| Calling Form | Description |
|:-------------|:------------|
| `EinsteinSummation[{i₁,i₂,…} → out, {A₁,A₂,…}]` | contracts tensors according to index specification |
| `EinsteinSummation[{i₁,i₂,…}, {A₁,A₂,…}]` | auto-determines output from indices appearing once |
| `EinsteinSummation["ij,jk->ik", {A, B}]` | string notation with comma-separated indices |

#### TensorJoin

| Calling Form | Description |
|:-------------|:------------|
| `TensorJoin[{i₁,i₂,…}, {A₁,A₂,…}]` | joins tensors over shared indices, broadcasting along non-shared dimensions |

Returns `{indices, tensor}` where tensor is the joined result.

#### ActivateTensors

| Calling Form | Description |
|:-------------|:------------|
| `ActivateTensors[expr]` | activates `Inactive[TensorProduct]`, `Inactive[TensorContract]`, and `Inactive[Transpose]` |

Converts symbolic tensor expressions to evaluated numerical tensors.

---

### Path Utilities

#### GreedyPath

| Calling Form | Description |
|:-------------|:------------|
| `GreedyPath[inputs, output, sizeDict, …]` | finds a contraction path using a greedy heuristic |

**Arguments:**
- `inputs` — list of index lists for each tensor
- `output` — list of indices for the final result
- `sizeDict` — `Association` mapping indices to dimensions

**Optional:** `costMod`, `temperature`, `maxNeighbors`, `seed`, `simplify`, `useSSA`

#### OptimalPath

| Calling Form | Description |
|:-------------|:------------|
| `OptimalPath[inputs, output, sizeDict, …]` | finds an optimal contraction path via dynamic programming |

**Optional:** `minimize`, `costCap`, `searchOuter`, `simplify`, `useSSA`

#### ContractIndices

| Calling Form | Description |
|:-------------|:------------|
| `ContractIndices[i, j]` | returns the indices that would be contracted between index sets i and j |

#### TreePathToPath

| Calling Form | Description |
|:-------------|:------------|
| `TreePathToPath[treePath, indices]` | converts a tree-structured path to a linear (pairwise) path |

#### PathToTreePath

| Calling Form | Description |
|:-------------|:------------|
| `PathToTreePath[path, indices]` | converts a linear path to a tree-structured path |

#### CanonicalPath

| Calling Form | Description |
|:-------------|:------------|
| `CanonicalPath[path, indices]` | returns a canonical (normalized) representation of the path |

#### PathIndexContractions

| Calling Form | Description |
|:-------------|:------------|
| `PathIndexContractions[path, indices]` | returns the sequence of index sets contracted at each step |

---

## Examples

### Creating Specific Tensor Network Types

```wolfram
(* Matrix Product State: 10 sites, bond dimension 4, physical dimension 2 *)
mps = RandomTensorNetwork["MPS"[10, 4, 2]]

(* Tensor Train: 8 sites, bond dimension 3 *)
tt = RandomTensorNetwork["TT"[8, 3]]

(* Matrix Product Operator: 6 sites, bond dimension 3, physical dimension 2 *)
mpo = RandomTensorNetwork["MPO"[6, 3, 2]]

(* PEPS: 4×4 grid, bond dimension 3, physical dimension 2 *)
peps = RandomTensorNetwork["PEPS"[{4, 4}, 3, 2]]

(* Tree Tensor Network: depth 3, bond dimension 4, branching 2 *)
ttn = RandomTensorNetwork["TTN"[3, 4, 2]]

(* MERA: width 4, bond dimension 4, 2 layers *)
mera = RandomTensorNetwork["MERA"[4, 4, 2]]
```

### MPS Operations

```wolfram
(* Create and canonicalize an MPS *)
mps = RandomTensorNetwork["MPS"[10, 4, 2]]
canonical = MPSCanonicalForm[mps, "Left"]

(* Check canonicality *)
MPSCanonicalQ[canonical, "Left"]  (* True *)

(* Compute norm and normalize *)
norm = MPSNorm[mps]
normalized = MPSNormalize[mps]

(* Compute entanglement entropy at site 5 *)
entropy = MPSEntanglementEntropy[normalized, 5]

(* Truncate to smaller bond dimension *)
truncated = MPSTruncate[mps, 2]
```

### Einstein Summation

```wolfram
(* Matrix multiplication: C = A.B *)
A = RandomReal[1, {3, 4}];
B = RandomReal[1, {4, 5}];
C = EinsteinSummation[{{i, k}, {k, j}} -> {i, j}, {A, B}]

(* Trace: Tr[A] *)
M = RandomReal[1, {4, 4}];
trace = EinsteinSummation[{{i, i}}, {M}]

(* String notation *)
result = EinsteinSummation["ij,jk->ik", {A, B}]
```
