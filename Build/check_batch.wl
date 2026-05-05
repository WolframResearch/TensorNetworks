#!/usr/bin/env wolframscript

(* Validate every Input in every .nb path passed as argument(s).
   Loads paclet once, then iterates. Exit 0 if all pass, 1 otherwise. *)

paths = Rest @ $ScriptCommandLine;
If[Length[paths] === 0, Print["Usage: ... <nb> [<nb> ...]"]; Quit[2]];

(* Netcon C++ LibraryLink is in hibernation per user directive (2026-05-05).
   Pages whose examples invoke Netcon-backed paths are skipped here so the
   harness does not exercise that code path until Netcon comes back online.
   To re-enable: empty this list. *)
$NetconHibernated = {
  "EinsteinSummation",                   (* hangs on Netcon C++ *)
  "TensorNetworkFindContractionPath"     (* deprecated; internally calls Netcon *)
};

paths = Select[paths, ! MemberQ[$NetconHibernated, FileBaseName[#]] &];
If[paths === {}, Print["No pages to check (all on Netcon-hibernation skip list)."]; Quit[0]];

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];
Quiet @ Needs["Wolfram`TensorNetworks`IndexArray`"];
Quiet @ Needs["Wolfram`TensorNetworks`Symmetry`"];

evalNB[nbPath_String] := Module[
  {nb, inputs, results, baseName = FileBaseName[nbPath]},
  Print["  ... loading ", baseName];
  nb = TimeConstrained[Quiet @ Get[nbPath], 30, $TimedOut];
  If[nb === $TimedOut,
    Print["  TIMEOUT loading ", baseName];
    Return[<|"Page" -> baseName, "Total" -> 0, "Failures" -> {<|"i" -> 0, "out" -> "LoadTimeout"|>}|>]
  ];
  (* Cap entire page eval at 90s wall time — pages with hundreds of examples
     still get covered, but a stuck input cannot stall the whole batch. *)
  pageStart = AbsoluteTime[];
  pageBudget = 90;
  inputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];
  (* Some Input cells contain BoxData[{a, b, c}] — a list of separate
     statement boxes. Flatten such groups into individual statements. *)
  inputs = Catenate @ Map[
    Function[box, If[MatchQ[box, _List], box, {box}]],
    inputs
  ];
  results = MapIndexed[
    Function[{box, idx},
      Module[{expr, val, outcome},
        If[AbsoluteTime[] - pageStart > pageBudget,
          (* Page wall-time budget exceeded — skip remaining inputs *)
          <|"i" -> idx[[1]], "out" -> "PageBudgetExceeded"|>,
          expr = Quiet @ ToExpression[box, StandardForm, HoldComplete];
          If[Head[expr] =!= HoldComplete,
            outcome = "ParseFailed",
            val = TimeConstrained[
              Quiet @ Check[ReleaseHold[expr], $Failed], 10, $TimedOut];
            outcome = Which[
              val === $TimedOut, "Timeout",
              val === $Failed,   "Failed",
              True, "OK"]
          ];
          <|"i" -> idx[[1]], "out" -> outcome|>
        ]
      ]
    ],
    inputs
  ];
  <|"Page" -> baseName, "Total" -> Length[inputs],
    "Failures" -> Select[results, #["out"] =!= "OK" &]|>
];

reports = evalNB /@ paths;
totalFails = Total[Length[#["Failures"]] & /@ reports];
totalIns   = Total[#["Total"] & /@ reports];

Scan[
  Function[r,
    If[Length[r["Failures"]] === 0,
      Print["  PASS  ", r["Page"], " (", r["Total"], " inputs)"],
      Print["  FAIL  ", r["Page"], " (", Length[r["Failures"]], "/", r["Total"], ")"];
      Scan[Print["         In[", #["i"], "]: ", #["out"]] &, r["Failures"]]
    ]
  ],
  reports
];

Print[""];
Print["Total: ", totalIns - totalFails, "/", totalIns, " passed across ", Length[paths], " pages."];
If[totalFails > 0, Quit[1], Quit[0]]
