#!/usr/bin/env bash
# ===========================================================================
# bench.slurm -- run the iNEXT.3D parallel-bootstrap benchmark for ONE diversity
# dimension on one whole 28-core spartan03 node. The fork's parallelism is
# mclapply (single node), so one full node is the right unit; we sweep 1..28
# threads inside the job. Submit one job per dimension (see submit_all.sh).
#
# Per-dimension knobs arrive via --export: BENCH_DIV, ENDPOINT, KNOTS, NB.
# ===========================================================================
#SBATCH --job-name=i3dbench
#SBATCH --partition=nodes
#SBATCH --nodes=1
#SBATCH --cpus-per-task=28
#SBATCH --mem=96G
#SBATCH --time=06:00:00
#SBATCH --output=/scratch/home/elewis/inext3d_bench/logs/slurm-%x-%j.log
set -o pipefail

REPO=/scratch/home/elewis/inext3d_bench
mkdir -p "$REPO/logs" "$REPO/bench"
source /opt/Miniconda3/Miniconda3-py313_25.11.1-1/etc/profile.d/conda.sh
conda activate lazarus-r

# Pin BLAS/OpenMP to 1 thread: parallelism comes from mclapply forks, and we must
# NOT let up to 28 forks each spawn 28 BLAS threads (28x28 oversubscribe).
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1

export LIB_FORK=/scratch/home/elewis/Rlibs/fork
export LIB_MASTER=/scratch/home/elewis/Rlibs/master
export WORKER="$REPO/hpc/bench_worker.R"
export BENCH_DIR="$REPO/bench"
export DEADLINE_S=19000          # ~5h17 internal deadline (SLURM walltime is 6h)

echo "[$(date)] START div=$BENCH_DIV host=$(hostname) cores=$SLURM_CPUS_PER_TASK ep=$ENDPOINT knots=$KNOTS nb=$NB"
Rscript "$REPO/hpc/bench_driver.R"
rc=$?
echo "[$(date)] END div=$BENCH_DIV rc=$rc"
exit $rc
