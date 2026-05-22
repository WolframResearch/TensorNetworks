(* Tests/test_random_tensor_network.wl

   Tests for RandomTensorNetwork — both the element-type contract (Real /
   Complex / Real-explicit) and the structural contract (right tensor count,
   right bond/free-index distribution for canonical topologies). The
   structural tests are what would catch a regression where the generator
   silently produces malformed networks.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

SeedRandom[42];


(* ============================================ *)
(* Element-type contract                       *)
(* ============================================ *)

VerificationTest[
    rtnAuto = RandomTensorNetwork[{10, 15}, 2, 4];
    AllTrue[Flatten[rtnAuto["Tensors"]], Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Real_Default"
]

VerificationTest[
    rtnComplex = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Complex"];
    AnyTrue[Flatten[rtnComplex["Tensors"]], !Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Complex"
]

VerificationTest[
    rtnReal = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Real"];
    AllTrue[Flatten[rtnReal["Tensors"]], Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Real_Explicit"
]


(* ============================================ *)
(* Structural contract — generic graph form    *)
(* ============================================ *)

(* {n, m} graph input must produce a TN with exactly n tensors. *)
VerificationTest[
    Length[RandomTensorNetwork[{8, 12}, 2, 4]["Tensors"]],
    8,
    TestID -> "RandomTensorNetwork_NTensorCount"
]

(* Every tensor's actual array dimensions must match the dim of each leg. *)
VerificationTest[
    Module[{tn, indDims, ok},
        tn = RandomTensorNetwork[{6, 9}, 2, 4];
        indDims = Association @ tn["IndexDimensions"];
        ok = AllTrue[
            Range[Length[tn["Tensors"]]],
            Dimensions[tn["Tensors"][[#]]] === (
                Lookup[indDims, Last /@ tn["Indices"][[#]]]
            ) &
        ];
        ok
    ],
    True,
    TestID -> "RandomTensorNetwork_TensorShapes_Match_IndexDims"
]


(* ============================================ *)
(* Structural contract — MPS topology          *)
(* ============================================ *)

(* MPS[L, D, d] must produce L tensors, with ranks (2, 3, 3, ..., 3, 2). *)
VerificationTest[
    Module[{tn},
        tn = RandomTensorNetwork["MPS"[6, 4, 2]];
        Length[tn["Tensors"]] === 6 &&
            tn["Ranks"] === {2, 3, 3, 3, 3, 2}
    ],
    True,
    TestID -> "RandomTensorNetwork_MPS_Ranks"
]

(* MPS bond dims should all equal D, phys dims should all equal d. *)
VerificationTest[
    Module[{tn, dims},
        tn = RandomTensorNetwork["MPS"[5, 4, 3]];
        dims = tn["Dimensions"];
        (* Boundary sites have 2 legs; interior have 3 *)
        First[dims] === {4, 3} &&
            Last[dims] === {4, 3} &&
            dims[[2]] === {4, 4, 3} &&
            dims[[3]] === {4, 4, 3}
    ],
    True,
    TestID -> "RandomTensorNetwork_MPS_BondAndPhysDims"
]

(* MPS free indices = the L physical legs (one per site, none paired). *)
VerificationTest[
    Module[{tn},
        tn = RandomTensorNetwork["MPS"[6, 3, 2]];
        Length[tn["FreeIndices"]] === 6
    ],
    True,
    TestID -> "RandomTensorNetwork_MPS_FreeIndicesCount"
]


(* ============================================ *)
(* Structural contract — PEPS topology         *)
(* ============================================ *)

(* PEPS {r, c} should produce r·c tensors with r·c free physical legs. *)
VerificationTest[
    Module[{tn},
        tn = RandomTensorNetwork["PEPS"[{3, 4}, 2, 2]];
        Length[tn["Tensors"]] === 12 &&
            Length[tn["FreeIndices"]] === 12
    ],
    True,
    TestID -> "RandomTensorNetwork_PEPS_TensorCount_And_Phys"
]
