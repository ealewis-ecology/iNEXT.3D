#!/usr/bin/env bash
# Submit one 28-core node per diversity dimension (TD, PD, FD). Each job sweeps
# 1..28 threads on the SAME iNEXT3D() call and proves byte-identity. Override the
# workload via env, e.g.:  NB=5040 KNOTS=40 ENDPOINT=NA bash submit_all.sh
REPO=/scratch/home/elewis/inext3d_bench
NB="${NB:-auto}"; KNOTS="${KNOTS:-40}"; ENDPOINT="${ENDPOINT:-NA}"; TARGET_SERIAL_S="${TARGET_SERIAL_S:-900}"
mkdir -p "$REPO/logs" "$REPO/bench"
echo "submitting TD/PD/FD with NB=$NB KNOTS=$KNOTS ENDPOINT=$ENDPOINT TARGET_SERIAL_S=$TARGET_SERIAL_S"
for DIV in TD PD FD; do
  jid=$(sbatch --parsable -J "i3d_$DIV" \
        --export=ALL,BENCH_DIV=$DIV,ENDPOINT=$ENDPOINT,KNOTS=$KNOTS,NB=$NB,TARGET_SERIAL_S=$TARGET_SERIAL_S \
        "$REPO/hpc/bench.slurm")
  echo "submitted $DIV -> job $jid"
done
echo "---"; squeue -u elewis -o "%.10i %.9P %.10j %.2t %.10M %.6D %R"
