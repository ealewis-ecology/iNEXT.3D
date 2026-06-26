#!/usr/bin/env Rscript
# Collect per-dimension summaries into a headline table (1 vs 28 threads), the
# full thread sweep, and a markdown table for the PR.
BENCH <- Sys.getenv("BENCH_DIR", "/scratch/home/elewis/inext3d_bench/bench")
dims  <- c("TD", "PD", "FD")
labs  <- c(TD = "Taxonomic (TD)", PD = "Phylogenetic (PD)", FD = "Functional (FD, AUC)")
fmt <- function(s) if (is.na(s)) "NA" else if (s >= 60) sprintf("%dm %02ds", s %/% 60, round(s %% 60)) else sprintf("%.1fs", s)

hl <- list(); allt <- list()
for (d in dims) {
  f <- file.path(BENCH, sprintf("summary_%s.rds", d))
  if (!file.exists(f)) { cat("MISSING", f, "\n"); next }
  s <- readRDS(f); t <- s$table
  if (is.null(t) || !any(t$threads == 1)) { cat("no usable table for", d, "\n"); next }
  t1  <- t$elapsed_s[t$threads == 1][1]; kmax <- max(t$threads)
  t28 <- t$elapsed_s[t$threads == kmax][1]
  hl[[d]] <- data.frame(dimension = labs[[d]], species = s$species, knots = s$knots, nboot = s$nboot,
    serial_1thr_s = round(t1, 1), thr_max = kmax, thr_max_s = round(t28, 1),
    speedup = round(t1 / t28, 1), efficiency_pct = round(100 * (t1 / t28) / kmax, 1),
    floor_s = round(s$floor_s, 2), per_boot_s = round(s$per_boot_s, 3),
    ident_fork_par = s$ident_fork_par, ident_fork_full = s$ident_fork_full, ident_master = s$ident_master,
    fork_ver = s$ver_fork, master_ver = s$master_ver, host = s$host, stringsAsFactors = FALSE)
  t$dimension <- labs[[d]]; allt[[d]] <- t
}
H <- do.call(rbind, hl); A <- do.call(rbind, allt)
cat("================ HEADLINE (serial vs max threads) ================\n")
print(H[, c("dimension","species","nboot","serial_1thr_s","thr_max","thr_max_s","speedup","efficiency_pct","ident_fork_par","ident_master")], row.names = FALSE)
cat("\n================ FULL THREAD SWEEP ================\n")
if (!is.null(A)) print(A[, c("dimension","threads","nboot","elapsed_s","speedup","efficiency")], row.names = FALSE)

write.csv(H, file.path(BENCH, "HEADLINE.csv"), row.names = FALSE)
if (!is.null(A)) write.csv(A, file.path(BENCH, "ALL_TIMINGS.csv"), row.names = FALSE)

con <- file(file.path(BENCH, "SUMMARY.md"), "w")
writeLines(c("| Dimension | Species | nboot | 1 thread | 28 threads | Speedup | Parallel eff. | Identical results? |",
             "|---|--:|--:|--:|--:|--:|--:|:--:|"), con)
for (i in seq_len(nrow(H))) { r <- H[i, ]
  writeLines(sprintf("| %s | %d | %d | %s | %s | %.1f× | %.0f%% | %s |",
    r$dimension, r$species, r$nboot, fmt(r$serial_1thr_s), fmt(r$thr_max_s), r$speedup, r$efficiency_pct,
    if (isTRUE(r$ident_fork_par) && isTRUE(r$ident_master)) "yes" else "**NO**"), con) }
close(con)
cat("\nwrote HEADLINE.csv, ALL_TIMINGS.csv, SUMMARY.md to", BENCH, "\n")
