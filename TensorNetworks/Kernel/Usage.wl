(* ::Package:: *)

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
RandomTensorNetwork::usage = "RandomTensorNetwork[{verticesNumber,edgesNumber}, maxDimension, maxAdditionalRank] yields a random TN based on RandomGraph[{verticesNumber,edgesNumber}] with tensor dimensions randomly picked from 2 to maxDimension. Use {dim} instead of maxDimension to fix all dimensions to dim."

(* ToTensorNetworkGraph.wl *)
TensorNetworkGraphQ::usage = "TensorNetworkGraphQ[g] yields True if g is a valid tensor network graph."
TensorNetworkIndexGraph::usage = "TensorNetworkIndexGraph[net] returns a graph representing the index connectivity of the tensor network."
ToTensorNetworkGraph::usage = "ToTensorNetworkGraph[g] constructs a tensor network from a directed acyclic graph g."
TensorNetworkIndices::usage = "TensorNetworkIndices[net] returns the index lists for each tensor in the network."
TensorNetworkTensors::usage = "TensorNetworkTensors[net] returns the list of tensors stored in the network vertices."
TensorNetworkGraphData::usage = "TensorNetworkGraphData[net] returns an association containing raw data (tensors, indices, dimensions) of the network."
TensorNetworkIndexDimensions::usage = "TensorNetworkIndexDimensions[net] returns the dimensions associated with each index in the network."
TensorNetworkFreeIndices::usage = "TensorNetworkFreeIndices[net] returns the list of uncontracted (free) indices in the network."
TensorNetworkAdd::usage = "TensorNetworkAdd[net, tensor, indices] adds a new tensor to the network with specified indices."
TensorNetworkDelete::usage = "TensorNetworkDelete[net, index] deletes the tensor at the specified index from the network."
TensorNetworkRemoveCycles::usage = "TensorNetworkRemoveCycles[net] inserts identity tensors to break cycles in the network graph."
TensorNetworkToNetGraph::usage = "TensorNetworkToNetGraph[net] converts the tensor network into a Neural NetGraph."
TensorNetworkReplaceIndices::usage = "TensorNetworkReplaceIndices[net, rules] replaces indices in the network according to rules."
InitializeTensorNetwork::usage = "InitializeTensorNetwork[net, tensors] initializes a tensor network with a initial tensors."

(* Contraction.wl *)
TensorNetworkContract::usage = "TensorNetworkContract[net, path] contracts the entire tensor network to a single tensor."
TensorNetworkFindContractionPath::usage = "TensorNetworkFindContractionPath[net] computes an optimized contraction path for the network."
TensorNetworkContraction::usage = "TensorNetworkContraction[net, path] returns a contraction expression for the tensor network along a path."
$TensorNetworkContractionMethods::usage = "$TensorNetworkContractionMethods is a list of available types for contraction expressions."

(* MPS.wl *)
MPSCanonicalForm::usage = "MPSCanonicalForm[mps, form] transforms an MPS tensor network into canonical form.
\[Bullet] MPSCanonicalForm[mps, \"Left\"] puts all tensors in left-isometric form (A\[ConjugateTranspose]\[CenterDot]A = I).
\[Bullet] MPSCanonicalForm[mps, \"Right\"] puts all tensors in right-isometric form (A\[CenterDot]A\[ConjugateTranspose] = I).
\[Bullet] MPSCanonicalForm[mps, {\"Mixed\", k}] creates mixed canonical form centered at site k."

MPSCanonicalQ::usage = "MPSCanonicalQ[mps, form] returns True if mps is in the specified canonical form.
\[Bullet] MPSCanonicalQ[mps, \"Left\"] checks left-canonical form.
\[Bullet] MPSCanonicalQ[mps, \"Right\"] checks right-canonical form.
\[Bullet] MPSCanonicalQ[mps, {\"Mixed\", k}] checks mixed-canonical form at site k.
Uses tolerance 10^-10 for numerical comparison."

MPSOverlap::usage = "MPSOverlap[mps1, mps2] computes the inner product \[LeftAngleBracket]\[Psi]\:2081|\[Psi]\:2082\[RightAngleBracket] between two MPS.
Returns a complex number. For self-overlap MPSOverlap[mps, mps], returns the squared norm.
The second argument is conjugated in the inner product."

MPSNorm::usage = "MPSNorm[mps] computes the norm of an MPS.
Returns a non-negative real number. Equivalent to Sqrt[Abs[MPSOverlap[mps, mps]]]."

MPSNormalize::usage = "MPSNormalize[mps] returns an MPS normalized to unit norm.
After normalization, MPSNorm[result] \[TildeEqual] 1.0.
The physical state is preserved; only the overall scale factor changes."

MPSEntanglementEntropy::usage = "MPSEntanglementEntropy[mps, site] computes the von Neumann entanglement entropy S = -\[Sum] p log(p) at the bond between site and site+1.
\[Bullet] Returns 0 for a product state.
\[Bullet] Returns log(D) for a maximally entangled state with bond dimension D.
Uses natural logarithm."

MPSSchmidtValues::usage = "MPSSchmidtValues[mps, site] returns the normalized Schmidt coefficients at the bond between site and site+1.
The values satisfy \[Sum] \[Lambda]^2 = 1 (normalized).
Number of values equals the bond dimension at that cut."

MPSTruncate::usage = "MPSTruncate[mps, maxBond] compresses an MPS by truncating all bonds to at most maxBond.
The result is in left-canonical form. Truncation error depends on discarded singular values.
Use after time evolution or variational updates to control bond dimension growth."

