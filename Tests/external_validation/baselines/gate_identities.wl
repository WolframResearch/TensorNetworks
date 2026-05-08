(* Tests/external_validation/baselines/gate_identities.wl

Baseline tests: gate identities. The paclet has no native circuit primitives, so we
build gates as KroneckerProducts and verify identities at the matrix level.
Where the paclet would extend this through Wolfram`QuantumFramework`, we leave
a capability-gated skip.

Sources:
- quimb test_circuit.py:658-682 (multi-controlled gates)
- quimb test_circuit.py:129-146 (GHZ-3 prepare)
- quimb test_circuit.py:154-156 (QFT 4-qubit)
- quimb test_circuit.py:310-348 (SU4 decomposition vs raw)
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
        Print["[baseline-gates] ERROR: cannot locate ValidationHelpers.wl"]; Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* Single-qubit gates *)
gateI = IdentityMatrix[2];
gateX = {{0, 1}, {1, 0}};
gateY = {{0, -I}, {I, 0}};
gateZ = {{1, 0}, {0, -1}};
gateH = (1/Sqrt[2]) {{1, 1}, {1, -1}};
gateS = {{1, 0}, {0, I}};
gateT = {{1, 0}, {0, Exp[I Pi/4]}};

(* CNOT, CZ, SWAP — control on first qubit *)
gateCNOT = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 0, 1}, {0, 0, 1, 0}};
gateCZ = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, -1}};
gateSWAP = {{1, 0, 0, 0}, {0, 0, 1, 0}, {0, 1, 0, 0}, {0, 0, 0, 1}};

(* 3-qubit Toffoli (CCNOT, control-control-target on |..1> -> flip) and Fredkin *)
toffoliMat = ReplacePart[N @ IdentityMatrix[8],
    {{7, 7} -> 0, {8, 8} -> 0, {7, 8} -> 1, {8, 7} -> 1}];
fredkinMat = ReplacePart[N @ IdentityMatrix[8],
    {{6, 6} -> 0, {7, 7} -> 0, {6, 7} -> 1, {7, 6} -> 1}];

(* ----- E1: GHZ-3 prepare via H ⊗ I ⊗ I, then CNOT(0,1), CNOT(1,2)
   Final state should be (|000> + |111>)/√2. *)
VerificationTest[
    Module[{psi0, U, finalState, ghz3},
        psi0 = SparseArray[{1 -> 1}, 8];  (* |000> *)
        (* H on qubit 0: H ⊗ I ⊗ I *)
        U = KroneckerProduct[gateH, gateI, gateI];
        psi0 = U . psi0;
        (* CNOT(0,1): control qubit 0, target qubit 1, identity on qubit 2 *)
        U = KroneckerProduct[gateCNOT, gateI];
        psi0 = U . psi0;
        (* CNOT(1,2): identity on qubit 0, CNOT on (1,2) *)
        U = KroneckerProduct[gateI, gateCNOT];
        finalState = U . psi0;
        ghz3 = N @ Normalize[SparseArray[{1 -> 1, 8 -> 1}, 8]];
        ValidationClose[Abs[Re[Conjugate[ghz3] . finalState]], 1.0, 1.*^-12]
    ],
    True,
    TestID -> "baseline-gates-E1-ghz3-prep"
];

(* ----- E2: Toffoli equals controlled-controlled-X
   Direct hand-built CCNOT vs the explicit matrix above — sanity. *)
VerificationTest[
    Module[{ccx, expected},
        (* Build via projector: |11><11| ⊗ X + (I - |11><11|) ⊗ I *)
        ccx = KroneckerProduct[
                DiagonalMatrix[{0, 0, 0, 1}], gateX
              ] + KroneckerProduct[
                IdentityMatrix[4] - DiagonalMatrix[{0, 0, 0, 1}], gateI
              ];
        ValidationClose[N @ ccx, toffoliMat, 1.*^-12]
    ],
    True,
    TestID -> "baseline-gates-E2-toffoli-ccx"
];

(* ----- E3: Fredkin equals controlled-SWAP
   |1><1|_0 ⊗ SWAP + |0><0|_0 ⊗ I_4 *)
VerificationTest[
    Module[{cswap, expected},
        cswap = KroneckerProduct[{{0, 0}, {0, 1}}, gateSWAP] +
                KroneckerProduct[{{1, 0}, {0, 0}}, IdentityMatrix[4]];
        ValidationClose[N @ cswap, fredkinMat, 1.*^-12]
    ],
    True,
    TestID -> "baseline-gates-E3-fredkin-cswap"
];

(* ----- E4: 4-qubit QFT unitary
   QFT matrix entries: F[j,k] = (1/sqrt(N)) ω^{(j-1)(k-1)} where ω = exp(2πi/N).
   Verify F is unitary (F.F† = I). *)
VerificationTest[
    Module[{N, omega, qft, prod},
        N = 16;
        omega = Exp[2 Pi I / N];
        qft = (1/Sqrt[N]) * Table[omega^((j - 1)(k - 1)), {j, N}, {k, N}];
        prod = qft . ConjugateTranspose[qft];
        ValidationClose[prod, IdentityMatrix[N], 1.*^-12]
    ],
    True,
    TestID -> "baseline-gates-E4-qft4-unitary"
];

(* ----- E5: HCH = Z (Hadamard sandwich identity) *)
VerificationTest[
    ValidationClose[gateH . gateZ . gateH, gateX, 1.*^-12],
    True,
    TestID -> "baseline-gates-E5-hch-equals-x"
];

(* ----- E6: H Z H = X (alternative form) — sanity *)
VerificationTest[
    ValidationClose[gateH . gateX . gateH, gateZ, 1.*^-12],
    True,
    TestID -> "baseline-gates-E6-hxh-equals-z"
];

(* ----- E7: T² = S (gate identity) *)
VerificationTest[
    ValidationClose[gateT . gateT, gateS, 1.*^-12],
    True,
    TestID -> "baseline-gates-E7-tsquared-equals-s"
];

(* ----- E8: skip — paclet TN-of-circuit primitives
   The paclet has no exported Circuit / Gate constructors that produce a
   tensor-network representation. quimb's qtn.Circuit is the reference. *)
RecordSkipMissing["baseline-gates-E8-tn-circuit",
    {"Circuit", "ApplyGate"},
    "quimb docs/tensor/tensor-circuit.ipynb (Circuit primitives)"];

(* ----- E9: skip — sample / amplitude on a circuit (no paclet circuit type) *)
RecordSkipMissing["baseline-gates-E9-amplitude-sample",
    {"CircuitAmplitude", "CircuitSample"},
    "quimb tests/test_circuit.py:466-487 (circ.sample)"];
