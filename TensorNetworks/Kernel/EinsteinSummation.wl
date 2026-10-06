Package["Wolfram`TensorNetworks`"]


PackageExport[EinsteinSummation]
PackageExport[IndexedMultiply]
PackageExport[ActivateTensors]


EinsteinSummation[in_List | (in_List -> Automatic), arrays_] := Module[{
	res = isum[in -> Cases[Tally @ Flatten @ in, {_, 1}][[All, 1]], arrays]
},
	res /; res =!= $Failed
]

EinsteinSummation[in_List -> out_, arrays_] := isum[in -> out, arrays]

EinsteinSummation[s_String, arrays_] := EinsteinSummation[
	Replace[
		StringSplit[s, "->"],
		{{in_, out_} :> Characters[StringSplit[in, ","]] -> Characters[out],
		{in_} :> Characters[StringSplit[in, ","]]}
	],
	arrays
]

IndexedMultiply[indices_, arrays_] := Enclose @ Block[{
    oldIndices, newIndices, dims, posIndex
},
    ConfirmAssert[Length /@ indices == tensorRank /@ arrays];
    oldIndices = Block[{i = 0},
        FoldPairList[
            With[{is = FoldPairList[With[{j = Lookup[#1, #2, i++]}, {j, KeyDrop[#1, {#2}]}] &, #1, #2]}, {is, <|#1, Thread[#2 -> is]|>}] &,
            <||>,
            indices
        ]
    ];
    dims = GroupBy[Catenate[MapThread[Thread[#1 -> tensorDimensions[#2]] &, {oldIndices, arrays}]], First -> Last, Max];
    newIndices = Map[old |-> With[{new = Select[Keys[dims], MemberQ[old, #] &]}, Join[new, Drop[old, UpTo[Length[new]]]]], oldIndices];
    posIndex = First /@ PositionIndex[Keys[dims]];
    {
        Lookup[AssociationThread[Catenate[oldIndices], Catenate[indices]], Keys[dims]],
        Times @@ MapThread[
            If[ TensorQ[#3],
                Fold[
                    ArrayPad[
                        #1,
                        Append[ConstantArray[{0, 0}, #2[[1]]], {0, #2[[2]] - #2[[3]]}],
                        If[#2[[3]] == 1, "Fixed", 1]
                    ] &,
                    #,
                    Reverse @ Thread[{Range[0, Length[dims] - 1], Values[dims], tensorDimensions[#]}]
                ] & @ With[{perm = FindPermutation[#1, #2]},
                    ArrayReshape[
                        Transpose[#3, perm],
                        ReplacePart[ConstantArray[1, Length[posIndex]], Thread[Lookup[posIndex, #2, {}] -> Permute[tensorDimensions[#3], perm]]]
                    ]
                ],
                ArraySymbol[Transpose[#3, FindPermutation[#1, #2]], Values[dims]]
            ] &,
            {oldIndices, newIndices, arrays}
        ]
    }
]

isum[in_List -> out_, arrays_List] := Enclose @ Module[{
	nonFreePos, freePos, nonFreeIn, nonFreeArray,
    newArrays, newIn, indices, dimensions, contracted, contractions,
    scalarPositions, scalars,
    multiplicity, tensor
},
	If[ Length[in] != Length[arrays],
        Message[EinsteinSummation::length, Length[in], Length[arrays]];
	    Confirm[$Failed]
    ];
	MapThread[
		If[ IntegerQ @ tensorRank[#1] && Length[#1] != tensorRank[#2],
			Message[EinsteinSummation::shape, #1, #2];
            Confirm[$Failed]
		] &,
		{in, arrays}
	];

    scalarPositions = Position[in, {}, {1}, Heads -> False];
    scalars = Extract[arrays, scalarPositions];
    newArrays = Delete[arrays, scalarPositions];
    newIn = Delete[in, scalarPositions];

    If[ AnyTrue[out, Count[in, {___, #, ___}] > 1 &],
        nonFreePos = Catenate @ Position[newIn, _ ? (ContainsAny[out]), {1}, Heads -> False];
        freePos = Complement[Range[Length[newIn]], nonFreePos];
        {nonFreeIn, nonFreeArray} = Confirm @ IndexedMultiply[newIn[[nonFreePos]], newArrays[[nonFreePos]]];
        newArrays = Prepend[newArrays[[freePos]], nonFreeArray];
        newIn = Prepend[newIn[[freePos]], nonFreeIn]
    ];
	indices = Catenate[newIn];
    dimensions = Catenate[tensorDimensions /@ newArrays];
	contracted = DeleteElements[indices, 1 -> out];
    tensor = If[Length[newArrays] == 1, First[newArrays], Inactive[TensorProduct] @@ newArrays];
    If[ contracted =!= {},
        contractions = MapThread[Reverse[Take[Reverse[#1], UpTo[#2]]] &, {Lookup[PositionIndex[indices], #1], #2}] & @@ Thread[Tally[contracted]];
        If[! AllTrue[contractions, Equal @@ dimensions[[#]] &], Message[EinsteinSummation::dim]; Confirm[$Failed]];
        indices = Reverse[DeleteElements[Reverse[indices], 1 -> contracted]];
        If[! ContainsAll[indices, out], Message[EinsteinSummation::output]; Confirm[$Failed]];
        tensor = Inactive[TensorContract][tensor, contractions]
    ];
	multiplicity = Max @ Merge[{Counts[out], Counts[indices]}, Apply[Ceiling[#1 / #2] &]];
	If[ multiplicity > 1,
		indices = Catenate @ ConstantArray[indices, multiplicity];
		contracted = DeleteElements[indices, 1 -> out];
        tensor = GeneralizedPower[TensorProduct, tensor, multiplicity];
        If[ contracted =!= {},
            contractions = MapThread[Reverse[Take[Reverse[#1], UpTo[#2]]] &, {Lookup[PositionIndex[indices], #1], #2}] & @@ Thread[Tally[contracted]];
            indices = Reverse[DeleteElements[Reverse[indices], 1 -> contracted]];
            tensor = Inactive[TensorContract][tensor, contractions]
        ];
	];
    Times @@ scalars * If[indices === out, tensor, Transpose[tensor, FindPermutation[indices, out]]]
]

EinsteinSummation::length = "Number of index specifications (`1`) does not match the number of tensors (`2`)";
EinsteinSummation::shape = "Index specification `1` does not match the tensor rank of `2`";
EinsteinSummation::dim = "Dimensions of contracted indices don't match";
EinsteinSummation::output = "The uncontracted indices can't compose the desired output";


(* An inert contraction is the TensorContract of a TensorProduct.  The kernel
   contracts an inert product of arrays without building it, so activating
   TensorContract first and the product after is fast for a contraction of
   arrays - but a symbolic delta has to be densified for that, and the inert
   form of a step with batch indices carries a rank-3 delta per batch index:
   a 7-qubit circuit's inert contraction took 3 s to activate, a 5-wire phase
   oracle's more than 15 s.

   So a contraction with a delta among its operands is handed to
   Wolfram/Arrays' ArrayContract as an operand set: the operands are
   contracted against each other, and the delta by identifying the indices it
   ties, never expanded - 13 ms for that circuit, 5 ms for the oracle.  Every
   other contraction goes through TensorContract of the inert product exactly
   as before.  The contraction head is renamed and Activate evaluates the
   expression bottom up, so a contraction sees its operands already evaluated
   and a scoping construct such as an inert Table still binds its iterators
   first; the renamed head holds its argument, so the product is seen before it
   is built.

   What ArrayContract gives is made what TensorContract of the product gave: a
   machine number among the operands makes every entry one, a dense result is
   packed where it can be, a SparseArray operand makes the result sparse, and
   the deltas-only and diagonal results ArrayContract keeps symbolic or sparse
   are made dense.  A delta outside a contraction is densified, as before.

   Each level of a nested contraction costs the evaluator a few frames more
   than TensorContract did, and a greedy path over a sequential circuit nests
   one level per gate, so the recursion limit is raised for the activation:
   2^14 frames carry some 2000 levels, where 1024 stopped at a few hundred,
   and stay well inside the kernel's stack, which a plain recursion 30000
   levels deep overflows. *)
ActivateTensors[expr_] := Block[{$RecursionLimit = Max[$RecursionLimit, 2^14]},
    Activate[expr /. {
        d : _SymbolicDeltaProductArray | _SymbolicIdentityArray :> Inactive[deltaOperand][d],
        Inactive[TensorContract] -> Inactive[inertContract]
    }]
]

deltaOperand[d_] := Normal[d]

SetAttributes[inertContract, HoldFirst]

inertContract[TensorProduct[operands___], pairs_] := contractOperands[operandValues[operands], pairs]

inertContract[operand_, pairs_] := With[{values = operandValues[operand]},
    If[ MatchQ[values, {Except[_SymbolicDeltaProductArray | _SymbolicIdentityArray]}],
        TensorContract[First[values], pairs],
        contractOperands[values, pairs]
    ]
]

(* A product's operands, nested products and powers flattened in order of
   their levels, and a delta kept as the delta it is. *)
SetAttributes[operandValues, HoldAll]

operandValues[operands___] := Catenate[operandValue /@ Unevaluated[{operands}]]

SetAttributes[operandValue, HoldAll]

operandValue[deltaOperand[d_]] := {d}

operandValue[TensorProduct[operands___]] := operandValues[operands]

operandValue[GeneralizedPower[TensorProduct, t_, n_Integer]] := ConstantArray[t, n]

operandValue[operand_] := {operand}

contractOperands[operands_List, pairs_] := If[
    MemberQ[operands, _SymbolicDeltaProductArray | _SymbolicIdentityArray] && AllTrue[operands, plainOperandQ],
    Replace[
        Quiet @ Wolfram`Arrays`ArrayContract[Inactive[TensorProduct] @@ operands, pairs],
        {
            r : _SymbolicDeltaProductArray | _SymbolicIdentityArray | _SymbolicOnesArray :> asProductContracted[Normal[r], operands],
            r_ /; NumericQ[r] || MatchQ[r, _List | _SparseArray] && ArrayQ[r] :> asProductContracted[r, operands],
            _ :> productContract[operands, pairs]
        }
    ],
    productContract[operands, pairs]
]

plainOperandQ[t_] := NumericQ[t] || MatchQ[t, _SparseArray | _SymbolicDeltaProductArray | _SymbolicIdentityArray] || ListQ[t] && ArrayQ[t]

productContract[operands_, pairs_] := Activate @ TensorContract[
    Inactive[TensorProduct] @@ Replace[operands, d : _SymbolicDeltaProductArray | _SymbolicIdentityArray :> Normal[d], {1}],
    pairs
]

asProductContracted[r_, operands_] := With[{
    value = If[ Min[Precision /@ DeleteCases[operands, _SymbolicDeltaProductArray | _SymbolicIdentityArray]] === MachinePrecision &&
            (NumericQ[r] || ArrayQ[r, _, NumericQ]),
        N[r],
        r
    ]
},
    Which[
        NumericQ[value], value,
        MemberQ[operands, _SparseArray], SparseArray[value],
        True, packedIfMachine[If[MatchQ[value, _SparseArray], Normal[value], value]]
    ]
]
