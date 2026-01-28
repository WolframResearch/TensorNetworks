(* Tests/test_symmetry.wl *)
(* Comprehensive tests for Symmetry module (YoungTableaux.wl and QuantumNumbers.wl) *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* Load the Symmetry subpackage *)
Needs["Wolfram`TensorNetworks`Symmetry`"];

(* ============================================ *)
(* YoungTableau Constructor Tests              *)
(* ============================================ *)

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    YoungTableauQ[yt],
    True,
    TestID -> "YoungTableau_Constructor_Explicit"
]

VerificationTest[
    (* Construct from partition *)
    yt = YoungTableau[{3, 2}];
    YoungTableauQ[yt],
    True,
    TestID -> "YoungTableau_Constructor_FromPartition"
]

VerificationTest[
    yt = YoungTableau[{4, 2, 1}];
    YoungTableauQ[yt],
    True,
    TestID -> "YoungTableau_Constructor_ThreeRows"
]

VerificationTest[
    yt = YoungTableau[{5}];
    YoungTableauQ[yt],
    True,
    TestID -> "YoungTableau_Constructor_SingleRow"
]

(* ============================================ *)
(* YoungTableauQ Tests                         *)
(* ============================================ *)

VerificationTest[
    YoungTableauQ[YoungTableau[{{1, 2}, {3}}]],
    True,
    TestID -> "YoungTableauQ_Valid"
]

VerificationTest[
    YoungTableauQ["not a tableau"],
    False,
    TestID -> "YoungTableauQ_InvalidInput_String"
]

VerificationTest[
    YoungTableauQ[123],
    False,
    TestID -> "YoungTableauQ_InvalidInput_Number"
]

VerificationTest[
    (* Invalid: row lengths not decreasing *)
    YoungTableauQ[YoungTableau[{{1}, {2, 3}}]],
    False,
    TestID -> "YoungTableauQ_InvalidRowLengths"
]

VerificationTest[
    (* Invalid: duplicate entries *)
    YoungTableauQ[YoungTableau[{{1, 1}, {2}}]],
    False,
    TestID -> "YoungTableauQ_DuplicateEntries"
]

(* ============================================ *)
(* TableauShape Tests                          *)
(* ============================================ *)

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    TableauShape[yt],
    {3, 2},
    TestID -> "TableauShape_Basic"
]

VerificationTest[
    yt = YoungTableau[{4, 2, 1}];
    TableauShape[yt],
    {4, 2, 1},
    TestID -> "TableauShape_FromPartition"
]

VerificationTest[
    yt = YoungTableau[{5}];
    TableauShape[yt],
    {5},
    TestID -> "TableauShape_SingleRow"
]

VerificationTest[
    TableauShape["not a tableau"],
    $Failed,
    TestID -> "TableauShape_InvalidInput"
]

(* ============================================ *)
(* TableauSize Tests                           *)
(* ============================================ *)

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    TableauSize[yt],
    5,
    TestID -> "TableauSize_Basic"
]

VerificationTest[
    yt = YoungTableau[{4, 2, 1}];
    TableauSize[yt],
    7,
    TestID -> "TableauSize_FromPartition"
]

VerificationTest[
    yt = YoungTableau[{1}];
    TableauSize[yt],
    1,
    TestID -> "TableauSize_SingleBox"
]

VerificationTest[
    TableauSize["not a tableau"],
    $Failed,
    TestID -> "TableauSize_InvalidInput"
]

(* ============================================ *)
(* HookLength Tests                            *)
(* ============================================ *)

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    HookLength[yt, {1, 1}],
    4,  (* 3 to the right + 1 below *)
    TestID -> "HookLength_TopLeftCorner"
]

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    HookLength[yt, {1, 3}],
    1,  (* Corner box *)
    TestID -> "HookLength_Corner"
]

VerificationTest[
    yt = YoungTableau[{{1, 2, 3}, {4, 5}}];
    HookLength[yt, {2, 1}],
    2,  (* 2 to the right, 0 below *)
    TestID -> "HookLength_SecondRow"
]

VerificationTest[
    HookLength["not a tableau", {1, 1}],
    $Failed,
    TestID -> "HookLength_InvalidInput"
]

(* ============================================ *)
(* TableauDimension Tests                      *)
(* ============================================ *)

VerificationTest[
    (* Standard tableau {2,1}: dimension should be 2 *)
    yt = YoungTableau[{2, 1}];
    TableauDimension[yt],
    2,
    TestID -> "TableauDimension_Partition21"
]

VerificationTest[
    (* Standard tableau {3}: dimension should be 1 (totally symmetric) *)
    yt = YoungTableau[{3}];
    TableauDimension[yt],
    1,
    TestID -> "TableauDimension_TotallySymmetric"
]

VerificationTest[
    (* Standard tableau {1,1,1}: dimension should be 1 (totally antisymmetric) *)
    yt = YoungTableau[{1, 1, 1}];
    TableauDimension[yt],
    1,
    TestID -> "TableauDimension_TotallyAntisymmetric"
]

VerificationTest[
    (* Standard tableau {2,2}: dimension should be 2 *)
    yt = YoungTableau[{2, 2}];
    TableauDimension[yt],
    2,
    TestID -> "TableauDimension_Partition22"
]

VerificationTest[
    TableauDimension["not a tableau"],
    $Failed,
    TestID -> "TableauDimension_InvalidInput"
]

(* ============================================ *)
(* YoungSymmetrize Tests                       *)
(* ============================================ *)

VerificationTest[
    (* Symmetrize a rank-3 tensor over {3} partition (totally symmetric) *)
    T = RandomReal[{-1, 1}, {2, 2, 2}];
    yt = YoungTableau[{3}];
    result = YoungSymmetrize[T, yt];
    ArrayQ[result],
    True,
    TestID -> "YoungSymmetrize_TotallySymmetric"
]

VerificationTest[
    (* Symmetrize a rank-3 tensor over {1,1,1} partition (totally antisymmetric) *)
    T = RandomReal[{-1, 1}, {3, 3, 3}];
    yt = YoungTableau[{1, 1, 1}];
    result = YoungSymmetrize[T, yt];
    ArrayQ[result],
    True,
    TestID -> "YoungSymmetrize_TotallyAntisymmetric"
]

VerificationTest[
    (* Mixed symmetry *)
    T = RandomReal[{-1, 1}, {2, 2, 2}];
    yt = YoungTableau[{2, 1}];
    result = YoungSymmetrize[T, yt];
    ArrayQ[result],
    True,
    TestID -> "YoungSymmetrize_MixedSymmetry"
]

VerificationTest[
    (* Rank mismatch should fail *)
    T = RandomReal[{-1, 1}, {2, 2}];  (* Rank 2 *)
    yt = YoungTableau[{3}];           (* Size 3 *)
    result = YoungSymmetrize[T, yt];
    result === $Failed,
    True,
    TestID -> "YoungSymmetrize_RankMismatch"
]

(* ============================================ *)
(* YoungProject Tests                          *)
(* ============================================ *)

VerificationTest[
    T = RandomReal[{-1, 1}, {2, 2, 2}];
    yt = YoungTableau[{3}];
    result = YoungProject[T, yt];
    ArrayQ[result],
    True,
    TestID -> "YoungProject_TotallySymmetric"
]

VerificationTest[
    T = RandomReal[{-1, 1}, {2, 2, 2}];
    yt = YoungTableau[{2, 1}];
    result = YoungProject[T, yt];
    ArrayQ[result],
    True,
    TestID -> "YoungProject_MixedSymmetry"
]

(* ============================================ *)
(* ChargeVector Constructor Tests              *)
(* ============================================ *)

VerificationTest[
    cv = ChargeVector[{0, 1, -1, 0, 1}];
    ChargeVectorQ[cv],
    True,
    TestID -> "ChargeVector_Constructor_Basic"
]

VerificationTest[
    cv = ChargeVector[{0, 0, 0}];
    ChargeVectorQ[cv],
    True,
    TestID -> "ChargeVector_Constructor_AllZero"
]

VerificationTest[
    cv = ChargeVector[{-5, -3, -1, 1, 3, 5}];
    ChargeVectorQ[cv],
    True,
    TestID -> "ChargeVector_Constructor_MixedCharges"
]

(* ============================================ *)
(* ChargeVectorQ Tests                         *)
(* ============================================ *)

VerificationTest[
    ChargeVectorQ[ChargeVector[{1, 2, 3}]],
    True,
    TestID -> "ChargeVectorQ_Valid"
]

VerificationTest[
    ChargeVectorQ["not a charge vector"],
    False,
    TestID -> "ChargeVectorQ_InvalidInput_String"
]

VerificationTest[
    ChargeVectorQ[{1, 2, 3}],
    False,
    TestID -> "ChargeVectorQ_PlainList"
]

(* ============================================ *)
(* AllowedContractions Tests                   *)
(* ============================================ *)

VerificationTest[
    qA = {0, 1, -1};
    qB = {0, -1, 1};
    allowed = AllowedContractions[qA, qB];
    Sort[allowed] === Sort[{{1, 1}, {2, 2}, {3, 3}}],
    True,
    TestID -> "AllowedContractions_SimpleCharges"
]

VerificationTest[
    cvA = ChargeVector[{0, 1, -1}];
    cvB = ChargeVector[{0, -1, 1}];
    allowed = AllowedContractions[cvA, cvB];
    Sort[allowed] === Sort[{{1, 1}, {2, 2}, {3, 3}}],
    True,
    TestID -> "AllowedContractions_ChargeVectors"
]

VerificationTest[
    qA = {1, 2, 3};
    qB = {-1, -2, -3};
    allowed = AllowedContractions[qA, qB];
    Sort[allowed] === Sort[{{1, 1}, {2, 2}, {3, 3}}],
    True,
    TestID -> "AllowedContractions_NonZeroCharges"
]

VerificationTest[
    qA = {0, 0, 0};
    qB = {0, 0, 0};
    allowed = AllowedContractions[qA, qB];
    Length[allowed] == 9,  (* All pairs allowed *)
    True,
    TestID -> "AllowedContractions_AllZero"
]

VerificationTest[
    qA = {1, 2, 3};
    qB = {4, 5, 6};  (* No pairs sum to zero *)
    allowed = AllowedContractions[qA, qB];
    allowed === {},
    True,
    TestID -> "AllowedContractions_NoAllowed"
]

(* ============================================ *)
(* ChargesConservedQ Tests                     *)
(* ============================================ *)

VerificationTest[
    ChargesConservedQ[{1, -1, 0}, {-1, 1, 0}],
    True,
    TestID -> "ChargesConservedQ_Conserved"
]

VerificationTest[
    ChargesConservedQ[{1, 2, 3}, {1, 2, 3}],
    False,
    TestID -> "ChargesConservedQ_NotConserved"
]

VerificationTest[
    cvA = ChargeVector[{1, -1}];
    cvB = ChargeVector[{-1, 1}];
    ChargesConservedQ[cvA, cvB],
    True,
    TestID -> "ChargesConservedQ_ChargeVectors"
]

(* ============================================ *)
(* IndicesWithCharge Tests                     *)
(* ============================================ *)

VerificationTest[
    cv = ChargeVector[{0, 1, 0, -1, 0}];
    indices = IndicesWithCharge[cv, 0];
    Sort[indices] === {1, 3, 5},
    True,
    TestID -> "IndicesWithCharge_ChargeZero"
]

VerificationTest[
    cv = ChargeVector[{0, 1, 0, -1, 0}];
    indices = IndicesWithCharge[cv, 1];
    indices === {2},
    True,
    TestID -> "IndicesWithCharge_ChargeOne"
]

VerificationTest[
    charges = {0, 1, 0, -1, 0};
    indices = IndicesWithCharge[charges, -1];
    indices === {4},
    True,
    TestID -> "IndicesWithCharge_PlainList"
]

VerificationTest[
    cv = ChargeVector[{1, 2, 3}];
    indices = IndicesWithCharge[cv, 5];  (* Charge not present *)
    indices === {},
    True,
    TestID -> "IndicesWithCharge_NotFound"
]

(* ============================================ *)
(* ChargeVector Arithmetic Tests               *)
(* ============================================ *)

VerificationTest[
    cv = ChargeVector[{1, 2, 3}];
    negated = -cv;
    ChargeVectorQ[negated] && negated[[1]] === {-1, -2, -3},
    True,
    TestID -> "ChargeVector_Negation"
]

(* ============================================ *)
(* Integration Tests with TensorNetworkContract *)
(* ============================================ *)

VerificationTest[
    (* Symmetry-filtered contraction should give same result as ArrayDot *)
    (* Note: This test only runs if SymmetryFiltered method is available *)
    If[MemberQ[$TensorNetworkContractionMethods, "SymmetryFiltered"],
        Module[{dim = 10, A, B, charges, tn, indexCharges, resultArrayDot, resultSymFiltered},
            A = RandomReal[{-1, 1}, {dim, dim}];
            B = RandomReal[{-1, 1}, {dim, dim}];
            charges = Mod[Range[dim], 3] - 1;
            tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];
            indexCharges = <|3 -> charges|>;
            resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
            resultSymFiltered = TensorNetworkContract[tn, "Optimal",
                Method -> "SymmetryFiltered",
                "IndexCharges" -> indexCharges
            ];
            Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10
        ],
        True  (* Skip test if method not available *)
    ],
    True,
    TestID -> "SymmetryFiltered_Integration_Consistent"
]

