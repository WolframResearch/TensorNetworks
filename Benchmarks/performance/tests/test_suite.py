"""Tests for measurement integrity, corpus layout, and failure propagation."""
from pathlib import Path
import copy
import sys
import os
import subprocess
import tempfile
import unittest

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import digest, numeric_error, read_array, timing_record, validate_result, verify_manifest
from corpus import generate
from python_bench import path_stats
from run import check_kernel_unchanged


class SuiteTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.path = generate(self.root / "corpus", "smoke", 3, .001, 1)
        self.manifest = verify_manifest(self.path)

    def tearDown(self):
        self.directory.cleanup()

    def test_references_and_layout(self):
        for case in self.manifest["cases"]:
            arrays = [read_array(self.path.parent, spec) for spec in case["tensors"]]
            reference = read_array(self.path.parent, case["reference"])
            if case["family"] == "matrix_chain":
                from functools import reduce
                numeric_error(reduce(np.matmul, arrays), reference)
                stats = path_stats(case["labels"], case["output"], {i: case["d"] for i in range(case["n"] + 1)}, case["path"])
                self.assertEqual(stats["scalar_product_terms"], (case["n"] - 1) * case["d"]**3)
            else:
                # Independent all-at-once einsum, rather than the generator's transfer of physical axes.
                alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                equation = ",".join("".join(alphabet[i] for i in inds) for inds in case["labels"])
                equation += "->" + "".join(alphabet[i] for i in case["output"])
                numeric_error(np.einsum(equation, *arrays, optimize=False), reference)
                self.assertLess(abs(np.vdot(reference, reference).real - case["norm_squared"]), 1e-12)

    def test_filter_preserves_tensor_values(self):
        selected = self.manifest["cases"][1]
        other = generate(self.root / "filtered", "smoke", 3, .001, 1, [selected["id"]])
        filtered = verify_manifest(other)["cases"][0]
        self.assertEqual(selected, filtered)
        for spec in selected["tensors"]:
            self.assertEqual(digest(self.path.parent / spec["real"]), digest(other.parent / spec["real"]))

    def test_corrupt_corpus_is_rejected(self):
        file = self.path.parent / self.manifest["files"][0]["path"]
        data = bytearray(file.read_bytes())
        data[0] ^= 1
        file.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "checksum"):
            verify_manifest(self.path)

    def test_wrong_output_cannot_receive_a_timing(self):
        row = timing_record("test", "fake", "test", lambda: np.ones((3, 2)),
                            lambda x: numeric_error(x, np.ones((2, 3))), 3, .001)
        self.assertEqual(row["status"], "failed")
        self.assertNotIn("samples_seconds", row)
        with self.assertRaises(ValueError):
            numeric_error(np.array([np.nan]), np.ones(1))

    def test_incomplete_or_mismatched_results_are_rejected(self):
        result = {"schema_version": 1, "corpus_sha256": digest(self.path), "backend": "python", "records": []}
        with self.assertRaisesRegex(ValueError, "coverage"):
            validate_result(result, self.manifest, digest(self.path), "python")
        with self.assertRaisesRegex(ValueError, "identity"):
            validate_result(result, self.manifest, "wrong", "python")
        with self.assertRaisesRegex(ValueError, "worker identity"):
            validate_result(result, self.manifest, digest(self.path), "tn")

    def test_kernel_changes_invalidate_the_run(self):
        check_kernel_unchanged({"kernel": "before"}, {"kernel": "before"})
        with self.assertRaisesRegex(ValueError, "changed"):
            check_kernel_unchanged({"kernel": "before"}, {"kernel": "after"})

    def test_invalid_path_rejected(self):
        with self.assertRaisesRegex(ValueError, "invalid"):
            path_stats([[0, 1], [1, 2]], [0, 2], {0: 2, 1: 2, 2: 2}, [[0, 0]])

    def test_successful_adapter_output_has_complete_validated_rows(self):
        from python_bench import main
        result_path = self.root / "python.json"
        self.assertEqual(main(self.path, result_path), 0)
        import json
        value = json.loads(result_path.read_text())
        metadata = value["metadata"]
        self.assertIn("Build Dependencies", metadata["numpy_build_config"])
        self.assertEqual(metadata["requested_threads"], 1)
        self.assertIn("VECLIB_MAXIMUM_THREADS", metadata["thread_environment"])
        self.assertIn("effective_blas_threads", metadata)
        self.assertIn("thread_observability", metadata)
        if not any(pool.get("user_api") == "blas" for pool in metadata["threadpools"]):
            self.assertIsNone(metadata["effective_blas_threads"])
            self.assertIn("unavailable", metadata["thread_observability"])
        validate_result(value, self.manifest, digest(self.path), "python")
        for i, row in enumerate(value["records"]):
            incomplete = {**value, "records": value["records"][:i] + value["records"][i+1:]}
            with self.subTest(task=row["task"], implementation=row["implementation"]):
                with self.assertRaisesRegex(ValueError, "coverage"):
                    validate_result(incomplete, self.manifest, digest(self.path), "python")
        # Reproduce the complete runner attack: a successful Python payload in the TN slot.
        fake = self.root / "fake-wolfram"
        fake.write_text("#!/usr/bin/env python3\nimport os,json,hashlib\n"
                        f"value=json.loads({json.dumps(value)!r})\n"
                        "value['corpus_sha256']=hashlib.sha256(open(os.environ['TN_BENCH_MANIFEST'],'rb').read()).hexdigest()\n"
                        "open(os.environ['TN_BENCH_OUTPUT'],'w').write(json.dumps(value))\n")
        fake.chmod(0o755)
        out = self.root / "identity-run"
        command = [sys.executable, str(Path(__file__).resolve().parents[1] / "run.py"),
                   "--profile", "smoke", "--samples", "3", "--sample-seconds", ".001",
                   "--backends", "tn", "--wolframscript", str(fake), "--out", str(out)]
        executed = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(executed.returncode, 1, executed.stderr)
        run = json.loads((out / "run.json").read_text())
        self.assertEqual(run["status"], "failed")
        self.assertIn("worker identity", run["backends"]["tn"]["error"])

        # Reject boolean evidence in every numeric field, including a complete fake worker run.
        for field in ("samples_seconds", "median_seconds", "min_seconds", "max_seconds",
                      "iterations_per_sample", "normalized_error"):
            for invalid in (True, False, float("nan"), float("inf")):
                malformed = copy.deepcopy(value)
                malformed["records"][0][field] = [invalid] * 3 if field == "samples_seconds" else invalid
                with self.subTest(field=field, invalid=invalid):
                    with self.assertRaises(ValueError):
                        validate_result(malformed, self.manifest, digest(self.path), "python")
        boolean_payload = copy.deepcopy(value)
        for row in boolean_payload["records"]:
            row.update(samples_seconds=[True] * 3, median_seconds=True, min_seconds=True,
                       max_seconds=True, iterations_per_sample=True, normalized_error=False)
        fake_python = self.root / "fake-python"
        fake_python.write_text("#!/usr/bin/env python3\nimport sys,json,hashlib\n"
                               f"value=json.loads({json.dumps(boolean_payload)!r})\n"
                               "value['corpus_sha256']=hashlib.sha256(open(sys.argv[2],'rb').read()).hexdigest()\n"
                               "open(sys.argv[3],'w').write(json.dumps(value))\n")
        fake_python.chmod(0o755)
        out = self.root / "boolean-run"
        command = [sys.executable, str(Path(__file__).resolve().parents[1] / "run.py"),
                   "--profile", "smoke", "--samples", "3", "--sample-seconds", ".001",
                   "--backends", "python", "--python", str(fake_python), "--out", str(out)]
        executed = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(executed.returncode, 1, executed.stderr)
        run = json.loads((out / "run.json").read_text())
        self.assertEqual(run["status"], "failed")
        self.assertIn("invalid timing samples", run["backends"]["python"]["error"])

    def test_process_timeout_is_reported(self):
        from run import run_process
        info = run_process([sys.executable, "-c", "import time; time.sleep(5)"], os.environ.copy(),
                           self.root / "sleep.log", .1, self.root / "rss.txt")
        self.assertEqual(info["status"], "timeout")
        self.assertNotEqual(info["returncode"], 0)

    def test_profile_evidence_and_adversarial_mutations(self):
        import json
        from profile_tn import validate_profile
        path = Path(__file__).resolve().parents[1] / "profiling/macos-arm64-2026-10-26/run.json"
        run = json.loads(path.read_text())
        value, manifest, identity = run["result"], run["manifest"], run["corpus_sha256"]
        validate_profile(value, manifest, identity)
        for i in range(len(value["records"])):
            incomplete = {**value, "records": value["records"][:i] + value["records"][i+1:]}
            with self.subTest(missing_row=i), self.assertRaisesRegex(ValueError, "coverage"):
                validate_profile(incomplete, manifest, identity)
        for field in ("samples_seconds", "median_seconds", "min_seconds", "max_seconds",
                      "iterations_per_sample", "calls_per_replay", "normalized_error"):
            for invalid in (True, False, float("nan"), float("inf")):
                malformed = copy.deepcopy(value)
                malformed["records"][0][field] = [invalid] * manifest["protocol"]["samples"] if field == "samples_seconds" else invalid
                with self.subTest(field=field, invalid=invalid), self.assertRaises(ValueError):
                    validate_profile(malformed, manifest, identity)
        for field in ("profiled_definitions_unchanged", "ordered_label_candidate_boundary_checks"):
            malformed = copy.deepcopy(value)
            malformed["metadata"][field] = False
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "guard"):
                validate_profile(malformed, manifest, identity)
        malformed = copy.deepcopy(value)
        malformed["observations"][0]["unique_replay_inputs"]["contractStep"] += 1
        with self.assertRaisesRegex(ValueError, "topology"):
            validate_profile(malformed, manifest, identity)


if __name__ == "__main__":
    unittest.main()
