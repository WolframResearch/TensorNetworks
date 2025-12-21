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
PacletDirectoryLoad["/path/to/Cotengra/TensorNetworks"]
Needs["Wolfram`TensorNetworks`"]
```

## Usage

### Contraction Path Optimization

The paclet provides functions to find optimal contraction paths for tensor networks, leveraging the `Cotengra` library.

```wolfram
net = TensorNetworkFromGraph[RandomGraph[{10, 20}], 
  Method -> "RandomComplex"]

TensorNetworkContract[net]

path = TensorNetworkFindContractionPath[net]

Activate /@ 
 AssociationMap[
  TensorNetworkContraction[net, path, 
    Method -> #] &, $TensorNetworkContractionMethods]
```

## Function List

This section provides a comprehensive list of all public functions exported by the `Wolfram`TensorNetworks`` paclet, organized by category.

### Core Tensor Network Construction

| Function | Usage | Output |
| :--- | :--- | :--- |
| `TensorNetwork` | creates a tensor network object with a summary box display. | `TensorNetwork[...]` object |
| `TensorNetworkQ` | yields `True` if an expression is a valid `TensorNetwork` object. | `True` or `False` |
| `TensorNetworkFromGraph` | constructs a tensor network from a graph. | `TensorNetwork[...]` object |
| `RandomTensorNetwork` | creates a tensor network with random tensors and topology. | `TensorNetwork[...]` object |
| `SparseTensorNetwork` | converts a tensor network's tensors to `SparseArray`. | `TensorNetwork[...]` object |
| `BinaryTensorNetwork` | converts a tensor network to binary form (at most 2 tensors per index). | `TensorNetwork[...]` object |
| `BinaryTensorNetworkQ` | yields `True` if a tensor network is in binary form. | `True` or `False` |

### Graph & Topology

| Function | Usage | Output |
| :--- | :--- | :--- |
| `TensorNetworkGraphQ` | yields `True` if a graph is a valid tensor network graph. | `True` or `False` |
| `TensorNetworkIndexGraph` | returns a graph representing the index connectivity of the network. | `Graph` object |
| `TensorNetworkToNetGraph` | converts a tensor network into a Neural `NetGraph` object. | `NetGraph` object |
| `TensorNetworkRemoveCycles` | inserts identity tensors to break cycles in the network graph. | `TensorNetwork[...]` object |

### Network Manipulation

| Function | Usage | Output |
| :--- | :--- | :--- |
| `TensorNetworkAdd` | adds a new tensor to the network with specified indices. | `TensorNetwork[...]` object |
| `TensorNetworkReplaceIndices` | replaces indices in the network according to rules. | `TensorNetwork[...]` object |
| `InitializeTensorNetwork` | initializes a tensor network with specific tensors. | `TensorNetwork[...]` object |

### Data & Extraction

| Function | Usage | Output |
| :--- | :--- | :--- |
| `TensorNetworkIndices` | returns the index lists for each tensor in the network. | `List` of index lists |
| `TensorNetworkTensors` | returns the list of tensors stored in the network. | `List` of arrays |
| `TensorNetworkFromGraphData` | returns raw data (tensors, indices, dimensions) of the network. | `Association` of raw data |
| `TensorNetworkIndexDimensions` | returns the dimensions associated with each index. | `Association` |
| `TensorNetworkFreeIndices` | returns the list of uncontracted (free) indices in the network. | `List` of indices |
| `TensorNetworkData` | returns an association of all internal data for a `TensorNetwork`. | `Association` |
| `TensorNetworkSize` | returns the number of tensors in the network. | `Integer` |
| `TensorNetworkContractions` | returns the tensor network indices grouped by connectivity. | `List` of index groups |

### Contraction & Path Optimization

| Function | Usage | Output |
| :--- | :--- | :--- |
| `TensorNetworkContract` | contracts the entire tensor network to a single tensor. | `Array` (result of contraction) |
| `TensorNetworkFindContractionPath` | computes an optimized contraction path for the network. | `List` (contraction path) |
| `TensorNetworkContraction` | returns a contraction expression for the network along a path. | symbolic `Inactive` expression |
| `$TensorNetworkContractionMethods` | list of available types for contraction expressions. | `List` of strings |
| `ContractionTree` | visualizes the contraction process as a tree. | `Tree` object |
| `GreedyPath` | finds a contraction path using a greedy heuristic. | `List` (contraction path) |
| `OptimalPath` | finds an optimal contraction path. | `List` (contraction path) |

### Low-level Utilities

| Function | Usage | Output |
| :--- | :--- | :--- |
| `EinsteinSummation` | contracts given arrays according to the index specification. | an active `TensorContract` which will be an `Array` resulting from the specified sum over indices. |
| `TensorJoin` | joins arrays over shared indices. | `Array` (result of join) |
| `ActivateTensors` | activates `Inactive` tensor operations in an expression. | expression with activated tensors |
| `CanonicalPath` | returns a canonical representation of a contraction path. | standardized path `List` |
| `TreePathToPath` | converts a tree-structured path to a linear contraction path. | linear path `List` |
| `PathToTreePath` | converts a linear contraction path to a tree-structured path. | nested path `List` |
| `PathIndexContractions` | returns the sequence of indices contracted at each step. | `List` of index sets |
| `ContractIndices` | returns the indices that would be contracted between two index sets. | `List` of common indices |
