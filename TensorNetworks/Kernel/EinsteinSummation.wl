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


ActivateTensors[expr_] := Activate[
    Activate[expr /. {
        GeneralizedPower[TensorProduct, t_, n_Integer] :> Inactive[TensorProduct] @@ ConstantArray[Activate[t, TensorContract], n],
        arr : _SymbolicIdentityArray | _SymbolicDeltaProductArray :> Normal[arr]
    }, TensorContract]
]
