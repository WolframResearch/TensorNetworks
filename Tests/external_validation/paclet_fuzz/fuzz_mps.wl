(* Tests/external_validation/paclet_fuzz/fuzz_mps.wl

   Property-based fuzz layer for MPSCanonicalForm, MPSOverlap, MPSNorm,
   MPSNormalize, MPSSchmidtValues and MPSTruncate. Each sweep point draws a
   random complex MPS with random physical dimensions (2 or 3) and random
   bond dimensions (1 to 5) on every bond, plus a second, different state
   on the same sites, and checks every result against the dense state
   vector built here by plain matrix products, never by the paclet:

     - left, right and mixed (every centre) canonical forms give the same
       dense vector, and their tensors are isometries by explicit sums
     - MPSOverlap[a, b] = conj(vb) . va, MPSNorm = Norm[v],
       MPSNormalize gives v / Norm[v]
     - Schmidt values on every cut = SVD of the dense vector
     - MPSTruncate of the right-canonical state to one less than the largest
       Schmidt rank: the truncations are nested projections, so the squared
       error is at least the largest and at most the summed discarded weight
       of the dense vector over the cuts

   Edge cases: L = 2 (both boundaries adjacent), bond 1 everywhere (product
   state). Timing sentinel at L = 32, D = 8, checked by amplitudes of single
   configurations computed as plain matrix products.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-mps] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];


(* ----- Independent references *)

fuzzSameQ[x_, y_] := Norm[Flatten[{x - y}]] <= 10^-10 Max[1, Norm[Flatten[{y}]]];

fuzzHyperedges[n_] := Join[{{1, n + 1}}, Table[{i - 1, i, n + i}, {i, 2, n - 1}], {{n - 1, 2 n}}];

(* Layout: first {right, phys}, bulk {left, right, phys}, last {left, phys}. *)
fuzzMPS[phys_List, bonds_List] :=
    With[{n = Length[phys]},
        TensorNetwork[
            Join[
                {RandomComplex[{-1 - I, 1 + I}, {bonds[[1]], phys[[1]]}]},
                Table[RandomComplex[{-1 - I, 1 + I}, {bonds[[i - 1]], bonds[[i]], phys[[i]]}], {i, 2, n - 1}],
                {RandomComplex[{-1 - I, 1 + I}, {bonds[[n - 1]], phys[[n]]}]}
            ],
            fuzzHyperedges[n]
        ]
    ];

fuzzSiteStep[m_, t_ /; ArrayDepth[t] == 2] := m . t;
fuzzSiteStep[m_, t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        ArrayReshape[m . ArrayReshape[Transpose[t, {1, 3, 2}], {d[[1]], d[[3]] d[[2]]}], {Length[m] d[[3]], d[[2]]}]
    ];
fuzzDense[tn_] := Flatten[Fold[fuzzSiteStep, Transpose[First[tn["Tensors"]]], Rest[tn["Tensors"]]]];

fuzzCutValues[v_, phys_, k_] :=
    Diagonal[SingularValueDecomposition[ArrayReshape[v, {Times @@ Take[phys, k], Times @@ Drop[phys, k]}]][[2]]];

fuzzLeftGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[Conjugate[t[[r, p]]] t[[s, p]], {p, d[[2]]}], {r, d[[1]]}, {s, d[[1]]}]];
fuzzLeftGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[Conjugate[t[[a, r, p]]] t[[a, s, p]], {a, d[[1]]}, {p, d[[3]]}], {r, d[[2]]}, {s, d[[2]]}]
    ];
fuzzRightGram[t_ /; ArrayDepth[t] == 2] :=
    With[{d = Dimensions[t]}, Table[Sum[t[[a, p]] Conjugate[t[[b, p]]], {p, d[[2]]}], {a, d[[1]]}, {b, d[[1]]}]];
fuzzRightGram[t_ /; ArrayDepth[t] == 3] :=
    With[{d = Dimensions[t]},
        Table[Sum[t[[a, r, p]] Conjugate[t[[b, r, p]]], {r, d[[2]]}, {p, d[[3]]}], {a, d[[1]]}, {b, d[[1]]}]
    ];
fuzzIsometryQ[gram_] := fuzzSameQ[gram, IdentityMatrix[Length[gram]]];

leftCanonicalQ[ts_] := AllTrue[ts, fuzzIsometryQ[fuzzLeftGram[#]] &];
rightCanonicalQ[ts_] := AllTrue[ts, fuzzIsometryQ[fuzzRightGram[#]] &];

(* All checks for one random pair of states on L sites. Returns an
   association of named Booleans so a failure names the property. *)
checkMPSAgainstDense[L_Integer, maxBond_Integer, seed_Integer] :=
    BlockRandom[
        SeedRandom[seed];
        Module[{phys, bonds, mps, other, v, w, n, left, right, values, ranks, chi, err2, discarded},
            phys = RandomInteger[{2, 3}, L];
            bonds = RandomInteger[{1, maxBond}, L - 1];
            mps = fuzzMPS[phys, bonds];
            other = fuzzMPS[phys, RandomInteger[{1, maxBond}, L - 1]];
            v = fuzzDense[mps];
            w = fuzzDense[other];
            n = Norm[v];
            left = MPSCanonicalForm[mps, "Left"];
            right = MPSCanonicalForm[mps, "Right"];
            values = Table[fuzzCutValues[v, phys, k], {k, L - 1}];
            ranks = Count[#, s_ /; s > 10^-10 Max[#]] & /@ values;
            chi = Max[ranks] - 1;
            discarded = Total[Drop[#, UpTo[chi]]^2] & /@ values;
            err2 = If[chi >= 1,
                Norm[v - fuzzDense[MPSTruncate[right, chi, "Normalize" -> False]]]^2,
                0.
            ];
            <|
                "LeftState" -> fuzzSameQ[fuzzDense[left], v],
                "LeftIsometries" -> leftCanonicalQ[Most[left["Tensors"]]],
                "RightState" -> fuzzSameQ[fuzzDense[right], v],
                "RightIsometries" -> rightCanonicalQ[Rest[right["Tensors"]]],
                "Mixed" -> AllTrue[Range[L],
                    With[{ts = MPSCanonicalForm[mps, {"Mixed", #}]["Tensors"]},
                        fuzzSameQ[fuzzDense[TensorNetwork[ts, fuzzHyperedges[L]]], v] &&
                            leftCanonicalQ[Take[ts, # - 1]] && rightCanonicalQ[Drop[ts, #]]
                    ] &
                ],
                "Overlap" -> fuzzSameQ[MPSOverlap[mps, other], Conjugate[w] . v] &&
                    fuzzSameQ[MPSOverlap[other, mps], Conjugate[v] . w],
                "Norm" -> fuzzSameQ[MPSNorm[mps], n],
                "Normalize" -> fuzzSameQ[fuzzDense[MPSNormalize[mps]], v / n],
                "Schmidt" -> AllTrue[Range[L - 1],
                    fuzzSameQ[PadRight[MPSSchmidtValues[mps, #], Length[values[[#]]], 0.], values[[#]] / n] &
                ],
                "TruncationError" -> Or[
                    chi < 1,
                    Max[discarded] (1 - 10^-10) <= err2 <= Total[discarded] (1 + 10^-10) + 10^-20 n^2
                ]
            |>
        ]
    ];

failedChecks[results_List] := Union @ Flatten[Keys[Select[#, Not @* TrueQ]] & /@ results];


(* ----- F-MPS-1: small/medium sweep -----
   L in {3, 4, 5, 6}, bonds up to 4, seeds 1..4 = 16 pairs of states. *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSSchmidtValues", "MPSTruncate"},
    "paclet-fuzz-mps-1-small-sweep",
    "Complex MPS[L, D, d] sweep against the dense state vector",
    VerificationTest[
        failedChecks @ Flatten @ Table[checkMPSAgainstDense[L, 4, 100 L + seed], {L, 3, 6}, {seed, 4}],
        {},
        TestID -> "paclet-fuzz-mps-1-small-sweep"
    ]
];


(* ----- F-MPS-2: larger-bond sweep -----
   L in {6, 7}, bonds up to 5 (dense vectors up to 3^7 entries), seeds 1..3. *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSSchmidtValues", "MPSTruncate"},
    "paclet-fuzz-mps-2-larger-bond-sweep",
    "Complex MPS[L = 6..7, D <= 5, d] sweep against the dense state vector",
    VerificationTest[
        failedChecks @ Flatten @ Table[checkMPSAgainstDense[L, 5, 1000 L + seed], {L, 6, 7}, {seed, 3}],
        {},
        TestID -> "paclet-fuzz-mps-2-larger-bond-sweep"
    ]
];


(* ----- F-MPS-3: L=2 edge case -----
   Both boundary tensors are adjacent: the state is a matrix and truncation
   is a single SVD. *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSSchmidtValues", "MPSTruncate"},
    "paclet-fuzz-mps-3-edge-L2",
    "L=2 complex MPS (both boundaries adjacent)",
    VerificationTest[
        failedChecks @ Table[checkMPSAgainstDense[2, 5, 300 + seed], {seed, 6}],
        {},
        TestID -> "paclet-fuzz-mps-3-edge-L2"
    ]
];


(* ----- F-MPS-4: bond 1 edge case -----
   Every bond is 1: a product of random complex vectors. Overlaps with a
   second product state still need the conjugate on the right side. *)
WithCapability[{"TensorNetwork", "MPSOverlap", "MPSCanonicalForm", "MPSNorm",
                "MPSNormalize", "MPSSchmidtValues", "MPSTruncate"},
    "paclet-fuzz-mps-4-edge-D1-product",
    "Bond-1 complex product-state edge case",
    VerificationTest[
        failedChecks @ Flatten @ Table[checkMPSAgainstDense[L, 1, 400 + 10 L + seed], {L, {3, 5, 7}}, {seed, 3}],
        {},
        TestID -> "paclet-fuzz-mps-4-edge-D1-product"
    ]
];


(* ----- F-MPS-6: timing sentinel -----
   L = 32, D = 8, complex: left-canonicalize within 15 s. The dense vector is
   out of reach, so the state is compared on 20 random configurations, each
   amplitude a product of 32 matrices, and every tensor but the last must be
   a left isometry. *)
WithCapability[{"TensorNetwork", "MPSCanonicalForm"},
    "paclet-fuzz-mps-6-timing",
    "L=32, D=8 complex left-canonicalize within 15s",
    VerificationTest[
        BlockRandom[
            SeedRandom[101];
            Module[{mps, canon, configs, amp},
                mps = fuzzMPS[ConstantArray[2, 32], ConstantArray[8, 31]];
                configs = RandomInteger[{1, 2}, {20, 32}];
                amp[ts_, c_] := First[ts][[All, First[c]]] .
                    (Dot @@ MapThread[#1[[All, All, #2]] &, {ts[[2 ;; -2]], c[[2 ;; -2]]}]) .
                    Last[ts][[All, Last[c]]];
                And[
                    WithBudget[15., (canon = MPSCanonicalForm[mps, "Left"]; True)],
                    fuzzSameQ[amp[canon["Tensors"], #] & /@ configs, amp[mps["Tensors"], #] & /@ configs],
                    leftCanonicalQ[Most[canon["Tensors"]]]
                ]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-mps-6-timing"
    ]
];
