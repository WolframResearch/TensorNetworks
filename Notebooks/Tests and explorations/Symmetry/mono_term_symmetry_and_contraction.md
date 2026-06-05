# Mono-Term Symmetry and Tensor-Network Contraction

The Wolfram Language kernel ships a compact language for tensor symmetry: a tensor is declared equal to a phased permutation of itself, and `SymmetrizedArray` stores only the independent components. This note asks one precise question and answers it by computation: when such a symmetry-structured tensor becomes a *node* in a `Wolfram`TensorNetworks`` network, what exactly happens to its symmetry under contraction? We build every result explicitly so it can be tested, modified, and extended, and we let the kernel correct us wherever intuition is wrong.

We start with the kernel's mono-term objects and what they store, test how the bare contraction primitives (`TensorContract`, `ArrayDot`) treat them, and then put the decisive question to the paclet's `TensorNetworkContract`: does declaring a symmetry change the result or the cost of a contraction? It does not. We close with the honest ceiling the experiments expose and the integration question it raises.

Load the paclet; every later cell assumes this has run.

```wl
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
```

## Mono-term symmetry: a tensor equals a permuted copy of itself

The kernel models a symmetry as a relation `φ TensorTranspose[T, perm] == T` with `φ` a root of unity: *one* permuted copy equated to the tensor. This is the mono-term language, and `Symmetric`, `Antisymmetric`, and `Hermitian` are its named symmetry types. A `SymmetrizedArray` carries the symmetry as metadata rather than expanding it. Build the two-spin singlet as a totally antisymmetric array.

```wl
eps = Symmetrize[{{0, 1}, {-1, 0}}/Sqrt[2], Antisymmetric[{1, 2}]];
{MatchQ[eps, _SymmetrizedArray], Normal[eps]}
(* {True, {{0, 1/Sqrt[2]}, {-(1/Sqrt[2]), 0}}} *)
```

The structure test returns `True`, so the object is still a `SymmetrizedArray`, and `Normal` expands it to the familiar antisymmetric matrix. As one can see, the object knows it is antisymmetric without us repeating the entries.

`Symmetrize` is not merely a relabeling; it is the orthogonal projector onto the symmetry class, so applying it twice changes nothing. Verify idempotence on a generic 2x2 array.

```wl
g = Array[a, {2, 2}];
Normal@Symmetrize[Normal@Symmetrize[g, Symmetric[{1, 2}]], Symmetric[{1, 2}]] ===
  Normal@Symmetrize[g, Symmetric[{1, 2}]]
(* True *)
```

The loop closes the other way too: `TensorSymmetry` inspects a concrete array and reports the largest symmetry group that fixes it. Read the symmetry back off a symmetric and an antisymmetric projection.

```wl
{TensorSymmetry[Normal@Symmetrize[g, Symmetric[{1, 2}]]],
 TensorSymmetry[Normal@Symmetrize[g, Antisymmetric[{1, 2}]]]}
(* {Symmetric[{1, 2}], Antisymmetric[{1, 2}]} *)
```

The payoff of the structured representation is storage: a `SymmetrizedArray` keeps only orbit representatives. Compare the independent-component count of the rank-3 Levi-Civita tensor with its dense entry count.

```wl
e3 = Symmetrize[LeviCivitaTensor[3], Antisymmetric[{1, 2, 3}]];
{Length[SymmetrizedArrayRules[e3]], 3^3}
(* {2, 27} *)
```

Two stored rules stand in for twenty-seven dense entries. This compression is exactly what we want a contraction engine to *propagate*; the rest of the note tests whether it does.

## What the contraction primitives do to the structure

A tensor-network contraction is built from two kernel primitives: `TensorContract` (the unfused form, contracting slots of a single tensor product) and `ArrayDot` (the fused two-tensor form the paclet prefers for speed). They do not treat structure the same way. First, contract the rank-3 `e3` against a basis vector with the *unfused* `TensorContract`, leaving a rank-2 result.

```wl
MatchQ[TensorContract[TensorProduct[e3, {1, 0, 0}], {{3, 4}}], _SymmetrizedArray]
(* True *)
```

The unfused path keeps the `SymmetrizedArray` tag. Now do the same contraction with the *fused* `ArrayDot`.

```wl
ad = ArrayDot[e3, {1, 0, 0}, {{3, 1}}];
{MatchQ[ad, _SymmetrizedArray], Normal[ad]}
(* {False, {{0, 0, 0}, {0, 0, 1}, {0, -1, 0}}} *)
```

The structure test returns `False`: `ArrayDot` has returned a plain dense `List`, and the tag is gone. Crucially, though, the *symmetry itself is not lost*, only its label. Confirm that `TensorSymmetry` still recognizes the antisymmetry in the dense values.

```wl
TensorSymmetry[ad]
(* Antisymmetric[{1, 2}] *)
```

So the two primitives diverge on bookkeeping even though they agree on the numbers. Before moving into the paclet, summarize what the kernel layer establishes:

- A `SymmetrizedArray` stores a mono-term symmetry as metadata and only the independent components.
- `Symmetrize` is an idempotent projector; `TensorSymmetry` is its inverse reader.
- Unfused `TensorContract` preserves the `SymmetrizedArray` tag when the result has rank at least 2.
- Fused `ArrayDot` returns a dense `List`; the symmetry survives in the values but the tag is dropped.

## Inside the TensorNetworks paclet

`TensorNetworkContract` is what we actually call, and it can pick any of several contraction methods. The natural question is which of the kernel behaviors above it inherits. Start with the degenerate case: a network of a single node with two free indices and *no* shared index, so no contraction happens.

```wl
tnEps = TensorNetwork[{eps}, {{"a", "b"}}, {"a", "b"}];
MatchQ[TensorNetworkContract[tnEps], _SymmetrizedArray]
(* True *)
```

With nothing to contract, the paclet hands the node back untouched and the tag survives. Now make it a real contraction: wire the rank-3 `e3` to a vector on index `"c"`, leaving two free legs, and sweep every available method.

```wl
tn = TensorNetwork[{e3, {1, 0, 0}}, {{"a", "b", "c"}, {"c"}}, {"a", "b"}];
Table[m -> MatchQ[TensorNetworkContract[tn, Method -> m], _SymmetrizedArray],
  {m, {"ArrayDot", "ArrayDotTranspose", "Dot", "TensorContract", "TableSum"}}]
(* {"ArrayDot" -> False, "ArrayDotTranspose" -> False, "Dot" -> False,
    "TensorContract" -> False, "TableSum" -> False} *)
```

Every method returns `False`: the result is a dense `List` in each case. The structure tag does not survive a genuine contraction through the paclet under *any* method, including the one named after the tag-preserving kernel primitive (the paclet post-processes indices, which drops the structure tag). The symmetry is still present numerically, recoverable on demand.

```wl
TensorSymmetry[Normal@TensorNetworkContract[tn]]
(* Antisymmetric[{1, 2}] *)
```

Because the engine never *relies* on the tag, feeding it the structured array or its dense expansion must give the same answer. Verify that the `SymmetrizedArray` node and its `Normal` produce identical results.

```wl
tnDense = TensorNetwork[{Normal[eps]}, {{"a", "b"}}, {"a", "b"}];
Normal[TensorNetworkContract[tnEps]] === Normal[TensorNetworkContract[tnDense]]
(* True *)
```

The reading is clear and worth stating plainly: the paclet consumes a symmetry-structured node *correctly* but *densely*. Replacing every symmetric node with its plain dense expansion changes neither the result nor the work done, so in the current paclet declaring a symmetry buys nothing at contraction time. The symmetry is input metadata, not something the contraction propagates or exploits. That is a real limitation, and it is also exactly the seam where an integration effort would add value.

## Summary

The experiments establish a precise and slightly uncomfortable picture:

- Kernel mono-term symmetry objects store the symmetry as metadata and compress to independent components.
- Among bare primitives, unfused `TensorContract` preserves the `SymmetrizedArray` tag (rank at least 2), while fused `ArrayDot` returns a dense `List`.
- The paclet's `TensorNetworkContract` drops the tag under *every* method once a real (index-sharing) contraction occurs; only a no-contraction network returns the node untouched.
- The symmetry is never lost numerically: `TensorSymmetry` recovers it from the dense output, and structured input and its `Normal` give identical answers.
- Because the symmetric input is expanded to dense before contraction, a symmetric network and its dense counterpart give identical results at identical cost: in the current paclet, declaring a symmetry confers no speed, memory, or accuracy benefit at contraction time.

## Where this leaves us

We built symmetry-structured tensors with the kernel, fed them through the `TensorNetworks` paclet, and measured exactly what survives. The paclet contracts these nodes correctly, but the symmetry is consumed densely: a symmetric network and its dense expansion give identical results at identical cost, established here by computation rather than assertion. The `SymmetrizedArray` compression and the mono-term tag do not propagate through contraction, so the engine neither stores intermediates compactly nor exploits the symmetry for speed.

That gap is the natural starting point for the next step: making `TensorNetworkContract` symmetry-aware, so that the storage and contraction-cost benefits of a declared symmetry survive into intermediates and outputs rather than being flattened at the first `ArrayDot`. Designing that integration (how to carry block structure through the path optimizer and the fused contraction primitives) deserves its own dedicated treatment.
