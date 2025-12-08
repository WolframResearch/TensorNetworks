Package["Wolfram`TensorNetworks`"]

(* EinsteinSummation.wl *)
EinsteinSummation::usage = "EinsteinSummation[in -> out, arrays] contracts the given arrays according to the index specification."
HadamardProduct::usage = "HadamardProduct[indices, arrays] computes the Hadamard product of arrays over shared indices."
ActivateTensor::usage = "ActivateTensor[expr] activates Inactive[TensorProduct] and Inactive[TensorContract] in expr."

(* TensorNetworks.wl *)
GreedyPath::usage = "GreedyPath[inputs, output, sizeDict] finds a contraction path using a greedy heuristic."
OptimalPath::usage = "OptimalPath[inputs, output, sizeDict] finds an optimal contraction path."
ContractIndices::usage = "ContractIndices[i, j] returns the indices that would be contracted between two index sets i and j."
TreePathToPath::usage = "TreePathToPath[treePath, indices] converts a tree-structured path to a linear contraction path."
PathToTreePath::usage = "PathToTreePath[path, indices] converts a linear contraction path to a tree-structured path."
CanonicalPath::usage = "CanonicalPath[path, indices] returns a canonical representation of the contraction path."
PathIndexContractions::usage = "PathIndexContractions[path, indices] returns the sequence of indices contracted at each step of the path."

(* TensorNetworkGraph.wl *)
TensorNetworkGraphQ::usage = "TensorNetworkGraphQ[g] yields True if g is a valid tensor network graph."
TensorNetworkIndexGraph::usage = "TensorNetworkIndexGraph[net] returns a graph representing the index connectivity of the tensor network."
GraphTensorNetwork::usage = "GraphTensorNetwork[g] constructs a tensor network from a directed acyclic graph g."
TensorNetworkIndices::usage = "TensorNetworkIndices[net] returns the index lists for each tensor in the network."
TensorNetworkTensors::usage = "TensorNetworkTensors[net] returns the list of tensors stored in the network vertices."
TensorNetworkGraphData::usage = "TensorNetworkGraphData[net] returns an association containing raw data (tensors, indices, dimensions) of the network."
TensorNetworkIndexDimensions::usage = "TensorNetworkIndexDimensions[net] returns the dimensions associated with each index in the network."
TensorNetworkFreeIndices::usage = "TensorNetworkFreeIndices[net] returns the list of uncontracted (free) indices in the network."
TensorNetworkAdd::usage = "TensorNetworkAdd[net, tensor, indices] adds a new tensor to the network with specified indices."
RemoveTensorNetworkCycles::usage = "RemoveTensorNetworkCycles[net] inserts identity tensors to break cycles in the network graph."
TensorNetworkNetGraph::usage = "TensorNetworkNetGraph[net] converts the tensor network into a Neural NetGraph."
TensorNetworkIndexReplace::usage = "TensorNetworkIndexReplace[net, rules] replaces indices in the network according to rules."
InitializeTensorNetwork::usage = "InitializeTensorNetwork[net, tensors] initializes a tensor network with a initial tensors."

(* Contraction.wl *)
ContractTensorNetwork::usage = "ContractTensorNetwork[net] contracts the entire tensor network to a single tensor."
TensorNetworkContractionPath::usage = "TensorNetworkContractionPath[net] computes an optimized contraction path for the network."
TensorNetworkContractPath::usage = "TensorNetworkContractPath[net, path] contracts the network using the specified contraction path."
TensorNetworkContraction::usage = "TensorNetworkContraction[net, path] returns a contraction expression for the tensor network along a path."
$TensorNetworkContractionMethods::usage = "$TensorNetworkContractionMethods is a list of available types for contraction expressions."
