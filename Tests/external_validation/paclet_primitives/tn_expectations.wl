(* Tests/external_validation/paclet_primitives/tn_expectations.wl

Expectation values computed as tensor-network sandwiches <psi| O |psi> with
TensorNetwork + TensorNetworkContract, checked against the dense state vector.

F5 and F6 use an entangled complex random MPS with unequal physical and bond
dimensions. The dense vector psi is the explicit sum over the bond indices (written in
this file); the references are Conjugate[phi] . psi, and Conjugate[psi] . K . psi with
K the Kronecker product of the operator with identities. Operators are complex random
(not Hermitian), so a transposed operator leg or a missing conjugation changes the value.
F7 compares with quimb's values from a fixture.

Sources:
- ITensorMPS expect (test_mps.jl:880-935 pattern)
- quimb MatrixProductState (fixture quimb_random_mps_seed42.json)
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

(* agreement to 1e-10 relative to the size of the reference *)
tneClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];

(* open-boundary MPS on 5 sites: physical dimensions 2, 3, 2, 2, 3; bonds 3, 2, 4, 2 *)
tnePhys = {2, 3, 2, 2, 3};
tneBonds = {3, 2, 4, 2};
tneLength = Length[tnePhys];
tneKetLegs = Table[
    Which[
        k === 1, {"b1", "p1"},
        k === tneLength, {"b" <> ToString[k - 1], "p" <> ToString[k]},
        True, {"b" <> ToString[k - 1], "b" <> ToString[k], "p" <> ToString[k]}],
    {k, tneLength}];
(* bra bonds are separate labels; physical legs are shared unless an operator sits there *)
tneBraLegs[opSites_List] := Map[
    Function[l, Which[
        StringStartsQ[l, "b"], "c" <> StringDrop[l, 1],
        MemberQ[opSites, ToExpression[StringDrop[l, 1]]], "q" <> StringDrop[l, 1],
        True, l]],
    tneKetLegs, {2}];
tneRandomMPS[seed_] := BlockRandom[SeedRandom[seed];
    Table[RandomComplex[{-1 - I, 1 + I},
        Which[
            k === 1, {tneBonds[[1]], tnePhys[[1]]},
            k === tneLength, {tneBonds[[k - 1]], tnePhys[[k]]},
            True, {tneBonds[[k - 1]], tneBonds[[k]], tnePhys[[k]]}]],
        {k, tneLength}]];

(* dense state psi[s1, ..., s5] as an explicit sum over the four bond indices, flattened *)
tneDense[tensors_] := Flatten @ Table[
    Sum[
        tensors[[1]][[b1, s1]] tensors[[2]][[b1, b2, s2]] tensors[[3]][[b2, b3, s3]] tensors[[4]][[b3, b4, s4]] tensors[[5]][[b4, s5]],
        {b1, tneBonds[[1]]}, {b2, tneBonds[[2]]}, {b3, tneBonds[[3]]}, {b4, tneBonds[[4]]}],
    {s1, tnePhys[[1]]}, {s2, tnePhys[[2]]}, {s3, tnePhys[[3]]}, {s4, tnePhys[[4]]}, {s5, tnePhys[[5]]}];

(* Kronecker product of identities with op acting on consecutive sites starting at first *)
tneEmbed[op_, first_, count_] := KroneckerProduct @@ Join[
    IdentityMatrix /@ tnePhys[[;; first - 1]],
    {op},
    IdentityMatrix /@ tnePhys[[first + count ;;]]];

(* ----- F5: <phi|psi> and <psi|psi> for two different complex random MPS: the sandwich
   network with conjugated bra tensors equals Conjugate[phi] . psi of the dense vectors. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-F5-mps-overlap-dense",
    "quimb docs/tensor/tensor-1d.ipynb (MPS overlap); dense state vector",
    VerificationTest[
        Module[{psi, phi, sandwich},
            psi = tneRandomMPS[701];
            phi = tneRandomMPS[702];
            sandwich[bra_, ket_] := TensorNetworkContract[
                TensorNetwork[Join[ket, Conjugate[bra]], Join[tneKetLegs, tneBraLegs[{}]] -> {}]];
            tneClose[sandwich[phi, psi], Conjugate[tneDense[phi]] . tneDense[psi]] &&
                tneClose[sandwich[psi, psi], Conjugate[tneDense[psi]] . tneDense[psi]]
        ],
        True,
        TestID -> "paclet-tn-F5-mps-overlap-dense"
    ]
];

(* ----- F6: <psi|O_k|psi> for a complex random operator on each site k, and for a
   complex random two-site operator on sites 2 and 3 (stored with its slots reordered),
   equal Conjugate[psi] . K . psi with K the operator embedded by Kronecker products. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-F6-mps-local-and-two-site-expectations",
    "ITensorMPS expect (test_mps.jl:880-935 pattern); dense state vector",
    VerificationTest[
        Module[{psi, v, ops, two, local, pair},
            psi = tneRandomMPS[703];
            v = tneDense[psi];
            ops = BlockRandom[SeedRandom[704]; RandomComplex[{-1 - I, 1 + I}, {#, #}] & /@ tnePhys];
            two = BlockRandom[SeedRandom[705]; RandomComplex[{-1 - I, 1 + I}, {6, 6}]];
            local = Table[
                TensorNetworkContract[TensorNetwork[
                    Join[psi, Conjugate[psi], {ops[[k]]}],
                    Join[tneKetLegs, tneBraLegs[{k}], {{"q" <> ToString[k], "p" <> ToString[k]}}] -> {}]],
                {k, tneLength}];
            pair = TensorNetworkContract[TensorNetwork[
                (* rows (s2', s3'), columns (s2, s3); slots stored as (s3', s2', s3, s2) *)
                Join[psi, Conjugate[psi], {Transpose[ArrayReshape[two, {3, 2, 3, 2}], {2, 1, 4, 3}]}],
                Join[tneKetLegs, tneBraLegs[{3, 2}], {{"q3", "q2", "p3", "p2"}}] -> {}]];
            And[
                AllTrue[Range[tneLength], tneClose[local[[#]], Conjugate[v] . tneEmbed[ops[[#]], #, 1] . v] &],
                tneClose[pair, Conjugate[v] . tneEmbed[two, 2, 2] . v]
            ]
        ],
        True,
        TestID -> "paclet-tn-F6-mps-local-and-two-site-expectations"
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
