(* Tests/test_symmetry_filtered.wl *)
(* Tests for SymmetryFiltered contraction method *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* Also load the Symmetry subpackage *)
Needs["Wolfram`TensorNetworks`Symmetry`"];

(* ============================================ *)
(* Test: SymmetryFiltered gives same result as ArrayDot *)
(* ============================================ *)

VerificationTest[
    (* Simple matrix multiplication *)
    dim = 20;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];

    (* Create charges (5 sectors) *)
    charges = Mod[Range[dim], 5] - 2;

    (* Build TensorNetwork *)
    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];
    indexCharges = <|3 -> charges|>;

    (* Compare methods *)
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    resultSymFiltered = TensorNetworkContract[tn, "Optimal",
        Method -> "SymmetryFiltered",
        "IndexCharges" -> indexCharges
    ];

    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10,
    True,
    TestID -> "SymmetryFiltered_MatchesArrayDot_Matrix"
]

(* ============================================ *)
(* Test: SymmetryFiltered with rank-3 tensors  *)
(* ============================================ *)

VerificationTest[
    (* MPS-like tensors *)
    chi = 15;
    d = 2;
    A = RandomReal[{-1, 1}, {chi, d, chi}];
    B = RandomReal[{-1, 1}, {chi, d, chi}];

    (* Create charges for bond dimension *)
    bondCharges = Mod[Range[chi], 5] - 2;

    (* Build TensorNetwork: contract over right bond of A with left bond of B *)
    tn = TensorNetwork[{A, B}, {{1, 2, 5}, {5, 3, 4}}, {1, 2, 3, 4}];
    indexCharges = <|5 -> bondCharges|>;

    (* Compare methods *)
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    resultSymFiltered = TensorNetworkContract[tn, "Optimal",
        Method -> "SymmetryFiltered",
        "IndexCharges" -> indexCharges
    ];

    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10,
    True,
    TestID -> "SymmetryFiltered_MatchesArrayDot_Rank3"
]

(* ============================================ *)
(* Test: SymmetryFiltered fallback without charges *)
(* ============================================ *)

VerificationTest[
    (* When no IndexCharges provided, should fall back to ArrayDot *)
    dim = 10;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];

    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];

    (* This should issue a warning message and fall back to ArrayDot *)
    resultSymFiltered = Quiet[
        TensorNetworkContract[tn, "Optimal", Method -> "SymmetryFiltered"],
        {contractTensorPair::nocharges}
    ];
    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];

    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-10,
    True,
    TestID -> "SymmetryFiltered_FallbackWithoutCharges"
]

(* ============================================ *)
(* Test: Method option is registered           *)
(* ============================================ *)

VerificationTest[
    MemberQ[$TensorNetworkContractionMethods, "SymmetryFiltered"],
    True,
    TestID -> "SymmetryFiltered_InMethodList"
]

(* ============================================ *)
(* Test: All existing methods still work       *)
(* ============================================ *)

VerificationTest[
    dim = 10;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];
    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];

    (* Test all methods work *)
    results = Table[
        TensorNetworkContract[tn, "Optimal", Method -> method],
        {method, {"ArrayDot", "ArrayDotTranspose", "Dot", "TensorContract"}}
    ];

    (* All should give the same result *)
    AllTrue[Rest[results], Max[Abs[# - First[results]]] < 10^-10 &],
    True,
    TestID -> "AllMethods_StillWork"
]

(* ============================================ *)
(* Test: ChargeVector functions work           *)
(* ============================================ *)

VerificationTest[
    charges = {0, 1, -1, 0, 1, -1, 2, -2};
    cv = ChargeVector[charges];
    ChargeVectorQ[cv],
    True,
    TestID -> "ChargeVector_Creation"
]

VerificationTest[
    (* Test AllowedContractions with plain lists *)
    qA = {0, 1, -1};
    qB = {0, -1, 1};
    allowed = AllowedContractions[qA, qB];
    (* 0+0=0, 1+(-1)=0, (-1)+1=0 *)
    Sort[allowed] === Sort[{{1, 1}, {2, 2}, {3, 3}}],
    True,
    TestID -> "AllowedContractions_SimpleCharges"
]

VerificationTest[
    (* Test AllowedContractions with ChargeVector objects *)
    (* Use unique charges to ensure only diagonal pairs match *)
    charges = {0, 1, -1};  (* All unique charges *)
    cvA = ChargeVector[charges];
    cvB = ChargeVector[-charges];  (* Negated: {0, -1, 1} *)
    allowed = AllowedContractions[cvA, cvB];
    (* Pairs where cvA[i] + cvB[j] = 0:
       (1,1): 0+0=0, (2,2): 1+(-1)=0, (3,3): (-1)+1=0 *)
    Sort[allowed] === Sort[{{1, 1}, {2, 2}, {3, 3}}],
    True,
    TestID -> "AllowedContractions_ChargeVectorPairs"
]

(* ============================================ *)
(* Test: Large tensor with many sectors        *)
(* ============================================ *)

VerificationTest[
    (* Larger test to verify numerical stability *)
    dim = 50;
    nSectors = 10;
    A = RandomReal[{-1, 1}, {dim, dim}];
    B = RandomReal[{-1, 1}, {dim, dim}];

    charges = Mod[Range[dim], nSectors] - nSectors/2;

    tn = TensorNetwork[{A, B}, {{1, 3}, {3, 2}}, {1, 2}];
    indexCharges = <|3 -> charges|>;

    resultArrayDot = TensorNetworkContract[tn, "Optimal", Method -> "ArrayDot"];
    resultSymFiltered = TensorNetworkContract[tn, "Optimal",
        Method -> "SymmetryFiltered",
        "IndexCharges" -> indexCharges
    ];

    Max[Abs[resultArrayDot - resultSymFiltered]] < 10^-9,
    True,
    TestID -> "SymmetryFiltered_LargeTensor"
]
