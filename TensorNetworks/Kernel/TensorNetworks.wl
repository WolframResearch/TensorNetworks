Package["Wolfram`TensorNetworks`"]

PackageExport[GreedyContractionPath]
PackageExport[OptimalContractionPath]



ClearAll["Wolfram`TensorNetworks`*", "Wolfram`TensorNetworks`**`*"]

pacletInstalledQ[paclet_, version_] := AnyTrue[Through[PacletFind[paclet]["Version"]], ResourceFunction["VersionOrder"][#, version] <= 0 &]

libraryFunctions := libraryFunctions = (
	If[ ! pacletInstalledQ["ExternalEvaluate", "38.0.1"],
		PacletInstall["ExternalEvaluate"]
	];
	If[ ! pacletInstalledQ["PacletExtensions", "40.0.0"],
		PacletInstall["https://www.wolframcloud.com/obj/nikm/PacletExtensions.paclet"]
	];
	Needs["ExtensionCargo`"];
	Replace[
		ExtensionCargo`CargoLoad[
			PacletObject["Wolfram/TensorNetworks"],
			"Functions"
		],
		Except[_ ? AssociationQ] :> Replace[
			ExtensionCargo`CargoBuild[PacletObject["Wolfram/TensorNetworks"]], {
				f : Except[{__ ? FileExistsQ}] :> Function @ Function @ Failure["CargoBuildError", <|
						"MessageTemplate" -> "Cargo build failed",
						"Return" -> f
					|>],
				files_ :> Replace[
					ExtensionCargo`CargoLoad[files, "Functions"],
					f : Except[_ ? AssociationQ] :>
						Function @ Function @ Failure["CargoLoadError", <|
							"MessageTemplate" -> "Cargo load failed",
							"Return" -> f
						|>]
				]
			}
		]
	]
) // Replace[{
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
			#2
		] &,
		functions
	]
}
]


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
] := Block[{ds = Developer`DataStore, path},
	Enclose[
		path = List @@ List @@@ Confirm @ libraryFunctions["optimize_greedy"][
			ds @@ ds @@@ input,
			ds @@ output,
			ds @@ ds @@@ Normal[N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1]],
			ds @ Replace[N[costMod], None -> Sequence[]],
			ds @ Replace[N[temperature], None -> Sequence[]],
			ds @ Replace[maxNeighbors, None -> Sequence[]],
			ds @ Replace[seed, None -> Sequence[]],
			ds @ Replace[simplify, None -> Sequence[]],
			ds @ Replace[useSSA, None -> Sequence[]]
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
] := Block[{ds = Developer`DataStore, path},
	Enclose[
		path = List @@ List @@@ Confirm @ libraryFunctions["optimize_optimal"][
			ds @@ ds @@@ input,
			ds @@ output,
			ds @@ ds @@@ Normal[N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1]],
			ds @ Replace[minimize, None -> Sequence[]],
			ds @ Replace[N[costCap], None -> Sequence[]],
			ds @ Replace[searchOuter, None -> Sequence[]],
			ds @ Replace[simplify, None -> Sequence[]],
			ds @ Replace[useSSA, None -> Sequence[]]
		];
		path + 1
	]
]

(* Internal helper for parameter extraction *)
extractContractionParameters[KeyValuePattern[{
    "Dimensions" -> tensorDimensions_,
    "Indices" -> tensorIndices_,
    "Contractions" -> contractions_
}]] := Enclose @ Block[{
    dimensions, pairs, rules, indices, normalIndices, input, output
},
    dimensions = AssociationThread[Catenate[tensorIndices], Catenate[tensorDimensions]];
    pairs = Cases[Catenate[contractions], {_, _}];
    rules = Rule @@@ pairs;
    ConfirmAssert[AllTrue[Partition[Lookup[dimensions, Catenate[pairs]], 2], Apply[Equal]]];
    dimensions = KeyMap[Replace[rules], dimensions];
    indices = Replace[tensorIndices, rules, {2}];
    normalIndices = Thread[# -> Range[Length[#]]] & [Union @@ indices];
    input = Replace[indices, normalIndices, {2}];
    output = Replace[Cases[Catenate[contractions], Except[{_, _}]], normalIndices, 1];
    dimensions = KeyMap[Replace[normalIndices], dimensions];
    {input, output, dimensions}
]

extractContractionParameters[net_Graph ? TensorNetworkGraphQ] :=
    extractContractionParameters[TensorNetworkGraphData[net]]

extractContractionParameters[net_TensorNetwork ? TensorNetworkQ] :=
    extractContractionParameters[TensorNetworkData[BinaryTensorNetwork[net]]]

(* TensorNetwork input patterns *)
GreedyContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        CanonicalPath @ GreedyContractionPath[Sequence @@ params, args]
    ]

OptimalContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        CanonicalPath @ OptimalContractionPath[Sequence @@ params, args]
    ]

(* Graph input patterns *)
GreedyContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        CanonicalPath @ GreedyContractionPath[Sequence @@ params, args]
    ]

OptimalContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        CanonicalPath @ OptimalContractionPath[Sequence @@ params, args]
    ]

(* Association/data input patterns *)
GreedyContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        CanonicalPath @ GreedyContractionPath[Sequence @@ params, args]
    ]

OptimalContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        CanonicalPath @ OptimalContractionPath[Sequence @@ params, args]
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

