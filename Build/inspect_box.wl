#!/usr/bin/env wolframscript

(* Print the actual parsed box form of failing inputs so I can write
   a matching ReplaceAll pattern. *)

inspect[path_String, idx_Integer] := Module[{nb, inputs, box},
  nb = Get[path];
  inputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];
  inputs = Catenate @ Map[Function[b, If[MatchQ[b, _List], b, {b}]], inputs];
  box = inputs[[idx]];
  Print["==== ", FileBaseName[path], " #", idx, " ===="];
  Print[FullForm[box]];
  Print[]
];

inspect["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols/BinaryTensorNetwork.nb", 3];
inspect["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols/TensorNetwork.nb", 2];
inspect["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols/PathIndexContractions.nb", 3];
inspect["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols/ToTensorNetworkGraph.nb", 3];
Quit[0]
