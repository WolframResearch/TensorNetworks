(* Specs for the 10 Symmetry-context pages. *)

{
  <|
    "Symbol"   -> "YoungTableau",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"YoungTableau", "[", StyleBox["rows", "TI"], "]"}],
       "represents a Young tableau, where rows is a list of lists of slot indices defining how tensor indices transform under permutations."}
    },
    "Examples" -> {
      {"Construct a {3,2} standard Young tableau:",
       RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}]},
      {"Read its shape:",
       RowBox[{"TableauShape", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"YoungTableauQ", "TableauShape", "TableauDimension"}
  |>,

  <|
    "Symbol"   -> "TransposePartition",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"TransposePartition", "[", StyleBox["partition", "TI"], "]"}],
       "returns the conjugate (transpose) of an integer partition, equivalent to swapping rows and columns of the corresponding Young diagram."}
    },
    "Examples" -> {
      {"Conjugate of the partition {4, 2, 1}:",
       RowBox[{"TransposePartition", "[", RowBox[{"{", RowBox[{"4", ",", "2", ",", "1"}], "}"}], "]"}]},
      {"Conjugating twice returns the original partition:",
       RowBox[{"TransposePartition", "[", RowBox[{"TransposePartition", "[", RowBox[{"{", RowBox[{"3", ",", "2", ",", "1"}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"PartitionQ", "TableauShape", "YoungTableau"}
  |>,

  <|
    "Symbol"   -> "TableauShape",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"TableauShape", "[", StyleBox["tableau", "TI"], "]"}],
       "returns the shape (partition) of a Young tableau as a list of row lengths."}
    },
    "Examples" -> {
      {"Shape of a {3,2} tableau:",
       RowBox[{"TableauShape", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"TableauSize", "YoungTableau", "PartitionQ"}
  |>,

  <|
    "Symbol"   -> "TableauSize",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"TableauSize", "[", StyleBox["tableau", "TI"], "]"}],
       "returns the total number of boxes in a Young tableau, i.e. the sum of its row lengths."}
    },
    "Examples" -> {
      {"Total number of boxes in a {3,2} tableau:",
       RowBox[{"TableauSize", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"TableauShape", "YoungTableau"}
  |>,

  <|
    "Symbol"   -> "HookLength",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"HookLength", "[", RowBox[{StyleBox["tableau", "TI"], ",", RowBox[{"{", RowBox[{StyleBox["row", "TI"], ",", StyleBox["col", "TI"]}], "}"}]}], "]"}],
       "computes the hook length at position {row, col} in a Young tableau."}
    },
    "Examples" -> {
      {"Hook length at the top-left of a {3,2} tableau:",
       RowBox[{"HookLength", "[", RowBox[{RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], ",", RowBox[{"{", RowBox[{"4", ",", "5"}], "}"}]}], "}"}], "]"}], ",", RowBox[{"{", RowBox[{"1", ",", "1"}], "}"}]}], "]"}]}
    },
    "SeeAlso" -> {"HookLengths", "HookFactor", "TableauDimension"}
  |>,

  <|
    "Symbol"   -> "HookLengths",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"HookLengths", "[", StyleBox["partition", "TI"], "]"}],
       "returns the nested list of all hook lengths for the cells of a Young diagram of the given integer partition."},
      {RowBox[{"HookLengths", "[", StyleBox["tableau", "TI"], "]"}],
       "returns the hook lengths for the underlying partition of a YoungTableau."}
    },
    "Examples" -> {
      {"All hook lengths for the partition {3, 2}:",
       RowBox[{"HookLengths", "[", RowBox[{"{", RowBox[{"3", ",", "2"}], "}"}], "]"}]}
    },
    "SeeAlso" -> {"HookLength", "HookFactor", "TableauDimension"}
  |>,

  <|
    "Symbol"   -> "HookFactor",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"HookFactor", "[", StyleBox["partition", "TI"], "]"}],
       "computes 1 / Product[hook lengths] for the given partition via the Frobenius determinant formula."},
      {RowBox[{"HookFactor", "[", StyleBox["tableau", "TI"], "]"}],
       "does the same for the underlying partition of a YoungTableau."}
    },
    "Examples" -> {
      {"HookFactor for the partition {2, 1}:",
       RowBox[{"HookFactor", "[", RowBox[{"{", RowBox[{"2", ",", "1"}], "}"}], "]"}]},
      {"Multiplied by n! gives the irrep dimension:",
       RowBox[{RowBox[{"3", "!"}], " ", RowBox[{"HookFactor", "[", RowBox[{"{", RowBox[{"2", ",", "1"}], "}"}], "]"}]}]}
    },
    "SeeAlso" -> {"HookLengths", "TableauDimension", "PartitionQ"}
  |>,

  <|
    "Symbol"   -> "TableauDimension",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"TableauDimension", "[", StyleBox["tableau", "TI"], "]"}],
       "computes the dimension of the irreducible S\:2099 representation corresponding to the Young tableau via the hook-length formula."}
    },
    "Examples" -> {
      {"Dimension of the standard S\:2083 irrep with shape {2,1}:",
       RowBox[{"TableauDimension", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", "3", "}"}]}], "}"}], "]"}], "]"}]},
      {"Fully symmetric and fully antisymmetric irreps are 1-dimensional:",
       RowBox[{"TableauDimension", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{"{", RowBox[{"1", ",", "2", ",", "3"}], "}"}], "}"}], "]"}], "]"}],
       RowBox[{"TableauDimension", "[", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{RowBox[{"{", "1", "}"}], ",", RowBox[{"{", "2", "}"}], ",", RowBox[{"{", "3", "}"}]}], "}"}], "]"}], "]"}]}
    },
    "SeeAlso" -> {"HookFactor", "HookLengths", "YoungTableau"}
  |>,

  <|
    "Symbol"   -> "YoungSymmetrize",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"YoungSymmetrize", "[", RowBox[{StyleBox["tensor", "TI"], ",", StyleBox["tableau", "TI"]}], "]"}],
       "projects tensor onto the symmetry class defined by the Young tableau by symmetrizing over rows then antisymmetrizing over columns."}
    },
    "Examples" -> {
      {"Symmetrize a rank-2 tensor with the totally symmetric tableau {2}:",
       RowBox[{"YoungSymmetrize", "[", RowBox[{RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "4"}], "}"}]}], "}"}], ",", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "}"}], "]"}]}], "]"}]}
    },
    "SeeAlso" -> {"YoungProject", "YoungTableau", "TableauDimension"}
  |>,

  <|
    "Symbol"   -> "YoungProject",
    "Context"  -> "Wolfram`TensorNetworks`Symmetry`",
    "Template" -> "PathQ",
    "UsageBoxes" -> {
      {RowBox[{"YoungProject", "[", RowBox[{StyleBox["tensor", "TI"], ",", StyleBox["tableau", "TI"]}], "]"}],
       "returns the normalized projection of tensor onto the Young tableau symmetry class; the projection is idempotent."}
    },
    "Examples" -> {
      {"Project a rank-2 tensor onto the totally symmetric class:",
       RowBox[{"YoungProject", "[", RowBox[{RowBox[{"{", RowBox[{RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], ",", RowBox[{"{", RowBox[{"3", ",", "4"}], "}"}]}], "}"}], ",", RowBox[{"YoungTableau", "[", RowBox[{"{", RowBox[{"{", RowBox[{"1", ",", "2"}], "}"}], "}"}], "]"}]}], "]"}]}
    },
    "SeeAlso" -> {"YoungSymmetrize", "YoungTableau", "TableauDimension"}
  |>
}
