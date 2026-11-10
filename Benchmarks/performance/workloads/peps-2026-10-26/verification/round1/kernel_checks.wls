Begin["PEPSVerifier`"];
base = "/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance";
out = FileNameJoin[{base, "results", "peps-verification-round1"}];
Scan[Information, {FileHash, BinaryReadList, ArrayReshape, MemoryConstrained, TimeConstrained, MaxMemoryUsed, ClearSystemCache, SetSystemOptions}];
PacletDirectoryLoad[FileNameJoin[{base, ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> 1}];
Echo[Options[TensorNetworkContract], "TensorNetworkContract options"];
Echo[Options[GreedyContractionPath], "GreedyContractionPath options"];
manifest = Import[FileNameJoin[{out, "replay", "manifest.json"}], "RawJSON"];
read[spec_] := ArrayReshape[BinaryReadList[FileNameJoin[{out, "replay", spec["file"]}], "Real64", ByteOrdering -> -1], spec["shape"]];
tracked = {Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan, Wolfram`TensorNetworks`Contraction`PackagePrivate`freshPlan, Wolfram`TensorNetworks`Contraction`PackagePrivate`cheapestPlan, Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumDot, Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumArrayDot};
definitionHashes = Function[s, Hash[{DownValues[s], UpValues[s], OwnValues[s]}, "SHA256"], HoldAll];
before = definitionHashes /@ tracked;
records = Map[Function[case, Module[{tensors, data, plans, paths, forms},
 tensors = read /@ case["tensors"];
 data = TensorNetworkData[TensorNetwork[tensors, case["labels"], {}]];
 plans = Table[ClearSystemCache[]; Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>}, AbsoluteTiming[TimeConstrained[MemoryConstrained[Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan[data, "ArrayDot"], 512 2^20, $Failed], 30, $Failed]]], {3}];
 paths = TreePathToPath[Last[Last[#]], data["Vertices"]] - 1 & /@ plans;
 forms = First[Last[#]] & /@ plans;
 <|"id" -> case["id"], "planning_samples_seconds" -> plans[[All, 1]], "same_given_tensors" -> AllTrue[forms, #["Tensors"] === tensors &], "same_given_labels" -> AllTrue[forms, #["Hyperedges"] === data["Hyperedges"] &], "no_reduction_key" -> AllTrue[forms, !KeyExistsQ[#, "Reduction"] &], "same_saved_path" -> AllTrue[paths, # === case["paths"]["tn.automatic"] &], "paths" -> paths|>
]], manifest["cases"]];
valid[value_, reference_] := NumberQ[value] && TrueQ[Abs[value-reference]/Max[Abs[reference], 1.*^-300] < 1.*^-9];
gates = <|"recorded_references_reject_zero" -> AllTrue[Select[manifest["cases"], KeyExistsQ[#, "reference"] &], !valid[0., #["reference"]] &], "symbolic_rejected" -> !valid[x, 1.], "indeterminate_rejected" -> !valid[Indeterminate, 1.], "infinity_rejected" -> !valid[Infinity, 1.], "subfloor_reference" -> ToString[N[10^-310, 50], InputForm], "subfloor_zero_accepted" -> valid[0, N[10^-310, 50]]|>;
result = <|"version" -> $Version, "arrays_version" -> PacletObject["Wolfram/Arrays"]["Version"], "arrays_location" -> PacletObject["Wolfram/Arrays"]["Location"], "tn_location" -> PacletObject["Wolfram/TensorNetworks"]["Location"], "parallel_options" -> ToString[SystemOptions["ParallelOptions"], InputForm], "automatic_plan_records" -> records, "validation_gate_tests" -> gates, "function_definitions_unchanged" -> (before === definitionHashes /@ tracked)|>;
Export[FileNameJoin[{out, "kernel-checks.json"}], result, "RawJSON"];
Echo[gates]; Echo[result["function_definitions_unchanged"]];
End[];
