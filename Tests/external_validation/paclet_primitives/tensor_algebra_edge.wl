(* Tests/external_validation/paclet_primitives/tensor_algebra_edge.wl

Tier-2 direct-validation tests for EinsteinSummation edge cases. Each test
cites a specific catalog assertion (shape or scalar value) and verifies the
paclet's EinsteinSummation/ActivateTensors reproduces it.

Sources:
- quimb tests/test_tensor_core.py:185-203 (multi-trace specific values)
- quimb tests/test_tensor_core.py:283-295 (squeeze size-1 dims, expected shape)
- quimb tests/test_tensor_core.py:259-264 (isel slicing, expected shape)
- quimb tests/test_tensor_core.py:752-779 (tensor direct product, structure)
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

contract = ActivateTensors @* EinsteinSummation;

(* ----- T1: Trace of N x N identity matrix = N
   Source: quimb tests/test_tensor_core.py:185-203 (trace pair test pattern).
   Direct value: Tr(I_N) = N for any N. Tested for N=7. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T1-identity-trace",
    "quimb tests/test_tensor_core.py:185-203 (trace pair)",
    VerificationTest[
        Module[{n, id, traced},
            n = 7;
            id = N @ IdentityMatrix[n];
            traced = contract[{{"i", "i"}} -> {}, {id}];
            traced === N[n]
        ],
        True,
        TestID -> "paclet-tensor-edge-T1-identity-trace"
    ]
];

(* ----- T2: Squeeze size-1 dimensions
   Source: quimb tests/test_tensor_core.py:283-295.
   t with shape (1,2,3,1,4) and indices "abcde"; after t.squeeze() the
   result has shape (2,3,4) and indices "bce". The paclet's analogue is
   to contract such that the size-1 indices are summed (which trivially
   keeps the data) — the resulting shape is specific. *)
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

(* ----- T3: Hyper-index over 4 tensors all-identity gives hyper-delta
   Source: extension of quimb tensor-design.ipynb hyper-index pattern.
   For 4 identity matrices I_a connected on a shared index x, the hyper-edge
   sum is the 4-index tensor T[a,b,c,d] = sum_x I[a,x] I[b,x] I[c,x] I[d,x] =
   delta(a=b=c=d). Specific value: T[i,i,i,i] = 1 for i in 1..N, else 0. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T3-hyper4-identity-delta",
    "quimb docs/tensor/tensor-design.ipynb (hyper-index sum pattern)",
    VerificationTest[
        Module[{n, id, t, expected},
            n = 3;
            id = N @ IdentityMatrix[n];
            t = contract[
                {{"a", "x"}, {"b", "x"}, {"c", "x"}, {"d", "x"}} -> {"a", "b", "c", "d"},
                {id, id, id, id}
            ];
            expected = Table[
                If[a === b === c === d, 1.0, 0.0],
                {a, n}, {b, n}, {c, n}, {d, n}
            ];
            ValidationClose[t, expected, 1.*^-12]
        ],
        True,
        TestID -> "paclet-tensor-edge-T3-hyper4-identity-delta"
    ]
];

(* ----- T4: Single-element tensor (rank-0 from rank-1 contraction)
   Source: ITensors tests/test_contract.jl (vᵀv scalar).
   Specific value: contract a vector of N ones with itself = N. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T4-vec-ones-self-dot",
    "ITensors tests/test_contract.jl (vᵀv scalar)",
    VerificationTest[
        Module[{v, scalar, n},
            n = 11;
            v = ConstantArray[1.0, n];
            scalar = contract[{{"i"}, {"i"}} -> {}, {v, v}];
            scalar === N[n]
        ],
        True,
        TestID -> "paclet-tensor-edge-T4-vec-ones-self-dot"
    ]
];

(* ----- T5: Trace of an N x N all-ones matrix = N
   Source: extension of trace identities; specific scalar.
   The all-ones matrix M = ones(N,N). Tr(M) = sum of diagonal = N
   (each diagonal entry is 1, of which there are N). *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T5-allones-trace",
    "ITensors tests/test_contract.jl trace identity",
    VerificationTest[
        Module[{n, m, traced},
            n = 5;
            m = ConstantArray[1.0, {n, n}];
            traced = contract[{{"i", "i"}} -> {}, {m}];
            traced === N[n]
        ],
        True,
        TestID -> "paclet-tensor-edge-T5-allones-trace"
    ]
];

(* ----- T6: Six-rank tensor contraction: union of legs gives output of rank
   Source: extension of quimb's general contraction patterns.
   Two rank-4 tensors A[i,j,k,l] and B[i,j,m,n] sharing legs (i,j); contract
   them. Output: rank-4 tensor with shape (k,l,m,n).
   With all-ones tensors of these shapes, every output entry equals the
   product of shared dim sizes = d_i * d_j. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T6-rank4-rank4-contract",
    "quimb docs/tensor/tensor-basics.ipynb (general rank-N contraction)",
    VerificationTest[
        Module[{di, dj, dk, dl, dm, dn, a, b, result, expectedValue},
            di = 2; dj = 3; dk = 4; dl = 5; dm = 6; dn = 7;
            a = ConstantArray[1.0, {di, dj, dk, dl}];
            b = ConstantArray[1.0, {di, dj, dm, dn}];
            result = contract[
                {{"i", "j", "k", "l"}, {"i", "j", "m", "n"}} -> {"k", "l", "m", "n"},
                {a, b}
            ];
            expectedValue = N[di * dj];
            Dimensions[result] === {dk, dl, dm, dn} &&
                AllTrue[Flatten[result], ValidationClose[#, expectedValue, 1.*^-12] &]
        ],
        True,
        TestID -> "paclet-tensor-edge-T6-rank4-rank4-contract"
    ]
];

(* ----- T7: Single-tensor pure transpose (no contraction)
   Source: quimb tests/test_tensor_core.py:167-174 (named transpose).
   T of shape (2,3,4,5,2,2) with indices abcdef; permute to cdfeba.
   Result: rank-6 tensor with shape (4,5,2,2,3,2). The data must equal
   Mathematica's Transpose with the corresponding axis permutation. *)
WithCapability[{"EinsteinSummation", "ActivateTensors"},
    "paclet-tensor-edge-T7-pure-transpose-shape",
    "quimb tests/test_tensor_core.py:167-174 (named-axis transpose)",
    VerificationTest[
        Module[{t, transposed, expected},
            SeedRandom[613];
            t = RandomReal[{-1, 1}, {2, 3, 4, 5, 2, 2}];
            transposed = contract[
                {{"a", "b", "c", "d", "e", "f"}} -> {"c", "d", "f", "e", "b", "a"},
                {t}
            ];
            (* Map orig position -> new position: a->6, b->5, c->1, d->2, e->4, f->3 *)
            expected = Transpose[t, {6, 5, 1, 2, 4, 3}];
            Dimensions[transposed] === {4, 5, 2, 2, 3, 2} &&
                ValidationClose[transposed, expected, 1.*^-12]
        ],
        True,
        TestID -> "paclet-tensor-edge-T7-pure-transpose-shape"
    ]
];
