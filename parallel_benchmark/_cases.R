# Shared test cases for the parallel-bootstrap validation.
# Sourced by BOTH the stock (installed iNEXT.3D 1.0.12) subprocess and the fork
# session, so the two are compared on byte-identical inputs.
#
# run_cases(nthreads):
#   nthreads = NULL  -> omit the argument        (for stock 1.0.12, no nthreads arg)
#   nthreads = <int> -> pass nthreads = <int>    (for the fork)
#
# The caller must already have the iNEXT.3D functions available
# (library(iNEXT.3D) for stock, or pkgload::load_all() for the fork).

# Built-in datasets (identical in stock and fork; loaded into this environment).
local({
  ds <- c("Brazil_rainforest_abun_data", "Brazil_rainforest_distance_matrix",
          "Brazil_rainforest_phylo_tree", "Fish_incidence_data", "Fish_distance_matrix")
  for (d in ds) utils::data(list = d, package = "iNEXT.3D", envir = globalenv())
})

# Compact inputs so the validation runs quickly but still exercises every path.
.abun  <- Brazil_rainforest_abun_data
.tree  <- Brazil_rainforest_phylo_tree
.distB <- as.matrix(Brazil_rainforest_distance_matrix)

# species subset for FD (small but non-degenerate distance matrix)
.spF   <- rownames(.abun)[order(rowSums(.abun), decreasing = TRUE)][1:50]
.abunF <- .abun[.spF, ]
.distF <- .distB[.spF, .spF]

.fish     <- Fish_incidence_data
.distFish <- as.matrix(Fish_distance_matrix)

NB    <- 12     # bootstrap replicates (enough to exercise the loop)
FDCUT <- 15     # AUC tau cuts
SEED  <- 2024

run_cases <- function(nthreads = NULL) {
  nt <- function(args) if (is.null(nthreads)) args else c(args, list(nthreads = nthreads))
  go <- function(FUN, args) { set.seed(SEED); do.call(FUN, nt(args)) }

  list(
    # ---- TD : iNEXT.Ind / iNEXT.Sam / invChat / asyTD+obsTD ----
    TD_abun_iNEXT = go(iNEXT3D,    list(data=.abun, diversity="TD", q=c(0,1,2),
                                        datatype="abundance", nboot=NB)),
    TD_inc_iNEXT  = go(iNEXT3D,    list(data=.fish, diversity="TD", q=c(0,1,2),
                                        datatype="incidence_raw", nboot=NB)),
    TD_est        = go(estimate3D, list(data=.abun, diversity="TD", q=c(0,1,2),
                                        datatype="abundance", base="coverage", nboot=NB)),
    TD_obsasy     = go(ObsAsy3D,   list(data=.abun, diversity="TD", q=c(0,1,2),
                                        datatype="abundance",
                                        method=c("Asymptotic","Observed"), nboot=NB)),
    # ---- PD : inextPD / invChatPD / asymPD+EmpPD ----
    PD_abun_iNEXT = go(iNEXT3D,    list(data=.abun, diversity="PD", q=c(0,1,2),
                                        datatype="abundance", PDtree=.tree, nboot=NB)),
    PD_est        = go(estimate3D, list(data=.abun, diversity="PD", q=c(0,1,2),
                                        datatype="abundance", base="coverage",
                                        PDtree=.tree, nboot=NB)),
    PD_obsasy     = go(ObsAsy3D,   list(data=.abun, diversity="PD", q=c(0,1,2),
                                        datatype="abundance", PDtree=.tree,
                                        method=c("Asymptotic","Observed"), nboot=NB)),
    # ---- FD : iNextFD / invChatFD / FDtable_mle+est / AUCtable_* ----
    FD_tau_iNEXT  = go(iNEXT3D,    list(data=.abunF, diversity="FD", q=c(0,1,2),
                                        datatype="abundance", FDdistM=.distF,
                                        FDtype="tau_values", nboot=NB)),
    FD_auc_iNEXT  = go(iNEXT3D,    list(data=.abunF, diversity="FD", q=c(0,1,2),
                                        datatype="abundance", FDdistM=.distF,
                                        FDtype="AUC", FDcut_number=FDCUT, nboot=NB)),
    FD_auc_est    = go(estimate3D, list(data=.abunF, diversity="FD", q=c(0,1,2),
                                        datatype="abundance", base="coverage",
                                        FDdistM=.distF, FDtype="AUC",
                                        FDcut_number=FDCUT, nboot=NB)),
    FD_auc_obsasy = go(ObsAsy3D,   list(data=.abunF, diversity="FD", q=c(0,1,2),
                                        datatype="abundance", FDdistM=.distF,
                                        FDtype="AUC", FDcut_number=FDCUT,
                                        method=c("Asymptotic","Observed"), nboot=NB)),
    # ---- FD incidence (the draw-hoist path) ----
    FD_auc_inc    = go(iNEXT3D,    list(data=.fish, diversity="FD", q=c(0,1,2),
                                        datatype="incidence_raw", FDdistM=.distFish,
                                        FDtype="AUC", FDcut_number=FDCUT, nboot=NB))
  )
}
