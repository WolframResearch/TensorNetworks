(* Tests/external_validation/paclet_primitives/tn_expectations.wl

Paclet-primitive tests for TensorNetwork-based expectation values on simple
states. Uses paclet's TensorNetwork[...] + TensorNetworkContract[...] to
compute <psi|O|psi> on product states.

Sources:
- ITensorNetworks #15 (2x2 GHZ <Sz>=0)
- ITensorMPS expect (test_mps.jl:880-935 pattern)
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "..", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[paclet-tn] ERROR: cannot locate ValidationHelpers.wl. Tried: ", candidates];
        Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* Single-site states *)
upState = N @ {1, 0};
dnState = N @ {0, 1};
sigmaZ = N @ {{1, 0}, {0, -1}};

(* ----- F5: TensorNetwork product-state norm = 1
   Build |Up,Dn,Up,Dn> as paclet TensorNetwork; close ket-bra via shared phys
   indices. Result = <psi|psi> = 1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-F5-product-state-norm",
    "quimb docs/tensor/tensor-1d.ipynb (MPS norm)",
    VerificationTest[
        Module[{L, ketTensors, braTensors, allTensors, allInds, tn, result},
            L = 4;
            ketTensors = Table[If[OddQ[i], upState, dnState], {i, L}];
            braTensors = ketTensors;
            allTensors = Join[ketTensors, braTensors];
            allInds = Join[
                Table[{"p_" <> ToString[i]}, {i, L}],
                Table[{"p_" <> ToString[i]}, {i, L}]
            ];
            tn = TensorNetwork[allTensors, allInds];
            result = TensorNetworkContract[tn];
            ValidationClose[result, 1.0, 1.*^-12]
        ],
        True,
        TestID -> "paclet-tn-F5-product-state-norm"
    ]
];

(* ----- F6: TensorNetwork Sz expectation on product state
   <psi|Z_2|psi> for |Up,Dn,Up,Dn> at site 2 = -1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-F6-tn-sz-expectation",
    "ITensorMPS expect (test_mps.jl:880-935 pattern)",
    VerificationTest[
        Module[{L, ketTensors, braTensors, allTensors, allInds, tn, result},
            L = 4;
            ketTensors = Table[If[OddQ[i], upState, dnState], {i, L}];
            braTensors = ketTensors;
            allTensors = Append[Join[ketTensors, braTensors], sigmaZ];
            allInds = Join[
                (* ket: site i has phys ind p_i *)
                Table[{"p_" <> ToString[i]}, {i, L}],
                (* bra: site 2 uses q_2 (joins op output); other sites use p_i *)
                Table[
                    If[i === 2, {"q_2"}, {"p_" <> ToString[i]}]
                , {i, L}],
                {{"p_2", "q_2"}}  (* operator connects ket-p_2 to bra-q_2 *)
            ];
            tn = TensorNetwork[allTensors, allInds];
            result = TensorNetworkContract[tn];
            ValidationClose[result, -1.0, 1.*^-12]
        ],
        True,
        TestID -> "paclet-tn-F6-tn-sz-expectation"
    ]
];

(* ----- F7: cross-language random MPS norm + <Z_i> expectations
   Instead of trying to reproduce an RNG seed across languages, we lift the
   actual quimb-generated site-tensor arrays into a JSON fixture along with
   the reference scalars (norm-squared and per-site <Z>). The paclet
   reconstructs the same TN bra-ket sandwich (with a Z gate inserted for the
   expectation runs) and must match each reference within tolerance. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-F7-random-mps-cross-lang",
    "quimb MatrixProductState seed=42 (fixture: external_oracles/fixtures/quimb_random_mps_seed42.json)",
    VerificationTest[
        Module[{fixture, L, arrs, ketTensors, ketLegs, braTensors, braLegs,
                tn, normSq, zVals, zExpected, normExpected, tol, normOK, zOK,
                kLeg, mLeg, pLeg, ppLeg, zMat},
            fixture = Import[OracleFixturePath["quimb_random_mps_seed42.json"], "RawJSON"];
            L = fixture["L"];
            arrs = fixture["tensors"];  (* list of nested-list arrays *)
            normExpected = fixture["expected_norm_sq"];
            zExpected = fixture["expected_z_expectations"];
            tol = 1.*^-8;

            kLeg[i_] := "l" <> ToString[i];   (* ket bonds *)
            mLeg[i_] := "m" <> ToString[i];   (* bra bonds *)
            pLeg[i_] := "p" <> ToString[i];   (* physical, shared bra<->ket *)
            ppLeg[i_] := "pp" <> ToString[i]; (* gated physical (bra side, after Z) *)

            (* ----- 1) norm-squared <psi|psi> -----
               Ket site i carries legs (bond_left, bond_right, phys) for interior,
               (bond, phys) for boundaries. Bra mirrors with separate bond labels;
               physical legs are shared so they get summed. *)
            ketLegs = Table[
                Which[
                    i === 1, {kLeg[0], pLeg[0]},
                    i === L, {kLeg[L - 2], pLeg[L - 1]},
                    True,    {kLeg[i - 2], kLeg[i - 1], pLeg[i - 1]}
                ],
                {i, L}
            ];
            braLegs = Table[
                Which[
                    i === 1, {mLeg[0], pLeg[0]},
                    i === L, {mLeg[L - 2], pLeg[L - 1]},
                    True,    {mLeg[i - 2], mLeg[i - 1], pLeg[i - 1]}
                ],
                {i, L}
            ];
            ketTensors = arrs;
            braTensors = arrs;  (* real-valued; no conjugation needed *)
            tn = TensorNetwork[
                Join[ketTensors, braTensors],
                Join[ketLegs, braLegs]
            ];
            normSq = TensorNetworkContract[tn];
            normOK = ValidationCloseRel[normSq, normExpected, 1.*^-10];

            (* ----- 2) <psi | Z_k | psi> for each site k = 0..L-1 -----
               Reuse the same MPS arrays but rename the bra's physical at site k
               to "pp_k", and insert a 2x2 Z tensor between p_k and pp_k. *)
            zMat = {{1.0, 0.0}, {0.0, -1.0}};
            zVals = Table[
                Module[{braLegsGated, zLegs, allTensors, allLegs, tnZ},
                    braLegsGated = ReplacePart[braLegs,
                        Position[braLegs, pLeg[k - 1], {2}] -> ppLeg[k - 1]];
                    zLegs = {ppLeg[k - 1], pLeg[k - 1]};
                    allTensors = Join[ketTensors, braTensors, {zMat}];
                    allLegs = Join[ketLegs, braLegsGated, {zLegs}];
                    tnZ = TensorNetwork[allTensors, allLegs];
                    TensorNetworkContract[tnZ]
                ],
                {k, L}
            ];
            zOK = AllTrue[
                Transpose[{zVals, zExpected}],
                ValidationCloseRel[#[[1]], #[[2]], 1.*^-10] &
            ];

            normOK && zOK
        ],
        True,
        TestID -> "paclet-tn-F7-random-mps-cross-lang"
    ]
];

(* ----- F8: skip - DMRG-based ground state expectation *)
RecordSkipMissing["paclet-tn-F8-dmrg-ground-expectation",
    {"DMRG"},
    "ITensorMPS expect on DMRG ground state (test_dmrg.jl:276-316)"];
