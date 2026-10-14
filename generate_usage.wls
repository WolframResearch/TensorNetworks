#!/usr/bin/env wolframscript
(* Regenerate each context's Usage.wl from the reference pages' Usage cells *)

$root = DirectoryName[ExpandFileName[If[$InputFileName === "", NotebookFileName[], $InputFileName]]];

$symbolsDir = FileNameJoin[{$root, "TensorNetworks", "Documentation", "English", "ReferencePages", "Symbols"}];
$kernelDir = FileNameJoin[{$root, "TensorNetworks", "Kernel"}];

$defaultContext = "Wolfram`TensorNetworks`";
$contextFiles = <|
	"Wolfram`TensorNetworks`" -> FileNameJoin[{$kernelDir, "Usage.wl"}],
	"Wolfram`TensorNetworks`IndexArray`" -> FileNameJoin[{$kernelDir, "IndexArray", "Usage.wl"}],
	"Wolfram`TensorNetworks`Symmetry`" -> FileNameJoin[{$kernelDir, "Symmetry", "Usage.wl"}]
|>;

(* Symbol -> context map from the kernel sources *)

scanKernelFile[file_String] := Module[{text, ctx, syms},
	text = Import[file, "Text"];
	ctx = FirstCase[
		StringCases[text, "Package[\"" ~~ c : Except["\""] .. ~~ "\"]" :> c],
		_String, Missing[]
	];
	If[MissingQ[ctx], Return[{}]];
	syms = DeleteDuplicates @ StringCases[
		text,
		StartOfLine ~~ name : ((LetterCharacter | "$") ~~ (WordCharacter | "$") ...) ~~
			Except[WordCharacter | "$"] :> name
	];
	# -> ctx & /@ syms
];

kernelFiles = Select[FileNames["*.wl", $kernelDir, Infinity], FileBaseName[#] =!= "Usage" &];
$symContext = Association @@ Flatten[scanKernelFile /@ kernelFiles];

(* Box cleanup *)

cleanBoxes[ButtonBox[label_, ___]] := cleanBoxes[label]
cleanBoxes[FormBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[TagBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[InterpretationBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[TooltipBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[AdjustmentBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[FrameBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[StyleBox[x_, opts___]] := StyleBox[cleanBoxes[x], opts]
cleanBoxes[(h : RowBox | SubscriptBox | SuperscriptBox | SubsuperscriptBox |
		FractionBox | SqrtBox | RadicalBox | OverscriptBox |
		UnderscriptBox | UnderoverscriptBox | GridBox)[args__]] :=
	h @@ Replace[{args}, x_ :> cleanBoxes[x], {1}]
cleanBoxes[list_List] := cleanBoxes /@ list
cleanBoxes[other_] := other

(* Linear-box form, so formulas render like System` usage messages *)

(* Plain strings render the same without the wrapper and stay readable *)
asLinear[s_String] := s
asLinear[expr_] := "\!\(\*" <> ToString[expr, InputForm] <> "\)"

(* Cell -> usage-string fragments *)

cellToString[s_String] := s
cellToString[TextData[items_List]] := StringJoin[cellToString /@ items]
cellToString[TextData[item_]] := cellToString[item]
cellToString[Cell[_, "ModInfo", ___]] := ""
cellToString[Cell[BoxData[boxes_], "InlineFormula", ___]] := asLinear[cleanBoxes[boxes]]
cellToString[Cell[BoxData[boxes_], ___]] := asLinear[cleanBoxes[boxes]]
cellToString[Cell[content_, ___]] := cellToString[content]
cellToString[other_] := ToString[other, InputForm]

(* Post-process: one paragraph per line *)

formatUsage[raw_String] := Module[{s = raw, paragraphs},
	s = StringReplace[s, "\[LineSeparator]" -> " "];
	paragraphs = StringTrim /@ StringSplit[s, "\n"];
	paragraphs = StringTrim[StringTrim[#, WhitespaceCharacter]] & /@ paragraphs;
	paragraphs = DeleteCases[paragraphs, ""];
	StringRiffle[paragraphs, "\n"]
];

(* Per-file pipeline *)

processFile[file_String] := Module[{nb, cell, raw, text, name = FileBaseName[file], ctx},
	nb = Get[file];
	If[Head[nb] =!= Notebook, Print["Could not Get ", file]; Return[Nothing]];
	cell = FirstCase[nb, Cell[content_, "Usage", ___] :> content, Missing[], Infinity];
	If[MissingQ[cell], Print["No Usage cell in ", file]; Return[Nothing]];
	ctx = Lookup[$symContext, name, $defaultContext];
	If[! KeyExistsQ[$contextFiles, ctx],
		Print["Unknown context ", ctx, " for ", name, " - routing to default"];
		ctx = $defaultContext
	];
	raw = cellToString[cell];
	text = formatUsage[raw];
	ctx -> (name <> "::usage = " <> ExportString[text, "WL", "Comments" -> None])
];

symbolFiles = Sort @ FileNames["*.nb", $symbolsDir];
Print["Processing ", Length[symbolFiles], " files\:2026"];

entries = processFile /@ symbolFiles;
grouped = GroupBy[entries, First -> Last];

KeyValueMap[
	Function[{ctx, lines},
		Module[{outFile = $contextFiles[ctx], stream, content},
			content = StringRiffle[Prepend[Sort[lines], "Package[\"" <> ctx <> "\"]"], "\r\n\r\n\r\n"];
			stream = OpenWrite[outFile, CharacterEncoding -> "UTF-8"];
			WriteString[stream, content];
			Close[stream];
			Print["Wrote ", Length[lines], " usage messages to ", outFile];
		]
	],
	grouped
];

(* Stub files for contexts without symbols *)
KeyValueMap[
	Function[{ctx, outFile},
		If[! KeyExistsQ[grouped, ctx],
			Module[{stream},
				stream = OpenWrite[outFile, CharacterEncoding -> "UTF-8"];
				WriteString[stream, "Package[\"" <> ctx <> "\"]\r\n"];
				Close[stream];
				Print["Wrote empty stub to ", outFile];
			]
		]
	],
	$contextFiles
];
