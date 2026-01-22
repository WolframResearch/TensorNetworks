(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

(* ============================================ *)
(* MPS Core Algorithms                         *)
(* ============================================ *)

PackageExport[MPSCanonicalForm]
PackageExport[MPSCanonicalQ]
PackageExport[MPSOverlap]
PackageExport[MPSNorm]
PackageExport[MPSNormalize]
PackageExport[MPSEntanglementEntropy]
PackageExport[MPSSchmidtValues]
PackageExport[MPSTruncate]

(* svdTruncate is a local helper function, not exported *)


(* ============================================ *)
(* Helper: SVD with Truncation                 *)
(* ============================================ *)

Options[svdTruncate] = {"MaxBond" -> Infinity, "Tolerance" -> 0}

svdTruncate[matrix_, OptionsPattern[]] := Block[{
    u, s, v, svals, maxBond, tol, keep, error, normSq
},
    {u, s, v} = SingularValueDecomposition[matrix];
    svals = Diagonal[s];
    maxBond = OptionValue["MaxBond"];
    tol = OptionValue["Tolerance"];
    
    (* Determine cutoff *)
    normSq = Total[svals^2];
    keep = Length[svals];
    
    (* Apply tolerance cutoff *)
    If[tol > 0,
        keep = Min[keep, Count[svals, _?(# > tol &)]]
    ];
    
    (* Apply max bond cutoff *)
    keep = Min[keep, maxBond];
    keep = Max[keep, 1];  (* Keep at least 1 *)
    
    (* Compute truncation error *)
    error = If[keep < Length[svals],
        Sqrt[Total[svals[[keep + 1 ;;]]^2] / normSq],
        0.
    ];
    
    (* Truncate *)
    {
        u[[All, ;; keep]], 
        svals[[;; keep]], 
        ConjugateTranspose[v][[;; keep, All]],
        error
    }
]


(* ============================================ *)
(* MPS Canonicalization                        *)
(* ============================================ *)

Options[MPSCanonicalForm] = {"MaxBond" -> Infinity, "Tolerance" -> 0}

(* Left canonical form *)
MPSCanonicalForm[mps_TensorNetwork ? TensorNetworkQ, "Left", opts : OptionsPattern[]] := 
    mpsLeftCanonical[mps, opts]

(* Right canonical form *)
MPSCanonicalForm[mps_TensorNetwork ? TensorNetworkQ, "Right", opts : OptionsPattern[]] := 
    mpsRightCanonical[mps, opts]

(* Mixed canonical form at site k *)
MPSCanonicalForm[mps_TensorNetwork ? TensorNetworkQ, {"Mixed", k_Integer}, opts : OptionsPattern[]] := 
    mpsMixedCanonical[mps, k, opts]

(* Default to left canonical *)
MPSCanonicalForm[mps_TensorNetwork ? TensorNetworkQ, opts : OptionsPattern[]] := 
    MPSCanonicalForm[mps, "Left", opts]


mpsLeftCanonical[mps_, opts___] := Block[{
    tensors = mps["Tensors"],
    hyperedges = mps["Hyperedges"],
    perm = mps["Permutation"],
    n, newTensors, residual, dims, matrix, u, s, vt, err,
    leftDim, rightDim, physDim
},
    n = Length[tensors];
    newTensors = tensors;
    residual = None;
    
    Do[
        (* Get current tensor, absorbing residual from previous step *)
        dims = Dimensions[newTensors[[i]]];
        
        If[residual =!= None,
            (* Absorb residual from left *)
            newTensors[[i]] = tensorAbsorbLeft[newTensors[[i]], residual]
        ];
        
        dims = Dimensions[newTensors[[i]]];
        
        If[i < n,
            (* Not the last tensor - perform SVD and pass residual right *)
            If[Length[dims] == 2,
                (* Boundary tensor: {bond, physical} - reshape to (physical) × (bond) for SVD *)
                (* Actually for left canon, we want (left×phys) × right, but first tensor has no left *)
                (* Treat as: (phys) × (right_bond) *)
                matrix = Transpose[newTensors[[i]]];  (* {physical, bond} -> {bond, physical} for SVD *)
                {u, s, vt, err} = svdTruncate[matrix, opts];
                newTensors[[i]] = Transpose[u];  (* Back to {bond_new, physical} *)
                residual = DiagonalMatrix[s] . vt
                ,
                (* Bulk tensor: left × right × physical (based on MPS structure) *)
                (* Reshape to (left × physical) × right *)
                leftDim = dims[[1]];
                physDim = dims[[-1]];
                rightDim = dims[[2]];
                matrix = ArrayReshape[
                    Transpose[newTensors[[i]], {1, 3, 2}],  (* left, physical, right *)
                    {leftDim * physDim, rightDim}
                ];
                {u, s, vt, err} = svdTruncate[matrix, opts];
                newTensors[[i]] = Transpose[
                    ArrayReshape[u, {leftDim, physDim, Length[s]}],
                    {1, 3, 2}  (* back to left, right, physical *)
                ];
                residual = DiagonalMatrix[s] . vt
            ]
            ,
            (* Last tensor - just absorb residual *)
            Null
        ],
        {i, n}
    ];
    
    TensorNetwork[newTensors, hyperedges, perm]
]


(* Helper: Infer MPS hyperedges from tensor dimensions *)
inferMPSHyperedges[tensors_List] := Block[{n, dims, hyperedges, bondIdx, physIdx, i},
    n = Length[tensors];
    bondIdx = 1;
    physIdx = n;  (* Physical indices start at n *)
    
    hyperedges = Table[
        dims = Dimensions[tensors[[i]]];
        Which[
            i == 1 && Length[dims] == 2,
                (* First tensor: {right_bond, physical} *)
                {bondIdx++, physIdx++},
            i == n && Length[dims] == 2,
                (* Last tensor: {left_bond, physical} *)
                {bondIdx - 1, physIdx++},
            Length[dims] == 3,
                (* Bulk tensor: {left_bond, right_bond, physical} *)
                Module[{leftB = bondIdx - 1, rightB},
                    rightB = bondIdx++;
                    {If[i == 1, rightB, leftB], rightB, physIdx++}
                ],
            True,
                (* Fallback for unexpected structure *)
                Range[Length[dims]]
        ],
        {i, n}
    ];
    
    (* Fix first tensor if bulk (for very short MPS) *)
    If[n > 0 && Length[Dimensions[tensors[[1]]]] == 2,
        hyperedges[[1]] = {1, n}
    ];
    
    hyperedges
]


mpsRightCanonical[mps_, opts___] := Block[{
    tensors = mps["Tensors"],
    perm = mps["Permutation"],
    n, newTensors, residual, t, dims, mat, i,
    uFull, sFull, vFull, svals, k,
    leftDim, rightDim, physDim, absorbed, newHyperedges
},
    n = Length[tensors];
    newTensors = tensors;
    residual = None;
    
    (* Sweep from right to left *)
    For[i = n, i >= 1, i--,
        t = newTensors[[i]];
        dims = Dimensions[t];
        
        (* Absorb residual from tensor i+1 *)
        If[residual =!= None,
            If[Length[dims] == 2,
                (* Boundary tensor {left, phys}: absorb on left index *)
                (* residual is {old_left, new_left}, t is {old_left, phys} *)
                (* t' = residual^T . t gives {new_left, phys} *)
                t = Transpose[residual] . t,
                (* Bulk tensor {left, right, phys}: absorb on right index *)
                (* residual is {old_right, new_right}, t is {left, old_right, phys} *)
                absorbed = EinsteinSummation[
                    {{"a", "r", "d"}, {"r", "k"}} -> {"a", "k", "d"},
                    {t, residual}
                ];
                t = ActivateTensors[absorbed]
            ];
            newTensors[[i]] = t;
            dims = Dimensions[t]
        ];
        
        (* Decompose if not the first tensor *)
        If[i > 1,
            If[Length[dims] == 2,
                (* Boundary tensor {left, phys}: SVD for right isometry *)
                (* t[left, phys] = U[left, k] . S[k] . V†[k, phys] *)
                (* Keep V†^T = V[phys, k]^T = ... for right-isometry we want V†[k, phys] *)
                (* which satisfies V† . V = I_k (rows are orthonormal) *)
                {uFull, sFull, vFull} = SingularValueDecomposition[t];
                svals = Diagonal[sFull];
                k = Length[svals];
                (* vFull is {phys, phys}, we want first k rows of V† = first k columns of vFull^* *)
                (* V† = ConjugateTranspose[vFull] is {phys, phys}, take first k rows: {k, phys} *)
                newTensors[[i]] = ConjugateTranspose[vFull][[;; k]];
                (* residual = U . S has shape {left, k} *)
                residual = uFull[[All, ;; k]] . DiagonalMatrix[svals],
                
                (* Bulk tensor {left, right, phys}: SVD decomposition *)
                leftDim = dims[[1]];
                rightDim = dims[[2]];
                physDim = dims[[3]];
                (* Reshape to {left, right*phys} and SVD *)
                mat = ArrayReshape[t, {leftDim, rightDim * physDim}];
                {uFull, sFull, vFull} = SingularValueDecomposition[mat];
                svals = Diagonal[sFull];
                k = Length[svals];
                (* V† is first k rows of ConjugateTranspose[vFull], shape {k, right*phys} *)
                (* Reshape to {k, right, phys} *)
                newTensors[[i]] = ArrayReshape[
                    ConjugateTranspose[vFull][[;; k]],
                    {k, rightDim, physDim}
                ];
                (* residual = U . S has shape {left, k} *)
                residual = uFull[[All, ;; k]] . DiagonalMatrix[svals]
            ]
        ]
    ];
    
    (* Rebuild TensorNetwork with correct hyperedges based on new tensor dimensions *)
    newHyperedges = inferMPSHyperedges[newTensors];
    TensorNetwork[newTensors, newHyperedges, perm]
]


mpsMixedCanonical[mps_, k_, opts___] := Block[{
    intermediate
},
    (* Left-canonicalize up to k-1, then right-canonicalize from k+1 *)
    intermediate = mpsLeftCanonicalUpTo[mps, k, opts];
    mpsRightCanonicalFrom[intermediate, k, opts]
]

(* Partial canonicalization helpers *)
mpsLeftCanonicalUpTo[mps_, k_, opts___] := Block[{
    tensors = mps["Tensors"],
    hyperedges = mps["Hyperedges"],
    perm = mps["Permutation"],
    n, newTensors, residual, dims, matrix, u, s, vt, err,
    leftDim, rightDim, physDim
},
    n = Length[tensors];
    newTensors = tensors;
    residual = None;
    
    Do[
        dims = Dimensions[newTensors[[i]]];
        
        If[residual =!= None,
            newTensors[[i]] = tensorAbsorbLeft[newTensors[[i]], residual]
        ];
        
        dims = Dimensions[newTensors[[i]]];
        
        If[i < k,
            If[Length[dims] == 2,
                matrix = newTensors[[i]];
                {u, s, vt, err} = svdTruncate[matrix, opts];
                newTensors[[i]] = u;
                residual = DiagonalMatrix[s] . vt
                ,
                leftDim = dims[[1]];
                physDim = dims[[-1]];
                rightDim = dims[[2]];
                matrix = ArrayReshape[
                    Transpose[newTensors[[i]], {1, 3, 2}],
                    {leftDim * physDim, rightDim}
                ];
                {u, s, vt, err} = svdTruncate[matrix, opts];
                newTensors[[i]] = Transpose[
                    ArrayReshape[u, {leftDim, physDim, Length[s]}],
                    {1, 3, 2}
                ];
                residual = DiagonalMatrix[s] . vt
            ]
            ,
            (* At site k, just absorb residual but don't SVD *)
            residual = None
        ],
        {i, k}
    ];
    
    TensorNetwork[newTensors, hyperedges, perm]
]

mpsRightCanonicalFrom[mps_, k_, opts___] := Block[{
    tensors = mps["Tensors"],
    hyperedges = mps["Hyperedges"],
    perm = mps["Permutation"],
    n, newTensors, residual, dims, matrix, u, s, vt, err,
    leftDim, rightDim, physDim
},
    n = Length[tensors];
    newTensors = tensors;
    residual = None;
    
    Do[
        dims = Dimensions[newTensors[[i]]];
        
        If[residual =!= None,
            newTensors[[i]] = tensorAbsorbRight[newTensors[[i]], residual]
        ];
        
        dims = Dimensions[newTensors[[i]]];
        
        If[i > k,
            If[Length[dims] == 2,
                matrix = newTensors[[i]];
                {u, s, vt, err} = svdTruncate[Transpose[matrix], opts];
                newTensors[[i]] = Transpose[u];
                residual = Transpose[DiagonalMatrix[s] . vt]
                ,
                leftDim = dims[[1]];
                rightDim = dims[[2]];
                physDim = dims[[-1]];
                matrix = ArrayReshape[newTensors[[i]], {leftDim, rightDim * physDim}];
                {u, s, vt, err} = svdTruncate[Transpose[matrix], opts];
                newTensors[[i]] = ArrayReshape[Transpose[u], {Length[s], rightDim, physDim}];
                residual = Transpose[DiagonalMatrix[s] . vt]
            ]
            ,
            (* At site k, absorb residual *)
            residual = None
        ],
        {i, n, k, -1}
    ];
    
    TensorNetwork[newTensors, hyperedges, perm]
]


(* Tensor absorption helpers *)
tensorAbsorbLeft[tensor_, mat_] := Block[{dims = Dimensions[tensor]},
    If[Length[dims] == 2,
        mat . tensor,
        ArrayReshape[
            mat . ArrayReshape[tensor, {dims[[1]], Times @@ dims[[2 ;;]]}],
            Prepend[dims[[2 ;;]], Dimensions[mat][[1]]]
        ]
    ]
]

tensorAbsorbRight[tensor_, mat_] := Block[{dims = Dimensions[tensor]},
    If[Length[dims] == 2,
        tensor . mat,
        ArrayReshape[
            ArrayReshape[tensor, {Times @@ dims[[;; -2]], dims[[-1]]}] . mat,
            Append[dims[[;; -2]], Dimensions[mat][[2]]]
        ]
    ]
]


(* ============================================ *)
(* Check Canonical Form                        *)
(* ============================================ *)

MPSCanonicalQ[mps_TensorNetwork ? TensorNetworkQ, "Left", tol_ : 10^-10] := Block[{
    tensors = mps["Tensors"],
    n, isometric
},
    n = Length[tensors];
    AllTrue[
        tensors[[;; n - 1]],
        isLeftIsometry[#, tol] &
    ]
]

MPSCanonicalQ[mps_TensorNetwork ? TensorNetworkQ, "Right", tol_ : 10^-10] := Block[{
    tensors = mps["Tensors"],
    n
},
    n = Length[tensors];
    AllTrue[
        tensors[[2 ;;]],
        isRightIsometry[#, tol] &
    ]
]

isLeftIsometry[tensor_, tol_] := Block[{
    dims = Dimensions[tensor],
    mat, prod
},
    If[Length[dims] == 2,
        (* Boundary tensor: {bond, physical} -> need {physical, bond} for left-isometry *)
        mat = Transpose[tensor],
        (* Bulk tensor: {left, right, phys} -> reshape to {left*phys, right} *)
        mat = ArrayReshape[
            Transpose[tensor, {1, 3, 2}],
            {dims[[1]] * dims[[-1]], dims[[2]]}
        ]
    ];
    prod = ConjugateTranspose[mat] . mat;
    Norm[prod - IdentityMatrix[Dimensions[prod][[1]]], "Frobenius"] < tol
]

isRightIsometry[tensor_, tol_] := Block[{
    dims = Dimensions[tensor],
    mat, prod
},
    If[Length[dims] == 2,
        mat = tensor,
        mat = ArrayReshape[tensor, {dims[[1]], dims[[2]] * dims[[-1]]}]
    ];
    prod = mat . ConjugateTranspose[mat];
    Norm[prod - IdentityMatrix[Dimensions[prod][[1]]], "Frobenius"] < tol
]


(* ============================================ *)
(* MPS Overlap (Inner Product)                 *)
(* ============================================ *)

MPSOverlap[mps1_TensorNetwork ? TensorNetworkQ, mps2_TensorNetwork ? TensorNetworkQ] := Block[{
    tensors1 = mps1["Tensors"],
    tensors2 = mps2["Tensors"],
    n, transfer, t1, t2, dims1
},
    n = Length[tensors1];
    If[n != Length[tensors2],
        Message[MPSOverlap::length]; Return[$Failed]
    ];
    
    (* First tensor: {right_bond, physical} - contract over physical *)
    t1 = tensors1[[1]];
    t2 = tensors2[[1]];
    dims1 = Dimensions[t1];
    
    If[Length[dims1] == 2,
        (* {bond, physical} - contract physical, keep bond as transfer matrix *)
        transfer = EinsteinSummation[
            {{"b", "d"}, {"bp", "d"}} -> {"b", "bp"},
            {t1, Conjugate[t2]}
        ],
        (* Bulk tensor at position 1 (shouldn't happen for open MPS but handle it) *)
        transfer = EinsteinSummation[
            {{"a", "b", "d"}, {"a", "bp", "d"}} -> {"b", "bp"},
            {t1, Conjugate[t2]}
        ]
    ];
    
    (* Middle tensors: {left_bond, right_bond, physical} *)
    Do[
        t1 = tensors1[[i]];
        t2 = tensors2[[i]];
        dims1 = Dimensions[t1];
        
        If[Length[dims1] == 3,
            (* Bulk: contract left bond with transfer, contract physical, keep right bond *)
            transfer = EinsteinSummation[
                {{"a", "ap"}, {"a", "b", "d"}, {"ap", "bp", "d"}} -> {"b", "bp"},
                {transfer, t1, Conjugate[t2]}
            ],
            (* Boundary (rank 2): {left_bond, physical} - final tensor *)
            (* Contract left bond with transfer, contract physical -> scalar *)
            transfer = EinsteinSummation[
                {{"a", "ap"}, {"a", "d"}, {"ap", "d"}} -> {},
                {transfer, t1, Conjugate[t2]}
            ]
        ],
        {i, 2, n}
    ];
    
    (* Result should be a scalar - activate to get numeric value *)
    transfer = ActivateTensors[transfer];
    If[ArrayQ[transfer] && Dimensions[transfer] == {},
        transfer,
        If[ListQ[transfer] && Length[Flatten[transfer]] == 1,
            First[Flatten[transfer]],
            transfer
        ]
    ]
]

MPSOverlap::length = "MPS lengths do not match.";


(* ============================================ *)
(* MPS Norm                                    *)
(* ============================================ *)

MPSNorm[mps_TensorNetwork ? TensorNetworkQ] := Sqrt[Abs[MPSOverlap[mps, mps]]]


(* ============================================ *)
(* MPS Normalize                               *)
(* ============================================ *)

MPSNormalize[mps_TensorNetwork ? TensorNetworkQ] := Block[{
    tensors = mps["Tensors"],
    hyperedges = mps["Hyperedges"],
    perm = mps["Permutation"],
    norm, factor
},
    norm = MPSNorm[mps];
    If[norm == 0, Return[mps]];
    
    (* Divide first tensor by norm *)
    factor = norm^(1/Length[tensors]);
    TensorNetwork[
        tensors / factor,
        hyperedges,
        perm
    ]
]


(* ============================================ *)
(* Schmidt Values                              *)
(* ============================================ *)

MPSSchmidtValues[mps_TensorNetwork ? TensorNetworkQ, site_Integer] := Block[{
    canonical, tensors, tensor, dims, matrix, svals, normalization
},
    (* Use left-canonical form - Schmidt values are singular values of bond matrix between sites *)
    canonical = MPSCanonicalForm[mps, "Left"];
    tensors = canonical["Tensors"];
    
    (* For bond after site k, we look at tensor k+1 and compute its left singular values *)
    If[site >= Length[tensors],
        (* Last site - return {1} for normalized state *)
        Return[{1.}]
    ];
    
    tensor = tensors[[site + 1]];
    dims = Dimensions[tensor];
    
    (* Reshape tensor to (left_bond) x (other indices) and compute SVD *)
    If[Length[dims] == 2,
        (* Boundary tensor: {bond, physical} *)
        matrix = tensor,
        (* Bulk tensor: {left, right, physical} -> {left, right*physical} *)
        matrix = ArrayReshape[tensor, {dims[[1]], Times @@ dims[[2 ;;]]}]
    ];
    
    svals = SingularValueList[matrix];
    (* Normalize *)
    normalization = Norm[svals];
    If[normalization > 0, svals / normalization, svals]
]


(* ============================================ *)
(* Entanglement Entropy                        *)
(* ============================================ *)

MPSEntanglementEntropy[mps_TensorNetwork ? TensorNetworkQ, site_Integer] := Block[{
    schmidt, probabilities
},
    schmidt = MPSSchmidtValues[mps, site];
    probabilities = schmidt^2;
    (* Von Neumann entropy: -Σ p log(p) *)
    -Total[Select[probabilities, # > 0 &] * Log[Select[probabilities, # > 0 &]]]
]


(* ============================================ *)
(* MPS Truncation                              *)
(* ============================================ *)

Options[MPSTruncate] = {"Normalize" -> True}

MPSTruncate[mps_TensorNetwork ? TensorNetworkQ, maxBond_Integer, opts : OptionsPattern[]] := Block[{
    truncated, normalized
},
    (* Canonicalize with truncation *)
    truncated = MPSCanonicalForm[mps, "Left", "MaxBond" -> maxBond];
    
    If[TrueQ[OptionValue["Normalize"]],
        truncated = MPSNormalize[truncated]
    ];
    
    truncated
]
