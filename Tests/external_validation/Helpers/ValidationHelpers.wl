(* Tests/external_validation/Helpers/ValidationHelpers.wl

Helpers for the external-validation test suite. Loads the paclet, provides
capability-gating + skip-recording so that the master runner can distinguish:

  Pass         — assertion held
  Failure      — assertion violated (numeric mismatch or wrong value)
  SkipRNG      — test depends on RNG that cannot be reproduced cross-language
  SkipMissing  — paclet lacks a required symbol/feature for this test
  Error        — test threw an unexpected exception (bug, not gap)

Skipped/missing/error records are kept in global associations so that
run_external_validation.wl can pull them out and write SKIPPED_AND_MISSING.md.
*)

(* Locate worktree root by walking up from cwd looking for PacletInfo.wl. *)
$ValidationWorktreeRoot = SelectFirst[
    NestList[ParentDirectory, Directory[], 8],
    DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
    Directory[]
];

PacletDirectoryLoad[FileNameJoin[{$ValidationWorktreeRoot, "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];
Quiet @ Needs["Wolfram`TensorNetworks`Symmetry`"];

(* Global accumulators — read by the master runner *)
$ValidationRNGSkipped = <||>;       (* id -> <| reason, source |> *)
$ValidationMissingSkipped = <||>;   (* id -> <| missing -> {syms}, source |> *)
$ValidationErrors = <||>;           (* id -> <| error, source |> *)
$ValidationCapabilityCache = <||>;  (* sym -> Bool *)

(* Reset all accumulators (called at the start of each tier file) *)
ClearValidationRecords[] := (
    $ValidationRNGSkipped = <||>;
    $ValidationMissingSkipped = <||>;
    $ValidationErrors = <||>;
);

(* Capability detection — uses Names[] which handles backticked context strings cleanly. *)
HasSymbolQ[name_String] := Module[{cached},
    cached = Lookup[$ValidationCapabilityCache, name, Missing[]];
    If[!MissingQ[cached], Return[cached]];
    cached = Or[
        Names["Wolfram`TensorNetworks`" <> name] =!= {},
        Names["Wolfram`TensorNetworks`IndexArray`" <> name] =!= {},
        Names["Wolfram`TensorNetworks`Symmetry`" <> name] =!= {}
    ];
    AssociateTo[$ValidationCapabilityCache, name -> cached];
    cached
];

(* Record a skip due to RNG-dependence *)
RecordSkipRNG[id_String, reason_String, source_String] := (
    AssociateTo[$ValidationRNGSkipped, id -> <|"reason" -> reason, "source" -> source|>];
);

(* Record a skip due to missing paclet feature *)
RecordSkipMissing[id_String, missing_List, source_String] := (
    AssociateTo[$ValidationMissingSkipped, id -> <|"missing" -> missing, "source" -> source|>];
);

(* Record an error (unexpected exception during test setup or assertion) *)
RecordError[id_String, errMsg_, source_String] := (
    AssociateTo[$ValidationErrors, id -> <|"error" -> ToString[errMsg], "source" -> source|>];
);

(* withCapability[{symA, symB, ...}, id, source, body]:
     If all symbols bound, evaluate body. Otherwise record SkipMissing and skip. *)
SetAttributes[WithCapability, HoldRest];
WithCapability[required_List, id_String, source_String, body_] := Module[{missing},
    missing = Select[required, !HasSymbolQ[#] &];
    If[Length[missing] > 0,
        RecordSkipMissing[id, missing, source];
        Null
    ,
        body
    ]
];

(* SkipDueToRNG[id, reason, source] — explicit skip for RNG cases *)
SkipDueToRNG[id_String, reason_String, source_String] := (
    RecordSkipRNG[id, reason, source];
    Null
);

(* parityClose[a, b, tol] — within tol; works for numeric + arrays *)
ValidationClose[a_, b_, tol_:1.*^-10] := Module[{diff},
    Catch[
        If[ListQ[a] || ListQ[b],
            If[Dimensions[a] =!= Dimensions[b], Throw[False]];
            Throw[Max[Abs[Flatten[a - b]]] <= tol]
        ];
        Throw[Abs[a - b] <= tol]
    ]
];

(* pathCost: walk a contraction path under the opt_einsum convention
   (remove positions i,j; append merged at end) and sum per-step flops.

   Per-step cost = product of dims of all unique legs in the union of the
   two tensors. This matches both:
     - cotengra's mul-count `_flops` with dtype=None (cotengra/core.py:1196)
     - paclet Rust optimizer's `compute_flops` (Cotengra/src/lib.rs:115).
   The merged tensor's surviving legs are those open in the original network
   (appearing exactly once globally) OR appearing in remaining tensors. *)
pathCost[indicesPerTensor_, sizeDict_, path_] := Module[
    {idxs = indicesPerTensor, totalCost = 0, openLegs,
     i, j, mergedIdx, remaining, surviving},
    openLegs = Keys @ Select[Counts[Catenate[indicesPerTensor]], # === 1 &];
    Do[
        {i, j} = path[[step]];
        mergedIdx = DeleteDuplicates @ Join[idxs[[i]], idxs[[j]]];
        totalCost += Times @@ (sizeDict /@ mergedIdx);
        remaining = Delete[idxs, {{i}, {j}}];
        surviving = Select[mergedIdx,
            With[{leg = #},
                MemberQ[openLegs, leg] || AnyTrue[remaining, MemberQ[#, leg] &]
            ] &];
        idxs = Append[remaining, surviving]
    , {step, Length[path]}];
    totalCost
];

(* parityCloseRel[a, b, rtol] — relative tolerance comparison *)
ValidationCloseRel[a_, b_, rtol_:1.*^-6] := Module[{denom},
    Catch[
        If[ListQ[a] || ListQ[b],
            If[Dimensions[a] =!= Dimensions[b], Throw[False]];
            denom = Max[Abs[Flatten[b]], 1.*^-30];
            Throw[Max[Abs[Flatten[a - b]]] / denom <= rtol]
        ];
        denom = Max[Abs[b], 1.*^-30];
        Throw[Abs[a - b] / denom <= rtol]
    ]
];

(* ============ Fuzz-layer helpers (paclet_fuzz/) ============ *)

(* WithBudget[seconds, expr] — evaluate expr, return True iff the result is
   True AND the wall-clock time is within budget. Used in fuzz files to attach
   a timing sentinel to a correctness check. *)
SetAttributes[WithBudget, HoldRest];
WithBudget[seconds_, expr_] := Module[{t, r}, {t, r} = AbsoluteTiming[expr]; TrueQ[r] && t <= seconds];

(* TNShapeSpec[tn] — extract ({indices-per-tensor}, sizeDict) from a paclet
   TensorNetwork object. Suitable for feeding pathCost or differential checks. *)
TNShapeSpec[tn_] := Module[{shapes},
    shapes = tn["Indices"];
    {
        shapes,
        AssociationThread[
            Flatten[shapes],
            Flatten[MapThread[Take[#1, Length[#2]] &, {tn["Dimensions"], shapes}]]
        ]
    }
];

(* PathValidQ[path, n] — True iff `path` is a well-formed list of (n-1) merge
   steps over n tensors: each step is a pair of distinct in-range positions
   under the opt_einsum convention (remove both positions, append merged at end). *)
PathValidQ[path_, n_Integer] := Module[{working, i, j},
    Which[
        n === 1, path === {},
        ! ListQ[path], False,
        Length[path] =!= n - 1, False,
        True,
            working = Range[n];
            Catch[
                Do[
                    {i, j} = path[[k]];
                    If[! (IntegerQ[i] && IntegerQ[j]) || i === j, Throw[False]];
                    If[i < 1 || j < 1 || i > Length[working] || j > Length[working],
                        Throw[False]];
                    working = Append[Delete[working, {{i}, {j}}], k + n];
                ,
                    {k, n - 1}
                ];
                Length[working] === 1
            ]
    ]
];


(* OracleFixturePath[name] — resolve a fixture under external_oracles/fixtures/.
   The fixtures are committed to the repo; they were extracted offline from
   numerical packages (cotengra, quimb, ...) via the scripts in external_oracles/. *)
OracleFixturePath[name_String] := Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "external_oracles", "fixtures", name}],
            Null],
        FileNameJoin[{$ValidationWorktreeRoot, "Tests", "external_validation", "external_oracles", "fixtures", name}],
        FileNameJoin[{Directory[], "Tests", "external_validation", "external_oracles", "fixtures", name}],
        FileNameJoin[{Directory[], "external_validation", "external_oracles", "fixtures", name}],
        FileNameJoin[{Directory[], "external_oracles", "fixtures", name}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Message[General::nffil, name]; $Failed,
        found
    ]
];


(* ValidationWriteSkipLog[outFile] — called by the master runner. *)
ValidationWriteSkipLog[outFile_String,
    Optional[passCount_Integer, 0],
    Optional[failCount_Integer, 0]] := Module[{lines, time, sec},
    time = DateString[];
    lines = {};
    AppendTo[lines, "# Skipped & Missing Features Report"];
    AppendTo[lines, ""];
    AppendTo[lines, "Auto-generated by `run_external_validation.wl` on " <> time <> "."];
    AppendTo[lines, ""];
    AppendTo[lines, "## Summary"];
    AppendTo[lines, ""];
    AppendTo[lines, "- Passed: " <> ToString[passCount]];
    AppendTo[lines, "- Failed: " <> ToString[failCount]];
    AppendTo[lines, "- Skipped (RNG-dependent): " <> ToString[Length[$ValidationRNGSkipped]]];
    AppendTo[lines, "- Skipped (paclet feature missing): " <> ToString[Length[$ValidationMissingSkipped]]];
    AppendTo[lines, "- Errors (unexpected): " <> ToString[Length[$ValidationErrors]]];
    AppendTo[lines, ""];

    mkRow[cells_] := "| " <> StringRiffle[Map[ToString, cells], " | "] <> " |";

    sec[title_, items_, headerCols_, rowFn_] := (
        AppendTo[lines, "## " <> title];
        AppendTo[lines, ""];
        If[Length[items] === 0,
            AppendTo[lines, "_(none)_"];
        ,
            AppendTo[lines, mkRow[headerCols]];
            AppendTo[lines, mkRow[ConstantArray["---", Length[headerCols]]]];
            KeyValueMap[
                Function[{id, info}, AppendTo[lines, mkRow[rowFn[id, info]]]],
                items
            ];
        ];
        AppendTo[lines, ""];
    );

    sec["Skipped: RNG-dependent",
        $ValidationRNGSkipped,
        {"Test ID", "Source", "Reason"},
        Function[{id, info},
            {id, Lookup[info, "source", ""], Lookup[info, "reason", ""]}]];

    sec["Skipped: paclet feature missing",
        $ValidationMissingSkipped,
        {"Test ID", "Source", "Missing symbols"},
        Function[{id, info},
            {id, Lookup[info, "source", ""],
             StringRiffle[Map[ToString, Lookup[info, "missing", {}]], ", "]}]];

    sec["Errors (unexpected -- investigate as bugs)",
        $ValidationErrors,
        {"Test ID", "Source", "Error"},
        Function[{id, info},
            {id, Lookup[info, "source", ""], Lookup[info, "error", ""]}]];

    Export[outFile, StringRiffle[lines, "\n"], "Text"];
    outFile
];
