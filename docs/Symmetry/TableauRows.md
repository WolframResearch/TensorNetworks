---
Template: Symbol
Name: TableauRows
Context: Wolfram`TensorNetworks`Symmetry`
Paclet: Wolfram/TensorNetworks
URI: Wolfram/TensorNetworks/ref/TableauRows
Keywords: [Young tableau, rows, symmetry, partition]
SeeAlso: [TableauColumns, TableauShape, TableauSize, YoungTableau]
RelatedGuides: [TensorNetworks]
---

## Usage

<code>[TableauRows]()[*tableau*]</code> returns the inner row list of *tableau* as a list of lists of slot indices.

## Details & Options

- [`YoungTableau`]() is atomic, so [`First`]() and [`Part`]() do not unpack its rows; use [`TableauRows`]() as the explicit accessor.
- Pair with [`TableauColumns`]() to traverse the same tableau along its columns.

## Basic Examples

```wl
TableauRows[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]]
```
<!-- => {{1, 2, 3}, {4, 5}, {6}} -->

## Properties and Relations

[`TableauRows`]() and [`TableauColumns`]() are duals on the same tableau:

```wl
yt = YoungTableau[{{1, 2, 3}, {4, 5}, {6}}];
TableauRows[yt]
```
<!-- => {{1, 2, 3}, {4, 5}, {6}} -->

---

```wl
TableauColumns[yt]
```
<!-- => {{1, 4, 6}, {2, 5}, {3}} -->

The row lengths reproduce the tableau shape:

```wl
Length /@ TableauRows[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]]
```
<!-- => {3, 2, 1} -->

## Possible Issues

[`TableauRows`]() accepts only a [`YoungTableau`](); a raw list of lists triggers a <code>[TableauRows]()::noyt</code> message and returns [`$Failed`]():

```wl
TableauRows[{{1, 2}, {3}}]
```
<!-- => $Failed (with TableauRows::noyt) -->
