# Parallel bootstrap — validation & benchmark

This folder validates the optional multi-core bootstrap (the `nthreads` argument
added to `iNEXT3D()`, `estimate3D()` and `ObsAsy3D()`) and measures its speed-up.

## What the change does

The bootstrap that builds confidence intervals is the slow part of iNEXT.3D
(especially functional diversity with `FDtype = "AUC"`). The replicate loop is
plain `sapply()`/`apply()`; this branch lets it run on several CPU cores via the
base **`parallel`** package. Only the per-replicate *computation* is parallelised
— every random draw (`rmultinom`/`rbinom`) is generated **before** the parallel
region — so the result is **numerically identical** to the sequential run, not
merely equal in distribution.

* `nthreads = 1` (default) → original sequential code path, behaviour unchanged.
* `nthreads > 1` → forked workers on Unix/macOS, a PSOCK cluster on Windows.

## Run the validation

From the package root:

```r
Rscript parallel_benchmark/validate_parallel.R        # K = detectCores() - 1
Rscript parallel_benchmark/validate_parallel.R 4      # K = 4 cores
```

It checks, for every combination of TD/PD/FD × abundance/incidence × the three
exported functions:

1. `fork(nthreads = K)` == `fork(nthreads = 1)`  — parallel equals sequential, and
2. `fork(nthreads = 1)` == stock **iNEXT.3D 1.0.12** — the sequential path is unchanged

(comparison tolerance `1e-12`), then prints a wall-clock speed-up for the FD-AUC
bootstrap. `_cases.R` holds the shared test calls used for both the stock baseline
(run in a clean subprocess) and the fork.

A lighter, self-contained version of check (1) ships as a unit test:
`tests/testthat/test-parallel-equivalence.R`.

## Requirements

`pkgload` (to `load_all()` the fork) and the installed stock `iNEXT.3D` 1.0.12
(for the baseline). Both come with a normal development setup.
