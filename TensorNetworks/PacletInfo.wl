(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "Wolfram/TensorNetworks",
    "Description" -> "Tensor networks, index contraction and path optimization",
    "Creator" -> "Nik Murzin",
    "License" -> "MIT",
    "PublisherID" -> "Wolfram",
    "Version" -> "1.0.0",
    "WolframVersion" -> "14.3+",
    "PrimaryContext" -> "Wolfram`TensorNetworks`",
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> "Wolfram`TensorNetworks`"
      },
      {"Cargo", "Root" -> "Cotengra"},
      {"Build", "Actions" -> {"CargoBuild"}},
      {"Binaries"}
    }
  |>
]
