(* Tests/test_mps.wl *)
(* Tests for MPS algorithms. Each test asserts a STRUCTURAL property
   (canonicality, isometry, norm positivity, ...), not a specific numeric
   value — but we pin RNG so the same MPS instances are exercised on every
   run for reproducibility. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

SeedRandom[42];

(* ============================================ *)
(* Test: Left Canonicalization                 *)
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
    TestID -> "MPSCanonicalForm_Left_IsCanonical"
]

(* ============================================ *)
(* Test: Right Canonicalization                *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    canonical = MPSCanonicalForm[mps, "Right"];
    MPSCanonicalQ[canonical, "Right"],
    True,
    TestID -> "MPSCanonicalForm_Right_IsCanonical"
]

(* ============================================ *)
(* Test: Mixed Canonicalization                *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[5, 4, 2]];
    canonical = MPSCanonicalForm[mps, {"Mixed", 3}];
    MPSCanonicalQ[canonical, {"Mixed", 3}],
    True,
    TestID -> "MPSCanonicalForm_Mixed_IsCanonical"
]

(* ============================================ *)
(* Test: Right Canonicalization Respects MaxBond *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    canonical = MPSCanonicalForm[mps, "Right", "MaxBond" -> 3];
    dims = Dimensions /@ canonical["Tensors"];
    bondDims = Flatten[Map[If[Length[#] == 2, {First[#]}, {#[[1]], #[[2]]}] &, dims]];
    Max[bondDims] <= 3,
    True,
    TestID -> "MPSCanonicalForm_Right_RespectsMaxBond"
]

(* ============================================ *)
(* Test: Overlap is Real and Positive for Self *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    overlap = MPSOverlap[mps, mps];
    Abs[Im[overlap]] < 10^-10 && Re[overlap] > 0,
    True,
    TestID -> "MPSOverlap_SelfIsRealPositive"
]

(* ============================================ *)
(* Test: Overlap is Gauge Invariant            *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    leftMPS = MPSCanonicalForm[mps, "Left"];
    Abs[MPSOverlap[mps, mps] - MPSOverlap[leftMPS, leftMPS]] < 10^-8,
    True,
    TestID -> "MPSOverlap_GaugeInvariant"
]

(* ============================================ *)
(* Test: Norm is Positive                      *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    MPSNorm[mps] > 0,
    True,
    TestID -> "MPSNorm_IsPositive"
]

(* ============================================ *)
(* Test: Normalize Gives Unit Norm             *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    normalized = MPSNormalize[mps];
    Abs[MPSNorm[normalized] - 1] < 10^-8,
    True,
    TestID -> "MPSNormalize_UnitNorm"
]

(* ============================================ *)
(* Test: Entanglement Entropy is Non-negative  *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    entropy = MPSEntanglementEntropy[mps, 2];
    NumericQ[entropy] && entropy >= -10^-10,  (* Allow small numerical errors *)
    True,
    TestID -> "MPSEntanglementEntropy_NonNegative"
]

(* ============================================ *)
(* Test: Schmidt Values Sum to 1 (squared)     *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[4, 3, 2]];
    schmidt = MPSSchmidtValues[mps, 2];
    Abs[Total[schmidt^2] - 1] < 10^-8,
    True,
    TestID -> "MPSSchmidtValues_Normalized"
]

(* ============================================ *)
(* Test: Truncation Preserves TensorNetwork    *)
(* ============================================ *)

VerificationTest[
    mps = RandomTensorNetwork["MPS"[6, 8, 2]];
    truncated = MPSTruncate[mps, 4];
    TensorNetworkQ[truncated],
    True,
    TestID -> "MPSTruncate_ReturnsTensorNetwork"
]
