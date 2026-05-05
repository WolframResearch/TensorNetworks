(* Specs for simple predicate symbols — first batch of Phase B.
   Template: PathQ.nb (a 1-pattern predicate page). *)

{
  (* ---------- IndexArray context ---------- *)

  <|
    "Symbol"   -> "ShapeQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ShapeQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid Shape (a sequence of Dimension objects), and False otherwise."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid Shape:",
       RowBox[{"ShapeQ", "[", RowBox[{"Shape", "[", RowBox[{"2", ",", "3", ",", "4"}], "]"}], "]"}],
       RowBox[{"ShapeQ", "[", RowBox[{"{", RowBox[{"2", ",", "3"}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"Shape", "Dimension", "DimensionQ"}
  |>,

  <|
    "Symbol"   -> "DimensionQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"DimensionQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid Dimension object, and False otherwise."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid Dimension:",
       RowBox[{"DimensionQ", "[", RowBox[{"Dimension", "[", RowBox[{"3", ",", "\"i\""}], "]"}], "]"}],
       RowBox[{"DimensionQ", "[", "3", "]"}]}
    },
    "SeeAlso" -> {"Dimension", "Shape", "ShapeQ"}
  |>,

  <|
    "Symbol"   -> "IndexArrayQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexArrayQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid IndexArray, i.e. its tensor's dimensions match the declared Shape under any recorded assumptions."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid IndexArray:",
       RowBox[{"IndexArrayQ", "[", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}], "]"}],
       RowBox[{"IndexArrayQ", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"IndexArray", "IndexTensor", "IndexTensorQ"}
  |>,

  <|
    "Symbol"   -> "IndexTensorQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"IndexTensorQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid IndexTensor (an IndexArray together with optional metric tensors)."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid IndexTensor:",
       RowBox[{"IndexTensorQ", "[", RowBox[{"IndexTensor", "[", RowBox[{"IndexArray", "[", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "]"}], "]"}], "]"}],
       RowBox[{"IndexTensorQ", "[", "1", "]"}]}
    },
    "SeeAlso" -> {"IndexTensor", "IndexArray", "MetricTensor"}
  |>,

  <|
    "Symbol"   -> "MetricTensorQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"MetricTensorQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid MetricTensor (a rank-2 IndexTensor flagged as a metric)."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid MetricTensor:",
       RowBox[{"MetricTensorQ", "[", RowBox[{"MetricTensor", "[", "\"Euclidean\"", "]"}], "]"}],
       RowBox[{"MetricTensorQ", "[", RowBox[{"IdentityMatrix", "[", "3", "]"}], "]"}]}
    },
    "SeeAlso" -> {"MetricTensor", "IndexTensor", "IndexTensorQ"}
  |>,

  <|
    "Symbol"   -> "ZeroArrayQ",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ZeroArrayQ", "[", StyleBox["t", "TI"], "]"}],
       "yields True if any dimension of the tensor t is zero, indicating an empty tensor."}
    },
    "Examples" -> {
      {"Test whether a tensor has a zero dimension:",
       RowBox[{"ZeroArrayQ", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}],
       RowBox[{"ZeroArrayQ", "[", RowBox[{"{", "}"}], "]"}],
       RowBox[{"ZeroArrayQ", "[", RowBox[{"ConstantArray", "[", RowBox[{"0", ",", RowBox[{"{", RowBox[{"3", ",", "0", ",", "2"}], "}"}]}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"ArrayDimensions", "ArrayRank", "IndexArrayQ"}
  |>,

  (* ---------- Symmetry context ---------- *)

  <|
    "Symbol"   -> "YoungTableauQ",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"YoungTableauQ", "[", StyleBox["expr", "TI"], "]"}],
       "yields True if expr is a valid YoungTableau (rows of distinct positive integers with non-increasing lengths)."}
    },
    "Examples" -> {
      {"Test whether an expression is a valid YoungTableau:",
       RowBox[{"YoungTableauQ", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}], "]"}],
       RowBox[{"YoungTableauQ", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "4", ",", "5"}], "}"}]}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"YoungTableau", "PartitionQ", "TableauShape"}
  |>,

  <|
    "Symbol"   -> "PartitionQ",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"PartitionQ", "[", StyleBox["list", "TI"], "]"}],
       "yields True if list is a valid integer partition (positive integers in non-increasing order)."}
    },
    "Examples" -> {
      {"Test whether a list is a valid integer partition:",
       RowBox[{"PartitionQ", "[", RowBox[{"{", RowBox[{"4", ",", "2", ",", "1"}], "}"}], "]"}],
       RowBox[{"PartitionQ", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}],
       RowBox[{"PartitionQ", "[", RowBox[{"{", RowBox[{"3", ",", RowBox[{"-", "1"}]}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"YoungTableau", "TransposePartition", "TableauShape"}
  |>
}
