(* Tests/test_tensor_network_comprehensive.wl *)
(* Comprehensive tests for TensorNetwork.wl - ALL patterns, ALL options, EXACT verification *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 1       *)
(* TensorNetwork[tensors, hyperedges] (2-arg)  *)
(* ============================================ *)

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    {
        TensorNetworkQ[tn],
        tn["Tensors"] === {A, B},
        tn["Hyperedges"] === {{1, 2}, {2, 3}},
        tn["Output"] === Automatic
    },
    {True, True, True, True},
    TestID -> "TensorNetwork_Constructor_TwoArgs_ExactVerification"
]

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 2       *)
(* TensorNetwork[tensors, hyperedges, output]  *)
(* ============================================ *)

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    {
        TensorNetworkQ[tn],
        tn["Tensors"] === {A, B},
        tn["Hyperedges"] === {{1, 2}, {2, 3}},
        tn["Output"] === {1, 3},
        tn["FreeIndices"] === {1, 3}
    },
    {True, True, True, True, True},
    TestID -> "TensorNetwork_Constructor_ThreeArgs_ExplicitOutput"
]

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {3, 1}];
    {
        tn["Output"] === {3, 1},
        tn["FreeIndices"] === {3, 1}
    },
    {True, True},
    TestID -> "TensorNetwork_Constructor_ThreeArgs_ReversedOutput"
]

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, Automatic];
    {
        tn["Output"] === Automatic,
        Sort[tn["FreeIndices"]] === {1, 3}
    },
    {True, True},
    TestID -> "TensorNetwork_Constructor_ThreeArgs_AutomaticOutput"
]

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 3       *)
(* TensorNetwork[tensors, hyperedges -> out]   *)
(* ============================================ *)

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}} -> {3, 1}];
    {
        TensorNetworkQ[tn],
        tn["Hyperedges"] === {{1, 2}, {2, 3}},
        tn["FreeIndices"] === {3, 1}
    },
    {True, True, True},
    TestID -> "TensorNetwork_Constructor_RuleForm"
]

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 4       *)
(* TensorNetwork[tensors, hyperedges, Cycles]  *)
(* ============================================ *)

VerificationTest[
    A = {{1, 2, 3}, {4, 5, 6}};
    B = {{1, 2}, {3, 4}, {5, 6}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, Cycles[{{1, 2}}]];
    {
        TensorNetworkQ[tn],
        tn["FreeIndices"] === {3, 1}  (* Permuted from {1, 3} *)
    },
    {True, True},
    TestID -> "TensorNetwork_Constructor_CyclesPermutation"
]

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 5       *)
(* TensorNetwork[hypergraph] (symbolic)        *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{1, 2}, {2, 3}}];
    {
        TensorNetworkQ[tn],
        tn["Hyperedges"] === {{1, 2}, {2, 3}},
        Length[tn["Tensors"]] === 2,
        tn["Output"] === Automatic
    },
    {True, True, True, True},
    TestID -> "TensorNetwork_Constructor_HypergraphOnly"
]

VerificationTest[
    tn = TensorNetwork[{{1, 2}, {2, 3}} -> {1, 3}];
    {
        TensorNetworkQ[tn],
        tn["FreeIndices"] === {1, 3}
    },
    {True, True},
    TestID -> "TensorNetwork_Constructor_HypergraphWithOutput"
]

(* ============================================ *)
(* TensorNetwork Constructor - Pattern 6       *)
(* TensorNetwork[TensorContract[...]]          *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tc = Inactive[TensorContract][Inactive[TensorProduct][A, B], {{2, 3}}];
    tn = TensorNetwork[tc];
    {
        TensorNetworkQ[tn],
        Length[tn["Tensors"]] === 2
    },
    {True, True},
    TestID -> "TensorNetwork_Constructor_FromTensorContract"
]

(* ============================================ *)
(* TensorNetworkQ Tests - All Cases            *)
(* ============================================ *)

VerificationTest[
    TensorNetworkQ[TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2}}]],
    True,
    TestID -> "TensorNetworkQ_ValidSingleTensor"
]

VerificationTest[
    TensorNetworkQ[TensorNetwork[{}, {}, {}]],
    True,
    TestID -> "TensorNetworkQ_EmptyNetwork"
]

VerificationTest[
    TensorNetworkQ["not a tensor network"],
    False,
    TestID -> "TensorNetworkQ_InvalidString"
]

VerificationTest[
    TensorNetworkQ[123],
    False,
    TestID -> "TensorNetworkQ_InvalidNumber"
]

VerificationTest[
    TensorNetworkQ[{1, 2, 3}],
    False,
    TestID -> "TensorNetworkQ_InvalidList"
]

VerificationTest[
    (* Mismatched dimensions: tensor has rank 2, but 3 indices given *)
    TensorNetworkQ[TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2, 3}}]],
    False,
    TestID -> "TensorNetworkQ_MismatchedDimensions"
]

VerificationTest[
    (* Incompatible dimension sizes on shared index *)
    TensorNetworkQ[TensorNetwork[{{{1, 2}, {3, 4}}, {{1}, {2}, {3}}}, {{1, 2}, {2, 3}}]],
    False,
    TestID -> "TensorNetworkQ_IncompatibleDimensionSizes"
]

(* ============================================ *)
(* TensorNetwork Properties - Tensors          *)
(* ============================================ *)

VerificationTest[
    A = {{1, 2}, {3, 4}};
    B = {{5, 6}, {7, 8}};
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    tn["Tensors"],
    {A, B},
    TestID -> "TensorNetwork_Property_Tensors_ExactMatch"
]

(* ============================================ *)
(* TensorNetwork Properties - Hyperedges       *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 3}}];
    tn["Hyperedges"],
    {{1, 2}, {2, 3}},
    TestID -> "TensorNetwork_Property_Hyperedges_ExactMatch"
]

(* ============================================ *)
(* TensorNetwork Properties - Output           *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2}}, {2, 1}];
    tn["Output"],
    {2, 1},
    TestID -> "TensorNetwork_Property_Output_Explicit"
]

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2}}];
    tn["Output"],
    Automatic,
    TestID -> "TensorNetwork_Property_Output_Automatic"
]

(* ============================================ *)
(* TensorNetwork Properties - FreeIndices      *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 3}}];
    Sort[tn["FreeIndices"]],
    {1, 3},
    TestID -> "TensorNetwork_Property_FreeIndices_Computed"
]

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 3}}, {3, 1}];
    tn["FreeIndices"],
    {3, 1},
    TestID -> "TensorNetwork_Property_FreeIndices_Explicit"
]

VerificationTest[
    (* Fully contracted network *)
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 1}}, {}];
    tn["FreeIndices"],
    {},
    TestID -> "TensorNetwork_Property_FreeIndices_FullyContracted"
]

(* ============================================ *)
(* TensorNetwork Properties - Dimensions       *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4, 5}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3, 4}}];
    tn["Dimensions"],
    {{2, 3}, {3, 4, 5}},
    TestID -> "TensorNetwork_Property_Dimensions_ExactMatch"
]

(* ============================================ *)
(* TensorNetwork Properties - Ranks            *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4, 5}];
    T3 = RandomReal[{-1, 1}, {5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3, 4}, {4}}];
    tn["Ranks"],
    {2, 3, 1},
    TestID -> "TensorNetwork_Property_Ranks_ExactMatch"
]

(* ============================================ *)
(* TensorNetwork Properties - Size             *)
(* ============================================ *)

VerificationTest[
    (* Each tensor is a vector of length 1, matching 1-index hyperedge *)
    tn = TensorNetwork[{{1}, {2}, {3}, {4}}, {{1}, {2}, {3}, {4}}];
    TensorNetworkSize[tn],
    4,
    TestID -> "TensorNetworkSize_ExactValue"
]

VerificationTest[
    (* Each tensor is a vector of length 1, matching 1-index hyperedge *)
    tn = TensorNetwork[{{1}, {2}, {3}, {4}}, {{1}, {2}, {3}, {4}}];
    tn["Size"],
    4,
    TestID -> "TensorNetwork_Property_Size_ExactValue"
]

(* ============================================ *)
(* TensorNetwork Properties - IndexDimensions  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    indexDims = tn["IndexDimensions"];
    {
        AssociationQ[indexDims],
        indexDims[Superscript[1, 1]] === 2,
        indexDims[Superscript[1, 2]] === 3,
        indexDims[Superscript[2, 3]] === 4
    },
    {True, True, True, True},
    TestID -> "TensorNetwork_Property_IndexDimensions"
]

(* ============================================ *)
(* TensorNetwork Properties - OutputDimensions *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    tn["OutputDimensions"],
    {2, 4},
    TestID -> "TensorNetwork_Property_OutputDimensions"
]

(* ============================================ *)
(* TensorNetwork Properties - OutputDimension  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    tn["OutputDimension"],
    8,  (* 2 * 4 *)
    TestID -> "TensorNetwork_Property_OutputDimension"
]

(* ============================================ *)
(* TensorNetwork Properties - BinaryQ          *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 3}}];
    tn["BinaryQ"],
    True,
    TestID -> "TensorNetwork_Property_BinaryQ_True"
]

VerificationTest[
    (* Index 2 appears 3 times - not binary *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {3, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {2, 4}}];
    tn["BinaryQ"],
    False,
    TestID -> "TensorNetwork_Property_BinaryQ_False"
]

(* ============================================ *)
(* TensorNetwork Properties - SparseQ          *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}];
    tn["SparseQ"],
    False,
    TestID -> "TensorNetwork_Property_SparseQ_False"
]

VerificationTest[
    A = SparseArray[RandomReal[{-1, 1}, {2, 3}]];
    tn = TensorNetwork[{A}, {{1, 2}}];
    tn["SparseQ"],
    True,
    TestID -> "TensorNetwork_Property_SparseQ_True"
]

(* ============================================ *)
(* TensorNetwork Properties - Vertices         *)
(* ============================================ *)

VerificationTest[
    (* Each tensor is a vector of length 1, matching 1-index hyperedge *)
    tn = TensorNetwork[{{1}, {2}, {3}}, {{1}, {2}, {3}}];
    tn["Vertices"],
    {1, 2, 3},
    TestID -> "TensorNetwork_Property_Vertices"
]

(* ============================================ *)
(* TensorNetwork Properties - Properties       *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2}}];
    props = tn["Properties"];
    {
        ListQ[props],
        MemberQ[props, "Tensors"],
        MemberQ[props, "Hyperedges"],
        MemberQ[props, "FreeIndices"],
        MemberQ[props, "Dimensions"],
        MemberQ[props, "BinaryQ"],
        MemberQ[props, "SparseQ"]
    },
    {True, True, True, True, True, True, True},
    TestID -> "TensorNetwork_Property_Properties"
]

(* ============================================ *)
(* TensorNetwork Properties - Unknown          *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}}, {{1, 2}}];
    tn["NonExistentProperty"],
    Missing["UnknownProperty", "NonExistentProperty"],
    TestID -> "TensorNetwork_Property_Unknown"
]

(* ============================================ *)
(* TensorNetworkData Tests                     *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    data = TensorNetworkData[tn];
    {
        AssociationQ[data],
        data["Tensors"] === {A, B},
        data["Hyperedges"] === {{1, 2}, {2, 3}},
        data["Vertices"] === {1, 2},
        ListQ[data["Dimensions"]],
        ListQ[data["ContractionIndices"]]
    },
    {True, True, True, True, True, True},
    TestID -> "TensorNetworkData_ExactStructure"
]

(* ============================================ *)
(* TensorNetworkContractions Tests             *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    contractions = TensorNetworkContractions[tn];
    {
        ListQ[contractions],
        Length[contractions] === 2
    },
    {True, True},
    TestID -> "TensorNetworkContractions_Structure"
]

(* ============================================ *)
(* BinaryTensorNetworkQ Tests                  *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{1, 2}, {2, 3}}];
    BinaryTensorNetworkQ[tn],
    True,
    TestID -> "BinaryTensorNetworkQ_IsBinary"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {3, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {2, 4}}];
    BinaryTensorNetworkQ[tn],
    False,
    TestID -> "BinaryTensorNetworkQ_NotBinary_TripleIndex"
]

(* ============================================ *)
(* BinaryTensorNetwork Tests                   *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    btn = BinaryTensorNetwork[tn];
    {
        TensorNetworkQ[btn],
        BinaryTensorNetworkQ[btn]
    },
    {True, True},
    TestID -> "BinaryTensorNetwork_AlreadyBinary"
]

VerificationTest[
    (* Network with index appearing 3 times - needs spider tensors *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {3, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {2, 4}}];
    btn = BinaryTensorNetwork[tn];
    {
        TensorNetworkQ[btn],
        BinaryTensorNetworkQ[btn],
        Length[btn["Tensors"]] > Length[tn["Tensors"]]  (* Added spider tensor *)
    },
    {True, True, True},
    TestID -> "BinaryTensorNetwork_AddsSpiders"
]

(* ============================================ *)
(* SparseTensorNetwork Tests                   *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    stn = SparseTensorNetwork[tn];
    {
        TensorNetworkQ[stn],
        stn["SparseQ"],
        AllTrue[stn["Tensors"], SparseArrayQ]
    },
    {True, True, True},
    TestID -> "SparseTensorNetwork_ConvertsToDense"
]

(* ============================================ *)
(* RandomTensorNetwork - Graph Input Tests     *)
(* ============================================ *)

VerificationTest[
    rtn = RandomTensorNetwork[{5, 7}, 3, 0];
    {
        TensorNetworkQ[rtn],
        TensorNetworkSize[rtn] === 5
    },
    {True, True},
    TestID -> "RandomTensorNetwork_GraphSpec"
]

VerificationTest[
    rtn = RandomTensorNetwork[CycleGraph[4], 3];
    {
        TensorNetworkQ[rtn],
        TensorNetworkSize[rtn] === 4
    },
    {True, True},
    TestID -> "RandomTensorNetwork_ExplicitGraph"
]

VerificationTest[
    rtn = RandomTensorNetwork[PathGraph[Range[5]], 2];
    {
        TensorNetworkQ[rtn],
        TensorNetworkSize[rtn] === 5
    },
    {True, True},
    TestID -> "RandomTensorNetwork_PathGraph"
]

(* ============================================ *)
(* RandomTensorNetwork - Fixed Dimension       *)
(* ============================================ *)

VerificationTest[
    rtn = RandomTensorNetwork[CycleGraph[4], {5}, 0];
    dims = Flatten[rtn["Dimensions"]];
    AllTrue[dims, # === 5 &],
    True,
    TestID -> "RandomTensorNetwork_FixedDimension_AllSame"
]

(* ============================================ *)
(* RandomTensorNetwork - Method Option         *)
(* ============================================ *)

VerificationTest[
    rtn = RandomTensorNetwork[CycleGraph[3], 2, 0, Method -> Automatic];
    tensors = Flatten[rtn["Tensors"]];
    AllTrue[tensors, Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Method_Automatic_Real"
]

VerificationTest[
    rtn = RandomTensorNetwork[CycleGraph[3], 2, 0, Method -> "Complex"];
    tensors = Flatten[rtn["Tensors"]];
    AnyTrue[tensors, Im[#] != 0 &],
    True,
    TestID -> "RandomTensorNetwork_Method_Complex"
]

(* ============================================ *)
(* RandomTensorNetwork - MPS All Options       *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    {
        TensorNetworkQ[mps],
        Length[mps["Tensors"]] === 5
    },
    {True, True},
    TestID -> "RandomTensorNetwork_MPS_Basic"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2], "Boundary" -> "Open"];
    ranks = mps["Ranks"];
    {
        ranks[[1]] === 2,   (* First tensor: {bond, physical} *)
        ranks[[-1]] === 2,  (* Last tensor: {bond, physical} *)
        AllTrue[ranks[[2 ;; -2]], # === 3 &]  (* Bulk: {left, right, physical} *)
    },
    {True, True, True},
    TestID -> "RandomTensorNetwork_MPS_Open_Ranks"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2], "Boundary" -> "Periodic"];
    ranks = mps["Ranks"];
    AllTrue[ranks, # === 3 &],  (* All rank-3 for periodic *)
    True,
    TestID -> "RandomTensorNetwork_MPS_Periodic_AllRank3"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 3], "Boundary" -> "Open"];
    dims = mps["Dimensions"];
    (* Physical dimension should be 3 *)
    dims[[1, -1]] === 3 && dims[[-1, -1]] === 3,
    True,
    TestID -> "RandomTensorNetwork_MPS_PhysicalDimension"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[1, 4, 2]];
    {
        TensorNetworkQ[mps],
        Length[mps["Tensors"]] === 1
    },
    {True, True},
    TestID -> "RandomTensorNetwork_MPS_LengthOne"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2], Method -> "Complex"];
    tensors = Flatten[mps["Tensors"]];
    AnyTrue[tensors, Im[#] != 0 &],
    True,
    TestID -> "RandomTensorNetwork_MPS_Complex"
]

(* ============================================ *)
(* RandomTensorNetwork - TT All Options        *)
(* ============================================ *)

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4]];
    {
        TensorNetworkQ[tt],
        Length[tt["Tensors"]] === 5
    },
    {True, True},
    TestID -> "RandomTensorNetwork_TT_Basic"
]

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4], "Boundary" -> "Open"];
    ranks = tt["Ranks"];
    {
        ranks[[1]] === 1,   (* Vector *)
        ranks[[-1]] === 1,  (* Vector *)
        AllTrue[ranks[[2 ;; -2]], # === 2 &]  (* Matrices *)
    },
    {True, True, True},
    TestID -> "RandomTensorNetwork_TT_Open_Ranks"
]

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 4], "Boundary" -> "Periodic"];
    ranks = tt["Ranks"];
    AllTrue[ranks, # === 2 &],  (* All matrices for periodic *)
    True,
    TestID -> "RandomTensorNetwork_TT_Periodic_AllRank2"
]

(* ============================================ *)
(* RandomTensorNetwork - MPO All Options       *)
(* ============================================ *)

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2]];
    {
        TensorNetworkQ[mpo],
        Length[mpo["Tensors"]] === 4
    },
    {True, True},
    TestID -> "RandomTensorNetwork_MPO_Basic"
]

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2], "Boundary" -> "Open"];
    ranks = mpo["Ranks"];
    {
        ranks[[1]] === 3,   (* {bond, phys_in, phys_out} *)
        ranks[[-1]] === 3,
        AllTrue[ranks[[2 ;; -2]], # === 4 &]  (* {left, right, phys_in, phys_out} *)
    },
    {True, True, True},
    TestID -> "RandomTensorNetwork_MPO_Open_Ranks"
]

VerificationTest[
    mpo = RandomTensorNetwork["MPO"[4, 3, 2], "Boundary" -> "Periodic"];
    ranks = mpo["Ranks"];
    AllTrue[ranks, # === 4 &],
    True,
    TestID -> "RandomTensorNetwork_MPO_Periodic_AllRank4"
]

(* ============================================ *)
(* RandomTensorNetwork - PEPS Tests            *)
(* ============================================ *)

VerificationTest[
    peps = RandomTensorNetwork["PEPS"[{2, 3}, 2, 2]];
    {
        TensorNetworkQ[peps],
        Length[peps["Tensors"]] === 6  (* 2x3 grid *)
    },
    {True, True},
    TestID -> "RandomTensorNetwork_PEPS_Basic"
]

VerificationTest[
    (* Alternative syntax *)
    peps = RandomTensorNetwork["PEPS"[2, 3, 2, 2]];
    {
        TensorNetworkQ[peps],
        Length[peps["Tensors"]] === 6
    },
    {True, True},
    TestID -> "RandomTensorNetwork_PEPS_AlternativeSyntax"
]

VerificationTest[
    peps = RandomTensorNetwork["PEPS"[{3, 3}, 2, 2]];
    Length[peps["Tensors"]] === 9,
    True,
    TestID -> "RandomTensorNetwork_PEPS_3x3"
]

(* ============================================ *)
(* RandomTensorNetwork - TTN Tests             *)
(* ============================================ *)

VerificationTest[
    ttn = RandomTensorNetwork["TTN"[3, 2, 2]];
    TensorNetworkQ[ttn],
    True,
    TestID -> "RandomTensorNetwork_TTN_Basic"
]

VerificationTest[
    ttn = RandomTensorNetwork["TTN"[2, 3, 2]];
    TensorNetworkQ[ttn],
    True,
    TestID -> "RandomTensorNetwork_TTN_Depth2"
]

(* ============================================ *)
(* RandomTensorNetwork - MERA Tests            *)
(* ============================================ *)

VerificationTest[
    mera = RandomTensorNetwork["MERA"[4, 2, 1]];
    TensorNetworkQ[mera],
    True,
    TestID -> "RandomTensorNetwork_MERA_Basic"
]

VerificationTest[
    mera = RandomTensorNetwork["MERA"[4, 2, 2]];
    TensorNetworkQ[mera],
    True,
    TestID -> "RandomTensorNetwork_MERA_TwoLayers"
]

(* ============================================ *)
(* TensorNetworkAdd Tests                      *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tnAdded = TensorNetworkAdd[tn, B, {2, 3}];
    {
        TensorNetworkQ[tnAdded],
        TensorNetworkSize[tnAdded] === 2,
        tnAdded["Tensors"][[2]] === B,
        tnAdded["Hyperedges"] === {{1, 2}, {2, 3}}
    },
    {True, True, True, True},
    TestID -> "TensorNetworkAdd_Basic"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}, {1, 2}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tnAdded = TensorNetworkAdd[tn, B, {2, 3}];
    Sort[tnAdded["FreeIndices"]],
    {1, 3},  (* Index 2 is now contracted *)
    TestID -> "TensorNetworkAdd_UpdatesFreeIndices"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}, {1, 2}];
    B = RandomReal[{-1, 1}, {4, 5}];
    tnAdded = TensorNetworkAdd[tn, B, {3, 4}];
    Sort[tnAdded["FreeIndices"]],
    {1, 2, 3, 4},  (* No contraction - all free *)
    TestID -> "TensorNetworkAdd_NoContraction"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}, {1, 2}];
    B = RandomReal[{-1, 1}, {2, 3}];
    tnAdded = TensorNetworkAdd[tn, B, {1, 2}];
    tnAdded["FreeIndices"],
    {},  (* Full contraction *)
    TestID -> "TensorNetworkAdd_FullContraction"
]

(* ============================================ *)
(* TensorNetworkDelete Tests                   *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    tnDeleted = TensorNetworkDelete[tn, -1];
    {
        TensorNetworkQ[tnDeleted],
        TensorNetworkSize[tnDeleted] === 1,
        tnDeleted["Tensors"] === {A}
    },
    {True, True, True},
    TestID -> "TensorNetworkDelete_LastTensor"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    tnDeleted = TensorNetworkDelete[tn, 1];
    {
        TensorNetworkQ[tnDeleted],
        TensorNetworkSize[tnDeleted] === 1,
        tnDeleted["Tensors"] === {B}
    },
    {True, True, True},
    TestID -> "TensorNetworkDelete_FirstTensor"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2}];
    B = RandomReal[{-1, 1}, {3}];
    T3 = RandomReal[{-1, 1}, {4}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1}, {2}, {3}}, {3, 2, 1}];
    tnDeleted = TensorNetworkDelete[tn, 2];
    {
        tnDeleted["FreeIndices"] === {3, 1},
        TensorNetworkSize[tnDeleted] === 2
    },
    {True, True},
    TestID -> "TensorNetworkDelete_UpdatesFreeIndices"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    tnDeleted = TensorNetworkDelete[tn];  (* Default index -1 *)
    TensorNetworkSize[tnDeleted] === 1,
    True,
    TestID -> "TensorNetworkDelete_DefaultIndex"
]

(* ============================================ *)
(* Edge Cases - Single Tensor                  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    tn = TensorNetwork[{A}, {{1, 2, 3}}];
    {
        TensorNetworkQ[tn],
        TensorNetworkSize[tn] === 1,
        tn["Ranks"] === {3},
        Sort[tn["FreeIndices"]] === {1, 2, 3}
    },
    {True, True, True, True},
    TestID -> "TensorNetwork_SingleTensor_Rank3"
]

(* ============================================ *)
(* Edge Cases - Vector Tensors                 *)
(* ============================================ *)

VerificationTest[
    a = RandomReal[{-1, 1}, {5}];
    b = RandomReal[{-1, 1}, {5}];
    tn = TensorNetwork[{a, b}, {{1}, {1}}, {}];
    {
        TensorNetworkQ[tn],
        tn["Ranks"] === {1, 1},
        tn["FreeIndices"] === {}
    },
    {True, True, True},
    TestID -> "TensorNetwork_VectorDotProduct"
]

(* ============================================ *)
(* Edge Cases - Complex Tensors                *)
(* ============================================ *)

VerificationTest[
    A = RandomComplex[{-1 - I, 1 + I}, {2, 3}];
    B = RandomComplex[{-1 - I, 1 + I}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    {
        TensorNetworkQ[tn],
        tn["Dimensions"] === {{2, 3}, {3, 4}}
    },
    {True, True},
    TestID -> "TensorNetwork_ComplexTensors"
]

(* ============================================ *)
(* Edge Cases - Large Network                  *)
(* ============================================ *)

VerificationTest[
    rtn = RandomTensorNetwork[{20, 30}, 2, 0];
    {
        TensorNetworkQ[rtn],
        TensorNetworkSize[rtn] === 20
    },
    {True, True},
    TestID -> "TensorNetwork_LargeNetwork"
]
