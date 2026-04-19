# =========================================================
# Unified rGREAT Analysis Pipeline 
# (Includes multiple group comparisons, 3 GO ontologies, robust reading, and updated aesthetic plotting)
# =========================================================

# -----------------------------
# 0. Auto-install and load dependencies
# -----------------------------
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "http://cran.us.r-project.org")
}

required_pkgs <- c("rGREAT", "GenomicRanges", "IRanges")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    BiocManager::install(pkg, update = FALSE, ask = FALSE)
  }
}

cran_pkgs <- c("dplyr", "ggplot2", "stringr", "RColorBrewer")
for (pkg in cran_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "http://cran.us.r-project.org")
  }
}

# Add mm10 annotation library if needed
if (!requireNamespace("TxDb.Mmusculus.UCSC.mm10.knownGene", quietly = TRUE)) {
  BiocManager::install("TxDb.Mmusculus.UCSC.mm10.knownGene", update = FALSE, ask = FALSE)
}

suppressPackageStartupMessages({
  library(rGREAT)
  library(GenomicRanges)
  library(IRanges)
  library(dplyr)
  library(ggplot2)
  library(stringr)
  library(RColorBrewer)
})

# -----------------------------
# 1. Parameters and path configuration
# -----------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) {
  stop("Usage: Rscript rgreat_pipeline.R <mouse_spec> <human_spec> <cons_mouse_in_human> <cons_human_in_mouse> [outdir]")
}

peak_files <- list(
  mouse_specific           = args[1],
  human_specific           = args[2],
  conserved_mouse_in_human = args[3],
  conserved_human_in_mouse = args[4]
)

outdir <- if (length(args) >= 5) args[5] else "rGREAT_results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

genome_map <- list(
  mouse_specific           = "mm10",
  human_specific           = "hg38",
  conserved_mouse_in_human = "hg38",
  conserved_human_in_mouse = "mm10"
)

# -----------------------------
# 2. Safe BED reader (Fixes extra columns/format issues from HALPER)
# -----------------------------
read_bed3 <- function(file) {
  if (!file.exists(file)) stop(paste("File not found:", file))
  
  df <- read.table(file, header = FALSE, sep = "\t", stringsAsFactors = FALSE, quote = "")
  # Critical fix: Keep only the first 3 columns (chr, start, end)
  df <- df[, 1:3]
  colnames(df) <- c("chr", "start", "end")
  
  # Filter out non-standard chromosomes (e.g., unmapped contigs)
  df <- df[grepl("^chr([0-9]+|X|Y|M)$", df$chr), ]
  df$start <- as.numeric(df$start)
  df$end   <- as.numeric(df$end)
  
  GRanges(
    seqnames = df$chr,
    ranges   = IRanges(start = df$start + 1, end = df$end)
  )
}

# -----------------------------
# 3. Core GREAT runner function
# -----------------------------
run_great <- function(file, genome, name) {
  cat("\n========================================\n")
  cat(sprintf("Running analysis: %s (Genome: %s)\n", name, genome))
  cat("========================================\n")
  
  gr <- read_bed3(file)
  cat("Valid peaks count:", length(gr), "\n")
  
  # Extract GO:BP
  job_bp <- great(gr = gr, tss_source = genome, gene_sets = "GO:BP")
  tbl_bp <- getEnrichmentTable(job_bp)
  if (!is.null(tbl_bp) && nrow(tbl_bp) > 0) {
    write.table(tbl_bp, file.path(outdir, paste0(name, "_GO_BP.tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
  }
  
  # Additionally fetch GO:MF and GO:CC 
  tryCatch({
    job_mf <- great(gr = gr, tss_source = genome, gene_sets = "GO:MF")
    write.table(getEnrichmentTable(job_mf), file.path(outdir, paste0(name, "_GO_MF.tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
    
    job_cc <- great(gr = gr, tss_source = genome, gene_sets = "GO:CC")
    write.table(getEnrichmentTable(job_cc), file.path(outdir, paste0(name, "_GO_CC.tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
  }, error = function(e) { cat("Warning during MF/CC retrieval:", conditionMessage(e), "\n") })
  
  return(list(job = job_bp, table = tbl_bp))
}

# -----------------------------
# 4. Run GREAT for all datasets
# -----------------------------
results <- list()
for (name in names(peak_files)) {
  results[[name]] <- run_great(file = peak_files[[name]], genome = genome_map[[name]], name = name)
}

# -----------------------------
# 5. Standardize and Save All Significant Terms (Optional tracking)
# -----------------------------
standardize <- function(tb, label) {
  if (is.null(tb) || nrow(tb) == 0) return(NULL)
  term_col <- intersect(c("name", "term_name", "description", "id"), colnames(tb))[1]
  padj_col <- intersect(c("p_adjust", "adj_p_value", "fdr", "p_adjust_binom", "p_adjust_hyper"), colnames(tb))[1]
  enrich_col <- intersect(c("fold_enrichment", "enrichment", "fold_enrichment_binom", "fold_enrichment_hyper"), colnames(tb))[1]
  
  tb$term_name_final <- tb[[term_col]]
  tb$padj_final <- tb[[padj_col]]
  tb$fold_enrichment_final <- if (!is.na(enrich_col)) tb[[enrich_col]] else 1
  tb$dataset <- label
  return(tb)
}

dfs <- list()
for (name in names(results)) {
  df <- standardize(results[[name]]$table, name)
  if (!is.null(df)) dfs[[name]] <- df %>% filter(padj_final < 0.05)
}
combined_all <- bind_rows(dfs)
if(nrow(combined_all) > 0) {
  write.table(combined_all, file.path(outdir, "ALL_significant_terms_BP.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

# -----------------------------
# 6. Plotting (Modified for Publication Style, Aesthetic Color, and Adjusted Bubbles)
# -----------------------------
make_rgreat_plot <- function(tsv_file, task_name, top_n = 20) {
  enrich_tbl <- utils::read.delim(
    tsv_file,
    header = TRUE,
    sep = "\t",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  
  # Fallback mappings for different rGREAT versions to prevent "Missing column" errors
  if (!"description" %in% colnames(enrich_tbl) && "name" %in% colnames(enrich_tbl)) enrich_tbl$description <- enrich_tbl$name
  if (!"p_adjust" %in% colnames(enrich_tbl)) enrich_tbl$p_adjust <- enrich_tbl[[intersect(c("adj_p_value", "fdr", "p_adjust_binom"), colnames(enrich_tbl))[1]]]
  if (!"fold_enrichment" %in% colnames(enrich_tbl)) enrich_tbl$fold_enrichment <- enrich_tbl[[intersect(c("fold_enrichment_binom", "enrichment"), colnames(enrich_tbl))[1]]]
  if (!"observed_region_hits" %in% colnames(enrich_tbl)) enrich_tbl$observed_region_hits <- enrich_tbl[[intersect(c("observed_hits", "Count"), colnames(enrich_tbl))[1]]]
  
  required_cols <- c("description", "fold_enrichment", "observed_region_hits", "p_adjust")
  missing_cols <- setdiff(required_cols, colnames(enrich_tbl))
  
  if (length(missing_cols) > 0) {
    message("Skipping missing/invalid cols in ", tsv_file, ": ", paste(missing_cols, collapse = ", "))
    return(invisible(NULL))
  }
  
  enrich_tbl <- enrich_tbl[is.finite(enrich_tbl$p_adjust) & enrich_tbl$p_adjust > 0, , drop = FALSE]
  
  if (nrow(enrich_tbl) == 0) {
    message("Skipping empty/invalid file: ", tsv_file)
    return(invisible(NULL))
  }
  
  plot_tbl <- enrich_tbl[order(enrich_tbl$p_adjust, decreasing = FALSE), , drop = FALSE]
  plot_tbl <- utils::head(plot_tbl, top_n)
  plot_tbl$log10_p_adjust <- -log10(plot_tbl$p_adjust)
  
  # Wrapping long text to fit the plot nicely
  plot_tbl$description <- stringr::str_wrap(plot_tbl$description, width = 45)
  
  plot_tbl$description <- factor(
    plot_tbl$description,
    levels = rev(plot_tbl$description[order(plot_tbl$fold_enrichment, decreasing = FALSE)])
  )
  
  # Extract ontology name from filename (e.g., 'GO_BP' from 'mouse_specific_GO_BP.tsv')
  ontology_name <- sub("^.*_(GO_[A-Z]{2})\\.tsv$", "\\1", basename(tsv_file))
  
  # Create Plot (Publication Style)
  p <- ggplot(
    plot_tbl,
    aes(
      x = fold_enrichment,
      y = description,
      size = observed_region_hits,
      fill = log10_p_adjust
    )
  ) +
    # Use shape 21 for a border around points, increasing alpha slightly
    geom_point(alpha = 0.9, shape = 21, color = "black") +
    # MODIFIED: Slightly smaller bubble range (range = c(3, 8))
    scale_size_continuous(range = c(3, 8), name="Region hits") +
    # MODIFIED: Aesthetic color palette (Yellow-Orange-Red)
    scale_fill_distiller(palette = "YlOrRd", direction = 1, name="-log10(p_adjust)") +
    labs(
      title = paste0(task_name, " - ", ontology_name),
      x = "Fold enrichment",
      y = "GO Term (BP, MF, CC)"
    ) +
    # Switched to theme_classic() for a clean publication look
    theme_classic(base_size = 14) + # Increase base text size
    theme(
      axis.text.x = element_text(color="black"),
      axis.text.y = element_text(size = 10, color="black"), # Slightly smaller wrapped text
      axis.title = element_text(face="bold"),
      plot.title = element_text(hjust = 0.5, face="bold"),
      # Remove unnecessary background grid
      panel.grid.major = element_blank(), 
      panel.grid.minor = element_blank()
    )
  
  out_file <- file.path(
    dirname(tsv_file),
    paste0(task_name, "_", ontology_name, "_dotplot.png")
  )
  
  ggplot2::ggsave(out_file, p, width = 12, height = 8, dpi = 300)
  message("Saved plot: ", out_file)
}

# -----------------------------
# 7. Execute Plotting for all generated TSVs
# -----------------------------
top_n <- 20
cat("\n========================================\n")
cat("Generating plots...\n")
cat("========================================\n")

# Find all TSV files generated by GREAT (ignoring the merged summary table)
tsv_files <- list.files(path = outdir, full.names = TRUE, pattern = "_(GO_BP|GO_MF|GO_CC)\\.tsv$")

for (tsv_file in tsv_files) {
  # Dynamically extract task name (e.g., 'mouse_specific' from 'mouse_specific_GO_BP.tsv')
  task_name <- sub("_(GO_BP|GO_MF|GO_CC)\\.tsv$", "", basename(tsv_file))
  make_rgreat_plot(tsv_file, task_name = task_name, top_n = top_n)
}

message("\nDone. Processed ", length(tsv_files), " TSV file(s) and saved to: ", outdir)