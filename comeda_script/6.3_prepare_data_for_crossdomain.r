#! /usr/bin/Rscript

## 6.3_prepare_data_for_crossdomain.r
## Purpose: Prepare standardized CoMeDA.Rdata from Raw Uploads (Mode B)
## Logic: Strictly follows 4.2_metagenomicanalysis.r workflow
## Updated: 2025.12.06 (Removed extra args for compatibility)

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(ALDEx2))
suppressPackageStartupMessages(library(PLSDAbatch))

args <- commandArgs(TRUE)
if(length(args) < 10) stop("Insufficient arguments provided to 6.3 script.")

table_path <- args[1]; meta_path <- args[2]; comp_info_path <- args[3]
taxa_level_str <- args[4]; out_path <- args[5]; data_type <- args[6]
prop_cut <- as.numeric(args[7]); batch_col <- args[8]
method_out_path <- args[9]; scriptpath <- args[10]

source(paste0(scriptpath, "/analysis.function.R"))

# Read Data
raw.taxatable <- read.table(table_path, header=T, sep="\t", comment.char="", check.names=F)
colnames(raw.taxatable) <- gsub("-", ".", colnames(raw.taxatable)) # Normalize sample names

raw.metadata <- read.table(meta_path, header=T, sep="\t", comment.char="", row.names=1)
rownames(raw.metadata) <- gsub("-", ".", rownames(raw.metadata))

compinfotable <- read.table(comp_info_path, header=T, sep="\t", comment.char="", check.names=F)
taxalevels <- strsplit(taxa_level_str, ",")[[1]] %>% trimws()
primarycomp <- colnames(compinfotable)[1]
primarycompref <- as.character(compinfotable[1, 1])

# Step 1: Aggregate
agg.taxatable <- aggregate_taxa(raw.taxatable, levels = taxalevels)
agg.taxatable <- lapply(agg.taxatable, function(x) round(x))

aldex.clr <- list(); aldex.prop <- list()
batch.correct.res <- list(); filtered.meta <- list(); abd_prev.res <- list()
batch_methods_log <- c()

for (lvl in taxalevels) {
  # Step 2: CLR
  mat <- as.matrix(agg.taxatable[[lvl]]); cond <- rep(1, ncol(mat))
  aldexdenom <- "iqlr"
  aldex.res <- tryCatch({
    ALDEx2::aldex.clr(mat, cond, mc.samples = 128, denom = aldexdenom, verbose = FALSE)
  }, error = function(e) {
    record_parameter_adjustment("aldexdenom", "median", aldexdenom, "ALDEx2 failed (Mode B)")
    ALDEx2::aldex.clr(mat, cond, mc.samples = 128, denom = "median", verbose = FALSE)
  })
  
  mc.clr <- ALDEx2::getMonteCarloInstances(aldex.res)
  median.clr <- t(sapply(mc.clr, function(x) apply(x, 1, median)))
  aldex.clr[[lvl]] <- median.clr
  
  mc.prop <- ALDEx2::getDirichletInstances(aldex.res)
  ## [2026-08-12] marginal median 後逐樣本重新正規化至總和為 1（與 within-domain 4.2 一致）
  median.prop <- t(sapply(mc.prop, function(x) apply(x, 1, median)))
  median.prop <- median.prop / rowSums(median.prop)
  aldex.prop[[lvl]] <- median.prop
  
  # Step 3: Batch Correction
  # ------------------------------------------------------------------
  # 3.1 Align Data and Metadata
  common <- intersect(rownames(median.clr), rownames(raw.metadata))
  curr_meta <- raw.metadata[common, , drop=FALSE]
  curr_meta <- curr_meta[match(common, rownames(curr_meta)), , drop=FALSE]
  filtered.meta[[lvl]] <- curr_meta
  
  # 3.2 Determine Batch Method Logic
  # Default to "nobatches" unless batch_col exists and is valid
  est_method <- "nobatches"
  
  # Check if batch_col is specified (not "none") AND actually exists in metadata
  if (batch_col != "none" && batch_col %in% colnames(curr_meta)) {
    
    # Call the updated v3 classify_batchtype function
    # Note: The new function returns a LIST (final_type, diagnostics, params)
    class_res <- classify_batchtype(median.clr, curr_meta, batch_col, primarycomp)
    
    # Extract the method string (e.g., "uw_plsda", "w_splsda", "nobatches")
    est_method <- class_res$final_type
  }
  
  # Log the decision
  batch_methods_log <- c(batch_methods_log, paste0(data_type, " (", lvl, ") = ", est_method))
  
  # 3.3 Execute Correction
  if (est_method == "nobatches") {
    # If no correction needed, store original CLR
    batch.correct.res[[lvl]] <- list(correctedTable = median.clr)
  } else {
    # If correction needed, pass the v3 method string directly to plsda_correction
    # The updated plsda_correction function now handles "uw_plsda", "w_splsda" etc. internally
    res <- plsda_correction(
      clr = median.clr, 
      metadata = curr_meta, 
      batchcol = batch_col, 
      compcol = primarycomp, 
      compref = primarycompref, 
      bctype = est_method 
    )
    batch.correct.res[[lvl]] <- res
  }

  # Step 5: Prevalence
  ## [2026-08-12] median/prevalence 改由 renormalized ALDEx2 proportion（aldex.prop[[lvl]]，Dirichlet 中位後
  ## 逐樣本正規化）計算，與 within-domain 4.2 一致；原用 raw counts closure（raw_prop）。
  abd_prev.res[[lvl]] <- list()
  for (compcol in colnames(compinfotable)) {
    if (!compcol %in% colnames(curr_meta)) next
    compref_val <- as.character(compinfotable[1, compcol])
    stats <- calculate_taxa_stats(prop = aldex.prop[[lvl]], meta = curr_meta, compcol = compcol, compref = compref_val, prop_cutoff = prop_cut)
    abd_prev.res[[lvl]][[compcol]] <- stats
  }
}

save_parameter_adjustments(out_path)
if(length(batch_methods_log) > 0) writeLines(batch_methods_log, method_out_path)
dam.res <- list(); corr.res <- list()
## [2026-08-12] proportion 來源標記（同 4.2），供 6.1 Mode A 載入時檢查。
comeda_prop_source <- "aldex.prop_renorm_v20260812"
save(raw.taxatable, agg.taxatable, aldex.clr, aldex.prop, raw.metadata, filtered.meta, batch.correct.res, dam.res, corr.res, abd_prev.res, comeda_prop_source, file = paste0(out_path, "/CoMeDA.Rdata"))
