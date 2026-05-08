(* Tests/external_parity/tier1a_tensor_algebra.wl

Tier-1A: pure tensor-algebra parity tests. Pulled from quimb tests/test_tensor_core.py
and ITensors.jl test/base/test_contract.jl. Deterministic, exact-numeric, only need
EinsteinSummation + ActivateTensors + TensorNetwork primitives.

Convention: EinsteinSummation returns an Inactive[] form; wrap in ActivateTensors
to obtain the numeric contraction.
*)

(* Robust helper loader. *)
Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "Helpers", "ParityHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_parity", "Helpers", "ParityHelpers.wl"}],
        FileNameJoin[{Directory[], "external_parity", "Helpers", "ParityHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ParityHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[tier1a] ERROR: cannot locate ParityHelpers.wl. Tried: ", candidates];
        Abort[];
    ];
    Get[found];
];
ClearParityRecords[];

contract = ActivateTensors @* EinsteinSummation;

(* ----- A1: complex tensor conjugate (quimb test_tensor_core.py:36-52) ----- *)
WithCapability[{}, "tier1a-A1-conjugate",
    "quimb tests/test_tensor/test_tensor_core.py:36-52",
    VerificationTest[
        Module[{a},
            SeedRandom[2];
            a = RandomComplex[{-1 - I, 1 + I}, {2, 3, 4}];
            Conjugate[Conjugate[a]] === a && Dimensions[a] == {2, 3, 4}
        ],
        True,
        TestID -> "tier1a-A1-conjugate"
    ]
];

(* ----- A2: triple contraction (quimb test_tensor_core.py:421-430) -----
   a[i,j,k] (2,3,4), b[j,k,l] (3,4,5), c[l,i,m] (5,2,6) -> result[m] (6,) *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A2-triple-contract",
    "quimb tests/test_tensor/test_tensor_core.py:421-430",
    VerificationTest[
        Module[{a, b, c, result, expected},
            SeedRandom[42];
            a = RandomReal[{-1, 1}, {2, 3, 4}];
            b = RandomReal[{-1, 1}, {3, 4, 5}];
            c = RandomReal[{-1, 1}, {5, 2, 6}];
            result = contract[
                {{"i", "j", "k"}, {"j", "k", "l"}, {"l", "i", "m"}} -> {"m"},
                {a, b, c}
            ];
            expected = Table[
                Sum[a[[i, j, k]] b[[j, k, l]] c[[l, i, m]],
                    {i, 2}, {j, 3}, {k, 4}, {l, 5}],
                {m, 6}];
            Dimensions[result] === {6} && ParityClose[result, expected, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A2-triple-contract"
    ]
];

(* ----- A3: hyper-index sum (quimb tensor-design.ipynb)
   T[a,b,c] = sum_x I[a,x] I[b,x] I[c,x] = delta(a,b,c). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A3-hyper-index",
    "quimb docs/tensor/tensor-design.ipynb",
    VerificationTest[
        Module[{id, result, expected},
            id = N @ IdentityMatrix[2];
            result = contract[
                {{"a", "x"}, {"b", "x"}, {"c", "x"}} -> {"a", "b", "c"},
                {id, id, id}
            ];
            expected = Table[If[a === b && b === c, 1.0, 0.0], {a, 2}, {b, 2}, {c, 2}];
            ParityClose[result, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A3-hyper-index"
    ]
];

(* ----- A4: trace pair of indices (quimb test_tensor_core.py:185-203)
   t[i,j,i] -> sum_i t[i,j,i] for each j. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A4-trace-pair",
    "quimb tests/test_tensor/test_tensor_core.py:185-203",
    VerificationTest[
        Module[{t, traced, expected},
            SeedRandom[7];
            t = RandomReal[{-1, 1}, {3, 3, 3}];
            traced = contract[{{"i", "j", "i"}} -> {"j"}, {t}];
            expected = Table[Sum[t[[i, j, i]], {i, 3}], {j, 3}];
            ParityClose[traced, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A4-trace-pair"
    ]
];

(* ----- A5: sum-reduce one index (quimb test_tensor_core.py:213-226)
   t[a,b,c] (2,3,4); sum_a -> (3,4). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A5-sum-reduce",
    "quimb tests/test_tensor/test_tensor_core.py:213-226",
    VerificationTest[
        Module[{t, reduced, expected},
            SeedRandom[11];
            t = RandomReal[{-1, 1}, {2, 3, 4}];
            reduced = contract[{{"a", "b", "c"}} -> {"b", "c"}, {t}];
            expected = Total[t, {1}];
            Dimensions[reduced] === {3, 4} && ParityClose[reduced, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A5-sum-reduce"
    ]
];

(* ----- A6: vector reduce — single-index inner product (quimb test_tensor_core.py:228-234)
   einsum("abc,b->ac", t, g). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A6-vector-reduce",
    "quimb tests/test_tensor/test_tensor_core.py:228-234",
    VerificationTest[
        Module[{t, g, reduced, expected},
            SeedRandom[13];
            t = RandomReal[{-1, 1}, {2, 3, 4}];
            g = RandomReal[{-1, 1}, {3}];
            reduced = contract[{{"a", "b", "c"}, {"b"}} -> {"a", "c"}, {t, g}];
            expected = Table[Sum[t[[a, b, c]] g[[b]], {b, 3}], {a, 2}, {c, 4}];
            Dimensions[reduced] === {2, 4} && ParityClose[reduced, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A6-vector-reduce"
    ]
];

(* ----- A7: matrix * matrix (ITensors test_contract.jl, GEMM)
   einsum("ik,kj->ij", A, B) == A.B *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A7-gemm",
    "ITensors test/base/test_contract.jl:7-150 (GEMM)",
    VerificationTest[
        Module[{a, b, c, expected},
            SeedRandom[17];
            a = RandomReal[{-1, 1}, {3, 4}];
            b = RandomReal[{-1, 1}, {4, 5}];
            c = contract[{{"i", "k"}, {"k", "j"}} -> {"i", "j"}, {a, b}];
            expected = a . b;
            Dimensions[c] === {3, 5} && ParityClose[c, expected, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A7-gemm"
    ]
];

(* ----- A8: outer product (ITensors test_contract.jl, vector outer product)
   einsum("i,j->ij", v, w) == Outer[Times, v, w] *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A8-outer",
    "ITensors test/base/test_contract.jl:7-150 (outer product)",
    VerificationTest[
        Module[{v, w, c, expected},
            SeedRandom[19];
            v = RandomReal[{-1, 1}, {3}];
            w = RandomReal[{-1, 1}, {4}];
            c = contract[{{"i"}, {"j"}} -> {"i", "j"}, {v, w}];
            expected = Outer[Times, v, w];
            Dimensions[c] === {3, 4} && ParityClose[c, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A8-outer"
    ]
];

(* ----- A9: vector dot vector (ITensors test_contract.jl)
   einsum("i,i->", v, w) == v.w *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A9-dot",
    "ITensors test/base/test_contract.jl:7-150 (vᵀv scalar)",
    VerificationTest[
        Module[{v, w, c, expected},
            SeedRandom[23];
            v = RandomReal[{-1, 1}, {5}];
            w = RandomReal[{-1, 1}, {5}];
            c = contract[{{"i"}, {"i"}} -> {}, {v, w}];
            expected = v . w;
            ParityClose[c, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A9-dot"
    ]
];

(* ----- A10: 4-tensor closed network -> trace
   t1[a,b], t2[b,c], t3[c,d], t4[d,a] => Tr[t1.t2.t3.t4] *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"}, "tier1a-A10-closed4",
    "cotengra docs/basics.ipynb (closed-network variant)",
    VerificationTest[
        Module[{tn, result, expected, t1, t2, t3, t4},
            SeedRandom[29];
            t1 = RandomReal[{-1, 1}, {3, 4}];
            t2 = RandomReal[{-1, 1}, {4, 5}];
            t3 = RandomReal[{-1, 1}, {5, 6}];
            t4 = RandomReal[{-1, 1}, {6, 3}];
            tn = TensorNetwork[
                {t1, t2, t3, t4},
                {{"a", "b"}, {"b", "c"}, {"c", "d"}, {"d", "a"}}
            ];
            result = TensorNetworkContract[tn];
            expected = Tr[t1 . t2 . t3 . t4];
            ParityClose[result, expected, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A10-closed4"
    ]
];

(* ----- A11: Frobenius norm (quimb tensor-basics.ipynb)
   ||T||^2 = sum_ij T_ij conj(T_ij) *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A11-frobenius",
    "quimb docs/tensor/tensor-basics.ipynb (Frobenius via tn.H @ tn)",
    VerificationTest[
        Module[{t, sq, expected},
            SeedRandom[31];
            t = RandomComplex[{-1 - I, 1 + I}, {3, 4}];
            sq = contract[{{"i", "j"}, {"i", "j"}} -> {}, {Conjugate[t], t}];
            expected = Total[Abs[Flatten[t]]^2];
            ParityClose[Re[sq], expected, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A11-frobenius"
    ]
];

(* ----- A12: multi-index trace (quimb test_tensor_core.py:205-211)
   T[a,b,c,d,e] (3,3,3,3,3); trace([a,c],[e,b]) = sum over (a=e) and (c=b). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A12-multi-trace",
    "quimb tests/test_tensor/test_tensor_core.py:205-211",
    VerificationTest[
        Module[{t, traced, expected},
            SeedRandom[37];
            t = RandomReal[{-1, 1}, {3, 3, 3, 3, 3}];
            (* Trace pairs (a,e) and (c,b) -> result indexed by d *)
            traced = contract[{{"a", "b", "c", "b", "a"}} -> {"d"}, {t}];
            (* Wait — confusion. Let me rebuild more carefully.
               quimb's t.trace(["a","c"],["e","b"]) traces a<->e and c<->b. *)
            traced = contract[{{"a", "b", "c", "d", "a"}} -> {"d"}, {Total[t, {-1}]}];
            (* Simpler: full sum over (a=e) AND (c=b), leaving d free *)
            expected = Table[
                Sum[t[[a, b, c, d, a]] * KroneckerDelta[b, c],
                    {a, 3}, {b, 3}, {c, 3}],
                {d, 3}
            ];
            (* contract uses repeated indices to denote contraction *)
            traced = contract[{{"a", "b", "b", "d", "a"}} -> {"d"}, {t}];
            ParityClose[traced, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A12-multi-trace"
    ]
];

(* ----- A13: transpose by named order (quimb test_tensor_core.py:167-174)
   T (2,3,4,5,2,2) inds "abcdef"; transpose to "cdfeba" — exact rank-6 permutation. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A13-named-transpose",
    "quimb tests/test_tensor/test_tensor_core.py:167-174",
    VerificationTest[
        Module[{t, transposed, expected},
            SeedRandom[41];
            t = RandomReal[{-1, 1}, {2, 3, 4, 5, 2, 2}];
            (* Output {c,d,f,e,b,a} from input {a,b,c,d,e,f}.
               In Mathematica's Transpose convention, perm[k] gives the new
               position of input axis k. Input order (1=a,2=b,3=c,4=d,5=e,6=f)
               -> new positions (a@6, b@5, c@1, d@2, e@4, f@3) = {6,5,1,2,4,3}. *)
            transposed = contract[{{"a", "b", "c", "d", "e", "f"}} -> {"c", "d", "f", "e", "b", "a"}, {t}];
            expected = Transpose[t, {6, 5, 1, 2, 4, 3}];
            Dimensions[transposed] === {4, 5, 2, 2, 3, 2} && ParityClose[transposed, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A13-named-transpose"
    ]
];

(* ----- A14: tensor outer product with shared free index
   Build T[a,b,c] = u[a] v[b] w[c] (rank-1 outer product). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A14-rank1-outer",
    "quimb tensor-design.ipynb (factorizable tensor)",
    VerificationTest[
        Module[{u, v, w, t, expected},
            SeedRandom[43];
            u = RandomReal[{-1, 1}, {2}];
            v = RandomReal[{-1, 1}, {3}];
            w = RandomReal[{-1, 1}, {4}];
            t = contract[{{"a"}, {"b"}, {"c"}} -> {"a", "b", "c"}, {u, v, w}];
            expected = Outer[Times, u, v, w];
            Dimensions[t] === {2, 3, 4} && ParityClose[t, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A14-rank1-outer"
    ]
];

(* ----- A15: chain matrix product equivalence (ITensors test_contract.jl)
   Three matrices A.B.C should give same result whether we contract (A.B).C or A.(B.C). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A15-associative",
    "ITensors test/base/test_contract.jl (associativity)",
    VerificationTest[
        Module[{a, b, c, way1, way2, expected},
            SeedRandom[47];
            a = RandomReal[{-1, 1}, {3, 4}];
            b = RandomReal[{-1, 1}, {4, 5}];
            c = RandomReal[{-1, 1}, {5, 6}];
            way1 = contract[{{"i", "j"}, {"j", "k"}, {"k", "l"}} -> {"i", "l"}, {a, b, c}];
            (* Via repeated 2-tensor contractions *)
            way2 = contract[{{"i", "k"}, {"k", "l"}} -> {"i", "l"},
                {contract[{{"i", "j"}, {"j", "k"}} -> {"i", "k"}, {a, b}], c}];
            expected = a . b . c;
            ParityClose[way1, expected, 1.*^-10] && ParityClose[way2, expected, 1.*^-10] &&
                ParityClose[way1, way2, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A15-associative"
    ]
];

(* ----- A16: scalar contraction — fully traced expression -> single number *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A16-scalar",
    "quimb test_tensor_core.py (full trace)",
    VerificationTest[
        Module[{t, scalar, expected},
            SeedRandom[53];
            t = RandomReal[{-1, 1}, {4, 4}];
            scalar = contract[{{"i", "i"}} -> {}, {t}];
            expected = Tr[t];
            ParityClose[scalar, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A16-scalar"
    ]
];

(* ----- A17: 4-tensor closed network with hyper-edge — sum over a triple-shared index
   T1[i,x] T2[j,x] T3[k,x] T4[l,x] -> R[i,j,k,l] *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A17-quad-hyperedge",
    "quimb tensor-design.ipynb (hyper-index sum)",
    VerificationTest[
        Module[{t1, t2, t3, t4, r, expected},
            SeedRandom[59];
            t1 = RandomReal[{-1, 1}, {2, 5}];
            t2 = RandomReal[{-1, 1}, {3, 5}];
            t3 = RandomReal[{-1, 1}, {2, 5}];
            t4 = RandomReal[{-1, 1}, {3, 5}];
            r = contract[
                {{"i", "x"}, {"j", "x"}, {"k", "x"}, {"l", "x"}} -> {"i", "j", "k", "l"},
                {t1, t2, t3, t4}
            ];
            expected = Table[
                Sum[t1[[i, x]] t2[[j, x]] t3[[k, x]] t4[[l, x]], {x, 5}],
                {i, 2}, {j, 3}, {k, 2}, {l, 3}
            ];
            ParityClose[r, expected, 1.*^-10]
        ],
        True,
        TestID -> "tier1a-A17-quad-hyperedge"
    ]
];

(* ----- A18: sparse-friendly identity tensor as delta
   The identity matrix as a 2-index tensor satisfies sum_i I[i,j] T[i,k] = T[j,k]. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"}, "tier1a-A18-identity-tensor",
    "ITensors delta tensor (test_itensor.jl:140-168)",
    VerificationTest[
        Module[{id, t, contracted, expected},
            id = N @ IdentityMatrix[3];
            SeedRandom[61];
            t = RandomReal[{-1, 1}, {3, 4}];
            contracted = contract[{{"i", "j"}, {"i", "k"}} -> {"j", "k"}, {id, t}];
            expected = t;
            ParityClose[contracted, expected, 1.*^-12]
        ],
        True,
        TestID -> "tier1a-A18-identity-tensor"
    ]
];
