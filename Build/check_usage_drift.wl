#!/usr/bin/env wolframscript

(* For each .nb in the Symbols folder, compare its Usage cell against the
   current ::usage message. Flags drift (different number of overloads, or
   substantially different prose). *)

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];
Quiet @ Needs["Wolfram`TensorNetworks`IndexArray`"];
Quiet @ Needs["Wolfram`TensorNetworks`Symmetry`"];

docsDir = "/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols";

(* Resolve symbol from base name across all 3 contexts. *)
resolveSymbol[name_String] := Module[{candidates},
  candidates = Select[
    {"Wolfram`TensorNetworks`" <> name,
     "Wolfram`TensorNetworks`IndexArray`" <> name,
     "Wolfram`TensorNetworks`Symmetry`" <> name},
    NameQ
  ];
  If[candidates === {}, $Failed, ToExpression[First[candidates]]]
];

(* Count overload separators. ::usage uses \[Bullet] (\:2022); a Usage cell
   contains one ModInfo + one InlineFormula PER overload. *)

countUsageBullets[symbol_Symbol] := If[StringQ[symbol::usage],
  StringCount[symbol::usage, "\[Bullet]"], -1];

countUsageCellOverloads[nb_] := Module[{usageCells, modInfos},
  usageCells = Cases[nb, c_Cell?(MatchQ[#, Cell[_TextData, "Usage", ___]] &) :> c, Infinity];
  If[usageCells === {}, Return[-1]];
  (* Each overload is signaled by a "ModInfo" cell inside the TextData *)
  modInfos = Cases[First[usageCells], Cell["   ", "ModInfo", ___], Infinity];
  Length[modInfos]
];

drifts = Reap[
  Scan[
    Function[path,
      Module[{baseName = FileBaseName[path], sym, kernelN, nbN},
        sym = resolveSymbol[baseName];
        If[sym === $Failed, Sow[<|"Page" -> baseName, "Issue" -> "SymbolNotFound"|>],
          kernelN = countUsageBullets[sym];
          nbN     = countUsageCellOverloads[Get[path]];
          (* kernelN is "bullet count"; usually == overloadCount - 1 because
             the first form has no leading bullet. So compare nbN to kernelN+1. *)
          If[nbN > 0 && kernelN >= 0 && nbN =!= kernelN + 1,
            Sow[<|"Page" -> baseName,
              "KernelOverloads" -> kernelN + 1,
              "NotebookOverloads" -> nbN,
              "Issue" -> "OverloadCountMismatch"|>]
          ]
        ]
      ]
    ],
    FileNames["*.nb", docsDir]
  ]
][[2]];

drifts = If[drifts === {}, {}, First[drifts]];

Print["Pages checked: ", Length[FileNames["*.nb", docsDir]]];
Print["Drift candidates: ", Length[drifts]];
Scan[Print["  ", #["Page"], ": ",
  "kernel ", #["KernelOverloads"], " forms vs notebook ", #["NotebookOverloads"]] &,
  drifts];
Quit[0]
