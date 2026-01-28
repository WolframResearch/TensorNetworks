(* Tests/test_tensor_network.wl *)
(* Comprehensive tests for TensorNetwork.wl *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* TensorNetwork Constructor Tests             *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    TensorNetworkQ[tn],
    True,
    TestID -> "TensorNetwork_Constructor_TwoArguments"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}},
        {1, 3}
    ];
    tn["Output"],
    {1, 3},
    TestID -> "TensorNetwork_Constructor_ThreeArguments_ExplicitOutput"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}},
        Automatic
    ];
    tn["Output"],
    Automatic,
    TestID -> "TensorNetwork_Constructor_AutomaticOutput"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}},
        Cycles[{{1, 2}}]
    ];
    tn["FreeIndices"],
    {3, 1},
    TestID -> "TensorNetwork_Constructor_CyclesPermutation"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}} -> {3, 1}
    ];
    tn["FreeIndices"],
    {3, 1},
    TestID -> "TensorNetwork_Constructor_RuleForm"
]

VerificationTest[
    tn = TensorNetwork[{{1, 2}, {2, 3}}];
    TensorNetworkQ[tn],
    True,
    TestID -> "TensorNetwork_Constructor_HypergraphOnly"
]

(* ============================================ *)
(* TensorNetworkQ Tests                        *)
(* ============================================ *)

VerificationTest[
    TensorNetworkQ[TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2}}]],
    True,
    TestID -> "TensorNetworkQ_ValidNetwork"
]

VerificationTest[
    (* Empty network - behavior depends on implementation *)
    TensorNetworkQ[TensorNetwork[{}, {}, {}]],
    True,
    TestID -> "TensorNetworkQ_EmptyNetwork"
]

VerificationTest[
    TensorNetworkQ["not a tensor network"],
    False,
    TestID -> "TensorNetworkQ_InvalidInput_String"
]

VerificationTest[
    TensorNetworkQ[123],
    False,
    TestID -> "TensorNetworkQ_InvalidInput_Number"
]

VerificationTest[
    (* Mismatched tensor dimensions and hyperedges *)
    TensorNetworkQ[TensorNetwork[{RandomReal[{-1, 1}, {2, 3}]}, {{1, 2, 3}}]],
    False,
    TestID -> "TensorNetworkQ_MismatchedDimensions"
]

(* ============================================ *)
(* TensorNetwork Properties Tests              *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {IdentityMatrix[3], RandomReal[{-1, 1}, {3, 4, 5}]},
        {{1, 2}, {2, 3, 4}}
    ];
    tn["Tensors"] // Length,
    2,
    TestID -> "TensorNetwork_Property_Tensors"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tn["Hyperedges"],
    {{1, 2}, {2, 3}},
    TestID -> "TensorNetwork_Property_Hyperedges"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    Sort[tn["FreeIndices"]],
    {1, 3},
    TestID -> "TensorNetwork_Property_FreeIndices"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4, 5}]},
        {{1, 2}, {2, 3, 4}}
    ];
    tn["Dimensions"],
    {{2, 3}, {3, 4, 5}},
    TestID -> "TensorNetwork_Property_Dimensions"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4, 5}]},
        {{1, 2}, {2, 3, 4}}
    ];
    tn["Ranks"],
    {2, 3},
    TestID -> "TensorNetwork_Property_Ranks"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    TensorNetworkSize[tn],
    2,
    TestID -> "TensorNetwork_Property_Size"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}},
        {1, 3}
    ];
    tn["OutputDimensions"],
    {2, 4},
    TestID -> "TensorNetwork_Property_OutputDimensions"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}},
        {1, 3}
    ];
    tn["OutputDimension"],
    8,
    TestID -> "TensorNetwork_Property_OutputDimension"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    MemberQ[tn["Properties"], "Tensors"],
    True,
    TestID -> "TensorNetwork_Property_Properties"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tn["UnknownProperty"],
    Missing["UnknownProperty", "UnknownProperty"],
    TestID -> "TensorNetwork_Property_UnknownProperty"
]

(* ============================================ *)
(* TensorNetworkData Tests                     *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    data = TensorNetworkData[tn];
    AssociationQ[data] && KeyExistsQ[data, "Tensors"] && KeyExistsQ[data, "Hyperedges"],
    True,
    TestID -> "TensorNetworkData_ReturnsAssociation"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    data = TensorNetworkData[tn];
    data["Vertices"],
    {1, 2},
    TestID -> "TensorNetworkData_Vertices"
]

(* ============================================ *)
(* TensorNetworkContractions Tests             *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    contractions = TensorNetworkContractions[tn];
    Length[contractions] == 2,
    True,
    TestID -> "TensorNetworkContractions_Basic"
]

(* ============================================ *)
(* BinaryTensorNetwork Tests                   *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    BinaryTensorNetworkQ[tn],
    True,
    TestID -> "BinaryTensorNetworkQ_IsBinary"
]

VerificationTest[
    (* Hyperedge with 3 connections is not binary *)
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}], RandomReal[{-1, 1}, {4, 3}]},
        {{1, 2}, {2, 3}, {3, 2}}
    ];
    BinaryTensorNetworkQ[tn],
    False,
    TestID -> "BinaryTensorNetworkQ_NotBinary"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    btn = BinaryTensorNetwork[tn];
    TensorNetworkQ[btn],
    True,
    TestID -> "BinaryTensorNetwork_PreservesValidity"
]

(* ============================================ *)
(* SparseTensorNetwork Tests                   *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    stn = SparseTensorNetwork[tn];
    stn["SparseQ"],
    True,
    TestID -> "SparseTensorNetwork_IsSparse"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tn["SparseQ"],
    False,
    TestID -> "TensorNetwork_NotSparse"
]

(* ============================================ *)
(* RandomTensorNetwork - Graph Input Tests     *)
(* ============================================ *)

VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 2, 4];
    TensorNetworkQ[rtn],
    True,
    TestID -> "RandomTensorNetwork_GraphSpec_Valid"
]

VerificationTest[
    rtn = RandomTensorNetwork[CycleGraph[4], 3];
    TensorNetworkQ[rtn],
    True,
    TestID -> "RandomTensorNetwork_CycleGraph_Valid"
]

VerificationTest[
    rtn = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Real"];
    tensors = rtn["Tensors"];
    AllTrue[Flatten[tensors], Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Method_Real"
]

VerificationTest[
    rtn = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Complex"];
    tensors = rtn["Tensors"];
    AnyTrue[Flatten[tensors], !Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Method_Complex"
]

VerificationTest[
    (* Fixed dimension test *)
    rtn = RandomTensorNetwork[{5, 7}, {4}, 2];
    dims = Flatten[rtn["Dimensions"]];
    AllTrue[dims, # == 4 &],
    True,
    TestID -> "RandomTensorNetwork_FixedDimension"
]

(* ============================================ *)
(* RandomTensorNetwork - MPS Tests             *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    TensorNetworkQ[mps],
    True,
    TestID -> "RandomTensorNetwork_MPS_Valid"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    Length[mps["Tensors"]],
    4,
    TestID -> "RandomTensorNetwork_MPS_CorrectLength"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[1, 3, 2]];
    TensorNetworkQ[mps] && Length[mps["Tensors"]] == 1,
    True,
    TestID -> "RandomTensorNetwork_MPS_LengthOne"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], "Boundary" -> "Periodic"];
    (* All tensors should be rank-3 for periodic *)
    AllTrue[mps["Ranks"], # == 3 &],
    True,
    TestID -> "RandomTensorNetwork_MPS_Periodic"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], "Boundary" -> "Open"];
    (* Boundary tensors should be rank-2 for open *)
    mps["Ranks"][[1]] == 2 && mps["Ranks"][[-1]] == 2,
    True,
    TestID -> "RandomTensorNetwork_MPS_Open"
]

(* ============================================ *)
(* RandomTensorNetwork - TT Tests              *)
(* ============================================ *)

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4]];
    TensorNetworkQ[tt],
    True,
    TestID -> "RandomTensorNetwork_TT_Valid"
]

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4]];
    Length[tt["Tensors"]],
    5,
    TestID -> "RandomTensorNetwork_TT_CorrectLength"
]

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4], "Boundary" -> "Periodic"];
    AllTrue[tt["Ranks"], # == 2 &],
    True,
    TestID -> "RandomTensorNetwork_TT_Periodic"
]

(* ============================================ *)
(* RandomTensorNetwork - MPO Tests             *)
(* ============================================ *)

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2]];
    TensorNetworkQ[mpo],
    True,
    TestID -> "RandomTensorNetwork_MPO_Valid"
]

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2], "Boundary" -> "Open"];
    (* Boundary tensors should be rank-3 (bond, phys_in, phys_out) for open *)
    mpo["Ranks"][[1]] == 3 && mpo["Ranks"][[-1]] == 3,
    True,
    TestID -> "RandomTensorNetwork_MPO_Open"
]

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2], "Boundary" -> "Periodic"];
    AllTrue[mpo["Ranks"], # == 4 &],
    True,
    TestID -> "RandomTensorNetwork_MPO_Periodic"
]

(* ============================================ *)
(* RandomTensorNetwork - PEPS Tests            *)
(* ============================================ *)

VerificationTest[
    peps = RandomTensorNetwork["PEPS"[{2, 3}, 2, 2]];
    TensorNetworkQ[peps],
    True,
    TestID -> "RandomTensorNetwork_PEPS_Valid"
]

VerificationTest[
    peps = RandomTensorNetwork["PEPS"[{2, 3}, 2, 2]];
    Length[peps["Tensors"]],
    6,  (* 2x3 grid *)
    TestID -> "RandomTensorNetwork_PEPS_CorrectSize"
]

VerificationTest[
    peps = RandomTensorNetwork["PEPS"[2, 3, 2, 2]];
    TensorNetworkQ[peps],
    True,
    TestID -> "RandomTensorNetwork_PEPS_AlternativeSyntax"
]

(* ============================================ *)
(* RandomTensorNetwork - TTN Tests             *)
(* ============================================ *)

VerificationTest[
    ttn = RandomTensorNetwork["TTN"[3, 2, 2]];
    TensorNetworkQ[ttn],
    True,
    TestID -> "RandomTensorNetwork_TTN_Valid"
]

(* ============================================ *)
(* RandomTensorNetwork - MERA Tests            *)
(* ============================================ *)

VerificationTest[
    mera = RandomTensorNetwork["MERA"[4, 2, 1]];
    TensorNetworkQ[mera],
    True,
    TestID -> "RandomTensorNetwork_MERA_Valid"
]

(* ============================================ *)
(* TensorNetworkAdd Tests                      *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}]},
        {{1, 2}}
    ];
    newTensor = RandomReal[{-1, 1}, {3, 4}];
    tnAdded = TensorNetworkAdd[tn, newTensor, {2, 3}];
    TensorNetworkSize[tnAdded],
    2,
    TestID -> "TensorNetworkAdd_IncreasesSize"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}]},
        {{1, 2}},
        {1, 2}
    ];
    newTensor = RandomReal[{-1, 1}, {3, 4}];
    tnAdded = TensorNetworkAdd[tn, newTensor, {2, 3}];
    Sort[tnAdded["FreeIndices"]],
    {1, 3},
    TestID -> "TensorNetworkAdd_UpdatesFreeIndices"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}]},
        {{1, 2}},
        {1, 2}
    ];
    newTensor = RandomReal[{-1, 1}, {4, 5}];
    tnAdded = TensorNetworkAdd[tn, newTensor, {3, 4}];
    Sort[tnAdded["FreeIndices"]],
    {1, 2, 3, 4},
    TestID -> "TensorNetworkAdd_NoContraction"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}]},
        {{1, 2}},
        {1, 2}
    ];
    newTensor = RandomReal[{-1, 1}, {2, 3}];
    tnAdded = TensorNetworkAdd[tn, newTensor, {1, 2}];
    tnAdded["FreeIndices"],
    {},
    TestID -> "TensorNetworkAdd_FullContraction"
]

(* ============================================ *)
(* TensorNetworkDelete Tests                   *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tnDeleted = TensorNetworkDelete[tn, -1];
    TensorNetworkSize[tnDeleted],
    1,
    TestID -> "TensorNetworkDelete_DecreasesSize"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    tnDeleted = TensorNetworkDelete[tn, 1];
    TensorNetworkSize[tnDeleted],
    1,
    TestID -> "TensorNetworkDelete_FirstTensor"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {4}]},
        {{1}, {2}, {3}},
        {3, 2, 1}
    ];
    tnDeleted = TensorNetworkDelete[tn, 2];
    tnDeleted["FreeIndices"],
    {3, 1},
    TestID -> "TensorNetworkDelete_UpdatesFreeIndices"
]

(* ============================================ *)
(* Edge Cases and Error Handling               *)
(* ============================================ *)

VerificationTest[
    (* Single tensor network *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {2, 3, 4}]}, {{1, 2, 3}}];
    TensorNetworkQ[tn] && TensorNetworkSize[tn] == 1,
    True,
    TestID -> "TensorNetwork_SingleTensor"
]

VerificationTest[
    (* Large network *)
    rtn = RandomTensorNetwork[{20, 30}, 2, 2];
    TensorNetworkQ[rtn] && TensorNetworkSize[rtn] == 20,
    True,
    TestID -> "TensorNetwork_LargeNetwork"
]

VerificationTest[
    (* Complex-valued tensor network *)
    tn = TensorNetwork[
        {RandomComplex[{-1 - I, 1 + I}, {2, 3}], RandomComplex[{-1 - I, 1 + I}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    TensorNetworkQ[tn],
    True,
    TestID -> "TensorNetwork_ComplexTensors"
]

VerificationTest[
    (* Network with vectors *)
    tn = TensorNetwork[{RandomReal[{-1, 1}, {3}], RandomReal[{-1, 1}, {3, 4}]}, {{1}, {1, 2}}];
    TensorNetworkQ[tn],
    True,
    TestID -> "TensorNetwork_VectorTensor"
]

