(* Tests/external_validation/paclet_primitives/mps_canonical_states.wl

Tier-2 direct-validation tests for MPS-specific paclet primitives on canonical
states. Each test cites a specific value from the catalog and asserts the
paclet's MPS primitives reproduce it.

Sources:
- TeNPy doc/toycodes/a_mps.py (Schmidt values normalization)
- TeNPy exercises_uniform_toycodes Part 1.2 (AKLT correlation = (1/3)^(n-1))
- ITensorMPS test_mps.jl:200-214 (random_mps default chi=1, max_linkdim==1)
*)

Module[{worktreeRoot},
    worktreeRoot = SelectFirst[
        NestList[ParentDirectory, Directory[], 12],
        FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed];
    If[worktreeRoot === $Failed,
        Print["[paclet-mps-canonical] cannot find worktree root from ", Directory[]];
        Abort[];
    ];
    Get[FileNameJoin[{worktreeRoot, "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]];
];
ClearValidationRecords[];

(* ----- T1: bond-1 MPS is a product state -> Schmidt values = {1.0}
   Source: TeNPy a_mps.py (init_FM_MPS produces bond-1 product, S=[1.])
           ITensorMPS test_mps.jl:200-214 (random_mps default chi=1)
   Direct value: max bond dim 1 means at every internal bond, there is exactly
   one Schmidt value, equal to 1 (after normalization). *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSSchmidtValues"},
    "paclet-mps-canonical-T1-bond1-schmidt-1",
    "TeNPy a_mps.py / ITensorMPS test_mps.jl:200-214",
    VerificationTest[
        Module[{mps, canon, sv},
            SeedRandom[501];
            mps = RandomTensorNetwork["MPS"[5, 1, 2]];
            canon = MPSCanonicalForm[mps, "Left"];
            sv = MPSSchmidtValues[canon, 2];
            Length[sv] === 1 && ValidationClose[First[sv], 1.0, 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-canonical-T1-bond1-schmidt-1"
    ]
];

(* ----- T2: bond-1 MPS has zero entanglement entropy at every internal bond.
   Source: catalog item ITensorMPS test_mps.jl:200-214 (chi=1 product state). *)
WithCapability[{"RandomTensorNetwork", "MPSEntanglementEntropy"},
    "paclet-mps-canonical-T2-bond1-entropy-zero",
    "ITensorMPS test/base/test_mps.jl:200-214 (random_mps chi=1)",
    VerificationTest[
        Module[{mps, entropies},
            SeedRandom[503];
            mps = RandomTensorNetwork["MPS"[6, 1, 2]];
            entropies = Table[MPSEntanglementEntropy[mps, bond], {bond, 1, 5}];
            AllTrue[entropies, ValidationClose[#, 0.0, 1.*^-10] &]
        ],
        True,
        TestID -> "paclet-mps-canonical-T2-bond1-entropy-zero"
    ]
];

(* ----- T3: bond-D MPS entropy bounded by log(D) at every bond.
   Source: TeNPy a_mps.py + standard MPS theory. For a normalized MPS with
   bond dim D, S_vN <= log(D) at every internal bond.
   Direct test: for D=4 random MPS, all bond entropies <= log(4) = 1.3863... *)
WithCapability[{"RandomTensorNetwork", "MPSEntanglementEntropy"},
    "paclet-mps-canonical-T3-bondD-entropy-bound",
    "TeNPy a_mps.py (Schmidt entropy bounded by log(D))",
    VerificationTest[
        Module[{D, mps, entropies, bound},
            D = 4;
            SeedRandom[509];
            mps = RandomTensorNetwork["MPS"[8, D, 2]];
            entropies = Table[MPSEntanglementEntropy[mps, bond], {bond, 1, 7}];
            bound = Log[N @ D];
            AllTrue[entropies, # >= -1.*^-10 && # <= bound + 1.*^-6 &]
        ],
        True,
        TestID -> "paclet-mps-canonical-T3-bondD-entropy-bound"
    ]
];

(* ----- T4: MPSCanonicalForm to mixed center reproduces overlap.
   Source: ITensorMPS test_mps.jl:680-754 (orthogonalize preserves inner).
   Direct: |<canon, mps>| = ||mps||^2 (within phase up to gauge). *)
WithCapability[{"RandomTensorNetwork", "MPSCanonicalForm", "MPSOverlap", "MPSNorm"},
    "paclet-mps-canonical-T4-mixed-canon-preserves-overlap",
    "ITensorMPS test/base/test_mps.jl:680-754",
    VerificationTest[
        Module[{mps, canon, ovrl, normSq},
            SeedRandom[521];
            mps = RandomTensorNetwork["MPS"[6, 4, 2]];
            canon = MPSCanonicalForm[mps, {"Mixed", 3}];
            ovrl = MPSOverlap[mps, canon];
            normSq = MPSNorm[mps]^2;
            ValidationCloseRel[Abs[ovrl], normSq, 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-canonical-T4-mixed-canon-preserves-overlap"
    ]
];

(* ----- T5: AKLT transfer-matrix eigenvalues = {1, -1/3, -1/3, -1/3}
   Source: TeNPy exercises_uniform_toycodes Part 1.2.
   This is a structural test: build the AKLT site tensors A^m, form the
   transfer matrix T = sum_m A^m (x) conj(A^m), check its eigenvalues.
   Equivalent to baselines/analytic_grounds.wl D5 but uses the paclet's
   IndexedMultiply / EinsteinSummation (not just KroneckerProduct). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-mps-canonical-T5-aklt-transfer-eigvals",
    "TeNPy exercises_uniform_toycodes Part 1.2 (AKLT)",
    VerificationTest[
        Module[{aP1, a0, aM1, contract, tm, vals, sortedAbs},
            (* AKLT spin-1 site tensors in physical basis {+1, 0, -1} = {3-state} *)
            aP1 = N @ Sqrt[2/3] * {{0, 1}, {0, 0}};
            a0  = N @ -Sqrt[1/3] * {{1, 0}, {0, -1}};
            aM1 = N @ -Sqrt[2/3] * {{0, 0}, {1, 0}};
            contract = ActivateTensors @* EinsteinSummation;
            (* Transfer matrix entry T[(l,l'),(r,r')] = sum_m A^m[l,r] conj(A^m)[l',r']
               via paclet's EinsteinSummation. *)
            tm = Sum[
                contract[
                    {{"l", "r"}, {"lp", "rp"}} -> {"l", "lp", "r", "rp"},
                    {a, Conjugate[a]}
                ],
                {a, {aP1, a0, aM1}}
            ];
            (* Reshape (4-tensor of shape 2,2,2,2) to 4x4 transfer matrix *)
            tm = ArrayReshape[tm, {4, 4}];
            vals = Eigenvalues[tm];
            sortedAbs = Reverse @ Sort @ Abs[vals];
            ValidationClose[sortedAbs[[1]], 1.0, 1.*^-10] &&
                ValidationClose[sortedAbs[[2]], 1./3., 1.*^-10] &&
                ValidationClose[sortedAbs[[3]], 1./3., 1.*^-10] &&
                ValidationClose[sortedAbs[[4]], 1./3., 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-canonical-T5-aklt-transfer-eigvals"
    ]
];

(* ----- T6: AKLT correlation length = 1/log(3).
   Source: TeNPy exercises_uniform_toycodes Part 1.2 (xi = -1/log|lambda_2|).
   Direct value derived from T5: lambda_2 = 1/3 -> xi = 1/log(3). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-mps-canonical-T6-aklt-correlation-length",
    "TeNPy AKLT exercises Part 1.2 (xi = 1/log(3))",
    VerificationTest[
        Module[{aP1, a0, aM1, contract, tm, vals, sortedAbs, xi},
            aP1 = N @ Sqrt[2/3] * {{0, 1}, {0, 0}};
            a0  = N @ -Sqrt[1/3] * {{1, 0}, {0, -1}};
            aM1 = N @ -Sqrt[2/3] * {{0, 0}, {1, 0}};
            contract = ActivateTensors @* EinsteinSummation;
            tm = Sum[
                contract[
                    {{"l", "r"}, {"lp", "rp"}} -> {"l", "lp", "r", "rp"},
                    {a, Conjugate[a]}
                ], {a, {aP1, a0, aM1}}];
            tm = ArrayReshape[tm, {4, 4}];
            vals = Eigenvalues[tm];
            sortedAbs = Reverse @ Sort @ Abs[vals];
            xi = -1 / Log[sortedAbs[[2]]];
            ValidationClose[xi, 1./Log[3.], 1.*^-8]
        ],
        True,
        TestID -> "paclet-mps-canonical-T6-aklt-correlation-length"
    ]
];

(* ----- T7: skip - GHZ MPS half-bond entropy = log(2)
   Catalog reference exists (TeNPy entanglement_entropy on Bell/GHZ states)
   but constructing a GHZ MPS in paclet's TensorNetwork format such that
   MPSEntanglementEntropy recognizes it requires reverse-engineering the
   paclet's MPS site-tag scheme. Deferred until we either
   (a) confirm how RandomTensorNetwork["MPS"[...]] structures site/link tags, or
   (b) the paclet exposes a "MPS_computational_state"-like constructor. *)
RecordSkipMissing["paclet-mps-canonical-T7-ghz-mps-entropy",
    {"MPSFromTensorList", "MPS_computational_state"},
    "TeNPy entanglement_entropy on GHZ MPS"];

(* ----- T8: skip - DMRG-prepared MPS specific energies (TFIM L=10 -> -12.38..., etc.)
   Requires DMRG. *)
RecordSkipMissing["paclet-mps-canonical-T8-dmrg-energies",
    {"DMRG"},
    "TeNPy/ITensorMPS DMRG ground-state energies"];
