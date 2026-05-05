#!/usr/bin/env wolframscript

(* ============================================================
   Build/make_refpage.wl

   Build a paclet reference-page .nb by CLONING an existing
   template page and substituting the symbol-specific content.
   This guarantees structural and visual parity with the 46
   existing pages in TensorNetworks/Documentation/English/ReferencePages/Symbols/.

   Spec is a Wolfram Association of the form:

     <|
       "Symbol"      -> "ShapeQ",
       "Context"     -> "Wolfram`TensorNetworks`IndexArray`",
       "Template"    -> "PathQ",            (* file basename of an existing page *)
       "UsageBoxes"  -> {                   (* one InlineFormula per calling pattern *)
          { RowBox[{"ShapeQ", "[", StyleBox["expr", "TI"], "]"}],
            "yields True if expr is a valid Shape, and False otherwise." }
       },
       "Examples"    -> {                   (* list of {captionStr, inputBox, ...} *)
          { "Test a valid Shape:", RowBox[{"ShapeQ", "[", RowBox[{"Shape", "[", RowBox[{"2", ",", "3"}], "]"}], "]"}] }
       },
       "SeeAlso"     -> { "Shape", "Dimension" }
     |>

   Usage:
     wolframscript -file Build/make_refpage.wl <specFile> <outputDir>
   ============================================================ *)

args = Rest @ $ScriptCommandLine;
If[Length[args] < 2,
  Print["Usage: wolframscript -file Build/make_refpage.wl <specFile> <outputDir>"];
  Quit[2]
];
{specPath, outputDir} = args[[;; 2]];

If[! FileExistsQ[specPath], Print["spec not found: ", specPath]; Quit[2]];
If[! DirectoryQ[outputDir], Print["output dir not found: ", outputDir]; Quit[2]];

specsRaw = Get[specPath];
specs    = If[AssociationQ[specsRaw], {specsRaw}, specsRaw];

templatesDir = "/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols";

freshUUID[] := CreateUUID[];
freshCellID[] := RandomInteger[{10^8, 10^10}];

(* Walk the cloned template and freshen all CellID + ExpressionUUID values
   so the new file has unique identifiers. *)
freshenIDs[nb_] := nb /.
  {CellID -> _Integer :> CellID -> freshCellID[],
   ExpressionUUID -> _String :> ExpressionUUID -> freshUUID[]};

(* Build the Usage cell from per-form {boxes, descriptionString} pairs. *)
buildUsageCell[symbolName_String, uri_String, forms_List] := Module[{lines, n = Length[forms]},
  lines = MapIndexed[
    Function[{form, idx},
      With[{boxes = form[[1]], desc = form[[2]], isLast = idx[[1]] === n},
        {
          Cell["   ", "ModInfo", ExpressionUUID -> freshUUID[]],
          Cell[BoxData @ ReplaceAll[boxes,
            sym_String /; sym === symbolName :>
              ButtonBox[symbolName, BaseStyle -> "Link", ButtonData -> uri]],
            "InlineFormula", ExpressionUUID -> freshUUID[]],
          "\[LineSeparator]" <> desc <> If[isLast, "", " \[Bullet] \n"]
        }
      ]
    ],
    forms
  ];
  Cell[TextData @ Flatten[lines], "Usage",
    CellID -> freshCellID[], ExpressionUUID -> freshUUID[]]
];

(* Build a See Also cell from a list of paclet symbol names. *)
buildSeeAlsoCell[symbols_List] := Cell[TextData @ Riffle[
  Map[
    Cell[BoxData @ ButtonBox[#, BaseStyle -> "Link",
      ButtonData -> "paclet:WolframTensorNetworks/ref/" <> #],
      "InlineFormula", ExpressionUUID -> freshUUID[]] &,
    symbols
  ],
  Cell[TextData @ StyleBox[" \[FilledVerySmallSquare] ", "InlineSeparator"],
    ExpressionUUID -> freshUUID[]]
], "SeeAlso", CellID -> freshCellID[], ExpressionUUID -> freshUUID[]];

(* Build the Basic-Examples body — one ExampleText caption + Input cell(s) per group. *)
buildExamplesCells[examples_List] := Catenate @ MapIndexed[
  Function[{group, idx},
    Module[{caption = group[[1]], inputBoxes = Rest[group]},
      Flatten @ {
        Cell[caption, "ExampleText",
          CellID -> freshCellID[], ExpressionUUID -> freshUUID[]],
        MapIndexed[
          Cell[BoxData[#1], "Input",
            CellLabel -> "In[" <> ToString[#2[[1]]] <> "]:=",
            CellID -> freshCellID[], ExpressionUUID -> freshUUID[]] &,
          inputBoxes
        ]
      }
    ]
  ],
  examples
];

(* Substitute symbol name in all Categorization rows. *)
fixCategorization[nb_, oldSymbol_String, newSymbol_String, newContext_String] :=
  nb /.
    {Cell["Wolfram/TensorNetworks/ref/" <> oldSymbol, "Categorization", rest___] :>
       Cell["Wolfram/TensorNetworks/ref/" <> newSymbol, "Categorization", rest],
     Cell[_String, "Categorization", CellLabel -> "Context", rest___] :>
       Cell[newContext, "Categorization", CellLabel -> "Context", rest]
    };

(* Replace the ObjectName cell text. *)
fixObjectName[nb_, newSymbol_String] :=
  nb /. Cell[_String, "ObjectName", rest___] :> Cell[newSymbol, "ObjectName", rest];

(* Replace ExamplesInitialization Needs[...]. *)
fixInitNeeds[nb_, newContext_String] :=
  nb /.
    Cell[BoxData[RowBox[{"Needs", "[", _String, "]"}]], "ExampleInitialization", rest___] :>
      Cell[BoxData[RowBox[{"Needs", "[", "\"" <> newContext <> "\"", "]"}]],
        "ExampleInitialization", rest];

(* Replace the Usage cell with new content. *)
fixUsageCell[nb_, newCell_] :=
  nb /. _Cell?(MatchQ[#, Cell[_TextData, "Usage", ___]] &) :> newCell;

(* Replace the SeeAlso cell (the one inside SeeAlsoSection). *)
fixSeeAlsoCell[nb_, newCell_] :=
  ReplacePart[
    nb,
    First @ Position[nb, _Cell?(MatchQ[#, Cell[_, "SeeAlso", ___]] &), Infinity, 1] -> newCell
  ];

(* Replace the Basic Examples body — that's the run of cells AFTER the
   PrimaryExamplesSection cell and BEFORE the ExtendedExamplesSection
   (or before the Metadata if there's no extended block). *)
fixBasicExamples[nb_, newExampleCells_] := Module[{cells, primaryIdx, nextIdx},
  cells = nb[[1]];
  primaryIdx = First @ FirstPosition[cells,
    Cell[_, "PrimaryExamplesSection", ___], {0}, {1}];
  If[primaryIdx === 0, Return[nb]];
  (* Find the next "section-like" cell after PrimaryExamplesSection at top level. *)
  nextIdx = primaryIdx + 1;
  While[nextIdx <= Length[cells] &&
    ! MatchQ[cells[[nextIdx]], Cell[CellGroupData[{Cell[_, sect_String, ___], ___}, ___], ___] /;
      MemberQ[{"ExtendedExamplesSection", "MetadataSection"}, sect]],
    nextIdx++
  ];
  ReplacePart[nb, 1 -> Join[
    cells[[;; primaryIdx]],
    newExampleCells,
    cells[[nextIdx ;;]]
  ]]
];

(* ============================================================
   Run
   ============================================================ *)

buildPage[spec_Association] := Module[{
  oldSymbol, newSymbol, context, templatePath, nb, uri,
  usageCell, seeAlsoCell, exampleCells
},
  oldSymbol    = spec["Template"];
  newSymbol    = spec["Symbol"];
  context      = spec["Context"];
  templatePath = FileNameJoin[{templatesDir, oldSymbol <> ".nb"}];
  If[! FileExistsQ[templatePath],
    Print["template not found: ", templatePath]; Return[$Failed]
  ];
  uri = "paclet:WolframTensorNetworks/ref/" <> newSymbol;

  nb = Get[templatePath];
  nb = freshenIDs[nb];

  usageCell    = buildUsageCell[newSymbol, uri, spec["UsageBoxes"]];
  seeAlsoCell  = buildSeeAlsoCell[spec["SeeAlso"]];
  exampleCells = buildExamplesCells[spec["Examples"]];

  nb = fixObjectName[nb, newSymbol];
  nb = fixUsageCell[nb, usageCell];
  nb = fixSeeAlsoCell[nb, seeAlsoCell];
  nb = fixInitNeeds[nb, context];
  nb = fixCategorization[nb, oldSymbol, newSymbol, context];
  nb = fixBasicExamples[nb, exampleCells];
  nb
];

Print["Building ", Length[specs], " page(s) -> ", outputDir];
Scan[
  Function[spec,
    Module[{nb = buildPage[spec], path},
      If[nb === $Failed,
        Print["  FAIL: ", spec["Symbol"]];
        ,
        path = FileNameJoin[{outputDir, spec["Symbol"] <> ".nb"}];
        Export[path, nb, "NB"];
        Print["  wrote ", path]
      ]
    ]
  ],
  specs
];
Print["Done."];
Quit[0]
