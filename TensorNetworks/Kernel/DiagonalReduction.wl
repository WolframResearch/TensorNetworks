Package["Wolfram`TensorNetworks`"]

PackageScope[diagonalReduction]


(* Diagonal reduction (cotengra's diagonal_reduce): legs a tensor is diagonal in share one label.
   diagonalReduction[tensors, labels, output] gives {tensors, labels}, or None if nothing reduces.
   Two output labels are never merged. *)

diagonalReduction[tensors_List, labels_List, output_List] := Module[{
    groups, distinct, labelIds, outputIds, classes, representative
},
    groups = MapThread[diagonalGroups, {tensors, labels}];
    If[ AllTrue[groups, # === {} &], Return[None]];

    (* label -> integer *)
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
    (* a class keeps its output label's name *)
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

(* Label classes: connected components of the labels each group joins *)
labelClasses[groups_, labelIds_] := ConnectedComponents @ Catenate @ MapThread[
    Function[{tensorGroups, tensorIds}, Catenate[UndirectedEdge @@@ Partition[tensorIds[[#]], 2, 1] & /@ tensorGroups]],
    {groups, labelIds}
]

(* When a class would join two output labels: accept groups one at a time (union-find),
   refusing those that would. Iterative find, since chains grow one gate at a time. *)
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

(* Groups of equal-dimension legs with identical columns of nonzero positions.
   Gathered by weighted column sums, then verified; regathered exactly on a collision. *)
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
    (* PositionIndex sorts packed keys: restore leg order *)
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

(* Sparse, or dense and at most half nonzero. Above 2^12 entries, probe one entry per leg
   (zero wherever a diagonal pair differs) before counting zeros. *)
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

(* all but the first leg of each group *)
keptLegs[rank_, groups_] := Complement[Range[rank], Catenate[Rest /@ groups]]

(* Diagonal along each group: sparse via positions, dense via Transpose with repeated levels *)
diagonalTensor[tensor_SparseArray, groups_, kept_] :=
    SparseArray[tensor["NonzeroPositions"][[All, kept]] -> tensor["NonzeroValues"], Dimensions[tensor][[kept]], tensor["Background"]]

diagonalTensor[tensor_, groups_, kept_] := With[{
    representative = Association @ Catenate[Thread[# -> First[#]] & /@ groups],
    position = First /@ PositionIndex[kept]
},
    Transpose[tensor, position[Lookup[representative, #, #]] & /@ Range[ArrayDepth[tensor]]]
]

diagonalReduction[___] := None
