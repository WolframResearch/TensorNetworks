Package["Wolfram`TensorNetworks`"]

PackageScope[diagonalReduction]


(* Diagonal reduction, as cotengra's diagonal_reduce: a tensor whose entries
   vanish wherever two of its indices differ is the diagonal along those two
   times a delta tying them, and the delta can be contracted away for free by
   giving both indices one label.  The tensor loses a leg, and the label it
   keeps becomes shared by every tensor that held either: a diagonal gate on
   k wires, a tensor of 4^k entries on 2k legs, becomes 2^k entries on the k
   wire labels its neighbours carry.

   diagonalReduction[tensors, labels, output] gives {tensors, labels} with
   every such pair merged, or None when there is none.  Pairs are found from a
   tensor's nonzero positions, so only explicit arrays that are at most half
   full are inspected: a pair of dimension d >= 2 leaves at most 1/d of the
   entries nonzero.  Two labels both in the output cannot become one, so a
   merge that would join them is refused; when a merged class holds an output
   label, that label names it, and the output is unchanged. *)

diagonalReduction[tensors_List, labels_List, output_List] := Module[{
    groups, distinct, labelIds, outputIds, classes, representative
},
    groups = MapThread[diagonalGroups, {tensors, labels}];
    If[ AllTrue[groups, # === {} &], Return[None]];

    (* labels as integers, the positions of their first appearance *)
    distinct = DeleteDuplicates[Catenate[labels]];
    With[{ids = AssociationThread[distinct, Range[Length[distinct]]]},
        labelIds = Lookup[ids, #] & /@ labels;
        outputIds = Lookup[ids, output, Nothing]
    ];
    classes = labelClasses[groups, labelIds];
    If[ AnyTrue[classes, Length[Intersection[#, outputIds]] > 1 &],
        groups = acceptInTurn[groups, labelIds, outputIds, Length[distinct]];
        If[ AllTrue[groups, # === {} &], Return[None]];
        classes = labelClasses[groups, labelIds]
    ];
    (* a class is named by its output label, or by any of its labels *)
    representative = Range[Length[distinct]];
    Scan[(representative[[#]] = First[Join[Intersection[#, outputIds], #]]) &, classes];

    Transpose @ MapThread[
        Function[{tensor, tensorIds, tensorGroups},
            With[{kept = keptLegs[Length[tensorIds], tensorGroups]},
                {
                    If[tensorGroups === {}, tensor, diagonalTensor[tensor, tensorGroups, kept]],
                    distinct[[representative[[tensorIds[[kept]]]]]]
                }
            ]
        ],
        {tensors, labelIds, groups}
    ]
]

(* The classes of labels the groups make one: the connected components of
   the graph joining the labels of each group. *)
labelClasses[groups_, labelIds_] := ConnectedComponents @ Catenate @ MapThread[
    Function[{tensorGroups, tensorIds}, Catenate[UndirectedEdge @@@ Partition[tensorIds[[#]], 2, 1] & /@ tensorGroups]],
    {groups, labelIds}
]

(* Where a class would hold two output labels, the groups are accepted in
   turn instead, each unless it would join two classes that hold one each: a
   wire of diagonal gates with both ends in the output keeps its last gate
   whole.  A union-find over the label integers, a root holding an output
   label when its class does.  Its find walks iteratively: a gate lists its
   new wire label before the one it continues, so each gate on a wire can
   put the class under a new root, and a recursive walk would nest once per
   gate. *)
acceptInTurn[groups_, labelIds_, outputIds_, n_] := Module[{parent = Range[n], held = ConstantArray[False, n], find},
    held[[outputIds]] = True;
    find[x_] := Module[{root = x, y = x, next},
        While[parent[[root]] =!= root, root = parent[[root]]];
        While[y =!= root, next = parent[[y]]; parent[[y]] = root; y = next];
        root
    ];
    MapThread[
        Function[{tensorGroups, tensorIds},
            Select[tensorGroups, Function[group,
                With[{roots = DeleteDuplicates[find /@ tensorIds[[group]]]},
                    With[{outs = Select[roots, held[[#]] &]},
                        Length[outs] <= 1 && (parent[[roots]] = First[Join[outs, roots]]; True)
                    ]
                ]
            ]]
        ],
        {groups, labelIds}
    ]
]

(* The groups of legs a tensor is diagonal in: legs of one dimension, above
   one, whose coordinates agree at every nonzero entry - whose columns of
   nonzero positions are the same.  The columns are gathered, not compared
   pair by pair - a 20-leg tensor has 190 pairs - and by their sums weighted
   by row, which equal columns share; the legs a sum gathers are then checked
   against the first of their group, all in one array difference, and only
   if a check fails - unequal columns whose sums agree - are their columns
   gathered themselves.  Hashing every column took 60 of the 90 microseconds
   an 18-leg gate did.  A tensor with a nonzero background, more than half
   full or with no nonzero entry at all is left alone. *)
diagonalGroups[tensor_, tensorLabels_] /; Length[tensorLabels] >= 2 && reducibleArrayQ[tensor] := Module[{
    sparse = If[MatchQ[tensor, _SparseArray], tensor, SparseArray[tensor]],
    dims = Dimensions[tensor], positions, legs, candidates
},
    If[ ! TrueQ[sparse["Background"] == 0] || sparse["Density"] > 1/2 || sparse["NonzeroPositions"] === {}, Return[{}]];
    positions = sparse["NonzeroPositions"];
    legs = Pick[Range[Length[dims]], UnitStep[dims - 2], 1];
    candidates = legs[[#]] & /@ Select[
        Values @ PositionIndex[Transpose[{dims[[legs]], (Range[Length[positions]] . positions)[[legs]]}]],
        Length[#] >= 2 &
    ];
    (* PositionIndex orders a packed array's keys, so the groups are sorted
       back into the order of their first legs *)
    SortBy[
        If[ candidates === {} || sameColumnsQ[positions, candidates],
            candidates,
            Select[Catenate[GatherBy[#, positions[[All, #]] &] & /@ candidates], Length[#] >= 2 &]
        ],
        First
    ]
]

sameColumnsQ[positions_, groups_] :=
    positions[[All, Catenate[ConstantArray[First[#], Length[#] - 1] & /@ groups]]] === positions[[All, Catenate[Rest /@ groups]]]

diagonalGroups[___] := {}

(* An explicit array, which a dense one is only if it might be half empty:
   counting its zeros costs a pass over it, and a dense array with none is the
   common case that should cost nothing more.  So the pass over an array of
   more than 2^12 entries is made only when some leg could be diagonal with an
   earlier one of its dimension: the two differ where it reads 2 and every
   other leg 1, and a diagonal pair is zero there.  A dense array of random
   numbers fails that for one entry a leg - the pass over the 80 tensors of an
   MPS overlap of bond dimension 96 took 10 ms of a 100 ms contraction.  Below
   2^12 entries the pass is the cheaper of the two. *)
reducibleArrayQ[tensor_SparseArray] := True

reducibleArrayQ[tensor_List] := ArrayQ[tensor] && With[{dims = Dimensions[tensor]},
    (
        Times @@ dims <= 2^12 ||
        AnyTrue[
            Select[Range[2, Length[dims]], dims[[#]] > 1 && MemberQ[Take[dims, # - 1], dims[[#]]] &],
            TrueQ[Extract[tensor, ReplacePart[ConstantArray[1, Length[dims]], # -> 2]] == 0] &
        ]
    ) && 2 Total[Unitize[tensor], Infinity] <= Times @@ dims
]

reducibleArrayQ[_] := False

(* Every leg but the second and later of a group. *)
keptLegs[rank_, groups_] := Complement[Range[rank], Catenate[Rest /@ groups]]

(* The diagonal along each group: a leg of a group is read at the position of
   the group's first leg.  A SparseArray keeps its nonzero entries, exact or
   not; a dense array goes through Transpose with repeated levels, which takes
   the same diagonal. *)
diagonalTensor[tensor_SparseArray, groups_, kept_] :=
    SparseArray[tensor["NonzeroPositions"][[All, kept]] -> tensor["NonzeroValues"], Dimensions[tensor][[kept]], tensor["Background"]]

diagonalTensor[tensor_, groups_, kept_] := With[{
    representative = Association @ Catenate[Thread[# -> First[#]] & /@ groups],
    position = First /@ PositionIndex[kept]
},
    Transpose[tensor, position[Lookup[representative, #, #]] & /@ Range[ArrayDepth[tensor]]]
]

diagonalReduction[___] := None
