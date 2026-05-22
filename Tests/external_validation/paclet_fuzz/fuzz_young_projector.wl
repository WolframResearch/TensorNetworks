(* Tests/external_validation/paclet_fuzz/fuzz_young_projector.wl

   Property-based fuzz layer for YoungProject and YoungSymmetrize. The core
   identities — idempotency P^2 = P and inter-shape orthogonality P_lambda
   . P_mu = 0 — must hold across all partitions of n in {2,3,4} on random
   integer tensors. Plus an edge battery and a timing sentinel.

   Uses exact integer arithmetic so === comparisons are tight (no floating
   round-off slack).
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-yp] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];


(* Build a random rank-n tensor with integer entries (exact arithmetic). *)
randTensor[n_, seed_, dim_:3, range_:{-4, 4}] := BlockRandom[
    SeedRandom[seed];
    RandomInteger[range, ConstantArray[dim, n]]
];


(* ----- F-YP-1: idempotency P^2 = P for all partitions of n in {2,3,4} ----- *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-1-idempotency",
    "P_lambda^2 = P_lambda for every partition of n in {2,3,4} on 3 random tensors each",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                Module[{partitions, tab, T, once, twice},
                    partitions = IntegerPartitions[n];
                    Map[
                        Function[partition,
                            tab = YoungTableau[partition];
                            Table[
                                T = randTensor[n, 1000 n + 100 seed + Hash[partition]];
                                once = YoungProject[T, tab];
                                twice = YoungProject[once, tab];
                                twice === once
                            ,
                                {seed, 1, 3}
                            ]
                        ],
                        partitions
                    ]
                ],
                {n, 2, 4}
            ], 3],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-yp-1-idempotency"
    ]
];


(* ----- F-YP-2: orthogonality P_lambda . P_mu = 0 for distinct shapes ----- *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-2-orthogonality",
    "P_lambda(P_mu(T)) = 0 for distinct lambda, mu in partitions of n in {3,4}",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                Module[{parts, pairs, T, p1, p2},
                    parts = IntegerPartitions[n];
                    pairs = Subsets[parts, {2}];
                    T = randTensor[n, n * 1009 + 7];
                    Map[
                        Function[pair,
                            p1 = YoungProject[T, YoungTableau[First[pair]]];
                            p2 = YoungProject[p1, YoungTableau[Last[pair]]];
                            Max[Abs[Flatten[p2]]] === 0
                        ],
                        pairs
                    ]
                ],
                {n, 3, 4}
            ], 1],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-yp-2-orthogonality"
    ]
];


(* ----- F-YP-3: n=2 completeness — P_{2} + P_{1,1} = identity on V (x) V.
   Schur-Weyl rank-2 decomposition: only two partitions, so sum is identity. *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-3-rank2-completeness",
    "P_{2}(T) + P_{1,1}(T) = T for 10 random rank-2 tensors at varied dim",
    VerificationTest[
        AllTrue[
            Flatten[Table[
                BlockRandom[SeedRandom[seed];
                    Module[{T, pSym, pAnti},
                        T = RandomInteger[{-5, 5}, {dim, dim}];
                        pSym = YoungProject[T, YoungTableau[{{1, 2}}]];
                        pAnti = YoungProject[T, YoungTableau[{{1}, {2}}]];
                        (pSym + pAnti) === T
                    ]
                ],
                {dim, {2, 3, 4, 5}}, {seed, 1, 3}
            ], 1],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-yp-3-rank2-completeness"
    ]
];


(* ----- F-YP-4: fully-symmetric tableau edge.
   For 1-row tableau {{1,2,...,n}}, P maps to S^n(V) — the fully symmetric
   subspace. Property: P(T) is invariant under any permutation of indices. *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-4-fully-sym",
    "YoungProject onto 1-row tableau gives a tensor invariant under index perm",
    VerificationTest[
        Module[{T, sym, perms, results},
            T = randTensor[3, 271, 3];
            sym = YoungProject[T, YoungTableau[{{1, 2, 3}}]];
            perms = Permutations[{1, 2, 3}];
            results = Table[Transpose[sym, p] === sym, {p, perms}];
            AllTrue[results, TrueQ]
        ],
        True,
        TestID -> "paclet-fuzz-yp-4-fully-sym"
    ]
];


(* ----- F-YP-5: fully-antisymmetric tableau edge.
   For 1-column tableau, P maps to Lambda^n(V). Property: P(T) picks up
   sgn(perm) under any permutation of indices. *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-5-fully-antisym",
    "YoungProject onto 1-column tableau gives a tensor that transforms with sgn under perm",
    VerificationTest[
        Module[{T, anti, perms, results},
            T = randTensor[3, 353, 3];
            anti = YoungProject[T, YoungTableau[{{1}, {2}, {3}}]];
            perms = Permutations[{1, 2, 3}];
            results = Table[Transpose[anti, p] === Signature[p] * anti, {p, perms}];
            AllTrue[results, TrueQ]
        ],
        True,
        TestID -> "paclet-fuzz-yp-5-fully-antisym"
    ]
];


(* ----- F-YP-6: timing sentinel —
   rank-5 partition {3, 2} projection within budget. *)
WithCapability[{"YoungProject", "YoungTableau"},
    "paclet-fuzz-yp-6-timing",
    "Rank-5 {3,2} projection on dim-3 tensor within 10s",
    VerificationTest[
        WithBudget[10.,
            Module[{T, tab, result, again},
                T = randTensor[5, 911, 3];
                tab = YoungTableau[{3, 2}];
                result = YoungProject[T, tab];
                again = YoungProject[result, tab];
                again === result
            ]
        ],
        True,
        TestID -> "paclet-fuzz-yp-6-timing"
    ]
];
