(* Specs for IndexArray core data types and index operations. *)

{
  <|
    "Symbol"   -> "Dimension",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"Dimension", "[", RowBox[{StyleBox["d", "TI"], ",", StyleBox["name", "TI"]}], "]"}],
       "represents a tensor index of size d with the given name. A negative size denotes a covariant (lower) index; positive denotes contravariant (upper)."},
      {RowBox[{"Dimension", "[", RowBox[{StyleBox["d", "TI"], ",", StyleBox["name", "TI"], ",", StyleBox["indices", "TI"]}], "]"}],
       "additionally records the explicit basis labels for the index."},
      {RowBox[{"Dimension", "[", RowBox[{StyleBox["d", "TI"], ",", StyleBox["name", "TI"], ",", StyleBox["indices", "TI"], ",", StyleBox["pos", "TI"]}], "]"}],
       "marks the index as contracted at the specified position pos."}
    },
    "Examples" -> {
      {"Construct a 3-dimensional index named i:",
       RowBox[{"Dimension", "[", RowBox[{"3", ",", "\"i\""}], "]"}]},
      {"Read back its size and sign:",
       RowBox[{RowBox[{"Dimension", "[", RowBox[{"3", ",", "\"i\""}], "]"}], "[", "\"Size\"", "]"}],
       RowBox[{RowBox[{"Dimension", "[", RowBox[{RowBox[{"-", "3"}], ",", "\"i\""}], "]"}], "[", "\"Sign\"", "]"}]}
    },
    "SeeAlso" -> {"DimensionQ", "Shape", "ShapeQ"}
  |>,

  <|
    "Symbol"   -> "Shape",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"Shape", "[", RowBox[{SubscriptBox[StyleBox["d", "TI"], "1"], ",", SubscriptBox[StyleBox["d", "TI"], "2"], ",", "\[Ellipsis]"}], "]"}],
       "represents an ordered sequence of Dimension objects describing the index structure of a tensor."},
      {RowBox[{"Shape", "[", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["d", "TI"], "1"], ",", SubscriptBox[StyleBox["d", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}], "]"}],
       "accepts a list of integer sizes or Dimension objects."},
      {RowBox[{"Shape", "[", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["d", "TI"], "1"], ",", "\[Ellipsis]"}], "}"}], ",", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["n", "TI"], "1"], ",", "\[Ellipsis]"}], "}"}], "]"}],
       "pairs integer sizes with index names; a negative name marks a lower index."}
    },
    "Examples" -> {
      {"Construct a Shape from integer sizes:",
       RowBox[{"Shape", "[", RowBox[{"2", ",", "3", ",", "4"}], "]"}]},
      {"Inspect dimensions and rank:",
       RowBox[{RowBox[{"Shape", "[", RowBox[{"2", ",", "3", ",", "4"}], "]"}], "[", "\"Dimensions\"", "]"}],
       RowBox[{RowBox[{"Shape", "[", RowBox[{"2", ",", "3", ",", "4"}], "]"}], "[", "\"Rank\"", "]"}]}
    },
    "SeeAlso" -> {"ShapeQ", "Dimension", "IndexArray"}
  |>,

  <|
    "Symbol"   -> "IndexArray",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexArray", "[", StyleBox["tensor", "TI"], "]"}],
       "wraps tensor as an IndexArray with shape derived from ArrayDimensions[tensor]."},
      {RowBox[{"IndexArray", "[", RowBox[{StyleBox["tensor", "TI"], ",", StyleBox["shape", "TI"]}], "]"}],
       "wraps tensor with the given Shape, recording named index structure and variance."},
      {RowBox[{"IndexArray", "[", RowBox[{StyleBox["ia", "TI"], ",", StyleBox["shape", "TI"]}], "]"}],
       "returns the IndexArray ia with its Shape replaced."}
    },
    "Examples" -> {
      {"Wrap a numerical array as an IndexArray:",
       RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}]},
      {"Recover its dimensions:",
       RowBox[{RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], "[", "\"Dimensions\"", "]"}]}
    },
    "SeeAlso" -> {"IndexArrayQ", "Shape", "IndexTensor"}
  |>,

  <|
    "Symbol"   -> "IndexTensor",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexTensor", "[", StyleBox["ia", "TI"], "]"}],
       "wraps the IndexArray ia as an IndexTensor with no associated metrics."},
      {RowBox[{"IndexTensor", "[", RowBox[{StyleBox["ia", "TI"], ",", StyleBox["metric", "TI"]}], "]"}],
       "attaches a metric to all free index positions, enabling automatic raising and lowering."}
    },
    "Examples" -> {
      {"Promote a plain IndexArray to an IndexTensor:",
       RowBox[{"IndexTensor", "[", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], "]"}]},
      {"Test the result:",
       RowBox[{"IndexTensorQ", "[", RowBox[{"IndexTensor", "[", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "]"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"IndexTensorQ", "IndexArray", "MetricTensor"}
  |>,

  <|
    "Symbol"   -> "MetricTensor",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"MetricTensor", "[", StyleBox["name", "TI"], "]"}],
       "returns a built-in metric tensor by name, e.g. \"Euclidean\", \"Minkowski\", \"Schwarzschild\", \"Kerr\", \"FLRW\"."},
      {RowBox[{"MetricTensor", "[", RowBox[{StyleBox["matrix", "TI"], ",", StyleBox["coords", "TI"]}], "]"}],
       "constructs a metric from an explicit matrix and coordinate list."},
      {RowBox[{"MetricTensor", "[", "]"}],
       "returns the list of available built-in metric names."}
    },
    "Examples" -> {
      {"Get the Euclidean metric in 3 dimensions:",
       RowBox[{"MetricTensor", "[", "\"Euclidean\"", "]"}]},
      {"List the available built-in metrics:",
       RowBox[{"MetricTensor", "[", "]"}]}
    },
    "SeeAlso" -> {"MetricTensorQ", "IndexTensor", "IndexArray"}
  |>,

  <|
    "Symbol"   -> "IndexPart",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexPart", "[", RowBox[{StyleBox["ia", "TI"], ",", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["i", "TI"], "1"], ",", SubscriptBox[StyleBox["i", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}]}], "]"}],
       "extracts a sub-array of an IndexArray or IndexTensor at the given positions, where each i\:1d62 is an integer position, an index name, or All."}
    },
    "Examples" -> {
      {"Extract the second slice along the first index of a 3x3 IndexArray:",
       RowBox[{"IndexPart", "[", RowBox[{RowBox[{"IndexArray", "[", RowBox[{"IdentityMatrix", "[", "3", "]"}], "]"}], ",", RowBox[{"{", "2", "}"}]}], "]"}]},
      {"Empty position list returns the original array:",
       RowBox[{"IndexPart", "[", RowBox[{RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], ",", RowBox[{"{", "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"IndexJuggling", "IndexContract", "Part"}
  |>,

  <|
    "Symbol"   -> "IndexContract",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexContract", "[", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["a", "TI"], "1"], ",", SubscriptBox[StyleBox["a", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}], "]"}],
       "contracts every matching pair of free index names across the IndexArray or IndexTensor objects a\:1d62, returning a new IndexArray or IndexTensor."},
      {RowBox[{"IndexContract", "[", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["a", "TI"], "1"], ",", "\[Ellipsis]"}], "}"}], ",", StyleBox["output", "TI"], "]"}],
       "forces the listed names to be the free indices of the result."}
    },
    "Examples" -> {
      {"Contract a single IndexArray over its only index:",
       RowBox[{"IndexContract", "[", RowBox[{RowBox[{"{", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], "}"}], ",", RowBox[{"{", "}"}]}], "]"}]},
      {"Single-array shorthand is equivalent to wrapping in a list:",
       RowBox[{"IndexContract", "[", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"EinsteinSummation", "IndexJuggling", "IndexPart"}
  |>,

  <|
    "Symbol"   -> "IndexJuggling",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexJuggling", "[", RowBox[{StyleBox["ia", "TI"], ",", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["n", "TI"], "1"], ",", SubscriptBox[StyleBox["n", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}]}], "]"}],
       "permutes and renames the indices of an IndexArray or IndexTensor so that its indices match the specified names."}
    },
    "Examples" -> {
      {"An empty new-index list returns the array unchanged:",
       RowBox[{"IndexJuggling", "[", RowBox[{RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], ",", RowBox[{"{", "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"IndexPart", "IndexContract", "Permute"}
  |>
}
