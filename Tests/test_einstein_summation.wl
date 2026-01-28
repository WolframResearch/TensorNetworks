(* Tests/test_einstein_summation.wl *)
(* Comprehensive tests for EinsteinSummation.wl *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* EinsteinSummation - List Input Tests        *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}} -> {"i", "k"}, {A, B}];
    expected = A . B;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_MatrixMultiplication"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {3, 3}];
    result = EinsteinSummation[{{"i", "i"}}, {A}];
    expected = Tr[A];
    Abs[ActivateTensors[result] - expected] < 10^-10,
    True,
    TestID -> "EinsteinSummation_Trace"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {3, 4}];
    B = RandomReal[{-1, 1}, {4, 3}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "i"}} -> {}, {A, B}];
    expected = Tr[A . B];
    Abs[ActivateTensors[result] - expected] < 10^-10,
    True,
    TestID -> "EinsteinSummation_FullContraction"
]

VerificationTest[
    a = RandomReal[{-1, 1}, {5}];
    b = RandomReal[{-1, 1}, {5}];
    result = EinsteinSummation[{{"i"}, {"i"}} -> {}, {a, b}];
    expected = a . b;
    Abs[ActivateTensors[result] - expected] < 10^-10,
    True,
    TestID -> "EinsteinSummation_VectorDotProduct"
]

VerificationTest[
    a = RandomReal[{-1, 1}, {3}];
    b = RandomReal[{-1, 1}, {4}];
    result = EinsteinSummation[{{"i"}, {"j"}} -> {"i", "j"}, {a, b}];
    expected = Outer[Times, a, b];
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_OuterProduct"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    B = RandomReal[{-1, 1}, {4, 5, 6}];
    result = EinsteinSummation[{{"i", "j", "k"}, {"k", "l", "m"}} -> {"i", "j", "l", "m"}, {A, B}];
    activated = ActivateTensors[result];
    Dimensions[activated],
    {2, 3, 5, 6},
    TestID -> "EinsteinSummation_Rank3Tensors"
]

(* ============================================ *)
(* EinsteinSummation - Automatic Output Tests  *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}}, {A, B}];
    activated = ActivateTensors[result];
    Dimensions[activated],
    {2, 4},
    TestID -> "EinsteinSummation_AutomaticOutput"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}} -> Automatic, {A, B}];
    activated = ActivateTensors[result];
    Dimensions[activated],
    {2, 4},
    TestID -> "EinsteinSummation_ExplicitAutomatic"
]

(* ============================================ *)
(* EinsteinSummation - String Input Tests      *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    result = EinsteinSummation["ij,jk->ik", {A, B}];
    expected = A . B;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_StringInput_MatrixMult"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {3, 3}];
    result = EinsteinSummation["ii", {A}];
    expected = Tr[A];
    Abs[ActivateTensors[result] - expected] < 10^-10,
    True,
    TestID -> "EinsteinSummation_StringInput_Trace"
]

VerificationTest[
    a = RandomReal[{-1, 1}, {3}];
    b = RandomReal[{-1, 1}, {4}];
    result = EinsteinSummation["i,j->ij", {a, b}];
    expected = Outer[Times, a, b];
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_StringInput_OuterProduct"
]

(* ============================================ *)
(* EinsteinSummation - Permutation Tests       *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}} -> {"k", "i"}, {A, B}];
    expected = Transpose[A . B];
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_OutputPermutation"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4}];
    result = EinsteinSummation[{{"i", "j", "k"}} -> {"k", "j", "i"}, {A}];
    expected = Transpose[A, {3, 2, 1}];
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_Transpose"
]

(* ============================================ *)
(* EinsteinSummation - Multi-Tensor Tests      *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}, {"k", "l"}} -> {"i", "l"}, {A, B, T3}];
    expected = A . B . T3;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_ThreeTensors"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    T3 = RandomReal[{-1, 1}, {4, 5}];  (* Renamed from C to avoid conflict with built-in *)
    T4 = RandomReal[{-1, 1}, {5, 6}];  (* Renamed from D to avoid conflict with built-in *)
    result = EinsteinSummation[
        {{"a", "b"}, {"b", "c"}, {"c", "d"}, {"d", "e"}} -> {"a", "e"},
        {A, B, T3, T4}
    ];
    expected = A . B . T3 . T4;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_FourTensors"
]

(* ============================================ *)
(* EinsteinSummation - Scalar Tests            *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    scalar = 2.5;
    result = EinsteinSummation[{{}, {"i", "j"}} -> {"i", "j"}, {scalar, A}];
    expected = scalar * A;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_ScalarMultiplication"
]

VerificationTest[
    scalar1 = 2.0;
    scalar2 = 3.0;
    result = EinsteinSummation[{{}, {}} -> {}, {scalar1, scalar2}];
    expected = 6.0;
    Abs[ActivateTensors[result] - expected] < 10^-10,
    True,
    TestID -> "EinsteinSummation_TwoScalars"
]

(* ============================================ *)
(* TensorJoin Tests                            *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {4, 3}];
    {indices, joined} = TensorJoin[{{"i", "k"}, {"j", "k"}}, {A, B}];
    ListQ[indices] && ArrayQ[joined],
    True,
    TestID -> "TensorJoin_Basic"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {2, 4}];
    {indices, joined} = TensorJoin[{{"i", "j"}, {"i", "k"}}, {A, B}];
    MemberQ[indices, "i"],
    True,
    TestID -> "TensorJoin_SharedIndex"
]

(* ============================================ *)
(* ActivateTensors Tests                       *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    B = RandomReal[{-1, 1}, {3, 4}];
    inactive = EinsteinSummation[{{"i", "j"}, {"j", "k"}} -> {"i", "k"}, {A, B}];
    active = ActivateTensors[inactive];
    ArrayQ[active],
    True,
    TestID -> "ActivateTensors_ProducesArray"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3}];
    active = ActivateTensors[A];
    active === A,
    True,
    TestID -> "ActivateTensors_AlreadyActive"
]

VerificationTest[
    inactive = Inactive[TensorProduct][RandomReal[{-1, 1}, {2}], RandomReal[{-1, 1}, {3}]];
    active = ActivateTensors[inactive];
    ArrayQ[active],
    True,
    TestID -> "ActivateTensors_InactiveTensorProduct"
]

(* ============================================ *)
(* Complex-Valued Tensor Tests                 *)
(* ============================================ *)

VerificationTest[
    A = RandomComplex[{-1 - I, 1 + I}, {2, 3}];
    B = RandomComplex[{-1 - I, 1 + I}, {3, 4}];
    result = EinsteinSummation[{{"i", "j"}, {"j", "k"}} -> {"i", "k"}, {A, B}];
    expected = A . B;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_ComplexTensors"
]

(* ============================================ *)
(* Edge Cases and Error Handling               *)
(* ============================================ *)

VerificationTest[
    A = RandomReal[{-1, 1}, {3}];
    result = EinsteinSummation[{{"i"}}, {A}];
    expected = A;
    Max[Abs[ActivateTensors[result] - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_SingleVector"
]

VerificationTest[
    A = RandomReal[{-1, 1}, {2, 3, 4, 5}];
    B = RandomReal[{-1, 1}, {5, 6, 7}];
    result = EinsteinSummation[{{"a", "b", "c", "d"}, {"d", "e", "f"}} -> {"a", "b", "c", "e", "f"}, {A, B}];
    activated = ActivateTensors[result];
    Dimensions[activated],
    {2, 3, 4, 6, 7},
    TestID -> "EinsteinSummation_HighRankTensors"
]

VerificationTest[
    (* Diagonal extraction *)
    A = RandomReal[{-1, 1}, {3, 3, 4}];
    result = EinsteinSummation[{{"i", "i", "j"}} -> {"j"}, {A}];
    activated = ActivateTensors[result];
    expected = Sum[A[[i, i, All]], {i, 3}];
    Max[Abs[activated - expected]] < 10^-10,
    True,
    TestID -> "EinsteinSummation_DiagonalExtraction"
]

VerificationTest[
    (* Batched matrix multiplication *)
    A = RandomReal[{-1, 1}, {2, 3, 4}];  (* Batch of 2 3x4 matrices *)
    B = RandomReal[{-1, 1}, {2, 4, 5}];  (* Batch of 2 4x5 matrices *)
    result = EinsteinSummation[{{"b", "i", "j"}, {"b", "j", "k"}} -> {"b", "i", "k"}, {A, B}];
    activated = ActivateTensors[result];
    Dimensions[activated],
    {2, 3, 5},
    TestID -> "EinsteinSummation_BatchedMatrixMult"
]

