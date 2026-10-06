(* Tests/test_array_utilities.wl

   Pins the boundary between this paclet and Wolfram/Arrays.

   The IndexArray subcontext used to carry its own ArrayDimensions, ArrayRank,
   ArrayName, ArrayPart, ArrayTranspose, ArrayContract, SimplifyArray and
   ZeroArrayQ.  They now come from Wolfram/Arrays and only ArraySymmetry is
   still defined here.  What follows checks the three things that delegation
   can break and that neither run_tests.wl nor run_doc_examples.wl looks at:
   that the local definitions really are gone and the dependency's really are
   not mutated, that the shape rules this paclet depends on still hold in the
   version it now requires, and that the callers whose behaviour changed
   changed in the intended direction. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

Needs["Wolfram`Arrays`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];


(* === the delegation itself === *)

(* Only ArraySymmetry is left.  A name reappearing here is either a definition
   that was meant to be deleted or - the failure this is really watching for -
   a stray assignment that recreated a second, shadowing symbol. *)
VerificationTest[
    Names["Wolfram`TensorNetworks`IndexArray`Array*"],
    {"ArraySymmetry"},
    TestID -> "ArrayUtilities_OnlyArraySymmetryIsLocal"
]

(* The signature of a half-finished migration: exports removed but definitions
   left behind, which lands them in the file's private context, defined and
   unreachable. *)
VerificationTest[
    Names["Wolfram`TensorNetworks`IndexArray`*`Array*"],
    {},
    TestID -> "ArrayUtilities_NoOrphanedPrivateDefinitions"
]

(* Delegation must not mean MUTATION.  These names are no longer local, so an
   ordinary-looking definition on one of them inside this subcontext would add a
   DownValue to the DEPENDENCY, session-wide, where neither ClearAll in
   TensorNetworks.wl can reach it.  Any TensorNetworks file adding a rule to an
   Arrays symbol shows up here as a count that is not the shipped one. *)
VerificationTest[
    Length[DownValues[Wolfram`Arrays`ArrayDimensions]] ===
        Block[{$ContextPath}, Needs["Wolfram`Arrays`"]; Length[DownValues[Wolfram`Arrays`ArrayDimensions]]],
    True,
    TestID -> "ArrayUtilities_ArraysSymbolsNotMutated"
]


(* === the two shape rules the dependency floor exists for === *)

(* A rank-0 operand under Inactive[D] is a SCALAR FIELD, so its gradient by n
   coordinates has rank n.  Wolfram/Arrays before 1.3.3 reported {} and the
   covariant derivative of a scalar field silently lost its index. *)
VerificationTest[
    ArrayDimensions[Inactive[D][phi, {{cx, cy}}]],
    {2},
    TestID -> "ArrayUtilities_GradientOfScalarFieldKeepsItsIndex"
]

(* A list whose leaves are symbolic containers is a higher-rank array, and
   Dimensions alone stops at the list level.  Before 1.3.3 this read {2}, which
   flipped squareMatrixQ and sent MetricTensor down its diagonal branch to build
   a different metric that still satisfied MetricTensorQ. *)
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

(* TensorSymmetry does not evaluate on the storage wrappers, so before this was
   generalized the same matrix reported Symmetric[{1, 2}] as a List and {} as a
   NumericArray - a disagreement the migration would otherwise have exposed,
   since a NumericArray only became a well-shaped IndexArray through it. *)
VerificationTest[
    ArraySymmetry[NumericArray[{{1, 2}, {2, 3}}, "Integer64"]],
    Symmetric[{1, 2}],
    TestID -> "ArraySymmetry_ReadsThroughStorageWrappers"
]

(* Structured arrays stay on the native path: the symmetry is in the structure
   and materializing would throw it away. *)
VerificationTest[
    ArraySymmetry[SymmetrizedArray[{{1, 2} -> 3}, {2, 2}, Antisymmetric[{1, 2}]]],
    Antisymmetric[{1, 2}],
    TestID -> "ArraySymmetry_ReadsStructuredArraysNatively"
]

(* The rank gate, not a Quiet, is what keeps ragged input silent: TensorSymmetry
   emits TensorSymmetry::rect on a nonrectangular array, and ArrayDimensions has
   already refused such input, so the rank is 0 and the message is unreachable. *)
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

(* squareMatrixQ reads its shape from Wolfram/Arrays and so now holds for the
   storage wrappers.  MetricTensor materializes those rather than admitting a
   container it cannot invert: without that it built a MetricTensorQ-True object
   whose "MatrixRepresentation" and "Determinant" were unevaluated heads. *)
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

(* A NumericArray leaf now yields a well-shaped IndexArray instead of a rank-0
   one, and its symmetry agrees with the same matrix written as a List. *)
VerificationTest[
    With[{ia = IndexArray[NumericArray[{{1, 2}, {2, 3}}, "Integer64"]]},
        {IndexArrayQ[ia], ia["Dimensions"], ia["Symmetry"]}
    ],
    {True, {2, 2}, Symmetric[{1, 2}]},
    TestID -> "IndexArray_StorageWrapperLeafIsWellShaped"
]

(* ArrayPart declines a structural tree carrying a symbolic container rather
   than slicing the expression tree and handing back an operand of the node.
   IndexPart must decline with it: storing that unevaluated call would produce
   an IndexArray that satisfies IndexArrayQ as a rank-0 object wrapping a
   foreign head. *)
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

(* The explicit case still slices, and still produces a valid IndexArray. *)
VerificationTest[
    With[{ia = IndexArray[{{1, 2}, {3, 4}}]},
        {Normal[IndexPart[ia, {1}]["Array"]], IndexArrayQ[IndexPart[ia, {1}]]}
    ],
    {{1, 2}, True},
    TestID -> "IndexPart_ExplicitArrayStillSlices"
]
