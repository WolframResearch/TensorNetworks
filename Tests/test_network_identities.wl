(* Tests/test_network_identities.wl

   Tensor-network results checked against quantities computed without the
   code under test: explicit index sums, matrix products and traces, the
   singular values of the full state vector, counts of index assignments,
   and an exhaustive search over contraction orders.

   A.  Contraction values: exact symbolic identities for every engine and
       for hyperedges (one index on three tensors) with and without a
       contraction path; numeric checks for scalar tensors, reordered
       outputs, mixed bond dimensions, rings, added tensors (also on a
       network with no open index), renamed indices, and tensors that carry
       a traced index pair.
   B.  Network structure: bond dimensions, and the wiring of the random
       networks: tree and MERA by contracting all-ones tensors, which counts
       the joint index assignments; PEPS by counting labels shared by two
       tensors; with one fixed bond dimension, the bonds of a random network
       on a graph follow the graph's edges.
   C.  Contraction paths: the optimal path costs the exhaustive minimum over
       all contraction orders, on a tensor with a traced index pair and on
       random connected networks; the Boolean search options leave the
       optimum and the contracted value unchanged.
   D.  Matrix product states: Schmidt values and entanglement entropy on
       every cut of a complex state equal those of the full state vector;
       left- and right-canonical tensors are isometries; truncating a
       canonical state reaches the Eckart-Young fidelity on one cut and
       stays within the summed discarded weight on many; exact Schmidt
       spectra of the W and GHZ states for any number of sites, and the
       large-n entropy of the W state; the zero state stays zero.
   E.  Dimensions: contraction-tree roots, symbolic ArrayDot and symbolic
       slices carry the dimensions of the numeric result.
   F.  Renaming indices of a network graph: the renamed labels appear on
       the vertices and on both ends of every edge; a renaming changes
       labels, not tensors, so the renamed graph must contract to the same value as the
       original, computed here as an explicit matrix product, trace, or sum
       over a shared index of symbolic arrays (exact polynomial identities).
       Covers a chain, a ring (every bond renamed on both ends), a
       hyperedge through a spider vertex, and renaming only free indices.

   Regimes covered:
     General symbolic       A1-A3: contraction of symbolic matrices and a
                            symbolic hyperedge, as exact polynomial identities.
     Exactly solvable       D7-D8: W and GHZ Schmidt spectra and entropies
                            in closed form for 3 to 8 sites; B3-B5: tree,
                            MERA and grid layouts; D6: a product state.
     Asymptotic             D9: W-state entropy for 16 to 128 sites
                            converging to its large-n expansion in 1/n.
     Limiting               D4-D5: truncation error vanishes as the bond
                            dimension reaches the Schmidt rank.
     Independent reference  D1-D2: SVD of the full state; C1-C2: exhaustive
                            search over contraction orders.
     Edge                   A4: scalar tensors; A7: a network of one tensor;
                            D10: the zero state; E2: a rank-0 result.

   Known defects kept out of this file (each would fail today):
   MPSCanonicalForm with "MaxBond" and MPSTruncate applied to a state that
   is not already canonical fall short of the Eckart-Young fidelity.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`IndexArray`"];


(* ============================================ *)
(* Independent references                       *)
(* ============================================ *)

(* Agreement to 10^-10 relative to the size of the reference. *)
numericSameQ[x_, y_] := Norm[Flatten[{x - y}]] <= 10^-10 Max[1, Norm[Flatten[{y}]]]

zeroPolynomialQ[x_] := Union[Flatten[{Expand[x]}]] === {0}

(* Contract a network by one TensorContract of the full tensor product:
   every label shared by two tensors is summed, the remaining labels are
   ordered as in out. *)
directContraction[tensors_List, hyperedges_List, out_List] :=
    With[{labels = Catenate[hyperedges]},
        With[
            {
                pairs = Values @ Select[PositionIndex[labels], Length[#] == 2 &],
                free = Select[labels, Count[labels, #] == 1 &]
            },
            With[{t = TensorContract[TensorProduct @@ tensors, pairs]},
                If[free === {}, t, Transpose[t, Flatten[Position[out, #] & /@ free]]]
            ]
        ]
    ]

(* Symbolic matrix chain x.y.z with open ends. *)
{symbolicX, symbolicY, symbolicZ} = {Array[x, {2, 3}], Array[y, {3, 4}], Array[z, {4, 2}]};
symbolicChain = TensorNetwork[{symbolicX, symbolicY, symbolicZ}, {{1, 2}, {2, 3}, {3, 4}}];

(* Three symbolic 2 x 3 matrices sharing their first index: a hyperedge,
   with value Sum_s p[s,i] q[s,j] r[s,k]. *)
{hyperP, hyperQ, hyperR} = {Array[p, {2, 3}], Array[q, {2, 3}], Array[r, {2, 3}]};
hyperedgeNetwork = TensorNetwork[{hyperP, hyperQ, hyperR}, {{"s", "a"}, {"s", "b"}, {"s", "c"}}];
hyperedgeSum = Table[Sum[hyperP[[s, i]] hyperQ[[s, j]] hyperR[[s, k]], {s, 2}], {i, 3}, {j, 3}, {k, 3}];

(* Replace every tensor by all ones: the contraction then counts, for each
   assignment of the free indices, the assignments of the summed ones. *)
onesContraction[tn_] :=
    TensorNetworkContract[TensorNetwork[ConstantArray[1, Dimensions[#]] & /@ tn["Tensors"], tn["Hyperedges"]]]

labelMultiplicities[tn_] := Counts[Catenate[tn["Hyperedges"]]]

(* Pairs of tensors joined by a bond, as positions in the tensor list. *)
bondedPairs[tn_] :=
    With[{h = tn["Hyperedges"]},
        Sort @ Select[
            Flatten[Position[h, l_List /; MemberQ[l, #], {1}, Heads -> False]] & /@ Union @@ h,
            Length[#] == 2 &
        ]
    ]

(* Open matrix product state on n sites: bonds 1..n-1, physical legs n+1..2n. *)
mpsHyperedges[n_] := Join[{{1, n + 1}}, Table[{i - 1, i, n + i}, {i, 2, n - 1}], {{n - 1, 2 n}}]

complexMPS[n_, bond_, seed_] :=
    BlockRandom[
        SeedRandom[seed];
        TensorNetwork[
            Join[
                {RandomComplex[{-1 - I, 1 + I}, {bond, 2}]},
                Table[RandomComplex[{-1 - I, 1 + I}, {bond, bond, 2}], n - 2],
                {RandomComplex[{-1 - I, 1 + I}, {bond, 2}]}
            ],
            mpsHyperedges[n]
        ]
    ]

stateVector[tn_, n_] := Flatten[directContraction[tn["Tensors"], tn["Hyperedges"], Range[n + 1, 2 n]]]

(* Random complex 6-site state with bond dimension 3, and its state vector. *)
mpsSix = complexMPS[6, 3, 7];
psiSix = stateVector[mpsSix, 6];

(* Schmidt coefficients (singular values) of the normalized state across
   the cut after site k. *)
cutSpectrum[psi_, n_, k_] := SingularValueList[ArrayReshape[Normalize[psi], {2^k, 2^(n - k)}]]

fidelity[psi_, phi_] := Abs[Conjugate[psi] . phi]^2 / (Norm[psi]^2 Norm[phi]^2)

(* Left isometry: summing a site tensor with its conjugate over the left
   bond and the physical leg gives the identity on the right bond. Right
   isometry: summing over the right bond and the physical leg gives the
   identity on the left bond. Site tensors are ordered (left, right,
   physical); the end tensors are (bond, physical). *)
leftGram[t_ /; ArrayDepth[t] == 2] := t . ConjugateTranspose[t]
leftGram[t_ /; ArrayDepth[t] == 3] :=
    With[{m = ArrayReshape[Transpose[t, {2, 1, 3}], {Dimensions[t][[2]], Dimensions[t][[1]] Dimensions[t][[3]]}]},
        m . ConjugateTranspose[m]
    ]

rightGram[t_ /; ArrayDepth[t] == 2] := t . ConjugateTranspose[t]
rightGram[t_ /; ArrayDepth[t] == 3] :=
    With[{m = ArrayReshape[t, {Dimensions[t][[1]], Dimensions[t][[2]] Dimensions[t][[3]]}]},
        m . ConjugateTranspose[m]
    ]

isometryQ[gram_] := numericSameQ[gram, IdentityMatrix[Length[gram]]]

(* W state as a bond-2 MPS: bond value 1 means no excitation placed yet,
   2 means placed. GHZ state: every index equal. Both unnormalized. *)
wFirst = {{1, 0}, {0, 1}};
wMiddle = Transpose[{IdentityMatrix[2], {{0, 1}, {0, 0}}}, {3, 1, 2}];
wLast = {{0, 1}, {1, 0}};
wState[n_] := TensorNetwork[Join[{wFirst}, ConstantArray[wMiddle, n - 2], {wLast}], mpsHyperedges[n]]

ghzState[n_] :=
    TensorNetwork[
        Join[{IdentityMatrix[2]}, ConstantArray[Table[Boole[l == r == s], {l, 2}, {r, 2}, {s, 2}], n - 2], {IdentityMatrix[2]}],
        mpsHyperedges[n]
    ]

binaryEntropy[p_] := -p Log[p] - (1 - p) Log[1 - p]

(* Cost of a contraction path in the opt_einsum convention, counting only
   pairwise steps: contracting tensors with label sets s and t costs the
   product of the dimensions of their union, and keeps the labels still
   needed by the output or another tensor. A one-tensor step sums a
   repeated label and costs nothing here. *)
keptLabels[labels_, others_List, out_] := Select[DeleteDuplicates[labels], MemberQ[Join[out, Catenate[others]], #] &]

pathStep[{sets_, cost_}, step_List, out_, dims_] :=
    With[{rest = Delete[sets, List /@ step], joint = Union @@ sets[[step]]},
        {
            Append[rest, keptLabels[Catenate[sets[[step]]], rest, out]],
            cost + If[Length[step] == 2, Times @@ Lookup[dims, joint], 0]
        }
    ]

pathCost[sets_, path_, out_, dims_] := Last @ Fold[pathStep[#1, #2, out, dims] &, {sets, 0}, path]

(* Minimum pairwise cost over every contraction order that only contracts
   tensors sharing a label (no outer products, the search space of the
   optimal path finder by default), by exhaustive search. *)
minimumPairwiseCost[{_}, _, _] := 0
minimumPairwiseCost[sets_List, out_, dims_] :=
    Min[
        Function[step,
            With[{next = pathStep[{sets, 0}, step, out, dims]},
                Last[next] + minimumPairwiseCost[First[next], out, dims]
            ]
        ] /@ Select[Subsets[Range[Length[sets]], {2}], IntersectingQ @@ sets[[#]] &]
    ]

(* Label lists of a network on n tensors with the given edges (one label
   per edge, numbered by position) plus an open label on the first and
   last tensor. *)
networkLabels[edges_List, n_Integer] :=
    With[{m = Length[edges]},
        Table[
            Join[
                Flatten[Position[edges, {t, _} | {_, t}, {1}, Heads -> False]],
                If[t == 1, {m + 1}, {}],
                If[t == n, {m + 2}, {}]
            ],
            {t, n}
        ]
    ]

(* A path in single-assignment form names the n inputs 1..n and the result
   of step k n + k. The same path in the opt_einsum convention names
   positions in the current list of tensors, where each step removes its
   operands and appends its result. *)
ssaToLinearPath[path_, n_] :=
    First @ Fold[
        Function[{state, step},
            With[{positions = Flatten[Position[state[[2]], #] & /@ step]},
                {Append[state[[1]], positions], Append[Delete[state[[2]], List /@ positions], state[[3]]], state[[3]] + 1}
            ]
        ],
        {{}, Range[n], n + 1},
        path
    ]

(* Five tensors on a ring with one chord and one open leg 7; every other
   label is shared by exactly two tensors. *)
ringSets = {{1, 2}, {2, 3, 4}, {3, 5}, {4, 5, 6}, {6, 1, 7}};
ringOutput = {7};
ringDimensions = BlockRandom[SeedRandom[21]; AssociationThread[Range[7], RandomInteger[{2, 6}, 7]]];
ringTensors = BlockRandom[SeedRandom[22]; RandomReal[{-1, 1}, Lookup[ringDimensions, #]] & /@ ringSets];
ringNetwork = TensorNetwork[ringTensors, ringSets];


(* ============================================ *)
(* A. Contraction values                        *)
(* ============================================ *)

(* A1. For symbolic matrices the chain contracts to the polynomial matrix
   x.y.z exactly, for every engine. *)
VerificationTest[
    zeroPolynomialQ[TensorNetworkContract[symbolicChain, {{1, 2}, {1, 2}}, Method -> #] - symbolicX . symbolicY . symbolicZ] & /@ $TensorNetworkContractionMethods,
    ConstantArray[True, Length[$TensorNetworkContractionMethods]],
    TestID -> "A1.symbolic_chain_every_engine"
]

(* A2. Contracting without naming a path, with Automatic, and through the
   deferred form with activation give the same polynomial matrix. *)
VerificationTest[
    zeroPolynomialQ[# - symbolicX . symbolicY . symbolicZ] & /@ {
        TensorNetworkContract[symbolicChain],
        TensorNetworkContract[symbolicChain, Automatic],
        TensorNetworkContraction[symbolicChain, "Inactive" -> False]
    },
    {True, True, True},
    TestID -> "A2.symbolic_chain_default_path"
]

(* A3. The symbolic hyperedge network contracted along greedy, optimal and
   explicit paths, and the activated deferred form, equal
   Sum_s p[s,i] q[s,j] r[s,k] exactly. *)
VerificationTest[
    Append[
        zeroPolynomialQ[TensorNetworkContract[hyperedgeNetwork, #] - hyperedgeSum] & /@ {"Greedy", "Optimal", GreedyContractionPath[hyperedgeNetwork]},
        zeroPolynomialQ[ActivateTensors[TensorNetworkContraction[hyperedgeNetwork, GreedyContractionPath[hyperedgeNetwork]]] - hyperedgeSum]
    ],
    {True, True, True, True},
    TestID -> "A3.symbolic_hyperedge_equals_index_sum"
]

(* A4. A scalar tensor multiplies the rest of the network: {3, v, v}
   contracts to 3 v.v with and without a path. *)
VerificationTest[
    With[{tn = TensorNetwork[{3., {1., 2.}, {1., 2.}}, {{}, {1}, {1}}]},
        {TensorNetworkContract[tn], TensorNetworkContract[tn, {{1, 2}, {1, 2}}]}
    ],
    {15., 15.},
    SameTest -> numericSameQ,
    TestID -> "A4.scalar_tensor_scales_network"
]

(* A5. With every tensor stored sparse, the network {2, v} contracts to 2 v. *)
VerificationTest[
    Normal @ TensorNetworkContract[SparseTensorNetwork[TensorNetwork[{2., {1., 2.}}, {{}, {"i"}}]]],
    {2., 4.},
    SameTest -> numericSameQ,
    TestID -> "A5.sparse_scalar_tensor_scales_vector"
]

(* A6. Index 2 is shared by three tensors and the free indices are
   reordered by Cycles[{{1, 3}}]; the path contraction equals the
   transposed triple sum. *)
VerificationTest[
    BlockRandom[SeedRandom[1];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], d = RandomReal[1, {5, 3}]},
            {
                TensorNetworkContract[TensorNetwork[{a, b, d}, {{1, 2}, {2, 3}, {4, 2}}, Cycles[{{1, 3}}]], {{1, 2}, {1, 2}, {1, 2}}],
                Transpose[Table[Sum[a[[i, j]] b[[j, k]] d[[l, j]], {j, 3}], {i, 2}, {k, 4}, {l, 5}], Cycles[{{1, 3}}]]
            }
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A6.hyperedge_permuted_output_equals_transposed_sum"
]

(* A7. A network of one tensor is that tensor, whatever path search runs. *)
VerificationTest[
    With[{m = {{1., 2., 3.}, {4., 5., 6.}}},
        TensorNetworkContract[TensorNetwork[{m}, {{1, 2}}], #] & /@ {"Optimal", "Greedy"}
    ],
    {{{1., 2., 3.}, {4., 5., 6.}}, {{1., 2., 3.}, {4., 5., 6.}}},
    TestID -> "A7.single_tensor_network_is_the_tensor"
]

(* A8. A triangle with three different bond dimensions, contracted along
   its optimal path, equals Tr[a.b.c]. *)
VerificationTest[
    BlockRandom[SeedRandom[1];
        With[{ts = RandomReal[{-1, 1}, #] & /@ {{2, 3}, {3, 4}, {4, 2}}},
            With[{tn = TensorNetwork[ts, {{"i", "j"}, {"j", "k"}, {"k", "i"}}]},
                {TensorNetworkContract[tn, OptimalContractionPath[tn]], Tr[Dot @@ ts]}
            ]
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A8.triangle_mixed_bonds_equals_trace"
]

(* A9. A directed 3-cycle of matrices is closed with cup and cap matrices
   into a valid network whose value is a cyclic trace. The two
   orientations give the two distinct cyclic traces: 1 -> 2 -> 3 -> 1
   gives Tr[c.b.a] and the reversed ring gives Tr[a.b.c], because
   reversing every edge transposes every matrix. *)
VerificationTest[
    BlockRandom[SeedRandom[3];
        With[{mats = RandomReal[{-1, 1}, {3, 3, 3}]},
            With[{ring = TensorNetworkContract[ToTensorNetworkGraph[Graph[#, AnnotationRules -> MapThread[#1 -> {"Tensor" -> #2} &, {{1, 2, 3}, mats}]]]] &},
                {
                    {ring[{1 -> 2, 2 -> 3, 3 -> 1}], ring[{2 -> 1, 3 -> 2, 1 -> 3}]},
                    {Tr[Dot @@ Reverse[mats]], Tr[Dot @@ mats]}
                }
            ]
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A9.ring_orientations_give_the_two_cyclic_traces"
]

(* A10. Adding T on labels {3, 6} to the chain a.b with explicit output
   {3, 1} sums label 3: the network becomes a.b.T. *)
VerificationTest[
    BlockRandom[SeedRandom[2];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], t = RandomReal[1, {4, 7}]},
            {TensorNetworkContract[TensorNetworkAdd[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}, Cycles[{{1, 2}}]], t, {3, 6}], {{1, 2}, {1, 2}}], a . b . t}
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A10.added_tensor_contracts_open_index"
]

(* A11. The deprecated path finder with Method -> "Greedy" returns the
   greedy path, and contracting along it gives x.y.z. *)
VerificationTest[
    With[{path = TensorNetworkFindContractionPath[symbolicChain, Method -> "Greedy"]},
        {path === GreedyContractionPath[symbolicChain], zeroPolynomialQ[TensorNetworkContract[symbolicChain, path] - symbolicX . symbolicY . symbolicZ]}
    ],
    {True, True},
    {General::deprec},
    TestID -> "A11.deprecated_greedy_finder_equals_greedy_path"
]

(* A12. Renaming indices of the graph form relabels the network without
   changing it: renaming the open index of a, or both ends of the bond
   between a and b, still contracts to a.b. *)
VerificationTest[
    BlockRandom[SeedRandom[8];
        With[{a = RandomReal[{-1, 1}, {2, 3}], b = RandomReal[{-1, 1}, {3, 4}]},
            With[{g = ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]]},
                numericSameQ[TensorNetworkContract[TensorNetworkReplaceIndices[g, #]], a . b] & /@ {
                    {Superscript[1, 1] -> Superscript[1, 5]},
                    {Superscript[1, 2] -> Superscript[1, 7], Subscript[2, 1] -> Subscript[2, 7]}
                }
            ]
        ]
    ],
    {True, True},
    TestID -> "A12.renamed_indices_keep_matrix_product"
]

(* A13. Label 1 occurs twice on one tensor, so that tensor is traced over
   those two slots before its remaining slots meet the rest of the
   network. Contracting along an explicit path with every engine, along a
   searched path, or through the deferred form with activation equals the
   trace followed by the product: Sum_{x,y} A[x,x,y] v[y], and for C on
   labels {1, 2, 1} next to D on {2, 3}, Sum_{x,y} C[x,y,x] D[y,k]. *)
VerificationTest[
    BlockRandom[SeedRandom[9];
        With[
            {
                a = RandomReal[{-1, 1}, {3, 3, 2}], v = RandomReal[{-1, 1}, 2],
                c = RandomReal[{-1, 1}, {3, 2, 3}], d = RandomReal[{-1, 1}, {2, 4}]
            },
            With[
                {
                    vectorNet = TensorNetwork[{a, v}, {{1, 1, 2}, {2}}],
                    vectorValue = TensorContract[TensorProduct[a, v], {{1, 2}, {3, 4}}],
                    matrixNet = TensorNetwork[{c, d}, {{1, 2, 1}, {2, 3}}],
                    matrixValue = TensorContract[TensorProduct[c, d], {{1, 3}, {2, 4}}]
                },
                {
                    numericSameQ[TensorNetworkContract[vectorNet, {{1, 2}}, Method -> #], vectorValue] & /@ $TensorNetworkContractionMethods,
                    numericSameQ[TensorNetworkContract[matrixNet, {{1, 2}}, Method -> #], matrixValue] & /@ $TensorNetworkContractionMethods,
                    numericSameQ[TensorNetworkContract[#1, #2], #3] & @@@ {
                        {vectorNet, "Optimal", vectorValue}, {vectorNet, "Greedy", vectorValue},
                        {matrixNet, "Optimal", matrixValue}, {matrixNet, "Greedy", matrixValue}
                    },
                    numericSameQ[ActivateTensors[TensorNetworkContraction[matrixNet, {{1, 2}}]], matrixValue]
                }
            ]
        ]
    ],
    {
        ConstantArray[True, Length[$TensorNetworkContractionMethods]],
        ConstantArray[True, Length[$TensorNetworkContractionMethods]],
        {True, True, True, True},
        True
    },
    TestID -> "A13.traced_index_pair_equals_trace_then_product"
]

(* A14. A single matrix whose two slots carry the same label contracts to
   its trace, along the optimal and the greedy path. *)
VerificationTest[
    BlockRandom[SeedRandom[10];
        With[{m = RandomReal[{-1, 1}, {4, 4}]},
            numericSameQ[TensorNetworkContract[TensorNetwork[{m}, {{1, 1}}], #], Tr[m]] & /@ {"Optimal", "Greedy"}
        ]
    ],
    {True, True},
    TestID -> "A14.self_traced_matrix_equals_trace"
]

(* A15. Adding a tensor to a network with no open index joins nothing, so
   the value is the outer product: the empty network plus m is m, and the
   closed ring Tr[a.b.c] plus a vector v is Tr[a.b.c] v. *)
VerificationTest[
    BlockRandom[SeedRandom[12];
        With[
            {
                m = RandomReal[{-1, 1}, {2, 3}], v = RandomReal[{-1, 1}, 3],
                ts = RandomReal[{-1, 1}, #] & /@ {{2, 3}, {3, 4}, {4, 2}}
            },
            With[
                {
                    fromEmpty = TensorNetworkAdd[Graph[{}, {}], m],
                    fromRing = TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[ts, {{1, 2}, {2, 3}, {3, 1}}]], v]
                },
                {
                    GraphQ[fromEmpty] && numericSameQ[TensorNetworkContract[fromEmpty], m],
                    GraphQ[fromRing] && numericSameQ[TensorNetworkContract[fromRing], Tr[Dot @@ ts] v]
                }
            ]
        ]
    ],
    {True, True},
    TestID -> "A15.added_tensor_on_closed_network_is_outer_product"
]

(* A16-A19 add a tensor to the graph of the chain a.b, whose open legs have
   dimensions 2 (the row index of a) and 4 (the column index of b). *)

(* A16. With no index list, a 4 x 5 tensor t joins its dimension-4 slot to
   the dimension-4 leg and keeps its dimension-5 slot open: the network
   becomes a.b.t, with the dimension-2 leg of a still open. *)
VerificationTest[
    BlockRandom[SeedRandom[4];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], t = RandomReal[1, {4, 5}]},
            {TensorNetworkContract[TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]], t]], a . b . t}
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A16.automatic_add_joins_leg_of_equal_dimension"
]

(* A17. A 2 x 4 tensor u has one slot of each open dimension; with no index
   list it closes the network to the scalar Sum_ik (a.b)[[i,k]] u[[i,k]]. *)
VerificationTest[
    BlockRandom[SeedRandom[5];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], u = RandomReal[1, {2, 4}]},
            {TensorNetworkContract[TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]], u]], Total[a . b u, 2]}
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A17.automatic_add_closes_legs_in_dimension_order"
]

(* A18. A 7 x 4 x 2 tensor w has no leg of dimension 7, so with no index list
   its first slot stays open and the other two close the chain: the value is
   Sum_ik (a.b)[[i,k]] w[[m,k,i]] for each m. *)
VerificationTest[
    BlockRandom[SeedRandom[6];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], w = RandomReal[1, {7, 4, 2}]},
            {
                TensorNetworkContract[TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]], w]],
                Table[Sum[(a . b)[[i, k]] w[[m, k, i]], {i, 2}, {k, 4}], {m, 7}]
            }
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A18.automatic_add_skips_slot_without_matching_leg"
]

(* A19. A 2 x 5 tensor x joined on the dimension-2 leg only, given
   explicitly, keeps its second slot as a separate open leg: the network is
   Transpose[a.b].x. *)
VerificationTest[
    BlockRandom[SeedRandom[7];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 4}], x = RandomReal[1, {2, 5}]},
            {TensorNetworkContract[TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]], x, {Superscript[1, 1]}]], Transpose[a . b] . x}
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A19.explicit_add_on_one_leg_keeps_other_slot_open"
]

(* A20. On the chain a.b with a 2 x 3 and b 3 x 2, both open legs have
   dimension 2, so slots follow the order of TensorNetworkFreeIndices: the
   first slot of m takes the row index of a and the second the column index
   of b, giving Sum_ik (a.b)[[i,k]] m[[i,k]], not the value for Transpose[m]. *)
VerificationTest[
    BlockRandom[SeedRandom[8];
        With[{a = RandomReal[1, {2, 3}], b = RandomReal[1, {3, 2}], m = RandomReal[1, {2, 2}]},
            {TensorNetworkContract[TensorNetworkAdd[ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]], m]], Total[a . b m, 2]}
        ]
    ] // Apply[numericSameQ],
    True,
    TestID -> "A20.automatic_add_ties_follow_free_index_order"
]


(* ============================================ *)
(* B. Network structure                         *)
(* ============================================ *)

(* B1. The bonds of a chain with dimensions 2, 3, 4, 5 are the labels
   shared by two tensors, with their dimensions 3 and 4; open legs are
   not bonds. *)
VerificationTest[
    Values @ TensorNetwork[ConstantArray[0, #] & /@ {{2, 3}, {3, 4}, {4, 5}}, {{"a", "b"}, {"b", "c"}, {"c", "d"}}]["Bonds"],
    {3, 4},
    TestID -> "B1.bonds_are_shared_labels"
]

(* B2. A random network on a graph has a bond exactly where the graph has
   an edge, whatever the vertex names: tensor k is the k-th vertex. *)
VerificationTest[
    BlockRandom[SeedRandom[1];
        {
            bondedPairs[RandomTensorNetwork[Graph[{3, 1, 2}, {3 <-> 1, 3 <-> 2}], 2]],
            bondedPairs[RandomTensorNetwork[Graph[{"a" <-> "b", "b" <-> "c"}], 2]]
        }
    ],
    {{{1, 2}, {1, 3}}, {{1, 2}, {2, 3}}},
    TestID -> "B2.random_network_bonds_follow_graph_edges"
]

(* B3. A tree tensor network: its bonds form a tree on the N tensors, so
   there are N - 1 bonds, no open legs, and the all-ones contraction
   counts 2^(N-1) assignments. *)
VerificationTest[
    BlockRandom[SeedRandom[5];
        With[{tn = RandomTensorNetwork[#]},
            {TreeGraphQ[Graph[Range[Length[tn["Tensors"]]], UndirectedEdge @@@ bondedPairs[tn]]], onesContraction[tn] - 2^(Length[tn["Tensors"]] - 1)}
        ] & /@ {"TTN"[3, 2], "TTN"[3, 2, 3]}
    ],
    {{True, 0}, {True, 0}},
    TestID -> "B3.tree_network_counts_bond_assignments"
]

(* B4. MERA on 4 sites with bond dimension 2: six open legs of dimension 2,
   and each open assignment extends to 2^4 assignments of the four
   internal bonds, so every entry of the all-ones contraction is 16. *)
VerificationTest[
    BlockRandom[SeedRandom[6];
        With[{r = onesContraction[RandomTensorNetwork["MERA"[4, 2]]]}, {Dimensions[r], Union[Flatten[r]]}]
    ],
    {{2, 2, 2, 2, 2, 2}, {16}},
    TestID -> "B4.mera_counts_internal_bond_assignments"
]

(* B5. The bonds of an r x c PEPS form the r x c grid graph: every label
   sits on at most two tensors and the bond graph is isomorphic to the
   grid, including grids with 100 or more bonds. *)
VerificationTest[
    BlockRandom[SeedRandom[7];
        Function[rc,
            With[{tn = RandomTensorNetwork["PEPS"[rc, 2]]},
                {Max[labelMultiplicities[tn]], IsomorphicGraphQ[Graph[UndirectedEdge @@@ bondedPairs[tn]], GridGraph[rc]]}
            ]
        ] /@ {{2, 3}, {11, 11}, {12, 3}, {4, 30}}
    ],
    ConstantArray[{2, True}, 4],
    TestID -> "B5.peps_bond_count"
]

(* B6. With one fixed bond dimension for every index, a random network on
   a graph still has a bond exactly where the graph has an edge: tensor k
   is the k-th vertex, so the bonded pairs are the edges of IndexGraph[g],
   and every index has the given dimension. *)
VerificationTest[
    BlockRandom[SeedRandom[13];
        Function[g,
            With[{tn = RandomTensorNetwork[g, {3}]},
                {
                    bondedPairs[tn] === Sort[Sort /@ List @@@ EdgeList[IndexGraph[g]]],
                    Union[Flatten[Dimensions /@ tn["Tensors"]]]
                }
            ]
        ] /@ {
            Graph[{3, 1, 2}, {3 <-> 1, 3 <-> 2}],
            Graph[{"a" <-> "b", "b" <-> "c", "c" <-> "a"}],
            Graph[{5, 2, 9, 4}, {5 <-> 9, 9 <-> 2, 2 <-> 4, 4 <-> 5}]
        }
    ],
    ConstantArray[{True, {3}}, 3],
    TestID -> "B6.fixed_dimension_network_bonds_follow_graph_edges"
]


(* ============================================ *)
(* C. Contraction paths                         *)
(* ============================================ *)

(* C1. Tensor 1 carries a traced pair {1, 1} and a bond 2 to the next
   tensor. After the trace it still holds bond 2, and the optimal path
   costs the minimum over every pairwise contraction order of the traced
   network. The label-list form of the path finder is used because it
   reaches the trace step. *)
VerificationTest[
    With[{sets = {{1, 1, 2}, {2, 3}, {3, 4}}, out = {4}, dims = <|1 -> 3, 2 -> 2, 3 -> 50, 4 -> 2|>},
        pathCost[sets, OptimalContractionPath[sets, out, dims, Method -> "flops"], out, dims] - minimumPairwiseCost[{{2}, {2, 3}, {3, 4}}, out, dims]
    ],
    0,
    TestID -> "C1.traced_tensor_optimal_path_is_minimal"
]

(* C2. On 20 random connected networks of 5 or 6 tensors, with loops,
   parallel bonds and bond dimensions 2 to 5, the optimal path costs the
   exhaustive minimum over orders without outer products. *)
VerificationTest[
    Select[
        Flatten[Table[{n, seed}, {n, {5, 6}}, {seed, 10}], 1],
        Function[{spec},
            With[
                {
                    edges = BlockRandom[SeedRandom[Last[spec]];
                        Join[Table[{k, RandomInteger[{1, k - 1}]}, {k, 2, First[spec]}], RandomSample[Subsets[Range[First[spec]], {2}], 2]]
                    ]
                },
                With[
                    {
                        sets = networkLabels[edges, First[spec]],
                        out = {Length[edges] + 1, Length[edges] + 2},
                        dims = BlockRandom[SeedRandom[Last[spec]]; AssociationThread[Range[Length[edges] + 2], RandomInteger[{2, 5}, Length[edges] + 2]]]
                    },
                    pathCost[sets, OptimalContractionPath[sets, out, dims, Method -> "flops"], out, dims] =!= minimumPairwiseCost[sets, out, dims]
                ]
            ]
        ]
    ],
    {},
    TestID -> "C2.random_networks_optimal_path_is_minimal"
]

(* C3. The optimal flops path on the ring network costs the exhaustive
   minimum whether the pre-simplification runs or not and whether outer
   products are allowed. Pre-simplification decides how a traced index
   pair is summed: with it, tensor 1 is traced alone first; without it,
   the trace is taken inside the first pairwise step. *)
VerificationTest[
    With[
        {
            cost = pathCost[ringSets, OptimalContractionPath[ringSets, ringOutput, ringDimensions, Method -> "flops", ##], ringOutput, ringDimensions] &,
            minimum = minimumPairwiseCost[ringSets, ringOutput, ringDimensions]
        },
        {
            cost[] - minimum,
            cost["PreSimplify" -> False] - minimum,
            cost["AllowOuterProducts" -> True] - minimum,
            GreedyContractionPath[{{1, 1, 2}, {2, 3}, {3}}, {}, <|1 -> 3, 2 -> 2, 3 -> 2|>, "PreSimplify" -> #] & /@ {True, False}
        }
    ],
    {0, 0, 0, {{{1}, {1, 2}, {1, 2}}, {{1, 2}, {1, 2}}}},
    TestID -> "C3.boolean_options_keep_optimal_cost"
]

(* C4. With "FixedIndexing" -> True the path names every intermediate
   result by a new number; rewritten as positions in the shrinking tensor
   list it contracts the ring network to its explicit index sum, as do the
   greedy paths found with and without pre-simplification. *)
VerificationTest[
    With[{value = directContraction[ringTensors, ringSets, ringOutput]},
        numericSameQ[TensorNetworkContract[ringNetwork, #], value] & /@ {
            ssaToLinearPath[OptimalContractionPath[ringNetwork, "FixedIndexing" -> True], Length[ringSets]],
            ssaToLinearPath[GreedyContractionPath[ringNetwork, "FixedIndexing" -> True], Length[ringSets]],
            GreedyContractionPath[ringNetwork, "PreSimplify" -> False]
        }
    ],
    {True, True, True},
    TestID -> "C4.fixed_indexing_path_contracts_to_index_sum"
]


(* ============================================ *)
(* D. Matrix product states                     *)
(* ============================================ *)

(* D1. On every cut of a random complex 6-site state with bond dimension 3,
   the Schmidt values are the singular values of the normalized state
   vector reshaped across that cut. *)
VerificationTest[
    Table[{MPSSchmidtValues[mpsSix, k], cutSpectrum[psiSix, 6, k]}, {k, 5}] // Map[Apply[numericSameQ]],
    ConstantArray[True, 5],
    TestID -> "D1.schmidt_values_equal_state_svd"
]

(* D2. On every cut the entanglement entropy is -Sum p Log p over the
   squared singular values of the full state. *)
VerificationTest[
    Table[{MPSEntanglementEntropy[mpsSix, k], With[{pk = cutSpectrum[psiSix, 6, k]^2}, -Total[pk Log[pk]]]}, {k, 5}] // Map[Apply[numericSameQ]],
    ConstantArray[True, 5],
    TestID -> "D2.entanglement_entropy_equals_state_svd"
]

(* D3. Every tensor but the last of a left-canonical complex state is a
   left isometry, every tensor but the first of a right-canonical one is a
   right isometry, and both leave the state vector unchanged. *)
VerificationTest[
    With[{lc = MPSCanonicalForm[mpsSix, "Left"], rc = MPSCanonicalForm[mpsSix, "Right"]},
        {
            isometryQ[leftGram[#]] & /@ Most[lc["Tensors"]],
            isometryQ[rightGram[#]] & /@ Rest[rc["Tensors"]],
            numericSameQ[stateVector[#, 6], psiSix] & /@ {lc, rc}
        }
    ],
    {ConstantArray[True, 5], ConstantArray[True, 5], {True, True}},
    TestID -> "D3.left_canonical_tensors_are_isometries"
]

(* D4. Two sites with 4-dimensional physical legs and bond dimension 5
   have Schmidt rank 4. Left-canonicalizing, then right-canonicalizing
   with MaxBond -> chi, keeps the chi largest Schmidt values: the fidelity
   with the original state is Sum_{k<=chi} s_k^2 / Sum s_k^2, the
   Eckart-Young optimum, and reaches 1 at chi = 4. *)
VerificationTest[
    BlockRandom[SeedRandom[9];
        With[{two = TensorNetwork[RandomComplex[{-1 - I, 1 + I}, {2, 5, 4}], {{1, 3}, {1, 4}}]},
            With[{psi = Flatten[directContraction[two["Tensors"], two["Hyperedges"], {3, 4}]]},
                With[{sv = SingularValueList[ArrayReshape[psi, {4, 4}]]},
                    Table[
                        {
                            fidelity[psi, Flatten[With[{t = MPSCanonicalForm[MPSCanonicalForm[two, "Left"], "Right", "MaxBond" -> chi]}, directContraction[t["Tensors"], t["Hyperedges"], {3, 4}]]]],
                            Total[Take[sv, chi]^2] / Total[sv^2]
                        },
                        {chi, 4}
                    ]
                ]
            ]
        ]
    ] // Map[Apply[numericSameQ]],
    ConstantArray[True, 4],
    TestID -> "D4.canonical_truncation_reaches_eckart_young"
]

(* D5. On six sites with bond dimension 4 truncation is no longer optimal
   cut by cut, but the infidelity of the truncated state stays below the
   discarded Schmidt weight summed over all five cuts,
   Sum_cuts Sum_{k>chi} s_k^2, and vanishes at chi = 4, the largest
   Schmidt rank. *)
VerificationTest[
    With[{mps = complexMPS[6, 4, 7]},
        With[{psi = Normalize[stateVector[mps, 6]]},
            Table[
                With[{phi = stateVector[MPSCanonicalForm[MPSCanonicalForm[mps, "Left"], "Right", "MaxBond" -> chi], 6]},
                    {
                        1 - fidelity[psi, phi] <= Total[Table[Total[Drop[cutSpectrum[psi, 6, k], UpTo[chi]]^2], {k, 5}]] + 10^-12,
                        chi < 4 || 1 - fidelity[psi, phi] < 10^-12
                    }
                ],
                {chi, 4}
            ]
        ]
    ],
    ConstantArray[{True, True}, 4],
    TestID -> "D5.multisite_truncation_within_discarded_weight"
]

(* D6. A product state stored with bond dimension 3 has Schmidt rank 1 on
   every cut, so right-canonicalizing with MaxBond -> 1 reduces every bond
   to 1 and leaves the state unchanged. *)
VerificationTest[
    BlockRandom[SeedRandom[11];
        With[{n = 4, u = RandomReal[{-1, 1}, 3], a = RandomReal[{-1, 1}, {4, 2}]},
            With[
                {
                    mps = TensorNetwork[
                        Join[{TensorProduct[u, a[[1]]]}, Table[TensorProduct[u, u, a[[i]]], {i, 2, n - 1}], {TensorProduct[u, a[[n]]]}],
                        mpsHyperedges[n]
                    ]
                },
                With[{c = MPSCanonicalForm[mps, "Right", "MaxBond" -> 1]},
                    {numericSameQ[stateVector[c, n], stateVector[mps, n]], Max[Most /@ Dimensions /@ c["Tensors"]]}
                ]
            ]
        ]
    ],
    {True, 1},
    TestID -> "D6.product_state_truncates_exactly_to_bond_one"
]

(* D7. The W state on n sites, (|10..0> + |01..0> + ... + |0..01>) / Sqrt[n],
   has exactly two Schmidt coefficients on the cut after site k,
   Sqrt[k/n] and Sqrt[(n-k)/n], and entropy binaryEntropy[k/n]; checked
   exactly for n = 3..8 on every cut. *)
VerificationTest[
    Union @ Flatten @ Table[
        {
            Sort[MPSSchmidtValues[wState[n], k]] == Sort[Sqrt[{k, n - k} / n]],
            FullSimplify[MPSEntanglementEntropy[wState[n], k] - binaryEntropy[k / n]] === 0
        },
        {n, 3, 8}, {k, n - 1}
    ],
    {True},
    TestID -> "D7.w_state_schmidt_spectrum_exact"
]

(* D8. The GHZ state (|0..0> + |1..1>) / Sqrt[2] has Schmidt coefficients
   {1/Sqrt[2], 1/Sqrt[2]} and entropy Log[2] on every cut. *)
VerificationTest[
    Union @ Flatten[Table[{MPSSchmidtValues[ghzState[n], k], MPSEntanglementEntropy[ghzState[n], k]}, {n, 3, 8}, {k, n - 1}], 1],
    {{{1 / Sqrt[2], 1 / Sqrt[2]}, Log[2]}},
    TestID -> "D8.ghz_state_schmidt_spectrum_exact"
]

(* D9. Cutting one site off the W state gives S(n) = binaryEntropy[1/n],
   whose large-n expansion (1 + Log n)/n + c2/n^2 + c3/n^3 + ... has its
   coefficients taken from Series (c2 = -1/2, c3 = -1/6). For n = 16, 32,
   64, 128 the entropy computed from the MPS follows it: the rescaled
   residual n (n^2 (S - (1 + Log n)/n) - c2) lies within 1/n of c3, so the
   expansion converges at the predicted rate. *)
VerificationTest[
    With[{expansion = Expand[Normal[Series[binaryEntropy[1 / m], {m, Infinity, 3}]]]},
        With[{c2 = Coefficient[expansion, m, -2], c3 = Coefficient[expansion, m, -3]},
            Function[n,
                Abs[N[n (n^2 (MPSEntanglementEntropy[wState[n], 1] - (1 + Log[n]) / n) - c2)] - c3] < 1 / n
            ] /@ {16, 32, 64, 128}
        ]
    ],
    {True, True, True, True},
    TestID -> "D9.w_state_entropy_large_n"
]

(* D10. A state with one zero tensor is the zero vector, and so is its
   canonical form. *)
VerificationTest[
    With[{mps = complexMPS[5, 3, 7]},
        Max[Abs[stateVector[MPSCanonicalForm[TensorNetwork[ReplacePart[mps["Tensors"], 2 -> ConstantArray[0., {3, 3, 2}]], mps["Hyperedges"]], "Left", "MaxBond" -> 1], 5]]]
    ],
    0,
    SameTest -> Equal,
    TestID -> "D10.zero_state_canonical_form_is_zero"
]


(* ============================================ *)
(* E. Dimensions                                *)
(* ============================================ *)

(* E1. The root of a contraction tree carries the dimensions of the
   contracted network, for every engine, on a network with a rank-3
   tensor, a free vector and a reordered output. The reference dimensions
   come from the direct contraction: free labels 1, 3, 5, 6 in order, then
   the transposition Cycles[{{1, 4}}]. *)
VerificationTest[
    BlockRandom[SeedRandom[5];
        With[
            {
                tensors = {RandomReal[1, {2, 3}], RandomReal[1, {3, 4, 5}], RandomReal[1, {5, 6}], RandomReal[1, {7}]},
                hyperedges = {{1, 2}, {2, 3, 4}, {4, 5}, {6}}
            },
            With[
                {
                    tn = TensorNetwork[tensors, hyperedges, Cycles[{{1, 4}}]],
                    reference = Dimensions[Transpose[directContraction[tensors, hyperedges, {1, 3, 5, 6}], Cycles[{{1, 4}}]]]
                },
                ArrayDimensions[TreeData[ContractionTree[TensorNetworkContraction[tn, {{1, 2}, {1, 2}, {1, 2}}, Method -> #]]]] === reference & /@ $TensorNetworkContractionMethods
            ]
        ]
    ],
    ConstantArray[True, Length[$TensorNetworkContractionMethods]],
    TestID -> "E1.tree_root_has_result_dimensions"
]

(* E2. A network with the scalar 3 and a closed vector pair v.v = 5
   contracts to the number 15, and the root of its contraction tree has no
   dimensions. *)
VerificationTest[
    With[{expr = TensorNetworkContraction[TensorNetwork[{3., {1., 2.}, {1., 2.}}, {{}, {1}, {1}}], {{1, 2}, {1, 2}}]},
        {ActivateTensors[expr], ArrayDimensions[TreeData[ContractionTree[expr]]]}
    ],
    {15., {}},
    TestID -> "E2.scalar_network_has_rank_zero"
]

(* E3. ArrayDot of symbolic arrays of dimensions {a, b, c} and {c, b, e}
   contracting axis 2 with axis 2 has dimensions {a, c, c, e}; with
   a..e = 2, 3, 4, 5 these are the dimensions of the numeric ArrayDot. *)
VerificationTest[
    {
        ArrayDimensions[ArrayDot[ArraySymbol["A", {da, db, dc}], ArraySymbol["B", {dc, db, de}], {{2, 2}}]],
        ArrayDimensions[ArrayDot[ArraySymbol["A", {2, 3, 4}], ArraySymbol["B", {4, 3, 5}], {{2, 2}}]]
    },
    {{da, dc, dc, de}, Dimensions[ArrayDot[ConstantArray[1, {2, 3, 4}], ConstantArray[1, {4, 3, 5}], {{2, 2}}]]},
    TestID -> "E3.symbolic_arraydot_dimensions"
]

(* E4. Fixing the first index of a symbolic array of dimensions {a, b, c}
   leaves {b, c}; on numeric shapes this is what Part gives. *)
VerificationTest[
    {
        ArrayDimensions[ArrayPart[ArraySymbol["A", {da, db, dc}], {2}]],
        ArrayDimensions[ArrayPart[ArraySymbol["A", {2, 3, 4, 5}], {2}]],
        ArrayDimensions[ArrayPart[ArraySymbol["A", {2, 3, 4}], {1}]]
    },
    {{db, dc}, Dimensions[ConstantArray[0, {2, 3, 4, 5}][[2]]], Dimensions[ConstantArray[0, {2, 3, 4}][[1]]]},
    TestID -> "E4.symbolic_slice_dimensions"
]


(* ============================================ *)
(* F. Renaming indices                          *)
(* ============================================ *)

(* A renaming that sends every index label to a new label: the second
   slot of Superscript[v, n] / Subscript[v, n] is wrapped in a list. *)
renameAll[g_Graph] := With[{all = Catenate[TensorNetworkIndices[g]]},
    Thread[all -> Replace[all, (h : Superscript | Subscript)[v_, n_] :> h[v, {n}], {1}]]
]

(* The renamed graph carries the renamed labels, on its vertices and on
   both ends of every edge. *)
renamedLabelsQ[g_Graph, rules_] := With[{h = TensorNetworkReplaceIndices[g, rules]},
    TensorNetworkIndices[h] === Replace[TensorNetworkIndices[g], rules, {2}] &&
        Sort[Catenate[EdgeTags[h]]] === Sort[Replace[Catenate[EdgeTags[g]], rules, {1}]]
]

(* Contraction of the network rebuilt from a graph with renamed indices,
   minus the reference value. *)
renamedResidual[g_Graph, rules_, reference_] :=
    Expand[TensorNetworkContract[TensorNetwork[TensorNetworkReplaceIndices[g, rules]]] - reference]

matA = Array[x, {2, 3}];
matB = Array[y, {3, 4}];
matC = Array[z, {4, 2}];
vecU = Array[p, 2];
vecV = Array[q, 2];
vecW = Array[r, 2];


(* F1. Chain A_ij B_jk: renaming every index, the bond on both of its
   ends, contracts to the matrix product A.B. *)
VerificationTest[
    With[{g = ToTensorNetworkGraph[TensorNetwork[{matA, matB}, {{i, j}, {j, k}}]]},
        {renamedLabelsQ[g, renameAll[g]], renamedResidual[g, renameAll[g], matA . matB]}
    ],
    {True, ConstantArray[0, {2, 4}]},
    TestID -> "F1.renamed_chain_equals_matrix_product"
]

(* F2. Ring A_ij B_jk C_ki: every index is a bond, so a renaming that
   missed either end of an edge would disconnect the ring. The renamed
   graph contracts to Tr[A.B.C]. *)
VerificationTest[
    With[{g = ToTensorNetworkGraph[TensorNetwork[{matA, matB, matC}, {{i, j}, {j, k}, {k, i}}]]},
        {renamedLabelsQ[g, renameAll[g]], renamedResidual[g, renameAll[g], Tr[matA . matB . matC]]}
    ],
    {True, 0},
    TestID -> "F2.renamed_ring_equals_trace"
]

(* F3. Hyperedge u_i v_i w_i: the graph routes the shared index through a
   spider vertex, whose indices are renamed too. The renamed graph
   contracts to Sum_i u_i v_i w_i. *)
VerificationTest[
    With[{g = ToTensorNetworkGraph[TensorNetwork[{vecU, vecV, vecW}, {{i}, {i}, {i}}]]},
        {renamedLabelsQ[g, renameAll[g]], renamedResidual[g, renameAll[g], Total[vecU vecV vecW]]}
    ],
    {True, 0},
    TestID -> "F3.renamed_hyperedge_equals_index_sum"
]

(* F4. Renaming only the two free indices of the chain: they sit on no
   edge, so the edge tags stay as they were. The free indices of the
   rebuilt network are the new labels, and it still contracts to A.B. *)
VerificationTest[
    With[{g = ToTensorNetworkGraph[TensorNetwork[{matA, matB}, {{i, j}, {j, k}}]]},
        With[{
            rules = {Superscript[1, 1] -> Superscript[1, "a"], Subscript[2, 2] -> Subscript[2, "c"]}
        },
            {
                renamedLabelsQ[g, rules],
                Sort[TensorNetwork[TensorNetworkReplaceIndices[g, rules]]["FreeIndices"]],
                renamedResidual[g, rules, matA . matB]
            }
        ]
    ],
    {True, Sort[{Superscript[1, "a"], Subscript[2, "c"]}], ConstantArray[0, {2, 4}]},
    TestID -> "F4.renamed_free_indices_keep_product"
]
