Begin["DenseExecutionProbe`"];
here = Environment["TN_PROBE_HERE"];
root = FileNameJoin[{here, "results", "peps-workloads"}];
out = Environment["TN_PROBE_OUT"];
caseName = Environment["TN_PROBE_CASE"];
manifest = Import[FileNameJoin[{here, "workloads", "peps-2026-10-26", "manifest.json"}], "RawJSON"];
case = SelectFirst[manifest["cases"], #["id"] === caseName &];
PacletDirectoryLoad[FileNameJoin[{here, ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[here]], "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> 1}];
read[spec_] := If[FileHash[FileNameJoin[{root, spec["file"]}], "SHA256", "HexString"] === spec["sha256"],
    ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["file"]}], "Real64", ByteOrdering -> -1], spec["shape"]], $Failed];
tensors = read /@ case["tensors"];
If[MemberQ[tensors, $Failed], Exit[2]];
path = case["paths"]["cotengra.hyper3s"] + 1;
net = TensorNetwork[tensors, case["labels"], {}];
guardSymbols = {Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumArrayDot,
    Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumDot,
    Wolfram`TensorNetworks`Contraction`PackagePrivate`contractTreePath,
    Wolfram`TensorNetworks`Contraction`PackagePrivate`contractStep};
definitionsBefore = Hash[DownValues /@ guardSymbols];
SetAttributes[bounded, HoldAll];
limitString = Environment["TN_PROBE_LIMIT_MIB"];
limitBytes = If[StringQ[limitString], FromDigits[limitString] 2^20, 768 2^20];
bounded[expr_] := TimeConstrained[MemoryConstrained[expr, limitBytes, "memory_limit"], 30, "time_limit"];
relative[value_] := If[NumberQ[value], Abs[value - case["reference"]]/Abs[case["reference"]], Null];

matrixPair[{a_, i_}, {b_, j_}] := Block[{
    c = Select[i, MemberQ[j, #] &], al, br, da = Dimensions[a], db = Dimensions[b],
    ai = AssociationThread[i, Range[Length[i]]], bi = AssociationThread[j, Range[Length[j]]],
    shape, x, y, pa, pb, z
},
    al = Select[i, ! MemberQ[j, #] &];
    br = Select[j, ! MemberQ[i, #] &];
    shape = Join[da[[Lookup[ai, al]]], db[[Lookup[bi, br]]]];
    pa = FindPermutation[i, Join[al, c]];
    pb = FindPermutation[j, Join[c, br]];
    x = ArrayReshape[If[pa === Cycles[{}], a, Transpose[a, pa]],
        {Times @@ da[[Lookup[ai, al]]], Times @@ da[[Lookup[ai, c]]]}];
    y = ArrayReshape[If[pb === Cycles[{}], b, Transpose[b, pb]],
        {Times @@ db[[Lookup[bi, c]]], Times @@ db[[Lookup[bi, br]]]}];
    z = x . y;
    {If[shape === {}, z[[1, 1]], ArrayReshape[z, shape]], Join[al, br]}
];
fusedPair[{a_, i_}, {b_, j_}] := Block[{
    c = Select[i, MemberQ[j, #] &], al, br, da = Dimensions[a], db = Dimensions[b],
    ai = AssociationThread[i, Range[Length[i]]], bi = AssociationThread[j, Range[Length[j]]],
    shape, x, y, ag, bg, z
},
    al = Select[i, ! MemberQ[j, #] &];
    br = Select[j, ! MemberQ[i, #] &];
    shape = Join[da[[Lookup[ai, al]]], db[[Lookup[bi, br]]]];
    ag = {Lookup[ai, al], Lookup[ai, c]};
    bg = {Lookup[bi, c], Lookup[bi, br]};
    x = If[MemberQ[ag, {}], ArrayReshape[Flatten[a, DeleteCases[ag, {}]], Times @@@ (da[[#]] & /@ ag)], Flatten[a, ag]];
    y = If[MemberQ[bg, {}], ArrayReshape[Flatten[b, DeleteCases[bg, {}]], Times @@@ (db[[#]] & /@ bg)], Flatten[b, bg]];
    z = x . y;
    {If[shape === {}, z[[1, 1]], ArrayReshape[z, shape]], Join[al, br]}
];
arrayPair[{a_, i_}, {b_, j_}] := Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumArrayDot[{i, j} -> Automatic, a, b, False];
dotPair[{a_, i_}, {b_, j_}] := Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumDot[{i, j} -> Automatic, a, b, False];

runPairs[pair_] := First @ First @ Fold[
    Function[{state, positions}, Append[Delete[state, List /@ ReverseSort[positions]], pair @@ state[[positions]]]],
    MapThread[List, {tensors, case["labels"]}], path
];
records = {};
entries = {
    {"public_ArrayDot", Function[TensorNetworkContract[net, path, Method -> "ArrayDot"]]},
    {"public_Dot", Function[TensorNetworkContract[net, path, Method -> "Dot"]]},
    {"standalone_existing_ArrayDot", Function[runPairs[arrayPair]]},
    {"standalone_fused_2D_Dot", Function[runPairs[fusedPair]]},
    {"standalone_2D_Dot", Function[runPairs[matrixPair]]},
    {"standalone_existing_Dot", Function[runPairs[dotPair]]}
};
selection = Environment["TN_PROBE_METHODS"];
If[StringQ[selection], entries = Select[entries, MemberQ[StringSplit[selection, ","], First[#]] &]];
Scan[Function[entry, Block[{first, trials, values, row},
    ClearSystemCache[];
    first = AbsoluteTiming[bounded[entry[[2]][]]];
    row = <|"name" -> entry[[1]], "first_seconds" -> First[first], "first_relative_error" -> relative[Last[first]],
        "first_value" -> If[NumberQ[Last[first]], Last[first], Null]|>;
    If[NumberQ[Last[first]] && relative[Last[first]] < 1.*^-9,
        trials = Table[AbsoluteTiming[bounded[entry[[2]][]]], {3}];
        row["samples_seconds"] = trials[[All, 1]];
        row["samples_values"] = Replace[trials[[All, 2]], Except[_ ? NumberQ] -> Null, {1}];
        row["relative_errors"] = relative /@ trials[[All, 2]];
        row["ok"] = AllTrue[trials[[All, 2]], NumberQ[#] && relative[#] < 1.*^-9 &],
        row["ok"] = False; row["failure"] = ToString[Last[first], InputForm]
    ];
    records = Append[records, row];
    Echo[row];
    Export[out, <|"case" -> caseName, "records" -> records, "wolfram" -> $Version, "additional_memory_limit_bytes" -> limitBytes,
        "wl_peak_bytes_including_startup_and_previous_jobs" -> MaxMemoryUsed[],
        "definitions_unchanged" -> (definitionsBefore === Hash[DownValues /@ guardSymbols])|>, "RawJSON"]
]], entries];
End[];
