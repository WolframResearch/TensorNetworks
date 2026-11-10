(* ArraySymmetry and the callers that read arrays through Wolfram/Arrays containers *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

Needs["Wolfram`Arrays`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];


(* === ArraySymmetry, the one operation still defined here === *)

VerificationTest[
    ArraySymmetry[{{1, 2}, {2, 3}}],
    Symmetric[{1, 2}],
    TestID -> "ArraySymmetry_SymmetricList"
]

(* Symmetric in slots 1 and 3 only: entries depend on i k and on j *)
VerificationTest[
    {
        ArraySymmetry[Table[i k + j, {i, 2}, {j, 3}, {k, 2}]],
        ArraySymmetry[{{0, 2}, {-2, 0}}],
        ArraySymmetry[{{1, 2}, {3, 4}}]
    },
    {Symmetric[{1, 3}], Antisymmetric[{1, 2}], {}},
    TestID -> "ArraySymmetry_SlotPairAntisymmetricAndNone"
]

(* TensorSymmetry itself does not evaluate on a NumericArray *)
VerificationTest[
    ArraySymmetry[NumericArray[{{1, 2}, {2, 3}}, "Integer64"]],
    Symmetric[{1, 2}],
    TestID -> "ArraySymmetry_ReadsThroughStorageWrappers"
]

(* Not materialized: the symmetry is in the structure *)
VerificationTest[
    ArraySymmetry[SymmetrizedArray[{{1, 2} -> 3}, {2, 2}, Antisymmetric[{1, 2}]]],
    Antisymmetric[{1, 2}],
    TestID -> "ArraySymmetry_ReadsStructuredArraysNatively"
]

(* The rank gate, not a Quiet, keeps ragged input from TensorSymmetry::rect *)
VerificationTest[
    ArraySymmetry[{{1, 2}, {3}}],
    {},
    TestID -> "ArraySymmetry_RaggedInputIsQuiet"
]

VerificationTest[
    ArraySymmetry[7],
    {},
    TestID -> "ArraySymmetry_ScalarHasNoSymmetry"
]


(* === the callers whose behaviour the delegation changed === *)

(* MetricTensor materializes storage wrappers, which it cannot invert *)
VerificationTest[
    With[{g = MetricTensor[NumericArray[{{2, 1}, {1, -3}}, "Integer64"]]},
        {MetricTensorQ[g], g["Matrix"], g["Determinant"]}
    ],
    {True, {{2, 1}, {1, -3}}, -7},
    TestID -> "MetricTensor_MaterializesStorageWrappers"
]

(* A NumericArray leaf keeps its full shape and has the List's symmetry *)
VerificationTest[
    With[{ia = IndexArray[NumericArray[{{1, 2}, {2, 3}}, "Integer64"]]},
        {IndexArrayQ[ia], ia["Dimensions"], ia["Symmetry"]}
    ],
    {True, {2, 2}, Symmetric[{1, 2}]},
    TestID -> "IndexArray_StorageWrapperLeafIsWellShaped"
]

(* ArrayPart declines a symbolic structural tree; IndexPart must not wrap the unevaluated call *)
VerificationTest[
    With[{
        ia = IndexArray[
            Inactive[TensorProduct][MatrixSymbol["pA", {2, 2}], MatrixSymbol["pB", {2, 2}]],
            Shape[{2, 2, 2, 2}]
        ]
    },
        MatchQ[IndexPart[ia, {1}], HoldPattern[IndexPart[_IndexArray, {1}]]]
    ],
    True,
    TestID -> "IndexPart_DeclinesSymbolicStructuralTree"
]

VerificationTest[
    With[{ia = IndexArray[{{1, 2}, {3, 4}}]},
        {Normal[IndexPart[ia, {1}]["Array"]], IndexArrayQ[IndexPart[ia, {1}]]}
    ],
    {{1, 2}, True},
    TestID -> "IndexPart_ExplicitArrayStillSlices"
]
