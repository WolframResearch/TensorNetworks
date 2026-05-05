(* Audit-driven regenerations of existing pages with broken content. *)

{
  (* PathQ: the existing page uses the deprecated
     TensorNetworkFindContractionPath. Replace with a working example
     that uses GreedyContractionPath. *)
  <|
    "Symbol"   -> "PathQ",
    "Context"  -> "Wolfram`TensorNetworks`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"PathQ", "[", StyleBox["path", "TI"], "]"}],
       "yields True if path is a valid contraction path (a list of integer pairs), and False otherwise."}
    },
    "Examples" -> {
      {"Test that the output of GreedyContractionPath is a valid path:",
       RowBox[{"tn", "=", RowBox[{"RandomTensorNetwork", "[", RowBox[{RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}], ",", "3"}], "]"}]}],
       RowBox[{"path", "=", RowBox[{"GreedyContractionPath", "[", "tn", "]"}]}],
       RowBox[{"PathQ", "[", "path", "]"}]},
      {"A non-list is not a path:",
       RowBox[{"PathQ", "[", "42", "]"}]}
    },
    "SeeAlso" -> {"CanonicalPathQ", "TreePathQ", "GreedyContractionPath"}
  |>
}
