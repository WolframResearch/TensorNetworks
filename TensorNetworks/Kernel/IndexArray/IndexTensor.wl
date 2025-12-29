Package["Wolfram`TensorNetworks`IndexArray`"]

PackageExport[IndexTensorQ]
PackageExport[IndexTensor]

PackageScope[metricQ]



(* Validation *)

metricQ[ia_] := IndexArrayQ[ia] && With[{n = Length[ia["Parameters"]]}, MatchQ[ia["SignedDimensions"], {n, n} | {- n, - n}]]

indexTensorQ[IndexTensor[ia_IndexArray, gs : {({__Integer ? Positive} -> _IndexArray | None) ...}, ___]] :=
    IndexArrayQ[ia] && AllTrue[gs[[All, 2]], # === None || metricQ[#] &] &&
    With[{indices = ia["Indices"]},
        AllTrue[Catenate[gs[[All, 1]]], 0 < # <= Length[indices] &] && AllTrue[gs, #[[2]] === None || AllTrue[Through[Select[indices[[#[[1]]]], #["FreeQ"] &]["Dimension"]], EqualTo[#[[2]]["Dimensions"][[1]]]] &]
    ]

indexTensorQ[IndexTensor[g_IndexArray]] := metricQ[g]

indexTensorQ[___] := False


IndexTensorQ[it_IndexTensor] := System`Private`HoldValidQ[it] || indexTensorQ[Unevaluated[it]]

IndexTensorQ[___] := False


(* Mutation *)

IndexTensor[it_IndexTensor, args___] := With[{newArray = IndexArray[it["IndexArray"], args]},
    If[it["MetricQ"] && metricQ[newArray], IndexTensor[newArray], IndexTensor[newArray, it["Metrics"]]]
]


it_IndexTensor /; System`Private`HoldNotValidQ[it] && indexTensorQ[Unevaluated[it]] :=
    System`Private`SetNoEntry[System`Private`HoldSetValid[it]]


(* Properties *)

(it_IndexTensor ? IndexTensorQ)[prop_String | prop_String[args___]] := Prop[it, prop, args] = Prop[it, prop, args]

IndexTensor["Properties"] := Join[{"IndexArray", "Metrics", "MetricRules", "MetricQ", "ChristoffelSymbol"}, IndexArray["Properties"]]

Prop[_, "Properties"] := IndexTensor["Properties"]

Prop[IndexTensor[ia_, ___] ? IndexTensorQ, "IndexArray"] := ia

Prop[IndexTensor[_, g_] ? IndexTensorQ, "Metrics"] := g

Prop[IndexTensor[g_] ? IndexTensorQ, "Metrics"] := Sequence[]

Prop[it : IndexTensor[_], "MetricQ"] := metricQ[it["IndexArray"]]
Prop[_, "MetricQ"] := False

Prop[it_, "MetricRules"] := With[{metrics = If[it["MetricQ"], {Range[it["Rank"]] -> it["IndexArray"]}, it["Metrics"]]},
    Join[
        MapAt[If[#["SignedDimensions"][[1]] > 0, Inverse[#], #] &, metrics, {All, 2}],
        Values @ GroupBy[Thread[# -> it["Dimensions"][[#]]], #[[2]] &, #[[All, 1]] -> With[{dim = #[[1, 2]]}, Inverse @ IndexArray[IdentityMatrix[dim], Automatic, Array[\[FormalI], dim], "I"]] &] & @
            Complement[it["FreeIndexPositions"], Catenate[metrics[[All, 1]]]]
    ]
]

Prop[it_, prop_String, args___] /; MemberQ[IndexArray["Properties"], prop] := it["IndexArray"][prop, args]

Prop[it_, "Tensor"] := it["IndexArray"]["Array"]

Prop[it_, "Coordinates"] := it["Parameters"]

Prop[it_, "ChristoffelSymbol" | "ChristoffelSymbols"] := ChristoffelSymbols[it]

Prop[_, prop_String, ___] := Missing[prop]


(* General constructors *)

IndexTensor[arg : Except[_IndexArray | _IndexTensor]] := With[{ia = IndexArray[arg]}, If[metricQ[ia], IndexTensor[ia], IndexTensor[ia, {}]]]

IndexTensor[arg : Except[_IndexArray | _IndexTensor], args___] := IndexTensor[IndexArray[arg, args]]

IndexTensor[arg : Except[_IndexArray | _IndexTensor], args___, metric : _ ? metricQ | {({__Integer} -> _ ? metricQ) ..}] := IndexTensor[IndexArray[arg, args], metric]

IndexTensor[arg : Except[_IndexArray | _IndexTensor], args___, metric_ ? IndexTensorQ] /; metric["MetricQ"] := IndexTensor[IndexArray[arg, args], metric["IndexArray"]]

IndexTensor[ia_ ? IndexArrayQ, metric_ ? IndexArrayQ] /; metricQ[metric] := IndexTensor[ia, {ia["FreeIndexPositions"] -> metric}]

IndexTensor[ia_ ? IndexArrayQ] /; ! metricQ[ia] := IndexTensor[ia, {}]


(* UpValues *)

(it : _IndexTensor ? IndexTensorQ)[[is__]] ^:= IndexPart[it, {is}]

(it : _IndexTensor ? IndexTensorQ)[is___] := IndexJuggling[it, {is}]


Scan[
    Function[f,
        IndexTensor /: f[it_IndexTensor ? IndexTensorQ, args___] := f[it["IndexArray"], args]
    ],
    {Normal, Dimensions, SquareMatrixQ}
]

Scan[
    Function[f,
        IndexTensor /: f[it_IndexTensor ? IndexTensorQ, args___] := If[it["MetricQ"], IndexTensor[#], IndexTensor[#, it["Metrics"]]] & @ f[it["IndexArray"], args]
    ],
    {Inverse, Transpose}
]


IndexTensor /: D[it_IndexTensor, i_] /; it["MetricQ"] := D[it, i, it]

IndexTensor /: D[it_IndexTensor, i_, g_ ? IndexTensorQ /; g["MetricQ"]] :=
 	IndexTensor[
  		Inactive[D][it["Array"], {g["Coordinates"]}],
  		Append[PartialD /@ it["Indices"], Dimension[- Length[it["Coordinates"]], i]],
  		it["Coordinates"], it["Assumptions"], it["Name"],
  		Append[it["MetricRules"], {it["Size"] + 1} -> g["IndexArray"]]
  	]

IndexTensor /: Times[it_IndexTensor ? IndexTensorQ, xs___] :=
 	IndexTensor[
        Times[it["Array"], xs],
        it["Shape"], it["Parameters"], it["Assumptions"], 
        Times[xs] it["Name"],
        it["Metrics"]
    ]

IndexTensor /: Plus[its__IndexTensor] := Block[{
   	indices = Through[{its}["FreeIndices"]],
   	setIndices, newTensors
 },
  	(
        setIndices = {its}[[1]]["FreeIndices"];
        newTensors = # @@ setIndices & /@ {its};
        IndexTensor[
            Total[Through[newTensors["Array"]]],
            setIndices,
            DeleteDuplicates @ Catenate[Through[{its}["Parameters"]]],
            DeleteDuplicates @ Catenate[Through[{its}["Assumptions"]]],
            Total[Through[{its}["Name"]]],
            {its}[[1]]["Metrics"]
        ]
    ) /; SameQ @@ Sort /@ Map[{#["Name"], #["Dimension"]} &, indices, {2}]
]


IndexTensor /: Equal[it__IndexTensor ? IndexTensorQ] := Equal @@ Through[{it}["IndexArray"]] &&
    With[{metrics = Through[{it}["MetricRules"]]},
        And @@ Merge[KeyUnion[Catenate /@ Map[Thread] /@ metrics], Apply[Equal]]
    ]


(* Formatting *)

IndexTensor /: MakeBoxes[it_IndexTensor /; IndexTensorQ[Unevaluated[it]], TraditionalForm] := With[{
    boxes = ToBoxes[Normal[it], TraditionalForm]
},
    InterpretationBox[
        boxes,
        it
    ]
]
    

IndexTensor /: MakeBoxes[it_IndexTensor /; IndexTensorQ[Unevaluated[it]], form_] :=
    BoxForm`ArrangeSummaryBox["IndexTensor", it, it["Icon"],
        {
            {
                BoxForm`SummaryItem[{"Symbol: ", it["Symbol"]}],
                If[it["MetricQ"], BoxForm`SummaryItem[{"Metric"}], Nothing]
            },
            {
                BoxForm`SummaryItem[{"Dimensions: ", it["Dimensions"]}], 
                BoxForm`SummaryItem[{"Coordinates: ", it["Coordinates"]}]   
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Symmetry: ", it["Symmetry"]}],
                BoxForm`SummaryItem[{"Assumptions: ", it["Assumptions"]}]
            }
        },
        form,
        "Interpretable" -> Automatic
    ]


If[ $FrontEnd =!= Null,
    ResourceFunction["AddCodeCompletion"]["IndexTensor"][IndexTensor[]]
]

