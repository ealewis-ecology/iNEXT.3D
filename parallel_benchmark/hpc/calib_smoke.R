#!/usr/bin/env Rscript
# Cluster calibration: floor + per-bootstrap cost for TD/PD/FD (knots=40, default
# endpoint, 1 thread) so we can size nboot for a target serial runtime. Prints a
# suggested NB (multiple of 28) for a ~TARGET_S serial baseline.
.libPaths(c(Sys.getenv("LIB_FORK", "/scratch/home/elewis/Rlibs/fork"), .libPaths()))
suppressMessages(library(iNEXT.3D))
data(Brazil_rainforest_abun_data);       abun  <- Brazil_rainforest_abun_data
data(Brazil_rainforest_phylo_tree);      tree  <- Brazil_rainforest_phylo_tree
data(Brazil_rainforest_distance_matrix); distM <- Brazil_rainforest_distance_matrix
NB       <- as.integer(Sys.getenv("CAL_NB", "56")); KN <- 40L
TARGET_S <- as.numeric(Sys.getenv("TARGET_S", "1500"))
cat("detectCores:", parallel::detectCores(), "\n")
cal <- function(div, extra) {
  base <- c(list(data = abun, diversity = div, datatype = "abundance", knots = KN, q = c(0, 1, 2)), extra)
  set.seed(42); t0 <- system.time(do.call(iNEXT3D, c(base, list(nboot = 0,  nthreads = 1))))[["elapsed"]]
  set.seed(42); tN <- system.time(do.call(iNEXT3D, c(base, list(nboot = NB, nthreads = 1))))[["elapsed"]]
  pb <- (tN - t0) / NB
  nb_target <- max(28L, as.integer(round((TARGET_S - t0) / pb / 28) * 28))
  cat(sprintf("CAL %s floor=%.2fs per_boot=%.3fs (serial nb%d=%.1fs) -> NB_for_%.0fs_serial=%d\n",
              div, t0, pb, NB, tN, TARGET_S, nb_target)); flush(stdout())
}
cal("TD", list())
cal("PD", list(PDtree = tree))
cal("FD", list(FDdistM = distM, FDtype = "AUC"))
cat("CALIB_SMOKE_DONE\n")
