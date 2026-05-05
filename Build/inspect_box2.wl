#!/usr/bin/env wolframscript

nb = Get["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols/BinaryTensorNetwork.nb"];
inputs = Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity];
inputs = Catenate @ Map[Function[b, If[MatchQ[b, _List], b, {b}]], inputs];
box = inputs[[3]];
Print["Length: ", Length[box]];
Print["Head:   ", Head[box]];
Print["Args characters: ", Map[{ToString[#], StringLength[ToString[#]]} &, List @@ box]];
Print["Args head/length: ", Map[{Head[#], StringLength[#]} &, List @@ box]];

(* Now test different patterns *)
test1 = MatchQ[box, RowBox[{"tn", "[", "Hypergraph", "]"}]];
test2 = MatchQ[box, RowBox[{"tn", "[", "\"Hypergraph\"", "]"}]];
test3 = MatchQ[box, RowBox[{"tn", "[", s_String, "]"}]];
Print["pattern Hypergraph (no quotes): ", test1];
Print["pattern \\\"Hypergraph\\\" (with quotes): ", test2];
Print["pattern any string: ", test3];

Quit[0]
