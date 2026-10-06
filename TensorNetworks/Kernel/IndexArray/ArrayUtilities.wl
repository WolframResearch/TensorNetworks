Package["Wolfram`TensorNetworks`IndexArray`"]

PackageImport["Wolfram`Arrays`"]

PackageExport[ArraySymmetry]

PackageScope[squareMatrixQ]



(* ArrayDimensions, ArrayRank, ArrayName, ArrayPart, ArrayTranspose,
   ArrayContract, SimplifyArray and ZeroArrayQ used to be defined here, in this
   subcontext, in a form this paclet grew for its own tensors.  They now come
   from Wolfram/Arrays, a declared dependency (see PacletInfo.wl), which hosts
   the same operations generalized past the tensors of a tensor network to
   every array container it classifies - explicit, lazy and symbolic.  The
   definitions were the ancestors of those, so this is a delegation, not a
   substitution: the clauses this paclet relied on are still the clauses that
   run, with container tiers added around them.

   Nothing is re-exported under a Wolfram`TensorNetworks`IndexArray` name.  A
   forwarding alias would have to be unwound the moment index notation lands in
   Arrays and EinsteinSummation follows it there, and a second symbol per name
   is exactly the shadowing this file existed to create: a session with both
   contexts loaded silently resolved ArrayDimensions to one of two different
   functions depending on load order.  Code inside this subcontext reaches the
   operations through the PackageImport above, which is FILE-scoped - every
   other file here that calls one carries its own.

   ArraySymmetry stays because Arrays has no symmetry API at all; it is the one
   operation of the original file with nothing upstream to delegate to. *)


(* Symmetry is read off the materialized data for the explicit containers that
   TensorSymmetry does not evaluate on - NumericArray, ByteArray, Tabular and
   the other storage wrappers - which is the guard shape Arrays uses for the
   same reason in ArrayContract.  Structured arrays stay on the native path:
   TensorSymmetry reads a SymmetrizedArray's symmetry from its structure
   without touching an element, and materializing one would throw that away.

   The rank test comes first and does two things.  It answers {} for a scalar,
   which has no indices to be symmetric in, and it is what keeps ragged input
   quiet: TensorSymmetry emits TensorSymmetry::rect on a nonrectangular array,
   and ArrayDimensions has already refused such input with {}, so the rank is 0
   and the message is never reached.  That is a guard, not a Quiet. *)

ArraySymmetry[t_] := If[
    ArrayRank[t] == 0,
    {},
    Replace[
        TensorSymmetry[If[ArrayExplicitQ[t] && ! ArrayQ[t], ArrayMaterialize[t], t]],
        Except[_Symmetric | _Antisymmetric | _ZeroSymmetric] -> {}
    ]
]


(* Kept local rather than taken from Wolfram`Arrays`PackageScope`: a one-line
   predicate is not worth reaching into another paclet's private context for,
   and this one is read by MetricTensor's constructor, which is this paclet's
   own notion of what a metric may be built from. *)

squareMatrixQ[t_] := MatchQ[ArrayDimensions[t], {n_, n_} | {_, 0}]
