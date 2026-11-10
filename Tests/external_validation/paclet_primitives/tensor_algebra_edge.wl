(* Tests/external_validation/paclet_primitives/tensor_algebra_edge.wl

Edge cases of a contraction (trace, partial trace, an index shared by four tensors,
a scalar from two vectors, size-1 slots, reordered outputs, a pure relabeling), each
on complex random tensors with unequal dimensions and computed two ways: through
EinsteinSummation (activated) and through TensorNetworkContract. Both must equal the
explicit Sum or Table written out in the test. T2 is unchanged (EinsteinSummation only).

Sources:
- quimb tests/test_tensor_core.py:185-203 (multi-trace specific values)
- quimb tests/test_tensor_core.py:283-295 (squeeze size-1 dims, expected shape)
- quimb docs/tensor/tensor-design.ipynb, tensor-basics.ipynb (hyper-index sum, rank-N contraction)
- quimb tests/test_tensor_core.py:167-174 (named-axis transpose)
- ITensors tests/test_contract.jl (degenerate dim-1 cases)
*)

Module[{worktreeRoot},
    worktreeRoot = SelectFirst[
        NestList[ParentDirectory, Directory[], 12],
        FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed];
    If[worktreeRoot === $Failed,
        Print["[paclet-tensor-edge] cannot find worktree root from ", Directory[]];
        Abort[];
    ];
    Get[FileNameJoin[{worktreeRoot, "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]];
];
ClearValidationRecords[];

(* agreement to 1e-10 relative to the size of the reference, same dimensions *)
taeClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];
contract = ActivateTensors @* EinsteinSummation;

(* both routes: EinsteinSummation (activated) and TensorNetworkContract of the same network *)
taeBothRoutes[shapes_, out_, arrays_] := {
    contract[shapes -> out, arrays],
    TensorNetworkContract[TensorNetwork[arrays, shapes -> out]]
};

(* ----- T1: trace of a complex random 7 x 7 matrix equals Sum[m[[i, i]]].
   Source: quimb tests/test_tensor_core.py:185-203 (trace pair test pattern). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T1-trace",
    "quimb tests/test_tensor_core.py:185-203 (trace pair); explicit sum",
    VerificationTest[
        Module[{m, ref},
            m = BlockRandom[SeedRandom[601]; RandomComplex[{-1 - I, 1 + I}, {7, 7}]];
            ref = Sum[m[[i, i]], {i, 7}];
            AllTrue[taeBothRoutes[{{"i", "i"}}, {}, {m}], taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T1-trace"
    ]
];

(* ----- T2: Squeeze size-1 dimensions
   Source: quimb tests/test_tensor_core.py:283-295.
   t with shape (1,2,3,1,4) and indices "abcde"; after t.squeeze() the
   result has shape (2,3,4) and indices "bce". The paclet's analogue is
   to contract such that the size-1 indices are summed (which trivially
   keeps the data); the resulting shape is specific. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T2-squeeze-size1",
    "quimb tests/test_tensor_core.py:283-295 (squeeze)",
    VerificationTest[
        Module[{t, squeezed},
            SeedRandom[601];
            t = RandomReal[{-1, 1}, {1, 2, 3, 1, 4}];
            (* EinsteinSummation that "absorbs" the size-1 indices by treating
               them as scalar broadcast: contract a<->a (size 1, trace) and d<->d
               (size 1, trace). For size-1 indices, trace is identity. *)
            squeezed = contract[{{"a", "b", "c", "d", "e"}} -> {"b", "c", "e"}, {t}];
            Dimensions[squeezed] === {2, 3, 4} && ValidationClose[squeezed, t[[1, All, All, 1, All]], 1.*^-12]
        ],
        True,
        TestID -> "paclet-tensor-edge-T2-squeeze-size1"
    ]
];

(* ----- T3: one index x shared by four complex random matrices of different row
   dimensions, output in a permuted order: T[d, b, a, c] = Sum_x A[a,x] B[b,x] C[c,x] D[d,x].
   Source: quimb docs/tensor/tensor-design.ipynb (hyper-index sum pattern). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T3-hyper4",
    "quimb docs/tensor/tensor-design.ipynb (hyper-index sum pattern); explicit sum",
    VerificationTest[
        Module[{a, b, c, d, ref},
            {a, b, c, d} = BlockRandom[SeedRandom[603];
                RandomComplex[{-1 - I, 1 + I}, #] & /@ {{2, 3}, {4, 3}, {3, 3}, {2, 3}}];
            ref = Table[Sum[a[[ia, x]] b[[ib, x]] c[[ic, x]] d[[id, x]], {x, 3}], {id, 2}, {ib, 4}, {ia, 2}, {ic, 3}];
            AllTrue[
                taeBothRoutes[{{"a", "x"}, {"b", "x"}, {"c", "x"}, {"d", "x"}}, {"d", "b", "a", "c"}, {a, b, c, d}],
                taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T3-hyper4"
    ]
];

(* ----- T4: dot product of two different complex random vectors of length 11.
   Source: ITensors tests/test_contract.jl (vector contraction to a scalar). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T4-vector-dot",
    "ITensors tests/test_contract.jl (scalar from two vectors); explicit sum",
    VerificationTest[
        Module[{v, w, ref},
            {v, w} = BlockRandom[SeedRandom[604]; RandomComplex[{-1 - I, 1 + I}, {2, 11}]];
            ref = Sum[v[[i]] w[[i]], {i, 11}];
            AllTrue[taeBothRoutes[{{"i"}, {"i"}}, {}, {v, w}], taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T4-vector-dot"
    ]
];

(* ----- T5: partial trace of a complex random 3 x 4 x 3 tensor over its first and last
   slots: r[j] = Sum_i T[i, j, i].
   Source: ITensors tests/test_contract.jl (trace over a repeated index). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T5-partial-trace",
    "ITensors tests/test_contract.jl (repeated index); explicit sum",
    VerificationTest[
        Module[{t, ref},
            t = BlockRandom[SeedRandom[605]; RandomComplex[{-1 - I, 1 + I}, {3, 4, 3}]];
            ref = Table[Sum[t[[i, j, i]], {i, 3}], {j, 4}];
            AllTrue[taeBothRoutes[{{"i", "j", "i"}}, {"j"}, {t}], taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T5-partial-trace"
    ]
];

(* ----- T6: two complex random rank-4 tensors sharing two legs, output in an interleaved
   order: R[m, k, n, l] = Sum_{i,j} A[i,j,k,l] B[i,j,m,n].
   Source: quimb docs/tensor/tensor-basics.ipynb (general rank-N contraction). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T6-rank4-rank4-contract",
    "quimb docs/tensor/tensor-basics.ipynb (general rank-N contraction); explicit sum",
    VerificationTest[
        Module[{a, b, ref},
            {a, b} = BlockRandom[SeedRandom[606];
                RandomComplex[{-1 - I, 1 + I}, #] & /@ {{2, 3, 4, 5}, {2, 3, 6, 7}}];
            ref = Table[Sum[a[[i, j, k, l]] b[[i, j, m, n]], {i, 2}, {j, 3}], {m, 6}, {k, 4}, {n, 7}, {l, 5}];
            AllTrue[
                taeBothRoutes[{{"i", "j", "k", "l"}, {"i", "j", "m", "n"}}, {"m", "k", "n", "l"}, {a, b}],
                taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T6-rank4-rank4-contract"
    ]
];

(* ----- T7: a pure relabeling of one rank-6 tensor (no contraction) through both routes
   equals the explicitly built transposed array.
   Source: quimb tests/test_tensor_core.py:167-174 (named-axis transpose). *)
WithCapability[{"EinsteinSummation", "ActivateTensors", "TensorNetwork", "TensorNetworkContract"},
    "paclet-tensor-edge-T7-pure-transpose-shape",
    "quimb tests/test_tensor_core.py:167-174 (named-axis transpose); explicit table",
    VerificationTest[
        Module[{t, ref},
            t = BlockRandom[SeedRandom[613]; RandomComplex[{-1 - I, 1 + I}, {2, 3, 4, 5, 2, 2}]];
            ref = Table[t[[a, b, c, d, e, f]], {c, 4}, {d, 5}, {f, 2}, {e, 2}, {b, 3}, {a, 2}];
            AllTrue[
                taeBothRoutes[{{"a", "b", "c", "d", "e", "f"}}, {"c", "d", "f", "e", "b", "a"}, {t}],
                taeClose[#, ref] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T7-pure-transpose-shape"
    ]
];
