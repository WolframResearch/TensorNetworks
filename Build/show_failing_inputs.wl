#!/usr/bin/env wolframscript

(* Print the source of specific Input cells from a .nb file in InputForm,
   so I can read what each failing example is doing.

   Usage:
     wolframscript -file Build/show_failing_inputs.wl <nb_path> <i1,i2,...>
*)

args = Rest @ $ScriptCommandLine;
If[Length[args] < 2, Print["Usage: ... <nb_path> <indices,comma-separated>"]; Quit[2]];

nbPath = args[[1]];
indices = ToExpression /@ StringSplit[args[[2]], ","];

nb = Get[nbPath];
allInputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];
allInputs = Catenate @ Map[Function[box, If[MatchQ[box, _List], box, {box}]], allInputs];

Print["File: ", nbPath];
Print["Inputs total: ", Length[allInputs]];
Print[];

Scan[
  Function[i,
    If[1 <= i <= Length[allInputs],
      Module[{box = allInputs[[i]], expr},
        Print["===== Input #", i, " ====="];
        expr = Quiet @ ToExpression[box, StandardForm, HoldComplete];
        If[Head[expr] === HoldComplete,
          Print[ToString[#, InputForm] & @ First[Hold @@ expr]],
          Print["(parse failed; raw box form below)"];
          Print[ToString[box, InputForm]]
        ];
        Print[]
      ],
      Print["Index ", i, " out of range (1..", Length[allInputs], ")"];
    ]
  ],
  indices
];
Quit[0]
