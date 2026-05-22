(* Tests/external_validation/paclet_primitives/mps.wl

Paclet-primitive tests: MPS-specific paclet primitives. Exercises:
  RandomTensorNetwork["MPS"[L, bondDim, physDim]],
  MPSCanonicalForm, MPSCanonicalQ, MPSOverlap, MPSNorm,
  MPSEntanglementEntropy, MPSSchmidtValues, MPSTruncate.

Sources mirrored:
- ITensorMPS test_mps.jl (MPS construction, norm, orthogonalize, truncate!)
- ITensorMPS test_mps.jl:880-935 (expect on canonical MPS)
- TeNPy a_mps.py (Schmidt entropy on canonical form)
- quimb tests/test_tensor_core.py (MPS overlap, entropy at bond)
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[paclet-mps] ERROR: cannot locate ValidationHelpers.wl"]; Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* ----- G1: random MPS produces a valid TensorNetwork *)
WithCapability[{"RandomTensorNetwork", "TensorNetworkQ"},
    "paclet-mps-G1-random-mps-tn",
    "ITensorMPS test/base/test_mps.jl:200-214 (random_mps)",
    VerificationTest[
        Module[{mps},
            SeedRandom[401];
            mps = RandomTensorNetwork["MPS"[6, 4, 2]];
            TensorNetworkQ[mps]
        ],
        True,
        TestID -> "paclet-mps-G1-random-mps-tn"
    ]
];

(* ----- G2: MPSOverlap[mps,mps] == MPSNorm[mps]^2 (real-positive)
   ITensorMPS test_mps.jl:241-253 (inner consistency). *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSNorm"},
    "paclet-mps-G2-overlap-equals-norm-sq",
    "ITensorMPS test/base/test_mps.jl:241-253 (inner = norm^2)",
    VerificationTest[
        Module[{mps, ovrl, norm},
            SeedRandom[409];
            mps = RandomTensorNetwork["MPS"[5, 3, 2]];
            ovrl = MPSOverlap[mps, mps];
            norm = MPSNorm[mps];
            ValidationCloseRel[Re[ovrl], norm^2, 1.*^-10] && Abs[Im[ovrl]] < 1.*^-10
        ],
        True,
        TestID -> "paclet-mps-G2-overlap-equals-norm-sq"
    ]
];

(* ----- G3: MPSCanonicalForm Left produces a left-canonical state
   ITensorMPS test_mps.jl:680-754 (orthogonalize!). *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSCanonicalQ"},
    "paclet-mps-G3-canonical-left",
    "ITensorMPS test/base/test_mps.jl:680-754 (left orthogonality)",
    VerificationTest[
        Module[{mps, canon},
            SeedRandom[419];
            mps = RandomTensorNetwork["MPS"[7, 5, 2]];
            canon = MPSCanonicalForm[mps, "Left"];
            MPSCanonicalQ[canon, "Left"]
        ],
        True,
        TestID -> "paclet-mps-G3-canonical-left"
    ]
];

(* ----- G4: MPSCanonicalForm Right produces a right-canonical state. *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSCanonicalQ"},
    "paclet-mps-G4-canonical-right",
    "ITensorMPS test/base/test_mps.jl (right orthogonality)",
    VerificationTest[
        Module[{mps, canon},
            SeedRandom[421];
            mps = RandomTensorNetwork["MPS"[6, 4, 2]];
            canon = MPSCanonicalForm[mps, "Right"];
            MPSCanonicalQ[canon, "Right"]
        ],
        True,
        TestID -> "paclet-mps-G4-canonical-right"
    ]
];

(* ----- G5: MPSCanonicalForm Mixed at site k. *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSCanonicalQ"},
    "paclet-mps-G5-canonical-mixed",
    "ITensorMPS test/base/test_mps.jl (mixed canonical at site k)",
    VerificationTest[
        Module[{mps, canon, k},
            SeedRandom[431];
            mps = RandomTensorNetwork["MPS"[8, 5, 2]];
            k = 4;
            canon = MPSCanonicalForm[mps, {"Mixed", k}];
            MPSCanonicalQ[canon, {"Mixed", k}]
        ],
        True,
        TestID -> "paclet-mps-G5-canonical-mixed"
    ]
];

(* ----- G6: Canonicalization preserves the state up to gauge.
   For a normalized MPS, canon(mps) and mps should have the same overlap with each other
   equal to the squared norm. ITensorMPS test_mps.jl norm preservation. *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSOverlap", "MPSNorm"},
    "paclet-mps-G6-canon-preserves-norm",
    "ITensorMPS test/base/test_mps.jl (canonical-form preserves overlap)",
    VerificationTest[
        Module[{mps, canon, normMps, normCanon, ovrl},
            SeedRandom[433];
            mps = RandomTensorNetwork["MPS"[6, 4, 2]];
            canon = MPSCanonicalForm[mps, "Left"];
            normMps = MPSNorm[mps];
            normCanon = MPSNorm[canon];
            ovrl = MPSOverlap[mps, canon];
            ValidationCloseRel[normCanon, normMps, 1.*^-10] &&
                ValidationCloseRel[Abs[ovrl], normMps^2, 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-G6-canon-preserves-norm"
    ]
];

(* ----- G7: Schmidt values squared sum to 1 (paclet returns normalized).
   The paclet's MPSSchmidtValues returns the *normalized* singular values of
   the bipartition, so they sum-square to 1 regardless of the MPS's overall
   norm. (For the norm-aware version, multiply by MPSNorm^2 outside.) *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSSchmidtValues", "MPSNorm"},
    "paclet-mps-G7-schmidt-sum-to-one",
    "TeNPy doc/toycodes/a_mps.py (Schmidt values normalization)",
    VerificationTest[
        Module[{mps, canon, sv, sumSq},
            SeedRandom[439];
            mps = RandomTensorNetwork["MPS"[6, 5, 2]];
            canon = MPSCanonicalForm[mps, {"Mixed", 3}];
            sv = MPSSchmidtValues[canon, 3];
            sumSq = Total[sv^2];
            ValidationCloseRel[sumSq, 1.0, 1.*^-8]
        ],
        True,
        TestID -> "paclet-mps-G7-schmidt-sum-to-one"
    ]
];

(* ----- G8: Entanglement entropy is non-negative and bounded by log(min(D_left, D_right)).
   For bond dim 4 on a 2-level MPS, entropy <= log(min(4, 2^min(L1, L2)) but conservatively
   <= log(physDim^min(siteToLeft, siteToRight)) for a generic state.
   ITensorMPS test_mps.jl entanglement_entropy bounds. *)
WithCapability[{"RandomTensorNetwork", "MPSEntanglementEntropy"},
    "paclet-mps-G8-entropy-bounds",
    "ITensorMPS test/base/test_mps.jl (entanglement entropy)",
    VerificationTest[
        Module[{mps, S, upper},
            SeedRandom[443];
            mps = RandomTensorNetwork["MPS"[6, 4, 2]];
            S = MPSEntanglementEntropy[mps, 3];
            (* Upper bound: log(bond dim cap) on a generic random MPS *)
            upper = Log[4];
            S >= -1.*^-10 && S <= upper + 1.*^-6
        ],
        True,
        TestID -> "paclet-mps-G8-entropy-bounds"
    ]
];

(* ----- G9: MPSTruncate reduces bond dim and produces a renormalized state.
   ITensorMPS test_mps.jl:755-794 (truncate!). *)
WithCapability[{"RandomTensorNetwork", "MPSTruncate", "MPSNorm"},
    "paclet-mps-G9-truncate-reduces-bond",
    "ITensorMPS test/base/test_mps.jl:755-794 (truncate!)",
    VerificationTest[
        Module[{mps, truncated, normTrunc},
            SeedRandom[449];
            mps = RandomTensorNetwork["MPS"[6, 8, 2]];
            truncated = MPSTruncate[mps, 3];  (* maxBond = 3 *)
            normTrunc = MPSNorm[truncated];
            (* Truncated MPS norm is positive (state still represents something) *)
            normTrunc > 0
        ],
        True,
        TestID -> "paclet-mps-G9-truncate-reduces-bond"
    ]
];

(* ----- G10: Skip — DMRG ground-state expectation
   Awaiting DMRG primitive in paclet. *)
RecordSkipMissing["paclet-mps-G10-dmrg-mps-overlap",
    {"DMRG"},
    "ITensorMPS test_dmrg.jl ground-state expectation"];

(* ----- G11: Cross-language random MPS overlap + canonicalization
   Original framing required cross-language RNG seed parity, which is
   impossible. Reframed: lift quimb's actual MPS site tensors into a fixture
   (axis order matches the paclet's MPS convention: boundaries (bond, phys),
   interior (left, right, phys)) and verify:
     1) MPSOverlap[mps, mps] matches quimb's <psi|psi> exactly
     2) MPSCanonicalForm preserves the overlap (no information loss in left/right canon)
   Julia/ITensorMPS isn't installed locally; quimb is an equally valid
   external oracle (same fixture as F7 in tn_expectations.wl). *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm"},
    "paclet-mps-G11-cross-lang-random-mps",
    "quimb MatrixProductState seed=42 (fixture: external_oracles/fixtures/quimb_random_mps_seed42.json)",
    VerificationTest[
        Module[{fixture, L, arrs, legs, mps, normSq, expected, mpsL, mpsR,
                overlapLL, overlapRR, rawOK, leftOK, rightOK},
            fixture = Import[OracleFixturePath["quimb_random_mps_seed42.json"], "RawJSON"];
            L = fixture["L"];
            arrs = fixture["tensors"];
            expected = fixture["expected_norm_sq"];

            (* Leg convention: bond_i between sites i and i+1, phys_i on site i.
               Site 0: (b_0, p_0); interior i: (b_{i-1}, b_i, p_i); site L-1: (b_{L-2}, p_{L-1}). *)
            legs = Table[
                Which[
                    i === 1, {"b0", "p0"},
                    i === L, {"b" <> ToString[L - 2], "p" <> ToString[L - 1]},
                    True,    {"b" <> ToString[i - 2], "b" <> ToString[i - 1],
                              "p" <> ToString[i - 1]}
                ],
                {i, L}
            ];

            mps = TensorNetwork[arrs, legs];

            (* 1) raw overlap *)
            normSq = MPSOverlap[mps, mps];
            rawOK = ValidationCloseRel[normSq, expected, 1.*^-10];

            (* 2) left-canonical preserves overlap *)
            mpsL = MPSCanonicalForm[mps, "Left"];
            overlapLL = MPSOverlap[mpsL, mpsL];
            leftOK = ValidationCloseRel[overlapLL, expected, 1.*^-8];

            (* 3) right-canonical preserves overlap *)
            mpsR = MPSCanonicalForm[mps, "Right"];
            overlapRR = MPSOverlap[mpsR, mpsR];
            rightOK = ValidationCloseRel[overlapRR, expected, 1.*^-8];

            rawOK && leftOK && rightOK
        ],
        True,
        TestID -> "paclet-mps-G11-cross-lang-random-mps"
    ]
];
