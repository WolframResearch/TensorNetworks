(* Tests/external_validation/paclet_fuzz/fuzz_tn_contract.wl

   Seeded sweeps for TensorNetworkContract on complex random tensors with unequal
   dimensions, every value checked against a reference computed here without the paclet:

   - fzcOracle: an explicit sum over every index assignment (any network, including
     indices shared by three tensors, repeated labels on one tensor and shared indices
     kept in the output);
   - fzcPairwise: tensors multiplied in by TensorProduct, each bond summed by
     TensorContract once both its ends are present (networks of plain bonds too large
     for the explicit sum);
   - dense state vectors and plain Dot for bra-ket sandwiches and for a real operand
     meeting a complex one.

   Outputs are requested in random order with at least three open legs where possible,
   so a misordered result is seen.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-contract] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];

(* ===================== Independent references ===================== *)

(* agreement to 1e-10 relative to the size of the reference, same dimensions *)
fzcClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];

fzcSizes[ts_, shapes_] := Association @ Catenate @ MapThread[Thread[#2 -> Dimensions[#1]] &, {ts, shapes}];
fzcEntry[ts_, shapes_, val_] := Times @@ MapThread[Extract[#1, Lookup[val, #2]] &, {ts, shapes}];
fzcOracle[ts_, shapes_, out_] := Block[{sd = fzcSizes[ts, shapes], internal, tuples, labels, sumAt},
    internal = Complement[DeleteDuplicates[Catenate[shapes]], out];
    tuples = Tuples[Range /@ Lookup[sd, internal]];
    labels = Join[out, internal];
    sumAt[o_List] := Total[fzcEntry[ts, shapes, AssociationThread[labels, Join[o, #]]] & /@ tuples];
    If[out === {}, sumAt[{}], Array[sumAt[{##}] &, Lookup[sd, out]]]
];

(* plain bonds only (each label on at most two slots): fold the tensors in one by one *)
fzcPairwise[ts_, shapes_, out_] := With[{
    final = Fold[
        Function[{acc, next}, With[{labels = Join[acc[[2]], next[[2]]]},
            With[{pairs = Values @ Select[PositionIndex[labels], Length[#] == 2 &]},
                {If[pairs === {}, TensorProduct[acc[[1]], next[[1]]], TensorContract[TensorProduct[acc[[1]], next[[1]]], pairs]],
                 Select[labels, Count[labels, #] == 1 &]}]]],
        {First[ts], First[shapes]},
        Transpose[{Rest[ts], Rest[shapes]}]]},
    If[out === {}, final[[1]], Transpose[final[[1]], Flatten[Position[out, #] & /@ final[[2]]]]]
];

(* seeded random connected network: spanning tree + extra bonds, indices shared by three
   tensors (some kept in the output), open legs; output in random order *)
fzcRandomNetwork[seed_, n_, extra_, hyper_, keptHyper_, open_, maxTotal_] := Module[{try = seed, net},
    While[True,
        net = BlockRandom[SeedRandom[try];
            Module[{legs = ConstantArray[{}, n], k = 0, sd = <||>, add, out = {}},
                add[label_, members_, d_] := (sd[label] = d; Scan[(legs[[#]] = Append[legs[[#]], label]) &, members]);
                Do[add["e" <> ToString[++k], {t, RandomInteger[{1, t - 1}]}, RandomInteger[{2, 4}]], {t, 2, n}];
                Do[add["e" <> ToString[++k], RandomSample[Range[n], 2], RandomInteger[{2, 4}]], {extra}];
                Do[add["h" <> ToString[m], RandomSample[Range[n], 3], RandomInteger[{2, 3}]];
                    If[m <= keptHyper, AppendTo[out, "h" <> ToString[m]]], {m, hyper}];
                Do[add["o" <> ToString[m], {RandomInteger[{1, n}]}, RandomInteger[{2, 3}]]; AppendTo[out, "o" <> ToString[m]], {m, open}];
                {RandomSample[#] & /@ legs, RandomSample[out], sd}]];
        If[Times @@ Values[net[[3]]] <= maxTotal, Return[net]];
        try += 1000]
];

fzcComplex[{shapes_, out_, sd_}, seed_] := BlockRandom[SeedRandom[seed];
    RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];

(* ----- F-CONTRACT-1: 24 random networks of 3 to 6 tensors with 3 open legs in random
   order, half also with an index on three tensors: the default contraction equals the
   explicit index sum. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-1-random-networks",
    "explicit index sum; 24 seeded networks",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, n, h}, {n, 3, 6}, {seed, 3}, {h, 0, 1}], 2],
            Function[spec, With[{net = fzcRandomNetwork[1000 spec[[1]] + 10 spec[[2]] + spec[[3]], spec[[2]], 1, spec[[3]], 0, 3, 40000]},
                With[{ts = fzcComplex[net, spec[[1]]]},
                    fzcClose[TensorNetworkContract[TensorNetwork[ts, net[[1]] -> net[[2]]]], fzcOracle[ts, net[[1]], net[[2]]]]]]]],
        True,
        TestID -> "paclet-fuzz-contract-1-random-networks"
    ]
];

(* ----- F-CONTRACT-2: <phi|psi> for two different complex random MPS of 3 to 6 sites with
   random bonds 1 to 4 and physical dimensions 2 or 3: the bra-ket network (bra tensors
   conjugated) equals Conjugate[phi] . psi of the dense vectors, each the explicit sum
   over its bonds. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-2-mps-overlap-dense",
    "dense state vectors; 8 seeded pairs",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, len}, {len, 3, 6}, {seed, 2}], 1],
            Function[spec, BlockRandom[SeedRandom[2000 spec[[1]] + spec[[2]]];
                Module[{len = spec[[2]], phys, bonds, ketLegs, braLegs, sd, psi, phi, dense, physOut},
                    phys = RandomInteger[{2, 3}, len];
                    bonds = RandomInteger[{1, 4}, len - 1];
                    ketLegs = Table[DeleteCases[{If[k > 1, "b" <> ToString[k - 1], Nothing], If[k < len, "b" <> ToString[k], Nothing], "p" <> ToString[k]}, Nothing], {k, len}];
                    braLegs = ketLegs /. s_String /; StringStartsQ[s, "b"] :> "c" <> StringDrop[s, 1];
                    sd = Join[AssociationThread["b" <> ToString[#] & /@ Range[len - 1], bonds], AssociationThread["p" <> ToString[#] & /@ Range[len], phys]];
                    {psi, phi} = Table[RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ ketLegs, 2];
                    physOut = "p" <> ToString[#] & /@ Range[len];
                    dense[t_] := Flatten @ fzcOracle[t, ketLegs, physOut];
                    fzcClose[
                        TensorNetworkContract[TensorNetwork[Join[psi, Conjugate[phi]], Join[ketLegs, braLegs] -> {}]],
                        Conjugate[dense[phi]] . dense[psi]]]]]],
        True,
        TestID -> "paclet-fuzz-contract-2-mps-overlap-dense"
    ]
];

(* ----- F-CONTRACT-3: shared indices kept in the output (batch steps), with blocks above
   16 entries: three tensors A[b,i,s], B[b,s,k], C[b,k,j] sharing b, output (j, b, i), as
   dense and as sparse arrays; and 8 random networks keeping one shared index of three
   tensors in the output. All equal the explicit index sum. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-3-batch-steps",
    "explicit index sum",
    VerificationTest[
        Module[{shapes, out, ts, ref, sparse, nets},
            shapes = {{"b", "i", "s"}, {"b", "s", "k"}, {"b", "k", "j"}};
            out = {"j", "b", "i"};
            ts = BlockRandom[SeedRandom[3001]; RandomComplex[{-1 - I, 1 + I}, #] & /@ {{3, 4, 5}, {3, 5, 6}, {3, 6, 2}}];
            ref = fzcOracle[ts, shapes, out];
            sparse = BlockRandom[SeedRandom[3002]; SparseArray[RandomChoice[{0.6, 0.4} -> {0, 1}, Dimensions[#]] #] & /@ ts];
            nets = Table[fzcRandomNetwork[3100 + seed, 4, 1, 1, 1, 2, 40000], {seed, 8}];
            And[
                fzcClose[TensorNetworkContract[TensorNetwork[ts, shapes -> out]], ref],
                fzcClose[Normal @ TensorNetworkContract[TensorNetwork[sparse, shapes -> out]], fzcOracle[Normal /@ sparse, shapes, out]],
                AllTrue[Range[8], With[{t = fzcComplex[nets[[#]], #]},
                    fzcClose[TensorNetworkContract[TensorNetwork[t, nets[[#, 1]] -> nets[[#, 2]]]], fzcOracle[t, nets[[#, 1]], nets[[#, 2]]]]] &]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-contract-3-batch-steps"
    ]
];

(* ----- F-CONTRACT-4: traces and diagonals inside one tensor and across two:
   T[i,j,i,k] -> (k, j); T[i,i,i] -> (i); and A[i,j,i] B[j,k,l] -> (l, k), complex random,
   against the explicit index sum. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-4-traces-and-diagonals",
    "explicit index sum",
    VerificationTest[
        Module[{t4, t3, a, b},
            {t4, t3, a, b} = BlockRandom[SeedRandom[4001];
                RandomComplex[{-1 - I, 1 + I}, #] & /@ {{3, 4, 3, 2}, {4, 4, 4}, {2, 5, 2}, {5, 3, 4}}];
            And[
                fzcClose[TensorNetworkContract[TensorNetwork[{t4}, {{"i", "j", "i", "k"}} -> {"k", "j"}]],
                    Table[Sum[t4[[i, j, i, k]], {i, 3}], {k, 2}, {j, 4}]],
                fzcClose[TensorNetworkContract[TensorNetwork[{t3}, {{"i", "i", "i"}} -> {"i"}]],
                    Table[t3[[i, i, i]], {i, 4}]],
                fzcClose[TensorNetworkContract[TensorNetwork[{a, b}, {{"i", "j", "i"}, {"j", "k", "l"}} -> {"l", "k"}]],
                    Table[Sum[a[[i, j, i]] b[[j, k, l]], {i, 2}, {j, 5}], {l, 4}, {k, 3}]]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-contract-4-traces-and-diagonals"
    ]
];

(* ----- F-CONTRACT-5: 2-tensor edge case: explicit dot product.
   T1[i,j] * T2[i,j] summed over both indices = scalar = Total[Flatten[T1 * T2]]. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-5-edge-2tensor-dot",
    "<T1, T2> via TN === Total[Flatten[T1 T2]] for random pair",
    VerificationTest[
        AllTrue[
            Table[
                BlockRandom[SeedRandom[seed];
                    Module[{T1, T2, tn, r, expected},
                        T1 = RandomReal[{-1, 1}, {3, 4}];
                        T2 = RandomReal[{-1, 1}, {3, 4}];
                        tn = TensorNetwork[{T1, T2}, {{"i", "j"}, {"i", "j"}}];
                        r = TensorNetworkContract[tn];
                        expected = Total[Flatten[T1 * T2]];
                        ValidationClose[r, expected, 1.*^-12]
                    ]
                ],
                {seed, 1, 5}
            ],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-contract-5-edge-2tensor-dot"
    ]
];

(* ----- F-CONTRACT-6: a 3x3 PEPS of complex random tensors (bond 2, physical 2) with its
   nine physical legs requested in reversed order, and its closed norm network
   <psi|psi>: equal to the pairwise TensorProduct/TensorContract reference, within
   10 seconds. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-6-peps",
    "pairwise TensorContract reference; timing budget",
    VerificationTest[
        WithBudget[10.,
            Module[{site, shapes, ts, out, braShapes},
                site[r_, c_] := ToString[r] <> ToString[c];
                shapes = Flatten[Table[
                    Join[
                        If[c < 3, {"h" <> site[r, c]}, {}], If[c > 1, {"h" <> site[r, c - 1]}, {}],
                        If[r < 3, {"v" <> site[r, c]}, {}], If[r > 1, {"v" <> site[r - 1, c]}, {}],
                        {"p" <> site[r, c]}],
                    {r, 3}, {c, 3}], 1];
                ts = BlockRandom[SeedRandom[6001]; RandomComplex[{-1 - I, 1 + I}, ConstantArray[2, Length[#]]] & /@ shapes];
                out = Reverse[Last /@ shapes];
                braShapes = shapes /. s_String /; ! StringStartsQ[s, "p"] :> s <> "x";
                fzcClose[TensorNetworkContract[TensorNetwork[ts, shapes -> out]], fzcPairwise[ts, shapes, out]] &&
                    fzcClose[TensorNetworkContract[TensorNetwork[Join[ts, Conjugate[ts]], Join[shapes, braShapes] -> {}]],
                        fzcPairwise[Join[ts, Conjugate[ts]], Join[shapes, braShapes], {}]]
            ]
        ],
        True,
        TestID -> "paclet-fuzz-contract-6-peps"
    ]
];

(* ----- F-CONTRACT-7: a real operand meeting a complex one with a long summed index
   (16 to 64): A[i,s] B[s,k] C[k,j] with A real, B complex, C real, both orientations,
   against plain Dot. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-contract-7-real-times-complex",
    "plain Dot",
    VerificationTest[
        AllTrue[{16, 40, 64},
            Function[len, Module[{a, b, c},
                {a, b, c} = BlockRandom[SeedRandom[7000 + len];
                    {RandomReal[{-1, 1}, {7, len}], RandomComplex[{-1 - I, 1 + I}, {len, len}], RandomReal[{-1, 1}, {len, 3}]}];
                fzcClose[TensorNetworkContract[TensorNetwork[{a, b, c}, {{"i", "s"}, {"s", "k"}, {"k", "j"}} -> {"j", "i"}]],
                    Transpose[a . b . c]] &&
                    fzcClose[TensorNetworkContract[TensorNetwork[{b, a}, {{"s", "k"}, {"i", "s"}} -> {"i", "k"}]], a . b] &&
                    fzcClose[TensorNetworkContract[TensorNetwork[{c, b}, {{"k", "j"}, {"s", "k"}} -> {"s", "j"}]], b . c]]]],
        True,
        TestID -> "paclet-fuzz-contract-7-real-times-complex"
    ]
];
