Begin["PEPSVerificationRound2`"];
out = "/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance/results/peps-verification-round2";
base = "/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance";
PacletDirectoryLoad[FileNameJoin[{base, ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> 1}];
result = <|"version" -> $Version, "systemID" -> $SystemID,
  "arrays" -> ToString[PacletFind["Wolfram/Arrays"], InputForm],
  "contract_options" -> ToString[Options[TensorNetworkContract], InputForm],
  "contract_downvalues" -> ToString[DownValues[TensorNetworkContract], InputForm],
  "greedy_downvalues" -> ToString[DownValues[GreedyContractionPath], InputForm]|>;
before = Hash[DownValues /@ {TensorNetworkContract, TensorNetworkContraction,
  Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan}, "SHA256"];
tiny = N[10^-310, 50];
validCases = {
  {"matching_tiny", tiny, tiny, True}, {"zero_against_tiny", 0, tiny, False},
  {"unit", 1., 1., True}, {"relative_inside", 1. + 5.*^-10, 1., True},
  {"relative_outside", 1. + 2.*^-9, 1., False},
  {"zero_reference", 0, 0, False}, {"negative_reference", -1, -1, False},
  {"infinite_reference", 1, Infinity, False}, {"nonreal_reference", 1, I, False},
  {"invalid_reference", 1, Missing["invalid"], False},
  {"symbolic_reference", 1, x, False}, {"empty_reference", 1, {}, False},
  {"failed_value", $Failed, 1, False}, {"indeterminate_value", Indeterminate, 1, False},
  {"infinite_value", Infinity, 1, False}, {"negative_value", -1, 1, False},
  {"empty_value", {}, 1, False}, {"symbolic_value", x, 1, False},
  {"string_value", "1", 1, False}, {"boolean_value", True, 1, False}
};
result["validation_gates"] = Table[
  text = Import[FileNameJoin[{base, file}], "Text"];
  gate = First[StringCases[text, Shortest["valid[value_]" ~~ __ ~~ ";"]]];
  ToExpression[gate];
  rows = Map[Function[row,
    case = <|"reference" -> row[[3]]|>;
    actual = valid[row[[2]]];
    <|"test" -> row[[1]], "actual" -> actual, "expected" -> row[[4]],
      "pass" -> SameQ[actual, row[[4]]]|>
  ], validCases];
  <|"file" -> file, "source" -> gate, "rows" -> rows, "all_passed" -> AllTrue[rows, TrueQ[#["pass"]] &]|>,
  {file, {"peps_execute.wls", "peps_engines.wls"}}
];
a = {{1., 2.}, {3., 4.}}; b = {{5., 6.}, {7., 8.}};
net = TensorNetwork[{a, b}, {{1, 2}, {2, 3}}, {1, 3}];
data = TensorNetworkData[net];
smallPath = {{1, 2}};
result["public_api"] = <|
  "tensor_network_valid" -> TensorNetworkQ[net],
  "explicit_path_valid" -> CanonicalPathQ[smallPath],
  "canonical_empty_valid" -> CanonicalPathQ[{}],
  "canonical_malformed_invalid" -> ! CanonicalPathQ[{{1, "x"}}],
  "methods" -> $TensorNetworkContractionMethods,
  "results" -> Table[<|"method" -> method,
    "value" -> TensorNetworkContract[net, smallPath, Method -> method],
    "pass" -> SameQ[TensorNetworkContract[net, smallPath, Method -> method], a.b]|>,
      {method, {"ArrayDot", "ArrayDotTranspose", "Dot"}}],
  "symbolic_scalar" -> TensorNetworkContract[TensorNetwork[{u, v}, {{}, {}}, {}], {{1, 2}}, Method -> "ArrayDot"],
  "empty_path_singleton" -> TensorNetworkContract[TensorNetwork[{{1., 2.}}, {{1}}, {1}], {}, Method -> "ArrayDot"]
|>;
plan = Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
  Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan[data, "ArrayDot"]];
result["planner_return"] = <|"association_and_tree" -> MatchQ[plan, {_Association, _ ? TreePathQ}],
  "same_labels" -> SameQ[First[plan]["Hyperedges"], data["Hyperedges"]],
  "path" -> TreePathToPath[Last[plan], First[plan]["Vertices"]]|>;
result["definitions_unchanged"] = SameQ[before, Hash[DownValues /@ {TensorNetworkContract, TensorNetworkContraction,
  Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan}, "SHA256"]];
(* Convert symbolic-only probes to text for finite JSON output. *)
result["public_api"]["symbolic_scalar"] = ToString[result["public_api"]["symbolic_scalar"], InputForm];
Export[FileNameJoin[{out, "kernel-checks.json"}], result, "RawJSON"];
Echo[result];
End[];
