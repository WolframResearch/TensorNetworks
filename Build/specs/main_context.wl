(* Specs for the 3 missing main-context pages. *)

{
  <|
    "Symbol"   -> "ContractIndices",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ContractIndices", "[", RowBox[{StyleBox["i", "TI"], ",", StyleBox["j", "TI"]}], "]"}],
       "returns the list of indices that would be contracted between two index sets i and j (their intersection)."}
    },
    "Examples" -> {
      {"Find shared indices between two tensors:",
       RowBox[{"ContractIndices", "[", RowBox[{RowBox[{"{", RowBox[{"\"i\"", ",", "\"j\""}], "}"}], ",", RowBox[{"{", RowBox[{"\"j\"", ",", "\"k\""}], "}"}]}], "]"}]},
      {"Disjoint index sets contract nothing:",
       RowBox[{"ContractIndices", "[", RowBox[{RowBox[{"{", RowBox[{"\"i\"", ",", "\"j\""}], "}"}], ",", RowBox[{"{", RowBox[{"\"k\"", ",", "\"l\""}], "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"PathIndexContractions", "TensorNetworkContractions", "EinsteinSummation"}
  |>,

  <|
    "Symbol"   -> "GreedyContractionPath",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"GreedyContractionPath", "[", StyleBox["tn", "TI"], "]"}],
       "finds a contraction path through the TensorNetwork tn using a greedy heuristic."},
      {RowBox[{"GreedyContractionPath", "[", StyleBox["graph", "TI"], "]"}],
       "finds a path for a TensorNetwork graph."},
      {RowBox[{"GreedyContractionPath", "[", RowBox[{StyleBox["inputs", "TI"], ",", StyleBox["output", "TI"], ",", StyleBox["sizeDict", "TI"]}], "]"}],
       "low-level form taking explicit per-tensor index lists, the output indices and a size-per-index Association."}
    },
    "Examples" -> {
      {"Find a greedy contraction path for a small random network:",
       RowBox[{"tn", "=", RowBox[{"RandomTensorNetwork", "[", RowBox[{RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}], ",", "3"}], "]"}]}],
       RowBox[{"GreedyContractionPath", "[", "tn", "]"}]},
      {"Tune the heuristic with the \"MemoryWeight\" option:",
       RowBox[{"GreedyContractionPath", "[", RowBox[{"tn", ",", RowBox[{"\"MemoryWeight\"", "->", "0.5"}]}], "]"}]},
      {"Use a fixed RandomSeed for reproducibility:",
       RowBox[{"GreedyContractionPath", "[", RowBox[{"tn", ",", RowBox[{"\"RandomSeed\"", "->", "42"}]}], "]"}]}
    },
    "SeeAlso" -> {"OptimalContractionPath", "TensorNetworkContraction", "TensorNetworkContract"}
  |>,

  <|
    "Symbol"   -> "OptimalContractionPath",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"OptimalContractionPath", "[", StyleBox["tn", "TI"], "]"}],
       "finds an optimal contraction path through the TensorNetwork tn via dynamic programming."},
      {RowBox[{"OptimalContractionPath", "[", StyleBox["graph", "TI"], "]"}],
       "finds an optimal path for a TensorNetwork graph."},
      {RowBox[{"OptimalContractionPath", "[", RowBox[{StyleBox["inputs", "TI"], ",", StyleBox["output", "TI"], ",", StyleBox["sizeDict", "TI"]}], "]"}],
       "low-level form taking explicit per-tensor index lists, the output indices and a size-per-index Association."}
    },
    "Examples" -> {
      {"Find an optimal path for a small random network (default Method -> \"size\"):",
       RowBox[{"tn", "=", RowBox[{"RandomTensorNetwork", "[", RowBox[{RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}], ",", "3"}], "]"}]}],
       RowBox[{"OptimalContractionPath", "[", "tn", "]"}]},
      {"Optimize for FLOP cost instead of intermediate-tensor size:",
       RowBox[{"OptimalContractionPath", "[", RowBox[{"tn", ",", RowBox[{"Method", "->", "\"flops\""}]}], "]"}]},
      {"Disallow outer products in the search:",
       RowBox[{"OptimalContractionPath", "[", RowBox[{"tn", ",", RowBox[{"\"AllowOuterProducts\"", "->", "False"}]}], "]"}]}
    },
    "SeeAlso" -> {"GreedyContractionPath", "TensorNetworkContraction", "TensorNetworkContract"}
  |>
}
