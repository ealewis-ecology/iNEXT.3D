#!/usr/bin/env Rscript
# Speedup-vs-threads scaling curves for TD/PD/FD -> speedup.png for the PR.
suppressMessages(library(ggplot2))
BENCH <- Sys.getenv("BENCH_DIR", "/scratch/home/elewis/inext3d_bench/bench")
dims <- c("TD", "PD", "FD"); labs <- c(TD = "Taxonomic (TD)", PD = "Phylogenetic (PD)", FD = "Functional (FD, AUC)")
rows <- list()
for (d in dims) { f <- file.path(BENCH, sprintf("summary_%s.rds", d)); if (!file.exists(f)) next
  s <- readRDS(f); t <- s$table; if (is.null(t)) next; t$dim <- labs[[d]]; t$nb <- s$nboot; rows[[d]] <- t }
A <- do.call(rbind, rows)
if (is.null(A)) { cat("no data\n"); quit(status = 1) }
kmax <- max(A$threads)
p <- ggplot(A, aes(threads, speedup, color = dim)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, color = "grey60") +
  geom_line(linewidth = 0.8) + geom_point(size = 2.2) +
  scale_x_continuous(breaks = sort(unique(A$threads))) +
  scale_y_continuous(breaks = scales::pretty_breaks()) +
  labs(title = "iNEXT.3D parallel bootstrap: speed-up vs threads",
       subtitle = "Brazil rainforest (425 sp), iNEXT3D() full R/E curve, 28-core node; nboot per dim (TD 3472, PD 504, FD 28); dashed = ideal",
       x = "threads (nthreads)", y = "speed-up vs 1 thread", color = NULL) +
  theme_bw(base_size = 12) + theme(legend.position = "top")
ggsave(file.path(BENCH, "speedup.png"), p, width = 7, height = 5, dpi = 130)
cat("wrote", file.path(BENCH, "speedup.png"), "\n")
