PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance/.dependencies/Arrays/Arrays"];
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
p[n_] := Symbol["Wolfram`TensorNetworks`Contraction`PackagePrivate`" <> n];
s[n_] := Symbol["Wolfram`TensorNetworks`PackageScope`" <> n];
Echo[{$Version, $SystemID, PacletObject["Wolfram/Arrays"]["Version"]}, "runtime"];
Echo[{Options[TensorNetworkContraction], Options[p["contractTensorPair"]]}, "live options"];
manifest = Import["/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance/results/profile-verify-round1/corpus/manifest.json", "RawJSON"];
root = "/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance/results/profile-verify-round1/corpus";
load[spec_] := Developer`ToPackedArray[ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["real"]}], "Real64", ByteOrdering -> -1], spec["shape"]]];
case = SelectFirst[manifest["cases"], #["id"] === "chain-n4-d8-real" &];
tensors = load /@ case["tensors"];
data = TensorNetworkData[TensorNetwork[tensors, case["labels"] -> case["output"]]];
tree = PathToTreePath[case["path"] + 1];
ref = Fold[Dot, First[tensors], Rest[tensors]];
ClearSystemCache[];
Echo[{TreePathQ[{}], TreePathQ[{{}}], TreePathQ[{{1}, {2}}], TreePathQ[bad], TreePathQ[tree], s["treeSteps"][tree, AssociationThread[List /@ Range[4], Range[4]]]}, "tree boundaries"];
SetAttributes[collect, HoldAllComplete];
collect[HoldCompleteForm[e_]] := With[{head = Head[Unevaluated[e]], args = List @@ Unevaluated[e]}, Sow[{head, args}, "captured"]];
replayResults = Table[
    Block[{trace},
      trace = Reap[TraceScan[collect, TensorNetworkContraction[data, tree, Method -> method, "Inactive" -> False],
        HoldPattern[(Wolfram`TensorNetworks`Contraction`PackagePrivate`contractTreePath | Wolfram`TensorNetworks`Contraction`PackagePrivate`contractStep |
          Wolfram`TensorNetworks`Contraction`PackagePrivate`contractTensorPair | Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumDot |
          Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumArrayDot | Wolfram`TensorNetworks`Contraction`PackagePrivate`settleLeaf)[___]], TraceInternal -> False], "captured"];
      frozen[method] = DeleteDuplicates[First[trace[[2]]]];
      {method, Norm[Flatten[trace[[1]] - ref]], Counts[SymbolName[First[#]] & /@ frozen[method]],
        AllTrue[Select[frozen[method], MemberQ[{"einsumDot", "einsumArrayDot"}, SymbolName[First[#]]] &],
          Function[call, ArrayQ[call[[2, 2]], 2, MachineNumberQ] && ArrayQ[call[[2, 3]], 2, MachineNumberQ]]],
        AllTrue[Select[frozen[method], SymbolName[First[#]] === "contractTreePath" &], AssociationQ[#[[2, 2]]] && AssociationQ[#[[2, 4]]] &]}
    ], {method, {"Dot", "ArrayDot"}}];
Echo[replayResults, "capture topology and evaluated operands"];
Clear[tensors, data, tree, ref];
Echo[Table[{method, AllTrue[Select[frozen[method], SymbolName[First[#]] === "contractTreePath" &],
  Function[call, ArrayQ[First[Apply @@ call], 2, NumberQ]]],
  AllTrue[Select[frozen[method], MemberQ[{"einsumDot", "einsumArrayDot"}, SymbolName[First[#]]] &],
    Function[call, Norm[Flatten[First[Apply @@ call] - Dot[call[[2, 2]], call[[2, 3]]]]] < 10^-12]]}, {method, {"Dot", "ArrayDot"}}], "replay survives clearing setup symbols"];
ordered[i_, j_] := With[{c = Select[i, MemberQ[j, #] &]}, {c, Select[i, ! MemberQ[c, #] &], Select[j, ! MemberQ[c, #] &]}];
source[i_, j_] := With[{c = DeleteElements[DeleteDuplicates[Join[i, j]], SymmetricDifference[i, j]]}, {c, DeleteElements[i, c], DeleteElements[j, c]}];
labelLists = Join[{{}}, Flatten[Permutations /@ Rest[Subsets[Range[4]]], 1], {{a, b}, {b, c}, {"a", "b"}}];
labelChecks = Flatten[Outer[Function[{i, j}, SameQ[ordered[i, j], source[i, j]]], labelLists, labelLists, 1]];
Echo[{Length[labelChecks], Count[labelChecks, True], Count[labelChecks, False]}, "exhaustive unique-label equivalence"];
tensors = load /@ case["tensors"];
data = TensorNetworkData[TensorNetwork[tensors, case["labels"] -> case["output"]]];
key = p["planKey"][data, "ArrayDot"];
variants = <|
  "values_same_support" -> Append[data, "Tensors" -> (2 tensors)],
  "support" -> Append[data, "Tensors" -> ReplacePart[tensors, {1, 1, 1} -> 0.]],
  "output" -> Append[data, "FreeIndices" -> Reverse[data["FreeIndices"]]],
  "dimensions" -> Append[data, "Tensors" -> ReplacePart[tensors, 1 -> ArrayReshape[First[tensors], {2, 32}]]],
  "precision" -> Append[data, "Tensors" -> SetPrecision[tensors, 30]],
  "container" -> Append[data, "Tensors" -> (SparseArray /@ tensors)]|>;
Echo[Join[Association @ KeyValueMap[#1 -> SameQ[key, p["planKey"][#2, "ArrayDot"]] &, variants], <|"method" -> SameQ[key, p["planKey"][data, "Dot"]]|>], "same-key checks; only values expected True"];
Echo[Table[With[{h = p[name]}, {name, ToString[First /@ DownValues[h], InputForm], Attributes[h]}], {name, {"planKey", "leafSignature", "einsumDot", "einsumArrayDot", "contractStep", "contractTreePath", "settleLeaf"}}], "live signatures and attributes"];
Echo[Table[{ToString[v, InputForm], p["numericLeafQ"][v], Dimensions[v]}, {v, {1., Pi, x, {}, {{1., 2.}}, {{x}}, {{1}, {2, 3}}}}], "numeric classification boundaries"];
Echo[{Head[First[First[Unitize[First[tensors]]]]], Developer`PackedArrayQ[Unitize[First[tensors]]], ByteCount[First[tensors]], ByteCount[Unitize[First[tensors]]]}, "mask storage"];
Exit[If[AllTrue[labelChecks, TrueQ], 0, 1]];
