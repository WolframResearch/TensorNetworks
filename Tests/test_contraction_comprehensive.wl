(* Tests/test_contraction_comprehensive.wl *)
(* Comprehensive tests for Contraction.wl - ALL patterns, ALL options, EXACT verification *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* From TensorNetwork Input                    *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    path = TensorNetworkFindContractionPath[tn];
    {
        CanonicalPathQ[path],
        ListQ[path],
        AllTrue[path, MatchQ[#, {_Integer, _Integer}] &]
    },
    {True, True, True},
    TestID -> "FindContractionPath_FromTensorNetwork_ReturnsCanonicalPath"
]

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* Method -> "Optimal" (default)               *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}];
    path = TensorNetworkFindContractionPath[tn, Method -> "Optimal"];
    {
        CanonicalPathQ[path],
        Length[path] === 2  (* 3 tensors -> 2 contractions *)
    },
    {True, True},
    TestID -> "FindContractionPath_Method_Optimal"
]

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* Method -> "Greedy"                          *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}];
    path = TensorNetworkFindContractionPath[tn, Method -> "Greedy"];
    {
        CanonicalPathQ[path],
        Length[path] === 2
    },
    {True, True},
    TestID -> "FindContractionPath_Method_Greedy"
]

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* Method -> specific optimization targets     *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    pathSize = TensorNetworkFindContractionPath[tn, Method -> "size"];
    pathFlops = TensorNetworkFindContractionPath[tn, Method -> "flops"];
    {
        CanonicalPathQ[pathSize],
        CanonicalPathQ[pathFlops]
    },
    {True, True},
    TestID -> "FindContractionPath_Method_SizeAndFlops"
]

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* "ReturnParameters" -> False (default)       *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    result = TensorNetworkFindContractionPath[tn, "ReturnParameters" -> False];
    CanonicalPathQ[result],
    True,
    TestID -> "FindContractionPath_ReturnParameters_False"
]

(* ============================================ *)
(* TensorNetworkFindContractionPath            *)
(* "ReturnParameters" -> True                  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    result = TensorNetworkFindContractionPath[tn, "ReturnParameters" -> True];
    {
        ListQ[result],
        Length[result] === 3,
        ListQ[result[[1]]],   (* input *)
        ListQ[result[[2]]],   (* output *)
        AssociationQ[result[[3]]]  (* dimensions *)
    },
    {True, True, True, True, True},
    TestID -> "FindContractionPath_ReturnParameters_True_Structure"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
    {input, output, dimensions} = TensorNetworkFindContractionPath[tn, "ReturnParameters" -> True];
    {
        Length[input] === 2,  (* Two tensors *)
        Length[dimensions] > 0
    },
    {True, True},
    TestID -> "FindContractionPath_ReturnParameters_True_Content"
]

(* ============================================ *)
(* $TensorNetworkContractionMethods            *)
(* Verify all expected methods exist           *)
(* ============================================ *)

VerificationTest[
    ListQ[$TensorNetworkContractionMethods],
    True,
    TestID -> "ContractionMethods_IsList"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "ArrayDot"],
    True,
    TestID -> "ContractionMethods_Contains_ArrayDot"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "ArrayDotTranspose"],
    True,
    TestID -> "ContractionMethods_Contains_ArrayDotTranspose"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "Dot"],
    True,
    TestID -> "ContractionMethods_Contains_Dot"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "TensorContract"],
    True,
    TestID -> "ContractionMethods_Contains_TensorContract"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "TableSum"],
    True,
    TestID -> "ContractionMethods_Contains_TableSum"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "SymmetryFiltered"],
    True,
    TestID -> "ContractionMethods_Contains_SymmetryFiltered"
]

VerificationTest[
    Length[$TensorNetworkContractionMethods],
    6,
    TestID -> "ContractionMethods_ExactCount"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Default options - "Inactive" -> True        *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn];
    (* Result should contain Inactive expressions *)
    FreeQ[result, Inactive] === False,
    True,
    TestID -> "TensorNetworkContraction_Default_ReturnsInactive"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn];
    activated = ActivateTensors[result];
    expected = A . B;
    Max[Abs[activated - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContraction_Default_ActivatesCorrectly"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* "Inactive" -> True (explicit)               *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Inactive" -> True];
    FreeQ[result, Inactive] === False,
    True,
    TestID -> "TensorNetworkContraction_Inactive_True"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* "Inactive" -> False                         *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Inactive" -> False];
    {
        FreeQ[result, Inactive],
        ArrayQ[result],
        Max[Abs[result - A . B]] < 10^-10
    },
    {True, True, True},
    TestID -> "TensorNetworkContraction_Inactive_False"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Method -> "ArrayDot" with path              *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal", Method -> "ArrayDot", "Inactive" -> True];
    {
        (* Should contain Inactive[ArrayDot] *)
        !FreeQ[result, Inactive[ArrayDot]],
        (* Activating should give correct result *)
        Max[Abs[ActivateTensors[result] - A . B]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContraction_Method_ArrayDot_VerifyStructure"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Method -> "ArrayDotTranspose"               *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal", Method -> "ArrayDotTranspose", "Inactive" -> True];
    activated = ActivateTensors[result];
    expected = A . B;
    Max[Abs[activated - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContraction_Method_ArrayDotTranspose"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Method -> "Dot"                             *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal", Method -> "Dot", "Inactive" -> True];
    {
        !FreeQ[result, Inactive[Dot]],
        Max[Abs[ActivateTensors[result] - A . B]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContraction_Method_Dot_VerifyStructure"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Method -> "TensorContract"                  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal", Method -> "TensorContract", "Inactive" -> True];
    {
        !FreeQ[result, Inactive[TensorContract]],
        Max[Abs[ActivateTensors[result] - A . B]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContraction_Method_TensorContract_VerifyStructure"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* Method -> "TableSum"                        *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal", Method -> "TableSum", "Inactive" -> True];
    activated = ActivateTensors[result];
    expected = A . B;
    Max[Abs[activated - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContraction_Method_TableSum"
]

(* ============================================ *)
(* TensorNetworkContraction                    *)
(* All methods give same numerical result      *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {3, 4}];
    B = RandomReal[{-1, 1}, {4, 5}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    results = Table[
        ActivateTensors[TensorNetworkContraction[tn, "Optimal", Method -> method, "Inactive" -> True]],
        {method, {"ArrayDot", "ArrayDotTranspose", "Dot", "TensorContract"}}
    ];
    reference = A . B;
    AllTrue[results, Max[Abs[# - reference]] < 10^-10 &],
    True,
    TestID -> "TensorNetworkContraction_AllMethods_SameResult"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Returns activated result (not Inactive)     *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    {
        FreeQ[result, Inactive],  (* No Inactive wrappers *)
        ArrayQ[result],
        Max[Abs[result - A . B]] < 10^-10
    },
    {True, True, True},
    TestID -> "TensorNetworkContract_ReturnsActivated"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Matrix multiplication                       *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    expected = A . B;
    {
        Dimensions[result] === {2, 4},
        Max[Abs[result - expected]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContract_MatrixMultiplication"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* All contraction methods                     *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    expected = A . B;
    Max[Abs[resultArrayDot - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Method_ArrayDot"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDotTranspose"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Method_ArrayDotTranspose"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "Dot"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Method_Dot"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "TensorContract"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Method_TensorContract"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Three tensor chain                          *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}, {1, 4}];
    result = TensorNetworkContract[tn];
    expected = A . B . T3;
    {
        Dimensions[result] === {2, 5},
        Max[Abs[result - expected]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContract_ThreeTensorChain"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Vector dot product (full contraction)       *)
(* ============================================ *)

VerificationTest[
    a = RandomReal[{-1, 1}, {5}];
    b = RandomReal[{-1, 1}, {5}];
    tn = TensorNetwork[{a, b}, {{1}, {1}}, {}];
    result = TensorNetworkContract[tn];
    expected = a . b;
    {
        NumericQ[result],
        Abs[result - expected] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContract_VectorDotProduct"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Outer product (no contraction)              *)
(* ============================================ *)

VerificationTest[
    a = RandomReal[{-1, 1}, {3}];
    b = RandomReal[{-1, 1}, {4}];
    tn = TensorNetwork[{a, b}, {{1}, {2}}, {1, 2}];
    result = TensorNetworkContract[tn];
    expected = Outer[Times, a, b];
    {
        Dimensions[result] === {3, 4},
        Max[Abs[result - expected]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContract_OuterProduct"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Trace computation                           *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {4, 4}];
    identity = IdentityMatrix[4];
    tn = TensorNetwork[{A, identity}, {{1, 2}, {2, 1}}, {}];
    result = TensorNetworkContract[tn];
    expected = Tr[A];
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Trace"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Full scalar contraction (Tr[A.B])           *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {3, 4}];
    B = RandomReal[{-1, 1}, {4, 3}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 1}}, {}];
    result = TensorNetworkContract[tn];
    expected = Tr[A . B];
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_FullScalarContraction"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Output permutation                          *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {3, 1}];
    result = TensorNetworkContract[tn];
    expected = Transpose[A . B];
    {
        Dimensions[result] === {4, 2},
        Max[Abs[result - expected]] < 10^-10
    },
    {True, True},
    TestID -> "TensorNetworkContract_OutputPermutation"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Rank-3 tensor contraction                   *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    B = RandomReal[{-1, 1}, {4, 5, 6}];
    tn = TensorNetwork[{A, B}, {{1, 2, 3}, {3, 4, 5}}, {1, 2, 4, 5}];
    result = TensorNetworkContract[tn];
    {
        Dimensions[result] === {2, 3, 5, 6},
        ArrayQ[result]
    },
    {True, True},
    TestID -> "TensorNetworkContract_Rank3Tensors"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Single tensor (no contraction)              *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}, {1, 2}];
    result = TensorNetworkContract[tn];
    Max[Abs[result - A]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SingleTensor"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* With Greedy path                            *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Greedy"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_GreedyPath"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Complex-valued tensors                      *)
(* ============================================ *)

VerificationTest[
    A = RandomComplex[{-1 - I, 1 + I}, {2, 3}];
    B = RandomComplex[{-1 - I, 1 + I}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_ComplexTensors"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* Sparse tensors                              *)
(* ============================================ *)

VerificationTest[
    A = SparseArray[RandomReal[{-1, 1}, {3, 4}]];
    B = SparseArray[RandomReal[{-1, 1}, {4, 5}]];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    expected = Normal[A] . Normal[B];
    Max[Abs[Normal[result] - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SparseTensors"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* MPS contraction                             *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    result = TensorNetworkContract[mps];
    ArrayQ[result],
    True,
    TestID -> "TensorNetworkContract_MPS"
]

(* ============================================ *)
(* TensorNetworkContract                       *)
(* TT contraction (scalar result)              *)
(* ============================================ *)

VerificationTest[
    tt = RandomTensorNetwork["TT"[5, 3]];
    result = TensorNetworkContract[tt];
    NumericQ[result],
    True,
    TestID -> "TensorNetworkContract_TT_ScalarResult"
]

(* ============================================ *)
(* TensorNetworkContraction with IndexCharges  *)
(* (SymmetryFiltered method)                   *)
(* ============================================ *)

VerificationTest[
    dim = 10;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];
    charges = Mod[Range[dim], 5] - 2;
    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];
    indexCharges = <|3 -> charges|>;
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    resultSymFiltered = TensorNetworkContract[tn, "Optimal",
        Method -> "SymmetryFiltered",
        "IndexCharges" -> indexCharges
    ];
    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SymmetryFiltered_MatchesArrayDot"
]

VerificationTest[
    (* Without IndexCharges, SymmetryFiltered should fall back to ArrayDot *)
    dim = 10;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];
    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    resultSymFiltered = Quiet[
        TensorNetworkContract[tn, "Optimal", Method -> "SymmetryFiltered"],
        {contractTensorPair::nocharges}
    ];
    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SymmetryFiltered_FallbackWithoutCharges"
]

(* ============================================ *)
(* ContractionTree - Default Options           *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    contraction = TensorNetworkContraction[tn];
    tree = ContractionTree[contraction];
    TreeQ[tree],
    True,
    TestID -> "ContractionTree_ReturnsTree"
]

(* ============================================ *)
(* ContractionTree - "Labels" -> Automatic     *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    contraction = TensorNetworkContraction[tn, "Optimal"];
    tree = ContractionTree[contraction, "Labels" -> Automatic];
    TreeQ[tree],
    True,
    TestID -> "ContractionTree_Labels_Automatic"
]

(* ============================================ *)
(* ContractionTree - "Labels" -> "Dimensions"  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}, {1, 4}];
    contraction = TensorNetworkContraction[tn, "Optimal"];
    tree = ContractionTree[contraction, "Labels" -> "Dimensions"];
    TreeQ[tree],
    True,
    TestID -> "ContractionTree_Labels_Dimensions"
]

(* ============================================ *)
(* ContractionTree - Complex network           *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    contraction = TensorNetworkContraction[mps, "Optimal"];
    tree = ContractionTree[contraction];
    {
        TreeQ[tree],
        TreeDepth[tree] >= 1
    },
    {True, True},
    TestID -> "ContractionTree_MPS"
]

(* ============================================ *)
(* Edge Case: Multiple contracted indices      *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    B = RandomReal[{-1, 1}, {3, 4, 5}];
    tn = TensorNetwork[{A, B}, {{1, 2, 3}, {2, 3, 4}}, {1, 4}];
    result = TensorNetworkContract[tn];
    {
        Dimensions[result] === {2, 5},
        ArrayQ[result]
    },
    {True, True},
    TestID -> "TensorNetworkContract_MultipleContractedIndices"
]

(* ============================================ *)
(* Edge Case: Large network contraction        *)
(* ============================================ *)

VerificationTest[
    tensors = Table[RandomReal[{-1, 1}, {2, 2}], 5];
    hyperedges = {{1, 2}, {2, 3}, {3, 4}, {4, 5}, {5, 6}};
    tn = TensorNetwork[tensors, hyperedges, {1, 6}];
    result = TensorNetworkContract[tn];
    {
        ArrayQ[result],
        Dimensions[result] === {2, 2}
    },
    {True, True},
    TestID -> "TensorNetworkContract_FiveTensorChain"
]

(* ============================================ *)
(* Edge Case: Self-contraction (trace)         *)
(* within single tensor via TensorNetwork      *)
(* ============================================ *)

VerificationTest[
    (* Two matrices that contract to trace *)
    A = RandomReal[{-1, 1}, {3, 3}];
    B = IdentityMatrix[3];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 1}}, {}];
    result = TensorNetworkContract[tn];
    expected = Tr[A];
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SelfContraction_Trace"
]
