(* Tests/external_validation/paclet_primitives/tn_canonical_states.wl

Entangled states prepared by small circuits written as tensor networks (one tensor per
gate, |0> inputs), contracted with TensorNetworkContract and checked against values
worked out by hand or by dense matrix products:

- T1, T3: the state itself against its closed form. The circuits are chosen so the
  state is not symmetric under exchanging qubits, and T3 asks for the qubits in every
  order, so a swapped control and target, a gate on the wrong wire, or a misordered
  output changes the answer.
- T2, T4: expectation values as bra-operator-ket sandwiches (bra gates conjugated)
  against hand-computed closed forms that differ between qubit pairs.
- T5: a brickwork of complex random two-qubit unitaries against the state vector
  obtained by multiplying the Kronecker-embedded matrices.
- T6: quimb's 3x3 PEPS norm and local Z values from a fixture (unchanged).

Sources:
- quimb test_circuit.py:559-568 (Bell state expectations), 142-146 (GHZ-3)
- quimb PEPS.rand(3,3,seed=42) (fixture quimb_peps_3x3_seed42.json)
*)

Module[{worktreeRoot},
    worktreeRoot = SelectFirst[
        NestList[ParentDirectory, Directory[], 12],
        FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed];
    If[worktreeRoot === $Failed,
        Print["[paclet-tn-canonical] cannot find worktree root from ", Directory[]];
        Abort[];
    ];
    Get[FileNameJoin[{worktreeRoot, "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]];
];
ClearValidationRecords[];

(* agreement to 1e-10 relative to the size of the reference *)
tcsClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];

tcsX = {{0., 1.}, {1., 0.}};
tcsY = {{0., -I}, {I, 0.}};
tcsZ = {{1., 0.}, {0., -1.}};
tcsH = {{1., 1.}, {1., -1.}} / Sqrt[2.];
tcsS = {{1., 0.}, {0., I}};
tcsT = {{1., 0.}, {0., Exp[I Pi / 4.]}};
(* rows (control', target'), columns (control, target) *)
tcsCNOT = {{1., 0., 0., 0.}, {0., 1., 0., 0.}, {0., 0., 0., 1.}, {0., 0., 1., 0.}};

(* A circuit on n qubits as a network: |0> on every wire, then one tensor per gate
   {matrix, qubits}; a k-qubit gate has slots (outputs..., inputs...). Wire q carries
   label tag<>"q<q>t<m>" after its m-th gate. Returns {tensors, legs, final labels}. *)
tcsCircuitNet[n_, gates_, tag_] := Module[{time = ConstantArray[0, n], lab, tensors, legs},
    lab[q_, t_] := tag <> "q" <> ToString[q] <> "t" <> ToString[t];
    {tensors, legs} = Transpose @ Join[
        Table[{{1., 0.}, {lab[q, 0]}}, {q, n}],
        Map[
            Function[g, With[{qs = g[[2]]},
                With[{inLegs = lab[#, time[[#]]] & /@ qs},
                    Scan[(time[[#]] += 1) &, qs];
                    {ArrayReshape[g[[1]], ConstantArray[2, 2 Length[qs]]], Join[lab[#, time[[#]]] & /@ qs, inLegs]}]]],
            gates]];
    {tensors, legs, Table[lab[q, time[[q]]], {q, n}]}
];

(* state tensor with the qubits in the order given *)
tcsState[n_, gates_, order_] := With[{net = tcsCircuitNet[n, gates, ""]},
    TensorNetworkContract[TensorNetwork[net[[1]], net[[2]] -> net[[3]][[order]]]]];

(* <psi| O_1 x O_2 x ... |psi> with ops = {qubit -> matrix, ...}; matrix rows on the bra side *)
tcsExpectation[n_, gates_, ops_] := With[{ket = tcsCircuitNet[n, gates, ""], bra = tcsCircuitNet[n, gates, "x"]},
    With[{rename = Thread[bra[[3]][[Complement[Range[n], Keys[ops]]]] -> ket[[3]][[Complement[Range[n], Keys[ops]]]]]},
        TensorNetworkContract[TensorNetwork[
            Join[ket[[1]], Conjugate[bra[[1]]], Values[ops]],
            Join[ket[[2]], Replace[bra[[2]], rename, {2}], {bra[[3]][[#]], ket[[3]][[#]]} & /@ Keys[ops]] -> {}]]]];

(* dense simulation: each gate on adjacent qubits as a Kronecker product with identities *)
tcsEmbed[n_, {m_, qs_}] := KroneckerProduct @@ Join[
    Table[IdentityMatrix[2], First[qs] - 1], {m}, Table[IdentityMatrix[2], n - Last[qs]]];
tcsDense[n_, gates_] := Fold[tcsEmbed[n, #2] . #1 &, UnitVector[2^n, 1], gates];

(* X on qubit 2, H on 1, CNOT 1 -> 2, S on 1: (|01> + i |10>) / Sqrt[2] *)
tcsBellGates = {{tcsX, {2}}, {tcsH, {1}}, {tcsCNOT, {1, 2}}, {tcsS, {1}}};
(* X on 3, H on 1, CNOT 1 -> 2, CNOT 2 -> 3, T on 3: (E^(I Pi/4) |001> + |110>) / Sqrt[2] *)
tcsGHZGates = {{tcsX, {3}}, {tcsH, {1}}, {tcsCNOT, {1, 2}}, {tcsCNOT, {2, 3}}, {tcsT, {3}}};

(* ----- T1: the Bell-type circuit gives (|01> + i |10>) / Sqrt[2], i.e. the 2 x 2
   amplitude array {{0, 1}, {i, 0}} / Sqrt[2] indexed by (qubit 1, qubit 2). *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T1-bell-circuit-state",
    "quimb test_circuit.py:559-568 (Bell state); closed form",
    VerificationTest[
        tcsClose[tcsState[2, tcsBellGates, {1, 2}], {{0, 1}, {I, 0}} / Sqrt[2.]],
        True,
        TestID -> "paclet-tn-canonical-T1-bell-circuit-state"
    ]
];

(* ----- T2: on (|01> + i |10>) / Sqrt[2], <Y1 X2> = 1 and <X1 Y2> = -1 (Y x X maps the
   state to itself and X x Y to minus itself), <Z1> = 0 and <Z1 Z2> = -1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T2-bell-correlators",
    "quimb test_circuit.py local_expectation Bell pattern; closed form",
    VerificationTest[
        tcsClose[
            {
                tcsExpectation[2, tcsBellGates, {1 -> tcsY, 2 -> tcsX}],
                tcsExpectation[2, tcsBellGates, {1 -> tcsX, 2 -> tcsY}],
                tcsExpectation[2, tcsBellGates, {1 -> tcsZ}],
                tcsExpectation[2, tcsBellGates, {1 -> tcsZ, 2 -> tcsZ}]
            },
            {1., -1., 0., -1.}
        ],
        True,
        TestID -> "paclet-tn-canonical-T2-bell-correlators"
    ]
];

(* ----- T3: the GHZ-type circuit gives (E^(I Pi/4) |001> + |110>) / Sqrt[2]; asked for in
   each of the six qubit orders, the state equals the closed form with its slots in
   that order. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T3-ghz-circuit-state",
    "quimb test_circuit.py:142-146 (GHZ-3 prepare); closed form",
    VerificationTest[
        With[{closed = Normal @ SparseArray[{{1, 1, 2} -> Exp[I Pi / 4.] / Sqrt[2.], {2, 2, 1} -> 1 / Sqrt[2.]}, {2, 2, 2}]},
            AllTrue[Permutations[{1, 2, 3}],
                tcsClose[tcsState[3, tcsGHZGates, #], Transpose[closed, Ordering[#]]] &]
        ],
        True,
        TestID -> "paclet-tn-canonical-T3-ghz-circuit-state"
    ]
];

(* ----- T4: on a |001> + b |110> with a = E^(I Pi/4) / Sqrt[2], b = 1 / Sqrt[2]:
   <X1 X2 X3> = 2 Re(Conjugate[a] b) = Cos[Pi/4], <Y1 X2 X3> = -2 Im(a Conjugate[b]) = -Sin[Pi/4],
   <Z1 Z2> = 1, <Z2 Z3> = -1, <Z1 Z3> = -1. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T4-ghz-correlators",
    "quimb test_circuit.py:142-146 (GHZ correlations); closed form",
    VerificationTest[
        tcsClose[
            {
                tcsExpectation[3, tcsGHZGates, {1 -> tcsX, 2 -> tcsX, 3 -> tcsX}],
                tcsExpectation[3, tcsGHZGates, {1 -> tcsY, 2 -> tcsX, 3 -> tcsX}],
                tcsExpectation[3, tcsGHZGates, {1 -> tcsZ, 2 -> tcsZ}],
                tcsExpectation[3, tcsGHZGates, {2 -> tcsZ, 3 -> tcsZ}],
                tcsExpectation[3, tcsGHZGates, {1 -> tcsZ, 3 -> tcsZ}]
            },
            {Cos[Pi / 4.], -Sin[Pi / 4.], 1., -1., -1.}
        ],
        True,
        TestID -> "paclet-tn-canonical-T4-ghz-correlators"
    ]
];

(* ----- T5: four complex random two-qubit unitaries in a brickwork on three qubits after
   H on every qubit: the state (qubit order 2, 3, 1) equals the dense simulation, and
   <Y1 Z2 X3> equals Conjugate[v] . (Y x Z x X) . v. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T5-random-brickwork",
    "dense state-vector simulation",
    VerificationTest[
        Module[{unitaries, gates, v},
            unitaries = BlockRandom[SeedRandom[801];
                Table[First @ QRDecomposition[RandomComplex[{-1 - I, 1 + I}, {4, 4}]], 4]];
            gates = Join[
                Table[{tcsH, {q}}, {q, 3}],
                {{unitaries[[1]], {1, 2}}, {unitaries[[2]], {2, 3}}, {unitaries[[3]], {1, 2}}, {unitaries[[4]], {2, 3}}}];
            v = tcsDense[3, gates];
            tcsClose[tcsState[3, gates, {2, 3, 1}], Transpose[ArrayReshape[v, {2, 2, 2}], {3, 1, 2}]] &&
                tcsClose[tcsExpectation[3, gates, {1 -> tcsY, 2 -> tcsZ, 3 -> tcsX}],
                    Conjugate[v] . KroneckerProduct[tcsY, tcsZ, tcsX] . v]
        ],
        True,
        TestID -> "paclet-tn-canonical-T5-random-brickwork"
    ]
];

(* ----- T6: 3x3 PEPS norm + per-site <Z> via fixture
   The original test ('5x5 PEPS local_expectation') was infeasible to validate
   exactly (5x5 PEPS exceeds exact contraction width) and the value was tied
   to quimb's RNG. We lift the 3x3 case (where exact contraction is tractable)
   from quimb: the 9 site tensors with quimb's verbatim leg labels are stored
   in a JSON fixture, and the paclet reconstructs the same TN bra-ket
   sandwich (Z gate inserted for each site) and matches all 10 scalars. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-tn-canonical-T6-peps-local-expect",
    "quimb PEPS.rand(3,3,seed=42) (fixture: external_oracles/fixtures/quimb_peps_3x3_seed42.json)",
    VerificationTest[
        Module[{fixture, Lx, Ly, sites, physSet, ketLegs, ketTensors, braLegs,
                braRename, tnNorm, normSq, normExpected, zMat, zExpected,
                physLegOf, zSites, gatedLeg, normOK, zOK, allZ},
            fixture = Import[OracleFixturePath["quimb_peps_3x3_seed42.json"], "RawJSON"];
            Lx = fixture["Lx"]; Ly = fixture["Ly"];
            sites = fixture["site_tensors"];
            physSet = Association @ KeyValueMap[Rule, fixture["phys_legs"]];
            normExpected = fixture["expected_norm_sq"];
            zExpected = fixture["expected_z_expectations"];
            zMat = fixture["z_matrix"];

            (* Bra renames non-physical (bond) legs so bond chains stay separate. *)
            braRename[leg_String] :=
                If[MemberQ[Values[physSet], leg], leg, leg <> "__bra"];

            ketLegs = sites[[All, "legs"]];
            ketTensors = sites[[All, "data"]];
            braLegs = Map[braRename, ketLegs, {2}];

            (* ----- norm-squared <psi|psi> ----- *)
            tnNorm = TensorNetwork[
                Join[ketTensors, ketTensors],
                Join[ketLegs, braLegs]
            ];
            normSq = TensorNetworkContract[tnNorm];
            normOK = ValidationCloseRel[normSq, normExpected, 1.*^-10];

            (* ----- <psi|Z_{i,j}|psi> for all 9 sites ----- *)
            physLegOf[site_List] := physSet[ToString[site[[1]]] <> "," <> ToString[site[[2]]]];
            zSites = sites[[All, "site"]];

            allZ = Table[
                Module[{site, pLeg, gLeg, braLegsGated, allLegs, allTensors, tnZ},
                    site = zSites[[k]];
                    pLeg = physLegOf[site];
                    gLeg = pLeg <> "__gated";
                    braLegsGated = braLegs /. (pLeg -> gLeg);
                    allTensors = Join[ketTensors, ketTensors, {zMat}];
                    allLegs = Join[ketLegs, braLegsGated, {{gLeg, pLeg}}];
                    tnZ = TensorNetwork[allTensors, allLegs];
                    TensorNetworkContract[tnZ]
                ],
                {k, Length[zSites]}
            ];

            zOK = AllTrue[
                Range[Length[zSites]],
                Function[k,
                    Module[{site, key, ref},
                        site = zSites[[k]];
                        key = ToString[site[[1]]] <> "," <> ToString[site[[2]]];
                        ref = zExpected[key];
                        ValidationCloseRel[allZ[[k]], ref, 1.*^-10]
                    ]
                ]
            ];

            normOK && zOK
        ],
        True,
        TestID -> "paclet-tn-canonical-T6-peps-local-expect"
    ]
];

(* ----- T7: skip - DMRG/TEBD-prepared states (no DMRG in paclet) *)
RecordSkipMissing["paclet-tn-canonical-T7-dmrg-state-expect",
    {"DMRG"},
    "quimb / ITensorMPS DMRG ground-state expectation values"];
