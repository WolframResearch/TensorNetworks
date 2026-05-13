(* Tests/external_validation/paclet_fuzz/fuzz_contraction_paths.wl

   Property-based fuzz layer for OptimalContractionPath + GreedyContractionPath.
   The core invariant: contracting the same TN via the two different paths
   must produce the same numerical result. This is stronger than checking
   external cost values (which depend on whether indices are paclet-internal
   Superscript expressions or cotengra-style strings, and whether the network
   has hyper-edges that get binarized internally).

   Coverage: MPS / PEPS / TT / MPO topologies + edge cases + determinism +
   timing sentinel.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-paths] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];


(* Helper: assert that all three paths (default / optimal / greedy) lead to the
   same contracted tensor, and that both explicit paths are well-formed. *)
checkPathInvariants[tn_] := Module[{n, opt, gre, r0, rOpt, rGre, agreeOpt, agreeGre},
    n = Length[tn["Tensors"]];
    opt = OptimalContractionPath[tn, Method -> "flops"];
    gre = GreedyContractionPath[tn];
    r0 = TensorNetworkContract[tn];
    rOpt = TensorNetworkContract[tn, opt];
    rGre = TensorNetworkContract[tn, gre];
    agreeOpt = If[ListQ[r0],
        Dimensions[r0] === Dimensions[rOpt] && Max[Abs[Flatten[r0 - rOpt]]] < 1.*^-8,
        Abs[r0 - rOpt] < 1.*^-8];
    agreeGre = If[ListQ[r0],
        Dimensions[r0] === Dimensions[rGre] && Max[Abs[Flatten[r0 - rGre]]] < 1.*^-8,
        Abs[r0 - rGre] < 1.*^-8];
    PathValidQ[opt, n] && PathValidQ[gre, n] && agreeOpt && agreeGre
];


(* ----- F-PATHS-1: MPS topology sweep ----- *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath", "GreedyContractionPath", "TensorNetworkContract"},
    "paclet-fuzz-paths-1-sweep-mps",
    "MPS[L,D,2] for L in {3,5,8,12}, D in {2,3}, seeds 1..4 — opt and greedy paths must give the same contracted tensor",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed]; checkPathInvariants[RandomTensorNetwork["MPS"[L, D, 2]]]],
                {L, {3, 5, 8, 12}}, {D, {2, 3}}, {seed, 1, 4}
            ], 2],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-paths-1-sweep-mps"
    ]
];


(* ----- F-PATHS-2: structured 2D / TT topology sweep ----- *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath", "GreedyContractionPath", "TensorNetworkContract"},
    "paclet-fuzz-paths-2-sweep-peps-tt",
    "PEPS[{r,c}, D, 2] and TT[L, D] — opt/greedy result equality",
    VerificationTest[
        And[
            AllTrue[
                Flatten[Table[
                    BlockRandom[SeedRandom[seed]; checkPathInvariants[RandomTensorNetwork["PEPS"[shape, D, 2]]]],
                    {shape, {{2, 2}, {2, 3}, {3, 3}}}, {D, {2}}, {seed, 1, 2}
                ], 2],
                TrueQ
            ],
            AllTrue[
                Flatten[Table[
                    BlockRandom[SeedRandom[seed]; checkPathInvariants[RandomTensorNetwork["TT"[L, D]]]],
                    {L, {3, 5, 8}}, {D, {2, 3}}, {seed, 1, 2}
                ], 2],
                TrueQ
            ]
        ],
        True,
        TestID -> "paclet-fuzz-paths-2-sweep-peps-tt"
    ]
];


(* ----- F-PATHS-3: 2-tensor edge case -----
   Single contraction step; path must be exactly {{1, 2}}. *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath"},
    "paclet-fuzz-paths-3-edge-2tensor",
    "edge: 2-tensor MPS -> path = {{1,2}}",
    VerificationTest[
        Module[{tn, opt},
            BlockRandom[SeedRandom[1]; tn = RandomTensorNetwork["MPS"[2, 2, 2]]];
            opt = OptimalContractionPath[tn, Method -> "flops"];
            opt === {{1, 2}}
        ],
        True,
        TestID -> "paclet-fuzz-paths-3-edge-2tensor"
    ]
];


(* ----- F-PATHS-4: MPO topology (4-leg interior, 3-leg boundary) ----- *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath", "GreedyContractionPath", "TensorNetworkContract"},
    "paclet-fuzz-paths-4-mpo",
    "MPO[L=5, D=3, d=2] — non-uniform rank profile",
    VerificationTest[
        Module[{tn},
            BlockRandom[SeedRandom[17]; tn = RandomTensorNetwork["MPO"[5, 3, 2]]];
            checkPathInvariants[tn]
        ],
        True,
        TestID -> "paclet-fuzz-paths-4-mpo"
    ]
];


(* ----- F-PATHS-5: determinism -----
   Same input under same seed must give same path on repeated invocation. *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath"},
    "paclet-fuzz-paths-5-determinism",
    "OptimalContractionPath determinism on repeated call",
    VerificationTest[
        Module[{tn, p1, p2},
            BlockRandom[SeedRandom[31]; tn = RandomTensorNetwork["MPS"[6, 3, 2]]];
            p1 = OptimalContractionPath[tn, Method -> "flops"];
            p2 = OptimalContractionPath[tn, Method -> "flops"];
            p1 === p2
        ],
        True,
        TestID -> "paclet-fuzz-paths-5-determinism"
    ]
];


(* ----- F-PATHS-6: timing sentinel -----
   Optimal path on a 20-site MPS must complete within 30 seconds and the
   contraction-result invariant must hold. *)
WithCapability[{"RandomTensorNetwork", "OptimalContractionPath", "GreedyContractionPath", "TensorNetworkContract"},
    "paclet-fuzz-paths-6-timing",
    "20-site MPS opt path + contraction within 30s",
    VerificationTest[
        WithBudget[30.,
            Module[{tn},
                BlockRandom[SeedRandom[91]; tn = RandomTensorNetwork["MPS"[20, 3, 2]]];
                checkPathInvariants[tn]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-paths-6-timing"
    ]
];
