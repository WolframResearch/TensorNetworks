(* ::Package:: *)

Package["Wolfram`TensorNetworks`IndexArray`"]

(* ============================================ *)
(* Dimension.wl                                *)
(* ============================================ *)

Dimension::usage = "Dimension[d, name] represents a single tensor index of size d with the given name.
\[Bullet] Dimension[d, name, indices] additionally records the explicit list of basis labels for the index.
\[Bullet] Dimension[d, name, indices, position] marks the index as contracted at the specified position.
\[Bullet] A negative size d denotes a covariant (lower) index; positive denotes contravariant (upper).
\[Bullet] Dimension[\[Ellipsis]][\"prop\"] retrieves a property such as \"Size\", \"Sign\", \"Name\", \"SignedDimension\", \"Lower\", \"Upper\", \"FreeQ\", or \"Symbol\"."

DimensionQ::usage = "DimensionQ[expr] yields True if expr is a valid Dimension object, and False otherwise."

(* ============================================ *)
(* Shape.wl                                    *)
(* ============================================ *)

Shape::usage = "Shape[d\:2081, d\:2082, \[Ellipsis]] represents an ordered sequence of Dimension objects describing a tensor's index structure.
\[Bullet] Shape[{d\:2081, d\:2082, \[Ellipsis]}] accepts a list of integer sizes or Dimension objects.
\[Bullet] Shape[{d\:2081, d\:2082, \[Ellipsis]}, {n\:2081, n\:2082, \[Ellipsis]}] pairs integer sizes with index names; a negative name marks a lower index.
\[Bullet] Shape[s, dims] re-sizes the dimensions of an existing Shape s.
\[Bullet] Shape[\[Ellipsis]][\"prop\"] retrieves \"Indices\", \"FreeIndices\", \"Dimensions\", \"SignedDimensions\", \"Rank\", \"Size\", \"Variance\", or \"Names\"."

ShapeQ::usage = "ShapeQ[expr] yields True if expr is a valid Shape (sequence of Dimension objects), and False otherwise."

(* ============================================ *)
(* ArrayUtilities.wl                           *)
(* ============================================ *)

ArrayDimensions::usage = "ArrayDimensions[t] returns the list of dimensions of a tensor t, tracking through Inactive[TensorContract], Inactive[TensorProduct], Inactive[Transpose], and Inactive[D].
\[Bullet] Returns {} for scalars and unrecognized expressions.
\[Bullet] Equivalent to TensorDimensions but robust on inactive tensor expressions."

ArrayRank::usage = "ArrayRank[t] returns Length[ArrayDimensions[t]], i.e. the number of indices of the tensor t."

ArraySymmetry::usage = "ArraySymmetry[t] returns the symmetry declaration (Symmetric[\[Ellipsis]], Antisymmetric[\[Ellipsis]], or ZeroSymmetric[\[Ellipsis]]) of t, or {} if none.
\[Bullet] Wraps TensorSymmetry, ignoring symmetries that are not pure index permutations."

ArrayName::usage = "ArrayName[t] returns the underlying symbol associated with t, or None.
\[Bullet] ArrayName[VectorSymbol[s, \[Ellipsis]]] returns s; same for MatrixSymbol and ArraySymbol.
\[Bullet] ArrayName[t] returns t itself when t is an atomic symbol."

ArrayPart::usage = "ArrayPart[t, {i\:2081, i\:2082, \[Ellipsis]}] extracts a sub-array of t at the given positions, propagating dimensional metadata for VectorSymbol, MatrixSymbol, and ArraySymbol.
\[Bullet] Use All for a position to keep that index free.
\[Bullet] Behaves like Part on numerical arrays."

ArrayTranspose::usage = "ArrayTranspose[t, perm] permutes the axes of t according to perm and simplifies the result.
\[Bullet] perm may be a list, a Cycles object, or m\[UndirectedEdge]n for a single swap.
\[Bullet] Composes nested transposes into a single permutation."

ArrayContract::usage = "ArrayContract[t, contractions] contracts pairs of indices in t and simplifies the result.
\[Bullet] ArrayContract[{t\:2081, t\:2082, \[Ellipsis]}, contractions] forms an Inactive[TensorProduct] of the tensors and then contracts.
\[Bullet] Returns {} if any input has a zero dimension."

SimplifyArray::usage = "SimplifyArray[expr] simplifies a nested array expression by removing empty contractions, identity transpositions, and singleton tensor products.
\[Bullet] Operates on Inactive[TensorContract], Inactive[Transpose], and Inactive[TensorProduct] subexpressions."

ZeroArrayQ::usage = "ZeroArrayQ[t] yields True if any dimension of t is zero, indicating an empty tensor."

(* ============================================ *)
(* IndexArray.wl                               *)
(* ============================================ *)

IndexArray::usage = "IndexArray[tensor, shape] wraps tensor with the given Shape, recording named index structure and variance.
\[Bullet] IndexArray[tensor] auto-derives the shape from ArrayDimensions[tensor].
\[Bullet] IndexArray[tensor, {b\:2081, b\:2082, \[Ellipsis]}] uses Boolean variance flags (True = upper, False = lower) per index.
\[Bullet] IndexArray[tensor, shape, parameters] additionally records the symbolic parameters tensor depends on.
\[Bullet] IndexArray[tensor, shape, parameters, assumptions] adds Assuming-style assumptions used when checking validity.
\[Bullet] IndexArray[tensor, shape, parameters, assumptions, name] sets the display name for the array.
\[Bullet] IndexArray[ia, shape] returns ia with its Shape replaced.
\[Bullet] IndexArray[\[Ellipsis]][\"prop\"] retrieves \"Array\", \"Tensor\", \"Shape\", \"Parameters\", \"Assumptions\", \"Name\", \"Dimension\", \"Symmetry\", \"Symbol\", \"Icon\", or any Shape property such as \"Dimensions\", \"Rank\", and \"FreeIndices\"."

IndexArrayQ::usage = "IndexArrayQ[expr] yields True if expr is a valid IndexArray, i.e. its tensor's dimensions match the declared Shape under the recorded assumptions."

(* ============================================ *)
(* IndexTensor.wl                              *)
(* ============================================ *)

IndexTensor::usage = "IndexTensor[ia] wraps an IndexArray ia as an IndexTensor with no associated metrics.
\[Bullet] IndexTensor[ia, metric] attaches a metric IndexArray to all free index positions, enabling automatic raising and lowering.
\[Bullet] IndexTensor[ia, {{i\:2081,\[Ellipsis]} \[Rule] g\:2081, {j\:2081,\[Ellipsis]} \[Rule] g\:2082, \[Ellipsis]}] attaches different metrics to specified groups of index positions.
\[Bullet] IndexTensor[g] declares ia as itself a metric tensor (rank-2, square dimensions of equal sign).
\[Bullet] IndexTensor[expr, args\[Ellipsis]] builds an IndexArray from expr with args and wraps it as an IndexTensor.
\[Bullet] IndexTensor[\[Ellipsis]][\"prop\"] retrieves \"IndexArray\", \"Metrics\", \"MetricRules\", \"MetricQ\", \"ChristoffelSymbol\", or any IndexArray property."

IndexTensorQ::usage = "IndexTensorQ[expr] yields True if expr is a valid IndexTensor, i.e. its inner IndexArray is valid and any attached metrics are rank-2 with dimensions matching the relevant free indices."

(* ============================================ *)
(* IndexJuggling.wl                            *)
(* ============================================ *)

IndexPart::usage = "IndexPart[ia, {i\:2081, i\:2082, \[Ellipsis]}] extracts a sub-array of an IndexArray or IndexTensor at the given positions, where each i\:1d62 is an integer position, an index name, or All.
\[Bullet] String or symbolic positions are matched against the index names of ia.
\[Bullet] A negative integer name lowers the index; a positive name raises it.
\[Bullet] Triggered by ia[[i\:2081, i\:2082, \[Ellipsis]]] on IndexArray and IndexTensor."

IndexContract::usage = "IndexContract[{a\:2081, a\:2082, \[Ellipsis]}] contracts every matching pair of free index names across the IndexArray or IndexTensor objects a\:1d62, returning the result as a new IndexArray or IndexTensor.
\[Bullet] IndexContract[{a\:2081, a\:2082, \[Ellipsis]}, output] forces the listed names to be the free indices of the result.
\[Bullet] IndexContract[a] contracts within a single tensor.
\[Bullet] IndexContract[arrays, metric] uses metric to raise/lower indices when sign mismatches occur in pairs being contracted.
\[Bullet] Built on top of EinsteinSummation."

IndexJuggling::usage = "IndexJuggling[ia, {n\:2081, n\:2082, \[Ellipsis]}] permutes and renames the indices of an IndexArray or IndexTensor so its indices match the specified names.
\[Bullet] Each n\:1d62 may be an existing index name, a negated name (to lower the index), or a Dimension object.
\[Bullet] When the variance of a target name differs from the source, the attached metric is used to raise or lower the index.
\[Bullet] Triggered by ia[n\:2081, n\:2082, \[Ellipsis]] on IndexArray and IndexTensor."

(* ============================================ *)
(* MetricTensor.wl                             *)
(* ============================================ *)

MetricTensor::usage = "MetricTensor[name] returns a built-in metric tensor by name, where name is one of \"Euclidean\", \"Minkowski\", \"Schwarzschild\", \"IsotropicSchwarzschild\", \"EddingtonFinkelstein\", \"GullstrandPainleve\", \"KruskalSzekeres\", \"Kerr\", \"KerrNewman\", \"ReissnerNordstrom\", \"Godel\", \"FLRW\", \"Symmetric\", \"SymmetricField\", \"Asymmetric\", or \"AsymmetricField\".
\[Bullet] MetricTensor[name[args]] passes parameters such as mass M, charge Q, or angular momentum J to the metric.
\[Bullet] MetricTensor[name[args], {x\:2081, x\:2082, \[Ellipsis]}] specifies coordinate symbols.
\[Bullet] MetricTensor[matrix, coordinates] constructs a metric from an explicit matrix and coordinate list.
\[Bullet] MetricTensor[] returns the list of available built-in metric names.
\[Bullet] MetricTensor[\[Ellipsis]][\"prop\"] retrieves properties including \"MatrixRepresentation\", \"InverseMetricTensor\", \"Determinant\", \"LineElement\", \"Signature\", \"RiemannianQ\", \"LorentzianQ\", \"Eigenvalues\", and \"VolumeForm\"."

MetricTensorQ::usage = "MetricTensorQ[expr] yields True if expr is a valid MetricTensor, i.e. it wraps a rank-2 IndexTensor flagged as a metric."
