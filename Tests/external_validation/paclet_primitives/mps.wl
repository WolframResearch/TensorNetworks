(* Tests/external_validation/paclet_primitives/mps.wl

Paclet-primitive tests: MPS-specific paclet primitives. Exercises:
  MPSCanonicalForm, MPSOverlap, MPSNorm, MPSNormalize,
  MPSEntanglementEntropy, MPSSchmidtValues, MPSTruncate.

Every state is a random complex MPS with unequal physical and bond
dimensions, and every result is compared with the dense state vector built
here by plain matrix products (primDenseState), never by the paclet: canonical
forms leave the vector unchanged and their tensors are isometries by
explicit sums; overlaps of two different states equal conj(v2) . v1;
Schmidt values and entropies equal the SVD of the dense vector on each cut;
truncation of a canonical state on one cut equals the best rank-chi
approximation. G11 checks the overlap against a quimb fixture.

Sources mirrored:
- ITensorMPS test_mps.jl (inner, orthogonalize!, truncate!)
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


(* ----- Independent references: dense state vectors by plain matrix products *)

primMpsSameQ[x_, y_] := Norm[Flatten[{x - y}]] <= 10^-10 Max[1, Norm[Flatten[{y}]]];

primMpsHyperedges[n_] := Join[{{1, n + 1}}, Table[{i - 1, i, n + i}, {i, 2, n - 1}], {{n - 1, 2 n}}];

(* Layout: first {right, phys}, bulk {left, right, phys}, last {left, phys}. *)
primRandomComplexMPS[phys_List, bonds_List, seed_] :=
    BlockRandom[
        SeedRandom[seed];
        With[{n = Length[phys]},
            TensorNetwork[
                Join[
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[1]], phys[[1]]}]},
                    Table[RandomComplex[{-1 - I, 1 + I}, {bonds[[i - 1]], bonds[[i]], phys[[i]]}], {i, 2, n - 1}],
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[n - 1]], phys[[n]]}]}
                ],
                primMpsHyperedges[n]
            ]
        ]
    ];

primSiteStep[m_, t_ /; ArrayDepth[t] == 2] := m . t;
primSiteStep[m_, t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        ArrayReshape[m . ArrayReshape[Transpose[t, {1, 3, 2}], {d[[1]], d[[3]] d[[2]]}], {Length[m] d[[3]], d[[2]]}]
    ];
primDenseState[tn_] := Flatten[Fold[primSiteStep, Transpose[First[tn["Tensors"]]], Rest[tn["Tensors"]]]];

primCutMatrix[v_, phys_, k_] := ArrayReshape[v, {Times @@ Take[phys, k], Times @@ Drop[phys, k]}];
primCutSpectrum[v_, phys_, k_] := Diagonal[SingularValueDecomposition[primCutMatrix[Normalize[v], phys, k]][[2]]];
primBestRank[v_, phys_, k_, chi_] :=
    With[{svd = SingularValueDecomposition[primCutMatrix[v, phys, k]]},
        Flatten[svd[[1, All, ;; chi]] . svd[[2, ;; chi, ;; chi]] . ConjugateTranspose[svd[[3, All, ;; chi]]]]
    ];

(* Sum over left bond and phys of conj(A) A (left isometry); over right bond
   and phys of A conj(A) (right isometry). *)
primLeftGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[Conjugate[t[[r, p]]] t[[s, p]], {p, d[[2]]}], {r, d[[1]]}, {s, d[[1]]}]];
primLeftGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[Conjugate[t[[a, r, p]]] t[[a, s, p]], {a, d[[1]]}, {p, d[[3]]}], {r, d[[2]]}, {s, d[[2]]}]
    ];
primRightGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[t[[a, p]] Conjugate[t[[b, p]]], {p, d[[2]]}], {a, d[[1]]}, {b, d[[1]]}]];
primRightGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[t[[a, r, p]] Conjugate[t[[b, r, p]]], {r, d[[2]]}, {p, d[[3]]}], {a, d[[1]]}, {b, d[[1]]}]
    ];
primIsometryQ[gram_] := primMpsSameQ[gram, IdentityMatrix[Length[gram]]];

(* Six sites, physical dimensions 2, 3, 2, 4, 3, 2, bonds 2, 4, 5, 3, 2. *)
physG = {2, 3, 2, 4, 3, 2};
mpsG = primRandomComplexMPS[physG, {2, 4, 5, 3, 2}, 401];
psiG = primDenseState[mpsG];

(* ----- G2: MPSOverlap of two different complex states equals the dense
   inner product, with the second argument conjugated (as documented), and
   MPSNorm equals the dense norm. ITensorMPS test_mps.jl:241-253 (inner). *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSNorm"},
    "paclet-mps-G2-overlap-two-states-dense",
    "ITensorMPS test/base/test_mps.jl:241-253 (inner)",
    VerificationTest[
        Module[{other, psiO},
            other = primRandomComplexMPS[physG, {2, 3, 3, 4, 2}, 409];
            psiO = primDenseState[other];
            {
                primMpsSameQ[MPSOverlap[mpsG, other], Conjugate[psiO] . psiG],
                primMpsSameQ[MPSOverlap[other, mpsG], Conjugate[psiG] . psiO],
                primMpsSameQ[MPSNorm[mpsG], Norm[psiG]]
            }
        ],
        {True, True, True},
        TestID -> "paclet-mps-G2-overlap-two-states-dense"
    ]
];

(* ----- G3: left-canonical form leaves the dense state unchanged and every
   tensor but the last is a left isometry (explicit sum).
   ITensorMPS test_mps.jl:680-754 (orthogonalize!). *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm"},
    "paclet-mps-G3-canonical-left",
    "ITensorMPS test/base/test_mps.jl:680-754 (left orthogonality)",
    VerificationTest[
        Module[{canon},
            canon = MPSCanonicalForm[mpsG, "Left"];
            {primMpsSameQ[primDenseState[canon], psiG], AllTrue[Most[canon["Tensors"]], primIsometryQ[primLeftGram[#]] &]}
        ],
        {True, True},
        TestID -> "paclet-mps-G3-canonical-left"
    ]
];

(* ----- G4: right-canonical form leaves the dense state unchanged and every
   tensor but the first is a right isometry (explicit sum). *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm"},
    "paclet-mps-G4-canonical-right",
    "ITensorMPS test/base/test_mps.jl (right orthogonality)",
    VerificationTest[
        Module[{canon},
            canon = MPSCanonicalForm[mpsG, "Right"];
            {primMpsSameQ[primDenseState[canon], psiG], AllTrue[Rest[canon["Tensors"]], primIsometryQ[primRightGram[#]] &]}
        ],
        {True, True},
        TestID -> "paclet-mps-G4-canonical-right"
    ]
];

(* ----- G5: mixed-canonical form at every site k: dense state unchanged,
   sites left of k left isometries, sites right of k right isometries. *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm"},
    "paclet-mps-G5-canonical-mixed",
    "ITensorMPS test/base/test_mps.jl (mixed canonical at site k)",
    VerificationTest[
        Table[
            Module[{ts},
                ts = MPSCanonicalForm[mpsG, {"Mixed", k}]["Tensors"];
                And[
                    primMpsSameQ[primDenseState[TensorNetwork[ts, primMpsHyperedges[6]]], psiG],
                    AllTrue[Take[ts, k - 1], primIsometryQ[primLeftGram[#]] &],
                    AllTrue[Drop[ts, k], primIsometryQ[primRightGram[#]] &]
                ]
            ],
            {k, 6}
        ],
        ConstantArray[True, 6],
        TestID -> "paclet-mps-G5-canonical-mixed"
    ]
];

(* ----- G6: Canonicalization preserves the state up to gauge: the overlap
   of a complex state with its left-canonical form is its squared norm.
   ITensorMPS test_mps.jl norm preservation. *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm", "MPSOverlap", "MPSNorm"},
    "paclet-mps-G6-canon-preserves-norm",
    "ITensorMPS test/base/test_mps.jl (canonical-form preserves overlap)",
    VerificationTest[
        Module[{mps, canon, normMps, normCanon, ovrl},
            mps = primRandomComplexMPS[{2, 3, 2, 3, 2, 2}, {4, 4, 4, 4, 4}, 433];
            canon = MPSCanonicalForm[mps, "Left"];
            normMps = MPSNorm[mps];
            normCanon = MPSNorm[canon];
            ovrl = MPSOverlap[mps, canon];
            ValidationCloseRel[normCanon, normMps, 1.*^-10] &&
                ValidationCloseRel[ovrl, normMps^2, 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-G6-canon-preserves-norm"
    ]
];

(* ----- G7: Schmidt values on every cut equal the singular values of the
   normalized dense state reshaped across that cut.
   TeNPy doc/toycodes/a_mps.py (Schmidt values). *)
WithCapability[{"TensorNetwork", "MPSSchmidtValues"},
    "paclet-mps-G7-schmidt-equals-dense-svd",
    "TeNPy doc/toycodes/a_mps.py (Schmidt values)",
    VerificationTest[
        Table[
            With[{sv = primCutSpectrum[psiG, physG, k]},
                primMpsSameQ[PadRight[MPSSchmidtValues[mpsG, k], Length[sv], 0.], sv]
            ],
            {k, 5}
        ],
        ConstantArray[True, 5],
        TestID -> "paclet-mps-G7-schmidt-equals-dense-svd"
    ]
];

(* ----- G8: entanglement entropy on every cut equals -Sum p Log p over the
   squared singular values of the dense state.
   ITensorMPS test_mps.jl (entanglement entropy). *)
WithCapability[{"TensorNetwork", "MPSEntanglementEntropy"},
    "paclet-mps-G8-entropy-equals-dense-svd",
    "ITensorMPS test/base/test_mps.jl (entanglement entropy)",
    VerificationTest[
        Table[
            With[{pk = Select[primCutSpectrum[psiG, physG, k]^2, # > 0 &]},
                primMpsSameQ[MPSEntanglementEntropy[mpsG, k], -Total[pk Log[pk]]]
            ],
            {k, 5}
        ],
        ConstantArray[True, 5],
        TestID -> "paclet-mps-G8-entropy-equals-dense-svd"
    ]
];

(* ----- G9: MPSTruncate of a right-canonical state to bond 4: the Schmidt
   ranks on the five cuts are 2, 4, 5, 3, 2, so only the cut after site 3 is
   cut. The normalized result is the normalized best rank-4 approximation
   across that cut, and every bond is at most 4.
   ITensorMPS test_mps.jl:755-794 (truncate!). *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm", "MPSTruncate"},
    "paclet-mps-G9-truncate-best-rank",
    "ITensorMPS test/base/test_mps.jl:755-794 (truncate!)",
    VerificationTest[
        Module[{truncated},
            truncated = MPSTruncate[MPSCanonicalForm[mpsG, "Right"], 4];
            {
                Max[Most /@ Dimensions /@ truncated["Tensors"]],
                primMpsSameQ[primDenseState[truncated], Normalize[primBestRank[psiG, physG, 3, 4]]]
            }
        ],
        {4, True},
        TestID -> "paclet-mps-G9-truncate-best-rank"
    ]
];

(* ----- G12: MPSNormalize divides the dense state by its norm. *)
WithCapability[{"TensorNetwork", "MPSNormalize"},
    "paclet-mps-G12-normalize-dense",
    "ITensorMPS test/base/test_mps.jl (normalize!)",
    VerificationTest[
        primMpsSameQ[primDenseState[MPSNormalize[mpsG]], psiG / Norm[psiG]],
        True,
        TestID -> "paclet-mps-G12-normalize-dense"
    ]
];

(* ----- G10: Skip: DMRG ground-state expectation
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
