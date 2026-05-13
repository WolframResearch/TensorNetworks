(* Tests/external_validation/paclet_fuzz/fuzz_mps.wl

   Property-based fuzz layer for MPSOverlap, MPSCanonicalForm, MPSNorm,
   MPSNormalize. Each sweep iteration generates a random MPS at a point in
   the (L, D, phys) grid and asserts:

     - MPSOverlap[mps, mps] === MPSNorm[mps]^2  (real, non-negative)
     - MPSCanonicalQ[Left[mps], "Left"]  and  MPSCanonicalQ[Right[mps], "Right"]
     - canonicalization preserves overlap within tolerance
     - normalization gives unit norm

   Edge cases: L=2 (both boundaries adjacent), D=1 (product state).
   Timing sentinel at L=32, D=8.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-mps] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];


(* Core MPS invariant check. Returns True iff:
   1. MPSOverlap[mps, mps] is real and non-negative
   2. MPSOverlap === MPSNorm^2 (within numerical tolerance)
   3. Left/right canonicalization preserves overlap
   4. Normalization gives unit overlap
   5. MPSCanonicalQ confirms the canonicalized form *)
checkMPSInvariants[mps_, tol_:1.*^-8] := Module[
    {ov, norm, leftCanon, rightCanon, normalized, ovL, ovR, ovN, scale},
    ov = MPSOverlap[mps, mps];
    norm = MPSNorm[mps];
    leftCanon = MPSCanonicalForm[mps, "Left"];
    rightCanon = MPSCanonicalForm[mps, "Right"];
    normalized = MPSNormalize[mps];
    ovL = MPSOverlap[leftCanon, leftCanon];
    ovR = MPSOverlap[rightCanon, rightCanon];
    ovN = MPSOverlap[normalized, normalized];
    scale = Max[1, Abs[ov]];
    And[
        Abs[Im[ov]] < tol * scale,
        Re[ov] >= -tol * scale,
        Abs[ov - norm^2]    < tol * scale,
        Abs[ov - ovL]       < tol * scale,
        Abs[ov - ovR]       < tol * scale,
        Abs[ovN - 1]        < tol,
        MPSCanonicalQ[leftCanon, "Left"],
        MPSCanonicalQ[rightCanon, "Right"]
    ]
];


(* ----- F-MPS-1: small/medium sweep -----
   L in {3, 5, 8}, D in {2, 4}, phys in {2, 3}, seed 1..2 = 24 networks. *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSCanonicalQ"},
    "paclet-fuzz-mps-1-small-sweep",
    "MPS[L,D,d] sweep: overlap=norm^2, canon preserves overlap, normalize gives 1",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed]; checkMPSInvariants[RandomTensorNetwork["MPS"[L, D, d]]]],
                {L, {3, 5, 8}}, {D, {2, 4}}, {d, {2, 3}}, {seed, 1, 2}
            ], 3],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-mps-1-small-sweep"
    ]
];


(* ----- F-MPS-2: larger-bond sweep -----
   L in {6, 12, 16}, D in {6, 8}, phys=2, seed 1..2 = 12 networks. *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSCanonicalQ"},
    "paclet-fuzz-mps-2-larger-bond-sweep",
    "MPS[L,D=6..8,2] sweep — larger bond dimensions stress canonicalization",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed]; checkMPSInvariants[RandomTensorNetwork["MPS"[L, D, 2]]]],
                {L, {6, 12, 16}}, {D, {6, 8}}, {seed, 1, 2}
            ], 2],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-mps-2-larger-bond-sweep"
    ]
];


(* ----- F-MPS-3: L=2 edge case -----
   Both boundary tensors are adjacent — special-case path through the
   canonicalization code. *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSCanonicalQ"},
    "paclet-fuzz-mps-3-edge-L2",
    "L=2 MPS (both boundaries adjacent)",
    VerificationTest[
        AllTrue[
            Table[
                BlockRandom[SeedRandom[seed]; checkMPSInvariants[RandomTensorNetwork["MPS"[2, D, 2]]]],
                {D, {2, 3, 4}}, {seed, 1, 3}
            ] // Flatten,
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-mps-3-edge-L2"
    ]
];


(* ----- F-MPS-4: D=1 product state edge case -----
   Bond dim 1 collapses every bond to a scalar — a product state. *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSCanonicalQ"},
    "paclet-fuzz-mps-4-edge-D1-product",
    "D=1 product-state edge case",
    VerificationTest[
        AllTrue[
            Table[
                BlockRandom[SeedRandom[seed]; checkMPSInvariants[RandomTensorNetwork["MPS"[L, 1, 2]]]],
                {L, {3, 5, 8}}, {seed, 1, 3}
            ] // Flatten,
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-mps-4-edge-D1-product"
    ]
];


(* ----- F-MPS-5: mixed-canonical at every site -----
   For an L=8 MPS, MPSCanonicalForm[mps, {"Mixed", k}] should yield a state
   that contains site k in its non-canonical (orthogonality-center) form, and
   the overall norm/overlap should be preserved. *)
WithCapability[{"RandomTensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSCanonicalQ"},
    "paclet-fuzz-mps-5-mixed-canonical",
    "Mixed-canonical at every site k preserves overlap and is canonical there",
    VerificationTest[
        Module[{mps, ov0, results},
            BlockRandom[SeedRandom[91]; mps = RandomTensorNetwork["MPS"[8, 3, 2]]];
            ov0 = MPSOverlap[mps, mps];
            results = Table[
                Module[{canon, ovK},
                    canon = MPSCanonicalForm[mps, {"Mixed", k}];
                    ovK = MPSOverlap[canon, canon];
                    Abs[ovK - ov0] < 1.*^-7 * Max[1, Abs[ov0]] &&
                        MPSCanonicalQ[canon, {"Mixed", k}]
                ],
                {k, 1, 8}
            ];
            AllTrue[results, TrueQ]
        ],
        True,
        TestID -> "paclet-fuzz-mps-5-mixed-canonical"
    ]
];


(* ----- F-MPS-6: timing sentinel -----
   Canonicalization on a moderately large MPS within 15s. *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSCanonicalQ"},
    "paclet-fuzz-mps-6-timing",
    "L=32, D=8 left-canonicalize within 15s",
    VerificationTest[
        WithBudget[15.,
            Module[{mps, canon},
                BlockRandom[SeedRandom[101]; mps = RandomTensorNetwork["MPS"[32, 8, 2]]];
                canon = MPSCanonicalForm[mps, "Left"];
                MPSCanonicalQ[canon, "Left"]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-mps-6-timing"
    ]
];
