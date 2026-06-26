#!/usr/bin/env bash
# Compact status of the three benchmark jobs: queue state, summaries written,
# fatal-crash flag, and the latest progress line from each job log.
JOBS="429653 429654 429655"
BENCH=/scratch/home/elewis/inext3d_bench
inq=0
for j in $JOBS; do st=$(squeue -j "$j" -h -o %T 2>/dev/null); [ -n "$st" ] && inq=$((inq+1)); printf '%s:%s ' "$j" "${st:-done}"; done
printf '\n'
echo "INQ=$inq SUMM=$(ls "$BENCH"/bench/summary_*.rds 2>/dev/null | wc -l | tr -d ' ')"
grep -lE 'Execution halted' "$BENCH"/logs/*.log 2>/dev/null | sed 's/^/HALT /'
for f in "$BENCH"/logs/slurm-i3d_*.log; do
  [ -f "$f" ] && printf '%s | %s\n' "$(basename "$f")" "$(grep -E '\] ' "$f" 2>/dev/null | tail -1)"
done
