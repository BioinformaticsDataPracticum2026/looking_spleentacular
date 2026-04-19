if (!requireNamespace("tidyverse", quietly = TRUE)) {
  stop("tidyverse is not installed. Please install it on a login node.")
}

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1) {
  stop("Usage: Rscript motif_table.R <top_n>")
}

filtered_dir <- "filtered_annotations"
top_n        <- if (length(args) == 1) as.integer(args[1]) else 5L
output       <- "top_motifs"

# --- Parsers ---
parse_header <- function(h) {
  fields <- strsplit(sub("^>", "", h), "\t")[[1]]
  
  name_string <- fields[2]
  log_pval    <- as.numeric(fields[4])
  
  stats       <- fields[6]
  target_hits <- as.numeric(sub("T:([0-9.]+).*", "\\1", stats))
  target_pct  <- sub(".*T:[0-9.]+\\(([0-9.]+%)\\).*", "\\1", stats)
  bg_hits     <- as.numeric(sub(".*B:([0-9.]+).*", "\\1", stats))
  bg_pct      <- sub(".*B:[0-9.]+\\(([0-9.]+%)\\).*", "\\1", stats)
  pval        <- sub(".*P:(\\S+)", "\\1", stats)
  
  tibble(name_string, log_pval, pval, target_hits, target_pct, bg_hits, bg_pct)
}

process_sample <- function(peaks_file) {
  sample      <- tools::file_path_sans_ext(basename(peaks_file))
  motif_file  <- file.path("homer_results", sample, "motifs", "nonRedundant.motifs")
  
  if (!file.exists(motif_file)) {
    warning("No nonRedundant.motifs found for sample: ", sample, " -- skipping")
    return(NULL)
  }
  
  # Parse motif file
  lines        <- readLines(motif_file)
  header_lines <- lines[startsWith(lines, ">")]
  
  motif_table <- map(header_lines, parse_header) %>%
    bind_rows() %>%
    arrange(desc(target_hits)) %>%
    slice_head(n = top_n)
  
  # Parse filtered peaks file
  peaks     <- read_tsv(peaks_file, show_col_types = FALSE)
  motif_cols <- setdiff(colnames(peaks), c("PeakID", "Annotation"))
  
  get_annotations <- function(name_string) {
    matching_col <- motif_cols[str_detect(motif_cols, fixed(name_string))]
    
    if (length(matching_col) == 0) return(NA_character_)
    
    peaks %>%
      filter(!is.na(.data[[matching_col[1]]]) & .data[[matching_col[1]]] != "") %>%
      pull(Annotation) %>%
      unique() %>%
      sort() %>%
      paste(collapse = ", ")
  }
  
   motif_table %>%
    mutate(annotations = map_chr(name_string, get_annotations)) %>%
    write_tsv(file.path(filtered_dir, paste0(sample, "_motif_table.tsv")))

    cat("Written:", file.path(filtered_dir, paste0(sample, "_motif_table.tsv")), "\n")
}

# --- Run across all files in filtered_annotations dir ---
peaks_files <- list.files(filtered_dir, pattern = "\\.txt$", full.names = TRUE)

if (length(peaks_files) == 0) {
  stop("No .txt files found in: ", filtered_dir)
}

walk(peaks_files, process_sample)