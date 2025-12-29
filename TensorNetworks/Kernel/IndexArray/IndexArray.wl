Package["Wolfram`TensorNetworks`IndexArray`"]

PackageExport[IndexArrayQ]
PackageExport[IndexArray]



(* Validation *)

indexArrayQ[IndexArray[tensor_, shape_Shape ? ShapeQ, params_List, assumptions_List, ___]] :=
    With[{dims1 = Assuming[assumptions, ArrayDimensions[tensor]], dims2 = shape["Dimensions"]},
        dims1 === dims2 || MemberQ[dims1, 0] && MemberQ[dims2, 0]
    ]

indexArrayQ[___] := False


IndexArrayQ[ia_IndexArray] := System`Private`HoldValidQ[ia] || indexArrayQ[Unevaluated[ia]]

IndexArrayQ[___] := False


(* Mutation *)

IndexArray[ia_ ? IndexArrayQ, arg1_, arg2_, args___] := With[{shape = Shape[arg1]},
    Which[
        ShapeQ[shape],
        IndexArray[IndexArray[ia["Tensor"], shape, ia["Parameters"], ia["Assumptions"], ia["Name"]], arg2, args],
        MatchQ[arg1, _List] && MatchQ[arg2, _List],
        IndexArray[ia["Tensor"], ia["Shape"], arg1, arg2, args, ia["Name"]],
        MatchQ[arg1, _List],
        IndexArray[ia["Tensor"], ia["Shape"], arg1, ia["Assumptions"], arg2, args],
        True,
        IndexArray[ia["Tensor"], ia["Shape"], ia["Parameters"], ia["Assumptions"], arg1, arg2, args]
    ]
]

IndexArray[ia_ ? IndexArrayQ, arg_] := With[{shape = Shape[arg]},
    Which[
        ShapeQ[shape],
        IndexArray[ia["Tensor"], shape, ia["Parameters"], ia["Assumptions"], ia["Name"]],
        MatchQ[arg, _List],
        IndexArray[ia["Tensor"], ia["Shape"], arg, ia["Assumptions"], ia["Name"]],
        True,
        IndexArray[ia["Tensor"], ia["Shape"], ia["Parameters"], ia["Assumptions"], arg]
    ]
]

IndexArray[ia_IndexArray] := ia


(* Constructors *)

IndexArray[tensor_, variance : {__ ? BooleanQ}, args___] :=    
    IndexArray[tensor, # * PadRight[- (-1) ^ Boole[variance], Length[#], 1] & @ IndexArray[tensor]["Dimensions"], args]

IndexArray[tensor_, Longest[variance : __ ? BooleanQ], args___] := IndexArray[tensor, {variance}, args]

IndexArray[tensor_, shape_Shape ? ShapeQ] := IndexArray[tensor, shape, {}, {}]

IndexArray[tensor_, shape_Shape ? ShapeQ, params_List] := IndexArray[tensor, shape, params, {}]

IndexArray[tensor_, shape_Shape ? ShapeQ, name : Except[_List]] := IndexArray[tensor, shape, {}, {}, name]


ia_IndexArray /; System`Private`HoldNotValidQ[ia] && IndexArrayQ[Unevaluated[ia]] :=
    System`Private`SetNoEntry[System`Private`HoldSetValid[ia]]



(* Properties *)

(m_IndexArray ? IndexArrayQ)[prop_String | prop_String[args___]] /; MemberQ[IndexArray["Properties"], prop] := Prop[m, prop, args]

IndexArray["Properties"] := Union @ Join[
    {
        "Properties", "Array", "Tensor", "Shape", "Parameters", "Assumptions", "Name", "Dimension", "Symmetry", "Symbol", "Icon"
    },
    Shape["Properties"]
]

Prop[_, "Properties"] := IndexArray["Properties"]

Prop[IndexArray[array_, ___], "Array" | "Tensor"] := array

Prop[IndexArray[_, shape_, ___], "Shape"] := shape

Prop[IndexArray[_, _, params_, ___], "Parameters"] := params

Prop[IndexArray[_, _, _, assumptions_, ___], "Assumptions"] := DeleteCases[assumptions, _ ? BooleanQ]

Prop[IndexArray[_, _, _, _, name_, ___], "Name"] := name

Prop[ia_, "Name"] := ArrayName[ia["Array"]]


Prop[ia_, "Dimension"] := Times @@ ia["Dimensions"]

Prop[ia_, "Symmetry"] := ArraySymmetry[ia["Array"]]


Prop[ia_, "Symbol"] := Block[{
    name = ia["Name"],
    indices = ia["Shape"]["Indices"],
    indexNames,
    dims
},
    indexNames = ia["Names"];
    dims = Through[indices["SignedDimension"]];
    indices = MapThread[
        {name, sign, view} |-> Tooltip[
            Switch[sign,
                1, Superscript["", name],
                -1, Subscript["", name],
                _, Superscript["", Style[name, Opacity[.3]]]
            ],
            view
        ],
        {indexNames, Through[indices["Sign"]], Through[indices["View"]]}
    ];
    If[ MatchQ[name, _Function],
        name @@ indices,
        Row[{
            Tooltip[Replace[name, None -> \[FormalCapitalT]], ia["SignedDimensions"]],
            Splice @ Riffle[indices, Replace[Partition[Thread[{StringLength /@ ToString /@ indexNames, dims}], 2, 1], {{{n_, s1_}, {m_, s2_}} /; s1 == s2 && (n > 1 || m > 1) :> "\[ThinSpace]", _ -> ""}, 1]]
        }]
    ]
]
   

squareDimensions[d_, limit_ : 10] := If[IntegerQ[d], With[{w = Floor[Sqrt[d]]}, Clip[{w, If[w == 0, 0, Ceiling[d / w]]}, {1, limit}]], {limit, limit}]

Prop[ia_, "Icon", limit_Integer : 10] := MatrixPlot[
    Map[
        Replace[{x_ ? (Not @* NumericQ) :> BlockRandom[RandomComplex[], RandomSeeding -> Hash[x]], x_ :> N[x]}],
        Replace[
            Normal[ia["Array"]],
            {
                v_ ? VectorQ :> If[ia["SignedDimensions"][[1]] > 0, Map[List], List] @ v[[;; UpTo[limit]]],
                m_ ? MatrixQ :> m[[;; UpTo[limit], ;; UpTo[limit]]],
                t_ ? ArrayQ :> ArrayReshape[t, squareDimensions[ia["Dimension"], limit]],
                _ :> BlockRandom[RandomReal[{-1, 1}, squareDimensions[ia["Dimension"], limit]], RandomSeeding -> Hash[ia]]
            }
        ],
        {2}
    ],
    ImageSize -> Dynamic[{Automatic, 3.5 * (CurrentValue["FontCapHeight"] / AbsoluteCurrentValue[Magnification])}],
    Frame -> False,
    FrameTicks -> None
]

Prop[ia_, prop_String] /; MemberQ[Shape["Properties"], prop] := ia["Shape"][prop]

Prop[_, prop_String, ___] := Missing[prop]


(* UpValues *)

applyIndexArray[f_, ia_IndexArray ? IndexArrayQ] := IndexArray[f[ia["Array"]], ia["Shape"], ia["Parameters"], ia["Assumptions"], ia["Name"]]

IndexArray /: Normal[ia_IndexArray ? IndexArrayQ] := Normal[ia["Tensor"]]

IndexArray /: Dimensions[ia_IndexArray ? IndexArrayQ] := ia["Dimensions"]

IndexArray /: SquareMatrixQ[ia_IndexArray ? IndexArrayQ] := MatchQ[Dimensions[ia], {x_, x_}]

IndexArray /: Inverse[ia_IndexArray ? IndexArrayQ] /; SquareMatrixQ[ia] := IndexArray[
    Inverse[Normal[ia["Tensor"]]],
    Minus /@ ia["Shape"],
    ia["Parameters"],
    ia["Assumptions"],
    ia["Name"]
]

IndexArray /: Transpose[ia_IndexArray ? IndexArrayQ, perm : {___Integer} | _ ? PermutationCyclesQ : {2, 1}] := If[
    ZeroArrayQ[ia["Array"]],
    ia,
    IndexArray[
        ArrayTranspose[ia["Array"], perm],
        Permute[ia["Indices"], perm],
        ia["Parameters"],
        ia["Assumptions"],
        ia["Name"]
    ]
]

IndexArray /: D[ia_IndexArray ? IndexArrayQ, i_] := With[{params = ia["Parameters"]},
 	IndexArray[
  		D[ia["Array"], {params}],
        Append[ia["Indices"], Dimension[- Length[params], PartialD[i], params]],
        params, ia["Assumptions"], ia["Name"]
  	]
]

IndexArray /: Times[ia_IndexArray ? IndexArrayQ, xs___] :=
 	IndexArray[
        Times[ia["Array"], xs],
        ia["Shape"], ia["Parameters"], ia["Assumptions"], 
        Times[xs] ia["Name"]
    ]

IndexArray /: Plus[ias__IndexArray] := Block[{
   	indices = Through[{ias}["FreeIndices"]],
   	setIndices, newTensors
 },
  	(
        setIndices = {ias}[[1]]["FreeIndices"];
        newTensors = # @@ setIndices & /@ {ias};
        IndexTensor[
            Total[Through[newTensors["Array"]]],
            setIndices,
            DeleteDuplicates @ Catenate[Through[{ias}["Parameters"]]],
            DeleteDuplicates @ Catenate[Through[{ias}["Assumptions"]]],
            Total[Through[{ias}["Name"]]]
        ]
    ) /; SameQ @@ Sort /@ Map[{#["Name"], #["Dimension"]} &, indices, {2}]
]

IndexArray /: Equal[ia__IndexArray ? IndexArrayQ] := Equal @@ Through[{ia}["Array"]]


(* General fallback *)

ia : IndexArray[t_, arg_, params_, assumptions_List, args___] /; ! IndexArrayQ[Unevaluated[ia]] := Enclose @ With[
    {dims = Assuming[assumptions, ArrayDimensions[t]]},
    {shape = ConfirmBy[If[ShapeQ[arg], If[Shape[dims] == arg, arg, Shape[dims]], Shape[Shape[dims], arg]], ShapeQ]},
    IndexArray[t, shape, ToList[params], assumptions, args]
]

ia : IndexArray[t_, arg_, params_, name_, args___] /; ! IndexArrayQ[Unevaluated[ia]] := IndexArray[t, arg, params, {}, name, args]

ia : IndexArray[t_, arg_, args___] /; ! IndexArrayQ[Unevaluated[ia]] := Enclose @ With[{tensorShape = Shape[ArrayDimensions[t]]}, {shape = Shape[tensorShape, arg]},
    If[ShapeQ[shape], IndexArray[t, shape, args], IndexArray[t, tensorShape, arg, args]]
]

IndexArray[t_] := IndexArray[t, Shape[ArrayDimensions[t]], {}, {}]

(* ia : IndexArray[_, shape_, args___] /; ! IndexArrayQ[Unevaluated[ia]] := Which[
    ! ShapeQ[shape],
    Failure["IndexArray", <|"MessageTemplate" -> "Wrong shape specification: ``", "MessageParameters" -> {shape}|>]
    ,
    True,
    Failure["IndexArray", <|"MessageTemplate" -> "Failed to construct ``", "MessageParameters" -> HoldForm[ia]|>]
] *)


(* Index juggling *)

(ia : _IndexArray ? IndexArrayQ)[[is__]] ^:= IndexPart[ia, {is}]

(ia : _IndexArray ? IndexArrayQ)[is___] := IndexJuggling[ia, {is}]


(* Formatting *)

IndexArray /: MakeBoxes[ia_IndexArray /; IndexArrayQ[Unevaluated[ia]], TraditionalForm] := With[{
    boxes = ToBoxes[Normal[ia], TraditionalForm]
},
    InterpretationBox[
        boxes,
        ia
    ]
]

IndexArray /: MakeBoxes[ia_IndexArray /; IndexArrayQ[Unevaluated[ia]], form_] := 
    BoxForm`ArrangeSummaryBox["IndexArray", ia, ia["Icon"],
        {
            {
                BoxForm`SummaryItem[{"Symbol: ", ia["Symbol"]}],
                BoxForm`SummaryItem[{"Dimensions: ", ia["Dimensions"]}]
            },
            {
                BoxForm`SummaryItem[{"Parameters: ", ia["Parameters"]}]
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Symmetry: ", ia["Symmetry"]}],
                BoxForm`SummaryItem[{"Assumptions: ", ia["Assumptions"]}]
            }
        },
        form,
        "Interpretable" -> Automatic
    ]
    
