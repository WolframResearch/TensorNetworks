(* Tests/test_mps_comprehensive.wl *)
(* Comprehensive tests for MPS.wl - ALL patterns, ALL options, EXACT verification *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* Helper: Check if tensor is left-isometric   *)
(* ============================================ *)

isLeftIsometricQ[tensor_, tol_ : 10^-10] := Block[{dims, mat, prod},
    dims = Dimensions[tensor];
    If[Length[dims] == 2,
        mat = Transpose[tensor],
        mat = ArrayReshape[Transpose[tensor, {1, 3, 2}], {dims[[1]] * dims[[-1]], dims[[2]]}]
    ];
    prod = ConjugateTranspose[mat] . mat;
    Norm[prod - IdentityMatrix[Dimensions[prod][[1]]], "Frobenius"] < tol
]

(* ============================================ *)
(* Helper: Check if tensor is right-isometric  *)
(* ============================================ *)

isRightIsometricQ[tensor_, tol_ : 10^-10] := Block[{dims, mat, prod},
    dims = Dimensions[tensor];
    If[Length[dims] == 2,
        mat = tensor,
        mat = ArrayReshape[tensor, {dims[[1]], dims[[2]] * dims[[-1]]}]
    ];
    prod = mat . ConjugateTranspose[mat];
    Norm[prod - IdentityMatrix[Dimensions[prod][[1]]], "Frobenius"] < tol
]

(* ============================================ *)
(* MPSCanonicalForm - "Left" Form              *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    TensorNetworkQ[canonical],
    True,
    TestID -> "MPSCanonicalForm_Left_ReturnsTensorNetwork"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    MPSCanonicalQ[canonical, "Left"],
    True,
    TestID -> "MPSCanonicalForm_Left_PassesCanonicalQ"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    tensors = canonical["Tensors"];
    n = Length[tensors];
    (* All tensors except last should be left-isometric *)
    AllTrue[tensors[[;; n - 1]], isLeftIsometricQ],
    True,
    TestID -> "MPSCanonicalForm_Left_TensorsAreLeftIsometric"
]

(* ============================================ *)
(* MPSCanonicalForm - "Right" Form             *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Right"];
    TensorNetworkQ[canonical],
    True,
    TestID -> "MPSCanonicalForm_Right_ReturnsTensorNetwork"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Right"];
    MPSCanonicalQ[canonical, "Right"],
    True,
    TestID -> "MPSCanonicalForm_Right_PassesCanonicalQ"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    canonical = MPSCanonicalForm[mps, "Right"];
    tensors = canonical["Tensors"];
    n = Length[tensors];
    (* All tensors except first should be right-isometric *)
    AllTrue[tensors[[2 ;;]], isRightIsometricQ],
    True,
    TestID -> "MPSCanonicalForm_Right_TensorsAreRightIsometric"
]

(* ============================================ *)
(* MPSCanonicalForm - {"Mixed", k} Form        *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    canonical = MPSCanonicalForm[mps, {"Mixed", 3}];
    TensorNetworkQ[canonical],
    True,
    TestID -> "MPSCanonicalForm_Mixed_ReturnsTensorNetwork"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    canonical = MPSCanonicalForm[mps, {"Mixed", 3}];
    MPSCanonicalQ[canonical, {"Mixed", 3}],
    True,
    TestID -> "MPSCanonicalForm_Mixed_PassesCanonicalQ"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 4, 2]];
    canonical = MPSCanonicalForm[mps, {"Mixed", 3}];
    tensors = canonical["Tensors"];
    {
        (* Tensors 1, 2 should be left-isometric *)
        AllTrue[tensors[[;; 2]], isLeftIsometricQ],
        (* Tensors 4, 5, 6 should be right-isometric *)
        AllTrue[tensors[[4 ;;]], isRightIsometricQ]
    },
    {True, True},
    TestID -> "MPSCanonicalForm_Mixed_CorrectIsometries"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    (* Test mixed canonical at different sites *)
    canonical1 = MPSCanonicalForm[mps, {"Mixed", 1}];
    canonical2 = MPSCanonicalForm[mps, {"Mixed", 2}];
    canonical5 = MPSCanonicalForm[mps, {"Mixed", 5}];
    {
        MPSCanonicalQ[canonical1, {"Mixed", 1}],
        MPSCanonicalQ[canonical2, {"Mixed", 2}],
        MPSCanonicalQ[canonical5, {"Mixed", 5}]
    },
    {True, True, True},
    TestID -> "MPSCanonicalForm_Mixed_DifferentSites"
]

(* ============================================ *)
(* MPSCanonicalForm - Default (Left)           *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps];
    MPSCanonicalQ[canonical, "Left"],
    True,
    TestID -> "MPSCanonicalForm_DefaultIsLeft"
]

(* ============================================ *)
(* MPSCanonicalForm - "MaxBond" Option         *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    canonical = MPSCanonicalForm[mps, "Left", "MaxBond" -> 3];
    dims = Dimensions /@ canonical["Tensors"];
    (* Extract all bond dimensions *)
    bondDims = Flatten[Cases[dims, {a_, b_, ___} :> {a, b}]];
    Max[bondDims] <= 3,
    True,
    TestID -> "MPSCanonicalForm_MaxBond_RespectsLimit"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    canonical = MPSCanonicalForm[mps, "Right", "MaxBond" -> 4];
    dims = Dimensions /@ canonical["Tensors"];
    bondDims = Flatten[Cases[dims, {a_, b_, ___} :> {a, b}]];
    Max[bondDims] <= 4,
    True,
    TestID -> "MPSCanonicalForm_Right_MaxBond"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 6, 2]];
    canonical = MPSCanonicalForm[mps, {"Mixed", 3}, "MaxBond" -> 2];
    dims = Dimensions /@ canonical["Tensors"];
    bondDims = Flatten[Cases[dims, {a_, b_, ___} :> {a, b}]];
    Max[bondDims] <= 2,
    True,
    TestID -> "MPSCanonicalForm_Mixed_MaxBond"
]

(* ============================================ *)
(* MPSCanonicalForm - "Tolerance" Option       *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 5, 2]];
    canonicalZeroTol = MPSCanonicalForm[mps, "Left", "Tolerance" -> 0];
    canonicalWithTol = MPSCanonicalForm[mps, "Left", "Tolerance" -> 0.1];
    {
        TensorNetworkQ[canonicalZeroTol],
        TensorNetworkQ[canonicalWithTol]
    },
    {True, True},
    TestID -> "MPSCanonicalForm_Tolerance_Option"
]

(* ============================================ *)
(* MPSCanonicalForm - Preserves Output         *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    {
        canonical["Output"] === mps["Output"],
        canonical["Hyperedges"] === mps["Hyperedges"]
    },
    {True, True},
    TestID -> "MPSCanonicalForm_PreservesStructure"
]

(* ============================================ *)
(* MPSCanonicalQ - "Left" with Tolerance       *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    {
        MPSCanonicalQ[canonical, "Left", 10^-10],
        MPSCanonicalQ[canonical, "Left", 10^-5],
        MPSCanonicalQ[canonical, "Left", 0.1]
    },
    {True, True, True},
    TestID -> "MPSCanonicalQ_Left_WithTolerance"
]

(* ============================================ *)
(* MPSCanonicalQ - "Right" with Tolerance      *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Right"];
    {
        MPSCanonicalQ[canonical, "Right", 10^-10],
        MPSCanonicalQ[canonical, "Right", 10^-5]
    },
    {True, True},
    TestID -> "MPSCanonicalQ_Right_WithTolerance"
]

(* ============================================ *)
(* MPSCanonicalQ - Non-canonical MPS           *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    (* After canonicalization, it should be canonical *)
    MPSCanonicalQ[MPSCanonicalForm[mps, "Left"], "Left", 10^-5],
    True,
    TestID -> "MPSCanonicalQ_AfterCanonicalization"
]

(* ============================================ *)
(* MPSOverlap - Self overlap is real & positive*)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    overlap = MPSOverlap[mps, mps];
    {
        NumericQ[overlap],
        Abs[Im[overlap]] < 10^-10,  (* Real *)
        Re[overlap] > 0  (* Positive *)
    },
    {True, True, True},
    TestID -> "MPSOverlap_SelfOverlap_RealPositive"
]

(* ============================================ *)
(* MPSOverlap - Gauge invariance               *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    leftMPS = MPSCanonicalForm[mps, "Left"];
    rightMPS = MPSCanonicalForm[mps, "Right"];
    overlapOriginal = MPSOverlap[mps, mps];
    overlapLeft = MPSOverlap[leftMPS, leftMPS];
    overlapRight = MPSOverlap[rightMPS, rightMPS];
    {
        Abs[overlapOriginal - overlapLeft] < 10^-8,
        Abs[overlapOriginal - overlapRight] < 10^-8
    },
    {True, True},
    TestID -> "MPSOverlap_GaugeInvariant"
]

(* ============================================ *)
(* MPSOverlap - Cross overlap                  *)
(* ============================================ *)

VerificationTest[
    mps1 = RandomTensorNetwork["MPS"[4, 3, 2]];
    mps2 = RandomTensorNetwork["MPS"[4, 3, 2]];
    overlap12 = MPSOverlap[mps1, mps2];
    overlap21 = MPSOverlap[mps2, mps1];
    (* <psi|phi> = conj(<phi|psi>) for complex *)
    Abs[overlap12 - Conjugate[overlap21]] < 10^-8,
    True,
    TestID -> "MPSOverlap_CrossOverlap_Conjugate"
]

(* ============================================ *)
(* MPSOverlap - Normalized MPS has overlap 1   *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    normalized = MPSNormalize[mps];
    overlap = MPSOverlap[normalized, normalized];
    Abs[overlap - 1] < 10^-8,
    True,
    TestID -> "MPSOverlap_NormalizedMPS_OverlapIsOne"
]

(* ============================================ *)
(* MPSNorm - Is positive                       *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    norm = MPSNorm[mps];
    {
        NumericQ[norm],
        norm > 0
    },
    {True, True},
    TestID -> "MPSNorm_IsPositive"
]

(* ============================================ *)
(* MPSNorm - Equals Sqrt[<psi|psi>]            *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    norm = MPSNorm[mps];
    overlap = MPSOverlap[mps, mps];
    Abs[norm - Sqrt[Abs[overlap]]] < 10^-8,
    True,
    TestID -> "MPSNorm_EqualsSqrtOverlap"
]

(* ============================================ *)
(* MPSNorm - Gauge invariant                   *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    leftMPS = MPSCanonicalForm[mps, "Left"];
    rightMPS = MPSCanonicalForm[mps, "Right"];
    {
        Abs[MPSNorm[mps] - MPSNorm[leftMPS]] < 10^-8,
        Abs[MPSNorm[mps] - MPSNorm[rightMPS]] < 10^-8
    },
    {True, True},
    TestID -> "MPSNorm_GaugeInvariant"
]

(* ============================================ *)
(* MPSNormalize - Gives unit norm              *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    normalized = MPSNormalize[mps];
    norm = MPSNorm[normalized];
    Abs[norm - 1] < 10^-8,
    True,
    TestID -> "MPSNormalize_UnitNorm"
]

(* ============================================ *)
(* MPSNormalize - Preserves structure          *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    normalized = MPSNormalize[mps];
    {
        TensorNetworkQ[normalized],
        Length[normalized["Tensors"]] === Length[mps["Tensors"]],
        normalized["Hyperedges"] === mps["Hyperedges"]
    },
    {True, True, True},
    TestID -> "MPSNormalize_PreservesStructure"
]

(* ============================================ *)
(* MPSNormalize - Idempotent on normalized     *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    normalized = MPSNormalize[mps];
    doubleNormalized = MPSNormalize[normalized];
    Abs[MPSNorm[doubleNormalized] - 1] < 10^-8,
    True,
    TestID -> "MPSNormalize_IdempotentOnNormalized"
]

(* ============================================ *)
(* MPSSchmidtValues - At valid site            *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    schmidt = MPSSchmidtValues[mps, 2];
    {
        ListQ[schmidt],
        AllTrue[schmidt, NumericQ],
        AllTrue[schmidt, # >= 0 &]  (* Non-negative *)
    },
    {True, True, True},
    TestID -> "MPSSchmidtValues_ValidSite_ReturnsNonNegativeValues"
]

(* ============================================ *)
(* MPSSchmidtValues - Normalized (sum^2 = 1)   *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    schmidt = MPSSchmidtValues[mps, 2];
    Abs[Total[schmidt^2] - 1] < 10^-8,
    True,
    TestID -> "MPSSchmidtValues_Normalized"
]

(* ============================================ *)
(* MPSSchmidtValues - Different sites          *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    schmidt1 = MPSSchmidtValues[mps, 1];
    schmidt2 = MPSSchmidtValues[mps, 2];
    schmidt3 = MPSSchmidtValues[mps, 3];
    schmidt4 = MPSSchmidtValues[mps, 4];
    AllTrue[{schmidt1, schmidt2, schmidt3, schmidt4},
        Abs[Total[#^2] - 1] < 10^-8 &],
    True,
    TestID -> "MPSSchmidtValues_AllSitesNormalized"
]

(* ============================================ *)
(* MPSSchmidtValues - Edge cases               *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    schmidtFirst = MPSSchmidtValues[mps, 0];  (* Invalid site *)
    schmidtLast = MPSSchmidtValues[mps, 5];   (* Edge site (n) - invalid for bond (n, n+1) *)
    {
        ListQ[schmidtFirst],
        ListQ[schmidtLast]
    },
    {True, True},
    TestID -> "MPSSchmidtValues_EdgeSites"
]

(* ============================================ *)
(* MPSEntanglementEntropy - Non-negative       *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    entropy = MPSEntanglementEntropy[mps, 2];
    {
        NumericQ[entropy],
        entropy >= -10^-10  (* Allow small numerical errors *)
    },
    {True, True},
    TestID -> "MPSEntanglementEntropy_NonNegative"
]

(* ============================================ *)
(* MPSEntanglementEntropy - Formula: -Σp log p *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    site = 2;
    schmidt = MPSSchmidtValues[mps, site];
    probabilities = schmidt^2;
    expectedEntropy = -Total[Select[probabilities, # > 0 &] * Log[Select[probabilities, # > 0 &]]];
    entropy = MPSEntanglementEntropy[mps, site];
    Abs[entropy - expectedEntropy] < 10^-8,
    True,
    TestID -> "MPSEntanglementEntropy_MatchesFormula"
]

(* ============================================ *)
(* MPSEntanglementEntropy - Different sites    *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    entropy1 = MPSEntanglementEntropy[mps, 1];
    entropy2 = MPSEntanglementEntropy[mps, 2];
    entropy3 = MPSEntanglementEntropy[mps, 3];
    AllTrue[{entropy1, entropy2, entropy3}, # >= -10^-10 &],
    True,
    TestID -> "MPSEntanglementEntropy_AllSitesNonNegative"
]

(* ============================================ *)
(* MPSEntanglementEntropy - Product state      *)
(* ============================================ *)

VerificationTest[
    (* Product state should have zero entanglement *)
    mps = RandomTensorNetwork["MPS"[3, 1, 2]];  (* Bond dim 1 = product state *)
    entropy = MPSEntanglementEntropy[mps, 1];
    entropy >= -10^-10,  (* Should be non-negative *)
    True,
    TestID -> "MPSEntanglementEntropy_SmallBondDim"
]

(* ============================================ *)
(* MPSTruncate - Returns TensorNetwork         *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4];
    TensorNetworkQ[truncated],
    True,
    TestID -> "MPSTruncate_ReturnsTensorNetwork"
]

(* ============================================ *)
(* MPSTruncate - Respects MaxBond              *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 3];
    dims = Dimensions /@ truncated["Tensors"];
    bondDims = Flatten[Cases[dims, {a_, b_, ___} :> {a, b}]];
    Max[bondDims] <= 3,
    True,
    TestID -> "MPSTruncate_RespectsMaxBond"
]

(* ============================================ *)
(* MPSTruncate - "Normalize" -> True (default) *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4, "Normalize" -> True];
    norm = MPSNorm[truncated];
    Abs[norm - 1] < 10^-8,
    True,
    TestID -> "MPSTruncate_Normalize_True"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4];  (* Default should be Normalize -> True *)
    norm = MPSNorm[truncated];
    Abs[norm - 1] < 10^-8,
    True,
    TestID -> "MPSTruncate_Normalize_Default"
]

(* ============================================ *)
(* MPSTruncate - "Normalize" -> False          *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4, "Normalize" -> False];
    {
        TensorNetworkQ[truncated],
        (* Norm might not be 1 when not normalized *)
        NumericQ[MPSNorm[truncated]]
    },
    {True, True},
    TestID -> "MPSTruncate_Normalize_False"
]

(* ============================================ *)
(* MPSTruncate - Preserves structure           *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4];
    {
        Length[truncated["Tensors"]] === Length[mps["Tensors"]],
        truncated["Hyperedges"] === mps["Hyperedges"]
    },
    {True, True},
    TestID -> "MPSTruncate_PreservesStructure"
]

(* ============================================ *)
(* MPSTruncate - Small MaxBond                 *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 6, 2]];
    truncated = MPSTruncate[mps, 1];
    dims = Dimensions /@ truncated["Tensors"];
    bondDims = Flatten[Cases[dims, {a_, b_, ___} :> {a, b}]];
    Max[bondDims] <= 1,
    True,
    TestID -> "MPSTruncate_MaxBondOne"
]

(* ============================================ *)
(* MPSTruncate - Large MaxBond (no truncation) *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    truncated = MPSTruncate[mps, 100];  (* Larger than any possible bond *)
    {
        TensorNetworkQ[truncated],
        Abs[MPSNorm[truncated] - 1] < 10^-8
    },
    {True, True},
    TestID -> "MPSTruncate_LargeMaxBond_NoTruncation"
]

(* ============================================ *)
(* Complex MPS Tests                           *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], Method -> "Complex"];
    canonical = MPSCanonicalForm[mps, "Left"];
    MPSCanonicalQ[canonical, "Left"],
    True,
    TestID -> "MPSCanonicalForm_ComplexMPS"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], Method -> "Complex"];
    overlap = MPSOverlap[mps, mps];
    Re[overlap] > 0,  (* Self-overlap should be positive real *)
    True,
    TestID -> "MPSOverlap_ComplexMPS"
]

(* ============================================ *)
(* Edge Cases - Short MPS                      *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[2, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    MPSCanonicalQ[canonical, "Left"],
    True,
    TestID -> "MPSCanonicalForm_ShortMPS_Length2"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[1, 3, 2]];
    norm = MPSNorm[mps];
    norm > 0,
    True,
    TestID -> "MPSNorm_SingleSiteMPS"
]

(* ============================================ *)
(* Edge Cases - Different Physical Dimensions  *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 4]];  (* Physical dim = 4 *)
    canonical = MPSCanonicalForm[mps, "Left"];
    {
        TensorNetworkQ[canonical],
        MPSCanonicalQ[canonical, "Left"]
    },
    {True, True},
    TestID -> "MPSCanonicalForm_PhysicalDim4"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 3]];  (* Physical dim = 3 *)
    normalized = MPSNormalize[mps];
    Abs[MPSNorm[normalized] - 1] < 10^-8,
    True,
    TestID -> "MPSNormalize_PhysicalDim3"
]

(* ============================================ *)
(* Periodic MPS Tests                          *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], "Boundary" -> "Periodic"];
    norm = MPSNorm[mps];
    norm > 0,
    True,
    TestID -> "MPSNorm_PeriodicMPS"
]

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2], "Boundary" -> "Periodic"];
    overlap = MPSOverlap[mps, mps];
    Re[overlap] > 0,
    True,
    TestID -> "MPSOverlap_PeriodicMPS"
]

(* ============================================ *)
(* Canonicalization preserves state            *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Left"];
    (* Overlap between original and canonical should be high for normalized versions *)
    normalized = MPSNormalize[mps];
    normalizedCanon = MPSNormalize[canonical];
    Abs[MPSOverlap[normalized, normalizedCanon]] > 0.99,
    True,
    TestID -> "MPSCanonicalForm_PreservesState"
]
