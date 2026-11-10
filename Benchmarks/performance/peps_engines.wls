Begin["PEPSAudit`"];
root = Environment["TN_PEPS_ROOT"];
job = Import[Environment["TN_PEPS_JOB"], "RawJSON"];
manifest = Import[FileNameJoin[{root, "manifest.json"}], "RawJSON"];
case = SelectFirst[manifest["cases"], #["id"] === job["case"] &];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[$InputFileName], ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[DirectoryName[$InputFileName]]], "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> 1}];
read[spec_] := If[FileHash[FileNameJoin[{root, spec["file"]}], "SHA256", "HexString"] === spec["sha256"],
    ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["file"]}], "Real64", ByteOrdering -> -1], spec["shape"]], $Failed];
tensors = read /@ case["tensors"];
If[MemberQ[tensors, $Failed], Exit[2]];
net = TensorNetwork[tensors, case["labels"], {}];
path = case["paths"][job["path"]] + 1;
SetAttributes[bounded, HoldAll];
bounded[expr_] := TimeConstrained[MemoryConstrained[expr, 768 2^20, "memory_limit_768MiB"], 30, "time_limit_30s"];
fn[] := TensorNetworkContract[net, path, Method -> job["method"]];
valid[value_] := NumberQ[value] && NumberQ[case["reference"]] &&
    TrueQ[0 < case["reference"] < Infinity] &&
    TrueQ[Abs[value - case["reference"]]/Abs[case["reference"]] < 1.*^-9];
ClearSystemCache[];
first = AbsoluteTiming[bounded[fn[]]];
result = <|"case" -> case["id"], "backend" -> "tn", "path" -> job["path"],
    "method" -> job["method"], "first_seconds" -> First[first], "first_ok" -> valid[Last[first]], "samples_seconds" -> {},
    "status" -> "failed", "wolfram" -> $Version|>;
If[! TrueQ[result["first_ok"]], result["failure_reason"] = If[StringQ[Last[first]], Last[first], "numerical validation failed"]];
If[TrueQ[result["first_ok"]],
    trials = Table[AbsoluteTiming[bounded[fn[]]], {3}];
    result["samples_seconds"] = trials[[All, 1]];
    result["correct"] = AllTrue[trials[[All, 2]], valid];
    result["relative_error"] = Max[Abs[trials[[All, 2]] - case["reference"]]]/Abs[case["reference"]];
    result["value"] = Last[Last[trials]];
    result["status"] = If[TrueQ[result["correct"]], "ok", "failed"];
];
result["wl_peak_bytes_including_startup"] = MaxMemoryUsed[];
Export[Environment["TN_PEPS_OUTPUT"], result, "RawJSON"];
Exit[Boole[result["status"] =!= "ok"]];
End[];
