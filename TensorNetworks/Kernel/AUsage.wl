(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

(* ============================================ *)
(* EinsteinSummation.wl                        *)
(* ============================================ *)

EinsteinSummation::usage = "EinsteinSummation[{i\:2081,i\:2082,\[Ellipsis]}\[Rule]out, {A\:2081,A\:2082,\[Ellipsis]}] contracts the tensors A\:2081,A\:2082,\[Ellipsis] according to the index specification.
\[Bullet] EinsteinSummation[{i\:2081,i\:2082,\[Ellipsis]}, {A\:2081,A\:2082,\[Ellipsis]}] automatically determines output indices from indices appearing exactly once.
\[Bullet] EinsteinSummation[\"ij,jk->ik\", {A, B}] uses string notation where commas separate tensor indices and -> specifies output."

IndexedMultiply::usage = "IndexedMultiply[{i\:2081,i\:2082,\[Ellipsis]}, {A\:2081,A\:2082,\[Ellipsis]}] joins tensors over shared indices, broadcasting along non-shared dimensions.
\[Bullet] Returns {indices, tensor} where tensor is the joined result padded appropriately."

ActivateTensors::usage = "ActivateTensors[expr] activates Inactive[TensorProduct], Inactive[TensorContract], and Inactive[Transpose] in expr.
\[Bullet] Converts symbolic tensor expressions to evaluated numerical tensors."

(* ============================================ *)
(* TensorNetwork.wl                            *)
(* ============================================ *)

TensorNetwork::usage = "TensorNetwork[{A\:2081,A\:2082,\[Ellipsis]}, {h\:2081,h\:2082,\[Ellipsis]}] creates a tensor network from tensors A\:1d62 with hyperedge index lists h\:1d62.
\[Bullet] TensorNetwork[{A\:2081,A\:2082,\[Ellipsis]}, {i\:2081,i\:2082,\[Ellipsis]}\[Rule]output] creates a tensor network using Einstein summation notation.
\[Bullet] TensorNetwork[{h\:2081,h\:2082,\[Ellipsis]}\[Rule]output, dims] creates a tensor network with symbolic tensors, where dims is an Association mapping indices to integer dimensions.
\[Bullet] TensorNetwork[{h\:2081,h\:2082,\[Ellipsis]}\[Rule]output, {d\:2081,d\:2082,\[Ellipsis]}] creates a tensor network with symbolic tensors, mapping the union of indices to the dimension list.
\[Bullet] TensorNetwork[expr] constructs a tensor network from TensorContract, Transpose, or TensorProduct expressions.
\[Bullet] TensorNetwork[graph] creates a tensor network from a directed acyclic graph with tensor annotations."

TensorNetworkQ::usage = "TensorNetworkQ[tn] yields True if tn is a valid TensorNetwork object, and False otherwise."

TensorNetworkData::usage = "TensorNetworkData[tn] returns an Association containing the complete data of tensor network tn, including vertices, tensors, indices, dimensions, and contractions."

TensorNetworkSize::usage = "TensorNetworkSize[tn] returns the total number of elements across all tensors in the network."

TensorNetworkContractions::usage = "TensorNetworkContractions[tn] returns the list of index contractions in the tensor network."

RandomTensorNetwork::usage = "RandomTensorNetwork[{n,m}, maxDim] creates a random tensor network based on RandomGraph[{n,m}] with dimensions up to maxDim.
\[Bullet] RandomTensorNetwork[{n,m}, {dim}] uses fixed dimension dim for all indices.
\[Bullet] RandomTensorNetwork[graph, maxDim] creates a tensor network from the specified graph.
\[Bullet] RandomTensorNetwork[\"MPS\"[length, bondDim, physicalDim]] creates a Matrix Product State.
\[Bullet] RandomTensorNetwork[\"TT\"[length, bondDim]] creates a Tensor Train (no physical indices).
\[Bullet] RandomTensorNetwork[\"MPO\"[length, bondDim, physicalDim]] creates a Matrix Product Operator.
\[Bullet] RandomTensorNetwork[\"PEPS\"[{rows,cols}, bondDim, physicalDim]] creates a Projected Entangled Pair State.
\[Bullet] RandomTensorNetwork[\"TTN\"[depth, bondDim, branching]] creates a Tree Tensor Network.
\[Bullet] RandomTensorNetwork[\"MERA\"[width, bondDim, layers]] creates a Multi-scale Entanglement Renormalization Ansatz."

TensorNetworkAdd::usage = "TensorNetworkAdd[tn, tensor, indices] adds a new tensor to the network with the specified indices.
\[Bullet] Indices matching existing network indices create new contractions."

TensorNetworkDelete::usage = "TensorNetworkDelete[tn, k] deletes the k-th tensor from the tensor network.
\[Bullet] TensorNetworkDelete[tn, -1] deletes the last tensor."


BinaryTensorNetwork::usage = "BinaryTensorNetwork[tn] transforms tn into a pairwise binary tn by adding SymbolicDeltaProductArray."

BinaryTensorNetworkQ::usage = "BinaryTensorNetworkQ[tn] returns True if tn is a pairwise binary tn."

SparseTensorNetwork::usage = "SparseTensorNetwork[tn] transforms tensors in tn into SparseArray."

(* ============================================ *)
(* ToTensorNetworkGraph.wl                     *)
(* ============================================ *)

TensorNetworkGraphQ::usage = "TensorNetworkGraphQ[net] yields True if net is a valid tensor network graph.
\[Bullet] TensorNetworkGraphQ[net, True] prints diagnostic messages for invalid networks."

TensorNetworkIndexGraph::usage = "TensorNetworkIndexGraph[net] returns a graph representing the index connectivity of the tensor network."

ToTensorNetworkGraph::usage = "ToTensorNetworkGraph[graph] constructs a tensor network graph from a directed acyclic graph.
\[Bullet] ToTensorNetworkGraph[tn] converts a TensorNetwork object to a graph representation.
\[Bullet] ToTensorNetworkGraph[graph, Method\[Rule]\"Symbolic\"] uses symbolic tensor representations."

TensorNetworkIndices::usage = "TensorNetworkIndices[net] returns the list of index specifications for each tensor vertex in the network graph."

TensorNetworkTensors::usage = "TensorNetworkTensors[net] returns the list of tensors stored in the network graph vertices."

TensorNetworkGraphData::usage = "TensorNetworkGraphData[net] returns an Association containing the raw data (tensors, indices, dimensions, contractions) of the network graph."

TensorNetworkIndexDimensions::usage = "TensorNetworkIndexDimensions[net] returns an Association mapping each index to its dimension.
\[Bullet] TensorNetworkIndexDimensions[indices, tensors] computes dimensions from explicit index and tensor lists."

TensorNetworkFreeIndices::usage = "TensorNetworkFreeIndices[net] returns the list of uncontracted (free/open) indices in the network."

TensorNetworkRemoveCycles::usage = "TensorNetworkRemoveCycles[net] inserts identity tensors to break any cycles in the network graph, making it acyclic."

TensorNetworkToNetGraph::usage = "TensorNetworkToNetGraph[net] converts the tensor network graph into a Wolfram Neural NetGraph."

TensorNetworkReplaceIndices::usage = "TensorNetworkReplaceIndices[net, {i\:2081\[Rule]j\:2081, i\:2082\[Rule]j\:2082, \[Ellipsis]}] replaces indices in the network according to the specified rules."

InitializeTensorNetwork::usage = "InitializeTensorNetwork[net, {t\:2081,t\:2082,\[Ellipsis]}] initializes a tensor network graph with numerical tensors."

(* ============================================ *)
(* Contraction.wl                              *)
(* ============================================ *)

TensorNetworkFindContractionPath::usage = "TensorNetworkFindContractionPath is deprecated. Use GreedyContractionPath or OptimalContractionPath instead."

GreedyContractionPath::usage = "GreedyContractionPath[tn] finds a contraction path using a greedy heuristic.
\[Bullet] GreedyContractionPath[graph] finds a path for a TensorNetwork graph.
\[Bullet] GreedyContractionPath[inputs, output, sizeDict] low-level form with explicit parameters.
\[Bullet] Options: \"MemoryWeight\", \"Temperature\", \"MaxNeighbors\", \"RandomSeed\", \"PreSimplify\", \"FixedIndexing\"."

OptimalContractionPath::usage = "OptimalContractionPath[tn] finds an optimal contraction path via dynamic programming.
\[Bullet] OptimalContractionPath[graph] finds an optimal path for a TensorNetwork graph.
\[Bullet] OptimalContractionPath[inputs, output, sizeDict] low-level form with explicit parameters.
\[Bullet] Options: Method (\"size\", \"flops\", \"max\", \"write\", \"combo\", \"limit\"), \"PruningThreshold\", \"AllowOuterProducts\", \"PreSimplify\", \"FixedIndexing\"."

TensorNetworkContraction::usage = "TensorNetworkContraction[tn, path] returns a symbolic contraction expression for the tensor network along the given path.
\[Bullet] TensorNetworkContraction[tn, treePath] uses a tree-structured contraction path.
\[Bullet] TensorNetworkContraction[tn, \"Greedy\"] automatically computes a greedy path.
\[Bullet] TensorNetworkContraction[tn, \"Optimal\"] automatically computes an optimal path.
\[Bullet] TensorNetworkContraction[\[Ellipsis], Method\[Rule]\"ArrayDot\"] specifies the contraction method."

TensorNetworkContract::usage = "TensorNetworkContract[tn] contracts the entire tensor network to a single tensor using the default path.
\[Bullet] TensorNetworkContract[tn, path] contracts using the specified contraction path.
\[Bullet] TensorNetworkContract[data, path] contracts using pre-computed network data.
\[Bullet] Returns an evaluated numerical tensor (not symbolic)."

$TensorNetworkContractionMethods::usage = "$TensorNetworkContractionMethods is the list of available contraction methods: \"ArrayDotTranspose\", \"ArrayDot\", \"Dot\", \"TensorContract\", \"TableSum\"."

ContractionTree::usage = "ContractionTree[tn] returns a Tree representing the contraction hierarchy of the tensor network.
\[Bullet] ContractionTree[tn, path] uses the specified contraction path."

(* ============================================ *)
(* MPS.wl                                      *)
(* ============================================ *)

MPSCanonicalForm::usage = "MPSCanonicalForm[mps] transforms an MPS tensor network into left-canonical form (default).
\[Bullet] MPSCanonicalForm[mps, \"Left\"] puts all tensors in left-isometric form where A\[ConjugateTranspose]\[CenterDot]A = I.
\[Bullet] MPSCanonicalForm[mps, \"Right\"] puts all tensors in right-isometric form where A\[CenterDot]A\[ConjugateTranspose] = I.
\[Bullet] MPSCanonicalForm[mps, {\"Mixed\", k}] creates mixed canonical form centered at site k."

MPSCanonicalQ::usage = "MPSCanonicalQ[mps, form] returns True if mps is in the specified canonical form.
\[Bullet] MPSCanonicalQ[mps, \"Left\"] checks left-canonical form.
\[Bullet] MPSCanonicalQ[mps, \"Right\"] checks right-canonical form.
\[Bullet] MPSCanonicalQ[mps, {\"Mixed\", k}] checks mixed-canonical form at site k.
\[Bullet] Uses tolerance 10^-10 for numerical comparison."

MPSOverlap::usage = "MPSOverlap[mps\:2081, mps\:2082] computes the inner product \[LeftAngleBracket]\[Psi]\:2081|\[Psi]\:2082\[RightAngleBracket] between two MPS.
\[Bullet] The second MPS is conjugated in the inner product.
\[Bullet] MPSOverlap[mps, mps] returns the squared norm of the MPS."

MPSNorm::usage = "MPSNorm[mps] computes the norm \[LeftDoubleBracketingBar]\[Psi]\[RightDoubleBracketingBar] of an MPS.
\[Bullet] Equivalent to Sqrt[Abs[MPSOverlap[mps, mps]]]."

MPSNormalize::usage = "MPSNormalize[mps] returns an MPS normalized to unit norm.
\[Bullet] After normalization, MPSNorm[result] \[TildeEqual] 1.0.
\[Bullet] The physical state is preserved; only the overall scale factor changes."

MPSEntanglementEntropy::usage = "MPSEntanglementEntropy[mps, site] computes the von Neumann entanglement entropy S = -\[Sum] p log(p) at the bond between site and site+1.
\[Bullet] Returns 0 for a product state.
\[Bullet] Returns log(D) for a maximally entangled state with bond dimension D.
\[Bullet] Uses natural logarithm."

MPSSchmidtValues::usage = "MPSSchmidtValues[mps, site] returns the normalized Schmidt coefficients \[Lambda]\:1d62 at the bond between site and site+1.
\[Bullet] The values satisfy \[Sum] \[Lambda]\:1d62^2 = 1.
\[Bullet] Number of values equals the bond dimension at that cut."

MPSTruncate::usage = "MPSTruncate[mps, maxBond] compresses an MPS by truncating all bonds to at most maxBond.
\[Bullet] The result is in left-canonical form.
\[Bullet] Truncation error depends on discarded singular values."

(* ============================================ *)
(* Paths.wl                                    *)
(* ============================================ *)

GreedyContractionPath::usage = "GreedyContractionPath[inputs, output, sizeDict] finds a contraction path using a greedy heuristic.
\[Bullet] inputs is a list of index lists for each tensor.
\[Bullet] output is the list of indices for the final result.
\[Bullet] sizeDict is an Association mapping indices to their dimensions.
\[Bullet] Also accepts TensorNetwork or inactive TensorContract/Transpose expressions from TensorNetworkContraction.
\[Bullet] Options: \"MemoryWeight\", \"Temperature\", \"MaxNeighbors\", \"RandomSeed\", \"PreSimplify\", \"FixedIndexing\"."

OptimalContractionPath::usage = "OptimalContractionPath[inputs, output, sizeDict] finds an optimal contraction path via dynamic programming.
\[Bullet] inputs is a list of index lists for each tensor.
\[Bullet] output is the list of indices for the final result.
\[Bullet] sizeDict is an Association mapping indices to their dimensions.
\[Bullet] Also accepts TensorNetwork or inactive TensorContract/Transpose expressions from TensorNetworkContraction.
\[Bullet] Options: Method (default \"size\"), \"PruningThreshold\", \"AllowOuterProducts\", \"PreSimplify\", \"FixedIndexing\"."

ContractIndices::usage = "ContractIndices[i, j] returns the list of indices that would be contracted between index sets i and j."

TreePathToPath::usage = "TreePathToPath[treePath, indices] converts a tree-structured contraction path to a linear (pairwise) path representation."

PathToTreePath::usage = "PathToTreePath[path, indices] converts a linear contraction path to a tree-structured path representation."

CanonicalPath::usage = "CanonicalPath[path, indices] returns a canonical (normalized) representation of the contraction path."

PathIndexContractions::usage = "PathIndexContractions[path, indices] returns the sequence of index sets contracted at each step of the path."

PathQ::usage = "PathQ[path] returns True if path is a contraction path."

CanonicalPathQ::usage = "CanonicalPathQ[path] returns True if path is a canonical contraction path (list of integer pairs)."

TreePathQ::usage = "TreePathQ[treePath] returns True if treePath is a tree-like contraction path."


