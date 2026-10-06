Package["Wolfram`TensorNetworks`IndexArray`"]



ArraySymmetry::usage = "\!\(\*RowBox[{\"ArraySymmetry\", \"[\", StyleBox[\"t\", \"TI\"], \"]\"}]\) \
returns the symmetry declaration (Symmetric[\[Ellipsis]], \
Antisymmetric[\[Ellipsis]] or ZeroSymmetric[\[Ellipsis]]) of t, or {} if \
there is none."



DimensionQ::usage = "\!\(\*RowBox[{\"DimensionQ\", \"[\", StyleBox[\"expr\", \"TI\"], \"]\"}]\) \
yields True if expr is a valid Dimension object, and False otherwise."



Dimension::usage = "\!\(\*RowBox[{\"Dimension\", \"[\", RowBox[{StyleBox[\"d\", \"TI\"], \",\", \
StyleBox[\"name\", \"TI\"]}], \"]\"}]\) represents a tensor index of size d \
with the given name. A negative size denotes a covariant (lower) index; \
positive denotes contravariant (upper). \
\[Bullet]\n\!\(\*RowBox[{\"Dimension\", \"[\", RowBox[{StyleBox[\"d\", \
\"TI\"], \",\", StyleBox[\"name\", \"TI\"], \",\", StyleBox[\"indices\", \
\"TI\"]}], \"]\"}]\) additionally records the explicit basis labels for the \
index. \[Bullet]\n\!\(\*RowBox[{\"Dimension\", \"[\", RowBox[{StyleBox[\"d\", \
\"TI\"], \",\", StyleBox[\"name\", \"TI\"], \",\", StyleBox[\"indices\", \
\"TI\"], \",\", StyleBox[\"pos\", \"TI\"]}], \"]\"}]\) marks the index as \
contracted at the specified position pos."



IndexArrayQ::usage = "\!\(\*RowBox[{\"IndexArrayQ\", \"[\", StyleBox[\"expr\", \"TI\"], \"]\"}]\) \
yields True if expr is a valid IndexArray, i.e. its tensor's dimensions match \
the declared Shape under any recorded assumptions."



IndexArray::usage = "\!\(\*RowBox[{\"IndexArray\", \"[\", StyleBox[\"tensor\", \"TI\"], \"]\"}]\) \
wraps tensor as an IndexArray with shape derived from \
ArrayDimensions[tensor]. \[Bullet]\n\!\(\*RowBox[{\"IndexArray\", \"[\", \
RowBox[{StyleBox[\"tensor\", \"TI\"], \",\", StyleBox[\"shape\", \"TI\"]}], \
\"]\"}]\) wraps tensor with the given Shape, recording named index structure \
and variance. \[Bullet]\n\!\(\*RowBox[{\"IndexArray\", \"[\", \
RowBox[{StyleBox[\"ia\", \"TI\"], \",\", StyleBox[\"shape\", \"TI\"]}], \
\"]\"}]\) returns the IndexArray ia with its Shape replaced."



IndexContract::usage = "\!\(\*RowBox[{\"IndexContract\", \"[\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"a\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"a\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}], \"]\"}]\) contracts every matching pair of free index names across \
the IndexArray or IndexTensor objects a\:1d62, returning a new IndexArray or \
IndexTensor.\n\!\(\*RowBox[{\"IndexContract\", \"[\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"a\", \"TI\"], \"1\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}], \",\", StyleBox[\"output\", \"TI\"], \"]\"}]\) \
forces the listed names to be the free indices of the result."



IndexJuggling::usage = "\!\(\*RowBox[{\"IndexJuggling\", \"[\", RowBox[{StyleBox[\"ia\", \"TI\"], \
\",\", RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"n\", \"TI\"], \"1\"], \
\",\", SubscriptBox[StyleBox[\"n\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}]}], \"]\"}]\) permutes and renames the indices of \
an IndexArray or IndexTensor so that its indices match the specified names."



IndexPart::usage = "\!\(\*RowBox[{\"IndexPart\", \"[\", RowBox[{StyleBox[\"ia\", \"TI\"], \",\", \
RowBox[{\"{\", RowBox[{SubscriptBox[StyleBox[\"i\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"i\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}]}], \"]\"}]\) extracts a sub-array of an IndexArray or IndexTensor at \
the given positions, where each i\:1d62 is an integer position, an index \
name, or All."



IndexTensorQ::usage = "\!\(\*RowBox[{\"IndexTensorQ\", \"[\", StyleBox[\"expr\", \"TI\"], \"]\"}]\) \
yields True if expr is a valid IndexTensor (an IndexArray together with \
optional metric tensors)."



IndexTensor::usage = "\!\(\*RowBox[{\"IndexTensor\", \"[\", StyleBox[\"ia\", \"TI\"], \"]\"}]\) \
wraps the IndexArray ia as an IndexTensor with no associated metrics. \
\[Bullet]\n\!\(\*RowBox[{\"IndexTensor\", \"[\", RowBox[{StyleBox[\"ia\", \
\"TI\"], \",\", StyleBox[\"metric\", \"TI\"]}], \"]\"}]\) attaches a metric \
to all free index positions, enabling automatic raising and lowering."



MetricTensorQ::usage = "\!\(\*RowBox[{\"MetricTensorQ\", \"[\", StyleBox[\"expr\", \"TI\"], \
\"]\"}]\) yields True if expr is a valid MetricTensor (a rank-2 IndexTensor \
flagged as a metric)."



MetricTensor::usage = "\!\(\*RowBox[{\"MetricTensor\", \"[\", StyleBox[\"name\", \"TI\"], \"]\"}]\) \
returns a built-in metric tensor by name, e.g. \"Euclidean\", \"Minkowski\", \
\"Schwarzschild\", \"Kerr\", \"FLRW\". \
\[Bullet]\n\!\(\*RowBox[{\"MetricTensor\", \"[\", \
RowBox[{StyleBox[\"matrix\", \"TI\"], \",\", StyleBox[\"coords\", \"TI\"]}], \
\"]\"}]\) constructs a metric from an explicit matrix and coordinate list. \
\[Bullet]\n\!\(\*RowBox[{\"MetricTensor\", \"[\", \"]\"}]\) returns the list \
of available built-in metric names."



ShapeQ::usage = "\!\(\*RowBox[{\"ShapeQ\", \"[\", StyleBox[\"expr\", \"TI\"], \"]\"}]\) \
yields True if expr is a valid Shape (a sequence of Dimension objects), and \
False otherwise."



Shape::usage = "\!\(\*RowBox[{\"Shape\", \"[\", RowBox[{SubscriptBox[StyleBox[\"d\", \
\"TI\"], \"1\"], \",\", SubscriptBox[StyleBox[\"d\", \"TI\"], \"2\"], \",\", \
\"\[Ellipsis]\"}], \"]\"}]\) represents an ordered sequence of Dimension \
objects describing the index structure of a tensor. \
\[Bullet]\n\!\(\*RowBox[{\"Shape\", \"[\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"d\", \"TI\"], \"1\"], \",\", \
SubscriptBox[StyleBox[\"d\", \"TI\"], \"2\"], \",\", \"\[Ellipsis]\"}], \
\"}\"}], \"]\"}]\) accepts a list of integer sizes or Dimension objects. \
\[Bullet]\n\!\(\*RowBox[{\"Shape\", \"[\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"d\", \"TI\"], \"1\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}], \",\", RowBox[{\"{\", \
RowBox[{SubscriptBox[StyleBox[\"n\", \"TI\"], \"1\"], \",\", \
\"\[Ellipsis]\"}], \"}\"}], \"]\"}]\) pairs integer sizes with index names; a \
negative name marks a lower index."
