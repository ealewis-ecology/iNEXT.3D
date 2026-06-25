#!/usr/bin/env Rscript
# ===========================================================================
# Validate the parallel bootstrap against the original sequential iNEXT.3D.
#
# Run from the package root:
#   Rscript parallel_benchmark/validate_parallel.R          # K = cores-1
#   Rscript parallel_benchmark/validate_parallel.R 4        # K = 4 cores
#
# Two equivalence checks (per case, across TD/PD/FD and abundance/incidence):
#   (1) fork(nthreads = K) == fork(nthreads = 1)   parallel == sequential
#   (2) fork(nthreads = 1) == stock iNEXT.3D 1.0.12  sequential path unchanged
# Then a wall-clock speedup for the slow FD-AUC bootstrap.
# ===========================================================================

args <- commandArgs(trailingOnly = TRUE)
K <- if (length(args) >= 1) as.integer(args[1]) else max(2L, parallel::detectCores() - 1L)

allargs <- commandArgs(trailingOnly = FALSE)
script  <- sub("^--file=", "", allargs[grep("^--file=", allargs)])
PKG     <- normalizePath(file.path(dirname(script), ".."))
CASES   <- file.path(PKG, "parallel_benchmark", "_cases.R")

cat(sprintf("Package : %s\nCores K : %d\n\n", PKG, K))

## ---- 1. stock baseline: installed iNEXT.3D 1.0.12 in a clean subprocess -----
stock_rds <- tempfile(fileext = ".rds")
stock_R <- sprintf('suppressMessages(library(iNEXT.3D)); source("%s"); saveRDS(run_cases(NULL), "%s")',
                   CASES, stock_rds)
cat("[1/3] stock iNEXT.3D baseline (subprocess) ...\n")
out <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(stock_R)),
               stdout = TRUE, stderr = TRUE)
if (!file.exists(stock_rds)) { cat(out, sep = "\n"); stop("stock baseline failed") }
stock     <- readRDS(stock_rds)
stock_ver <- system2(file.path(R.home("bin"), "Rscript"),
                     c("--vanilla", "-e", shQuote('cat(as.character(packageVersion("iNEXT.3D")))')),
                     stdout = TRUE)
cat(sprintf("      stock version = %s\n\n", stock_ver))

## ---- 2. load the fork, run sequentially and in parallel ---------------------
cat("[2/3] loading fork via pkgload::load_all ...\n")
suppressMessages(pkgload::load_all(PKG, quiet = TRUE))
source(CASES)
cat(sprintf("      fork version  = %s\n", as.character(utils::packageVersion("iNEXT.3D"))))
cat("      running fork(nthreads = 1) ...\n");        fork1 <- run_cases(1)
cat(sprintf("      running fork(nthreads = %d) ...\n\n", K)); forkK <- run_cases(K)

## ---- 3. compare -------------------------------------------------------------
num_of <- function(x) { v <- suppressWarnings(as.numeric(unlist(x, use.names = FALSE))); v[is.finite(v)] }
maxdiff <- function(a, b) { a <- num_of(a); b <- num_of(b)
                            if (length(a) != length(b) || !length(a)) return(NA_real_); max(abs(a - b)) }
same    <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-12, check.attributes = FALSE))

cat("[3/3] equivalence (tolerance 1e-12)\n")
cat(sprintf("%-15s %10s %10s %12s %12s\n", "case", "par==seq", "seq==stock", "dpar", "dstock"))
cat(strrep("-", 63), "\n")
ok <- TRUE
for (n in names(fork1)) {
  ep <- same(forkK[[n]], fork1[[n]]); es <- same(fork1[[n]], stock[[n]])
  ok <- ok && ep && es
  cat(sprintf("%-15s %10s %10s %12.2e %12.2e\n", n,
              ifelse(ep, "PASS", "FAIL"), ifelse(es, "PASS", "FAIL"),
              maxdiff(forkK[[n]], fork1[[n]]), maxdiff(fork1[[n]], stock[[n]])))
}
cat(strrep("-", 63), "\n")
cat(sprintf("OVERALL: %s\n\n", ifelse(ok, "*** ALL IDENTICAL ***", "MISMATCH (see FAIL rows)")))

## ---- 4. speedup on the slow FD-AUC bootstrap --------------------------------
cat("FD-AUC wall-clock (Brazil 80 spp, AUC, nboot = 40):\n")
ab <- Brazil_rainforest_abun_data; dd <- as.matrix(Brazil_rainforest_distance_matrix)
sp <- rownames(ab)[order(rowSums(ab), decreasing = TRUE)][1:80]
abT <- ab[sp, ]; ddT <- dd[sp, sp]
timeit <- function(k) { set.seed(1); system.time(
  iNEXT3D(abT, diversity = "FD", datatype = "abundance", FDdistM = ddT,
          FDtype = "AUC", FDcut_number = 30, nboot = 40, nthreads = k))[["elapsed"]] }
t1 <- timeit(1); tk <- timeit(K)
cat(sprintf("  nthreads = 1 : %6.1f s\n  nthreads = %d : %6.1f s\n  speedup      : %5.2fx\n",
            t1, K, tk, t1 / tk))

if (!ok) quit(status = 1)
