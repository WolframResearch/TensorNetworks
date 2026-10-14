(* The boundary with Wolfram/Arrays: delegated names, required shape rules, changed callers *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

Needs["Wolfram`Arrays`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];


(* === the delegation itself === *)

(* Any other name here would be a stray definition shadowing the Arrays symbol *)
VerificationTest[
    Names["Wolfram`TensorNetworks`IndexArray`Array*"],
    {"ArraySymmetry"},
    TestID -> "ArrayUtilities_OnlyArraySymmetryIsLocal"
]

(* Unexported leftover definitions would sit, unreachable, in the private context *)
VerificationTest[
    Names["Wolfram`TensorNetworks`IndexArray`*`Array*"],
    {},
    TestID -> "ArrayUtilities_NoOrphanedPrivateDefinitions"
]

(* A TensorNetworks definition on a delegated name would mutate Wolfram/Arrays, session-wide *)
VerificationTest[
    Length[DownValues[Wolfram`Arrays`ArrayDimensions]] ===
        Block[{$ContextPath}, Needs["Wolfram`Arrays`"]; Length[DownValues[Wolfram`Arrays`ArrayDimensions]]],
    True,
    TestID -> "ArrayUtilities_ArraysSymbolsNotMutated"
]


(* === the two shape rules the dependency floor exists for === *)

(* A rank-0 operand under Inactive[D] is a scalar field: its gradient by n coordinates has rank n *)
VerificationTest[
    ArrayDimensions[Inactive[D][phi, {{cx, cy}}]],
    {2},
    TestID -> "ArrayUtilities_GradientOfScalarFieldKeepsItsIndex"
]

(* A list of symbolic vectors is a matrix; Dimensions alone stops at the list level *)
VerificationTest[
    ArrayDimensions[{VectorSymbol["tv", 2], VectorSymbol["tw", 2]}],
    {2, 2},
    TestID -> "ArrayUtilities_ListOfSymbolicVectorsHasFullShape"
]

VerificationTest[
    Assuming[
        {Element[ta, Vectors[2]], Element[tb, Vectors[2]]},
        ArrayDimensions[{ta, tb}]
    ],
    {2, 2},
    TestID -> "ArrayUtilities_AssumptionRegisteredListHasFullShape"
]


(* === ArraySymmetry, the one operation still defined here === *)

VerificationTest[
    ArraySymmetry[{{1, 2}, {2, 3}}],
    Symmetric[{1, 2}],
    TestID -> "ArraySymmetry_SymmetricList"
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
    With[{g = MetricTensor[NumericArray[{{1, 0}, {0, -1}}, "Integer64"]]},
        {MetricTensorQ[g], g["Determinant"]}
    ],
    {True, -1},
    TestID -> "MetricTensor_MaterializesStorageWrappers"
]

VerificationTest[
    With[{g = MetricTensor[{{1, 0}, {0, -1}}]},
        {MetricTensorQ[g], g["Determinant"]}
    ],
    {True, -1},
    TestID -> "MetricTensor_PlainMatrixUnchanged"
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
        FreeQ[IndexPart[ia, {1}], _Wolfram`Arrays`ArrayPart]
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
