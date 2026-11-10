Begin["PEPSAudit`"];
root = FileNameJoin[{DirectoryName[$InputFileName], "results", "peps-workloads"}];
manifest = Import[FileNameJoin[{root, "manifest.json"}], "RawJSON"];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[$InputFileName], ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[DirectoryName[$InputFileName]]], "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> 1}];
read[spec_] := If[FileHash[FileNameJoin[{root, spec["file"]}], "SHA256", "HexString"] === spec["sha256"],
    ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["file"]}], "Real64", ByteOrdering -> -1], spec["shape"]], $Failed];
records = {};
Scan[Function[case, Module[{tensors, data, greedy, auto, timings, form, tree},
    Echo[case["id"]]; ClearSystemCache[];
    tensors = read /@ case["tensors"];
    If[MemberQ[tensors, $Failed], Exit[2]];
    data = TensorNetworkData[TensorNetwork[tensors, case["labels"], {}]];
    greedy = AbsoluteTiming[GreedyContractionPath[data]];
    auto = Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
        AbsoluteTiming[TimeConstrained[MemoryConstrained[
            Wolfram`TensorNetworks`Contraction`PackagePrivate`automaticPlan[data, "ArrayDot"], 512 2^20, $Failed], 30, $Failed]]];
    If[! CanonicalPathQ[Last[greedy]] || ! MatchQ[Last[auto], {_Association, _ ? TreePathQ}], Exit[2]];
    {form, tree} = Last[auto];
    If[form["Hyperedges"] =!= data["Hyperedges"], Echo["Unexpected reduction; execution must use the reduced tensors"]; Exit[2]];
    records = Append[records, <|"id" -> case["id"], "greedy_path" -> (Last[greedy] - 1),
        "automatic_path" -> (TreePathToPath[tree, form["Vertices"]] - 1),
        "greedy_plan_seconds" -> First[greedy], "automatic_plan_seconds" -> First[auto],
        "same_form" -> True|>];
    Export[FileNameJoin[{root, "tn-plans.json"}], <|"wolfram" -> $Version, "records" -> records|>, "RawJSON"];
]], manifest["cases"]];
End[];
