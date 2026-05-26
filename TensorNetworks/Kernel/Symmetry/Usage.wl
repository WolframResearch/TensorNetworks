Package["Wolfram`TensorNetworks`Symmetry`"]


HookFactor::usage = "\!\(\*RowBox[{\"HookFactor\", \"[\", StyleBox[\"partition\", \"TI\"], \
\"]\"}]\) computes \!\(\*RowBox[{\"1\", \"/\", RowBox[{\"\[Product]\", \" \", \
StyleBox[\"h\", \"TI\"]}]}]\), the reciprocal product of the hook lengths of \
the Young diagram of StyleBox[\"partition\", \"TI\"], evaluated by the \
Frobenius determinant formula. \[Bullet]\n\!\(\*RowBox[{\"HookFactor\", \
\"[\", StyleBox[\"tableau\", \"TI\"], \"]\"}]\) does the same for the \
underlying partition of a Young StyleBox[\"tableau\", \"TI\"]."



HookLengths::usage = "\!\(\*RowBox[{\"HookLengths\", \"[\", StyleBox[\"partition\", \"TI\"], \
\"]\"}]\) returns the nested list of hook lengths for the Young diagram of \
the integer partition \!\(\*StyleBox[\"partition\", \
\"TI\"]\).\n\!\(\*RowBox[{\"HookLengths\", \"[\", StyleBox[\"tableau\", \
\"TI\"], \"]\"}]\) returns the hook lengths for the underlying partition of \
the YoungTableau \!\(\*StyleBox[\"tableau\", \"TI\"]\)."



HookLength::usage = "\!\(\*RowBox[{\"HookLength\", \"[\", RowBox[{StyleBox[\"tableau\", \"TI\"], \
\",\", \" \", RowBox[{\"{\", RowBox[{StyleBox[\"row\", \"TI\"], \",\", \" \", \
StyleBox[\"col\", \"TI\"]}], \"}\"}]}], \"]\"}]\) computes the hook length at \
position {\!\(\*StyleBox[\"row\", \"TI\"]\), \!\(\*StyleBox[\"col\", \
\"TI\"]\)} of a Young tableau."



PartitionQ::usage = "\!\(\*RowBox[{\"PartitionQ\", \"[\", StyleBox[\"list\", \"TI\"], \"]\"}]\) \
yields True if \!\(\*StyleBox[\"list\", \"TI\"]\) is a valid integer \
partition: a non-empty list of positive integers in non-increasing order."



SchurDimension::usage = "\!\(\*RowBox[{\"SchurDimension\", \"[\", RowBox[{StyleBox[\"partition\", \
\"TI\"], \",\", \" \", StyleBox[\"d\", \"TI\"]}], \"]\"}]\) gives the \
dimension of the \!\(\*RowBox[{\"GL\", \"(\", StyleBox[\"d\", \"TI\"], \
\")\"}]\) Weyl module corresponding to the integer StyleBox[\"partition\", \" \
TI\"] via the hook-content formula. \
\[Bullet]\n\!\(\*RowBox[{\"SchurDimension\", \"[\", \
RowBox[{StyleBox[\"tableau\", \"TI\"], \",\", \" \", StyleBox[\"d\", \
\"TI\"]}], \"]\"}]\) does the same when the input is a Young \
StyleBox[\"tableau\", \" TI\"]."



TableauColumns::usage = "\!\(\*RowBox[{\"TableauColumns\", \"[\", StyleBox[\"tableau\", \"TI\"], \
\"]\"}]\) returns the column slot lists of a Young tableau."



TableauDimension::usage = "\!\(\*RowBox[{\"TableauDimension\", \"[\", StyleBox[\"tableau\", \"TI\"], \
\"]\"}]\) gives the dimension of the irreducible representation of the \
symmetric group corresponding to a Young StyleBox[\"tableau\", \" TI\"], \
computed via the hook-length formula. \
\[Bullet]\n\!\(\*RowBox[{\"TableauDimension\", \"[\", StyleBox[\"partition\", \
\"TI\"], \"]\"}]\) does the same when the input is a bare integer \
StyleBox[\"partition\", \"TI\"]."



TableauRows::usage = "\!\(\*RowBox[{\"TableauRows\", \"[\", StyleBox[\"tableau\", \"TI\"], \
\"]\"}]\) returns the inner row list of a Young tableau as a list of lists of \
slot indices."



TableauShape::usage = "\!\(\*RowBox[{\"TableauShape\", \"[\", StyleBox[\"tableau\", \"TI\"], \
\"]\"}]\) returns the partition (list of row lengths) of a Young tableau."



TableauSize::usage = "\!\(\*RowBox[{\"TableauSize\", \"[\", StyleBox[\"tableau\", \"TI\"], \
\"]\"}]\) returns the total number of boxes in a Young tableau, i.e. the sum \
of its row lengths."



TableauWeylDimension::usage = "\!\(\*RowBox[{\"TableauWeylDimension\", \"[\", RowBox[{StyleBox[\"tableau\", \
\"TI\"], \",\", \" \", StyleBox[\"d\", \"TI\"]}], \"]\"}]\) gives the \
\!\(\*RowBox[{\"GL\", \"(\", StyleBox[\"d\", \"TI\"], \")\"}]\) Weyl module \
dimension for the partition underlying the Young StyleBox[\"tableau\", \" \
TI\"]."



TransposePartition::usage = "\!\(\*RowBox[{\"TransposePartition\", \"[\", StyleBox[\"partition\", \
\"TI\"], \"]\"}]\) returns the conjugate (transpose) of an integer partition, \
equivalent to swapping rows and columns of the corresponding Young diagram."



YoungProject::usage = "\!\(\*RowBox[{\"YoungProject\", \"[\", RowBox[{StyleBox[\"tensor\", \"TI\"], \
\",\", StyleBox[\"tableau\", \"TI\"]}], \"]\"}]\) returns the normalized \
projection of \!\(\*StyleBox[\"tensor\", \"TI\"]\) onto the symmetry class \
labelled by the Young \!\(\*StyleBox[\"tableau\", \"TI\"]\); the operator is \
idempotent."



YoungSymmetrize::usage = "\!\(\*RowBox[{\"YoungSymmetrize\", \"[\", RowBox[{StyleBox[\"tensor\", \
\"TI\"], \",\", StyleBox[\"tableau\", \"TI\"]}], \"]\"}]\) returns the \
unnormalized Young-symmetrized \!\(\*StyleBox[\"tensor\", \"TI\"]\) obtained \
by first symmetrizing over the rows of \!\(\*StyleBox[\"tableau\", \"TI\"]\) \
and then antisymmetrizing over its columns."



YoungTableauQ::usage = "\!\(\*RowBox[{\"YoungTableauQ\", \"[\", StyleBox[\"expr\", \"TI\"], \
\"]\"}]\) yields True if \!\(\*StyleBox[\"expr\", \"TI\"]\) is a valid \
YoungTableau and False otherwise."



YoungTableau::usage = "\!\(\*RowBox[{\"YoungTableau\", \"[\", StyleBox[\"rows\", \"TI\"], \"]\"}]\) \
represents a Young tableau, where \!\(\*StyleBox[\"rows\", \"TI\"]\) is a \
list of lists of slot indices.\n\!\(\*RowBox[{\"YoungTableau\", \"[\", \
StyleBox[\"partition\", \"TI\"], \"]\"}]\) constructs a standard tableau from \
an integer \!\(\*StyleBox[\"partition\", \"TI\"]\), auto-filling rows in \
reading order."
