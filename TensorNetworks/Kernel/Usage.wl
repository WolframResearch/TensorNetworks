Package["Wolfram`TensorNetworks`"]


ActivateTensors::usage = "\!\(\*RowBox[{\"ActivateTensors\", \"[\", StyleBox[\"expr\", \"TI\"], \
\"]\"}]\) activates \!\(\*RowBox[{\"Inactive\", \"[\", \"TensorProduct\", \
\"]\"}]\), \!\(\*RowBox[{\"Inactive\", \"[\", \"TensorContract\", \"]\"}]\), \
and \!\(\*RowBox[{\"Inactive\", \"[\", \"Transpose\", \"]\"}]\) in \
\!\(\*StyleBox[\"expr\", \"TI\"]\), returning the evaluated tensor."



BinaryTensorNetworkQ::usage = "\!\(\*RowBox[{\"BinaryTensorNetworkQ\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) yields True if every index of \!\(\*StyleBox[\"tn\", \"TI\"]\) \
appears in at most two tensors, i.e. the network has no hyperedges, and False \
otherwise."



BinaryTensorNetwork::usage = "\!\(\*RowBox[{\"BinaryTensorNetwork\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns a binary (pairwise) tensor network equivalent to \
\!\(\*StyleBox[\"tn\", \"TI\"]\), inserting a SymbolicDeltaProductArray \
spider for every index that appears in three or more tensors."



CanonicalPathQ::usage = "\!\(\*RowBox[{\"CanonicalPathQ\", \"[\", StyleBox[\"path\", \"TI\"], \
\"]\"}]\) yields True if \!\(\*StyleBox[\"path\", \"TI\"]\) is a list of \
integer pairs \[LongDash] the canonical opt_einsum form \[LongDash] and False \
otherwise."



CanonicalPath::usage = "\!\(\*RowBox[{\"CanonicalPath\", \"[\", StyleBox[\"path\", \"TI\"], \
\"]\"}]\) returns the canonical (normalized) form of the contraction \
\!\(\*StyleBox[\"path\", \"TI\"]\).\n\!\(\*RowBox[{\"CanonicalPath\", \"[\", \
RowBox[{StyleBox[\"path\", \"TI\"], \",\", StyleBox[\"indices\", \"TI\"]}], \
\"]\"}]\) uses the explicit index list \!\(\*StyleBox[\"indices\", \"TI\"]\) \
for the tree-path round-trip."



ContractIndices::usage = "\!\(\*RowBox[{\"ContractIndices\", \"[\", RowBox[{StyleBox[\"i\", \"TI\"], \
\",\", StyleBox[\"j\", \"TI\"]}], \"]\"}]\) returns the list of indices that \
would be contracted between two index sets i and j (their intersection)."



ContractionTree::usage = "\!\(\*RowBox[{\"ContractionTree\", \"[\", StyleBox[\"expr\", \"TI\"], \
\"]\"}]\) returns a Tree visualizing the contraction hierarchy of the \
inactive contraction expression \!\(\*StyleBox[\"expr\", \
\"TI\"]\).\n\!\(\*RowBox[{\"ContractionTree\", \"[\", \
RowBox[{StyleBox[\"expr\", \"TI\"], \",\", StyleBox[\"opts\", \"TI\"]}], \
\"]\"}]\) applies the option settings \!\(\*StyleBox[\"opts\", \"TI\"]\) (any \
Tree option plus the \!\(\*StyleBox[\"\\\"Labels\\\"\", ShowStringCharacters \
-> True]\) option)."



EinsteinSummation::usage = "\!\(\*RowBox[{\"EinsteinSummation\", \"[\", RowBox[{RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"i\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"i\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}], \",\", RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"A\", \"TI\"], \
\"1\"], \",\", SubscriptBox[StyleBox[\"A\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}]}], \"]\"}]\) returns an inactive expression \
contracting the tensors \!\(\*RowBox[{SubscriptBox[StyleBox[\"A\", \"TI\"], \
\"1\"], \",\", SubscriptBox[StyleBox[\"A\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}]\) over indices that appear more than once, with the output \
indices automatically taken to be those appearing exactly \
once.\n\!\(\*RowBox[{\"EinsteinSummation\", \"[\", \
RowBox[{RowBox[{RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"i\", \"TI\"], \
\"1\"], \",\", SubscriptBox[StyleBox[\"i\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}], \"\[Rule]\", StyleBox[\"out\", \"TI\"]}], \",\", \
RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"A\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"A\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}]}], \"]\"}]\) uses \!\(\*StyleBox[\"out\", \"TI\"]\) as the explicit \
list of output indices.\n\!\(\*RowBox[{\"EinsteinSummation\", \"[\", \
RowBox[{StyleBox[\"\\\"spec\\\"\", \"TI\"], \",\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"A\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"A\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}]}], \"]\"}]\) parses \!\(\*StyleBox[\"\\\"spec\\\"\", \"TI\"]\) as an \
einsum-style string such as \!\(\*StyleBox[\"\\\"ij,jk->ik\\\"\", \"TI\"]\) \
in which commas separate the per-tensor index lists and \
\!\(\*StyleBox[\"\\\"->\\\"\", \"TI\"]\) separates input indices from \
output."



GreedyContractionPath::usage = "\!\(\*RowBox[{\"GreedyContractionPath\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) finds a contraction path through the TensorNetwork \
\!\(\*StyleBox[\"tn\", \"TI\"]\) using a greedy cost-minimization \
heuristic.\n\!\(\*RowBox[{\"GreedyContractionPath\", \"[\", \
StyleBox[\"graph\", \"TI\"], \"]\"}]\) finds a path for a TensorNetwork \
Graph.\n\!\(\*RowBox[{\"GreedyContractionPath\", \"[\", \
RowBox[{\"\[LeftAssociation]\", RowBox[{\"\\\"Dimensions\\\"\", \"\[Rule]\", \
StyleBox[\"dims\", \"TI\"], \",\", \"\\\"Indices\\\"\", \"\[Rule]\", \
StyleBox[\"inds\", \"TI\"], \",\", \"\\\"Contractions\\\"\", \"\[Rule]\", \
StyleBox[\"cs\", \"TI\"]}], \"\[RightAssociation]\"}], \"]\"}]\) finds a path \
from explicit network data in association \
form.\n\!\(\*RowBox[{\"GreedyContractionPath\", \"[\", StyleBox[\"expr\", \
\"TI\"], \"]\"}]\) finds a path for an Inactive TensorContract of a \
TensorProduct.\n\!\(\*RowBox[{\"GreedyContractionPath\", \"[\", \
RowBox[{StyleBox[\"inputs\", \"TI\"], \",\", StyleBox[\"output\", \"TI\"], \
\",\", StyleBox[\"sizeDict\", \"TI\"]}], \"]\"}]\) low-level form taking \
explicit per-tensor index lists, the output indices, and a size-per-index \
Association."



IndexedMultiply::usage = "\!\(\*RowBox[{\"IndexedMultiply\", \"[\", RowBox[{RowBox[{\"{\", \
RowBox[{StyleBox[\"i\", \"TI\"], \",\", StyleBox[\"j\", \"TI\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}], \",\", RowBox[{\"{\", RowBox[{StyleBox[\"A\", \
\"TI\"], \",\", StyleBox[\"B\", \"TI\"], \",\", \"\[Ellipsis]\"}], \"}\"}]}], \
\"]\"}]\) joins the tensors \!\(\*RowBox[{StyleBox[\"A\", \"TI\"], \",\", \
StyleBox[\"B\", \"TI\"], \",\", \"\[Ellipsis]\"}]\) by broadcasting along \
shared indices and returns the pair \!\(\*RowBox[{\"{\", \
RowBox[{StyleBox[\"indices\", \"TI\"], \",\", StyleBox[\"tensor\", \"TI\"]}], \
\"}\"}]\)."



InitializeTensorNetwork::usage = "\!\(\*RowBox[{\"InitializeTensorNetwork\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"tensor\", \"TI\"]}], \
\"]\"}]\) rebinds the boundary of \!\(\*StyleBox[\"graph\", \"TI\"]\) to a \
new vertex 0 annotated with \!\(\*StyleBox[\"tensor\", \"TI\"]\) and default \
\!\(\*RowBox[{\"Superscript\", \"[\", \"0\", \",\", StyleBox[\"k\", \"TI\"], \
\"]\"}]\) indices.\n\!\(\*RowBox[{\"InitializeTensorNetwork\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"tensor\", \"TI\"], \
\",\", StyleBox[\"indices\", \"TI\"]}], \"]\"}]\) uses the explicit index \
list \!\(\*StyleBox[\"indices\", \"TI\"]\) for the new vertex."



MPSCanonicalForm::usage = "\!\(\*RowBox[{\"MPSCanonicalForm\", \"[\", StyleBox[\"mps\", \"TI\"], \
\"]\"}]\) transforms \!\(\*StyleBox[\"mps\", \"TI\"]\) into left-canonical \
form. \[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalForm\", \"[\", \
RowBox[{StyleBox[\"mps\", \"TI\"], \",\", \"\\\"Left\\\"\"}], \"]\"}]\) puts \
every tensor in left-isometric form where \!\(\*RowBox[{SuperscriptBox[\"A\", \
\"\[Dagger]\"], \".\", \"A\", \"=\", \"I\"}]\). \
\[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalForm\", \"[\", \
RowBox[{StyleBox[\"mps\", \"TI\"], \",\", \"\\\"Right\\\"\"}], \"]\"}]\) puts \
every tensor in right-isometric form where \!\(\*RowBox[{\"A\", \".\", \
SuperscriptBox[\"A\", \"\[Dagger]\"], \"=\", \"I\"}]\). \
\[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalForm\", \"[\", \
RowBox[{StyleBox[\"mps\", \"TI\"], \",\", RowBox[{\"{\", \
RowBox[{\"\\\"Mixed\\\"\", \",\", StyleBox[\"k\", \"TI\"]}], \"}\"}]}], \
\"]\"}]\) puts \!\(\*StyleBox[\"mps\", \"TI\"]\) in mixed canonical form with \
the orthogonality center at site \!\(\*StyleBox[\"k\", \"TI\"]\)."



MPSCanonicalQ::usage = "\!\(\*RowBox[{\"MPSCanonicalQ\", \"[\", RowBox[{StyleBox[\"mps\", \"TI\"], \
\",\", \"\\\"Left\\\"\"}], \"]\"}]\) returns True if every tensor of \
\!\(\*StyleBox[\"mps\", \"TI\"]\) except the last is left-isometric. \
\[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalQ\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", \"\\\"Right\\\"\"}], \"]\"}]\) returns True if every tensor \
of \!\(\*StyleBox[\"mps\", \"TI\"]\) except the first is right-isometric. \
\[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalQ\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", RowBox[{\"{\", RowBox[{\"\\\"Mixed\\\"\", \",\", \
StyleBox[\"k\", \"TI\"]}], \"}\"}]}], \"]\"}]\) returns True if sites before \
\!\(\*StyleBox[\"k\", \"TI\"]\) are left-isometric and sites after \
\!\(\*StyleBox[\"k\", \"TI\"]\) are right-isometric. \
\[Bullet]\n\!\(\*RowBox[{\"MPSCanonicalQ\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", StyleBox[\"form\", \"TI\"], \",\", StyleBox[\"tol\", \
\"TI\"]}], \"]\"}]\) uses Frobenius-norm tolerance \!\(\*StyleBox[\"tol\", \
\"TI\"]\) when comparing each Gram matrix to the identity."



MPSEntanglementEntropy::usage = "\!\(\*RowBox[{\"MPSEntanglementEntropy\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", StyleBox[\"site\", \"TI\"]}], \"]\"}]\) computes the von \
Neumann entanglement entropy at the bond between \!\(\*StyleBox[\"site\", \
\"TI\"]\) and \!\(\*StyleBox[\"site\", \"TI\"]\)+1."



MPSNormalize::usage = "\!\(\*RowBox[{\"MPSNormalize\", \"[\", StyleBox[\"mps\", \"TI\"], \"]\"}]\) \
rescales the MPS \!\(\*StyleBox[\"mps\", \"TI\"]\) to unit norm by dividing \
every tensor by \!\(\*RowBox[{\"MPSNorm\", \"[\", StyleBox[\"mps\", \"TI\"], \
\"]\"}]\)\!\(\*SuperscriptBox[\"\", RowBox[{\"1\", \"/\", StyleBox[\"n\", \
\"TI\"]}]]\)."



MPSNorm::usage = "\!\(\*RowBox[{\"MPSNorm\", \"[\", StyleBox[\"mps\", \"TI\"], \"]\"}]\) \
computes the norm \!\(\*RowBox[{\"\[LeftDoubleBracketingBar]\", \"\[Psi]\", \
\"\[RightDoubleBracketingBar]\"}]\) of a matrix-product state."



MPSOverlap::usage = "\!\(\*RowBox[{\"MPSOverlap\", \"[\", RowBox[{SubscriptBox[StyleBox[\"mps\", \
\"TI\"], \"1\"], \",\", SubscriptBox[StyleBox[\"mps\", \"TI\"], \"2\"]}], \
\"]\"}]\) computes the inner product \!\(\*RowBox[{\"\[LeftAngleBracket]\", \
SubscriptBox[\"\[Psi]\", \"1\"], \"|\", SubscriptBox[\"\[Psi]\", \"2\"], \
\"\[RightAngleBracket]\"}]\) between two matrix-product states. \
\[Bullet]\n\!\(\*RowBox[{\"MPSOverlap\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", StyleBox[\"mps\", \"TI\"]}], \"]\"}]\) returns the squared \
norm \!\(\*RowBox[{SuperscriptBox[RowBox[{\"\[LeftDoubleBracketingBar]\", \
\"\[Psi]\", \"\[RightDoubleBracketingBar]\"}], \"2\"], \"=\", \
RowBox[{\"\[LeftAngleBracket]\", \"\[Psi]\", \"|\", \"\[Psi]\", \
\"\[RightAngleBracket]\"}]}]\)."



MPSSchmidtValues::usage = "\!\(\*RowBox[{\"MPSSchmidtValues\", \"[\", RowBox[{StyleBox[\"mps\", \
\"TI\"], \",\", StyleBox[\"site\", \"TI\"]}], \"]\"}]\) returns the \
normalized Schmidt coefficients \!\(\*SubscriptBox[\"\[Lambda]\", \
StyleBox[\"i\", \"TI\"]]\) at the bond between \!\(\*StyleBox[\"site\", \
\"TI\"]\) and \!\(\*RowBox[{StyleBox[\"site\", \"TI\"], \"+\", \"1\"}]\)."



MPSTruncate::usage = "\!\(\*RowBox[{\"MPSTruncate\", \"[\", RowBox[{StyleBox[\"mps\", \"TI\"], \
\",\", StyleBox[\"maxBond\", \"TI\"]}], \"]\"}]\) compresses an MPS by \
truncating every bond to at most \!\(\*StyleBox[\"maxBond\", \"TI\"]\) \
singular values. \[Bullet]\n\!\(\*RowBox[{\"MPSTruncate\", \"[\", \
RowBox[{StyleBox[\"mps\", \"TI\"], \",\", StyleBox[\"maxBond\", \"TI\"], \
\",\", RowBox[{\"\\\"Normalize\\\"\", \"->\", \"False\"}]}], \"]\"}]\) \
returns the compressed MPS without rescaling to unit norm."



OptimalContractionPath::usage = "\!\(\*RowBox[{\"OptimalContractionPath\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) finds an optimal contraction path through the TensorNetwork \
\!\(\*StyleBox[\"tn\", \"TI\"]\) by dynamic-programming \
search.\n\!\(\*RowBox[{\"OptimalContractionPath\", \"[\", StyleBox[\"graph\", \
\"TI\"], \"]\"}]\) works directly on a tensor-network Graph \
\!\(\*StyleBox[\"graph\", \
\"TI\"]\).\n\!\(\*RowBox[{\"OptimalContractionPath\", \"[\", \
StyleBox[\"data\", \"TI\"], \"]\"}]\) accepts the low-level Association \
\!\(\*StyleBox[\"data\", \"TI\"]\) with keys \
\!\(\*StyleBox[\"\\\"Dimensions\\\"\", ShowStringCharacters -> True]\), \
\!\(\*StyleBox[\"\\\"Indices\\\"\", ShowStringCharacters -> True]\), and \
\!\(\*StyleBox[\"\\\"Contractions\\\"\", ShowStringCharacters -> \
True]\).\n\!\(\*RowBox[{\"OptimalContractionPath\", \"[\", StyleBox[\"expr\", \
\"TI\"], \"]\"}]\) finds a path for an Inactive TensorContract over a \
TensorProduct, optionally wrapped in Transpose with a Cycles permutation."



PathIndexContractions::usage = "\!\(\*RowBox[{\"PathIndexContractions\", \"[\", RowBox[{StyleBox[\"path\", \
\"TI\"], \",\", StyleBox[\"indices\", \"TI\"]}], \"]\"}]\) returns the \
sequence of index sets contracted at each step of \!\(\*StyleBox[\"path\", \
\"TI\"]\), given the per-tensor index lists \!\(\*StyleBox[\"indices\", \
\"TI\"]\).\n\!\(\*RowBox[{\"PathIndexContractions\", \"[\", \
RowBox[{StyleBox[\"path\", \"TI\"], \",\", StyleBox[\"indices\", \"TI\"], \
\",\", StyleBox[\"contractions\", \"TI\"]}], \"]\"}]\) returns the symbolic \
index sums at each step, mapping the integer positions in \
\!\(\*StyleBox[\"indices\", \"TI\"]\) back to the labels in \
\!\(\*StyleBox[\"contractions\", \
\"TI\"]\).\n\!\(\*RowBox[{\"PathIndexContractions\", \"[\", \
RowBox[{StyleBox[\"path\", \"TI\"], \",\", StyleBox[\"data\", \"TI\"]}], \
\"]\"}]\) takes an association with keys \"Indices\" and \"Contractions\", \
such as \!\(\*RowBox[{StyleBox[\"tn\", \"TI\"], \"[\", \"\\\"Data\\\"\", \
\"]\"}]\)."



PathQ::usage = "\!\(\*RowBox[{\"PathQ\", \"[\", StyleBox[\"path\", \"TI\"], \"]\"}]\) yields \
True if \!\(\*StyleBox[\"path\", \"TI\"]\) is a list whose elements are \
either \!\(\*RowBox[{\"{\", StyleBox[\"i\", \"TI\"], \"}\"}]\) (singleton) or \
\!\(\*RowBox[{\"{\", RowBox[{StyleBox[\"i\", \"TI\"], \",\", StyleBox[\"j\", \
\"TI\"]}], \"}\"}]\) (pair) integer lists, and False otherwise."



PathToTreePath::usage = "\!\(\*RowBox[{\"PathToTreePath\", \"[\", StyleBox[\"path\", \"TI\"], \
\"]\"}]\) converts a linear pairwise contraction \!\(\*StyleBox[\"path\", \
\"TI\"]\) to a nested tree-form path with auto-derived integer \
leaves.\n\!\(\*RowBox[{\"PathToTreePath\", \"[\", RowBox[{StyleBox[\"path\", \
\"TI\"], \",\", StyleBox[\"indices\", \"TI\"]}], \"]\"}]\) uses the explicit \
list \!\(\*StyleBox[\"indices\", \"TI\"]\) as the leaf labels."



RandomTensorNetwork::usage = "\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", RowBox[{RowBox[{\"{\", \
RowBox[{StyleBox[\"n\", \"TI\"], \",\", StyleBox[\"m\", \"TI\"]}], \"}\"}], \
\",\", StyleBox[\"maxDim\", \"TI\"]}], \"]\"}]\) creates a random tensor \
network with graph \!\(\*RowBox[{\"RandomGraph\", \"[\", RowBox[{\"{\", \
RowBox[{StyleBox[\"n\", \"TI\"], \",\", StyleBox[\"m\", \"TI\"]}], \"}\"}], \
\"]\"}]\) and bond dimensions up to \!\(\*StyleBox[\"maxDim\", \
\"TI\"]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"maxDim\", \"TI\"]}], \
\"]\"}]\) uses an arbitrary \!\(\*StyleBox[\"graph\", \"TI\"]\) and samples \
each bond dimension from \!\(\*RowBox[{\"{\", RowBox[{\"2\", \",\", \
StyleBox[\"maxDim\", \"TI\"]}], \
\"}\"}]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", RowBox[{\"{\", StyleBox[\"dim\", \
\"TI\"], \"}\"}]}], \"]\"}]\) makes every bond dimension exactly \
\!\(\*StyleBox[\"dim\", \"TI\"]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \
\"[\", RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"dim\", \"TI\"], \
\",\", StyleBox[\"r\", \"TI\"]}], \"]\"}]\) adds up to \!\(\*StyleBox[\"r\", \
\"TI\"]\) free legs per vertex on top of its \
degree.\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{\"\\\"MPS\\\"\", \"[\", RowBox[{StyleBox[\"n\", \"TI\"], \",\", \
StyleBox[\"\[Chi]\", \"TI\"], \",\", StyleBox[\"d\", \"TI\"]}], \"]\"}], \
\"]\"}]\) creates a random Matrix Product State of length \
\!\(\*StyleBox[\"n\", \"TI\"]\), bond dimension \!\(\*StyleBox[\"\[Chi]\", \
\"TI\"]\) and physical dimension \!\(\*StyleBox[\"d\", \
\"TI\"]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{\"\\\"TT\\\"\", \"[\", RowBox[{StyleBox[\"n\", \"TI\"], \",\", \
StyleBox[\"\[Chi]\", \"TI\"]}], \"]\"}], \"]\"}]\) creates a Tensor Train of \
length \!\(\*StyleBox[\"n\", \"TI\"]\) and bond dimension \
\!\(\*StyleBox[\"\[Chi]\", \"TI\"]\) (no physical \
legs).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{\"\\\"MPO\\\"\", \"[\", RowBox[{StyleBox[\"n\", \"TI\"], \",\", \
StyleBox[\"\[Chi]\", \"TI\"], \",\", StyleBox[\"d\", \"TI\"]}], \"]\"}], \
\"]\"}]\) creates a random Matrix Product Operator of length \
\!\(\*StyleBox[\"n\", \"TI\"]\) with bond dimension \
\!\(\*StyleBox[\"\[Chi]\", \"TI\"]\) and physical dimension \
\!\(\*StyleBox[\"d\", \"TI\"]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \
\"[\", RowBox[{\"\\\"PEPS\\\"\", \"[\", RowBox[{RowBox[{\"{\", \
RowBox[{StyleBox[\"rows\", \"TI\"], \",\", StyleBox[\"cols\", \"TI\"]}], \
\"}\"}], \",\", StyleBox[\"\[Chi]\", \"TI\"], \",\", StyleBox[\"d\", \
\"TI\"]}], \"]\"}], \"]\"}]\) creates a Projected Entangled Pair State on a \
\!\(\*RowBox[{StyleBox[\"rows\", \"TI\"], \"\[Times]\", StyleBox[\"cols\", \
\"TI\"]}]\) grid.\n\!\(\*RowBox[{\"RandomTensorNetwork\", \"[\", \
RowBox[{\"\\\"TTN\\\"\", \"[\", RowBox[{StyleBox[\"depth\", \"TI\"], \",\", \
StyleBox[\"\[Chi]\", \"TI\"], \",\", StyleBox[\"b\", \"TI\"]}], \"]\"}], \
\"]\"}]\) creates a Tree Tensor Network of binary depth \
\!\(\*StyleBox[\"depth\", \"TI\"]\) with branching factor \
\!\(\*StyleBox[\"b\", \"TI\"]\).\n\!\(\*RowBox[{\"RandomTensorNetwork\", \
\"[\", RowBox[{\"\\\"MERA\\\"\", \"[\", RowBox[{StyleBox[\"w\", \"TI\"], \
\",\", StyleBox[\"\[Chi]\", \"TI\"], \",\", StyleBox[\"L\", \"TI\"]}], \
\"]\"}], \"]\"}]\) creates a Multi-scale Entanglement Renormalization Ansatz \
of width \!\(\*StyleBox[\"w\", \"TI\"]\) and \!\(\*StyleBox[\"L\", \"TI\"]\) \
coarse-graining layers."



SparseTensorNetwork::usage = "\!\(\*RowBox[{\"SparseTensorNetwork\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns a tensor network with every rank-\!\(\*RowBox[{\">\", \" \
\", \"0\"}]\) tensor of \!\(\*StyleBox[\"tn\", \"TI\"]\) converted to a \
SparseArray."



TensorNetworkAdd::usage = "\!\(\*RowBox[{\"TensorNetworkAdd\", \"[\", RowBox[{StyleBox[\"tn\", \"TI\"], \
\",\", StyleBox[\"tensor\", \"TI\"], \",\", StyleBox[\"indices\", \"TI\"]}], \
\"]\"}]\) appends \!\(\*StyleBox[\"tensor\", \"TI\"]\) to the tensor network \
\!\(\*StyleBox[\"tn\", \"TI\"]\) with the given hyperedge \
\!\(\*StyleBox[\"indices\", \"TI\"]\). \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkAdd\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"tensor\", \"TI\"], \
\",\", StyleBox[\"index\", \"TI\"]}], \"]\"}]\) appends \
\!\(\*StyleBox[\"tensor\", \"TI\"]\) to a ToTensorNetworkGraph annotated \
graph, connecting it at \!\(\*StyleBox[\"index\", \"TI\"]\). \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkAdd\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", RowBox[{\"Labeled\", \"[\", \
RowBox[{StyleBox[\"tensor\", \"TI\"], \",\", StyleBox[\"label\", \"TI\"]}], \
\"]\"}], \",\", StyleBox[\"index\", \"TI\"]}], \"]\"}]\) attaches a vertex \
\!\(\*StyleBox[\"label\", \"TI\"]\) in the Graph form. \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkAdd\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"tensor\", \"TI\"]}], \
\"]\"}]\) selects indices automatically from the current free indices of \
\!\(\*StyleBox[\"graph\", \"TI\"]\)."



TensorNetworkContractions::usage = "\!\(\*RowBox[{\"TensorNetworkContractions\", \"[\", StyleBox[\"tn\", \
\"TI\"], \"]\"}]\) returns the list of index contractions in the tensor \
network \!\(\*StyleBox[\"tn\", \"TI\"]\), with each shared index replaced by \
the canonical list of its per-tensor labeled occurrences."



TensorNetworkContraction::usage = "\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns an inactive contraction expression for the tensor network \
using an auto-selected path \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", StyleBox[\"path\", \"TI\"]}], \
\"]\"}]\) uses the explicit canonical contraction path \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", StyleBox[\"treePath\", \"TI\"]}], \
\"]\"}]\) uses a tree-structured contraction path \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", \"\\\"Greedy\\\"\"}], \"]\"}]\) \
auto-computes a greedy contraction path \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", StyleBox[\"method\", \"TI\"]}], \
\"]\"}]\) uses method-string \"Optimal\", \"flops\", \"max\", \"size\", \
\"write\", \"combo\", or \"limit\" \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
StyleBox[\"graph\", \"TI\"], \"]\"}]\) operates on a tensor-network Graph \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkContraction\", \"[\", \
StyleBox[\"data\", \"TI\"], \"]\"}]\) accepts the low-level Association of \
network data"



TensorNetworkContract::usage = "\!\(\*RowBox[{\"TensorNetworkContract\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) contracts the entire tensor network \!\(\*StyleBox[\"tn\", \
\"TI\"]\) to a single tensor.\n\!\(\*RowBox[{\"TensorNetworkContract\", \
\"[\", RowBox[{StyleBox[\"tn\", \"TI\"], \",\", StyleBox[\"path\", \"TI\"]}], \
\"]\"}]\) uses the explicit canonical contraction \!\(\*StyleBox[\"path\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetworkContract\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", StyleBox[\"\\\"method\\\"\", \
\"TI\"]}], \"]\"}]\) dispatches to GreedyContractionPath or \
OptimalContractionPath using the named cost \
function.\n\!\(\*RowBox[{\"TensorNetworkContract\", \"[\", \
StyleBox[\"graph\", \"TI\"], \"]\"}]\) works directly on a tensor-network \
Graph \!\(\*StyleBox[\"graph\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetworkContract\", \"[\", \
StyleBox[\"data\", \"TI\"], \"]\"}]\) accepts the low-level Association \
\!\(\*StyleBox[\"data\", \"TI\"]\) produced by TensorNetworkData."



TensorNetworkData::usage = "\!\(\*RowBox[{\"TensorNetworkData\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns an Association containing the complete data of the tensor \
network \!\(\*StyleBox[\"tn\", \"TI\"]\): its tensors, dimensions, indices, \
vertices, bonds, contractions, and free indices."



TensorNetworkDelete::usage = "\!\(\*RowBox[{\"TensorNetworkDelete\", \"[\", RowBox[{StyleBox[\"tn\", \
\"TI\"], \",\", StyleBox[\"k\", \"TI\"]}], \"]\"}]\) removes the \
\!\(\*StyleBox[\"k\", \"TI\"]\)th tensor from the tensor network \
\!\(\*StyleBox[\"tn\", \"TI\"]\). \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkDelete\", \"[\", StyleBox[\"tn\", \
\"TI\"], \"]\"}]\) removes the last tensor (default \
\!\(\*RowBox[{StyleBox[\"k\", \"TI\"], \"=\", RowBox[{\"-\", \"1\"}]}]\)). \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkDelete\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"k\", \"TI\"]}], \
\"]\"}]\) operates on the annotated \!\(\*StyleBox[\"graph\", \"TI\"]\) form, \
removing the \!\(\*StyleBox[\"k\", \"TI\"]\)th vertex and its incident \
edges."



TensorNetworkFindContractionPath::usage = "\!\(\*RowBox[{\"TensorNetworkFindContractionPath\", \"[\", StyleBox[\"tn\", \
\"TI\"], \"]\"}]\) is deprecated; forwards to OptimalContractionPath. \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkFindContractionPath\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", RowBox[{\"Method\", \"\[Rule]\", \
StyleBox[\"m\", \"TI\"]}]}], \"]\"}]\) selects the path-finder by Method m. \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetworkFindContractionPath\", \"[\", \
RowBox[{StyleBox[\"tn\", \"TI\"], \",\", \
RowBox[{\"\\\"ReturnParameters\\\"\", \"\[Rule]\", \"True\"}]}], \"]\"}]\) \
returns the internal parameter-extraction result instead of a path."



TensorNetworkFreeIndices::usage = "\!\(\*RowBox[{\"TensorNetworkFreeIndices\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns the list of uncontracted (free) indices of the tensor \
network \!\(\*StyleBox[\"tn\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetworkFreeIndices\", \"[\", \
StyleBox[\"indices\", \"TI\"], \"]\"}]\) returns the free indices for a list \
of per-tensor index lists.\n\!\(\*RowBox[{\"TensorNetworkFreeIndices\", \
\"[\", StyleBox[\"net\", \"TI\"], \"]\"}]\) returns the free indices of the \
graph form \!\(\*StyleBox[\"net\", \"TI\"]\)."



TensorNetworkGraphData::usage = "\!\(\*RowBox[{\"TensorNetworkGraphData\", \"[\", StyleBox[\"graph\", \
\"TI\"], \"]\"}]\) returns an Association containing the data of the \
annotated tensor-network graph \!\(\*StyleBox[\"graph\", \"TI\"]\): its \
tensors, dimensions, indices, vertices, free indices, bonds, and \
contractions."



TensorNetworkGraphQ::usage = "\!\(\*RowBox[{\"TensorNetworkGraphQ\", \"[\", StyleBox[\"graph\", \"TI\"], \
\"]\"}]\) yields True if \!\(\*StyleBox[\"graph\", \"TI\"]\) is a valid \
annotated tensor-network graph, and False \
otherwise.\n\!\(\*RowBox[{\"TensorNetworkGraphQ\", \"[\", StyleBox[\"graph\", \
\"TI\"], \",\", Cell[BoxData[ButtonBox[\"True\", BaseStyle -> \"Link\", \
ButtonData -> \"paclet:ref/True\"]], \"InlineFormula\", ExpressionUUID -> \
\"f8073905-6e51-4581-b35d-5f81569553de\"], \"]\"}]\) prints diagnostic \
messages when \!\(\*StyleBox[\"graph\", \"TI\"]\) fails \
validation.\n\!\(\*RowBox[{\"TensorNetworkGraphQ\", \"[\", \
Cell[BoxData[ButtonBox[\"True\", BaseStyle -> \"Link\", ButtonData -> \
\"paclet:ref/True\"]], \"InlineFormula\", ExpressionUUID -> \
\"d9902fa8-e6c1-42cc-9c67-692d14d80851\"], \"]\"}]\) is the curried form: it \
returns a predicate that, applied to a graph, runs the verbose check."



TensorNetworkIndexDimensions::usage = "\!\(\*RowBox[{\"TensorNetworkIndexDimensions\", \"[\", StyleBox[\"tn\", \
\"TI\"], \"]\"}]\) returns the list of \!\(\*RowBox[{StyleBox[\"index\", \
\"TI\"], \"\[Rule]\", StyleBox[\"dimension\", \"TI\"]}]\) rules for every \
index occurrence in the tensor network \!\(\*StyleBox[\"tn\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetworkIndexDimensions\", \"[\", \
RowBox[{StyleBox[\"indices\", \"TI\"], \",\", StyleBox[\"tensors\", \
\"TI\"]}], \"]\"}]\) computes the rules from an explicit list of per-tensor \
index lists and an explicit list of \
tensors.\n\!\(\*RowBox[{\"TensorNetworkIndexDimensions\", \"[\", \
StyleBox[\"net\", \"TI\"], \"]\"}]\) returns the index-dimension rules of the \
graph form \!\(\*StyleBox[\"net\", \"TI\"]\)."



TensorNetworkIndexGraph::usage = "\!\(\*RowBox[{\"TensorNetworkIndexGraph\", \"[\", StyleBox[\"graph\", \
\"TI\"], \"]\"}]\) returns a Graph whose vertices are the individual indices \
of the tensor-network graph \!\(\*StyleBox[\"graph\", \"TI\"]\) and whose \
edges encode both contractions between tensors and co-occurrence of indices \
within each tensor."



TensorNetworkIndices::usage = "\!\(\*RowBox[{\"TensorNetworkIndices\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns the per-tensor index specifications for the tensor network \
\!\(\*StyleBox[\"tn\", \"TI\"]\), with each index labeled \
\!\(\*RowBox[{\"Superscript\", \"[\", RowBox[{StyleBox[\"v\", \"TI\"], \",\", \
StyleBox[\"k\", \"TI\"]}], \"]\"}]\) where \!\(\*StyleBox[\"v\", \"TI\"]\) is \
the 1-based tensor position and \!\(\*StyleBox[\"k\", \"TI\"]\) is the local \
slot identifier from the hyperedge \
specification.\n\!\(\*RowBox[{\"TensorNetworkIndices\", \"[\", \
StyleBox[\"net\", \"TI\"], \"]\"}]\) returns the per-vertex index lists \
annotated on the graph form \!\(\*StyleBox[\"net\", \"TI\"]\) produced by \
ToTensorNetworkGraph."



TensorNetworkQ::usage = "\!\(\*RowBox[{\"TensorNetworkQ\", \"[\", StyleBox[\"tn\", \"TI\"], \"]\"}]\) \
yields True if \!\(\*StyleBox[\"tn\", \"TI\"]\) is a valid TensorNetwork \
object, and False otherwise."



TensorNetworkRemoveCycles::usage = "\!\(\*RowBox[{\"TensorNetworkRemoveCycles\", \"[\", StyleBox[\"graph\", \
\"TI\"], \"]\"}]\) returns an acyclic Graph by inserting one cup/cap pair of \
identity tensors for each cycle in the directed input \
\!\(\*StyleBox[\"graph\", \"TI\"]\)."



TensorNetworkReplaceIndices::usage = "\!\(\*RowBox[{\"TensorNetworkReplaceIndices\", \"[\", \
RowBox[{StyleBox[\"graph\", \"TI\"], \",\", StyleBox[\"rules\", \"TI\"]}], \
\"]\"}]\) returns a tensor-network Graph whose \"Index\" annotations have \
been rewritten by applying \!\(\*StyleBox[\"rules\", \"TI\"]\) to every \
per-vertex index list."



TensorNetworkSize::usage = "\!\(\*RowBox[{\"TensorNetworkSize\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns the number of tensors in the network \!\(\*StyleBox[\"tn\", \
\"TI\"]\)."



TensorNetworkTensors::usage = "\!\(\*RowBox[{\"TensorNetworkTensors\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) returns the list of tensors stored in \!\(\*StyleBox[\"tn\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetworkTensors\", \"[\", StyleBox[\"net\", \
\"TI\"], \"]\"}]\) gives the list of tensors stored as \"Tensor\" annotations \
on the vertices of the tensor-network graph \!\(\*StyleBox[\"net\", \
\"TI\"]\)."



TensorNetworkToNetGraph::usage = "\!\(\*RowBox[{\"TensorNetworkToNetGraph\", \"[\", StyleBox[\"net\", \"TI\"], \
\"]\"}]\) converts the tensor-network graph \!\(\*StyleBox[\"net\", \"TI\"]\) \
into a Wolfram Neural NetGraph, using OptimalContractionPath to choose the \
contraction order.\n\!\(\*RowBox[{\"TensorNetworkToNetGraph\", \"[\", \
RowBox[{StyleBox[\"net\", \"TI\"], \",\", StyleBox[\"path\", \"TI\"]}], \
\"]\"}]\) uses the explicit contraction \!\(\*StyleBox[\"path\", \"TI\"]\)."



TensorNetwork::usage = "\!\(\*RowBox[{\"TensorNetwork\", \"[\", RowBox[{RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"A\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"A\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}], \",\", RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"h\", \"TI\"], \
\"1\"], \",\", SubscriptBox[StyleBox[\"h\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}]}], \"]\"}]\) creates a tensor network from tensors \
\!\(\*SubscriptBox[StyleBox[\"A\", \"TI\"], StyleBox[\"i\", \"TI\"]]\) and \
hyperedge index lists \!\(\*SubscriptBox[StyleBox[\"h\", \"TI\"], \
StyleBox[\"i\", \"TI\"]]\); repeated indices in the \
\!\(\*SubscriptBox[StyleBox[\"h\", \"TI\"], StyleBox[\"i\", \"TI\"]]\) denote \
contractions.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{StyleBox[\"tensors\", \"TI\"], \",\", StyleBox[\"hyperedges\", \
\"TI\"], \",\", StyleBox[\"output\", \"TI\"]}], \"]\"}]\) fixes the order of \
free indices in the contracted result to \!\(\*StyleBox[\"output\", \
\"TI\"]\).\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{StyleBox[\"tensors\", \"TI\"], \",\", RowBox[{StyleBox[\"in\", \
\"TI\"], \"\[Rule]\", StyleBox[\"out\", \"TI\"]}]}], \"]\"}]\) uses \
Einstein-summation rule syntax.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{StyleBox[\"tensors\", \"TI\"], \",\", StyleBox[\"indices\", \"TI\"], \
\",\", StyleBox[\"perm\", \"TI\"]}], \"]\"}]\) with a Cycles permutation \
\!\(\*StyleBox[\"perm\", \"TI\"]\) permutes the derived free \
indices.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", StyleBox[\"hyperedges\", \
\"TI\"], \"]\"}]\) builds a symbolic network with one ArraySymbol tensor per \
hyperedge.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{StyleBox[\"hyperedges\", \"TI\"], \"\[Rule]\", StyleBox[\"output\", \
\"TI\"]}], \"]\"}]\) builds a symbolic network with explicit output index \
list.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{RowBox[{StyleBox[\"hyperedges\", \"TI\"], \"\[Rule]\", \
StyleBox[\"output\", \"TI\"]}], \",\", StyleBox[\"dims\", \"TI\"]}], \
\"]\"}]\) with an Association \!\(\*StyleBox[\"dims\", \"TI\"]\) of \
index\[Rule]dimension entries fixes the dimensions of symbolic tensors. \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{RowBox[{StyleBox[\"hyperedges\", \"TI\"], \"\[Rule]\", \
StyleBox[\"output\", \"TI\"]}], \",\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"d\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"d\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}]}], \"]\"}]\) with a positional list of dimensions for the union of \
indices.\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", StyleBox[\"expr\", \"TI\"], \
\"]\"}]\) constructs a network from an Inactive TensorContract over a \
TensorProduct. \[Bullet]\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", \
RowBox[{\"Transpose\", \"[\", RowBox[{StyleBox[\"expr\", \"TI\"], \",\", \
StyleBox[\"perm\", \"TI\"]}], \"]\"}], \"]\"}]\) wraps a Transpose of an \
inactive contraction so the output index order follows \
\!\(\*StyleBox[\"perm\", \"TI\"]\). \
\[Bullet]\n\!\(\*RowBox[{\"TensorNetwork\", \"[\", StyleBox[\"graph\", \
\"TI\"], \"]\"}]\) reconstructs a network from a tensor-network Graph \
produced by ToTensorNetworkGraph."



ToTensorNetworkGraph::usage = "\!\(\*RowBox[{\"ToTensorNetworkGraph\", \"[\", StyleBox[\"tn\", \"TI\"], \
\"]\"}]\) converts the tensor network \!\(\*StyleBox[\"tn\", \"TI\"]\) into \
an annotated, directed-acyclic Graph. \
\[Bullet]\n\!\(\*RowBox[{\"ToTensorNetworkGraph\", \"[\", StyleBox[\"g\", \
\"TI\"], \"]\"}]\) builds a tensor-network graph from the graph \
\!\(\*StyleBox[\"g\", \"TI\"]\), first making it directed and acyclic if \
necessary. \[Bullet]\n\!\(\*RowBox[{\"ToTensorNetworkGraph\", \"[\", \
StyleBox[\"tensors\", \"TI\"], \",\", StyleBox[\"hyperedges\", \"TI\"], \
\"]\"}]\) constructs a tensor-network graph directly from a list of \
\!\(\*StyleBox[\"tensors\", \"TI\"]\) and an associated list of \
\!\(\*StyleBox[\"hyperedges\", \"TI\"]\) (per-tensor index lists), inserting \
spider tensors for any index shared by three or more tensors."



TreePathQ::usage = "\!\(\*RowBox[{\"TreePathQ\", \"[\", StyleBox[\"treePath\", \"TI\"], \
\"]\"}]\)  yields True if StyleBox[\"treePath\", \"TI\"] is a valid tree-form \
contraction path \[LongDash] a nested list whose non-leaf nodes recursively \
decompose into \!\(\*RowBox[{\"TreePathQ\", \"[\", StyleBox[\"_\", \"TI\"], \
\"]\"}]\) children, and False otherwise."



TreePathToPath::usage = "\!\(\*RowBox[{\"TreePathToPath\", \"[\", StyleBox[\"treePath\", \"TI\"], \
\"]\"}]\) converts the tree-structured contraction \
\!\(\*StyleBox[\"treePath\", \"TI\"]\) to a linear (pairwise) path \
representation.\n\!\(\*RowBox[{\"TreePathToPath\", \"[\", \
RowBox[{StyleBox[\"treePath\", \"TI\"], \",\", StyleBox[\"indices\", \
\"TI\"]}], \"]\"}]\) uses the explicit \!\(\*StyleBox[\"indices\", \"TI\"]\) \
list to label the tree's leaves."
