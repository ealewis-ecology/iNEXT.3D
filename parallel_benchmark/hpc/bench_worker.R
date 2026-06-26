#!/usr/bin/env Rscript
# ===========================================================================
# bench_worker.R -- run ONE iNEXT3D() call in an isolated subprocess against a
# chosen library path (fork | master), time only the call, and save
# elapsed + md5(serialized output). Isolation lets us load the stock-master and
# the parallel-fork builds (same package name) without a namespace clash, and
# gives each timing a cold process (no GC/warm-cache bleed between thread counts).
#
# Positional args:
#   1 LIB       library path holding the iNEXT.3D build to load
#   2 DIV       "TD" | "PD" | "FD"
#   3 NB        nboot
#   4 K         nthreads (passed ONLY if the loaded build exposes the arg)
#   5 ENDPOINT  extrapolation endpoint; "NA" -> package default (2x ref size)
#   6 KNOTS     number of knots on the rarefaction/extrapolation curve
#   7 TAG       label
#   8 OUTFILE   rds to write {elapsed, md5, ...}
#   9 INPUTS    rds holding list(abun, tree, distM) -- identical inputs for all libs
#
# iNEXT.3D draws its bootstrap rmultinom/rbinom OUTSIDE the parallelised region,
# so set.seed() here makes fork@K bit-identical to fork@1 and to master@1.
# ===========================================================================
a <- commandArgs(trailingOnly = TRUE)
LIB <- a[1]; DIV <- a[2]; NB <- as.integer(a[3]); K <- as.integer(a[4])
ENDPOINT <- if (a[5] == "NA") NULL else as.numeric(a[5]); KNOTS <- as.integer(a[6])
TAG <- a[7]; OUTFILE <- a[8]; INPUTS <- a[9]; SEED <- 42L

.libPaths(c(LIB, .libPaths()))
suppressMessages(library(iNEXT.3D))
inp    <- readRDS(INPUTS)
ver    <- as.character(utils::packageVersion("iNEXT.3D"))
has_nt <- "nthreads" %in% names(formals("iNEXT3D"))

args_list <- list(data = inp$abun, diversity = DIV, datatype = "abundance",
                  q = c(0, 1, 2), nboot = NB, knots = KNOTS)
if (!is.null(ENDPOINT))  args_list$endpoint <- ENDPOINT
if (DIV == "PD")         args_list$PDtree   <- inp$tree
if (DIV == "FD") {       args_list$FDdistM  <- inp$distM; args_list$FDtype <- "AUC" }
if (has_nt)              args_list$nthreads  <- K

set.seed(SEED)
el <- system.time(out <- do.call("iNEXT3D", args_list))[["elapsed"]]

tf <- tempfile(); writeBin(serialize(out, NULL, xdr = TRUE), tf)
md5 <- unname(tools::md5sum(tf)); unlink(tf)

saveRDS(list(tag = TAG, div = DIV, NB = NB, K = K,
             endpoint = if (is.null(ENDPOINT)) NA_real_ else ENDPOINT, knots = KNOTS,
             ver = ver, has_nthreads = has_nt, used_nthreads = if (has_nt) K else 1L,
             seed = SEED, elapsed = el, md5 = md5), OUTFILE)
cat(sprintf("[worker] %-20s DIV=%s NB=%4d K=%3d ep=%-7s ver=%-10s ntarg=%-5s elapsed=%8.1fs (%.2f min) md5=%s\n",
            TAG, DIV, NB, K, if (is.null(ENDPOINT)) "def" else as.character(ENDPOINT),
            ver, has_nt, el, el / 60, substr(md5, 1, 8)))
flush(stdout())
