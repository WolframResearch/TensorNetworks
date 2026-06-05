# CLAUDE.md: Wolfram/TensorNetworks

## Read the kernel audit first

Before answering any question about this paclet's kernel, or auditing / reviewing /
checking / cross-referencing anything against it, read
[`Audit/TensorNetworks_Kernel_Audit.md`](Audit/TensorNetworks_Kernel_Audit.md) **fully**
(no sampling, per the global File Reading Policy). It covers the architecture, execution
modes, the 84-symbol public API with per-object key listings, a faithful kernel
description (core plus the `IndexArray` and `Symmetry` sub-contexts), and a findings
section with `file:line`, severity, and fixes.

The audit is a point-in-time snapshot. `Audit/last-synced.md` is the **single source of
truth for the anchor commit**: read it first, run its drift-check command, and if the
kernel (`TensorNetworks/Kernel` or `TensorNetworks/PacletInfo.wl`) has moved past the
anchor, re-verify any cited `file:line` against the live kernel with `wolframscript`
before relying on it. Regenerate per `Audit/update-runbook.md` (re-read all kernel files,
rewrite the audit, bump the SHA in `last-synced.md` only). The `Audit/` folder is
`.gitignored` (local-only).

## Paclet facts

- Paclet / context: `Wolfram/TensorNetworks`, primary context `Wolfram`TensorNetworks``
  (version 1.0.7). Sub-contexts: `Wolfram`TensorNetworks`IndexArray``,
  `Wolfram`TensorNetworks`Symmetry``.
- Kernel source: `TensorNetworks/Kernel/*.wl` (21 files; excludes any `build/` copy).
- Public API: the 84 autoload `Symbols` in `TensorNetworks/PacletInfo.wl`. (Three exported
  `Symmetry` symbols are currently missing from that list: see Finding F1.)
- Rust optimizer (`Cotengra/`, via `ExtensionCargo`/`CargoLoad`) and the C++ Netcon
  LibraryLink back the path-finders; they are out of scope for the kernel audit except
  where the kernel calls into them.

## Wolfram Language conventions

Follow the global `~/.claude/CLAUDE.md` Wolfram rules: idiomatic functional WL, no
`Print` / `Quiet`, no `_` in identifiers, and use `wolframscript -file …` via Bash for
evaluation (not the evaluator MCP). Tests live under `Tests/` (run via
`wolframscript -file Tests/run_debug.wl`).
