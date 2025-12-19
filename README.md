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
| `TensorNetwork` | `TensorNetwork[tensors, indices]` or `TensorNetwork[graph]` creates a tensor network object with a summary box display. |
| `TensorNetworkQ` | `TensorNetworkQ[expr]` yields `True` if `expr` is a valid `TensorNetwork` object. |
| `TensorNetworkFromGraph` | `TensorNetworkFromGraph[g]` constructs a tensor network from a directed acyclic graph `g`. |
| `RandomTensorNetwork` | Create a tensor network with random tensors and topology. |
| `SparseTensorNetwork` | Convert a tensor network's tensors to `SparseArray`. |
| `BinaryTensorNetwork` | Convert a tensor network to a binary form (max 2 tensors per index). |

### Graph & Topology

| Function | Usage |
| :--- | :--- |
| `TensorNetworkGraphQ` | `TensorNetworkGraphQ[g]` yields `True` if `g` is a valid tensor network graph. |
| `TensorNetworkIndexGraph` | `TensorNetworkIndexGraph[net]` returns a graph representing the index connectivity of the tensor network. |
| `TensorNetworkToNetGraph` | `TensorNetworkToNetGraph[net]` converts the tensor network into a Neural `NetGraph`. |
| `TensorNetworkRemoveCycles` | `TensorNetworkRemoveCycles[net]` inserts identity tensors to break cycles in the network graph. |

### Network Manipulation

| Function | Usage |
| :--- | :--- |
| `TensorNetworkAdd` | `TensorNetworkAdd[net, tensor, indices]` adds a new tensor to the network with specified indices. |
| `TensorNetworkReplaceIndices` | `TensorNetworkReplaceIndices[net, rules]` replaces indices in the network according to rules. |
| `InitializeTensorNetwork` | `InitializeTensorNetwork[net, tensors]` initializes a tensor network with initial tensors. |

### Data & Extraction

| Function | Usage |
| :--- | :--- |
| `TensorNetworkIndices` | `TensorNetworkIndices[net]` returns the index lists for each tensor in the network. |
| `TensorNetworkTensors` | `TensorNetworkTensors[net]` returns the list of tensors stored in the network vertices. |
| `TensorNetworkFromGraphData` | `TensorNetworkFromGraphData[net]` returns an association containing raw data (tensors, indices, dimensions) of the network. |
| `TensorNetworkIndexDimensions` | `TensorNetworkIndexDimensions[net]` returns the dimensions associated with each index in the network. |
| `TensorNetworkFreeIndices` | `TensorNetworkFreeIndices[net]` returns the list of uncontracted (free) indices in the network. |
| `TensorNetworkData` | Returns an association of all internal data for a `TensorNetwork` object. |
| `TensorNetworkSize` | Returns the number of tensors in the network. |

### Contraction & Path Optimization

| Function | Usage |
| :--- | :--- |
| `TensorNetworkContract` | `TensorNetworkContract[net, path]` contracts the entire tensor network to a single tensor. |
| `TensorNetworkFindContractionPath` | `TensorNetworkFindContractionPath[net]` computes an optimized contraction path for the network. |
| `TensorNetworkContraction` | `TensorNetworkContraction[net, path]` returns a contraction expression for the tensor network along a path. |
| `$TensorNetworkContractionMethods` | List of available types for contraction expressions. |
| `ContractionTree` | Visualizes the contraction process as a tree. |

### Low-level Utilities

| Function | Usage |
| :--- | :--- |
| `EinsteinSummation` | `EinsteinSummation[in -> out, arrays]` contracts given arrays according to the index specification. |
| `TensorJoin` | `TensorJoin[indices, arrays]` joins arrays over shared indices. |
| `ActivateTensors` | `ActivateTensors[expr]` activates `Inactive[TensorProduct]` and `Inactive[TensorContract]` in `expr`. |
| `CanonicalPath` | Returns a canonical representation of a contraction path. |
| `TreePathToPath` / `PathToTreePath` | Conversion between tree and linear contraction paths. |
| `PathIndexContractions` | Returns the sequence of indices contracted at each step. |
