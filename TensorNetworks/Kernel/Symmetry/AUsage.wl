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

PartitionQ::usage = "PartitionQ[list] returns True if list is a valid integer partition, i.e. a non-empty list of positive integers in non-increasing order."

TransposePartition::usage = "TransposePartition[partition] returns the conjugate (transpose) of an integer partition.
\[Bullet] Equivalent to swapping rows and columns of the corresponding Young diagram.
\[Bullet] TransposePartition[{4, 2, 1}] returns {3, 2, 1, 1}."

TableauShape::usage = "TableauShape[tableau] returns the shape (partition) of a Young tableau as a list of row lengths.
\[Bullet] TableauShape[YoungTableau[{{\!\(\*SubscriptBox[\(i\), \(1, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(1, \*SubscriptBox[\(d\), \(1\)]\)]\)},{\!\(\*SubscriptBox[\(i\), \(2, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(2, \*SubscriptBox[\(d\), \(2\)]\)]\)},...,{\!\(\*SubscriptBox[\(i\), \(n, 1\)]\),...,\!\(\*SubscriptBox[\(i\), \(n, \*SubscriptBox[\(d\), \(n\)]\)]\)}}]] returns {\!\(\*SubscriptBox[\(d\), \(1\)]\),...,\!\(\*SubscriptBox[\(d\), \(n\)]\)}."

TableauSize::usage = "TableauSize[tableau] returns the total number of boxes in a Young tableau, i.e. the sum of its row lengths."

TableauRows::usage = "TableauRows[tableau] returns the inner row list of a Young tableau as a list of lists of slot indices.
\[Bullet] Explicit accessor since YoungTableau objects are atomic and do not unpack with First or Part.
\[Bullet] Pair with TableauColumns to traverse the column structure."

TableauColumns::usage = "TableauColumns[tableau] returns the column slot lists of a Young tableau as a list of lists.
\[Bullet] Column j collects the slot at position j of every row that reaches position j; handles ragged shapes.
\[Bullet] TableauColumns[YoungTableau[{{1,2,3},{4,5},{6}}]] returns {{1,4,6},{2,5},{3}}."

HookLength::usage = "HookLength[tableau, {row, col}] computes the hook length at position {row, col} in a Young tableau. It is  Used internally in the hook-length formula for computing irrep dimensions.
\[Bullet] The hook length is the number of cells to the right plus cells below plus 1 (for the cell itself)."

HookLengths::usage = "HookLengths[partition] returns the nested list of all hook lengths for the cells of a Young diagram of the given integer partition.
\[Bullet] HookLengths[tableau] returns the hook lengths for the underlying partition of a YoungTableau.
\[Bullet] The product of all hook lengths is the denominator in the hook-length formula for irrep dimensions."

HookFactor::usage = "HookFactor[partition] computes 1 / Product[hook lengths] for the given partition via the Frobenius determinant formula.
\[Bullet] HookFactor[tableau] does the same for the underlying partition of a YoungTableau.
\[Bullet] The dimension of the corresponding S\:2099 irrep is n! HookFactor[partition] where n is the number of boxes."

TableauDimension::usage = "TableauDimension[tableau] computes the dimension of the irreducible representation corresponding to the Young tableau.
\[Bullet] Uses the hook-length formula: d = n! / (\[Product] hook lengths).
\[Bullet] TableauDimension[YoungTableau[{3}]] returns 1 (fully symmetric).
\[Bullet] TableauDimension[YoungTableau[{1,1,1}]] returns 1 (fully antisymmetric).
\[Bullet] TableauDimension[YoungTableau[{2,1}]] returns 2 (mixed symmetry)."

SchurDimension::usage = "SchurDimension[partition, d] returns the dimension of the GL(d) Weyl module corresponding to the partition, computed via the hook-content formula \[Product] (d + j - i) / h(i, j) over diagram cells (i, j).
\[Bullet] Equivalent to the Schur polynomial \!\(\*SubscriptBox[\(s\), \(\[Lambda]\)]\) evaluated at the all-ones point of length d.
\[Bullet] Numerically equals the rank of the single-tableau Young projector on (\!\(\*SuperscriptBox[\(\[DoubleStruckCapitalC]\), \(d\)]\))\^\[CircleTimes]n.
\[Bullet] SchurDimension[YoungTableau[par], d] also accepts a tableau.
\[Bullet] Accepts symbolic d: SchurDimension[{2, 2}, n] returns \!\(\*FractionBox[\(\*SuperscriptBox[\(n\), \(2\)] \((\*SuperscriptBox[\(n\), \(2\)] - 1)\)\), \(12\)]\)."

TableauWeylDimension::usage = "TableauWeylDimension[tableau, d] returns the GL(d) Weyl module dimension for the underlying partition of tableau.
\[Bullet] Tableau-keyed companion to TableauDimension; while TableauDimension[tab] returns the \!\(\*SubscriptBox[\(S\), \(n\)]\) irrep dimension dim \!\(\*SubscriptBox[\(V\), \(\[Lambda]\)]\) (independent of d), TableauWeylDimension[tab, d] returns the GL(d) Weyl module dimension dim \!\(\*SubscriptBox[\(W\), \(\[Lambda]\)]\)(d).
\[Bullet] The product TableauDimension[tab] * TableauWeylDimension[tab, d] is the size of the \[Lambda]-isotypic block of (\!\(\*SuperscriptBox[\(\[DoubleStruckCapitalC]\), \(d\)]\))\^\[CircleTimes]n.
\[Bullet] Equivalent to SchurDimension[TableauShape[tab], d]; accepts symbolic d."

YoungSymmetrize::usage = "YoungSymmetrize[tensor, tableau] projects tensor onto the symmetry class defined by the Young tableau.
\[Bullet] First symmetrizes over rows, then antisymmetrizes over columns.
\[Bullet] The tensor rank must equal the number of boxes in the tableau.
\[Bullet] Returns 0 if the tensor has no component in the specified symmetry class."

YoungProject::usage = "YoungProject[tensor, tableau] returns the normalized projection of tensor onto the Young tableau symmetry class.
\[Bullet] Normalization factor is d/n! where d = TableauDimension[tableau] and n = number of boxes.
\[Bullet] The projection is idempotent: YoungProject[YoungProject[t, tab], tab] == YoungProject[t, tab].
\[Bullet] Use this for proper projectors; use YoungSymmetrize for unnormalized symmetrization."
