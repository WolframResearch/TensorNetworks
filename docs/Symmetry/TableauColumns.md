---
Template: Symbol
Name: TableauColumns
Context: Wolfram`TensorNetworks`Symmetry`
Paclet: Wolfram/TensorNetworks
URI: Wolfram/TensorNetworks/ref/TableauColumns
Keywords: [Young tableau, columns, symmetry, partition, transpose]
SeeAlso: [TableauRows, TableauShape, TransposePartition, YoungTableau]
RelatedGuides: [TensorNetworks]
---

## Usage

<code>[`TableauColumns`]()[*tableau*]</code> returns the column slot lists of *tableau*, with column $j$ collecting the slot at position $j$ of every row reaching position $j$.

## Details & Options

- The column lengths give the conjugate (transpose) partition of *tableau*'s shape — equivalent to [`TransposePartition`]() applied to [`TableauShape`]().
- Ragged tableau shapes are handled: short rows simply contribute no entry to their missing columns.
- [`YoungTableau`]() is atomic, so columns are not directly accessible via [`Part`](); [`TableauColumns`]() is the canonical accessor.

## Basic Examples

```wl
TableauColumns[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]]
```
<!-- => {{1, 4, 6}, {2, 5}, {3}} -->

## Properties and Relations

The column lengths form the conjugate partition of the tableau shape:

```wl
yt = YoungTableau[{{1, 2, 3, 4}, {5, 6}, {7}}];
Length /@ TableauColumns[yt] == TransposePartition[TableauShape[yt]]
```
<!-- => True -->

Transposing the row list and applying [`TableauColumns`]() are equivalent up to padding-aware column extraction:

```wl
yt = YoungTableau[{{1, 2, 3}, {4, 5}, {6}}];
TableauColumns[yt] == TableauRows[YoungTableau[TableauColumns[yt]]]
```
<!-- => True -->

## Possible Issues

[`TableauColumns`]() accepts only a [`YoungTableau`](); a raw list of lists triggers a <code>[TableauColumns]()::noyt</code> message and returns [`$Failed`]():

```wl
TableauColumns[{{1, 2}, {3}}]
```
<!-- => $Failed (with TableauColumns::noyt) -->
