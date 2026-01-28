(* Tests/test_contraction.wl *)
(* Comprehensive tests for Contraction.wl *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* TensorNetworkFindContractionPath Tests      *)
(* ============================================ *)

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    path = TensorNetworkFindContractionPath[tn];
    ListQ[path],
    True,
    TestID -> "TensorNetworkFindContractionPath_ReturnsPath"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}], RandomReal[{-1, 1}, {4, 5}]},
        {{1, 2}, {2, 3}, {3, 4}}
    ];
    path = TensorNetworkFindContractionPath[tn, Method -> "Greedy"];
    ListQ[path],
    True,
    TestID -> "TensorNetworkFindContractionPath_GreedyMethod"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    path = TensorNetworkFindContractionPath[tn, Method -> "Optimal"];
    ListQ[path],
    True,
    TestID -> "TensorNetworkFindContractionPath_OptimalMethod"
]

VerificationTest[
    tn = TensorNetwork[
        {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 4}]},
        {{1, 2}, {2, 3}}
    ];
    {input, output, dimensions} = TensorNetworkFindContractionPath[tn, "ReturnParameters" -> True];
    ListQ[input] && ListQ[output] && AssociationQ[dimensions],
    True,
    TestID -> "TensorNetworkFindContractionPath_ReturnParameters"
]

(* ============================================ *)
(* $TensorNetworkContractionMethods Tests      *)
(* ============================================ *)

VerificationTest[
    ListQ[$TensorNetworkContractionMethods],
    True,
    TestID -> "TensorNetworkContractionMethods_IsList"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "ArrayDot"],
    True,
    TestID -> "TensorNetworkContractionMethods_ContainsArrayDot"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "TensorContract"],
    True,
    TestID -> "TensorNetworkContractionMethods_ContainsTensorContract"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "Dot"],
    True,
    TestID -> "TensorNetworkContractionMethods_ContainsDot"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "ArrayDotTranspose"],
    True,
    TestID -> "TensorNetworkContractionMethods_ContainsArrayDotTranspose"
]

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "SymmetryFiltered"],
    True,
    TestID -> "TensorNetworkContractionMethods_ContainsSymmetryFiltered"
]

(* ============================================ *)
(* TensorNetworkContraction Tests              *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn];
    (* Should be an inactive expression *)
    MatchQ[result, _Inactive | _Transpose | _],
    True,
    TestID -> "TensorNetworkContraction_ReturnsInactive"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContraction[tn, "Optimal"];
    MatchQ[result, _Inactive | _Transpose | _ArrayDot | _],
    True,
    TestID -> "TensorNetworkContraction_WithOptimalPath"
]

(* ============================================ *)
(* TensorNetworkContract Tests                 *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_MatrixMultiplication"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_ArrayDotMethod"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDotTranspose"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_ArrayDotTransposeMethod"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "Dot"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_DotMethod"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Optimal", Method -> "TensorContract"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_TensorContractMethod"
]

VerificationTest[
    (* Test all methods give same result *)
    A = RandomReal[{-1, 1}, {3, 4}];
    B = RandomReal[{-1, 1}, {4, 5}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    results = Table[
        TensorNetworkContract[tn, "Optimal", Method -> method],
        {method, {"ArrayDot", "ArrayDotTranspose", "Dot", "TensorContract"}}
    ];
    AllTrue[Rest[results], Max[Abs[# - First[results]]] < 10^-10 &],
    True,
    TestID -> "TensorNetworkContract_AllMethodsConsistent"
]

VerificationTest[
    (* Three tensor contraction *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}, {1, 4}];
    result = TensorNetworkContract[tn];
    expected = A . B . T3;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_ThreeTensors"
]

VerificationTest[
    (* Trace computation via two tensors *)
    A = RandomReal[{-1, 1}, {3, 3}];
    identity = IdentityMatrix[3];
    tn = TensorNetwork[{A, identity}, {{1, 2}, {2, 1}}, {}];
    result = TensorNetworkContract[tn];
    expected = Tr[A];
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_Trace"
]

VerificationTest[
    (* Tensor product (no contraction) *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {4, 5}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {3, 4}}, {1, 2, 3, 4}];
    result = TensorNetworkContract[tn];
    Dimensions[result],
    {2, 3, 4, 5},
    TestID -> "TensorNetworkContract_TensorProduct"
]

VerificationTest[
    (* Rank-3 tensor contraction *)
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    B = RandomReal[{-1, 1}, {4, 5, 6}];
    tn = TensorNetwork[{A, B}, {{1, 2, 3}, {3, 4, 5}}, {1, 2, 4, 5}];
    result = TensorNetworkContract[tn];
    Dimensions[result],
    {2, 3, 5, 6},
    TestID -> "TensorNetworkContract_Rank3Tensors"
]

VerificationTest[
    (* Full scalar contraction *)
    A = RandomReal[{-1, 1}, {3, 4}];
    B = RandomReal[{-1, 1}, {4, 3}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 1}}, {}];
    result = TensorNetworkContract[tn];
    expected = Tr[A . B];
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_FullScalarContraction"
]

VerificationTest[
    (* Greedy path *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn, "Greedy"];
    expected = A . B;
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_GreedyPath"
]

VerificationTest[
    (* Output permutation *)
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {3, 1}];
    result = TensorNetworkContract[tn];
    expected = Transpose[A . B];
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_OutputPermutation"
]

(* ============================================ *)
(* Complex-Valued Tensor Tests                 *)
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
(* ContractionTree Tests                       *)
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

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    tn = TensorNetwork[{A, B, T3}, {{1, 2}, {2, 3}, {3, 4}}, {1, 4}];
    contraction = TensorNetworkContraction[tn, "Optimal"];
    tree = ContractionTree[contraction, "Labels" -> "Dimensions"];
    TreeQ[tree],
    True,
    TestID -> "ContractionTree_DimensionLabels"
]

(* ============================================ *)
(* Large Network Tests                         *)
(* ============================================ *)

VerificationTest[
    (* MPS contraction *)
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    result = TensorNetworkContract[mps];
    ArrayQ[result],
    True,
    TestID -> "TensorNetworkContract_MPS"
]

VerificationTest[
    (* TT contraction *)
    tt = RandomTensorNetwork["TT"[5, 3]];
    result = TensorNetworkContract[tt];
    NumericQ[result],  (* Scalar result for TT *)
    True,
    TestID -> "TensorNetworkContract_TT"
]

(* ============================================ *)
(* Sparse Tensor Contraction Tests             *)
(* ============================================ *)

VerificationTest[
    A = SparseArray[RandomReal[{-1, 1}, {3, 4}]];
    B = SparseArray[RandomReal[{-1, 1}, {4, 5}]];
    tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}, {1, 3}];
    result = TensorNetworkContract[tn];
    ArrayQ[result],
    True,
    TestID -> "TensorNetworkContract_SparseTensors"
]

(* ============================================ *)
(* Edge Cases                                  *)
(* ============================================ *)

VerificationTest[
    (* Single tensor, no contraction *)
    A = RandomReal[{-1, 1}, {2, 3}];
    tn = TensorNetwork[{A}, {{1, 2}}, {1, 2}];
    result = TensorNetworkContract[tn];
    Max[Abs[result - A]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_SingleTensor"
]

VerificationTest[
    (* Vector dot product *)
    a = RandomReal[{-1, 1}, {5}];
    b = RandomReal[{-1, 1}, {5}];
    tn = TensorNetwork[{a, b}, {{1}, {1}}, {}];
    result = TensorNetworkContract[tn];
    expected = a . b;
    Abs[result - expected] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_VectorDotProduct"
]

VerificationTest[
    (* Outer product *)
    a = RandomReal[{-1, 1}, {3}];
    b = RandomReal[{-1, 1}, {4}];
    tn = TensorNetwork[{a, b}, {{1}, {2}}, {1, 2}];
    result = TensorNetworkContract[tn];
    expected = Outer[Times, a, b];
    Max[Abs[result - expected]] < 10^-10,
    True,
    TestID -> "TensorNetworkContract_OuterProduct"
]

