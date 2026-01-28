(* Tests/test_graph_functions.wl *)
(* Comprehensive tests for ToTensorNetworkGraph.wl *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* ToTensorNetworkGraph Tests                  *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    GraphQ[g],
    True,
    TestID -> "ToTensorNetworkGraph_FromTensorNetwork"
]

VerificationTest[
    tensors = {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]};
    hyperedges = {{1, 2}, {2, 3}};
    g = ToTensorNetworkGraph[tensors, hyperedges];
    GraphQ[g],
    True,
    TestID -> "ToTensorNetworkGraph_FromTensorsAndHyperedges"
]

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3}];
    tng = ToTensorNetworkGraph[g];
    TensorNetworkGraphQ[tng],
    True,
    TestID -> "ToTensorNetworkGraph_FromDirectedGraph"
]

VerificationTest[
    g = Graph[{1 <-> 2, 2 <-> 3}];
    tng = ToTensorNetworkGraph[g];
    TensorNetworkGraphQ[tng],
    True,
    TestID -> "ToTensorNetworkGraph_FromUndirectedGraph"
]

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3}];
    tng = ToTensorNetworkGraph[g, Method -> "Symbolic"];
    TensorNetworkGraphQ[tng],
    True,
    TestID -> "ToTensorNetworkGraph_MethodSymbolic"
]

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3}];
    tng = ToTensorNetworkGraph[g, Method -> "Random"];
    TensorNetworkGraphQ[tng],
    True,
    TestID -> "ToTensorNetworkGraph_MethodRandom"
]

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3}];
    tng = ToTensorNetworkGraph[g, Method -> "Zero"];
    TensorNetworkGraphQ[tng],
    True,
    TestID -> "ToTensorNetworkGraph_MethodZero"
]

(* ============================================ *)
(* TensorNetworkGraphQ Tests                   *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    TensorNetworkGraphQ[g],
    True,
    TestID -> "TensorNetworkGraphQ_ValidGraph"
]

VerificationTest[
    TensorNetworkGraphQ[Graph[{1 -> 2}]],
    False,
    TestID -> "TensorNetworkGraphQ_PlainGraph"
]

VerificationTest[
    TensorNetworkGraphQ["not a graph"],
    False,
    TestID -> "TensorNetworkGraphQ_InvalidInput"
]

(* ============================================ *)
(* TensorNetworkGraphData Tests                *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    data = TensorNetworkGraphData[g];
    AssociationQ[data],
    True,
    TestID -> "TensorNetworkGraphData_ReturnsAssociation"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    data = TensorNetworkGraphData[g];
    KeyExistsQ[data, "Tensors"] && KeyExistsQ[data, "Indices"],
    True,
    TestID -> "TensorNetworkGraphData_HasRequiredKeys"
]

(* ============================================ *)
(* TensorNetworkIndices Tests                  *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    indices = TensorNetworkIndices[g];
    ListQ[indices],
    True,
    TestID -> "TensorNetworkIndices_ReturnsList"
]

(* ============================================ *)
(* TensorNetworkTensors Tests                  *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    tensors = TensorNetworkTensors[g];
    ListQ[tensors] && Length[tensors] == 2,
    True,
    TestID -> "TensorNetworkTensors_CorrectCount"
]

(* ============================================ *)
(* TensorNetworkIndexDimensions Tests          *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    dims = TensorNetworkIndexDimensions[g];
    AssociationQ[dims] || ListQ[dims],
    True,
    TestID -> "TensorNetworkIndexDimensions_ReturnsMapping"
]

(* ============================================ *)
(* TensorNetworkFreeIndices Tests (Graph)      *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    freeIndices = TensorNetworkFreeIndices[g];
    ListQ[freeIndices],
    True,
    TestID -> "TensorNetworkFreeIndices_Graph_ReturnsList"
]

(* ============================================ *)
(* TensorNetworkAdd (Graph) Tests              *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    newTensor = RandomReal[{-1, 1}, {4, 5}];
    gAdded = TensorNetworkAdd[g, newTensor];
    TensorNetworkGraphQ[gAdded],
    True,
    TestID -> "TensorNetworkAdd_Graph_AutomaticIndex"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}]},
        {{1, 2}}
    ];
    g = ToTensorNetworkGraph[tn];
    newTensor = RandomReal[{-1, 1}, {3, 4}];
    gAdded = TensorNetworkAdd[g, newTensor, Automatic];
    VertexCount[gAdded] > VertexCount[g],
    True,
    TestID -> "TensorNetworkAdd_Graph_IncreasesVertexCount"
]

(* ============================================ *)
(* TensorNetworkDelete (Graph) Tests           *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    gDeleted = TensorNetworkDelete[g, -1];
    VertexCount[gDeleted] < VertexCount[g],
    True,
    TestID -> "TensorNetworkDelete_Graph_DecreasesVertexCount"
]

(* ============================================ *)
(* TensorNetworkRemoveCycles Tests             *)
(* ============================================ *)

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3, 3 -> 1}];  (* Has cycle *)
    acyclic = TensorNetworkRemoveCycles[g];
    AcyclicGraphQ[acyclic],
    True,
    TestID -> "TensorNetworkRemoveCycles_RemovesCycle"
]

VerificationTest[
    g = Graph[{1 -> 2, 2 -> 3}];  (* No cycle *)
    result = TensorNetworkRemoveCycles[g];
    AcyclicGraphQ[result],
    True,
    TestID -> "TensorNetworkRemoveCycles_AcyclicInput"
]

(* ============================================ *)
(* TensorNetworkReplaceIndices Tests           *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    gReplaced = TensorNetworkReplaceIndices[g, {Subscript[_, x_] :> Subscript[100, x]}];
    TensorNetworkGraphQ[gReplaced],
    True,
    TestID -> "TensorNetworkReplaceIndices_PreservesValidity"
]

(* ============================================ *)
(* InitializeTensorNetwork Tests               *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    initTensor = RandomReal[{-1, 1}, {2}];
    initialized = InitializeTensorNetwork[g, initTensor];
    TensorNetworkGraphQ[initialized],
    True,
    TestID -> "InitializeTensorNetwork_Basic"
]

(* ============================================ *)
(* TensorNetworkIndexGraph Tests               *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    g = ToTensorNetworkGraph[tn];
    indexGraph = TensorNetworkIndexGraph[g];
    GraphQ[indexGraph],
    True,
    TestID -> "TensorNetworkIndexGraph_ReturnsGraph"
]

(* ============================================ *)
(* Edge Cases                                  *)
(* ============================================ *)

VerificationTest[
    (* Single tensor graph *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2}}];
    g = ToTensorNetworkGraph[tn];
    TensorNetworkGraphQ[g],
    True,
    TestID -> "ToTensorNetworkGraph_SingleTensor"
]

VerificationTest[
    (* Large network *)
    rtn = RandomTensorNetwork[{10, 15}, 2, 2];
    g = ToTensorNetworkGraph[rtn];
    TensorNetworkGraphQ[g],
    True,
    TestID -> "ToTensorNetworkGraph_LargeNetwork"
]

VerificationTest[
    (* Hyperedge with 3+ tensors *)
    tensors = {
        RandomReal[{-1, 1}, {2, 3}],
        RandomReal[{-1, 1}, {3, 4}],
        RandomReal[{-1, 1}, {4, 3}]
    };
    hyperedges = {{1, 2}, {2, 3}, {3, 2}};
    g = ToTensorNetworkGraph[tensors, hyperedges];
    GraphQ[g],
    True,
    TestID -> "ToTensorNetworkGraph_Hyperedge"
]

