#!/usr/bin/env wolframscript

(* Surgical fixes for failing example inputs found by the harness. *)

docsDir = "/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols";

fixPage[path_String, transforms_List] := Module[{nb, before, after, edits = 0},
  nb = Get[path];
  Scan[
    Function[rule,
      before = nb;
      nb = ReplaceAll[nb, rule];
      If[before =!= nb, edits++]
    ],
    transforms
  ];
  If[edits > 0, Export[path, nb, "NB"]];
  edits
];

(* Universal replacements applied across all pages: *)
universal = {
  (* deprecated TensorNetworkFindContractionPath -> GreedyContractionPath *)
  RowBox[{"TensorNetworkFindContractionPath", rest___}] :> RowBox[{"GreedyContractionPath", rest}],
  (* anyObject["Hypergraph"] -> anyObject["Hyperedges"] (Hypergraph property is broken in kernel) *)
  RowBox[{name_String, "[", "\"Hypergraph\"", "]"}] :> RowBox[{name, "[", "\"Hyperedges\"", "]"}]
};

(* ToTensorNetworkGraph: Method -> "Symbolic" -> Method -> Symbolic *)
toTNGFix = {
  RowBox[{"Method", "->", "\"Symbolic\""}] :> RowBox[{"Method", "->", "Symbolic"}],
  RowBox[{"Method", "\[Rule]", "\"Symbolic\""}] :> RowBox[{"Method", "\[Rule]", "Symbolic"}]
};

(* PathIndexContractions[path, indices] where 'indices' is undefined symbol *)
(* Replace second arg with tn["Hyperedges"] which works *)
pathIxFix = {
  RowBox[{"PathIndexContractions", "[", RowBox[{"path", ",", "indices"}], "]"}] :>
    RowBox[{"PathIndexContractions", "[", RowBox[{"path", ",", RowBox[{"tn", "[", "\"Hyperedges\"", "]"}]}], "]"}]
};

pages = {
  {"BinaryTensorNetwork.nb",         universal},
  {"TensorNetwork.nb",               universal},
  {"ContractionTree.nb",             universal},
  {"PathToTreePath.nb",              universal},
  {"TensorNetworkContract.nb",       universal},
  {"TreePathQ.nb",                   universal},
  {"PathIndexContractions.nb",       Join[universal, pathIxFix]},
  {"ToTensorNetworkGraph.nb",        Join[universal, toTNGFix]}
};

Print["Applying surgical fixes..."];
Total[
  Map[
    Function[entry,
      Module[{path = FileNameJoin[{docsDir, entry[[1]]}], n},
        n = fixPage[path, entry[[2]]];
        Print["  ", entry[[1]], ": ", n, " edit(s)"];
        n
      ]
    ],
    pages
  ]
]
Quit[0]
