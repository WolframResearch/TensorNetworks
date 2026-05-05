(* Regenerate pages whose Basic Examples lack a proper setup. *)

{
  <|
    "Symbol"   -> "PathIndexContractions",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"PathIndexContractions", "[", RowBox[{StyleBox["path", "TI"], ",", StyleBox["indices", "TI"]}], "]"}],
       "returns the sequence of index sets contracted at each step of a contraction path, given the per-tensor index lists."}
    },
    "Examples" -> {
      {"Find which indices are contracted at each step of a greedy path:",
       RowBox[{"tn", "=", RowBox[{"RandomTensorNetwork", "[", RowBox[{RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}], ",", "3"}], "]"}]}],
       RowBox[{"path", "=", RowBox[{"GreedyContractionPath", "[", "tn", "]"}]}],
       RowBox[{"PathIndexContractions", "[", RowBox[{"path", ",", RowBox[{"tn", "[", "\"Hyperedges\"", "]"}]}], "]"}]}
    },
    "SeeAlso" -> {"GreedyContractionPath", "ContractionTree", "PathToTreePath"}
  |>,

  <|
    "Symbol"   -> "ToTensorNetworkGraph",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ToTensorNetworkGraph", "[", StyleBox["tn", "TI"], "]"}],
       "converts a TensorNetwork object to a graph representation."},
      {RowBox[{"ToTensorNetworkGraph", "[", RowBox[{StyleBox["graph", "TI"]}], "]"}],
       "constructs a tensor network graph from a directed acyclic graph."}
    },
    "Examples" -> {
      {"Convert a tensor network to a graph:",
       RowBox[{"tn", "=", RowBox[{"RandomTensorNetwork", "[", RowBox[{RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}], ",", "3"}], "]"}]}],
       RowBox[{"ToTensorNetworkGraph", "[", "tn", "]"}]},
      {"Inspect the head of the resulting graph:",
       RowBox[{"Head", "[", RowBox[{"ToTensorNetworkGraph", "[", "tn", "]"}], "]"}]}
    },
    "SeeAlso" -> {"TensorNetworkGraphQ", "TensorNetworkIndexGraph", "TensorNetworkGraphData"}
  |>
}
