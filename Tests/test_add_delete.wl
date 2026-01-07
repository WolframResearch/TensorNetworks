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

(* Permutation tests *)
VerificationTest[
    tn = makeTestNet[];
    tn["Permutation"],
    Cycles[{{1, 2}}],
    TestID -> "Permutation_Initial"
]

VerificationTest[
    tn = makeTestNet[];
    tnAdded = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {5, 6}], {4, 5}];
    tnAdded["Permutation"],
    Cycles[{{1, 2}}],
    TestID -> "Permutation_Add_Extension"
]

VerificationTest[
    tn = makeTestNet[];
    tnAddedContract = TensorNetworkAdd[tn, RandomReal[{-1, 1}, {4, 7}], {3, 6}];
    Length[tnAddedContract["FreeIndices"]] == 2,
    True,
    TestID -> "Permutation_Add_Contraction_FreeCount"
]

VerificationTest[
    tn3 = TensorNetwork[
        {RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {4}]},
        {{1}, {2}, {3}},
        Cycles[{{1, 3}}]
    ];
    tnDel = TensorNetworkDelete[tn3, 2];
    tnDel["Permutation"],
    Cycles[{{1, 2}}],
    TestID -> "Permutation_Delete_Middle"
]

VerificationTest[
    tn3 = TensorNetwork[
        {RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {4}]},
        {{1}, {2}, {3}},
        Cycles[{{1, 3}}]
    ];
    tnDelFirst = TensorNetworkDelete[tn3, 1];
    tnDelFirst["Permutation"],
    Cycles[{}],
    TestID -> "Permutation_Delete_First"
]
