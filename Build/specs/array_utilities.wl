(* Specs for Array* utility functions in IndexArray context. *)

{
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
  |>
}
