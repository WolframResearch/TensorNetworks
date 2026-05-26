(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "Wolfram/TensorNetworks",
    "Description" -> "Tensor networks, index contraction and path optimization",
    "Creator" -> "Nik Murzin",
    "License" -> "MIT",
    "PublisherID" -> "Wolfram",
    "Version" -> "1.0.5",
    "WolframVersion" -> "14.3+",
    "PrimaryContext" -> "Wolfram`TensorNetworks`",
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {"Wolfram`TensorNetworks`", "Wolfram`TensorNetworks`IndexArray`", "Wolfram`TensorNetworks`Symmetry`"}
      },
      {"Cargo", "Root" -> "Cotengra"},
      {"Build", "Actions" -> {"CargoBuild"}},
      {"Binaries"},
      {"FrontEnd", "Prepend" -> True},
      {"Documentation", "Language" -> "English"}
    }
  |>
]
