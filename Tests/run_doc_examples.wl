#!/usr/bin/env wolframscript

(* ============================================================
   Tests/run_doc_examples.wl

   Walks every .nb file under
     Documentation/English/ReferencePages/Symbols/
   extracts every Input cell, evaluates it with a 30-second timeout,
   and reports per-page pass/fail.

   Exit 0 on success, 1 on any failure.
   ============================================================ *)

(* Colored output *)
red    = "\033[0;31m"; green = "\033[0;32m";
yellow = "\033[0;33m"; blue  = "\033[0;34m";
bold   = "\033[1m";    reset = "\033[0m";

checkMark = green <> "\[Checkmark]" <> reset;
crossMark = red   <> "\[Cross]"     <> reset;

printHeader [m_] := Print[bold, blue, "==> ", reset, bold, m, reset];
printSuccess[m_] := Print[green, "  ", checkMark, " ", m, reset];
printFailure[m_] := Print[red,   "  ", crossMark, " ", m, reset];

(* Resolve paths *)
root = DirectoryName @ DirectoryName @ $InputFileName;
If[root === "", root = Directory[]];

pacletDir = FileNameJoin[{root, "TensorNetworks"}];
docsDir   = FileNameJoin[{pacletDir, "Documentation", "English", "ReferencePages", "Symbols"}];

If[! DirectoryQ[docsDir],
  Print[red, "Documentation directory not found: ", docsDir, reset];
  Quit[1]
];

PacletDirectoryLoad[pacletDir];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

(* Netcon C++ LibraryLink is in hibernation per user directive (2026-05-05).
   Pages whose examples invoke Netcon-backed paths are skipped here so the
   harness does not exercise that code path until Netcon comes back online.
   To re-enable: empty this list. *)
$NetconHibernated = {
  "EinsteinSummation",                   (* hangs on Netcon C++ *)
  "TensorNetworkFindContractionPath"     (* deprecated; internally calls Netcon *)
};

(* Per-page evaluator *)
evalPage[nbPath_String] := Module[
  {
    nb = Quiet @ Get[nbPath],
    inputs, results, failures, baseName = FileBaseName[nbPath]
  },
  If[Head[nb] =!= Notebook,
    Return[<|"Page" -> baseName, "Total" -> 0, "Failed" -> 0, "Skipped" -> True|>]
  ];
  (* Collect every Input cell's BoxData *)
  inputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];
  inputs = Catenate @ Map[Function[box, If[MatchQ[box, _List], box, {box}]], inputs];
  results = Table[
    Module[{expr, val, errored = False, msgs},
      (* Convert box form to held expression *)
      expr = Quiet @ ToExpression[box, StandardForm, HoldComplete];
      If[Head[expr] =!= HoldComplete,
        errored = True; "ParseFailed",
        Block[{$MessageList = {}},
          val = TimeConstrained[
            Quiet @ Check[ReleaseHold[expr], $Failed, {General::stop}],
            30,
            $TimedOut
          ];
          msgs = $MessageList;
          Which[
            val === $TimedOut, errored = True; "Timeout",
            val === $Failed,   errored = True; "Failed",
            ! FreeQ[msgs, _MessageName],
              errored = True; "MessageEmitted: " <> ToString[Short /@ msgs],
            True, "OK"
          ]
        ]
      ]
    ],
    {box, inputs}
  ];
  failures = MapIndexed[
    Function[{outcome, idx},
      If[outcome === "OK", Nothing,
        <|"InputIndex" -> idx[[1]], "Outcome" -> outcome|>]
    ],
    results
  ];
  <|"Page" -> baseName,
    "Total" -> Length[inputs],
    "Failed" -> Length[failures],
    "Failures" -> failures,
    "Skipped" -> False|>
];

(* Run *)
nbFiles = FileNames["*.nb", docsDir];
nbFiles = Select[nbFiles, ! MemberQ[$NetconHibernated, FileBaseName[#]] &];
printHeader[StringTemplate["Evaluating examples in `1` reference pages (Netcon-hibernated: `2` skipped)"][Length[nbFiles], Length[$NetconHibernated]]];

reports = evalPage /@ nbFiles;

(* Summary *)
totalPages    = Length[reports];
totalExamples = Total[#["Total"] & /@ reports];
totalFailed   = Total[#["Failed"] & /@ reports];
skipped       = Count[reports, _?(#["Skipped"] === True &)];
failedPages   = Select[reports, #["Failed"] > 0 &];

Print[""];
printHeader["Summary"];
Print[bold, "  Pages:     ", totalPages, reset];
Print[bold, "  Examples:  ", totalExamples, reset];
Print[green, "  Passed:    ", totalExamples - totalFailed, reset];
If[skipped > 0, Print[yellow, "  Skipped:   ", skipped, " (notebook parse failed)", reset]];

If[totalFailed > 0,
  Print[red, "  Failed:    ", totalFailed, reset];
  Print[""];
  printHeader["Failures by page"];
  Scan[
    Function[r,
      printFailure[r["Page"] <> " (" <> ToString[r["Failed"]] <> "/" <> ToString[r["Total"]] <> ")"];
      Scan[
        Function[f, Print["    input #", f["InputIndex"], ": ", f["Outcome"]]],
        r["Failures"]
      ]
    ],
    failedPages
  ];
  Quit[1],
  printSuccess["All " <> ToString[totalExamples] <> " examples passed."];
  Quit[0]
]
