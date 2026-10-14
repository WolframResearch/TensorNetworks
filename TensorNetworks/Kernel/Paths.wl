
Package["Wolfram`TensorNetworks`"]

PackageExport[TreePathQ]
PackageExport[PathQ]
PackageExport[CanonicalPathQ]
PackageExport[TreePathToPath]
PackageExport[PathToTreePath]
PackageExport[CanonicalPath]
PackageExport[PathIndexContractions]

PackageScope[treeSteps]



(* A tree path is a nonempty list: a singleton - a leaf, or a wrapper of one
   node, not looked into - or a node of tree paths.  It is checked a level at
   a time, not by recursion, which nests once per level: the tree of a path
   that absorbs one tensor at a time into a single product is as deep as the
   network has tensors, and 600 levels passed the recursion limit. *)
TreePathQ[tree_List] := Module[{level = {tree}},
	While[ Length[level] > 0 && AllTrue[level, ListQ[#] && Length[#] > 0 &],
		level = Catenate @ Select[level, Length[#] > 1 &]
	];
	Length[level] === 0
]

TreePathQ[___] := False

TreePathToPath::indlen =
	"Length of indices `1` does not match the tree path's leaf count `2`. " <>
	"Pass a list whose length matches the number of singleton leaves in the tree path, " <>
	"or omit the indices argument to auto-derive them.";

TreePathToPath[treePath_List ? TreePathQ, indices_List] :=
	With[{leafCount = Length[Cases[treePath, {_}, {0, Infinity}]]},
		If[Length[indices] =!= leafCount,
			Message[TreePathToPath::indlen, Length[indices], leafCount];
			$Failed,
			doTreePathToPath[treePath, indices]
		]
	]

TreePathToPath[treePath_List ? TreePathQ, Automatic : Automatic] :=
	doTreePathToPath[treePath, Sort[Cases[treePath, {x_} :> x, All]]]

TreePathToPath[treePath_List ? TreePathQ] :=
	doTreePathToPath[treePath, Sort[Cases[treePath, {x_} :> x, All]]]

(* A path step names its operands by their positions in the current operand
   list, from which each step removes its operands and to whose end it appends
   its result.  An operand's position is therefore the number of live operands
   created no later than it - the leaves first, in the order of indices, then
   each step's result in turn - which a Fenwick tree over that creation order
   answers in logarithmic time.  Renumbering every remaining position after each
   step instead made canonicalizing quadratic: 1.6 s for a path over 2000
   tensors, against 0.011 s.  Steps are taken in post-order, as before, and the
   path is the same one, step for step. *)

doTreePathToPath[treePath_, indices_] := With[{
	steps = treeSteps[treePath, AssociationThread[List /@ indices, Range[Length[indices]]]]
},
	Which[
		steps === $Failed,
			$Failed,
		steps === {},
			{},
		True,
			TakeList[stepPositions[Length /@ steps, Catenate[steps], Length[indices]], Length /@ steps]
	]
]

(* The steps of a tree path in post-order, each the slots of its operands: a
   leaf's slot is the one slotOf gives it - slotOf is keyed by the singleton
   {v} - and each step's the next after the leaves and the steps before it.  A
   singleton that is no leaf wraps one node, and is a step of one operand.
   $Failed if a node is no nonempty list.

   The tree is walked with stacks of its own, not by recursion, which nests
   once per level of the tree: one that absorbs one tensor at a time into a
   single product - the sweep TensorNetworkContraction can choose, or the
   greedy path over an index that hundreds of tensors share - is as deep as
   the network has tensors, and 600 passed the recursion limit.  Popping a
   node and pushing its operands meets the nodes in post-order reversed: a
   leaf as its slot, a node as minus its operand count.  Read forwards, that
   order is evaluated on a stack of slots, each node taking its operands from
   the top (stepOperands).  The node stack is a linked list, {node, rest}: a
   list of nodes assigned in place is scanned whole when next read, which made
   the walk of 10^4 nodes take 0.32 s instead of 0.02 s. *)
treeSteps[tree_, slotOf_Association] := Module[{stack = {tree, {}}, node, order, malformed = False},
	order = First[Reap[
		While[ Length[stack] > 0 && ! malformed,
			{node, stack} = stack;
			Which[
				! ListQ[node] || Length[node] === 0,
					malformed = True,
				Length[node] === 1 && KeyExistsQ[slotOf, node],
					Sow[slotOf[node]],
				True,
					Sow[-Length[node]];
					Scan[(stack = {#, stack}) &, node]
			]
		]
	][[2]], {}];
	If[ malformed,
		$Failed,
		With[{forward = Reverse[order]},
			TakeList[stepOperands[forward, Length[slotOf]], -Select[forward, Negative]]
		]
	]
]

(* The operands of every step, one list: the order read forwards on a stack
   of slots. *)
stepOperands = Compile[{{order, _Integer, 1}, {leafCount, _Integer}},
	Module[{slots = Table[0, {Length[order]}], operands = Table[0, {Length[order]}], depth = 0, k = 0, next = leafCount},
		Do[
			If[ s > 0,
				depth++;
				slots[[depth]] = s,
				Do[k++; operands[[k]] = slots[[depth + s + i]], {i, -s}];
				depth += s + 1;
				next++;
				slots[[depth]] = next
			],
			{s, order}
		];
		Take[operands, k]
	]
]

stepPositions = Compile[{{arity, _Integer, 1}, {slots, _Integer, 1}, {leafCount, _Integer}},
	Module[{size = leafCount + Length[arity], live, j = 0, count = 0, positions, k = 0, next = leafCount},
		live = Table[0, {size}];
		Do[j = leaf; While[j <= size, live[[j]] += 1; j += BitAnd[j, -j]], {leaf, leafCount}];
		positions = Table[0, {Length[slots]}];
		Do[
			Do[
				k++; j = slots[[k]]; count = 0;
				While[j > 0, count += live[[j]]; j -= BitAnd[j, -j]];
				positions[[k]] = count,
				{arity[[step]]}
			];
			Do[j = slots[[m]]; While[j <= size, live[[j]] -= 1; j += BitAnd[j, -j]], {m, k - arity[[step]] + 1, k}];
			next++; j = next; While[j <= size, live[[j]] += 1; j += BitAnd[j, -j]],
			{step, Length[arity]}
		];
		positions
	]
]

PathQ[{}] := True
PathQ[{({_Integer} | {_Integer, _Integer}) ..}] := True
PathQ[___] := False

PathToTreePath::indlen =
	"Length of indices `1` does not match the path's required arity `2` " <>
	"(= Count[path, {_, _}] + 1). A path of a TN is over its own tensors, hyper-edges " <>
	"included; a path planned over BinaryTensorNetwork[tn] is over the binarized " <>
	"network — pass BinaryTensorNetwork[tn][\"Vertices\"] for one, or omit the " <>
	"indices argument to auto-derive them.";

PathToTreePath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	With[{required = Count[path, {_, _}] + 1},
		Which[
			indices === Automatic,
				doPathToTreePath[path, Range[required]],
			Length[indices] =!= required,
				Message[PathToTreePath::indlen, Length[indices], required];
				$Failed,
			True,
				doPathToTreePath[path, indices]
		]
	]

doPathToTreePath[path_, indices_] :=
	First @ Fold[
		{idx, pos} |-> Append[
			Delete[idx, List /@ pos],
			If[Length[pos] == 1, idx[[pos[[1]]]], idx[[pos]]]
		],
		List /@ indices,
		path
	]


CanonicalPath[{}, ___] := {}
CanonicalPath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	TreePathToPath[PathToTreePath[path, indices], indices]

CanonicalPathQ[{}] := True
CanonicalPathQ[{({_Integer, _Integer}) ..}] := True
CanonicalPathQ[___] := False

ContractIndices[i_, j_] := With[{c = Complement[Join[i, j], SymmetricDifference[i, j]]},
	c -> {DeleteElements[DeleteDuplicates[i], c], DeleteElements[DeleteDuplicates[j], c]}
]

PathIndexContractions::indlen =
	"Length of indices `1` does not match the path's required arity `2` " <>
	"(= Length[path] + 1). A path of a TN is over its own tensors, hyper-edges " <>
	"included; for a path planned over BinaryTensorNetwork[tn] pass that network's " <>
	"[\"Indices\"] / [\"Hyperedges\"], or use Automatic.";

PathIndexContractions[path : {{_Integer, _Integer} ...}, indices : {__List}] :=
	With[{required = Length[path] + 1},
		If[Length[indices] =!= required,
			Message[PathIndexContractions::indlen, Length[indices], required];
			$Failed,
			DeleteCases[{}] @ FoldPairList[
				With[{c = ContractIndices @@ #1[[#2]]}, {c[[1]], Append[Delete[#1, List /@ #2], Catenate[c[[2]]]]}] &,
				indices,
				path
			]
		]
	]

PathIndexContractions[path_List, indices : {__List}, contractions : {__List}] :=
	With[{index = First /@ PositionIndex[Catenate[indices]]},
		Map[Lookup[index, #] &, PathIndexContractions[path, contractions], {3}]
	]

PathIndexContractions[path_List, KeyValuePattern[{"Indices" -> indices_, "Contractions" -> contractions_}]] :=
	Catenate @ PathIndexContractions[path, indices, contractions]
