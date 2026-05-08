(* Tests/external_parity/paclet_primitives/tn_expectations.wl

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
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ParityHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_parity", "Helpers", "ParityHelpers.wl"}],
        FileNameJoin[{Directory[], "external_parity", "Helpers", "ParityHelpers.wl"}],
        FileNameJoin[{Directory[], "..", "Helpers", "ParityHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ParityHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[tn_expectations] ERROR: cannot locate ParityHelpers.wl. Tried: ", candidates];
        Abort[];
    ];
    Get[found];
];
ClearParityRecords[];

(* Single-site states *)
upState = N @ {1, 0};
dnState = N @ {0, 1};
sigmaZ = N @ {{1, 0}, {0, -1}};

(* ----- F5: TensorNetwork product-state norm = 1
   Build |Up,Dn,Up,Dn> as paclet TensorNetwork; close ket-bra via shared phys
   indices. Result = <psi|psi> = 1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "tier1f-F5-product-state-norm",
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
            ParityClose[result, 1.0, 1.*^-12]
        ],
        True,
        TestID -> "tier1f-F5-product-state-norm"
    ]
];

(* ----- F6: TensorNetwork Sz expectation on product state
   <psi|Z_2|psi> for |Up,Dn,Up,Dn> at site 2 = -1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "tier1f-F6-tn-sz-expectation",
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
            ParityClose[result, -1.0, 1.*^-12]
        ],
        True,
        TestID -> "tier1f-F6-tn-sz-expectation"
    ]
];

(* ----- F7: skip - cross-language random MPS *)
SkipDueToRNG["tier1f-F7-random-mps-cross-lang",
    "Random MPS reference values (e.g. quimb 'PEPS norm = 0.5078' at seed=666) require seed parity that NumPy/Julia/WL don't share",
    "quimb docs/tensor/tensor-2d.ipynb (random PEPS norm)"];

(* ----- F8: skip - DMRG-based ground state expectation *)
RecordSkipMissing["tier1f-F8-dmrg-ground-expectation",
    {"DMRG"},
    "ITensorMPS expect on DMRG ground state (test_dmrg.jl:276-316)"];
