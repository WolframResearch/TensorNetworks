(* ::Package:: *)

(* Symmetry-for-TN: runnable examples showing how the Symmetry subpackage
   pays off for tensor-network operations. Validates every assertion that
   will appear in the companion notebook SymmetryForTN.nb.

   Run with:
       wolframscript -file "Notebooks/Tests and explorations/Symmetry/symmetry_for_tn.wl"
*)

(* ============================================================ *)
(* Paclet load (mirrors Tests/test_setup.wl)                    *)
(* ============================================================ *)

Module[{candidates, root},
    candidates = DeleteDuplicates @ Join[
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            NestList[ParentDirectory, DirectoryName[$InputFileName], 6],
            {}
        ],
        NestList[ParentDirectory, Directory[], 6]
    ];
    root = SelectFirst[
        candidates,
        DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed
    ];
    If[root === $Failed,
        Echo["ERROR: cannot locate TensorNetworks paclet root", "[symmetry-for-tn]"];
        Abort[]
    ];
    PacletDirectoryLoad[FileNameJoin[{root, "TensorNetworks"}]];
    Needs["Wolfram`TensorNetworks`"];
    Needs["Wolfram`TensorNetworks`Symmetry`"];
];


(* ============================================================ *)
(* Helpers                                                       *)
(* ============================================================ *)

ClearAll[tol, schurDim, flattenProjector, irrepRank, contentSum,
    standardTableaux, removableCorners, shrinkAt];
tol = 10^-10;

(* Removable corners of a partition (cells whose removal leaves a partition). *)
removableCorners[par_List] := Select[
    Table[{i, par[[i]]}, {i, Length[par]}],
    Function[c, c[[1]] == Length[par] || par[[c[[1]] + 1]] < c[[2]]]
];

shrinkAt[par_List, {i_, _}] := DeleteCases[MapAt[# - 1 &, par, i], 0];

(* All standard Young tableaux of shape par, as rows-of-entries. *)
standardTableaux[{}] = {{}};
standardTableaux[par_List] := standardTableaux[par] = Module[{n = Total[par]},
    Join @@ Map[
        Function[c,
            Map[
                Function[T,
                    Module[{rows = T},
                        While[Length[rows] < c[[1]], AppendTo[rows, {}]];
                        ReplacePart[rows, c[[1]] -> Append[rows[[c[[1]]]], n]]
                    ]
                ],
                standardTableaux[shrinkAt[par, c]]
            ]
        ],
        removableCorners[par]
    ]
];

(* Weyl dimension of the GL(d) irrep labelled by partition par. *)
schurDim[par_List, d_Integer] := Module[{hooks},
    hooks = HookLengths[par];
    Product[
        Product[(d + j - i)/hooks[[i, j]], {j, par[[i]]}],
        {i, Length[par]}
    ]
];

(* Sum of contents Sum_{(i,j) in par}(j - i). Equals the eigenvalue of the
   sum-of-all-transpositions in S_n on the irrep V_par. *)
contentSum[par_List] :=
    Total @ Flatten @ Table[j - i, {i, Length[par]}, {j, par[[i]]}];

(* d^n x d^n matrix realisation of the projector
       Sum_{T in tableaux} YoungProject[*, YoungTableau[T]]
   acting on V^{(x)n}. Image rank = dimension of the corresponding S_n
   isotypic component in V^{(x)n}. *)
flattenProjector[tableaux_List, d_Integer, n_Integer] := Module[
    {dims, idxList, basisTensors, projected},
    dims = ConstantArray[d, n];
    idxList = Tuples[Range[d], n];
    basisTensors = Map[
        Normal @ SparseArray[# -> 1, dims] &,
        idxList
    ];
    projected = Map[
        Function[T,
            Flatten @ Total[
                Function[t, YoungProject[T, YoungTableau[t]]] /@ tableaux
            ]
        ],
        basisTensors
    ];
    Transpose @ projected
];

irrepRank[tableaux_List, d_Integer, n_Integer] :=
    MatrixRank @ flattenProjector[tableaux, d, n];


(* ============================================================ *)
(* Example 1.  V (x) V -- the simplest TN edge                  *)
(* ============================================================ *)

(* Schur-Weyl on a single bond:  V (x) V = Sym^2(V) (+) Anti^2(V).
   The TWO partitions of 2 -- {2} and {1,1} -- exhaust the tensor square. *)

ex1 = Module[{d, T, Psym, Pant, completeness, antiTraceFree, symDim, antiDim},
    d = 3;
    SeedRandom[2026];
    T = RandomReal[{-1, 1}, {d, d}];
    Psym = YoungProject[T, YoungTableau[{{1, 2}}]];
    Pant = YoungProject[T, YoungTableau[{{1}, {2}}]];

    completeness  = Max[Abs[Flatten[Psym + Pant - T]]];
    antiTraceFree = Max[Abs[Diagonal[Pant]]];

    symDim  = irrepRank[{{{1, 2}}}, d, 2];
    antiDim = irrepRank[{{{1}, {2}}}, d, 2];

    <|
        "completeness"     -> completeness < tol,
        "antiTraceFree"    -> antiTraceFree < tol,
        "symDim"           -> symDim,
        "expectedSymDim"   -> d (d + 1)/2,
        "antiDim"          -> antiDim,
        "expectedAntiDim"  -> d (d - 1)/2
    |>
];


(* ============================================================ *)
(* Example 2.  V (x) V (x) V Schur-Weyl + sum-of-pair-swaps      *)
(* ============================================================ *)

(* On rank-3 tensors the S_3 irrep projector for shape lambda is the sum
   over ALL STANDARD TABLEAUX of that shape:
       E_{3}     = p_{{{1,2,3}}}                                  (d_lambda = 1)
       E_{2,1}   = p_{{{1,2},{3}}} + p_{{{1,3},{2}}}              (d_lambda = 2)
       E_{1,1,1} = p_{{{1},{2},{3}}}                              (d_lambda = 1)
   They sum to the identity on V^{(x)3}.

   The sum H = P_{12} + P_{13} + P_{23} of pair-swaps is a CLASS FUNCTION
   of S_3, so it commutes with every Young projector and is constant on
   each irrep block.  Its eigenvalue on irrep lambda is the SUM OF
   CONTENTS: {3} -> +3, {2,1} -> 0, {1,1,1} -> -3. *)

ex2 = Module[
    {d, T, e3, e21, e111, blockSum, antiZeroD2,
     expectedSym, expectedMix, expectedAnti,
     symRank, mixRank, antiRank,
     applySwap, swapMat, Hmat, evalsSorted, expectedEvals},

    d = 2;
    SeedRandom[7];
    T = RandomReal[{-1, 1}, {d, d, d}];

    e3   = YoungProject[T, YoungTableau[{{1, 2, 3}}]];
    e21  = YoungProject[T, YoungTableau[{{1, 2}, {3}}]] +
           YoungProject[T, YoungTableau[{{1, 3}, {2}}]];
    e111 = YoungProject[T, YoungTableau[{{1}, {2}, {3}}]];

    blockSum   = Max[Abs[Flatten[e3 + e21 + e111 - T]]];
    antiZeroD2 = Max[Abs[Flatten[e111]]];

    expectedSym  = TableauDimension[{3}]       * schurDim[{3}, d];
    expectedMix  = TableauDimension[{2, 1}]    * schurDim[{2, 1}, d];
    expectedAnti = TableauDimension[{1, 1, 1}] * schurDim[{1, 1, 1}, d];

    symRank  = irrepRank[{{{1, 2, 3}}}, d, 3];
    mixRank  = irrepRank[{{{1, 2}, {3}}, {{1, 3}, {2}}}, d, 3];
    antiRank = irrepRank[{{{1}, {2}, {3}}}, d, 3];

    (* H = P_{12} + P_{13} + P_{23} as a d^3 x d^3 matrix *)
    applySwap[a_, b_] := Module[{perm = Range[3]},
        perm[[{a, b}]] = perm[[{b, a}]];
        ArrayReshape[
            Transpose[
                Normal @ SparseArray[
                    Flatten[Table[{i, j, k, i, j, k} -> 1,
                        {i, d}, {j, d}, {k, d}], 2],
                    {d, d, d, d, d, d}
                ],
                Join[perm, {4, 5, 6}]
            ],
            {d^3, d^3}
        ]
    ];
    Hmat = applySwap[1, 2] + applySwap[1, 3] + applySwap[2, 3];
    evalsSorted = Sort[Eigenvalues[Hmat], Greater];
    expectedEvals = Sort[
        Flatten @ {
            ConstantArray[contentSum[{3}],       expectedSym],
            ConstantArray[contentSum[{2, 1}],    expectedMix],
            ConstantArray[contentSum[{1, 1, 1}], expectedAnti]
        },
        Greater
    ];

    <|
        "blockSum"           -> blockSum < tol,
        "antiZeroD2"         -> antiZeroD2 < tol,
        "symRank"            -> symRank,
        "expectedSym"        -> expectedSym,
        "mixRank"            -> mixRank,
        "expectedMix"        -> expectedMix,
        "antiRank"           -> antiRank,
        "expectedAnti"       -> expectedAnti,
        "Heigenvalues"       -> evalsSorted,
        "expectedHEigenvals" -> expectedEvals,
        "spectrumMatches"    -> Max[Abs[evalsSorted - expectedEvals]] < tol
    |>
];


(* ============================================================ *)
(* Example 3.  Riemann tensor as a TN node                       *)
(* ============================================================ *)

(* The (2,2) Young tableau {{1,3},{2,4}} carries the full Riemann
   symmetry, INCLUDING the first Bianchi identity. Project a generic
   rank-4 tensor onto this irrep, then contract via the TN primitive
   TensorContract: the Ricci tensor R^a{}_{bad} comes out symmetric
   automatically. *)

ex3 = Module[{T0, R, antiPair12, antiPair34, pairSwap, bianchi, Ric, ricciSym, scalar},
    SeedRandom[42];
    T0 = RandomReal[{-1, 1}, {4, 4, 4, 4}];
    R = YoungProject[T0, YoungTableau[{{1, 3}, {2, 4}}]];

    antiPair12 = Max[Abs[Flatten[R + Transpose[R, {2, 1, 3, 4}]]]];
    antiPair34 = Max[Abs[Flatten[R + Transpose[R, {1, 2, 4, 3}]]]];
    pairSwap   = Max[Abs[Flatten[R - Transpose[R, {3, 4, 1, 2}]]]];
    bianchi    = Max[Abs[Flatten[
        R + Transpose[R, {1, 3, 4, 2}] + Transpose[R, {1, 4, 2, 3}]
    ]]];

    Ric = TensorContract[R, {{1, 3}}];
    ricciSym = Max[Abs[Flatten[Ric - Transpose[Ric]]]];
    scalar = Tr[Ric];

    <|
        "antiPair12"  -> antiPair12 < tol,
        "antiPair34"  -> antiPair34 < tol,
        "pairSwap"    -> pairSwap < tol,
        "bianchi"     -> bianchi < tol,
        "ricciSym"    -> ricciSym < tol,
        "ricciScalar" -> scalar
    |>
];


(* ============================================================ *)
(* Example 4.  On-site irreps predict MPS/MPO bond multiplicity  *)
(* ============================================================ *)

(* For a symmetry-resolved MPS on a chain of d-dim sites, the isotypic
   block of irrep lambda has dimension
       m_lambda = TableauDimension[lambda] * schurDim[lambda, d].
   Verify on V^{(x)n} for several (n, d). Enumerate STANDARD tableaux
   of each shape via the built-in YoungTableaux. *)

ex4 = Module[{cases},
    cases = {
        <|"n" -> 2, "d" -> 2|>,
        <|"n" -> 3, "d" -> 2|>,
        <|"n" -> 3, "d" -> 3|>,
        <|"n" -> 4, "d" -> 2|>
    };
    Map[
        Function[case,
            Module[{n, d, perShape},
                n = case["n"]; d = case["d"];
                perShape = Map[
                    Function[par,
                        <|
                            "partition"    -> par,
                            "schurWeylDim" -> TableauDimension[par] * schurDim[par, d],
                            "irrepRank"    -> irrepRank[standardTableaux[par], d, n]
                        |>
                    ],
                    IntegerPartitions[n]
                ];
                <|
                    "n"            -> n,
                    "d"            -> d,
                    "totalDim"     -> d^n,
                    "sumOfBlocks"  -> Total[#schurWeylDim & /@ perShape],
                    "perShape"     -> perShape
                |>
            ]
        ],
        cases
    ]
];


(* ============================================================ *)
(* Echo results so the script is informative when run            *)
(* ============================================================ *)

Echo[ex1, "Example 1 -- V (x) V Schur-Weyl"];
Echo[ex2, "Example 2 -- V (x) V (x) V Schur-Weyl + sum-of-swaps"];
Echo[ex3, "Example 3 -- Riemann tensor TN node"];
Echo[ex4, "Example 4 -- On-site irreps + bond multiplicity"];
