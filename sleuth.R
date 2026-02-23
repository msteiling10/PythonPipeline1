library(sleuth)
library(yaml)

config <- yaml::read_yaml("config.yaml")

samples <- names(config$samples)
conditions <- sapply(samples, function(s) config$conditions[[s]])
donors <- sapply(samples, function(s) config$donors[[s]])
kallisto_dirs <- file.path("results/kallisto_quant", samples)

cds_count <- as.integer(readLines("results/_cds_count.txt"))

s2c <- data.frame(
  sample = samples,
  condition = conditions,
  donor = donors,
  path = kallisto_dirs,
  stringsAsFactors = FALSE
)

# Paired design
so <- sleuth_prep(s2c, ~ donor + condition)
so <- sleuth_fit(so, ~ donor + condition, 'full')
so <- sleuth_wt(so, 'condition6dpi')

results_table <- sleuth_results(so, 'condition6dpi', 'wt')

sig_results <- results_table[
  results_table$qval < 0.05,
  c("target_id", "b", "pval", "qval")
]

colnames(sig_results)[2] <- "test_stat"

# Write report
out_file <- config$report_file
dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)

f <- file(out_file, "w")
writeLines(sprintf("The HCMV genome (GCF_000845245.1) has %d CDS.", cds_count), f)
close(f)

write.table(
  sig_results,
  file = out_file,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  col.names = TRUE,
  append = TRUE
)

