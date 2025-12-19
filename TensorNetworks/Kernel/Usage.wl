Package["Wolfram`TensorNetworks`"]

(* EinsteinSummation.wl *)
EinsteinSummation::usage = "EinsteinSummation[in -> out, arrays] contracts the given arrays according to the index specification."
TensorJoin::usage = "TensorJoin[indices, arrays] joins arrays over shared indices, broadcasting along non-shared dimensions."
ActivateTensors::usage = "ActivateTensors[expr] activates Inactive[TensorProduct] and Inactive[TensorContract] in expr."

(* TensorNetworks.wl *)
GreedyPath::usage = "GreedyPath[inputs, output, sizeDict] finds a contraction path using a greedy heuristic."
OptimalPath::usage = "OptimalPath[inputs, output, sizeDict] finds an optimal contraction path."
ContractIndices::usage = "ContractIndices[i, j] returns the indices that would be contracted between two index sets i and j."
TreePathToPath::usage = "TreePathToPath[treePath, indices] converts a tree-structured path to a linear contraction path."
PathToTreePath::usage = "PathToTreePath[path, indices] converts a linear contraction path to a tree-structured path."
CanonicalPath::usage = "CanonicalPath[path, indices] returns a canonical representation of the contraction path."
PathIndexContractions::usage = "PathIndexContractions[path, indices] returns the sequence of indices contracted at each step of the path."

(* TensorNetwork.wl *)
TensorNetwork::usage = "TensorNetwork[tensors, indices] or TensorNetwork[graph] creates a tensor network object with a summary box display."
TensorNetworkQ::usage = "TensorNetworkQ[expr] yields True if expr is a valid TensorNetwork object."

(* TensorNetworkGraph.wl *)
TensorNetworkGraphQ::usage = "TensorNetworkGraphQ[g] yields True if g is a valid tensor network graph."
TensorNetworkIndexGraph::usage = "TensorNetworkIndexGraph[net] returns a graph representing the index connectivity of the tensor network."
TensorNetworkGraph::usage = "TensorNetworkGraph[g] constructs a tensor network from a directed acyclic graph g."
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
TensorNetworkContract::usage = "TensorNetworkContract[net, path] contracts the entire tensor network to a single tensor."
TensorNetworkContractionPath::usage = "TensorNetworkContractionPath[net] computes an optimized contraction path for the network."
TensorNetworkContraction::usage = "TensorNetworkContraction[net, path] returns a contraction expression for the tensor network along a path."
$TensorNetworkContractionMethods::usage = "$TensorNetworkContractionMethods is a list of available types for contraction expressions."
