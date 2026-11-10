"""NumPy, opt_einsum, and cotengra adapters. Run through run.py."""
from __future__ import annotations

import importlib.metadata
import json
import os
import platform
import sys
from functools import reduce
from pathlib import Path

from common import SCHEMA_VERSION, digest, numeric_error, read_array, timing_record, verify_manifest, write_json


def main(manifest_path: Path, output: Path) -> int:
    import numpy as np
    import opt_einsum as oe
    import cotengra as ctg
    from threadpoolctl import threadpool_info, threadpool_limits

    manifest = verify_manifest(manifest_path)
    root, protocol = manifest_path.parent, manifest["protocol"]
    result = {"schema_version": SCHEMA_VERSION, "corpus_sha256": digest(manifest_path),
              "backend": "python", "metadata": {"python": sys.version, "platform": platform.platform(),
              "numpy_build_config": np.show_config(mode="dicts"),
              "requested_threads": protocol["threads"],
              "thread_environment": {key: os.environ.get(key) for key in (
                  "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
                  "VECLIB_MAXIMUM_THREADS", "BLIS_NUM_THREADS")},
              "packages": {name: importlib.metadata.version(name) for name in
                           ("numpy", "opt_einsum", "cotengra", "autoray", "threadpoolctl")}},
              "records": []}

    def measure(case, implementation, task, fn, expected=None, *, valid=None, mode="prepared"):
        validate = valid or (lambda value: numeric_error(value, expected))
        row = timing_record(case, implementation, task, fn, validate, protocol["samples"],
                            protocol["sample_seconds"], mode=mode)
        result["records"].append(row)
        return row

    # Load a BLAS-sized operation before applying runtime controls; all setup is untimed.
    np.matmul(np.ones((256, 256)), np.ones((256, 256)))
    with threadpool_limits(limits=protocol["threads"]):
        pools = threadpool_info()
        result["metadata"]["threadpools"] = pools
        blas_pools = [pool for pool in pools if pool.get("user_api") == "blas"]
        result["metadata"]["effective_blas_threads"] = [pool.get("num_threads") for pool in blas_pools] if blas_pools else None
        result["metadata"]["thread_observability"] = (
            "BLAS pool readbacks recorded; see effective_blas_threads" if blas_pools else
            "Effective BLAS thread count unavailable: threadpoolctl detected no supported BLAS pool. Environment settings are requested controls, not verified counts.")
        measure("harness", "python", "harness.noop", lambda: 1, 1)
        for case in manifest["cases"]:
            print(case["id"], flush=True)
            arrays = [read_array(root, spec) for spec in case["tensors"]]
            labels, output_labels = case["labels"], case["output"]
            shapes = [a.shape for a in arrays]
            size_dict = {label: dim for inds, shape in zip(labels, shapes) for label, dim in zip(inds, shape)}
            if case["family"] == "matrix_chain":
                expected = read_array(root, case["reference"])
                equation = ",".join("".join(oe.get_symbol(i) for i in inds) for inds in labels)
                equation += "->" + "".join(oe.get_symbol(i) for i in output_labels)
                path = [tuple(pair) for pair in case["path"]]
                prepare_oe = lambda: oe.contract_expression(equation, *shapes, optimize=path)
                prepare_ctg = lambda: ctg.array_contract_expression(
                    labels, output_labels, shapes=shapes, optimize=path, cache=False, autojit=False)
                for name, prepare in [("opt_einsum.numpy", prepare_oe), ("cotengra.numpy", prepare_ctg)]:
                    measure(case["id"], name, "chain.prepare.expression.fixed_path", prepare,
                            valid=lambda value: numeric_error(value(*arrays, backend="numpy"), expected))
                    expression = prepare()
                    measure(case["id"], name, "chain.execute.fixed_path",
                            lambda: expression(*arrays, backend="numpy"), expected)
                    new_arrays = [2 * arrays[0], *arrays[1:]]
                    measure(case["id"], name, "chain.execute.new_values",
                            lambda: expression(*new_arrays, backend="numpy"), 2 * expected)
                    support_arrays = [read_array(root, case["changed_first"]), *arrays[1:]]
                    measure(case["id"], name, "chain.execute.changed_support",
                            lambda: expression(*support_arrays, backend="numpy"),
                            read_array(root, case["changed_reference"]))
                measure(case["id"], "numpy", "chain.execute.fixed_path",
                        lambda: reduce(np.matmul, arrays), expected)

                def valid_oe_plan(value):
                    return numeric_error(oe.contract(equation, *arrays, optimize=value[0]), expected)

                def valid_ctg_plan(value):
                    return numeric_error(value.contract(arrays, backend="numpy", autojit=False), expected)

                measure(case["id"], "opt_einsum.numpy", "chain.plan.greedy",
                        lambda: oe.contract_path(equation, *shapes, shapes=True, optimize="greedy"),
                        valid=valid_oe_plan, mode="search")
                measure(case["id"], "cotengra.numpy", "chain.plan.greedy",
                        lambda: ctg.array_contract_tree(labels, output_labels, size_dict=size_dict, optimize="greedy"),
                        valid=valid_ctg_plan, mode="search")
                # Path quality is reported separately from execution and uses a common term-count convention.
                for name, planned in [("opt_einsum.numpy", oe.contract_path(equation, *shapes, shapes=True, optimize="greedy")[0]),
                                      ("cotengra.numpy", ctg.array_contract_tree(labels, output_labels, size_dict=size_dict, optimize="greedy").get_path())]:
                    row = next(r for r in reversed(result["records"]) if r["case"] == case["id"] and
                               r["implementation"] == name and r["task"] == "chain.plan.greedy")
                    row["plan_stats"] = path_stats(labels, output_labels, size_dict, planned)
            else:
                # Bra/ket contraction on the identical site arrays, prepared with one shared greedy path.
                n = case["n"]
                bra_labels = [[i + 2 * n if i < n - 1 else i for i in inds] for inds in labels]
                all_labels = labels + bra_labels
                all_arrays = arrays + [a.conj() for a in arrays]
                all_shapes = [a.shape for a in all_arrays]
                equation = ",".join("".join(oe.get_symbol(i) for i in inds) for inds in all_labels) + "->"
                path = oe.contract_path(equation, *all_shapes, shapes=True, optimize="greedy")[0]
                expressions = [
                    ("opt_einsum.numpy", oe.contract_expression(equation, *all_shapes, optimize=path)),
                    ("cotengra.numpy", ctg.array_contract_expression(
                        all_labels, [], shapes=all_shapes, optimize=path, cache=False, autojit=False))]
                for name, expression in expressions:
                    measure(case["id"], name, "mps.overlap", lambda: expression(*all_arrays, backend="numpy"),
                            case["norm_squared"], mode="prepared_generic_network")
            write_json(output, result)
    return int(any(row["status"] != "ok" for row in result["records"]))


def path_stats(inputs, output, sizes, path):
    """Sum scalar product terms; two real FLOPs per term is only an approximation."""
    remaining = [list(inds) for inds in inputs]
    terms, largest = 0, 0
    for pair in path:
        if len(pair) != 2 or len(set(pair)) != 2 or any(i < 0 or i >= len(remaining) for i in pair):
            raise ValueError("invalid pairwise path")
        union = list(dict.fromkeys(remaining[pair[0]] + remaining[pair[1]]))
        rest = [inds for i, inds in enumerate(remaining) if i not in pair]
        needed = set(output).union(*(set(inds) for inds in rest))
        new = [i for i in union if i in needed]
        terms += __import__("math").prod(sizes[i] for i in union)
        largest = max(largest, __import__("math").prod(sizes[i] for i in new))
        remaining = rest + [new]
    if len(remaining) != 1 or set(remaining[0]) != set(output):
        raise ValueError("incomplete path")
    return {"scalar_product_terms": terms, "largest_intermediate_elements": largest}


if __name__ == "__main__":
    try:
        sys.exit(main(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()))
    except Exception as exc:
        print(f"Python benchmark failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(2)
