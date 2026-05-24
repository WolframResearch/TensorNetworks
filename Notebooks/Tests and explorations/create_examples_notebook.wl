(* Generate TensorNetworks Comprehensive Examples Notebook *)
(* This script creates a properly formatted .nb file with runnable examples *)

SetDirectory[NotebookDirectory[] /. $Failed -> "/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation"];

(* Common setup code that must be run first *)
commonSetup = "
(* Load the TensorNetworks package *)
Needs[\"Wolfram`TensorNetworks`\"];

(* Set random seed for reproducibility *)
SeedRandom[1];

(* === Basic Tensors === *)
(* 2x3 matrix *)
A = RandomReal[1, {2, 3}];
(* 3x4 matrix *)
B = RandomReal[1, {3, 4}];
(* 4x2 matrix for cyclic contraction *)
CC = RandomReal[1, {4, 2}];
(* 2x2 square matrix *)
DD = RandomReal[1, {2, 2}];
(* Complex matrix *)
EE = RandomComplex[{-1 - I, 1 + I}, {2, 2}];

(* === Index symbols === *)
(* Named indices for readable contractions *)
{i, j, k, l, m, n, p, q} = Table[Symbol[\"idx\" <> ToString[x]], {x, 8}];

(* === Basic TensorNetwork objects === *)
(* Cyclic contraction network: A(i,j) B(j,k) C(k,i) *)
indices = {{i, j}, {j, k}, {k, i}};
tn = TensorNetwork[{A, B, CC}, indices];

(* Graph representation *)
g = ToTensorNetworkGraph[tn];

(* Extract network data *)
data = TensorNetworkData[tn];

(* Find contraction path *)
path = OptimalContractionPath[tn];
treePath = PathToTreePath[path, data[\"Vertices\"]];

(* === MPS (Matrix Product State) networks === *)
(* Open boundary MPS: 5 sites, bond dim 3, physical dim 2 *)
mps = RandomTensorNetwork[\"MPS\"[5, 3, 2]];
(* Periodic boundary MPS *)
mps2 = RandomTensorNetwork[\"MPS\"[5, 3, 2], \"Boundary\" -> \"Periodic\"];

(* === Size dictionary for path algorithms === *)
sizeDict = <|i -> 2, j -> 3, k -> 4, l -> 2, m -> 2, n -> 3|>;

(* === Young tableaux for symmetry operations === *)
yt1 = YoungTableau[{{1, 2}, {3}}];
yt2 = YoungTableau[{2, 1}];

(* === Rank-3 tensor for symmetry examples === *)
t3 = RandomReal[1, {2, 2, 2}];

(* === Cyclic graph for cycle removal examples === *)
cyc = ToTensorNetworkGraph[{A, B, CC}, {{1, 2}, {2, 3}, {3, 1}}];

Print[\"Setup complete. All variables initialized.\"];
";

(* Define all examples with explanations *)
sections = {

(* EinsteinSummation *)
{"EinsteinSummation",
"EinsteinSummation performs tensor contractions using Einstein summation convention. Repeated indices are summed over (contracted), while unique indices remain free in the output.",
{
{"Basic Index Notation", "Use nested lists to specify indices for each tensor. The arrow notation specifies output indices.", {
{"Matrix multiplication A.B using index notation. A has indices {i,j}, B has indices {j,k}, output has {i,k}. Index j is repeated so it gets contracted.",
"EinsteinSummation[{{i, j}, {j, k}} -> {i, k}, {A, B}]"},
{"Matrix multiplication without explicit output. Free indices appear in order of first occurrence.",
"EinsteinSummation[{{i, j}, {j, k}}, {A, B}]"}
}},
{"String Notation (NumPy-style)", "Use string notation similar to NumPy's einsum for compact expressions.", {
{"Matrix multiplication using string notation: tensor 1 has indices ij, tensor 2 has jk, output is ik.",
"EinsteinSummation[\"ij,jk->ik\", {A, B}]"},
{"String notation without explicit output. Free indices kept, contracted indices summed.",
"EinsteinSummation[\"ij,jk\", {A, B}]"}
}},
{"Trace and Full Contraction", "Contract all indices to produce a scalar result.", {
{"Full contraction of three matrices into a scalar (Tr[A.B.C]).",
"EinsteinSummation[{{i, j}, {j, k}, {k, i}} -> {}, {A, B, CC}]"},
{"Trace: diagonal elements are summed.",
"EinsteinSummation[{{i, i}}, {DD}]"}
}},
{"Scalar and Vector Operations", "Handle scalars and vectors.", {
{"Multiply two scalars. Empty index lists {} indicate scalars.",
"EinsteinSummation[{{}, {}}, {1.2, 3.4}]"},
{"Dot product of two vectors.",
"EinsteinSummation[{{i}, {i}}, {A[[All, 1]], A[[All, 2]]}]"},
{"Outer product: different indices mean no contraction.",
"EinsteinSummation[{{i}, {j}} -> {i, j}, {Range[3], Range[4]}]"}
}},
{"Sparse Arrays and Advanced", "Handle sparse arrays and batch operations.", {
{"Matrix multiply with sparse input.",
"EinsteinSummation[{{i, j}, {j, k}}, {SparseArray[A], B}]"},
{"Using Characters to create index lists.",
"EinsteinSummation[{Characters /@ {\"ij\", \"jk\"}} -> Characters[\"ik\"], {A, B}]"},
{"Batch matrix multiply (keep batch dimension b).",
"X = RandomReal[1, {5, 2, 3}]; Y = RandomReal[1, {5, 3, 4}];\nEinsteinSummation[\"bij,bjk->bik\", {X, Y}]"},
{"Tensor contraction of rank-3 tensors.",
"T1 = RandomReal[1, {2, 3, 4}]; T2 = RandomReal[1, {4, 3, 2}];\nEinsteinSummation[{{i, j, k}, {k, j, l}} -> {i, l}, {T1, T2}]"}
}}
}},

(* IndexedMultiply *)
{"IndexedMultiply",
"IndexedMultiply performs tensor contraction and returns both the resulting index structure and the contracted tensor as {indices, tensor}.",
{
{"Basic Contractions", "Contract tensors and get both indices and result.", {
{"Matrix multiplication returning {indices, result}.",
"IndexedMultiply[{{i, j}, {j, k}}, {A, B}]"},
{"Vector dot product. All indices contract, returns empty index list with scalar.",
"IndexedMultiply[{{i}, {i}}, {A[[All, 1]], A[[All, 2]]}]"},
{"Chain of three matrices A(i,j) * B(j,k) * C(k,l).",
"IndexedMultiply[{{i, j}, {j, k}, {k, l}}, {A, B, RandomReal[1, {4, 5}]}]"}
}},
{"Element-wise and Special Operations", "Handle element-wise products and special cases.", {
{"Element-wise product (Hadamard): same indices on both tensors.",
"IndexedMultiply[{{i, j, k}, {i, j, k}}, {RandomReal[1, {2, 3, 4}], RandomReal[1, {2, 3, 4}]}]"},
{"Element-wise with sparse arrays.",
"IndexedMultiply[{{i, j}, {i, j}}, {SparseArray[A], SparseArray[A]}]"},
{"Multiply two scalars.",
"IndexedMultiply[{{}, {}}, {3., 5.}]"}
}},
{"Advanced Patterns", "Transpose, diagonal, symbolic, and outer products.", {
{"Implicit transpose: A(i,j) * A^T(j,i) gives A.A^T.",
"IndexedMultiply[{{i, j}, {j, i}}, {A, Transpose[A]}]"},
{"Contract diagonal matrices.",
"IndexedMultiply[{{i, i}, {i, i}}, {DiagonalMatrix[{1, 2}], DiagonalMatrix[{3, 4}]}]"},
{"Symbolic array multiplication with ArraySymbol.",
"IndexedMultiply[{{i, j}, {j, k}}, {ArraySymbol[\"T\", {2, 3}], ArraySymbol[\"S\", {3, 4}]}]"},
{"Outer product: no shared indices, result is tensor product.",
"IndexedMultiply[{{i}, {j}}, {Range[5], Range[6]}]"}
}}
}},

(* ActivateTensors *)
{"ActivateTensors",
"ActivateTensors evaluates inactive tensor expressions. Use this to execute symbolic contraction expressions created with \"Inactive\" -> True.",
{
{"Activating Contractions", "Evaluate inactive tensor operations.", {
{"Create inactive contraction then activate it.",
"exprInactive = TensorNetworkContraction[tn, path, \"Inactive\" -> True];\nActivateTensors[exprInactive]"},
{"Activate a simple TensorContract expression.",
"ActivateTensors[Inactive[TensorContract][Inactive[TensorProduct][A, B], {{2, 3}}]]"},
{"Activate with transpose.",
"ActivateTensors[Inactive[Transpose][Inactive[TensorContract][Inactive[TensorProduct][A, B], {{2, 3}}], Cycles[{{1, 2}}]]]"}
}},
{"Products and Complex Expressions", "Handle tensor products and nested expressions.", {
{"Activate tensor product.",
"ActivateTensors[Inactive[TensorProduct][A, B, CC]]"},
{"Activate with delta product.",
"ActivateTensors[Inactive[TensorProduct][SymbolicDeltaProductArray[{2, 2}, {{1, 2}}], A]]"},
{"Activate a trace contraction.",
"ActivateTensors[Inactive[TensorContract][t3, {{1, 2}}]]"},
{"Chain contraction activation.",
"ActivateTensors[Inactive[TensorContract][Inactive[TensorProduct][A, B, CC], {{2, 3}, {4, 5}}]]"},
{"Generalized power activation.",
"ActivateTensors[Inactive[GeneralizedPower][TensorProduct, A, 2]]"},
{"Replace and reactivate.",
"ActivateTensors[exprInactive /. Inactive[TensorContract][x_, y_] :> Inactive[TensorContract][x, y]]"},
{"Build and activate custom expression.",
"customExpr = Inactive[TensorContract][Inactive[TensorProduct][DD, DD], {{2, 3}}];\nActivateTensors[customExpr]"}
}}
}},

(* TensorNetwork *)
{"TensorNetwork",
"TensorNetwork creates a tensor network object from tensors and their index structure. Supports multiple input formats.",
{
{"Basic Construction", "Create networks from tensors and indices.", {
{"From tensors and integer edge lists.",
"TensorNetwork[{A, B}, {{1, 2}, {2, 3}}]"},
{"Named indices with explicit output (arrow notation).",
"TensorNetwork[{A, B}, {{i, j}, {j, k}} -> {i, k}]"},
{"With output permutation (Cycles specify permutation).",
"TensorNetwork[{A, B}, {{i, j}, {j, k}}, Cycles[{{1, 2}}]]"},
{"Full cyclic contraction (trace-like).",
"TensorNetwork[{A, B, CC}, indices]"}
}},
{"From Mathematica Expressions", "Create from standard tensor operations.", {
{"From TensorContract expression.",
"TensorNetwork[TensorContract[TensorProduct[A, B], {{2, 3}}]]"},
{"From transposed contraction.",
"TensorNetwork[Transpose[TensorContract[TensorProduct[A, B], {{2, 3}}], Cycles[{{1, 2}}]]]"}
}},
{"From Graphs and Hypergraphs", "Create from graph structures.", {
{"From TensorNetworkGraph.",
"TensorNetwork[g]"},
{"From hypergraph structure only (no tensors).",
"TensorNetwork[{{1, 2}, {2, 3}}]"},
{"Hypergraph with output specification.",
"TensorNetwork[{{1, 2}, {2, 3}} -> {1, 3}]"},
{"With ArraySymbol placeholders.",
"TensorNetwork[{ArraySymbol[\"X\", {2, 2}], ArraySymbol[\"Y\", {2, 2}]}, {{1, 2}, {2, 3}}]"}
}},
{"Accessing Properties", "Query network properties.", {
{"Access all network properties.",
"tn[\"Properties\"]"},
{"Get tensors.",
"tn[\"Tensors\"]"},
{"Get hyperedges (index structure).",
"tn[\"Hyperedges\"]"},
{"Get indices.",
"tn[\"Indices\"]"},
{"Get free (uncontracted) indices.",
"tn[\"FreeIndices\"]"},
{"Get tensor dimensions.",
"tn[\"Dimensions\"]"},
{"Get network size (number of tensors).",
"tn[\"Size\"]"}
}}
}},

(* TensorNetworkQ *)
{"TensorNetworkQ",
"TensorNetworkQ tests whether an expression is a valid TensorNetwork with consistent dimensions.",
{
{"Validation Tests", "Test various network types.", {
{"Test valid network.",
"TensorNetworkQ[tn]"},
{"Test network with self-loop (trace).",
"TensorNetworkQ[TensorNetwork[{A}, {{1, 1}}]]"},
{"Test network without contraction.",
"TensorNetworkQ[TensorNetwork[{A}, {{1, 2}}]]"},
{"Test non-network object.",
"TensorNetworkQ[\"not a network\"]"},
{"Test binary network.",
"TensorNetworkQ[TensorNetwork[{A, B}, {{1, 2}, {2, 3}}]]"},
{"Test with permutation.",
"TensorNetworkQ[TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, Cycles[{{1, 2}}]]]"},
{"Test with Automatic permutation.",
"TensorNetworkQ[TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, Automatic]]"},
{"Test after adding tensor.",
"TensorNetworkQ[TensorNetworkAdd[tn, DD, {m, n}]]"},
{"Test after deleting tensor.",
"TensorNetworkQ[TensorNetworkDelete[tn, -1]]"}
}}
}},

(* TensorNetworkData *)
{"TensorNetworkData",
"TensorNetworkData extracts structural data from a tensor network as an Association.",
{
{"Data Extraction", "Extract data from various network types.", {
{"Data from basic network.",
"TensorNetworkData[tn]"},
{"Data from binary network.",
"TensorNetworkData[BinaryTensorNetwork[tn]]"},
{"Data from sparse network.",
"TensorNetworkData[SparseTensorNetwork[tn]]"},
{"Data after adding tensor.",
"TensorNetworkData[TensorNetworkAdd[tn, DD, {m, n}]]"},
{"Data after deleting tensor.",
"TensorNetworkData[TensorNetworkDelete[tn, -1]]"},
{"Data from random network.",
"TensorNetworkData[RandomTensorNetwork[{4, 4}, 3]]"},
{"Data from closed loop network.",
"TensorNetworkData[TensorNetwork[{A, B}, {{i, j}, {j, i}}]]"},
{"Data from scalar network.",
"TensorNetworkData[TensorNetwork[{A}, {{}}]]"},
{"Data from integer-indexed network.",
"TensorNetworkData[TensorNetwork[{A, B}, {{1, 2}, {2, 1}}]]"},
{"Data with symbolic arrays.",
"TensorNetworkData[TensorNetwork[{ArraySymbol[\"X\", {2, 2}], ArraySymbol[\"Y\", {2, 2}]}, {{1, 2}, {2, 3}}]]"}
}}
}},

(* RandomTensorNetwork *)
{"RandomTensorNetwork",
"RandomTensorNetwork generates random tensor networks with various structures including MPS, MPO, TT, PEPS, TTN, and MERA.",
{
{"Random Graph Networks", "Create random networks from graph specifications.", {
{"{6, 8} = 6 vertices, 8 edges; 4 = max bond dimension.",
"RandomTensorNetwork[{6, 8}, 4]"},
{"Fixed bond dimension (exactly 3 for all bonds).",
"RandomTensorNetwork[{6, 8}, {3}]"},
{"With additional physical dimensions (extra legs).",
"RandomTensorNetwork[{6, 8}, 4, 1]"},
{"Complex-valued random network.",
"RandomTensorNetwork[{6, 8}, {3}, 2, Method -> \"Complex\"]"},
{"From explicit graph.",
"RandomTensorNetwork[RandomGraph[{6, 8}], 4]"},
{"Complex from explicit graph.",
"RandomTensorNetwork[RandomGraph[{6, 8}], {3}, 1, Method -> \"Complex\"]"}
}},
{"Matrix Product States (MPS)", "1D chain tensor networks.", {
{"Open boundary MPS: MPS[length, bondDim, physicalDim].",
"RandomTensorNetwork[\"MPS\"[6, 3, 2]]"},
{"Periodic MPS (ring).",
"RandomTensorNetwork[\"MPS\"[6, 3, 2], \"Boundary\" -> \"Periodic\"]"}
}},
{"Other Architectures", "TT, MPO, and other structures.", {
{"Tensor Train (MPS without physical legs).",
"RandomTensorNetwork[\"TT\"[6, 3]]"},
{"Matrix Product Operator (input and output physical indices).",
"RandomTensorNetwork[\"MPO\"[4, 2, 2]]"}
}}
}},

(* TensorNetworkAdd and TensorNetworkDelete *)
{"TensorNetworkAdd and TensorNetworkDelete",
"TensorNetworkAdd appends a tensor with specified indices. TensorNetworkDelete removes a tensor by index.",
{
{"TensorNetworkAdd", "Add tensors to networks.", {
{"Add a 2x2 matrix with new indices.",
"TensorNetworkAdd[tn, DD, {m, n}]"},
{"Add rank-3 tensor.",
"TensorNetworkAdd[tn, RandomReal[1, {2, 2, 2}], {m, n, k}]"},
{"Add complex tensor with existing indices.",
"TensorNetworkAdd[tn, RandomComplex[{-1 - I, 1 + I}, {2, 2}], {i, j}]"},
{"Add to modified network.",
"TensorNetworkAdd[TensorNetworkDelete[tn, -1], CC, {k, i}]"},
{"Build chain incrementally.",
"TensorNetworkAdd[TensorNetwork[{A}, {{i, j}}], B, {j, k}]"},
{"Add with integer indices.",
"TensorNetworkAdd[TensorNetwork[{A, B}, {{1, 2}, {2, 3}}], CC, {3, 1}]"},
{"Add symbolic array.",
"TensorNetworkAdd[tn, ArraySymbol[\"New\", {2, 2}], {p, q}]"}
}},
{"TensorNetworkDelete", "Remove tensors from networks.", {
{"Delete last tensor.",
"TensorNetworkDelete[tn, -1]"},
{"Delete first tensor.",
"TensorNetworkDelete[tn, 1]"},
{"Delete from augmented network.",
"TensorNetworkDelete[TensorNetworkAdd[tn, DD, {m, n}], 4]"},
{"Delete middle tensor.",
"TensorNetworkDelete[TensorNetwork[{A, B, CC}, indices], 2]"},
{"Delete with integer indices.",
"TensorNetworkDelete[TensorNetwork[{A, B, CC}, {{1, 2}, {2, 3}, {3, 1}}], 2]"}
}}
}},

(* BinaryTensorNetwork and SparseTensorNetwork *)
{"BinaryTensorNetwork and SparseTensorNetwork",
"BinaryTensorNetwork converts to binary (degree 2) hyperedges. SparseTensorNetwork converts tensors to SparseArray format.",
{
{"BinaryTensorNetwork", "Convert to binary form.", {
{"Convert to binary form.",
"BinaryTensorNetwork[tn]"},
{"Binary from closed loop.",
"BinaryTensorNetwork[TensorNetwork[{A, B}, {{i, j}, {j, i}}]]"},
{"Binary from random network.",
"BinaryTensorNetwork[RandomTensorNetwork[{5, 5}, 3]]"},
{"Binary from sparse network.",
"BinaryTensorNetwork[SparseTensorNetwork[tn]]"},
{"Binary from augmented network.",
"BinaryTensorNetwork[TensorNetworkAdd[tn, DD, {m, n}]]"}
}},
{"BinaryTensorNetworkQ", "Test if network is binary.", {
{"Test if network is binary.",
"BinaryTensorNetworkQ[tn]"},
{"Test converted binary network.",
"BinaryTensorNetworkQ[BinaryTensorNetwork[tn]]"},
{"Test simple binary network.",
"BinaryTensorNetworkQ[TensorNetwork[{A, B}, {{1, 2}, {2, 3}}]]"}
}},
{"SparseTensorNetwork", "Convert to sparse tensors.", {
{"Convert to sparse tensors.",
"SparseTensorNetwork[tn]"},
{"Sparse from already sparse input.",
"SparseTensorNetwork[TensorNetwork[{SparseArray[A]}, {{1, 2}}]]"}
}}
}},

(* ToTensorNetworkGraph *)
{"ToTensorNetworkGraph",
"ToTensorNetworkGraph creates a graph representation where vertices are tensors and edges are contractions.",
{
{"Graph Creation", "Create graphs from various inputs.", {
{"Convert TensorNetwork to graph.",
"ToTensorNetworkGraph[tn]"},
{"From tensors and indices directly.",
"ToTensorNetworkGraph[{A, B}, {{1, 2}, {2, 3}}]"},
{"Symbolic method - creates symbolic placeholders.",
"ToTensorNetworkGraph[{A, B}, {{1, 2}, {2, 3}}, Method -> \"Symbolic\"]"},
{"From directed graph with symbolic method.",
"ToTensorNetworkGraph[DirectedGraph[{1 -> 2, 2 -> 3}], Method -> \"Symbolic\"]"},
{"Random method with vertex labels.",
"ToTensorNetworkGraph[Graph[{1 <-> 2, 2 <-> 3}], Method -> \"Random\", VertexLabels -> \"Name\"]"},
{"Zero initialization.",
"ToTensorNetworkGraph[DirectedGraph[{1 -> 2}], Method -> \"Zero\"]"},
{"Complex random initialization.",
"ToTensorNetworkGraph[DirectedGraph[{1 -> 2}], Method -> \"RandomComplex\"]"},
{"Full cyclic network graph.",
"ToTensorNetworkGraph[{A, B, CC}, indices]"},
{"Scalar tensor graph.",
"ToTensorNetworkGraph[{A}, {{}}]"},
{"With automatic vertex labels.",
"ToTensorNetworkGraph[tn, VertexLabels -> Automatic]"}
}}
}},

(* Graph Analysis Functions *)
{"Graph Analysis Functions",
"Functions to analyze and validate tensor network graph structures.",
{
{"TensorNetworkGraphQ", "Test graph validity.", {
{"Test valid tensor network graph.",
"TensorNetworkGraphQ[g]"},
{"Verbose validation.",
"TensorNetworkGraphQ[g, True]"},
{"Curried form with verbose.",
"TensorNetworkGraphQ[True][g]"},
{"Test random graph (likely invalid).",
"TensorNetworkGraphQ[RandomGraph[{3, 2}], True]"},
{"Test graph without cycles.",
"TensorNetworkGraphQ[TensorNetworkRemoveCycles[cyc]]"}
}},
{"TensorNetworkIndexGraph", "Create index connectivity graph.", {
{"Create index connectivity graph.",
"TensorNetworkIndexGraph[g]"},
{"Index graph with vertex labels.",
"TensorNetworkIndexGraph[g, VertexLabels -> Automatic]"},
{"Index graph with edge labels.",
"TensorNetworkIndexGraph[g, EdgeLabels -> Automatic]"},
{"Index graph from binary network.",
"TensorNetworkIndexGraph[BinaryTensorNetwork[tn][\"Graph\"]]"},
{"Index graph with custom size.",
"TensorNetworkIndexGraph[ToTensorNetworkGraph[{A, B}, {{1, 2}, {2, 1}}], ImageSize -> Small]"}
}}
}},

(* Graph Data Extraction *)
{"Graph Data Extraction",
"Functions to extract tensors, indices, and structural data from tensor network graphs.",
{
{"TensorNetworkIndices", "Get index lists.", {
{"Get indices from graph.",
"TensorNetworkIndices[g]"},
{"Get indices from TensorNetwork.",
"TensorNetworkIndices[tn]"},
{"Indices after cycle removal.",
"TensorNetworkIndices[TensorNetworkRemoveCycles[cyc]]"}
}},
{"TensorNetworkTensors", "Get tensor lists.", {
{"Get tensors from graph.",
"TensorNetworkTensors[g]"},
{"Get tensors from TensorNetwork.",
"TensorNetworkTensors[tn]"},
{"Tensors after modification.",
"TensorNetworkTensors[TensorNetworkAdd[tn, DD, {m, n}][\"Graph\"]]"}
}},
{"TensorNetworkGraphData", "Get full graph data.", {
{"Full graph data.",
"TensorNetworkGraphData[g]"},
{"Data from TensorNetwork.",
"TensorNetworkGraphData[tn]"},
{"Data after cycle removal.",
"TensorNetworkGraphData[TensorNetworkRemoveCycles[cyc]]"}
}},
{"TensorNetworkIndexDimensions", "Get dimension of each index.", {
{"Index dimensions from graph.",
"TensorNetworkIndexDimensions[g]"},
{"Index dimensions from TensorNetwork.",
"TensorNetworkIndexDimensions[tn]"},
{"From explicit indices and tensors.",
"TensorNetworkIndexDimensions[{{i, j}, {j, k}}, {A, B}]"}
}},
{"TensorNetworkFreeIndices", "Get uncontracted indices.", {
{"Free indices from graph.",
"TensorNetworkFreeIndices[g]"},
{"Free indices from TensorNetwork.",
"TensorNetworkFreeIndices[tn]"},
{"Free indices from index list.",
"TensorNetworkFreeIndices[{{a, b}, {b, c}, {c}}]"}
}}
}},

(* Graph Transformations *)
{"Graph Transformations",
"Functions to transform and modify tensor network graphs.",
{
{"TensorNetworkRemoveCycles", "Make directed graph acyclic.", {
{"Remove cycles from cyclic graph.",
"TensorNetworkRemoveCycles[cyc]"},
{"Remove cycles from closed loop.",
"TensorNetworkRemoveCycles[ToTensorNetworkGraph[{A, B}, {{1, 2}, {2, 1}}]]"},
{"From simple cycle graph.",
"TensorNetworkRemoveCycles[Graph[{1 -> 2, 2 -> 3, 3 -> 1}]]"},
{"Three-tensor cycle.",
"TensorNetworkRemoveCycles[ToTensorNetworkGraph[{A, B, CC}, {{1, 2}, {2, 3}, {3, 1}}]]"},
{"With vertex labels.",
"TensorNetworkRemoveCycles[ToTensorNetworkGraph[{A, B}, {{1, 2}, {2, 1}}], VertexLabels -> Automatic]"}
}},
{"TensorNetworkReplaceIndices", "Substitute indices in graph.", {
{"Replace specific index.",
"TensorNetworkReplaceIndices[g, {Superscript[1, 1] -> Superscript[1, 10]}]"},
{"Replace subscript index.",
"TensorNetworkReplaceIndices[g, {Subscript[2, 1] -> Subscript[2, 5]}]"},
{"Identity replacement (no change).",
"TensorNetworkReplaceIndices[g, {Superscript[1, 1] -> Superscript[1, 1]}]"}
}},
{"InitializeTensorNetwork", "Add initial tensor node.", {
{"Initialize with given tensor.",
"InitializeTensorNetwork[g, DD]"},
{"Initialize with Automatic index selection.",
"InitializeTensorNetwork[g, DD, Automatic]"},
{"Initialize with specific indices.",
"InitializeTensorNetwork[g, DD, {Superscript[0, 1], Superscript[0, 2]}]"}
}}
}},

(* Contraction Path Finding *)
{"Contraction Path Finding",
"Functions to find optimal or near-optimal contraction orders for tensor networks.",
{
{"GreedyContractionPath", "Fast heuristic path finding.", {
{"Find greedy path from TensorNetwork.",
"GreedyContractionPath[tn]"},
{"Find greedy path from graph.",
"GreedyContractionPath[g]"},
{"Find greedy path from data.",
"GreedyContractionPath[data]"},
{"Low-level form with explicit parameters.",
"GreedyContractionPath[{{i, j}, {j, k}, {k, l}}, {i, l}, sizeDict]"},
{"With custom options.",
"GreedyContractionPath[{{i, j}, {j, k}}, {i, k}, sizeDict, \"MemoryWeight\" -> 1., \"Temperature\" -> 0.1]"},
{"From random network.",
"GreedyContractionPath[RandomTensorNetwork[{5, 6}, 3]]"},
{"From closed loop.",
"GreedyContractionPath[TensorNetwork[{A, B}, {{i, j}, {j, i}}]]"},
{"From cyclic network.",
"GreedyContractionPath[TensorNetwork[{A, B, CC}, indices]]"},
{"From binary network.",
"GreedyContractionPath[BinaryTensorNetwork[tn]]"},
{"Full contraction (empty output).",
"GreedyContractionPath[{{i, j}, {j, k}, {k, i}}, {}, sizeDict]"}
}},
{"OptimalContractionPath", "Exact optimal path finding.", {
{"Find optimal path from TensorNetwork.",
"OptimalContractionPath[tn]"},
{"Find optimal path from graph.",
"OptimalContractionPath[g]"},
{"Find optimal path from data.",
"OptimalContractionPath[data]"},
{"Low-level form with explicit parameters.",
"OptimalContractionPath[{{i, j}, {j, k}, {k, l}}, {i, l}, sizeDict]"},
{"With size Method.",
"OptimalContractionPath[{{i, j}, {j, k}}, {i, k}, sizeDict, Method -> \"size\"]"},
{"With flops Method.",
"OptimalContractionPath[{{i, j}, {j, k}, {k, i}}, {}, sizeDict, Method -> \"flops\"]"},
{"From random network.",
"OptimalContractionPath[RandomTensorNetwork[{5, 6}, 3]]"},
{"From closed loop.",
"OptimalContractionPath[TensorNetwork[{A, B}, {{i, j}, {j, i}}]]"},
{"From cyclic network with flops method.",
"OptimalContractionPath[TensorNetwork[{A, B, CC}, indices], Method -> \"flops\"]"},
{"From binary network.",
"OptimalContractionPath[BinaryTensorNetwork[tn], Method -> \"size\"]"}
}},
{"$TensorNetworkContractionMethods", "List available contraction methods.", {
{"List all available methods.",
"$TensorNetworkContractionMethods"},
{"Check if ArrayDot is available.",
"MemberQ[$TensorNetworkContractionMethods, \"ArrayDot\"]"},
{"Count available methods.",
"Length[$TensorNetworkContractionMethods]"}
}}
}},

(* Tensor Network Contraction *)
{"Tensor Network Contraction",
"Functions to perform tensor contraction, producing symbolic expressions or evaluated results.",
{
{"TensorNetworkContraction (Symbolic)", "Create inactive/symbolic contraction expressions.", {
{"Inactive contraction with ArrayDotTranspose.",
"TensorNetworkContraction[tn, path, Method -> \"ArrayDotTranspose\", \"Inactive\" -> True]"},
{"Inactive with TensorContract method.",
"TensorNetworkContraction[data, treePath, Method -> \"TensorContract\", \"Inactive\" -> True]"},
{"Using Greedy path finding.",
"TensorNetworkContraction[tn, \"Greedy\"]"},
{"Using Optimal path finding.",
"TensorNetworkContraction[tn, \"Optimal\"]"},
{"Dot method inactive.",
"TensorNetworkContraction[data, Method -> \"Dot\", \"Inactive\" -> True]"},
{"TableSum method inactive.",
"TensorNetworkContraction[data, Method -> \"TableSum\", \"Inactive\" -> True]"},
{"Custom transpose function.",
"TensorNetworkContraction[tn, path, \"TransposeFunction\" -> Transpose, \"Inactive\" -> True]"},
{"Closed loop contraction.",
"TensorNetworkContraction[TensorNetwork[{A, B}, {{i, j}, {j, i}}], Method -> \"ArrayDot\", \"Inactive\" -> True]"},
{"Scalar network contraction.",
"TensorNetworkContraction[TensorNetwork[{A}, {{}}]]"},
{"Binary network with Greedy.",
"TensorNetworkContraction[BinaryTensorNetwork[tn], \"Greedy\"]"}
}},
{"TensorNetworkContract (Evaluated)", "Evaluate contractions directly.", {
{"Evaluate contraction directly.",
"TensorNetworkContract[tn]"},
{"With specific path and method.",
"TensorNetworkContract[tn, path, Method -> \"ArrayDot\"]"},
{"TensorContract method.",
"TensorNetworkContract[data, path, Method -> \"TensorContract\"]"},
{"Greedy path evaluation.",
"TensorNetworkContract[tn, \"Greedy\"]"},
{"Optimal path evaluation.",
"TensorNetworkContract[tn, \"Optimal\"]"}
}},
{"ContractionTree (Visualization)", "Visualize contractions as trees.", {
{"Visualize contraction as tree.",
"ContractionTree[TensorNetworkContraction[tn, path, \"Inactive\" -> True]]"},
{"Tree with dimension labels.",
"ContractionTree[TensorNetworkContraction[tn, \"Greedy\", \"Inactive\" -> True], \"Labels\" -> \"Dimensions\"]"},
{"Tree with custom size.",
"ContractionTree[TensorNetworkContraction[tn, \"Greedy\", \"Inactive\" -> True], ImageSize -> Medium]"},
{"Tree with layout options.",
"ContractionTree[TensorNetworkContraction[TensorNetwork[{A, B, CC}, indices], \"Inactive\" -> True], TreeLayout -> Right]"},
{"Tree with style options.",
"ContractionTree[TensorNetworkContraction[tn, path, \"Inactive\" -> True], TreeElementLabelStyle -> {All -> FontSize -> 6}]"}
}}
}},

(* Path Operations *)
{"Path Operations",
"Low-level functions for manipulating contraction paths.",
{
{"Path Validation", "Test path validity.", {
{"Test tree path validity.",
"TreePathQ[{{1}, {2}}]"},
{"Test empty path.",
"TreePathQ[{}]"},
{"Test nested tree path.",
"TreePathQ[{{{1}, {2}}, {{3}}}]"},
{"Test path validity.",
"PathQ[{{1, 2}, {1, 2}}]"},
{"Test canonical path validity.",
"CanonicalPathQ[{{1, 2}, {1, 2}}]"}
}},
{"Path Conversion", "Convert between path formats.", {
{"Convert tree path to canonical path.",
"TreePathToPath[{{1}, {2}}]"},
{"Tree to path with vertex labels.",
"TreePathToPath[{{1}, {2}}, {a, b}]"},
{"Convert canonical path to tree path.",
"PathToTreePath[{{1, 2}}]"},
{"Path to tree with vertex labels.",
"PathToTreePath[{{1, 2}}, {a, b}]"},
{"Canonicalize a path.",
"CanonicalPath[{{2, 3}, {1, 2}}]"}
}}
}},

(* MPS Functions *)
{"MPS (Matrix Product State) Functions",
"Functions for working with Matrix Product States, a 1D tensor network structure.",
{
{"MPSCanonicalForm", "Put MPS into canonical form.", {
{"Default (left) canonical form.",
"MPSCanonicalForm[mps]"},
{"Left canonical form.",
"MPSCanonicalForm[mps, \"Left\"]"},
{"Right canonical form.",
"MPSCanonicalForm[mps, \"Right\"]"},
{"Mixed canonical form at site 3.",
"MPSCanonicalForm[mps, {\"Mixed\", 3}]"},
{"With bond dimension truncation.",
"MPSCanonicalForm[mps, \"Left\", \"MaxBond\" -> 4]"},
{"With tolerance.",
"MPSCanonicalForm[mps, \"Left\", \"Tolerance\" -> 1.*^-6]"},
{"Periodic MPS left canonical.",
"MPSCanonicalForm[mps2, \"Left\"]"},
{"Periodic with truncation.",
"MPSCanonicalForm[mps2, \"Right\", \"MaxBond\" -> 5]"},
{"Periodic mixed with tolerance.",
"MPSCanonicalForm[mps2, {\"Mixed\", 2}, \"Tolerance\" -> 1.*^-8]"},
{"All options combined.",
"MPSCanonicalForm[RandomTensorNetwork[\"MPS\"[4, 2, 2]], \"Left\", \"MaxBond\" -> 3, \"Tolerance\" -> 0]"}
}},
{"MPSCanonicalQ", "Test canonical form.", {
{"Test left canonical form.",
"MPSCanonicalQ[MPSCanonicalForm[mps, \"Left\"], \"Left\"]"},
{"Test right canonical form.",
"MPSCanonicalQ[MPSCanonicalForm[mps, \"Right\"], \"Right\"]"},
{"Test mixed canonical form.",
"MPSCanonicalQ[MPSCanonicalForm[mps, {\"Mixed\", 3}], {\"Mixed\", 3}]"},
{"Test random MPS (not canonical).",
"MPSCanonicalQ[mps, \"Left\"]"},
{"Periodic test.",
"MPSCanonicalQ[mps2, \"Left\"]"}
}},
{"MPSOverlap and MPSNorm", "Compute inner products and norms.", {
{"Self overlap (norm squared).",
"MPSOverlap[mps, mps]"},
{"Cross overlap.",
"MPSOverlap[mps, mps2]"},
{"Overlap with random MPS.",
"MPSOverlap[mps, RandomTensorNetwork[\"MPS\"[5, 3, 2]]]"},
{"Compute MPS norm.",
"MPSNorm[mps]"},
{"Norm after canonicalization.",
"MPSNorm[MPSCanonicalForm[mps, \"Left\"]]"}
}},
{"MPSNormalize", "Normalize to unit norm.", {
{"Normalize MPS.",
"MPSNormalize[mps]"},
{"Verify normalized MPS has unit norm.",
"MPSNorm[MPSNormalize[mps]]"},
{"Normalize periodic MPS.",
"MPSNormalize[mps2]"},
{"Normalize canonical form.",
"MPSNormalize[MPSCanonicalForm[mps, \"Left\"]]"},
{"Normalize random MPS.",
"MPSNormalize[RandomTensorNetwork[\"MPS\"[4, 2, 2]]]"}
}},
{"MPSEntanglementEntropy and MPSSchmidtValues", "Compute entanglement properties.", {
{"Entanglement entropy at bond 2.",
"MPSEntanglementEntropy[mps, 2]"},
{"Entanglement entropy at bond 3.",
"MPSEntanglementEntropy[mps, 3]"},
{"Entropy of canonical form.",
"MPSEntanglementEntropy[MPSCanonicalForm[mps, \"Left\"], 2]"},
{"Schmidt values at bond 2.",
"MPSSchmidtValues[mps, 2]"},
{"Schmidt values at bond 3.",
"MPSSchmidtValues[mps, 3]"}
}},
{"MPSTruncate", "Truncate bond dimension.", {
{"Truncate to max bond 4.",
"MPSTruncate[mps, 4]"},
{"Aggressive truncation to bond 2.",
"MPSTruncate[mps, 2]"},
{"Truncate without normalization.",
"MPSTruncate[mps, 4, \"Normalize\" -> False]"},
{"Truncate periodic MPS.",
"MPSTruncate[mps2, 4]"},
{"Truncate canonical form.",
"MPSTruncate[MPSCanonicalForm[mps, \"Left\"], 3]"}
}}
}},

(* Young Tableaux *)
{"Young Tableaux",
"Functions for working with Young tableaux, used for tensor symmetry operations.",
{
{"YoungTableau Creation", "Create Young tableaux.", {
{"Create from explicit filling.",
"YoungTableau[{{1, 2}, {3}}]"},
{"Create from shape (standard filling).",
"YoungTableau[{2, 1}]"},
{"Single row tableau.",
"YoungTableau[{3}]"},
{"Single column tableau.",
"YoungTableau[{1, 1, 1}]"},
{"Square tableau.",
"YoungTableau[{2, 2}]"},
{"Complex shape.",
"YoungTableau[{4, 2, 1}]"}
}},
{"YoungTableauQ and Properties", "Test validity and get properties.", {
{"Test tableau validity.",
"YoungTableauQ[yt1]"},
{"Test another tableau.",
"YoungTableauQ[yt2]"},
{"Test invalid input.",
"YoungTableauQ[\"invalid\"]"},
{"Get tableau shape.",
"TableauShape[yt1]"},
{"Get tableau size (number of boxes).",
"TableauSize[yt1]"}
}},
{"HookLength and TableauDimension", "Compute hook lengths and dimensions.", {
{"Hook length at position (1,1).",
"HookLength[yt1, {1, 1}]"},
{"Hook length at position (1,2).",
"HookLength[yt1, {1, 2}]"},
{"Hook length at corner.",
"HookLength[yt1, {2, 1}]"},
{"Tableau dimension (number of standard tableaux).",
"TableauDimension[yt1]"},
{"Dimension of another shape.",
"TableauDimension[YoungTableau[{3}]]"}
}},
{"YoungSymmetrize and YoungProject", "Apply symmetry operations.", {
{"Symmetrize rank-3 tensor.",
"YoungSymmetrize[t3, yt1]"},
{"Symmetrize with different tableau.",
"YoungSymmetrize[t3, yt2]"},
{"Full symmetrization (single row).",
"YoungSymmetrize[RandomReal[1, {3, 3, 3}], YoungTableau[{3}]]"},
{"Full antisymmetrization (single column).",
"YoungSymmetrize[RandomReal[1, {2, 2, 2}], YoungTableau[{1, 1, 1}]]"},
{"Project onto symmetry subspace.",
"YoungProject[t3, yt1]"},
{"Project with different tableau.",
"YoungProject[t3, yt2]"},
{"Project fully symmetric.",
"YoungProject[RandomReal[1, {3, 3, 3}], YoungTableau[{3}]]"},
{"Project fully antisymmetric.",
"YoungProject[RandomReal[1, {2, 2, 2}], YoungTableau[{1, 1, 1}]]"},
{"Higher rank tensor symmetrization.",
"YoungSymmetrize[RandomReal[1, {2, 2, 2, 2}], YoungTableau[{2, 2}]]"}
}}
}}

};

(* Build notebook cells *)
cells = {
    Cell["TensorNetworks Comprehensive Examples", "Title"],
    Cell["A Complete Guide with Runnable Examples for Every Function", "Subtitle"],
    Cell["This notebook contains comprehensive examples for all functions in the Wolfram TensorNetworks package. Run the Setup section first to initialize required variables.", "Text"],
    Cell["Setup and Initialization", "Section"],
    Cell["Load the package and initialize variables used throughout the examples. Run this cell first.", "Text"],
    Cell[commonSetup, "Input"]
};

(* Add each section *)
Do[
    {sectionName, sectionDesc, subsections} = sec;
    AppendTo[cells, Cell[sectionName, "Section"]];
    AppendTo[cells, Cell[sectionDesc, "Text"]];

    Do[
        {subsecName, subsecDesc, examples} = subsec;
        AppendTo[cells, Cell[subsecName, "Subsection"]];
        AppendTo[cells, Cell[subsecDesc, "Text"]];

        Do[
            {explanation, code} = ex;
            AppendTo[cells, Cell["(* " <> explanation <> " *)", "Text"]];
            AppendTo[cells, Cell[code, "Input"]];
            , {ex, examples}
        ];
        , {subsec, subsections}
    ];
    , {sec, sections}
];

(* Create and export notebook *)
nb = Notebook[cells,
    WindowTitle -> "TensorNetworks Comprehensive Examples",
    StyleDefinitions -> "Default.nb"
];

Export["TensorNetworksComprehensiveExamples.nb", nb];
Print["Created TensorNetworksComprehensiveExamples.nb with ", Length[cells], " cells covering ", Length[sections], " function groups."];
