if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 is not installed. Please install it on a login node.")
}
library(ggplot2)

file_list <- list.files(path = "filtered_annotations", pattern = "\\.txt$", full.names = TRUE)

for (file in file_list) {
  peaks <- sub(".*/([^.]+)\\..*", "\\1", file)
  output_filename <- paste0(tools::file_path_sans_ext(file), ".png")
  df <- read.delim(file, header = TRUE)
  ggplot(df, aes(x = Annotation, fill = Annotation)) + geom_bar() + labs(title = peaks) + theme(legend.position = "none")
  ggsave(output_filename)
}
