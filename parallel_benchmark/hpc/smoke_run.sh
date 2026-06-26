#!/usr/bin/env bash
# Run on a compute node via srun: cluster calibration (per-boot cost per dimension)
# + a tiny end-to-end driver smoke test (TD, NB=56, threads 1,2) to validate the
# worker/driver/identity pipeline before submitting the full jobs.
set -o pipefail
source /opt/Miniconda3/Miniconda3-py313_25.11.1-1/etc/profile.d/conda.sh
conda activate lazarus-r
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
export LIB_FORK=/scratch/home/elewis/Rlibs/fork
export LIB_MASTER=/scratch/home/elewis/Rlibs/master
export WORKER=/scratch/home/elewis/inext3d_bench/hpc/bench_worker.R
export BENCH_DIR=/scratch/home/elewis/inext3d_bench/bench_smoke
REPO=/scratch/home/elewis/inext3d_bench
echo "HOST=$(hostname) nproc=$(nproc) SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-unset}"
echo "=== CALIBRATION (target 1500s serial) ==="
TARGET_S=1500 CAL_NB=56 Rscript "$REPO/hpc/calib_smoke.R"
echo "=== DRIVER SMOKE (TD, NB=56, sweep 1,2) ==="
BENCH_DIV=TD ENDPOINT=NA KNOTS=40 NB=56 SWEEP="1,2" DEADLINE_S=1200 Rscript "$REPO/hpc/bench_driver.R"
echo "SMOKE_ALL_DONE"
