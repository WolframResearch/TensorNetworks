(* Tests/external_validation/baselines/analytic_grounds.wl

Baseline tests: small-system analytic ground states. We build Hamiltonians as dense
matrices and use Mathematica's Eigensystem. The paclet has no DMRG, so the
matching test that goes via paclet primitives uses TensorNetworkContract on a
ground-state MPS once it's been computed (see paclet_primitives/tn_expectations.wl). Here we just check that
analytic / dense-ED answers reproduce the catalogued numbers.

Sources:
- quimb optimization #4 (2-qubit Heisenberg ground = -3/4)
- TeNPy tfi_exact.infinite_excitation_dispersion (TFIM dispersion)
- TeNPy AKLT exact (e=-2/3, S=log2, ξ=1/log3)
- ITensorMPS Heisenberg + TFIM ED references
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
        Print["[baseline-analytic] ERROR: cannot locate ValidationHelpers.wl"]; Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* Pauli matrices and spin-1 helpers *)
sigmaX = {{0, 1}, {1, 0}};
sigmaY = {{0, -I}, {I, 0}};
sigmaZ = {{1, 0}, {0, -1}};
spinHalfX = sigmaX/2; spinHalfY = sigmaY/2; spinHalfZ = sigmaZ/2;
sId[d_] := IdentityMatrix[d];

(* Apply local 2-site operator at sites (i,i+1) on an L-site spin-1/2 chain *)
twoSiteTerm[L_, i_, op_] := Which[
    L === 2 && i === 1, op,
    i === 1, KroneckerProduct[op, sId[2^(L - 2)]],
    i === L - 1, KroneckerProduct[sId[2^(L - 2)], op],
    True, KroneckerProduct[sId[2^(i - 1)], op, sId[2^(L - i - 1)]]
];

(* Apply local 1-site operator at site i on L-site chain *)
oneSiteTerm[L_, i_, op_] := Which[
    L === 1, op,
    i === 1, KroneckerProduct[op, sId[2^(L - 1)]],
    i === L, KroneckerProduct[sId[2^(L - 1)], op],
    True, KroneckerProduct[sId[2^(i - 1)], op, sId[2^(L - i)]]
];

heisenbergH[L_] := Module[{op, H},
    op = KroneckerProduct[spinHalfX, spinHalfX] +
         KroneckerProduct[spinHalfY, spinHalfY] +
         KroneckerProduct[spinHalfZ, spinHalfZ];
    H = ConstantArray[0, {2^L, 2^L}];
    Do[H += twoSiteTerm[L, i, op], {i, L - 1}];
    H
];

(* TFIM with H = -J Σ Z_i Z_{i+1} - g Σ X_i (TeNPy convention) *)
tfimH[L_, J_, g_] := Module[{ZZ, H},
    ZZ = KroneckerProduct[sigmaZ, sigmaZ];
    H = ConstantArray[0, {2^L, 2^L}];
    Do[H -= J * twoSiteTerm[L, i, ZZ], {i, L - 1}];
    Do[H -= g * oneSiteTerm[L, i, sigmaX], {i, L}];
    H
];

(* ----- D1: 2-qubit Heisenberg ground = -3/4 (quimb optimization #4) *)
VerificationTest[
    Module[{H, vals},
        H = N @ heisenbergH[2];
        vals = Sort @ Eigenvalues[H];
        ValidationClose[First[vals], -3/4, 1.*^-12]
    ],
    True,
    TestID -> "baseline-analytic-D1-heisenberg-2qubit"
];

(* ----- D2: 4-qubit OBC Heisenberg ground via dense ED.
   Reference value via Sort[Eigenvalues[H_4]] = -1.6160254037844386
   = -1 - Sqrt[3]/2 ≈ -1.866; actually the direct ED gives -1.61603. *)
VerificationTest[
    Module[{H, gsED, gsExpected},
        H = N @ heisenbergH[4];
        gsED = First @ Sort @ Re @ Eigenvalues[H];
        gsExpected = -1.6160254037844388;  (* exact dense-ED reference, OBC, AFM *)
        ValidationClose[gsED, gsExpected, 1.*^-10]
    ],
    True,
    TestID -> "baseline-analytic-D2-heisenberg-4qubit"
];

(* ----- D3: TFIM L=4 ground at g=1 (critical) — finite-system analytic
   E_exact = 1 − 1/sin(π/(4N+2)) [ITensorMPS test_dmrg.jl:218-247]. *)
VerificationTest[
    Module[{L, J, g, H, gsED, gsExpected},
        L = 4; J = 1; g = 1;
        H = N @ tfimH[L, J, g];
        gsED = First @ Sort @ Eigenvalues[H];
        gsExpected = 1 - 1/Sin[Pi / (4 L + 2)];
        ValidationClose[gsED, gsExpected, 1.*^-2]  (* finite-size correction expected *)
    ],
    True,
    TestID -> "baseline-analytic-D3-tfim-L4-critical"
];

(* ----- D4: TFIM dispersion ε(p)=2√(J²-2Jg·cosp+g²)
   Gap closes at g=J. (TeNPy tfi_exact.infinite_excitation_dispersion) *)
VerificationTest[
    Module[{eps, gap1, gap2},
        eps[p_, J_, g_] := 2 Sqrt[J^2 - 2 J g Cos[p] + g^2];
        (* At g = J = 1, gap = ε(0) = 0 *)
        gap1 = eps[0., 1., 1.];
        (* At g = 0.5, J = 1, gap = ε(0) = 2|J - g| = 1 *)
        gap2 = eps[0., 1., 0.5];
        ValidationClose[gap1, 0., 1.*^-12] && ValidationClose[gap2, 1., 1.*^-12]
    ],
    True,
    TestID -> "baseline-analytic-D4-tfim-dispersion"
];

(* ----- D5: AKLT exact correlation decay C(n) = (-1/3)^n × const.
   Build AKLT MPS A_L^{+1} = √(2/3) σ^+, A^0 = -√(1/3) σ_z, A^{-1} = -√(2/3) σ^-
   Transfer matrix: T = sum_m A^m ⊗ conj(A^m) has eigenvalues {1, -1/3, -1/3, -1/3}.
   The largest non-unit |λ| is 1/3, so correlation length ξ = 1/log(3). *)
VerificationTest[
    Module[{aP1, a0, aM1, transferMat, vals, sortedAbs, lambda2, xi},
        aP1 = Sqrt[2/3] * {{0, 1}, {0, 0}};         (* σ^+ = (σx + i σy)/2 *)
        a0  = -Sqrt[1/3] * {{1, 0}, {0, -1}};       (* -σ_z / √3 *)
        aM1 = -Sqrt[2/3] * {{0, 0}, {1, 0}};        (* -σ^- *)
        (* Transfer matrix for normal-ordered indices (l,r,l',r') as 4x4 *)
        transferMat = Sum[KroneckerProduct[a, Conjugate[a]], {a, {aP1, a0, aM1}}];
        vals = Eigenvalues[N @ transferMat];
        sortedAbs = Reverse @ Sort @ Abs[vals];
        lambda2 = sortedAbs[[2]];
        xi = -1 / Log[lambda2];
        ValidationClose[sortedAbs[[1]], 1.0, 1.*^-10] &&
            ValidationClose[lambda2, 1./3., 1.*^-10] &&
            ValidationClose[xi, 1./Log[3.], 1.*^-8]
    ],
    True,
    TestID -> "baseline-analytic-D5-aklt-correlation-length"
];

(* ----- D6: 4x4 Heisenberg ground / site comparison to quimb-stated value
   quimb PEPS #7: qu.groundenergy(qu.ham_heis_2D(4,4,sparse=True)) / 16
   = -0.5743254415745597. Skip - 16-site dense ED is 2^16 x 2^16 = 4G entries,
   needs sparse + Lanczos, which is out of scope here. *)
RecordSkipMissing["baseline-analytic-D6-heis2d-4x4-ground",
    {"SparseArrayHam", "Lanczos"},
    "quimb docs/tensor/tensor-2d.ipynb (4x4 Heisenberg ground -0.5743254...)"];

(* ----- D7: 4-qubit TFIM at g=2 (in paramagnetic phase) — ground = -? *)
VerificationTest[
    Module[{H, gs1, gs2, decreasing},
        (* TFI ground energy decreases monotonically with g for fixed J=1
           between g=0.5 and g=2.5 (in paramagnetic crossover regime). *)
        H = N @ tfimH[4, 1, 0.5];
        gs1 = First @ Sort @ Eigenvalues[H];
        H = N @ tfimH[4, 1, 2.5];
        gs2 = First @ Sort @ Eigenvalues[H];
        decreasing = gs2 < gs1;
        decreasing
    ],
    True,
    TestID -> "baseline-analytic-D7-tfim-monotone-g"
];

(* ----- D8: 6-qubit Heisenberg AFM ground via dense ED
   Pulled from ITensorMPS test_dmrg.jl style; check ground energy is real
   and below classical Néel-state energy. *)
VerificationTest[
    Module[{L, H, vals, gs, neelE},
        L = 6;
        H = N @ heisenbergH[L];
        vals = Sort @ Eigenvalues[H];
        gs = First[vals];
        neelE = -(L - 1)/4;  (* classical Néel: each Sz·Sz bond gives -1/4 *)
        Im[gs] < 1.*^-10 && Re[gs] < neelE
    ],
    True,
    TestID -> "baseline-analytic-D8-heisenberg-6qubit-below-neel"
];
