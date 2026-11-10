(* Tests/external_validation/paclet_primitives/mps_canonical_states.wl

Tier-2 direct-validation tests for MPS primitives on states whose answer is
known without the paclet: closed forms for the AKLT chain and a weighted GHZ
state, and the dense state vector (built here by plain matrix products) for
random complex states.

  T3  entropies of a complex state whose bonds exceed the Schmidt ranks,
      against the SVD of the dense state on every cut
  T4  mixed canonical form preserves the overlap with the original state
  T5  overlap of two AKLT chains with different complex boundary vectors,
      exact closed form with the transfer eigenvalue -1/3
  T6  Schmidt spectrum of an AKLT chain on every cut, closed form from the
      2 x 2 boundary Gram matrices
  T7  Schmidt values and entropy of a|0..0> + b|1..1> with complex a, b

Sources:
- TeNPy exercises_uniform_toycodes Part 1.2 (AKLT transfer matrix, -1/3)
- TeNPy a_mps.py (Schmidt values, entanglement entropy)
- ITensorMPS test_mps.jl:680-754 (orthogonalize preserves inner)
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

(* ----- Independent references *)

canonSameQ[x_, y_] := Norm[Flatten[{x - y}]] <= 10^-10 Max[1, Norm[Flatten[{y}]]];

canonHyperedges[n_] := Join[{{1, n + 1}}, Table[{i - 1, i, n + i}, {i, 2, n - 1}], {{n - 1, 2 n}}];

(* Layout: first {right, phys}, bulk {left, right, phys}, last {left, phys}. *)
canonRandomMPS[phys_List, bonds_List, seed_] :=
    BlockRandom[
        SeedRandom[seed];
        With[{n = Length[phys]},
            TensorNetwork[
                Join[
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[1]], phys[[1]]}]},
                    Table[RandomComplex[{-1 - I, 1 + I}, {bonds[[i - 1]], bonds[[i]], phys[[i]]}], {i, 2, n - 1}],
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[n - 1]], phys[[n]]}]}
                ],
                canonHyperedges[n]
            ]
        ]
    ];

canonSiteStep[m_, t_ /; ArrayDepth[t] == 2] := m . t;
canonSiteStep[m_, t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        ArrayReshape[m . ArrayReshape[Transpose[t, {1, 3, 2}], {d[[1]], d[[3]] d[[2]]}], {Length[m] d[[3]], d[[2]]}]
    ];
canonDenseState[tn_] := Flatten[Fold[canonSiteStep, Transpose[First[tn["Tensors"]]], Rest[tn["Tensors"]]]];

canonCutSpectrum[v_, phys_, k_] :=
    Diagonal[SingularValueDecomposition[ArrayReshape[Normalize[v], {Times @@ Take[phys, k], Times @@ Drop[phys, k]}]][[2]]];

(* AKLT matrices A^m for m = +1, 0, -1. They satisfy Sum A A^dagger =
   Sum A^dagger A = 1, and both maps X -> Sum A X A^dagger and
   X -> Sum A^dagger X A send each Pauli matrix to -1/3 of itself, so k
   applications act as akltChannel[X, k] = Tr X / 2 + (-1/3)^k (X - Tr X / 2). *)
akltA = {Sqrt[2/3] {{0, 1}, {0, 0}}, -Sqrt[1/3] {{1, 0}, {0, -1}}, -Sqrt[2/3] {{0, 0}, {1, 0}}};
akltChannel[x_, k_] := Tr[x] / 2 IdentityMatrix[2] + (-1/3)^k (x - Tr[x] / 2 IdentityMatrix[2]);

(* n-site AKLT chain with amplitude l . A^m1 ... A^mn . r. *)
akltMPS[n_, l_, r_] :=
    TensorNetwork[
        Join[
            {Transpose[(l . #) & /@ akltA]},
            ConstantArray[Transpose[akltA, {3, 1, 2}], n - 2],
            {Transpose[(# . r) & /@ akltA]}
        ],
        canonHyperedges[n]
    ];

(* <psi'|psi> = l^T E^n(r r'^dagger) conj(l'), with E(X) = Sum A X A^dagger. *)
akltOverlap[n_, {l_, r_}, {lp_, rp_}] := l . akltChannel[Outer[Times, r, Conjugate[rp]], n] . Conjugate[lp];

(* Squared Schmidt values on the cut after site k are the eigenvalues of
   GL . GR, with GL = Sum conj(L) L over the k left sites and GR = Sum R conj(R)
   over the n - k right sites, normalized to unit trace. *)
akltSchmidt[n_, k_, l_, r_] :=
    With[{g = akltChannel[Outer[Times, Conjugate[l], l], k] . akltChannel[Outer[Times, r, Conjugate[r]], n - k]},
        Sqrt[Reverse[Sort[Re[Eigenvalues[g]]]] / Re[Tr[g]]]
    ];


(* ----- T3: a complex state with physical dimensions 2, 3, 2, 3, 2 and bonds
   5, 6, 6, 5; the Schmidt ranks are 2, 6, 6, 2, so on the outer cuts the
   bond exceeds the rank and canonicalization meets zero singular values. The entropy on every
   cut equals -Sum p Log p over the squared singular values of the dense state.
   Source: TeNPy a_mps.py (entanglement entropy from Schmidt values). *)
WithCapability[{"TensorNetwork", "MPSEntanglementEntropy", "MPSSchmidtValues"},
    "paclet-mps-canonical-T3-oversized-bond-entropy-dense",
    "TeNPy a_mps.py (Schmidt entropy)",
    VerificationTest[
        Module[{phys, mps, psi},
            phys = {2, 3, 2, 3, 2};
            mps = canonRandomMPS[phys, {5, 6, 6, 5}, 509];
            psi = canonDenseState[mps];
            Table[
                With[{sv = canonCutSpectrum[psi, phys, k]},
                    {
                        canonSameQ[PadRight[MPSSchmidtValues[mps, k], Length[sv], 0.], sv],
                        With[{pk = Select[sv^2, # > 10^-24 &]}, canonSameQ[MPSEntanglementEntropy[mps, k], -Total[pk Log[pk]]]]
                    }
                ],
                {k, 4}
            ]
        ],
        ConstantArray[{True, True}, 4],
        TestID -> "paclet-mps-canonical-T3-oversized-bond-entropy-dense"
    ]
];

(* ----- T4: MPSCanonicalForm to mixed center reproduces overlap.
   Source: ITensorMPS test_mps.jl:680-754 (orthogonalize preserves inner).
   Direct: <canon|mps> = ||mps||^2 for a complex state. *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm", "MPSOverlap", "MPSNorm"},
    "paclet-mps-canonical-T4-mixed-canon-preserves-overlap",
    "ITensorMPS test/base/test_mps.jl:680-754",
    VerificationTest[
        Module[{mps, canon, ovrl, normSq},
            mps = canonRandomMPS[{2, 3, 2, 2, 3, 2}, {2, 4, 4, 4, 2}, 521];
            canon = MPSCanonicalForm[mps, {"Mixed", 3}];
            ovrl = MPSOverlap[mps, canon];
            normSq = MPSNorm[mps]^2;
            ValidationCloseRel[ovrl, normSq, 1.*^-10]
        ],
        True,
        TestID -> "paclet-mps-canonical-T4-mixed-canon-preserves-overlap"
    ]
];

(* ----- T5: overlap of two AKLT chains with different complex boundary
   vectors, in exact arithmetic, for 2 to 8 sites:
   <psi'|psi> = (r'^dagger r)(l'^dagger l)/2
              + (-1/3)^n ((l . r) conj(l' . r') - (r'^dagger r)(l'^dagger l)/2).
   Source: TeNPy exercises_uniform_toycodes Part 1.2 (AKLT transfer matrix
   eigenvalues 1, -1/3, -1/3, -1/3). *)
WithCapability[{"TensorNetwork", "MPSOverlap"},
    "paclet-mps-canonical-T5-aklt-overlap-closed-form",
    "TeNPy exercises_uniform_toycodes Part 1.2 (AKLT)",
    VerificationTest[
        Module[{ket, bra},
            ket = {{1, I}, {2, 1 - I}};
            bra = {{1 + I, 0}, {1, 3 - 2 I}};
            Table[
                Simplify[MPSOverlap[akltMPS[n, Sequence @@ ket], akltMPS[n, Sequence @@ bra]] - akltOverlap[n, ket, bra]],
                {n, 2, 8}
            ]
        ],
        ConstantArray[0, 7],
        TestID -> "paclet-mps-canonical-T5-aklt-overlap-closed-form"
    ]
];

(* ----- T6: Schmidt spectrum of a 12-site AKLT chain with complex boundary
   vectors on every cut, against the 2 x 2 boundary Gram matrices.
   Source: TeNPy exercises_uniform_toycodes Part 1.2 (AKLT). *)
WithCapability[{"TensorNetwork", "MPSSchmidtValues"},
    "paclet-mps-canonical-T6-aklt-schmidt-closed-form",
    "TeNPy exercises_uniform_toycodes Part 1.2 (AKLT)",
    VerificationTest[
        Module[{l, r, mps},
            l = N[{1 + 2 I, -1 / 2}];
            r = N[{I, 2 - I}];
            mps = akltMPS[12, l, r];
            Table[canonSameQ[MPSSchmidtValues[mps, k], akltSchmidt[12, k, l, r]], {k, 11}]
        ],
        ConstantArray[True, 11],
        TestID -> "paclet-mps-canonical-T6-aklt-schmidt-closed-form"
    ]
];

(* ----- T7: weighted GHZ state a|0..0> + b|1..1> with complex a, b of
   different moduli: on every cut the Schmidt values are
   {|a|, |b|} / Sqrt[|a|^2 + |b|^2} and the entropy is the binary entropy of
   |a|^2 / (|a|^2 + |b|^2), for 3 to 7 sites.
   Source: TeNPy entanglement_entropy on GHZ states. *)
WithCapability[{"TensorNetwork", "MPSSchmidtValues", "MPSEntanglementEntropy"},
    "paclet-mps-canonical-T7-weighted-ghz-entropy",
    "TeNPy entanglement_entropy on GHZ states",
    VerificationTest[
        Module[{a, b, p, ghz},
            a = 0.3 + 1.1 I;
            b = -0.7 + 0.2 I;
            p = Abs[a]^2 / (Abs[a]^2 + Abs[b]^2);
            ghz[n_] := TensorNetwork[
                Join[
                    {DiagonalMatrix[{a, b}]},
                    ConstantArray[Table[Boole[x == y == z], {x, 2}, {y, 2}, {z, 2}], n - 2],
                    {IdentityMatrix[2]}
                ],
                canonHyperedges[n]
            ];
            Union @ Flatten @ Table[
                {
                    canonSameQ[MPSSchmidtValues[ghz[n], k], Sqrt[{p, 1 - p}]],
                    canonSameQ[MPSEntanglementEntropy[ghz[n], k], -p Log[p] - (1 - p) Log[1 - p]]
                },
                {n, 3, 7}, {k, n - 1}
            ]
        ],
        {True},
        TestID -> "paclet-mps-canonical-T7-weighted-ghz-entropy"
    ]
];

(* ----- T8: skip - DMRG-prepared MPS specific energies (TFIM L=10 -> -12.38..., etc.)
   Requires DMRG. *)
RecordSkipMissing["paclet-mps-canonical-T8-dmrg-energies",
    {"DMRG"},
    "TeNPy/ITensorMPS DMRG ground-state energies"];
