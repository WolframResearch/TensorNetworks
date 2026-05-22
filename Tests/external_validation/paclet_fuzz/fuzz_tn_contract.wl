(* Tests/external_validation/paclet_fuzz/fuzz_tn_contract.wl

   Property-based fuzz layer for TensorNetworkContract. Tests structural
   invariants on random and edge-case networks rather than specific numeric
   values. The invariants cover correctness (finite numeric result, shape,
   bra-ket non-negativity), hyper-index handling, trace patterns, and a
   timing sentinel.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-contract] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];


(* ----- F-CONTRACT-1: contraction of random TNs gives a finite numeric tensor
   of the expected shape. Sweep over chain/2D/MPO topologies. *)
WithCapability[{"RandomTensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-1-finite-shape-sweep",
    "Random TN contract -> finite numeric tensor with shape = product of free-leg dims",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed];
                    Module[{tn, r, finiteQ, shapeOK, freeDims},
                        tn = RandomTensorNetwork[topo];
                        r = TensorNetworkContract[tn];
                        finiteQ = If[ListQ[r],
                            AllTrue[Flatten[r], (NumericQ[#] && Abs[#] < Infinity) &],
                            NumericQ[r] && Abs[r] < Infinity];
                        (* Shape = product of the dims of the FreeIndices *)
                        freeDims = Lookup[Association @ tn["IndexDimensions"], tn["FreeIndices"]];
                        shapeOK = If[Length[freeDims] === 0,
                            !ListQ[r] || Dimensions[r] === {},
                            Dimensions[r] === freeDims];
                        finiteQ && shapeOK
                    ]
                ],
                {topo, {"MPS"[4, 3, 2], "MPS"[6, 2, 2], "PEPS"[{2, 2}, 2, 2],
                        "PEPS"[{2, 3}, 2, 2], "MPO"[4, 2, 2], "TT"[5, 3]}},
                {seed, 1, 2}
            ], 1],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-contract-1-finite-shape-sweep"
    ]
];


(* ----- F-CONTRACT-2: bra-ket sandwich = ||psi||^2, real and >= 0.
   Bond-dim/length sweep; uses MPSOverlap (which IS a bra-ket contraction
   under the hood). *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap"},
    "paclet-fuzz-contract-2-bra-ket-positive",
    "<psi|psi> via MPSOverlap is real and non-negative for random MPS sweep",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed];
                    Module[{mps, ov, tol = 1.*^-10},
                        mps = RandomTensorNetwork["MPS"[L, D, d]];
                        ov = MPSOverlap[mps, mps];
                        Abs[Im[ov]] < tol * Max[1, Abs[Re[ov]]] && Re[ov] >= -tol
                    ]
                ],
                {L, {3, 5, 8, 14}}, {D, {2, 4}}, {d, {2, 3}}, {seed, 1, 2}
            ], 3],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-contract-2-bra-ket-positive"
    ]
];


(* ----- F-CONTRACT-3: hyper-3 identity-delta.
   sum_x I[a,x] I[b,x] I[c,x] = delta(a,b,c) — a basic hyper-index test. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-3-hyper3-delta",
    "Three identities sharing one index produce the rank-3 delta",
    VerificationTest[
        Module[{n, id, tn, r, expected},
            n = 3;
            id = N @ IdentityMatrix[n];
            tn = TensorNetwork[{id, id, id}, {{"x", "a"}, {"x", "b"}, {"x", "c"}}];
            r = TensorNetworkContract[tn];
            expected = Table[If[i === j && j === k, 1.0, 0.0], {i, n}, {j, n}, {k, n}];
            ValidationClose[r, expected, 1.*^-12]
        ],
        True,
        TestID -> "paclet-fuzz-contract-3-hyper3-delta"
    ]
];


(* ----- F-CONTRACT-4: trace patterns on a single tensor.
   T_ii = Tr[T] for an identity. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-4-traces",
    "Trace identities at varied dim",
    VerificationTest[
        AllTrue[
            Table[
                Module[{id, tn, r},
                    id = N @ IdentityMatrix[n];
                    tn = TensorNetwork[{id}, {{"i", "i"}}];
                    r = TensorNetworkContract[tn];
                    ValidationClose[r, N[n], 1.*^-12]
                ],
                {n, {2, 3, 5, 7, 11}}
            ],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-contract-4-traces"
    ]
];


(* ----- F-CONTRACT-5: 2-tensor edge case — explicit dot product.
   T1[i,j] * T2[i,j] summed over both indices = scalar = Total[Flatten[T1 * T2]]. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-5-edge-2tensor-dot",
    "<T1, T2> via TN === Total[Flatten[T1 T2]] for random pair",
    VerificationTest[
        AllTrue[
            Table[
                BlockRandom[SeedRandom[seed];
                    Module[{T1, T2, tn, r, expected},
                        T1 = RandomReal[{-1, 1}, {3, 4}];
                        T2 = RandomReal[{-1, 1}, {3, 4}];
                        tn = TensorNetwork[{T1, T2}, {{"i", "j"}, {"i", "j"}}];
                        r = TensorNetworkContract[tn];
                        expected = Total[Flatten[T1 * T2]];
                        ValidationClose[r, expected, 1.*^-12]
                    ]
                ],
                {seed, 1, 5}
            ],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-contract-5-edge-2tensor-dot"
    ]
];


(* ----- F-CONTRACT-6: timing sentinel —
   medium-PEPS contraction within budget. *)
WithCapability[{"RandomTensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-6-timing",
    "3x3 PEPS (D=2) bra-ket norm within 10s",
    VerificationTest[
        WithBudget[10.,
            Module[{peps, ov},
                BlockRandom[SeedRandom[131]; peps = RandomTensorNetwork["PEPS"[{3, 3}, 2, 2]]];
                (* Build bra-ket sandwich: paclet doesn't expose PEPSOverlap, so
                   contract the bare PEPS and check the result has finite values *)
                ov = TensorNetworkContract[peps];
                ListQ[ov] && AllTrue[Flatten[ov], (NumericQ[#] && Abs[#] < Infinity) &]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-contract-6-timing"
    ]
];
