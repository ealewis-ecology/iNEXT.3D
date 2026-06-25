context("parallel bootstrap equivalence")

# The optional parallel bootstrap (nthreads > 1) must return results IDENTICAL
# to the sequential code (nthreads = 1): every random draw is generated before
# the parallelised compute loop, so the parallel region consumes no random
# numbers. These tests assert that invariant across TD / PD / FD and
# abundance / incidence. Skipped on CRAN and on single-core machines.

same_par <- function(FUN, args) {
  set.seed(1); seq_out <- do.call(FUN, c(args, list(nthreads = 1)))
  set.seed(1); par_out <- do.call(FUN, c(args, list(nthreads = 2)))
  expect_equal(par_out, seq_out, tolerance = 1e-12)
}

test_that("parallel == sequential for abundance data (TD, PD, FD)", {
  skip_on_cran()
  if (parallel::detectCores() < 2) skip("needs >= 2 cores")

  data("Brazil_rainforest_abun_data")
  data("Brazil_rainforest_phylo_tree")
  data("Brazil_rainforest_distance_matrix")
  ab  <- Brazil_rainforest_abun_data
  sp  <- rownames(ab)[order(rowSums(ab), decreasing = TRUE)][1:40]
  abF <- ab[sp, ]
  dF  <- as.matrix(Brazil_rainforest_distance_matrix)[sp, sp]

  # TD
  same_par(iNEXT3D,    list(data = ab, diversity = "TD", q = c(0, 1, 2),
                            datatype = "abundance", nboot = 8))
  same_par(estimate3D, list(data = ab, diversity = "TD", q = c(0, 1, 2),
                            datatype = "abundance", base = "coverage", nboot = 8))
  same_par(ObsAsy3D,   list(data = ab, diversity = "TD", q = c(0, 1, 2),
                            datatype = "abundance",
                            method = c("Asymptotic", "Observed"), nboot = 8))
  # PD
  same_par(iNEXT3D,    list(data = ab, diversity = "PD", q = c(0, 1, 2),
                            datatype = "abundance",
                            PDtree = Brazil_rainforest_phylo_tree, nboot = 8))
  # FD (tau_values and the slow AUC path)
  same_par(iNEXT3D,    list(data = abF, diversity = "FD", q = c(0, 1, 2),
                            datatype = "abundance", FDdistM = dF,
                            FDtype = "tau_values", nboot = 8))
  same_par(iNEXT3D,    list(data = abF, diversity = "FD", q = c(0, 1, 2),
                            datatype = "abundance", FDdistM = dF,
                            FDtype = "AUC", FDcut_number = 12, nboot = 8))
})

test_that("parallel == sequential for incidence data (TD, FD)", {
  skip_on_cran()
  if (parallel::detectCores() < 2) skip("needs >= 2 cores")

  data("Fish_incidence_data")
  data("Fish_distance_matrix")

  # TD incidence
  same_par(iNEXT3D, list(data = Fish_incidence_data, diversity = "TD",
                         q = c(0, 1, 2), datatype = "incidence_raw", nboot = 8))
  # FD incidence AUC (the draw-hoist path)
  same_par(iNEXT3D, list(data = Fish_incidence_data, diversity = "FD",
                         q = c(0, 1, 2), datatype = "incidence_raw",
                         FDdistM = Fish_distance_matrix, FDtype = "AUC",
                         FDcut_number = 12, nboot = 8))
})
