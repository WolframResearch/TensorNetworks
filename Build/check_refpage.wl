#!/usr/bin/env wolframscript

(* Single-page example validator. Usage:
     wolframscript -file Build/check_refpage.wl <path_to_nb>
   Loads the TensorNetworks paclet, parses the .nb, evaluates every Input
   cell, prints per-input outcome. Exit 0 if all pass, 1 otherwise. *)

args = Rest @ $ScriptCommandLine;
If[Length[args] < 1, Print["Usage: ... <path_to_nb>"]; Quit[2]];
nbPath = args[[1]];
If[! FileExistsQ[nbPath], Print["Not found: ", nbPath]; Quit[2]];

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];
Quiet @ Needs["Wolfram`TensorNetworks`IndexArray`"];
Quiet @ Needs["Wolfram`TensorNetworks`Symmetry`"];

nb = Get[nbPath];
inputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];

Print["File:    ", nbPath];
Print["Inputs:  ", Length[inputs]];

failed = 0;
MapIndexed[
  Function[{box, idx},
    Module[{expr, val, outcome},
      expr = Quiet @ ToExpression[box, StandardForm, HoldComplete];
      If[Head[expr] =!= HoldComplete,
        outcome = "ParseFailed",
        val = TimeConstrained[
          Quiet @ Check[ReleaseHold[expr], $Failed],
          30,
          $TimedOut
        ];
        outcome = Which[
          val === $TimedOut, "Timeout",
          val === $Failed,   "Failed",
          True, "OK"
        ]
      ];
      Print["  In[", idx[[1]], "] ", outcome,
        If[outcome === "OK", "", " : " <> ToString[Short[val, 1]]]];
      If[outcome =!= "OK", failed++]
    ]
  ],
  inputs
];

Print[""];
If[failed > 0,
  Print["FAIL: ", failed, "/", Length[inputs]];
  Quit[1],
  Print["PASS: all ", Length[inputs], " inputs"];
  Quit[0]
]
