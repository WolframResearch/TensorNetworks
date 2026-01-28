(* ::Package:: *)

Package["Wolfram`TensorNetworks`Symmetry`"]

(* ============================================ *)
(* YoungTableaux.wl                             *)
(* ============================================ *)

YoungTableau::usage = "YoungTableau[rows] represents a Young tableau where rows is a list of lists of slot indices. It defines how tensor indices transform under permutations for symmetrization.
\[Bullet] YoungTableau[{{\!\(\*SubscriptBox[\(i\), \(1, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(1, \*SubscriptBox[\(d\), \(1\)]\)]\)},{\!\(\*SubscriptBox[\(i\), \(2, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(2, \*SubscriptBox[\(d\), \(2\)]\)]\)},...,{\!\(\*SubscriptBox[\(i\), \(n, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(n, \*SubscriptBox[\(d\), \(n\)]\)]\)}}] creates a tableau with shape {\!\(\*SubscriptBox[\(d\), \(1\)]\),...,\!\(\*SubscriptBox[\(d\), \(n\)]\)} and slots assigned explicitly.
\[Bullet] YoungTableau[{\!\(\*SubscriptBox[\(d\), \(1\)]\),...,\!\(\*SubscriptBox[\(d\), \(n\)]\)}] creates a standard tableau from a partition, automatically assigning slots row by row."

YoungTableauQ::usage = "YoungTableauQ[expr] returns True if expr is a valid Young tableau, and False otherwise.
\[Bullet] A valid tableau has non-increasing row lengths and distinct positive integer entries."

TableauShape::usage = "TableauShape[tableau] returns the shape (partition) of a Young tableau as a list of row lengths.
\[Bullet] TableauShape[YoungTableau[{{\!\(\*SubscriptBox[\(i\), \(1, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(1, \*SubscriptBox[\(d\), \(1\)]\)]\)},{\!\(\*SubscriptBox[\(i\), \(2, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(2, \*SubscriptBox[\(d\), \(2\)]\)]\)},...,{\!\(\*SubscriptBox[\(i\), \(n, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(n, \*SubscriptBox[\(d\), \(n\)]\)]\)}}]] returns {\!\(\*SubscriptBox[\(d\), \(1\)]\),...,\!\(\*SubscriptBox[\(d\), \(n\)]\)}."

TableauSize::usage = "TableauSize[tableau] returns the total number of boxes (size/weight) of a Young tableau.
\[Bullet] TableauSize[YoungTableau[{3,2,1}]] returns 6.
\[Bullet] The size equals the sum of the partition elements and relates to the symmetric group \!\(\*SubscriptBox[\(S\), \(n\)]\)."

HookLength::usage = "HookLength[tableau, {row, col}] computes the hook length at position {row, col} in a Young tableau. It is  Used internally in the hook-length formula for computing irrep dimensions.
\[Bullet] The hook length is the number of cells to the right plus cells below plus 1 (for the cell itself)."

TableauDimension::usage = "TableauDimension[tableau] computes the dimension of the irreducible representation corresponding to the Young tableau.
\[Bullet] Uses the hook-length formula: d = n! / (\[Product] hook lengths).
\[Bullet] TableauDimension[YoungTableau[{3}]] returns 1 (fully symmetric).
\[Bullet] TableauDimension[YoungTableau[{1,1,1}]] returns 1 (fully antisymmetric).
\[Bullet] TableauDimension[YoungTableau[{2,1}]] returns 2 (mixed symmetry)."

YoungSymmetrize::usage = "YoungSymmetrize[tensor, tableau] projects tensor onto the symmetry class defined by the Young tableau.
\[Bullet] First symmetrizes over rows, then antisymmetrizes over columns.
\[Bullet] The tensor rank must equal the number of boxes in the tableau.
\[Bullet] Returns 0 if the tensor has no component in the specified symmetry class."

YoungProject::usage = "YoungProject[tensor, tableau] returns the normalized projection of tensor onto the Young tableau symmetry class.
\[Bullet] Normalization factor is d/n! where d = TableauDimension[tableau] and n = number of boxes.
\[Bullet] The projection is idempotent: YoungProject[YoungProject[t, tab], tab] == YoungProject[t, tab].
\[Bullet] Use this for proper projectors; use YoungSymmetrize for unnormalized symmetrization."

(* ============================================ *)
(* QuantumNumbers.wl                           *)
(* ============================================ *)

ChargeVector::usage = "ChargeVector[{q\:2081, q\:2082, ..., q\:2099}] stores quantum numbers (charges) for each value of a tensor index.
\[Bullet] For U(1) symmetry, charges are integers representing particle number.
\[Bullet] Contraction conserves charge: q\:2090 + q\:2091 = 0 for contracted indices.
\[Bullet] Use -cv to negate all charges for conjugate indices."

ChargeVectorQ::usage = "ChargeVectorQ[expr] returns True if expr is a valid ChargeVector, and False otherwise.
\[Bullet] A valid ChargeVector contains a list of integers."

AllowedContractions::usage = "AllowedContractions[cvA, cvB] returns all index pairs {i, j} where charges sum to zero.
\[Bullet] These are the only pairs that contribute to a symmetry-filtered contraction.
\[Bullet] AllowedContractions[{0,1,-1}, {0,-1,1}] returns {{1,1}, {2,3}, {3,2}}."

ChargesConservedQ::usage = "ChargesConservedQ[cvA, cvB] tests if two charge lists satisfy conservation (sum to zero element-wise).
\[Bullet] ChargesConservedQ[{1,-1,0}, {-1,1,0}] returns True."

IndicesWithCharge::usage = "IndicesWithCharge[cv, charge] returns all index positions with the specified charge value.
\[Bullet] IndicesWithCharge[ChargeVector[{0,1,0,-1,0}], 0] returns {1,3,5}."
