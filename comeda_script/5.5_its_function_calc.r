#! /usr/bin/Rscript

## Calculate pathway/function abundance from FUNFUN results and feature table
## Matrix multiplication: [Function × ASV] × [ASV × Sample] = [Function × Sample]
## generate on 2025.10.14

library(tidyverse)

args <- commandArgs(TRUE)

if (length(args) < 3) {
	stop("Usage: script.r <function_asv_matrix> <asv_sample_table> <output_file>")
}

func_asv_file <- args[1]
asv_samp_file <- args[2]
output_file <- args[3]

## check input files
if (!file.exists(func_asv_file)) {
	stop("ERROR: Function × ASV matrix not found: ", func_asv_file)
}

if (!file.exists(asv_samp_file)) {
	stop("ERROR: ASV × Sample table not found: ", asv_samp_file)
}

## read data
cat("Reading Function × ASV matrix...\n")
func_asv <- read.table(func_asv_file, sep = "\t", header = TRUE, row.names = 1) %>% 
	as.matrix()

cat("Reading ASV × Sample table...\n")
asv_samp <- read.table(asv_samp_file, sep = "\t", header = TRUE, row.names = 1) %>% 
	as.matrix()

## check dimensions
cat("\nMatrix dimensions:\n")
cat("  Function × ASV:", dim(func_asv), "\n")
cat("  ASV × Sample:", dim(asv_samp), "\n")

## find common ASVs
common_asvs <- intersect(colnames(func_asv), rownames(asv_samp))

if (length(common_asvs) == 0) {
	stop("ERROR: No common ASVs found between function matrix and feature table!")
}

cat("\nCommon ASVs:", length(common_asvs), "\n")

## subset to common ASVs
func_asv <- func_asv[, common_asvs, drop = FALSE]
asv_samp <- asv_samp[common_asvs, , drop = FALSE]

## matrix multiplication
cat("\nPerforming matrix multiplication...\n")
func_samp <- func_asv %*% asv_samp

cat("  Result dimension:", dim(func_samp), "\n")

## write output
cat("\nWriting output to:", output_file, "\n")
write.table(
	func_samp %>% 
		data.frame(check.names = F) %>% 
		dplyr::mutate(function.id = row.names(.)) %>% 
		dplyr::relocate(function.id, .before = dplyr::everything()), 
	output_file, 
	sep = "\t", 
	col.names = TRUE, 
	row.names = FALSE, 
	quote = FALSE
)

cat("Calculation completed!\n")
