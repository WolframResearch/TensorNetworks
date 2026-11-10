(* Tests/test_mps.wl

   Matrix product state functions checked against the dense state vector,
   which is built here by plain matrix products (unitDenseState), never by the
   paclet. Every state is complex, with unequal physical and bond
   dimensions, so a conjugated, transposed or reordered result changes the
   vector.

   - Canonical forms (left, right, mixed at every site) leave the dense
     vector unchanged, and their tensors are isometries, checked by explicit
     sums of conj(A) A over the contracted legs.
   - MPSOverlap of two different states equals conj(v2) . v1 (the second
     argument is conjugated, as documented); MPSNorm equals Norm[v];
     MPSNormalize gives v / Norm[v].
   - Schmidt values and entanglement entropy on every cut equal the singular
     values of the normalized dense vector reshaped across that cut.
   - Truncation of a canonical state to bond chi on a single cut equals the
     best rank-chi approximation (SVD of the dense vector across that cut),
     and the distance to the original is the root of the discarded weight.

   Layout: first tensor {right, physical}, bulk {left, right, physical},
   last tensor {left, physical}. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];


(* ============================================ *)
(* Independent references                       *)
(* ============================================ *)

(* Agreement to 10^-10 relative to the size of the reference. *)
unitNumericSameQ[x_, y_] := Norm[Flatten[{x - y}]] <= 10^-10 Max[1, Norm[Flatten[{y}]]]

unitMpsHyperedges[n_] := Join[{{1, n + 1}}, Table[{i - 1, i, n + i}, {i, 2, n - 1}], {{n - 1, 2 n}}]

unitRandomComplexMPS[phys_List, bonds_List, seed_] :=
    BlockRandom[
        SeedRandom[seed];
        With[{n = Length[phys]},
            TensorNetwork[
                Join[
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[1]], phys[[1]]}]},
                    Table[RandomComplex[{-1 - I, 1 + I}, {bonds[[i - 1]], bonds[[i]], phys[[i]]}], {i, 2, n - 1}],
                    {RandomComplex[{-1 - I, 1 + I}, {bonds[[n - 1]], phys[[n]]}]}
                ],
                unitMpsHyperedges[n]
            ]
        ]
    ]

(* Dense state vector, first site's physical index slowest: carry the
   matrix M[(p1..pi), bond] and multiply in one site at a time. *)
unitSiteStep[m_, t_ /; ArrayDepth[t] == 2] := m . t
unitSiteStep[m_, t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        ArrayReshape[m . ArrayReshape[Transpose[t, {1, 3, 2}], {d[[1]], d[[3]] d[[2]]}], {Length[m] d[[3]], d[[2]]}]
    ]
unitDenseState[tn_] := Flatten[Fold[unitSiteStep, Transpose[First[tn["Tensors"]]], Rest[tn["Tensors"]]]]

(* Dense vector reshaped across the cut after site k. *)
unitCutMatrix[v_, phys_, k_] := ArrayReshape[v, {Times @@ Take[phys, k], Times @@ Drop[phys, k]}]

(* All min(rows, columns) singular values of the normalized state across the cut. *)
unitCutSpectrum[v_, phys_, k_] := Diagonal[SingularValueDecomposition[unitCutMatrix[Normalize[v], phys, k]][[2]]]

unitPadTo[list_, n_] := PadRight[list, n, 0.]

(* Best rank-chi approximation of v across the cut after site k (Eckart-Young). *)
unitBestRank[v_, phys_, k_, chi_] :=
    With[{svd = SingularValueDecomposition[unitCutMatrix[v, phys, k]]},
        Flatten[svd[[1, All, ;; chi]] . svd[[2, ;; chi, ;; chi]] . ConjugateTranspose[svd[[3, All, ;; chi]]]]
    ]

unitDiscardedNorm[v_, phys_, k_, chi_] :=
    Sqrt[Total[Drop[Diagonal[SingularValueDecomposition[unitCutMatrix[v, phys, k]][[2]]], chi]^2]]

(* Explicit sums: Sum_{left, phys} conj(A[l, r, p]) A[l, r', p] for a left
   isometry, Sum_{right, phys} A[l, r, p] conj(A[l', r, p]) for a right one. *)
unitLeftGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[Conjugate[t[[r, p]]] t[[s, p]], {p, d[[2]]}], {r, d[[1]]}, {s, d[[1]]}]]
unitLeftGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[Conjugate[t[[a, r, p]]] t[[a, s, p]], {a, d[[1]]}, {p, d[[3]]}], {r, d[[2]]}, {s, d[[2]]}]
    ]
unitRightGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[t[[a, p]] Conjugate[t[[b, p]]], {p, d[[2]]}], {a, d[[1]]}, {b, d[[1]]}]]
unitRightGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[t[[a, r, p]] Conjugate[t[[b, r, p]]], {r, d[[2]]}, {p, d[[3]]}], {a, d[[1]]}, {b, d[[1]]}]
    ]
unitIsometryQ[gram_] := unitNumericSameQ[gram, IdentityMatrix[Length[gram]]]

(* Five sites with physical dimensions 3, 2, 4, 2, 3 and bonds 2, 3, 4, 3:
   generic Schmidt ranks 2, 3, 4, 3 on the four cuts. *)
physA = {3, 2, 4, 2, 3};
mpsA = unitRandomComplexMPS[physA, {2, 3, 4, 3}, 11];
psiA = unitDenseState[mpsA];

(* A second state on the same sites with different bonds 3, 2, 3, 2. *)
mpsB = unitRandomComplexMPS[physA, {3, 2, 3, 2}, 12];
psiB = unitDenseState[mpsB];


(* ============================================ *)
(* Canonical forms                              *)
(* ============================================ *)

VerificationTest[
    unitNumericSameQ[unitDenseState[MPSCanonicalForm[mpsA, "Left"]], psiA],
    True,
    TestID -> "MPSCanonicalForm_Left_PreservesState"
]

(* Every tensor but the last is a left isometry; the last carries the norm. *)
VerificationTest[
    With[{ts = MPSCanonicalForm[mpsA, "Left"]["Tensors"]},
        {unitIsometryQ[unitLeftGram[#]] & /@ Most[ts], unitNumericSameQ[Norm[Flatten[Last[ts]]], Norm[psiA]]}
    ],
    {ConstantArray[True, 4], True},
    TestID -> "MPSCanonicalForm_Left_IsCanonical"
]

VerificationTest[
    With[{c = MPSCanonicalForm[mpsA, "Right"]},
        {
            unitNumericSameQ[unitDenseState[c], psiA],
            unitIsometryQ[unitRightGram[#]] & /@ Rest[c["Tensors"]],
            unitNumericSameQ[Norm[Flatten[First[c["Tensors"]]]], Norm[psiA]]
        }
    ],
    {True, ConstantArray[True, 4], True},
    TestID -> "MPSCanonicalForm_Right_IsCanonical"
]

(* Mixed form centred at every site k: the state is unchanged, sites left of
   k are left isometries, sites right of k right isometries, and the centre
   tensor carries the whole norm. *)
VerificationTest[
    Table[
        With[{ts = MPSCanonicalForm[mpsA, {"Mixed", k}]["Tensors"]},
            And[
                unitNumericSameQ[unitDenseState[TensorNetwork[ts, unitMpsHyperedges[5]]], psiA],
                AllTrue[Take[ts, k - 1], unitIsometryQ[unitLeftGram[#]] &],
                AllTrue[Drop[ts, k], unitIsometryQ[unitRightGram[#]] &],
                unitNumericSameQ[Norm[Flatten[ts[[k]]]], Norm[psiA]]
            ]
        ],
        {k, 5}
    ],
    ConstantArray[True, 5],
    TestID -> "MPSCanonicalForm_Mixed_IsCanonical"
]

(* Right sweep with MaxBond -> 3 on a left-canonical state: only the cut after
   site 3 (rank 4) exceeds 3, so the result is the best rank-3 approximation
   of the state across that cut, and every bond is at most 3. *)
VerificationTest[
    With[{c = MPSCanonicalForm[MPSCanonicalForm[mpsA, "Left"], "Right", "MaxBond" -> 3]},
        {
            Max[Most /@ Dimensions /@ c["Tensors"]],
            unitNumericSameQ[unitDenseState[c], unitBestRank[psiA, physA, 3, 3]]
        }
    ],
    {3, True},
    TestID -> "MPSCanonicalForm_Right_RespectsMaxBond"
]


(* ============================================ *)
(* Overlap, norm, normalization                 *)
(* ============================================ *)

(* The second argument is conjugated: MPSOverlap[a, b] = conj(vb) . va. *)
VerificationTest[
    {
        unitNumericSameQ[MPSOverlap[mpsA, mpsB], Conjugate[psiB] . psiA],
        unitNumericSameQ[MPSOverlap[mpsB, mpsA], Conjugate[psiA] . psiB]
    },
    {True, True},
    TestID -> "MPSOverlap_TwoStatesEqualsDenseInnerProduct"
]

(* Bra and ket in different gauges with different bond dimensions on every
   bond: left-canonical A against right-canonical B truncated to bond 2. *)
VerificationTest[
    With[{b2 = MPSCanonicalForm[MPSCanonicalForm[mpsB, "Left"], "Right", "MaxBond" -> 2]},
        unitNumericSameQ[MPSOverlap[MPSCanonicalForm[mpsA, "Left"], b2], Conjugate[unitDenseState[b2]] . psiA]
    ],
    True,
    TestID -> "MPSOverlap_MixedGaugesEqualsDenseInnerProduct"
]

VerificationTest[
    {unitNumericSameQ[MPSNorm[mpsA], Norm[psiA]], unitNumericSameQ[MPSNorm[mpsB], Norm[psiB]]},
    {True, True},
    TestID -> "MPSNorm_EqualsDenseNorm"
]

VerificationTest[
    unitNumericSameQ[unitDenseState[MPSNormalize[mpsA]], psiA / Norm[psiA]],
    True,
    TestID -> "MPSNormalize_EqualsNormalizedDenseState"
]


(* ============================================ *)
(* Schmidt values and entropy                   *)
(* ============================================ *)

VerificationTest[
    Table[
        With[{sv = unitCutSpectrum[psiA, physA, k]},
            unitNumericSameQ[unitPadTo[MPSSchmidtValues[mpsA, k], Length[sv]], sv]
        ],
        {k, 4}
    ],
    ConstantArray[True, 4],
    TestID -> "MPSSchmidtValues_EqualDenseSVD"
]

VerificationTest[
    Table[
        With[{pk = Select[unitCutSpectrum[psiA, physA, k]^2, # > 0 &]},
            unitNumericSameQ[MPSEntanglementEntropy[mpsA, k], -Total[pk Log[pk]]]
        ],
        {k, 4}
    ],
    ConstantArray[True, 4],
    TestID -> "MPSEntanglementEntropy_EqualsDenseSVD"
]


(* ============================================ *)
(* Truncation                                   *)
(* ============================================ *)

(* MPSTruncate truncates during a left sweep, which is optimal when the
   input is right-canonical. With MaxBond 3 only the cut after site 3 is
   cut, from rank 4 to 3: the result is the Eckart-Young approximation and
   its distance from the original is the discarded singular value. *)
VerificationTest[
    With[{t = MPSTruncate[MPSCanonicalForm[mpsA, "Right"], 3, "Normalize" -> False]},
        {
            Max[Most /@ Dimensions /@ t["Tensors"]],
            unitNumericSameQ[unitDenseState[t], unitBestRank[psiA, physA, 3, 3]],
            unitNumericSameQ[Norm[psiA - unitDenseState[t]], unitDiscardedNorm[psiA, physA, 3, 3]]
        }
    ],
    {3, True, True},
    TestID -> "MPSTruncate_EqualsBestRankApproximation"
]

(* Two sites, physical dimensions 4 and 5, bond 4: the state is a 4 x 5
   matrix of rank 4. Truncating to chi = 1, 2, 3 gives its best rank-chi
   approximation, normalized by default. *)
VerificationTest[
    With[{two = unitRandomComplexMPS[{4, 5}, {4}, 21]},
        With[{v = unitDenseState[two], r = MPSCanonicalForm[two, "Right"]},
            Table[unitNumericSameQ[unitDenseState[MPSTruncate[r, chi]], Normalize[unitBestRank[v, {4, 5}, 1, chi]]], {chi, 3}]
        ]
    ],
    {True, True, True},
    TestID -> "MPSTruncate_TwoSitesNormalizedBestRank"
]

(* A bond at least the largest Schmidt rank removes nothing: the result is
   the normalized original state. *)
VerificationTest[
    unitNumericSameQ[unitDenseState[MPSTruncate[mpsA, 4]], psiA / Norm[psiA]],
    True,
    TestID -> "MPSTruncate_FullBondKeepsState"
]
