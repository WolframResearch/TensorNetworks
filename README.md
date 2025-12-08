# Wolfram TensorNetworks

The **Wolfram TensorNetworks** paclet provides a general framework for Tensor Networks in the Wolfram Language. It integrates the **Cotengra** library (written in Rust) for high-performance contraction path optimization.

## Installation

### Paclet Repository

The paclet will be available from the Wolfram Paclet Repository:
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
net = GraphTensorNetwork[RandomGraph[{10, 20}], 
  Method -> "RandomComplex"]

ContractTensorNetwork[net]

path = TensorNetworkContractionPath[net]

Activate /@ 
 AssociationMap[
  TensorNetworkContraction[net, path, 
    Method -> #] &, $TensorNetworkContractionMethods]
```
