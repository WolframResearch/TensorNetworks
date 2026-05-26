# Wolfram TensorNetworks

A Wolfram Language paclet for tensor networks. A network is stored as a flat list of tensors plus one list of integer index labels per tensor; in the dual picture this is a hypergraph whose vertices are the *indices* and whose hyperedges are the *tensors*. Labels appearing in two tensors mark contracted bonds; labels appearing in three or more mark genuine hyperedges, resolved on demand by inserting Kronecker-delta spiders. Contraction paths come from either an exact dynamic-programming search (an opt_einsum / Cotengra-style optimizer ported to Rust) or a fast greedy heuristic, and five interchangeable engines turn a path into the contracted tensor.

On top of the core layer, the paclet ships a Matrix Product State toolkit (canonical forms, overlap, Schmidt decomposition, entanglement entropy, truncation) and a Young-tableau subpackage for the symmetric-group decomposition of tensor slots.

Full documentation, with every symbol's reference page rendered for the web, lives at the Wolfram Paclet Repository: [resources.wolframcloud.com/PacletRepository/resources/Wolfram/TensorNetworks](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/TensorNetworks/). This README is a guided tour; the doc pages carry every calling form and option.

## Installation

Install the development version from a single paclet URL:

```wolfram
PacletInstall["https://www.wolfr.am/DevWTN", ForceVersionInstall -> True]
```

Or install the released version from the public paclet repository:

```wolfram
PacletInstall["Wolfram/TensorNetworks"]
```

To work from a local clone instead, register the paclet directory:

```wolfram
PacletDirectoryLoad["/path/to/TensorNetworks"]
```

Then load the main context:

```wolfram
Needs["Wolfram`TensorNetworks`"]
```

## Quick Start

The pipeline is the same for every problem: build a network, plan a contraction order, execute. The default `TensorNetworkContract` collapses all three steps into one call; the planner and engine become explicit when cost or memory pressure forces them to be.

Build a random network whose underlying graph is a five-vertex star:

```wolfram
SeedRandom[42];
net = RandomTensorNetwork[StarGraph[5], Method -> "Complex"]
```

Contract it with the default planner. The result is a rank-4 numerical tensor:

```wolfram
TensorNetworkContract[net]
```

Ask the greedy heuristic which order it would pick. It scores each candidate pair by the size of the resulting intermediate and commits to the cheapest at every step:

```wolfram
GreedyContractionPath[net]
```

Ask the exact dynamic-programming planner for the size-optimal path. The search is `O(3^N)` in the number of tensors and is therefore reserved for small networks (under about twenty tensors):

```wolfram
OptimalContractionPath[net]
```

The five engines that turn a path into numerical work are listed in a single global. All five compute the same mathematical contraction; the choice between them is performance, not correctness:

```wolfram
$TensorNetworkContractionMethods
```

## Building Networks

A `TensorNetwork` carries a flat list of tensors and a list of hyperedges, where each hyperedge is the list of integer leg labels of one tensor. Labels appearing in two tensors are contracted bonds; labels appearing in three or more are hyperedges (resolved by inserting delta-tensor spiders, see below); labels appearing once are free legs. The object does not commit to a contraction order, so path search, binarization, and evaluation are all downstream concerns.

Wrap two rank-2 tensors sharing one bond:

```wolfram
A = RandomReal[1, {2, 3}];
B = RandomReal[1, {3, 4}];
tn = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}]
```

Labels 1 and 3 appear once and survive as free indices:

```wolfram
tn["FreeIndices"]
```

The shared label 2 names the contracted bond. Its dimension is the common axis size of the two tensors meeting on it:

```wolfram
tn["Bonds"]
```

Every shared index touches exactly two tensors, so the network is binary (a graph rather than a true hypergraph):

```wolfram
tn["BinaryQ"]
```

### Other constructor forms

Einsum-style with an explicit output list. The right-hand side selects which indices survive after contraction:

```wolfram
TensorNetwork[{A, B}, {{1, 2}, {2, 3}} -> {1, 3}]
```

Lift an unevaluated `TensorContract` expression. The `Inactive` wrapper keeps it from evaluating eagerly, and the constructor reads the index pairs directly from the held expression:

```wolfram
TensorNetwork[Inactive[TensorContract][Inactive[TensorProduct][A, B], {{2, 3}}]]
```

Build a symbolic skeleton from the hypergraph plus a dimension association. The constructor fills each slot with an `ArraySymbol` placeholder of the matching shape, which is useful for cost analysis or symbolic codegen against a fixed topology:

```wolfram
TensorNetwork[{{1, 2}, {2, 3}} -> {1, 3}, <|1 -> 2, 2 -> 5, 3 -> 4|>]
```

### Named topologies

`RandomTensorNetwork` builds instances of the standard named TN families. The taxonomy is organized by what entanglement scaling each family can support across a spatial cut:

- **MPS** (matrix product state): boundary-law entanglement in 1D, which by the area law for gapped local Hamiltonians is a constant independent of system size. This is the dominant ansatz for one-dimensional ground states.
- **PEPS** (projected entangled pair state): boundary-law entanglement in 2D, the natural generalization to a square lattice.
- **TT** (tensor train): MPS without physical legs; a chain decomposition of a single high-rank tensor.
- **MPO** (matrix product operator): the operator analogue of an MPS, with two physical legs per site; Hamiltonians and channels in 1D.
- **TTN** (tree tensor network): entanglement organized hierarchically through a tree, with no horizontal bonds between siblings.
- **MERA** (multi-scale entanglement renormalization ansatz): a tree with horizontal disentanglers between layers, designed to reproduce the logarithmic entanglement scaling of 1D critical systems.

Each family is named by a head bearing its parameters:

```wolfram
SeedRandom[7];
RandomTensorNetwork["MPS"[6, 4, 2], Method -> "Complex"]
```

A tensor train, the structural cousin of an MPS used to compress high-rank arrays:

```wolfram
RandomTensorNetwork["TT"[6, 3]]
```

A matrix product operator. Each bulk site has two physical legs and two bond legs:

```wolfram
RandomTensorNetwork["MPO"[4, 2, 2]]
```

A PEPS on a 2x2 grid. Each site carries one bond to each grid neighbor plus one physical leg:

```wolfram
RandomTensorNetwork["PEPS"[{2, 2}, 2, 2]]
```

A tree tensor network of depth 2 with branching 2:

```wolfram
RandomTensorNetwork["TTN"[2, 2, 2]]
```

A MERA on four physical sites with two layers of disentanglers:

```wolfram
RandomTensorNetwork["MERA"[4, 2, 2]]
```

Chain families accept `"Boundary" -> "Periodic"` to wrap the last site back to the first, promoting both boundary tensors to interior shape. The periodic MPS adds one extra hyperedge linking sites 1 and 4:

```wolfram
RandomTensorNetwork["MPS"[4, 2, 2], "Boundary" -> "Periodic"]["Hyperedges"]
```

Outside the named families, any `Graph` is accepted, or `{n, m}` as a shortcut for `RandomGraph[{n, m}]`. Each graph vertex becomes a tensor with rank equal to its degree; each edge becomes a contracted bond:

```wolfram
SeedRandom[42];
RandomTensorNetwork[{5, 8}, 3]
```

### Property dispatch

A network exposes its data through `tn["Property"]`. The complete list of keys is discoverable through one accessor:

```wolfram
tn["Properties"]
```

The full data association is reachable in one call, for serialization or batch access:

```wolfram
TensorNetworkData[tn]
```

Every key has an equivalent standalone function (`TensorNetworkTensors`, `TensorNetworkSize`, `TensorNetworkFreeIndices`, etc.) that composes naturally with `Map` and friends.

### Hyperedges and binarization

A hyperedge is a label shared by three or more tensors. It encodes a copy/broadcast constraint that two-endpoint edges cannot draw, and it appears naturally in CP-style decompositions, in symmetry-restricted networks, and wherever a delta-function constraint couples more than two tensors. Pairwise contraction-path algorithms assume binary networks, so the paclet replaces each hyperedge with a small auxiliary tensor: a Kronecker-delta spider whose entries enforce the equality constraint the hyperedge encoded. The spider sits as one extra vertex wired pairwise to each tensor that previously shared the hyperedge.

Construct a network with a genuine hyperedge. The label 2 appears in three tensors:

```wolfram
T1 = RandomReal[1, {2, 3}]; T2 = RandomReal[1, {3, 4}]; T3 = RandomReal[1, {3, 5}];
hyperTN = TensorNetwork[{T1, T2, T3}, {{1, 2}, {2, 3}, {2, 4}}];
BinaryTensorNetworkQ[hyperTN]
```

`BinaryTensorNetwork` performs the binarization and recovers binary topology with one extra tensor:

```wolfram
bin = BinaryTensorNetwork[hyperTN];
BinaryTensorNetworkQ[bin]
```

The inserted tensor is a `SymbolicDeltaProductArray`, a structural placeholder for the Kronecker delta that the path planner and the contraction engine know how to handle:

```wolfram
Head[bin["Tensors"][[-1]]]
```

`OptimalContractionPath`, `GreedyContractionPath`, and `TensorNetworkContract` apply this transformation automatically; you rarely invoke it by hand. Knowing what the spider is, though, makes the resulting paths legible: any tensor in the output trace whose head is `SymbolicDeltaProductArray` is one of these inserted vertices, not a tensor from the original network.

### Edits

Networks are immutable values. Edits return new networks.

Add a tensor to an existing network. Its label 3 already exists, so it becomes a contracted bond; label 4 is new and becomes a free leg:

```wolfram
Cmat = RandomReal[1, {4, 5}];
base = TensorNetwork[{A, B}, {{1, 2}, {2, 3}}];
added = TensorNetworkAdd[base, Cmat, {3, 4}];
added["Hyperedges"]
```

Delete a tensor by position. Removing position 2 breaks the bond it carried, and the corresponding label on the surviving neighbor becomes free:

```wolfram
TensorNetworkDelete[added, 2]["Hyperedges"]
```

Convert every tensor to a `SparseArray`. The hypergraph and indices are preserved exactly; only the storage representation changes. The contraction engine takes the sparse fast path on sparse input:

```wolfram
SparseTensorNetwork[base]["SparseQ"]
```

`TensorNetworkReplaceIndices` renames legs on the annotated `Graph` form returned by `ToTensorNetworkGraph`. `TensorNetworkRemoveCycles` opens cyclic networks by inserting a cup-and-cap pair of identity tensors, which is the internal mechanism that makes periodic chains sequentially contractible. `TensorNetworkIndexGraph` collapses a network down to its index-incidence structure for path-planning sanity checks.

## Contraction Paths and Execution

A contraction path is a list of integer pairs in the opt_einsum convention: at each step the tensors at positions i and j of the working list are contracted, both are removed, and the result is appended at the end. The order matters: pairwise contractions can differ in total work by orders of magnitude depending on which intermediates are formed, and finding the optimal order is NP-hard in general. The paclet exposes both an exact dynamic-programming planner (feasible up to about twenty tensors) and a fast greedy heuristic (the practical choice beyond that).

Build a five-tensor random network from a random graph for the following examples:

```wolfram
SeedRandom[42];
tn = BlockRandom[SeedRandom[42]; RandomTensorNetwork[RandomGraph[{5, 8}], 3]]
```

The greedy heuristic walks the network one pair at a time, scoring each candidate by the size of the resulting intermediate and committing to the cheapest:

```wolfram
GreedyContractionPath[tn]
```

`OptimalContractionPath` runs a dynamic-programming search over subsets of tensors and returns a provably optimal path for whichever cost functional `Method` selects. The default objective `"size"` minimizes the largest intermediate (a proxy for peak memory):

```wolfram
OptimalContractionPath[tn]
```

Selecting `Method -> "flops"` minimizes the total floating-point operation count. The two objectives generically disagree because the size-optimal path can accept wider intermediates to spread arithmetic across more pairs. The other accepted values are `"max"`, `"write"`, `"combo"`, and `"limit"`:

```wolfram
OptimalContractionPath[tn, Method -> "flops"]
```

The greedy planner accepts simulated-annealing noise (`"Temperature"`), a fixed random stream (`"RandomSeed"`), a beam-width cap (`"MaxNeighbors"`), and a peak-memory penalty (`"MemoryWeight"`):

```wolfram
GreedyContractionPath[tn, "MemoryWeight" -> 2.0, "Temperature" -> 0.5, "RandomSeed" -> 1]
```

### Inactive plans and execution engines

`TensorNetworkContraction` (note the trailing `tion`) returns a symbolic `Inactive`-tagged expression tree representing the planned contraction, with no array allocated and no arithmetic performed. `ActivateTensors` strips the inactive heads and evaluates. `TensorNetworkContract` is the shorthand: it activates the same plan in one call. The separation pays off when a contraction is large enough that inspecting cost, swapping engines per sub-tree, or evaluating symbolically against `ArraySymbol` placeholders matters more than the call site brevity.

Build a small numerical chain for the engine comparison:

```wolfram
SeedRandom[7];
mpsNum = TensorNetwork[
    {RandomReal[{-1, 1}, {2, 3}], RandomReal[{-1, 1}, {3, 3}], RandomReal[{-1, 1}, {3, 2}]},
    {{1, 2}, {2, 3}, {3, 4}}
]
```

Find a flops-optimal path:

```wolfram
path = OptimalContractionPath[mpsNum, Method -> "flops"]
```

Contract with the default `"ArrayDot"` engine, which calls `ArrayDot` after sorting the shared axes into contiguous position:

```wolfram
TensorNetworkContract[mpsNum, path, Method -> "ArrayDot"]
```

Repeat through the `"Dot"` engine via the inactive form. The `"Dot"` engine reshapes both operands to matrices and falls back to plain `Dot`:

```wolfram
ActivateTensors[TensorNetworkContraction[mpsNum, path, Method -> "Dot"]]
```

All five engines (`"ArrayDot"`, `"ArrayDotTranspose"`, `"Dot"`, `"TensorContract"`, `"TableSum"`) compute the same mathematical contraction. Differences between their outputs are bounded by floating-point noise from differing internal axis orderings. `"ArrayDot"` is fastest on dense numerical work; `"TensorContract"` produces the cleanest symbolic expression for pattern matching; `"TableSum"` is pedagogically transparent but quadratically slower; `"Dot"` is the entry point when an external matrix-multiplication routine has been overloaded.

A string passed in place of the path dispatches to the matching planner. `"Greedy"` runs the greedy heuristic:

```wolfram
TensorNetworkContract[mpsNum, "Greedy"]
```

`"flops"`, `"size"`, `"max"`, `"write"`, `"combo"`, `"limit"`, and `"Optimal"` all dispatch to `OptimalContractionPath` with that objective:

```wolfram
TensorNetworkContract[mpsNum, "flops"]
```

`ContractionTree`, `PathToTreePath`, `TreePathToPath`, and `PathIndexContractions` round out the path utilities; `PathQ`, `CanonicalPathQ`, and `TreePathQ` validate shape before a path reaches an engine.

## Matrix Product States

An MPS represents a quantum state on N sites as a contracted chain of site tensors: rank-2 at the two boundary sites (one bond, one physical leg) and rank-3 in the bulk (left bond, right bond, physical leg). The bond dimension D is the central dial. The Schmidt rank across any cut is bounded by D, and equivalently the von Neumann entanglement entropy across that cut is bounded by log D. For 1D gapped local Hamiltonians the ground state obeys an area law (in 1D, a boundary law: entanglement bounded by a constant independent of system size), so modest D suffices to represent the state to arbitrary precision. This is the structural reason MPS is the dominant variational ansatz for one-dimensional quantum systems.

An MPS also carries a gauge freedom: inserting `X . Inverse[X]` on any internal bond leaves the physical state unchanged while rewriting the two site tensors that meet on it. Canonical forms eliminate this redundancy by demanding that site tensors be isometric in a chosen direction, which both fixes the bookkeeping and makes the bond dimension coincide with the Schmidt rank at every cut.

Build a six-site qubit MPS with bond dimension four:

```wolfram
BlockRandom[SeedRandom[42]; mps = RandomTensorNetwork["MPS"[6, 4, 2]]]
```

`MPSCanonicalForm` accepts `"Left"`, `"Right"`, or `{"Mixed", k}`. The left form makes every site left-isometric (`A^† . A = I`, grouping the left bond and physical leg as rows), the right form is the mirror image, and the mixed form `{"Mixed", k}` puts the orthogonality center at site k. The center is where local operators act in DMRG-style algorithms:

```wolfram
canon = MPSCanonicalForm[mps, "Left"]
```

`MPSCanonicalQ` verifies the isometry condition site by site (default Frobenius tolerance `10^-10`):

```wolfram
MPSCanonicalQ[canon, "Left"]
```

`MPSOverlap` computes the inner product `<psi_1 | psi_2>` between two MPS by sweeping a transfer matrix from one boundary to the other. The second argument is conjugated, and the cost grows linearly in N and as `D^3` in the bond dimension. The dense state vector of `d^N` amplitudes is never materialized:

```wolfram
MPSOverlap[mps, mps]
```

`MPSNorm` is `Sqrt[Abs[MPSOverlap[mps, mps]]]`:

```wolfram
MPSNorm[mps]
```

`MPSNormalize` distributes the rescaling factor across every site, keeping each site's matrix elements small and the chain numerically well conditioned in long systems:

```wolfram
nmps = MPSNormalize[mps];
MPSNorm[nmps]
```

`MPSSchmidtValues[mps, k]` returns the Schmidt spectrum at the cut between sites k and k+1: build the mixed-canonical form centered at k, reshape the center tensor into the bipartition matrix, and read off the singular values. The number of nonzero values is the Schmidt rank, the physical invariant of the cut (at most D, often smaller):

```wolfram
MPSSchmidtValues[nmps, 3]
```

`MPSEntanglementEntropy` is the von Neumann entropy `S = -Sum[p_i log p_i]` of the same bipartition, with `p_i` the squared Schmidt values. It returns 0 for a product state and saturates at log D for a maximally entangled cut at bond dimension D:

```wolfram
MPSEntanglementEntropy[nmps, 3]
```

`MPSTruncate` compresses every bond down to a target dimension by a single left SVD sweep: at each bond an SVD is performed, the top D singular values are kept, and the remainder is absorbed into the next site. By the Eckart-Young theorem this is the optimal rank-D approximation in Frobenius norm on each bond. The accumulated truncation error is bounded by the sum of discarded squared singular values across all bonds. The result is left-canonical by construction:

```wolfram
truncated = MPSTruncate[nmps, 2]
```

The fidelity between the truncated state and the original is read off from their overlap:

```wolfram
Abs[MPSOverlap[truncated, nmps]]
```

## Einstein Summation

`EinsteinSummation` is sugar over `TensorContract`: it accepts a list of index labels per tensor (or the familiar einsum string) and returns an `Inactive[TensorContract]` expression that `ActivateTensors` reduces to a tensor. The contraction stays inspectable before evaluation, which is the point of the inactive form.

Set up two matrices for the next three examples:

```wolfram
A2 = RandomReal[1, {3, 4}];
B2 = RandomReal[1, {4, 5}];
```

Matrix multiplication via the rule form. The shared index k is summed:

```wolfram
ActivateTensors[EinsteinSummation[{{i, k}, {k, j}} -> {i, j}, {A2, B2}]]
```

The same contraction using the einsum string notation:

```wolfram
ActivateTensors[EinsteinSummation["ij,jk->ik", {A2, B2}]]
```

A matrix trace contracts both axes of a single tensor:

```wolfram
Mtr = RandomReal[1, {4, 4}];
ActivateTensors[EinsteinSummation[{{i, i}}, {Mtr}]]
```

`IndexedMultiply` is the companion primitive that joins tensors over shared indices and broadcasts along non-shared dimensions, returning the pair `{indices, tensor}`.

## Young Tableaux and Tensor Symmetries

The symmetric group `S_n` acts on a rank-n tensor by permuting its slots, and the resulting representation splits into a direct sum of irreducibles labelled by standard Young tableaux of size n. The subpackage `Wolfram`TensorNetworks`Symmetry`` exposes the combinatorial layer (tableaux, hook lengths, dimensions) together with the projectors that decompose a tensor into its irreducible pieces.

Load the subpackage:

```wolfram
Needs["Wolfram`TensorNetworks`Symmetry`"]
```

A standard Young tableau of size n labels an irreducible representation of `S_n`. Construct one from a partition (boxes auto-fill left to right, top to bottom):

```wolfram
yt = YoungTableau[{3, 2}]
```

Read the shape, total box count, and validity from the data structure:

```wolfram
{TableauShape[yt], TableauSize[yt], YoungTableauQ[yt]}
```

`HookLengths` returns the hook length at every cell, arranged in the tableau shape. The hook at cell `(i, j)` counts the cells strictly right of it in row i, the cells strictly below in column j, plus the cell itself:

```wolfram
HookLengths[{3, 2}]
```

The Frame and James hook-length formula gives the irrep dimension as `n!` divided by the product of the hook lengths: `5! / (4·3·1·2·1) = 5`:

```wolfram
TableauDimension[yt]
```

The Young symmetrizer associated with a tableau T is `c_T = a_T . b_T`, the product of the row symmetrizer and the column antisymmetrizer. It satisfies `c_T^2 = (n!/d_lambda) c_T`, so the *normalized* projector is `P_T = (d_lambda/n!) c_T`. `YoungProject` applies this normalized form, which is genuinely idempotent (`P_T^2 = P_T`). On a 2x2 tensor, the row-shape `{2}` projects onto the symmetric part:

```wolfram
T = {{a, b}, {c, d}};
YoungProject[T, YoungTableau[{2}]]
```

The column-shape `{1, 1}` projects onto the antisymmetric part:

```wolfram
YoungProject[T, YoungTableau[{1, 1}]]
```

Two applications of the mixed-symmetry projector `{2, 1}` on a random rank-3 tensor agree with one application to floating-point noise, confirming `P^2 = P` directly:

```wolfram
SeedRandom[42];
R = Round[10 RandomReal[1, {2, 2, 2}], 0.01];
yt21 = YoungTableau[{2, 1}];
Max[Abs[Flatten[YoungProject[YoungProject[R, yt21], yt21] - YoungProject[R, yt21]]]]
```

## Where to go next

The Documentation directory ships five tutorials and a reference page for every symbol. Open them from a Wolfram front end under `TensorNetworks/Documentation/English/`:

- `Tutorials/TensorNetworksOverview.nb`: the running example through every tier.
- `Tutorials/BuildingTensorNetworks.nb`: the constructor catalog and named-topology families.
- `Tutorials/ContractionPathsAndExecution.nb`: planners, objectives, engines, and the inactive form.
- `Tutorials/MPSAlgorithms.nb`: canonical forms, overlaps, Schmidt decomposition, truncation.
- `Tutorials/YoungSymmetries.nb`: tableaux, hook lengths, Young projectors.

Per-symbol reference pages are under `ReferencePages/Symbols/`.

## License

MIT.
