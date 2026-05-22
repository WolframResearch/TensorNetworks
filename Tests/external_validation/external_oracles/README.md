# External oracles — fixture extraction

Offline scripts that pull reference inputs and expected outputs from numerical
TN packages (quimb, cotengra, ITensorMPS, ...) into JSON fixtures committed
under `fixtures/`. The WL test suite never calls these packages at test time —
it `Import`s the fixtures and re-runs the same computations through paclet
primitives.

This is the mechanism that promoted all 6 previously-skipped "skip-RNG" tests
to passing direct-validation; see `../PLAN.md` § Tier-2 oracle fixtures.

## Run

Tests don't need this directory — only fixture regeneration does.

```bash
# One-time toolchain bootstrap (only on a fresh checkout / package upgrade)
python3 -m venv .venv
.venv/bin/pip install quimb cotengra networkx

# Regenerate fixtures (after pinning new reference values or bumping versions)
.venv/bin/python extract_cotengra_lattice45.py
.venv/bin/python extract_cotengra_sycamore_m20.py
.venv/bin/python extract_cotengra_hyperopt_bound.py
.venv/bin/python extract_quimb_random_mps.py
.venv/bin/python extract_quimb_peps_3x3.py
```

The `.venv/` directory is gitignored; fixtures under `fixtures/` are committed.

## Layout

```
external_oracles/
  extract_<package>_<topic>.py     # one extractor per fixture
  fixtures/
    <package>_<topic>_<seed>.json  # arrays + expected scalars
  README.md                        # this file
  .gitignore                       # excludes .venv and __pycache__
```

Fixture files document their source in a `"source"` field and pin the
package version in `"<package>_version"`; bump the latter when you regenerate
so a future cross-version mismatch surfaces.
