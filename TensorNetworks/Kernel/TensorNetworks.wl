Package["Wolfram`TensorNetworks`"]

PackageExport[GreedyContractionPath]
PackageExport[OptimalContractionPath]

PackageScope[extractContractionParameters]



ClearAll["Wolfram`TensorNetworks`*", "Wolfram`TensorNetworks`**`*"]

(* Rust optimizers, built by `cargo wl build` into Binaries/Cotengra-<SystemID>/;
   its generated Functions.wl gives <|"name" -> function, ...|> with WXF built in. *)

libraryLoaderFile := FileNameJoin[{
	PacletObject["Wolfram/TensorNetworks"]["Location"],
	"Binaries", "Cotengra-" <> $SystemID, "Functions.wl"
}]

(* wolfram-serialize reads a bool only from a symbol spelled out as
   System`True or System`False, while BinarySerialize writes System` symbols
   without their context. Each loaded function is a Composition that applies
   BinarySerialize to the argument list; serializeArguments takes its place.
   It writes the argument list itself and serializes each argument with
   BinarySerialize, except a Boolean, alone or as {"Some", b}, whose symbol
   is spelled out in full. Only whole arguments are rewritten, never bytes
   inside another value. A WXF symbol token is the byte 115 ("s"), the name
   length and the name; a function token is 102 ("f"), the argument count
   and the head. Both counts are one byte here, since every name and
   argument list is shorter than 128. *)
wxfSymbolToken[name_String] := Join[{115, StringLength[name]}, ToCharacterCode[name, "UTF8"]]

wxfArgument[b : True | False] := wxfSymbolToken["System`" <> ToString[b]]
wxfArgument[{"Some", b : True | False}] := Join[{102, 2}, wxfSymbolToken["List"], wxfArgument["Some"], wxfArgument[b]]
(* BinarySerialize output starts with the two header bytes "8:". *)
wxfArgument[x_] := Drop[Normal @ BinarySerialize[x], 2]

serializeArguments[args_List] := ByteArray @ Join[
	{56, 58, 102, Length[args]},
	wxfSymbolToken["List"],
	Catenate[wxfArgument /@ args]
]

libraryFunctions := libraryFunctions = Replace[
	If[ FileExistsQ[libraryLoaderFile], Get[libraryLoaderFile], $Failed], {
	functions_ ? AssociationQ :>
		Association @ KeyValueMap[
			#1 -> Composition[
				Replace[LibraryFunctionError[error_, code_] :>
					Failure["RustError", <|
						"MessageTemplate" -> "Rust error: `` (``)",
						"MessageParameters" -> {error, code},
					"Error" -> error, "ErrorCode" -> code, "Function" -> #1
				|>]
			],
			#2 /. HoldPattern[BinarySerialize] -> serializeArguments
		] &,
		functions
	],
	failure_ :> Function @ Function @ Failure["LibraryLoadError", <|
		"MessageTemplate" -> "No Cotengra library package for ``; prebuild it with build_all_targets.sh",
		"MessageParameters" -> {$SystemID},
		"Return" -> failure
	|>]
}
]

(* WXF boundary: Vec<u32> from a packed array (ByteArray[{}] when empty), jagged lists as
   (indices, lengths), Option in wolfram-serialize's enum encoding. *)
indexArray[{}] := ByteArray[{}]
indexArray[list_List] := NumericArray[list, "UnsignedInteger32"]
option[None] := "None"
option[value_] := {"Some", value}


Options[GreedyContractionPath] = {
    "MemoryWeight" -> None,
    "Temperature" -> None,
    "MaxNeighbors" -> None,
    "RandomSeed" -> None,
    "PreSimplify" -> None,
    "FixedIndexing" -> None
};

GreedyContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    opts : OptionsPattern[]
] := GreedyContractionPath[
    input, output, sizeDict,
    OptionValue["MemoryWeight"],
    OptionValue["Temperature"],
    OptionValue["MaxNeighbors"],
    OptionValue["RandomSeed"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

GreedyContractionPath[
	input : {{___Integer}...},
	output : {___Integer},
	sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
	costMod : _ ? NumericQ | None : None,
	temperature : _ ? NumericQ | None : None,
	maxNeighbors : _Integer | None : None,
    seed : _Integer | None : None,
	simplify : True | False | None : None,
	useSSA : True | False | None : None
] := Block[{path},
	Enclose[
		path = Confirm @ libraryFunctions["optimize_greedy"][
			indexArray @ Catenate[input],
			indexArray[Length /@ input],
			indexArray @ output,
			N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1],
			option @ N[costMod],
			option @ N[temperature],
			option @ maxNeighbors,
			option @ seed,
			option @ simplify,
			option @ useSSA
		];
		path + 1
	]
]

Options[OptimalContractionPath] = {
    Method -> "size",
    "PruningThreshold" -> None,
    "AllowOuterProducts" -> None,
    "PreSimplify" -> None,
    "FixedIndexing" -> None
};

(* Pattern using Method option - must come before positional pattern *)
OptimalContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    opts : OptionsPattern[]
] := OptimalContractionPath[
    input, output, sizeDict,
    OptionValue[Method],
    OptionValue["PruningThreshold"],
    OptionValue["AllowOuterProducts"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

(* Pattern with positional minimize for backward compatibility *)
OptimalContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    minimize : _String | None,
    opts : OptionsPattern[]
] := OptimalContractionPath[
    input, output, sizeDict, minimize,
    OptionValue["PruningThreshold"],
    OptionValue["AllowOuterProducts"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

OptimalContractionPath[
	input : {{___Integer}...},
	output : {___Integer},
	sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
	minimize : _String | None : None,
	costCap : _ ? NumericQ | None : None,
	searchOuter : True | False | None : None,
	simplify : True | False | None : None,
	useSSA : True | False | None : None
] := Block[{path},
	Enclose[
		path = Confirm @ libraryFunctions["optimize_optimal"][
			indexArray @ Catenate[input],
			indexArray[Length /@ input],
			indexArray @ output,
			N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1],
			option @ minimize,
			option @ N[costCap],
			option @ searchOuter,
			option @ simplify,
			option @ useSSA
		];
		path + 1
	]
]

(* scalars only: any order will do, and the optimizers reject an empty size table *)
GreedyContractionPath[input : {{} ...}, {}, sizeDict_Association /; sizeDict === <||>, ___] :=
    ConstantArray[{1, 2}, Max[Length[input] - 1, 0]]

OptimalContractionPath[input : {{} ...}, {}, sizeDict_Association /; sizeDict === <||>, ___] :=
    ConstantArray[{1, 2}, Max[Length[input] - 1, 0]]

(* Internal helper for parameter extraction.
   A hyperedge is one einsum index: each group maps to one representative.
   Dispatch tables, not rule lists (quadratic). Block, not Module or Enclose: those walk
   the spliced-in data, which for a hyperedge network repeats every group at every slot. *)
extractContractionParameters[data : KeyValuePattern[{
    "Dimensions" -> _,
    "Indices" -> _,
    "Contractions" -> _
}]] := Block[{
    tensorIndices = data["Indices"], dimensions, groups, rules, indices, normalIndices, input, output
},
    dimensions = AssociationThread[Catenate[tensorIndices], Catenate[data["Dimensions"]]];
    groups = contractionGroups[data];
    If[ AllTrue[groups, Equal @@ Lookup[dimensions, #] &],
        rules = Dispatch @ Catenate[Thread[Most[#] -> Last[#]] & /@ groups];
        dimensions = KeyMap[Replace[rules], dimensions];
        indices = Replace[tensorIndices, rules, {2}];
        normalIndices = Dispatch @ Thread[# -> Range[Length[#]]] & [Union @@ indices];
        input = Replace[indices, normalIndices, {2}];
        output = Replace[plannedOutput[data, rules], normalIndices, 1];
        dimensions = KeyMap[Replace[normalIndices], dimensions];
        {input, output, dimensions}
        ,
        Failure["DimensionMismatch", <|
            "MessageTemplate" -> "The slots of contracted indices `1` do not all have the same dimension.",
            "MessageParameters" -> {Select[groups, ! Equal @@ Lookup[dimensions, #] &]}
        |>]
    ]
]

(* Slot groups that form one einsum index: by label for TensorNetworkData,
   from contraction pairs for graph data; both agree on binary networks. *)
contractionGroups[data_] := If[
    KeyExistsQ[data, "Hyperedges"],
    Select[Values[GroupBy[Catenate[data["Indices"]], Last]], Length[#] > 1 &],
    DeleteDuplicates @ Cases[Catenate[data["Contractions"]], {_, __}]
]

(* Output a path is planned for: the unclaimed slots for plain bonds, else the declared
   output by label via its group's representative. One definition: two clauses would
   overlap, and the kernel doesn't keep their order. *)
plannedOutput[data_, rules_] := With[{
    hyperedges = Lookup[data, "Hyperedges", None],
    freeIndices = Lookup[data, "FreeIndices", None]
},
    If[ ListQ[hyperedges] && ListQ[freeIndices] && ! plainBondsQ[hyperedges, freeIndices],
        Lookup[
            Association[Last[#] -> Replace[#, rules] & /@ Catenate[data["Indices"]]],
            freeIndices
        ],
        Cases[Catenate[data["Contractions"]], Except[_List]]
    ]
]

(* every shared label a two-slot bond, output = labels carried once *)
plainBondsQ[hyperedges_, freeIndices_] := With[{counts = Counts[Catenate[hyperedges]]},
    AllTrue[counts, # <= 2 &] && Sort[freeIndices] === Sort[Keys[Select[counts, # == 1 &]]]
]

extractContractionParameters[net_Graph ? TensorNetworkGraphQ] :=
    extractContractionParameters[TensorNetworkGraphData[net]]

(* Planned over the network's own tensors, hyperedges included (no spiders);
   use BinaryTensorNetwork to plan the binarized network. *)
extractContractionParameters[net_TensorNetwork ? TensorNetworkQ] :=
    extractContractionParameters[TensorNetworkData[net]]

(* `"FixedIndexing" -> True` puts the Rust path in SSA form (positions > input length).
   CanonicalPath assumes the opt_einsum convention and fails with `Delete::partw`
   on SSA positions, so we skip the canonicalize step in that case. *)
fixedIndexingQ[args___] := MemberQ[{args}, ("FixedIndexing" -> True) | (True /; False)] ||
    Cases[{args}, ("FixedIndexing" -> v_) :> TrueQ[v]] === {True}
maybeCanonicalize[result_, args___] :=
    If[fixedIndexingQ[args] || !MatchQ[result, _List ? PathQ], result, CanonicalPath[result]]

(* TensorNetwork input patterns *)
GreedyContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Graph input patterns *)
GreedyContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Association/data input patterns *)
GreedyContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Inactive TensorContract/Transpose input patterns *)
GreedyContractionPath[
    expr : IgnoringInactive @ HoldPattern @ TensorContract[TensorProduct[___], _],
    args___
] := GreedyContractionPath[TensorNetwork[expr], args]

GreedyContractionPath[
    expr : HoldPattern[Transpose[_, _Cycles]],
    args___
] := GreedyContractionPath[TensorNetwork[expr], args]

OptimalContractionPath[
    expr : IgnoringInactive @ HoldPattern @ TensorContract[TensorProduct[___], _],
    args___
] := OptimalContractionPath[TensorNetwork[expr], args]

OptimalContractionPath[
    expr : HoldPattern[Transpose[_, _Cycles]],
    args___
] := OptimalContractionPath[TensorNetwork[expr], args]

