(* Specs for Array* utility functions in IndexArray context. *)

{
  <|
    "Symbol"   -> "ArrayDimensions",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayDimensions", "[", StyleBox["t", "TI"], "]"}],
       "returns the list of dimensions of the tensor t, tracking through Inactive[TensorContract], Inactive[TensorProduct], Inactive[Transpose] and Inactive[D]."}
    },
    "Examples" -> {
      {"Get the dimensions of a tensor:",
       RowBox[{"ArrayDimensions", "[", RowBox[{"RandomReal", "[", RowBox[{"1", ",", RowBox[{"{", RowBox[{"3", ",", "4", ",", "5"}], "}"}]}], "]"}], "]"}]},
      {"Returns {} for scalars:",
       RowBox[{"ArrayDimensions", "[", "3.14", "]"}]}
    },
    "SeeAlso" -> {"ArrayRank", "ArraySymmetry", "Dimensions"}
  |>,

  <|
    "Symbol"   -> "ArrayRank",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayRank", "[", StyleBox["t", "TI"], "]"}],
       "returns Length[ArrayDimensions[t]], i.e. the number of indices of the tensor t."}
    },
    "Examples" -> {
      {"Rank of a 3-index tensor:",
       RowBox[{"ArrayRank", "[", RowBox[{"RandomReal", "[", RowBox[{"1", ",", RowBox[{"{", RowBox[{"3", ",", "4", ",", "5"}], "}"}]}], "]"}], "]"}]},
      {"Rank of a scalar is 0:",
       RowBox[{"ArrayRank", "[", "1.0", "]"}]}
    },
    "SeeAlso" -> {"ArrayDimensions", "ArraySymmetry", "TensorRank"}
  |>,

  <|
    "Symbol"   -> "ArraySymmetry",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArraySymmetry", "[", StyleBox["t", "TI"], "]"}],
       "returns the symmetry declaration (Symmetric[\:2026], Antisymmetric[\:2026] or ZeroSymmetric[\:2026]) of t, or {} if there is none."}
    },
    "Examples" -> {
      {"Symmetry of a symmetric matrix:",
       RowBox[{"ArraySymmetry", "[", RowBox[{"SymmetrizedArray", "[", RowBox[{RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "->", "1"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "3"}], "}"}], ",", RowBox[{"Symmetric", "[", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "]"}]}], "]"}], "]"}]},
      {"Plain matrix has no special symmetry:",
       RowBox[{"ArraySymmetry", "[", RowBox[{"IdentityMatrix", "[", "3", "]"}], "]"}]}
    },
    "SeeAlso" -> {"ArrayDimensions", "TensorSymmetry"}
  |>,

  <|
    "Symbol"   -> "ArrayName",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayName", "[", StyleBox["t", "TI"], "]"}],
       "returns the underlying symbol associated with the tensor t, or None when t is not a symbolic array."}
    },
    "Examples" -> {
      {"Symbol from a VectorSymbol:",
       RowBox[{"ArrayName", "[", RowBox[{"VectorSymbol", "[", RowBox[{"v", ",", "3"}], "]"}], "]"}]},
      {"None for a numeric array:",
       RowBox[{"ArrayName", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"VectorSymbol", "MatrixSymbol", "ArraySymbol"}
  |>,

  <|
    "Symbol"   -> "ArrayPart",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayPart", "[", RowBox[{StyleBox["t", "TI"], ",", RowBox[{"{", RowBox[{SubscriptBox[StyleBox["i", "TI"], "1"], ",", SubscriptBox[StyleBox["i", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}]}], "]"}],
       "extracts the sub-array of t at the given positions, propagating dimensional metadata for VectorSymbol, MatrixSymbol and ArraySymbol."}
    },
    "Examples" -> {
      {"Take a sub-array of a 3-tensor:",
       RowBox[{"ArrayPart", "[", RowBox[{RowBox[{"Array", "[", RowBox[{"a", ",", RowBox[{"{", RowBox[{"3", ",", "3", ",", "3"}], "}"}]}], "]"}], ",", RowBox[{"{", RowBox[{"All", ",", "1"}], "}"}]}], "]"}]},
      {"Empty position list returns the original:",
       RowBox[{"ArrayPart", "[", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"Part", "ArrayDimensions"}
  |>,

  <|
    "Symbol"   -> "ArrayTranspose",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayTranspose", "[", RowBox[{StyleBox["t", "TI"], ",", StyleBox["perm", "TI"]}], "]"}],
       "permutes the axes of t according to perm, simplifying the result and composing nested transposes into a single permutation."}
    },
    "Examples" -> {
      {"Swap the first two axes of a 3-tensor:",
       RowBox[{"ArrayTranspose", "[", RowBox[{RowBox[{"Array", "[", RowBox[{"a", ",", RowBox[{"{", RowBox[{"2", ",", "3", ",", "4"}], "}"}]}], "]"}], ",", RowBox[{"{", RowBox[{"2", ",", "1", ",", "3"}], "}"}]}], "]"}]},
      {"Identity permutation returns the original:",
       RowBox[{"ArrayTranspose", "[", RowBox[{RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "4"}], "}"}]}], "}"}], ",", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"Transpose", "ArrayContract", "Permute"}
  |>,

  <|
    "Symbol"   -> "ArrayContract",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"ArrayContract", "[", RowBox[{StyleBox["t", "TI"], ",", StyleBox["c", "TI"]}], "]"}],
       "contracts the index pairs c in tensor t and simplifies the result."},
      {RowBox[{"ArrayContract", "[", RowBox[{RowBox[{"{", RowBox[{SubscriptBox[StyleBox["t", "TI"], "1"], ",", SubscriptBox[StyleBox["t", "TI"], "2"], ",", "\[Ellipsis]"}], "}"}], ",", StyleBox["c", "TI"]}], "]"}],
       "first forms an Inactive[TensorProduct] of the listed tensors, then contracts the index pairs c."}
    },
    "Examples" -> {
      {"Trace of a matrix as a contraction over indices 1 and 2:",
       RowBox[{"ArrayContract", "[", RowBox[{RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "4"}], "}"}]}], "}"}], ",", RowBox[{"{", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "}"}]}], "]"}]},
      {"Returns {} when any input dimension is zero:",
       RowBox[{"ArrayContract", "[", RowBox[{RowBox[{"ConstantArray", "[", RowBox[{"0", ",", RowBox[{"{", RowBox[{"0", ",", "3"}], "}"}]}], "]"}], ",", RowBox[{"{", "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"TensorContract", "ArrayTranspose", "SimplifyArray"}
  |>,

  <|
    "Symbol"   -> "SimplifyArray",
    "Context"  -> "Wolfram`TensorNetworks`IndexArray`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"SimplifyArray", "[", StyleBox["expr", "TI"], "]"}],
       "simplifies a nested array expression by removing empty Inactive[TensorContract] calls, identity Inactive[Transpose] calls and singleton Inactive[TensorProduct] calls."}
    },
    "Examples" -> {
      {"Simplify a no-op contraction:",
       RowBox[{"SimplifyArray", "[", RowBox[{RowBox[{"Inactive", "[", "TensorContract", "]"}], "[", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", "}"}]}], "]"}], "]"}]},
      {"Pass-through on a plain expression:",
       RowBox[{"SimplifyArray", "[", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"ArrayContract", "ArrayTranspose"}
  |>
}
