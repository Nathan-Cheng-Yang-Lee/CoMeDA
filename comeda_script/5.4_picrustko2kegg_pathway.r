#! /usr/bin/Rscript

## convert KO abundance to KEGG pathway abundance using ggpicrust2
## generate on 2025.10.14

library(ggpicrust2)
library(tidyverse)

args <- commandArgs(TRUE)

ko.df <- args[1]
outfile <- args[2]

## check input file
if (!file.exists(ko.df)) {
	stop("ERROR: Input KO file not found: ", ko.df)
}

## read and convert KO to KEGG pathway
cat("Reading KO abundance table...\n")
ko.path.abund <- ko2kegg_abundance(file = ko.df)
colnames(ko.path.abund) <- gsub("-", ".", colnames(ko.path.abund))

## format and write output
cat("Writing KEGG pathway abundance table...\n")
write.table(
	ko.path.abund %>% 
		dplyr::arrange(row.names(.)) %>% 
		rownames_to_column("pathway.id"), 
	outfile, 
	sep = "\t", 
	col.names = TRUE, 
	row.names = FALSE, 
	quote = FALSE
)

cat("Conversion completed!\n")
cat("Output file:", outfile, "\n")
