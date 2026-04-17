# =========================================================
# rGREAT analysis for HALPER-derived peaks (FULL PIPELINE)
# =========================================================

# -----------------------------
# 0. Packages
# -----------------------------
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install(c("rGREAT", "GenomicRanges", "IRanges"), update = FALSE, ask = FALSE)

install.packages(c("dplyr", "ggplot2", "stringr"))
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install("TxDb.Mmusculus.UCSC.mm10.knownGene")
library(rGREAT)
library(GenomicRanges)
library(IRanges)
library(dplyr)
library(ggplot2)
library(stringr)

# -----------------------------
# 1. Settings
# -----------------------------
setwd("/Users/oukanyou/Desktop/GO")

outdir <- "rGREAT_results"
dir.create(outdir, showWarnings = FALSE)

ontology_to_run <- "GO:BP"

peak_files <- list(
  mouse_specific = "mouse_specific_peaks_conservative.narrowPeak",
  human_specific = "human_specific_peaks_conservative.narrowPeak",
  conserved_mouse_in_human = "mouse_to_human_conservative.narrowPeak",
  conserved_human_in_mouse = "human_conservative.sorted.narrowPeak"
)

genome_map <- list(
  mouse_specific = "mm10",
  human_specific = "hg38",
  conserved_mouse_in_human = "hg38",
  conserved_human_in_mouse = "mm10"
)

# -----------------------------
# 2. SAFE BED reader (HALPER-proof)
# -----------------------------
read_bed3 <- function(file) {
  
  df <- read.table(file,
                   header = FALSE,
                   sep = "\t",
                   stringsAsFactors = FALSE,
                   quote = "")
  
  # take only first 3 columns (CRITICAL FIX)
  df <- df[, 1:3]
  colnames(df) <- c("chr", "start", "end")
  
  # keep standard chromosomes
  df <- df[grepl("^chr([0-9]+|X|Y|M)$", df$chr), ]
  
  df$start <- as.numeric(df$start)
  df$end   <- as.numeric(df$end)
  
  GRanges(
    seqnames = df$chr,
    ranges   = IRanges(start = df$start + 1,
                       end   = df$end)
  )
}

# -----------------------------
# 3. rGREAT runner
# -----------------------------
run_great <- function(file, genome, name) {
  
  cat("\n=========================\n")
  cat("Running:", name, "\n")
  cat("=========================\n")
  
  gr <- read_bed3(file)
  
  cat("Peaks:", length(gr), "\n")
  
  job <- great(
    gr = gr,
    tss_source = genome,
    gene_sets = ontology_to_run
  )
  tbl <- getEnrichmentTable(job)
  
  if (!is.null(tbl) && nrow(tbl) > 0) {
    write.csv(tbl,
              file.path(outdir, paste0(name, "_GO_BP.csv")),
              row.names = FALSE)
  }
  
  return(list(job = job, table = tbl))
}

# -----------------------------
# 4. Run all datasets
# -----------------------------
results <- list()

for (name in names(peak_files)) {
  results[[name]] <- run_great(
    file   = peak_files[[name]],
    genome = genome_map[[name]],
    name   = name
  )
}

# -----------------------------
# 5. Extract significance
# -----------------------------
standardize <- function(tb, label) {
  
  if (is.null(tb) || nrow(tb) == 0) return(NULL)
  
  term_col <- intersect(c("name", "term_name", "description"), colnames(tb))[1]
  padj_col <- intersect(c("p_adjust", "adj_p_value", "fdr", "q_value"), colnames(tb))[1]
  enrich_col <- intersect(c("fold_enrichment", "enrichment"), colnames(tb))[1]
  
  tb$term_name_final <- tb[[term_col]]
  tb$padj_final <- tb[[padj_col]]
  
  if (!is.null(enrich_col)) {
    tb$fold_enrichment_final <- tb[[enrich_col]]
  } else {
    tb$fold_enrichment_final <- 1
  }
  
  tb$padj_final[is.na(tb$padj_final)] <- 1
  tb$neglog10_padj <- -log10(tb$padj_final)
  tb$dataset <- label
  
  tb
}

mouse_sig <- standardize(results$mouse_specific$table, "mouse_specific")
human_sig <- standardize(results$human_specific$table, "human_specific")
cons_hm   <- standardize(results$conserved_human_in_mouse$table, "conserved_human_in_mouse")
cons_mh   <- standardize(results$conserved_mouse_in_human$table, "conserved_mouse_in_human")

mouse_sig <- mouse_sig %>% filter(padj_final < 0.05)
human_sig <- human_sig %>% filter(padj_final < 0.05)
cons_hm   <- cons_hm %>% filter(padj_final < 0.05)
cons_mh   <- cons_mh %>% filter(padj_final < 0.05)

# save sig tables
write.csv(mouse_sig, file.path(outdir, "mouse_sig.csv"), row.names = FALSE)
write.csv(human_sig, file.path(outdir, "human_sig.csv"), row.names = FALSE)
write.csv(cons_hm, file.path(outdir, "conserved_hm_sig.csv"), row.names = FALSE)
write.csv(cons_mh, file.path(outdir, "conserved_mh_sig.csv"), row.names = FALSE)

# -----------------------------
# 6. SAFE plotting function (robust)
# -----------------------------
make_dotplot <- function(sig_list, dataset_levels, filename,
                         ncol = 2, width = 13, height = 7) {
  
  sig_list <- sig_list[!sapply(sig_list, is.null)]
  
  if (length(sig_list) == 0) return(NULL)
  
  df <- bind_rows(sig_list)
  
  if (nrow(df) == 0) return(NULL)
  
  df <- df %>%
    group_by(dataset) %>%
    arrange(padj_final, .by_group = TRUE) %>%
    slice_head(n = 10) %>%
    ungroup()
  
  df$term_name_final <- str_wrap(df$term_name_final, 34)
  
  df$fold_enrichment_final[is.na(df$fold_enrichment_final)] <- 1
  
  df$dataset <- factor(df$dataset, levels = dataset_levels)
  
  df <- df %>%
    group_by(dataset) %>%
    mutate(term_plot = factor(term_name_final,
                              levels = rev(unique(term_name_final)))) %>%
    ungroup()
  
  p <- ggplot(df, aes(x = neglog10_padj, y = term_plot)) +
    geom_point(aes(size = fold_enrichment_final,
                   fill = neglog10_padj),
               shape = 21, color = "black") +
    facet_wrap(~dataset, scales = "free", ncol = ncol) +
    scale_fill_gradient(low = "#DCE6F2", high = "#4C78A8") +
    scale_size_continuous(range = c(2.5, 7)) +
    theme_classic() +
    labs(x = "-log10(adj p)", y = NULL)
  
  ggsave(file.path(outdir, filename),
         p, width = width, height = height, dpi = 300)
  
  print(p)
}

# -----------------------------
# 7. Plots
# -----------------------------
make_dotplot(
  list(mouse_sig, human_sig),
  c("mouse_specific", "human_specific"),
  "dotplot_specific.png"
)

make_dotplot(
  list(cons_hm, cons_mh),
  c("conserved_human_in_mouse", "conserved_mouse_in_human"),
  "dotplot_conserved.png"
)

# -----------------------------
# 8. Final merge
# -----------------------------
combined <- bind_rows(mouse_sig, human_sig, cons_hm, cons_mh)
write.csv(combined,
          file.path(outdir, "all_sig_terms.csv"),
          row.names = FALSE)

cat("\nDONE → results saved in:", outdir, "\n")
