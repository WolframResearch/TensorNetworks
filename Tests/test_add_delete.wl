(* Setup *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

tensorDimensions = Wolfram`TensorNetworks`PackageScope`tensorDimensions;

(* Helper to create standard test network *)
makeTestNet[] := TensorNetwork[
    {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
    {{1, 2}, {2, 3}},
    Cycles[{{1, 2}}] (* free indices 1, 3 -> positions 1, 2. Swapped. *)
]

VerificationTest[
    tensorDimensions[{{1, 2}, {3, 4}}],
    {2, 2},
    TestID -> "Debug_TensorDimensions_Works"
]

(* Test TensorNetwork head *)
VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    TensorNetworkQ[rtn],
    True,
    TestID -> "RandomTensorNetwork_Valid"
]

VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    sizeOrig = TensorNetworkSize[rtn];
    newTensor = RandomReal[{-1, 1}, {2, 2}];
    newIndices = {100, 101};
    rtnAdded = TensorNetworkAdd[rtn, newTensor, newIndices];
    sizeAdded = TensorNetworkSize[rtnAdded];
    sizeAdded == sizeOrig + 1 && Last[rtnAdded["Tensors"]] === newTensor,
    True,
    TestID -> "TensorNetworkAdd_Basic"
]

VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    newTensor = RandomReal[{-1, 1}, {2, 2}];
    newIndices = {100, 101};
    rtnAdded = TensorNetworkAdd[rtn, newTensor, newIndices];
    sizeOrig = TensorNetworkSize[rtn];
    rtnDeleted = TensorNetworkDelete[rtnAdded, -1];
    TensorNetworkSize[rtnDeleted] == sizeOrig,
    True,
    TestID -> "TensorNetworkDelete_Basic"
]

(* Test Graph head *)
VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    g = ToTensorNetworkGraph[rtn];
    sizeGOrig = VertexCount[g];
    newTensor = RandomReal[{-1, 1}, {2, 2}];
    graphAdded = TensorNetworkAdd[g, newTensor, {Subscript[1, 1], Subscript[1, 2]}];
    If[!GraphQ[graphAdded], graphAdded = gAdded]; 
    VertexCount[graphAdded] == sizeGOrig + 1,
    True,
    TestID -> "TensorNetworkAdd_Graph"
]

VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    g = ToTensorNetworkGraph[rtn];
    newTensor = RandomReal[{-1, 1}, {2, 2}];
    graphAdded = TensorNetworkAdd[g, newTensor, {Subscript[1, 1], Subscript[1, 2]}];
    If[!GraphQ[graphAdded], graphAdded = gAdded];
    sizeGOrig = VertexCount[g];
    gDeleted = TensorNetworkDelete[graphAdded, -1];
    VertexCount[gDeleted] == sizeGOrig,
    True,
    TestID -> "TensorNetworkDelete_Graph"
]

(* FreeIndices tests - always test FreeIndices since Output can be Automatic *)
VerificationTest[
    tn = makeTestNet[];
    tn["FreeIndices"],
    {3, 1},  (* Free indices {1, 3} permuted by Cycles[{{1, 2}}] *)
    TestID -> "FreeIndices_Initial"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tn["FreeIndices"],
    {1, 3},  (* Default ordering when Output is Automatic *)
    TestID -> "FreeIndices_Automatic"
]

VerificationTest[
    tn = makeTestNet[];
    tnAdded = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {5, 6}], {4, 5}];
    tnAdded["FreeIndices"],
    {3, 1, 4, 5},  (* Original free indices {3,1} + new free indices {4,5} *)
    TestID -> "FreeIndices_Add_Extension"
]

VerificationTest[
    tn = makeTestNet[];
    tnAddedContract = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {4, 7}], {3, 6}];
    tnAddedContract["FreeIndices"],
    {1, 6},  (* Index 3 contracts, leaving {1} from original + {6} from new *)
    TestID -> "FreeIndices_Add_Contraction"
]

VerificationTest[
    tn3 = TensorNetwork[
        {RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {4}]},
        {{1}, {2}, {3}},
        Cycles[{{1, 3}}]  (* {1,2,3} -> {3,2,1} *)
    ];
    tnDel = TensorNetworkDelete[tn3, 2];
    tnDel["FreeIndices"],
    {3, 1},  (* Index 2 removed from {3,2,1} *)
    TestID -> "FreeIndices_Delete_Middle"
]

VerificationTest[
    tn3 = TensorNetwork[
        {RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {4}]},
        {{1}, {2}, {3}},
        Cycles[{{1, 3}}]  (* {1,2,3} -> {3,2,1} *)
    ];
    tnDelFirst = TensorNetworkDelete[tn3, 1];
    tnDelFirst["FreeIndices"],
    {3, 2},  (* Index 1 removed from {3,2,1} *)
    TestID -> "FreeIndices_Delete_First"
]

(* More sophisticated tests *)
VerificationTest[
    (* Multiple adds that create a chain *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2}}, {1, 2}];
    tn2 = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {3, 4}], {2, 3}];
    tn3 = TensorNetworkAdd[tn2, RandomReal[{-1, 1}, {4, 5}], {3, 4}];
    tn3["FreeIndices"],
    {1, 4},  (* Only endpoints remain free *)
    TestID -> "FreeIndices_ChainOfAdds"
]

VerificationTest[
    (* Add then delete maintains consistency *)
    tn = makeTestNet[];
    tnAdded = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {5, 6}], {4, 5}];
    tnBack = TensorNetworkDelete[tnAdded, -1];
    tnBack["FreeIndices"],
    {3, 1},  (* Back to original after removing added tensor *)
    TestID -> "FreeIndices_Add_Then_Delete"
]

VerificationTest[
    (* Automatic output propagates through operations *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2}}];
    tnAdded = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {3, 4}], {2, 3}];
    tnAdded["Output"] === Automatic && Sort[tnAdded["FreeIndices"]] === {1, 3},
    True,
    TestID -> "FreeIndices_Automatic_Propagates"
]

VerificationTest[
    (* Full contraction - all indices paired *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2}}, {1, 2}];
    tnContract = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {2, 3}], {1, 2}];
    tnContract["FreeIndices"],
    {},  (* No free indices - fully contracted *)
    TestID -> "FreeIndices_FullContraction"
]

