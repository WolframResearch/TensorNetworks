# `ContractIndices` investigation (Wolfram/TensorNetworks)

Investigation only. No kernel, `PacletInfo.wl`, `Usage.wl`, or audit files were modified.

- **Anchor commit:** `f383b09` (HEAD is at the anchor; the audit drift check returns empty, so the audit is current).
- **Symbol:** `Wolfram`TensorNetworks`ContractIndices`, defined at [`Paths.wl:99`](../../TensorNetworks/Kernel/Paths.wl), usage at [`Usage.wl:42`](../../TensorNetworks/Kernel/Usage.wl), listed in [`PacletInfo.wl:28`](../../TensorNetworks/PacletInfo.wl).
- All claims below were verified against a live `wolframscript` kernel after `Needs["Wolfram`TensorNetworks`"]`.

The definition:

```wl
ContractIndices[i_, j_] := With[{c = Complement[Join[i, j], SymmetricDifference[i, j]]},
    c -> {DeleteElements[DeleteDuplicates[i], c], DeleteElements[DeleteDuplicates[j], c]}
]
```

---

## 1. Exact semantics

`ContractIndices[i, j]` returns a **`Rule`** `shared -> {remaining_i, remaining_j}` where:

- `shared` is the set of labels common to both operands (set-deduplicated, canonically sorted),
- `remaining_i` is `DeleteDuplicates[i]` with the shared labels removed (the surviving free labels of operand `i`),
- `remaining_j` likewise for operand `j`.

It is **not** "the list of indices that would be contracted (their intersection)" as the usage string claims (see §4): the intersection is only the `Rule`'s left-hand side; the return value is the whole `Rule`.

### Worked examples (live kernel)

| Call | Result |
| --- | --- |
| disjoint `ci[{1,2},{3,4}]` | `{} -> {{1,2},{3,4}}` |
| identical `ci[{1,2},{1,2}]` | `{1,2} -> {{},{}}` |
| partial `ci[{1,2},{2,3}]` | `{2} -> {{1},{3}}` |
| repeat in one operand `ci[{1,1,2},{2,3}]` | `{2} -> {{1},{3}}` |
| repeated shared `ci[{1,2,2},{2,3}]` | `{2} -> {{1},{3}}` |
| both repeat `ci[{1,2,2},{2,2,3}]` | `{2} -> {{1},{3}}` |
| empty operand `ci[{},{2,3}]` | `{} -> {{},{2,3}}` |
| `Superscript` labels `ci[{1¹,1²},{1²,2³}]` | `{1²} -> {{1¹},{2³}}` |
| bond-group (list-valued) labels `ci[{b1,b2},{b2,b3}]` | `{b2} -> {{b1},{b3}}` |

(`b1,b2,b3` are bond pairs such as `{Superscript[1,1],Superscript[3,1]}`; `ContractIndices` treats each whole list as one opaque label, so list-valued bond groups work.)

### `Complement[Join[i,j], SymmetricDifference[i,j]]` is exactly `Intersection[i,j]`

The shared-label expression is an obfuscated set intersection. An element of `Join[i,j]` lies in `i`-only, `j`-only, or both; `SymmetricDifference[i,j]` is precisely the "exactly one" elements; `Complement` strips those, leaving the in-both elements, deduplicated and canonically sorted: identical to `Intersection[i,j]`. The multiset multiplicities introduced by `Join` are irrelevant because `Complement` deduplicates.

Verified empirically: `Complement[Join[i,j], SymmetricDifference[i,j]] === Intersection[i,j]` held for **all 10,000 random cases** (5,000 integer-label, 5,000 list/`Superscript`-label), plus the hand cases above. **No multiset divergence exists.** The `Join`/`SymmetricDifference` form could be replaced verbatim by `Intersection[i, j]` with no behavioral change (a cosmetic simplification, not a bug).

The only multiset-sensitive subtlety is benign: when a label is repeated **within** one operand (`{1,1,2}`), the `remaining` lists still come out deduplicated because the body applies `DeleteDuplicates` to each operand before removing the shared set. So `remaining_i`/`remaining_j` are always duplicate-free.

### Edge case that matters: a label shared across 3+ operands

`ContractIndices` is strictly pairwise and **removes** the shared label from both `remaining` lists. If the same label is meant to connect a third, not-yet-merged operand (a genuine hyperedge), the label is gone after the first pairwise merge and will never contract with the third operand. Concretely:

```
ci[{1,9},{2,9}]  ->  {9} -> {{1},{2}}      (* 9 deleted from both remainders *)
```

So `ContractIndices` (and `PathIndexContractions` built on it) is correct **only on binarized networks**, where every index appears in at most two operands. This is exactly the assumption the surrounding error message documents (§2).

---

## 2. How `PathIndexContractions` consumes it ([`Paths.wl:109-128`](../../TensorNetworks/Kernel/Paths.wl))

There are three signatures.

### (a) `PathIndexContractions[path, indices]` — raw labels ([`:109`](../../TensorNetworks/Kernel/Paths.wl))

```wl
DeleteCases[{}] @ FoldPairList[
  With[{c = ContractIndices @@ #1[[#2]]},
       {c[[1]], Append[Delete[#1, List /@ #2], Catenate[c[[2]]]]}] &,
  indices, path]
```

`FoldPairList` walks the path. At each step the current operand list `#1` is indexed by the path pair `#2 = {a,b}`; `ContractIndices` is applied to those two operands; it **emits** the shared labels (`c[[1]]`) as that step's contraction set, and **threads** a new operand list: the two consumed operands are `Delete`d and a merged operand `Catenate[c[[2]]]` (the two remainders concatenated) is appended at the end. This is the opt_einsum path convention (both positions removed, merged result appended). `DeleteCases[{}]` drops steps that contracted nothing (outer products).

**Arity requirement** (`PathIndexContractions::indlen`, [`:103`](../../TensorNetworks/Kernel/Paths.wl)): `Length[indices]` must equal `Length[path] + 1` (one starting operand per leaf). Verified: a mismatched call messages and returns `$Failed`.

**Returns raw labels.** Each step's value is whatever labels were shared. Critically, this form needs the per-operand index lists to encode shared bonds as **repeated identical labels**. So:

- With integer hyperedge labels (shared across tensors), it works:
  `PathIndexContractions[{{1,2},{1,2}}, {{1,2},{2,3},{3,1}}]` → `{{2}, {1,3}}`.
- With `tn["Data"]["Indices"]` (per-tensor-unique `Superscript[tensor, bond]` labels, **no** repeats across tensors), every step contracts nothing → returns `{}`. The shared-bond information for a real `TensorNetwork` lives in `"Contractions"`, not `"Indices"`. This is why the data-association form below folds over `"Contractions"`, not `"Indices"`.

Hyperedge caveat confirmed: `PathIndexContractions[{{1,2},{1,2}}, {{1,9},{2,9},{3,9}}]` → `{{9}}` (only one merge records `9`; the third `9` is silently dropped). Hyperedge networks must be binarized first.

### (b) `PathIndexContractions[path, indices, contractions]` — integer positions ([`:122`](../../TensorNetworks/Kernel/Paths.wl))

```wl
With[{index = First /@ PositionIndex[Catenate[indices]]},
     Map[Lookup[index, #] &, PathIndexContractions[path, contractions], {3}]]
```

It runs form (a) on **`contractions`** (the per-tensor bond-group lists, where each bond group is a list shared by exactly the two tensors it joins), then maps each surviving bond-group label to its **integer position** in `Catenate[indices]`. Returns a list (per step) of lists of position pairs.

Verified on the 3-tensor ring: `{{{2,3}}, {{1,6},{4,5}}}` (nested: per step, per contracted bond, the two endpoint positions).

### (c) `PathIndexContractions[path, data]` — flattened ([`:127`](../../TensorNetworks/Kernel/Paths.wl))

```wl
PathIndexContractions[path_List, KeyValuePattern[{"Indices" -> indices_, "Contractions" -> contractions_}]] :=
  Catenate @ PathIndexContractions[path, indices, contractions]
```

Accepts an association with `"Indices"` and `"Contractions"` keys (e.g. `tn["Data"]`) and returns form (b) flattened one level: `{{2,3}, {1,6}, {4,5}}`. Verified identical whether passed `KeyTake[data, {"Indices","Contractions"}]` or the full `tn["Data"]`.

**Summary of return shapes** (3-tensor ring, path `{{1,2},{1,2}}`):

| Signature | Input | Output |
| --- | --- | --- |
| (a) | raw integer labels `{{1,2},{2,3},{3,1}}` | `{{2},{1,3}}` (labels) |
| (b) | `Indices` + `Contractions` | `{{{2,3}},{{1,6},{4,5}}}` (positions, per-step) |
| (c) | `tn["Data"]` assoc | `{{2,3},{1,6},{4,5}}` (positions, flattened) |

---

## 3. Export / visibility issue (in depth)

Confirmed in a fresh kernel after `Needs["Wolfram`TensorNetworks`"]`:

| Probe | Result |
| --- | --- |
| `DownValues[Wolfram`TensorNetworks`ContractIndices]` | `{}` (0 rules) |
| `ValueQ[Wolfram`TensorNetworks`ContractIndices::usage]` | `False` |
| `ContractIndices[{1,2},{2,3}]` (public) | returns **unevaluated** |
| `DownValues[…Paths`PackagePrivate`ContractIndices]` | 1 rule |
| `…Paths`PackagePrivate`ContractIndices[{1,2},{2,3}]` | `{2} -> {{1},{3}}` ✓ |
| `…Usage`PackagePrivate`ContractIndices::usage` set | `True` |
| `DownValues[Wolfram`TensorNetworks`PathIndexContractions]` | 3 rules ✓ |

**Root cause.** [`Paths.wl`](../../TensorNetworks/Kernel/Paths.wl) `PackageExport`s seven symbols (lines 4-10): `TreePathQ`, `PathQ`, `CanonicalPathQ`, `TreePathToPath`, `PathToTreePath`, `CanonicalPath`, `PathIndexContractions`. It does **not** `PackageExport[ContractIndices]`. Because the file opens with `Package["Wolfram`TensorNetworks`"]`, an un-exported symbol first mentioned at line 99 resolves into the file's private context `Wolfram`TensorNetworks`Paths`PackagePrivate`ContractIndices`. Independently, [`Usage.wl:42`](../../TensorNetworks/Kernel/Usage.wl) sets `ContractIndices::usage` inside *its* file, so the usage attaches to `Wolfram`TensorNetworks`Usage`PackagePrivate`ContractIndices` (a different private symbol). Meanwhile [`PacletInfo.wl:28`](../../TensorNetworks/PacletInfo.wl) declares the **public** `Wolfram`TensorNetworks`ContractIndices` as an autoload symbol, but nothing ever defines that public symbol.

**Net effect.** The documented, autoload-declared `ContractIndices` is **inaccessible**: 0 DownValues, no usage, calls return unevaluated. The working definition and the usage string live in two *different* private contexts, neither reachable as `ContractIndices` from a user session. This is the exact mirror of audit Finding **F1** (symbols exported but missing from `PacletInfo`); here the symbol is in `PacletInfo` and documented but **never exported**.

**`PathIndexContractions` is unaffected.** It is genuinely exported and calls `ContractIndices` from within the same file/private context, so the internal call resolves to the working private definition. All three `PathIndexContractions` signatures work (verified). No other file references `ContractIndices` (grep across `*.wl`/`*.m`/`*.nb`: only `Paths.wl:99`, `Paths.wl:115`, `Usage.wl:42`, `PacletInfo.wl:28`), so nothing else breaks.

**Cleanest fix options** (pick one; do not apply yet):

- **(a) Make it public** (matches the documentation + `PacletInfo` intent). Add `PackageExport[ContractIndices]` to [`Paths.wl`](../../TensorNetworks/Kernel/Paths.wl) alongside the other seven exports (lines 4-10). The usage in `Usage.wl:42` will then attach to the public symbol (all `Usage.wl` `::usage` assignments rely on the symbol already being exported elsewhere, as they are for the other Paths symbols). No change needed in `PacletInfo.wl`. **Recommended**, since the function is documented, listed for autoload, and is a coherent companion to the exported `PathIndexContractions`.
- **(b) Make it fully private.** Remove `"Wolfram`TensorNetworks`ContractIndices"` from the `Symbols` list in [`PacletInfo.wl:28`](../../TensorNetworks/PacletInfo.wl) and delete the `ContractIndices::usage` block at [`Usage.wl:42`](../../TensorNetworks/Kernel/Usage.wl). The internal call site keeps working unchanged. Choose this only if the function is not intended as public API.

Option (a) is the smaller, more consistent change and keeps the autoload list honest.

---

## 4. Usage-string correctness

`ContractIndices::usage` ([`Usage.wl:42`](../../TensorNetworks/Kernel/Usage.wl)) currently reads:

> "…returns the list of indices that would be contracted between two index sets `i` and `j` (their intersection)."

This is wrong: the return is a `Rule` `intersection -> {remaining_i, remaining_j}`, not just the intersection list. Proposed corrected wording (plain-text gist; the actual string is the boxed `RowBox` form):

> `ContractIndices[i, j]` returns a rule `shared -> {keep_i, keep_j}` whose left side `shared` is the set of index labels common to `i` and `j` (the labels contracted when the two operands merge) and whose right side lists the surviving, deduplicated labels of `i` and of `j` after removing `shared`.

### Drift in the other Paths usage strings

- `PathIndexContractions::usage` ([`Usage.wl:240`](../../TensorNetworks/Kernel/Usage.wl)) is **accurate**: it documents all three signatures (sequence of index sets; integer-position form mapping back to `contractions` labels; and the `"Indices"`/`"Contractions"` association form, "such as `tn["Data"]`"). Matches observed behavior. One soft caveat worth adding: the 2-arg form only reports contractions when shared bonds appear as repeated labels, so on `tn["Data"]["Indices"]` (per-tensor-unique labels) it yields `{}` and the 3-arg/association forms are the ones to use; and all forms assume a binarized network for hyperedges. Optional, not a correctness bug.
- `CanonicalPathQ::usage` ([`Usage.wl:26`](../../TensorNetworks/Kernel/Usage.wl)) and `TreePathQ::usage` ([`Usage.wl:623`](../../TensorNetworks/Kernel/Usage.wl)) contain `\[LongDash]` (em dash) — already captured as audit Finding **F8**. No new finding.
- `CanonicalPath`, `PathQ`, `PathToTreePath`, `TreePathToPath` usage strings: spot-checked, descriptions match behavior; no drift.

---

## 5. Cross-check against the audit (recommend adding F11)

The `ContractIndices` export/visibility problem is **not** in [`Audit/TensorNetworks_Kernel_Audit.md`](../../Audit/TensorNetworks_Kernel_Audit.md). The audit even lists `ContractIndices` among the exported `Paths.wl` symbols in the §3.1 API table (line 135) and the §2.3 description (line 245), implicitly assuming it is public, when in fact it is not exported. Recommend adding it as a new finding **F11** (and correcting the §3.1 row to note it is currently inaccessible). The usage-string inaccuracy in §4 is best folded into the same finding rather than as a separate one.

Draft finding text, in the F1-F10 format (do **not** apply; for the audit owner to insert):

---

### F11. `ContractIndices` is declared public and documented but never exported, so it is inaccessible. **[verified]**. Severity: High

[`PacletInfo.wl:28`](../../TensorNetworks/PacletInfo.wl) lists `Wolfram`TensorNetworks`ContractIndices` as an autoload symbol and [`Usage.wl:42`](../../TensorNetworks/Kernel/Usage.wl) sets `ContractIndices::usage`, but [`Paths.wl`](../../TensorNetworks/Kernel/Paths.wl) never calls `PackageExport[ContractIndices]` (it exports the other seven `Paths.wl` symbols at lines 4-10). The definition at `Paths.wl:99` therefore binds in the file-private context `Wolfram`TensorNetworks`Paths`PackagePrivate`ContractIndices`, and the usage binds in yet another private context `Wolfram`TensorNetworks`Usage`PackagePrivate`ContractIndices`. Effect (verified in a fresh kernel after `Needs`): the public `Wolfram`TensorNetworks`ContractIndices` has 0 DownValues, no usage, and the documented call `ContractIndices[{1,2},{2,3}]` returns unevaluated. `PathIndexContractions` is unaffected because it calls `ContractIndices` from inside the same private context. This is the inverse of F1 (there: exported but missing from `PacletInfo`; here: in `PacletInfo` and documented but not exported). Secondary defect: even once reachable, the usage string is wrong: it says the function "returns the list of indices that would be contracted … (their intersection)", but the actual return is a `Rule` `intersection -> {remaining_i, remaining_j}`.
*Fix:* add `PackageExport[ContractIndices]` to `Paths.wl` (preferred: matches the documented, autoload-declared intent), or, if it is meant to be internal, remove it from the `PacletInfo.wl` `Symbols` list and delete its usage block. Either way, correct `ContractIndices::usage` to describe the `Rule` return shape. Also note that the §3.1 API table (audit line 135) currently lists `ContractIndices` as an exported `Paths.wl` symbol; that row should be annotated as currently inaccessible until the export is added.

---

## Appendix: reproduction

Scripts used (throwaway, under `/private/tmp/`): `ci_investigate.wl` (visibility), `ci_semantics.wl` / `ci_semantics2.wl` (semantics, three signatures, hyperedge/binarization), `ci_fuzz.wl` (10,000-case `Complement[Join,SymmetricDifference] === Intersection`). All run with `wolframscript -file …`.
