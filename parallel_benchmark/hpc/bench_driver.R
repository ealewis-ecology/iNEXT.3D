#!/usr/bin/env Rscript
# ===========================================================================
# bench_driver.R -- one-dimension parallel-bootstrap benchmark for the forked
# iNEXT.3D, on the bundled Brazil_rainforest data, on one whole spartan03 node.
#
# For diversity = $BENCH_DIV (TD|PD|FD) it produces:
#   * EARLY byte-identity proof (cheap): fork@1 == fork@28 == stock-master@1,
#     so a broken pipeline or a numbers-changing bug aborts before the long sweep;
#   * a thread-scaling sweep (default 1,2,4,7,14,28) of the SAME iNEXT3D() call;
#   * the headline serial(1) vs 28-thread speedup.
#
# The fork parallelises the bootstrap loop (mclapply), so useful cores <= nboot.
# nboot is SELF-SIZED from the measured per-bootstrap cost to hit ~TARGET_SERIAL_S
# of serial work (a heavy but bounded "simple call"), then capped to the walltime.
# ===========================================================================
suppressMessages(library(tools))

DIV         <- Sys.getenv("BENCH_DIV", "FD")
BENCH       <- Sys.getenv("BENCH_DIR", file.path(getwd(), "bench"))
LIB_FORK    <- Sys.getenv("LIB_FORK",   "/scratch/home/elewis/Rlibs/fork")
LIB_MASTER  <- Sys.getenv("LIB_MASTER", "/scratch/home/elewis/Rlibs/master")
WORKER      <- Sys.getenv("WORKER")
ENDPOINT    <- Sys.getenv("ENDPOINT", "NA")            # "NA" -> package default (2x ref size)
KNOTS       <- as.integer(Sys.getenv("KNOTS", "40"))
NB_chr      <- Sys.getenv("NB", "auto")               # integer, or "auto" to self-size
SWEEP       <- as.integer(strsplit(Sys.getenv("SWEEP", "1,2,4,7,14,28"), "[^0-9]+")[[1]])  # any non-digit sep
KMAX        <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "28"))
CAL_NB      <- as.integer(Sys.getenv("CAL_NB", as.character(KMAX)))  # nboot for calib + identity (cheap for FD)
REPS_HEAD   <- as.integer(Sys.getenv("REPS", "2"))                   # reps for the 1- and 28-thread headline points
TARGET_SER  <- as.numeric(Sys.getenv("TARGET_SERIAL_S", "1800"))   # ~30 min serial baseline
DEADLINE_S  <- as.numeric(Sys.getenv("DEADLINE_S", as.character(5.3 * 3600)))
dir.create(BENCH, showWarnings = FALSE, recursive = TRUE)

wall0     <- proc.time()[["elapsed"]]
elapsed   <- function() proc.time()[["elapsed"]] - wall0
remaining <- function() DEADLINE_S - elapsed()
say <- function(...) { cat(sprintf("[%6.0fs] ", elapsed())); cat(sprintf(...)); cat("\n"); flush(stdout()) }

## ---- export identical inputs FROM THE FORK LIB (master then reuses them) -----
.libPaths(c(LIB_FORK, .libPaths())); suppressMessages(library(iNEXT.3D))
data(Brazil_rainforest_abun_data);       abun  <- Brazil_rainforest_abun_data
data(Brazil_rainforest_phylo_tree);      tree  <- Brazil_rainforest_phylo_tree
data(Brazil_rainforest_distance_matrix); distM <- Brazil_rainforest_distance_matrix
inp <- list(abun = abun, tree = tree, distM = distM)
INPUTS <- file.path(BENCH, sprintf("inputs_%s.rds", DIV)); saveRDS(inp, INPUTS)
say("DIV=%s species=%d assemblages=%d | endpoint=%s knots=%d NB=%s | node cores=%d deadline=%.0f min",
    DIV, nrow(abun), ncol(abun), ENDPOINT, KNOTS, NB_chr, KMAX, DEADLINE_S / 60)

RSCRIPT <- file.path(R.home("bin"), "Rscript")
run <- function(tag, lib, nb, k) {
  out <- file.path(BENCH, paste0(tag, ".rds")); if (file.exists(out)) unlink(out)
  system2(RSCRIPT, c("--vanilla", WORKER, lib, DIV, nb, k, ENDPOINT, KNOTS, tag, out, INPUTS),
          stdout = "", stderr = "")
  if (!file.exists(out)) { say("  !! %s ERRORED (no output)", tag); return(NULL) }
  readRDS(out)
}

## ---- 1. calibrate: serial floor (nb=0) and per-bootstrap cost ----------------
fl  <- run(sprintf("%s_floor", DIV), LIB_FORK, 0L,     1L)
cal <- run(sprintf("%s_cal",   DIV), LIB_FORK, CAL_NB, 1L)
floor_s <- if (!is.null(fl)) fl$elapsed else NA_real_
pb <- if (!is.null(fl) && !is.null(cal)) max(1e-4, (cal$elapsed - floor_s) / CAL_NB) else NA_real_
say("calib: floor=%.2fs per_boot=%.3fs (remaining %.0f min)", floor_s, pb, remaining() / 60)

## ---- 2. EARLY byte-identity (cheap, nb=CAL_NB): fork@1 == fork@28 == master@1 -
NB_id <- CAL_NB
id_f1 <- run(sprintf("%s_id_f1", DIV), LIB_FORK,   NB_id, 1L)
id_fk <- run(sprintf("%s_id_fk", DIV), LIB_FORK,   NB_id, KMAX)
id_m1 <- run(sprintf("%s_id_m1", DIV), LIB_MASTER, NB_id, 1L)
ident_fork_par <- !is.null(id_f1) && !is.null(id_fk) && identical(id_f1$md5, id_fk$md5)
ident_master   <- !is.null(id_f1) && !is.null(id_m1) && identical(id_f1$md5, id_m1$md5)
say("EARLY IDENTITY (nb=%d): fork@1==fork@%d: %s | fork@1==stock-master@1: %s (master ver=%s)",
    NB_id, KMAX, ident_fork_par, ident_master, if (!is.null(id_m1)) id_m1$ver else "NA")

## ---- 3. self-size nboot toward TARGET_SERIAL_S, then cap to the walltime ------
if (toupper(NB_chr) == "AUTO") {
  NB <- as.integer(round(((TARGET_SER - floor_s) / pb) / KMAX) * KMAX)
  NB <- max(KMAX * 4L, NB)
} else NB <- max(KMAX, as.integer(NB_chr))
budget_1thr <- remaining() * 0.45
proj1 <- floor_s + NB * pb
if (is.finite(proj1) && proj1 > budget_1thr) {
  NB_old <- NB; NB <- max(KMAX, (as.integer((budget_1thr - floor_s) / pb) %/% KMAX) * KMAX)
  say("CAP NB %d -> %d so the serial run fits ~%.0f min", NB_old, NB, budget_1thr / 60)
}
say("nboot=%d -> projected serial=%.1f min, projected %d-thread=%.1f min",
    NB, (floor_s + NB * pb) / 60, KMAX, (floor_s + ceiling(NB / KMAX) * pb) / 60)

## ---- 4. thread-scaling sweep (k=1 is the serial baseline) ---------------------
res <- list()
for (k in SWEEP) {
  if (k > KMAX) next
  reps <- if (k %in% c(1L, KMAX)) REPS_HEAD else 1L  # reps for the two headline points; keep min
  best <- NULL
  for (r in seq_len(reps)) {
    rr <- run(sprintf("%s_k%02d_r%d", DIV, k, r), LIB_FORK, NB, k)
    if (!is.null(rr) && (is.null(best) || rr$elapsed < best$elapsed)) best <- rr
  }
  if (!is.null(best)) {
    res[[as.character(k)]] <- best
    say("sweep k=%-2d elapsed=%8.1fs (%.2f min) md5=%s", k, best$elapsed, best$elapsed / 60, substr(best$md5, 1, 8))
  }
}
md5s <- vapply(res, function(x) x$md5, character(1))
ident_fork_full <- length(md5s) > 0 && length(unique(md5s)) == 1L
say("FULL-NB IDENTITY fork across %d thread counts: %s", length(md5s), ident_fork_full)

## ---- 5. assemble + persist ---------------------------------------------------
tab <- do.call(rbind, lapply(names(res), function(k) {
  x <- res[[k]]
  data.frame(div = DIV, threads = as.integer(k), nboot = x$NB, endpoint = x$endpoint, knots = x$knots,
             elapsed_s = x$elapsed, md5 = x$md5, stringsAsFactors = FALSE)
}))
if (!is.null(tab) && any(tab$threads == 1)) {
  t1 <- tab$elapsed_s[tab$threads == 1][1]
  tab$speedup    <- t1 / tab$elapsed_s
  tab$efficiency <- tab$speedup / tab$threads
}
summary <- list(div = DIV, host = Sys.info()[["nodename"]], cores = KMAX, species = nrow(abun),
                endpoint = ENDPOINT, knots = KNOTS, nboot = NB, floor_s = floor_s, per_boot_s = pb,
                ident_fork_par = ident_fork_par, ident_fork_full = ident_fork_full, ident_master = ident_master,
                ver_fork = if (!is.null(id_f1)) id_f1$ver else NA, master_ver = if (!is.null(id_m1)) id_m1$ver else NA,
                table = tab, total_wall_s = elapsed())
saveRDS(summary, file.path(BENCH, sprintf("summary_%s.rds", DIV)))
if (!is.null(tab)) write.csv(tab, file.path(BENCH, sprintf("timings_%s.csv", DIV)), row.names = FALSE)

sink(file.path(BENCH, sprintf("REPORT_%s.txt", DIV)))
cat(sprintf("iNEXT.3D parallel-bootstrap benchmark -- diversity = %s\n", DIV))
cat(sprintf("host=%s cores=%d species=%d | endpoint=%s knots=%d nboot=%d\n",
            summary$host, KMAX, nrow(abun), ENDPOINT, KNOTS, NB))
cat(sprintf("fork ver=%s  master ver=%s\n", summary$ver_fork, summary$master_ver))
cat(sprintf("byte-identity: fork@1==fork@%d (nb=%d): %s | full-nb across threads: %s | fork@1==master@1: %s\n\n",
            KMAX, NB_id, ident_fork_par, ident_fork_full, ident_master))
if (!is.null(tab)) print(tab, row.names = FALSE)
cat(sprintf("\nfloor(point est, no bootstrap)=%.2fs  per_boot=%.3fs  total wall=%.1f min\n",
            floor_s, pb, summary$total_wall_s / 60))
sink()
say("DONE %s: serial->%d-thread speedup = %.2fx | wall %.1f min | wrote summary_%s.rds, timings_%s.csv, REPORT_%s.txt",
    DIV, KMAX, if (!is.null(tab)) max(tab$speedup, na.rm = TRUE) else NA_real_, summary$total_wall_s / 60, DIV, DIV, DIV)
if (!is.null(tab)) print(tab, row.names = FALSE)
