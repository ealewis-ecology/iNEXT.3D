# HPC parallel-bootstrap benchmark

Measures the `nthreads` speed-up on the bundled `Brazil_rainforest` data for all three
dimensions (TD/PD/FD) on one multi-core node, and verifies the parallel output is
byte-identical to the sequential run **and** to stock iNEXT.3D 1.0.12.

## Layout

- `bench_worker.R` — runs ONE `iNEXT3D()` call in an isolated subprocess against a chosen
  library path (fork or stock), times only the call, saves elapsed + the MD5 of the
  serialized output.
- `bench_driver.R` — for one dimension: calibrates per-bootstrap cost, checks byte-identity
  (`fork@1 == fork@28 == stock@1`), then sweeps `nthreads` (1..28) on the *same* call.
  Self-sizes `nboot` to a target serial runtime and caps it to the walltime.
- `bench.slurm` — one 28-core node per dimension; pins BLAS to one thread so the forks
  don't oversubscribe. `submit_all.sh` submits TD/PD/FD.
- `collect_results.R` / `plot_speedup.R` — build the summary table + figure.
- `calib_smoke.R` / `smoke_run.sh` — quick pre-flight (calibration + tiny end-to-end run).
- `status.sh` — compact queue/progress check.

## Run

```bash
# on the cluster, with the fork built into $LIB_FORK and stock into $LIB_MASTER:
NB=auto TARGET_SERIAL_S=900 bash hpc/submit_all.sh
Rscript hpc/collect_results.R && Rscript hpc/plot_speedup.R
```

## Results

See `results/`. Headline (Brazil rainforest, 425 species, full `iNEXT3D()` curve, one
28-core node, 1 vs 28 threads): **TD 21.6×, PD 14.1×, FD-AUC 13.5×**, all byte-identical
to serial and to stock 1.0.12. FD is Amdahl-capped because its serial point estimate
(~217s) costs as much as one bootstrap replicate (~213s).
