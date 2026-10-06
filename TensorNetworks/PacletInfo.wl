(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "Wolfram/TensorNetworks",
    "Description" -> "Tensor networks, index contraction and path optimization",
    "Creator" -> "Wolfram Research, Quantum Computation Framework team",
    "License" -> "MIT",
    "PublisherID" -> "Wolfram",
    "Version" -> "1.1.0",
    "WolframVersion" -> "14.3+",
    "PrimaryContext" -> "Wolfram`TensorNetworks`",
    (* 1.4.2 is a floor, not a preference: the IndexArray subcontext delegates
       its shape and structural operations to this paclet, and three of its
       shape rules were only settled there by 1.4.2 - the gradient of a rank-0
       operand under Inactive[D], the shape of a list whose leaves are symbolic
       containers, and a structural node over operands of symbolic size, such
       as the transpose of an n x m ArraySymbol.  Against earlier versions they
       come back wrong quietly. *)
    "Dependencies" -> {{"Wolfram/Arrays", "1.4.2+"}},
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {
          "Wolfram`TensorNetworks`",
          "Wolfram`TensorNetworks`IndexArray`",
          "Wolfram`TensorNetworks`Symmetry`"
        },
        "Symbols" -> {
          "Wolfram`TensorNetworks`ActivateTensors",
          "Wolfram`TensorNetworks`BinaryTensorNetwork",
          "Wolfram`TensorNetworks`BinaryTensorNetworkQ",
          "Wolfram`TensorNetworks`CanonicalPath",
          "Wolfram`TensorNetworks`CanonicalPathQ",
          "Wolfram`TensorNetworks`ContractIndices",
          "Wolfram`TensorNetworks`ContractionTree",
          "Wolfram`TensorNetworks`EinsteinSummation",
          "Wolfram`TensorNetworks`GreedyContractionPath",
          "Wolfram`TensorNetworks`IndexArray`ArraySymmetry",
          "Wolfram`TensorNetworks`IndexArray`Dimension",
          "Wolfram`TensorNetworks`IndexArray`DimensionQ",
          "Wolfram`TensorNetworks`IndexArray`IndexArray",
          "Wolfram`TensorNetworks`IndexArray`IndexArrayQ",
          "Wolfram`TensorNetworks`IndexArray`IndexContract",
          "Wolfram`TensorNetworks`IndexArray`IndexJuggling",
          "Wolfram`TensorNetworks`IndexArray`IndexPart",
          "Wolfram`TensorNetworks`IndexArray`IndexTensor",
          "Wolfram`TensorNetworks`IndexArray`IndexTensorQ",
          "Wolfram`TensorNetworks`IndexArray`MetricTensor",
          "Wolfram`TensorNetworks`IndexArray`MetricTensorQ",
          "Wolfram`TensorNetworks`IndexArray`Shape",
          "Wolfram`TensorNetworks`IndexArray`ShapeQ",
          "Wolfram`TensorNetworks`IndexedMultiply",
          "Wolfram`TensorNetworks`InitializeTensorNetwork",
          "Wolfram`TensorNetworks`MPSCanonicalForm",
          "Wolfram`TensorNetworks`MPSCanonicalQ",
          "Wolfram`TensorNetworks`MPSEntanglementEntropy",
          "Wolfram`TensorNetworks`MPSNorm",
          "Wolfram`TensorNetworks`MPSNormalize",
          "Wolfram`TensorNetworks`MPSOverlap",
          "Wolfram`TensorNetworks`MPSSchmidtValues",
          "Wolfram`TensorNetworks`MPSTruncate",
          "Wolfram`TensorNetworks`OptimalContractionPath",
          "Wolfram`TensorNetworks`PathIndexContractions",
          "Wolfram`TensorNetworks`PathQ",
          "Wolfram`TensorNetworks`PathToTreePath",
          "Wolfram`TensorNetworks`RandomTensorNetwork",
          "Wolfram`TensorNetworks`SparseTensorNetwork",
          "Wolfram`TensorNetworks`Symmetry`HookFactor",
          "Wolfram`TensorNetworks`Symmetry`HookLength",
          "Wolfram`TensorNetworks`Symmetry`HookLengths",
          "Wolfram`TensorNetworks`Symmetry`PartitionQ",
          "Wolfram`TensorNetworks`Symmetry`TableauColumns",
          "Wolfram`TensorNetworks`Symmetry`TableauDimension",
          "Wolfram`TensorNetworks`Symmetry`TableauRows",
          "Wolfram`TensorNetworks`Symmetry`TableauShape",
          "Wolfram`TensorNetworks`Symmetry`TableauSize",
          "Wolfram`TensorNetworks`Symmetry`TransposePartition",
          "Wolfram`TensorNetworks`Symmetry`YoungProject",
          "Wolfram`TensorNetworks`Symmetry`YoungSymmetrize",
          "Wolfram`TensorNetworks`Symmetry`YoungTableau",
          "Wolfram`TensorNetworks`Symmetry`YoungTableauQ",
          "Wolfram`TensorNetworks`TensorNetwork",
          "Wolfram`TensorNetworks`TensorNetworkAdd",
          "Wolfram`TensorNetworks`TensorNetworkContract",
          "Wolfram`TensorNetworks`TensorNetworkContraction",
          "Wolfram`TensorNetworks`TensorNetworkContractions",
          "Wolfram`TensorNetworks`TensorNetworkData",
          "Wolfram`TensorNetworks`TensorNetworkDelete",
          "Wolfram`TensorNetworks`TensorNetworkFindContractionPath",
          "Wolfram`TensorNetworks`TensorNetworkFreeIndices",
          "Wolfram`TensorNetworks`TensorNetworkGraphData",
          "Wolfram`TensorNetworks`TensorNetworkGraphQ",
          "Wolfram`TensorNetworks`TensorNetworkIndexDimensions",
          "Wolfram`TensorNetworks`TensorNetworkIndexGraph",
          "Wolfram`TensorNetworks`TensorNetworkIndices",
          "Wolfram`TensorNetworks`TensorNetworkQ",
          "Wolfram`TensorNetworks`TensorNetworkRemoveCycles",
          "Wolfram`TensorNetworks`TensorNetworkReplaceIndices",
          "Wolfram`TensorNetworks`TensorNetworkSize",
          "Wolfram`TensorNetworks`TensorNetworkTensors",
          "Wolfram`TensorNetworks`TensorNetworkToNetGraph",
          "Wolfram`TensorNetworks`ToTensorNetworkGraph",
          "Wolfram`TensorNetworks`TreePathQ",
          "Wolfram`TensorNetworks`TreePathToPath"
        }
      },
      {
        "Asset",
        "Root" -> ".",
        "Assets" -> {
          {"Binaries", "Binaries"}
        }
      },
      {"FrontEnd", "Prepend" -> True},
      {"Documentation", "Language" -> "English"}
    }
  |>
]
