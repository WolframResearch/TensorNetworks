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

| Function | Usage |
| :--- | :--- |
| `TensorNetwork` | creates a tensor network object with a summary box display. |
| `TensorNetworkQ` | yields `True` if an expression is a valid `TensorNetwork` object. |
| `TensorNetworkFromGraph` | constructs a tensor network from a graph. |
| `RandomTensorNetwork` | creates a tensor network with random tensors and topology. |
| `SparseTensorNetwork` | converts a tensor network's tensors to `SparseArray`. |
| `BinaryTensorNetwork` | converts a tensor network to binary form (at most 2 tensors per index). |
| `BinaryTensorNetworkQ` | yields `True` if a tensor network is in binary form. |

### Graph & Topology

| Function | Usage |
| :--- | :--- |
| `TensorNetworkGraphQ` | yields `True` if a graph is a valid tensor network graph. |
| `TensorNetworkIndexGraph` | returns a graph representing the index connectivity of the network. |
| `TensorNetworkToNetGraph` | converts a tensor network into a Neural `NetGraph` object. |
| `TensorNetworkRemoveCycles` | inserts identity tensors to break cycles in the network graph. |

### Network Manipulation

| Function | Usage |
| :--- | :--- |
| `TensorNetworkAdd` | adds a new tensor to the network with specified indices. |
| `TensorNetworkReplaceIndices` | replaces indices in the network according to rules. |
| `InitializeTensorNetwork` | initializes a tensor network with specific tensors. |

### Data & Extraction

| Function | Usage |
| :--- | :--- |
| `TensorNetworkIndices` | returns the index lists for each tensor in the network. |
| `TensorNetworkTensors` | returns the list of tensors stored in the network. |
| `TensorNetworkFromGraphData` | returns raw data (tensors, indices, dimensions) of the network. |
| `TensorNetworkIndexDimensions` | returns the dimensions associated with each index. |
| `TensorNetworkFreeIndices` | returns the list of uncontracted (free) indices in the network. |
| `TensorNetworkData` | returns an association of all internal data for a `TensorNetwork`. |
| `TensorNetworkSize` | returns the number of tensors in the network. |
| `TensorNetworkContractions` | returns the tensor network indices grouped by connectivity. |

### Contraction & Path Optimization

| Function | Usage |
| :--- | :--- |
| `TensorNetworkContract` | contracts the entire tensor network to a single tensor. |
| `TensorNetworkFindContractionPath` | computes an optimized contraction path for the network. |
| `TensorNetworkContraction` | returns a contraction expression for the network along a path. |
| `$TensorNetworkContractionMethods` | list of available types for contraction expressions. |
| `ContractionTree` | visualizes the contraction process as a tree. |
| `GreedyPath` | finds a contraction path using a greedy heuristic. |
| `OptimalPath` | finds an optimal contraction path. |

### Low-level Utilities

| Function | Usage |
| :--- | :--- |
| `EinsteinSummation` | contracts given arrays according to the index specification. |
| `TensorJoin` | joins arrays over shared indices. |
| `ActivateTensors` | activates `Inactive` tensor operations in an expression. |
| `CanonicalPath` | returns a canonical representation of a contraction path. |
| `TreePathToPath` | converts a tree-structured path to a linear contraction path. |
| `PathToTreePath` | converts a linear contraction path to a tree-structured path. |
| `PathIndexContractions` | returns the sequence of indices contracted at each step. |
| `ContractIndices` | returns the indices that would be contracted between two index sets. |
