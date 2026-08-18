#!/usr/bin/Rscript

################################################################################
# File    : 6.1_crossdomaincorrelation_wReport.r
# Purpose : Cross-domain/Paired correlation analysis between two datasets
#           Calculates correlations and prepares node info (Case vs Control)
# Author  : CoMeDA Pipeline
# Date    : 2025.12.15
# Version : 2.4 (Added parameters_info.txt update with Detection Info)
################################################################################

library(tidyverse)

# Parse command line arguments
args <- commandArgs(TRUE)

scriptpath <- args[1]           # Path to script directory
bacteria_rdata <- args[2]       # Path to Dataset1 (bacteria/16S) CoMeDA.Rdata
fungi_rdata <- args[3]          # Path to Dataset2 (fungi/ITS) CoMeDA.Rdata
taxalevels <- args[4]           # Comma-separated taxa levels
bacteria_prevcut <- as.numeric(args[5])
fungi_prevcut <- as.numeric(args[6])
compinfopath <- args[7]         # Path to comparison info table
outputpath <- args[8]           # Output directory path

# Parse taxa levels
taxalevels <- strsplit(taxalevels, ",")[[1]] %>% trimws()

# Load required functions
source(paste0(scriptpath, "/fastCCLasso_CLR.R"))
source(paste0(scriptpath, "/crossdomain.function.R"))

# Load comparison info table
compinfotable <- read.table(compinfopath, header = TRUE, sep = "\t", 
                            comment.char = "", stringsAsFactors = FALSE)

cat("\n========================================\n")
cat("Cross-Dataset Correlation Analysis v2.4\n")
cat("========================================\n")

################################################################################
# Step 1: Load Data
################################################################################

cat("Step 1: Loading data...\n")

# Load Dataset1 (bacteria/16S) results
ds1_env <- new.env()
load(bacteria_rdata, envir = ds1_env)
ds1.batch.correct.res <- ds1_env$batch.correct.res
ds1.filtered.meta <- ds1_env$filtered.meta
ds1.abd_prev.res <- ds1_env$abd_prev.res
ds1.prop_source <- ds1_env$comeda_prop_source          # [2026-08-12] Mode A 來源檢查
rm(ds1_env)

# Load Dataset2 (fungi/ITS) results
ds2_env <- new.env()
load(fungi_rdata, envir = ds2_env)
ds2.batch.correct.res <- ds2_env$batch.correct.res
ds2.filtered.meta <- ds2_env$filtered.meta
ds2.abd_prev.res <- ds2_env$abd_prev.res
ds2.prop_source <- ds2_env$comeda_prop_source          # [2026-08-12] Mode A 來源檢查
rm(ds2_env)

## [2026-08-12] 檢查兩個 CoMeDA.Rdata 的 proportion 來源。舊版（4.2 更新前）以 raw counts closure
## 計算 median/prevalence，缺 comeda_prop_source 標記；此時 hover 顯示與網路 taxa 過濾非 ALDEx2 基準，
## 與 within-domain 不一致。建議以新版 4.2 重跑各 dataset 後再做 cross-domain。
for (.ds in list(c("Dataset1(bacteria)", ds1.prop_source), c("Dataset2(fungi)", ds2.prop_source))) {
  if (is.null(.ds[[2]]) || !grepl("^aldex.prop_renorm", as.character(.ds[[2]]))) {
    warning(sprintf("[proportion 來源] %s 的 CoMeDA.Rdata 為舊版（median/prevalence 來源=%s），非 renormalized ALDEx2 proportion；建議以新版 4.2 重跑後再跑 cross-domain。",
                    .ds[[1]], ifelse(is.null(.ds[[2]]), "raw(未標記)", as.character(.ds[[2]]))))
  }
}

# Ensure Matrix Format
for (lvl in names(ds1.batch.correct.res)) {
  if (!is.null(ds1.batch.correct.res[[lvl]][["correctedTable"]])) 
    ds1.batch.correct.res[[lvl]][["correctedTable"]] <- as.matrix(ds1.batch.correct.res[[lvl]][["correctedTable"]])
}
for (lvl in names(ds2.batch.correct.res)) {
  if (!is.null(ds2.batch.correct.res[[lvl]][["correctedTable"]])) 
    ds2.batch.correct.res[[lvl]][["correctedTable"]] <- as.matrix(ds2.batch.correct.res[[lvl]][["correctedTable"]])
}

################################################################################
# [NEW v2.4] Track Detection Info for parameters_info.txt
################################################################################
detection_info <- list(
  analysis_type = "Unknown",
  overlapping_samples = 0,
  overlapping_taxa = 0,
  is_paired = FALSE
)

################################################################################
# Step 2: Main Analysis Loop
################################################################################

crossdomain.corr.res <- list()

for (lvl in taxalevels) {
  
  cat("Processing Level:", lvl, "\n")
  crossdomain.corr.res[[lvl]] <- list()
  
  if (!lvl %in% names(ds1.batch.correct.res) || !lvl %in% names(ds2.batch.correct.res)) next
  
  # Find Overlapping Samples
  ds1_samps <- rownames(ds1.batch.correct.res[[lvl]][["correctedTable"]])
  ds2_samps <- rownames(ds2.batch.correct.res[[lvl]][["correctedTable"]])
  overlap_samples <- intersect(ds1_samps, ds2_samps)
  
  # [NEW v2.4] Update detection info
  detection_info$overlapping_samples <- max(detection_info$overlapping_samples, length(overlap_samples))
  
  if (length(overlap_samples) < 5) {
    warning(paste("Insufficient overlapping samples for", lvl))
    next
  }
  
  # [NEW v2.3] Detect if Paired Analysis is needed (taxa overlap)
  ds1_all_taxa <- colnames(ds1.batch.correct.res[[lvl]][["correctedTable"]])
  ds2_all_taxa <- colnames(ds2.batch.correct.res[[lvl]][["correctedTable"]])
  taxa_overlap <- intersect(ds1_all_taxa, ds2_all_taxa)
  
  # [NEW v2.4] Update detection info
  detection_info$overlapping_taxa <- max(detection_info$overlapping_taxa, length(taxa_overlap))
  
  is_paired_analysis <- length(taxa_overlap) > 0
  if (is_paired_analysis) {
    cat("  [INFO] Detected overlapping taxa (", length(taxa_overlap), 
        ") - Using DS1_/DS2_ prefix for Paired Analysis mode\n")
    detection_info$is_paired <- TRUE
    detection_info$analysis_type <- paste0("Paired Analysis (", length(taxa_overlap), " overlapping taxa)")
  } else {
    cat("  [INFO] No taxa overlap - Using standard Cross-Kingdom mode\n")
    if (!detection_info$is_paired) {
      detection_info$analysis_type <- "Cross-Kingdom (No taxa overlap)"
    }
  }
  
  for (compcol in colnames(compinfotable)) {
    
    crossdomain.corr.res[[lvl]][[compcol]] <- list()
    
    # Get Reference Group Name
    ref_group <- as.character(compinfotable[1, compcol])
    
    ds1_meta <- ds1.filtered.meta[[lvl]][overlap_samples, , drop=F]
    ds2_meta <- ds2.filtered.meta[[lvl]][overlap_samples, , drop=F]
    
    if (!compcol %in% colnames(ds1_meta) || !compcol %in% colnames(ds2_meta)) next
    
    # Identify Common Events
    common_events <- intersect(unique(ds1_meta[[compcol]]), unique(ds2_meta[[compcol]]))
    common_events <- common_events[!is.na(common_events)]
    
    if (length(common_events) == 0) next

    # [NEW] Reorder: Put ref_group first, then other events
    if (ref_group %in% common_events) {
      other_events <- setdiff(common_events, ref_group)
      common_events <- c(ref_group, sort(other_events))
    } else {
      common_events <- sort(common_events)
    }
    
    for (evt in common_events) {
      
      cat("  Event:", evt, "\n")
      
      # 1. Filter Samples for Event
      evt_samps <- overlap_samples[ds1_meta[[compcol]] == evt & ds2_meta[[compcol]] == evt]
      if (length(evt_samps) < 5) next
      
      # 2. Filter Taxa by Prevalence (using Case/Event prevalence)
      # Define Column Names for Extraction
      # Case (Event)
      case_prop_col <- paste0("median.prop.", evt)
      case_prev_col <- paste0("prev.", evt)
      
      # Control (Reference)
      ref_prop_col <- paste0("median.prop.", ref_group)
      ref_prev_col <- paste0("prev.", ref_group)
      
      # Dataset1 Filtering & Info Extraction
      if (!case_prev_col %in% colnames(ds1.abd_prev.res[[lvl]][[compcol]])) next
      ds1_stats_df <- ds1.abd_prev.res[[lvl]][[compcol]]
      ds1_keep <- rownames(ds1_stats_df)[ds1_stats_df[[case_prev_col]] >= bacteria_prevcut]
      
      # Dataset2 Filtering & Info Extraction
      if (!case_prev_col %in% colnames(ds2.abd_prev.res[[lvl]][[compcol]])) next
      ds2_stats_df <- ds2.abd_prev.res[[lvl]][[compcol]]
      ds2_keep <- rownames(ds2_stats_df)[ds2_stats_df[[case_prev_col]] >= fungi_prevcut]
      
      if (length(ds1_keep) < 3 || length(ds2_keep) < 3) next
      
      # [NEW v2.3] Apply prefix if Paired Analysis mode
      if (is_paired_analysis) {
        ds1_keep_prefixed <- paste0("DS1_", ds1_keep)
        ds2_keep_prefixed <- paste0("DS2_", ds2_keep)
        
        # Create mapping for original names
        ds1_name_map <- setNames(ds1_keep, ds1_keep_prefixed)
        ds2_name_map <- setNames(ds2_keep, ds2_keep_prefixed)
      } else {
        ds1_keep_prefixed <- ds1_keep
        ds2_keep_prefixed <- ds2_keep
        ds1_name_map <- setNames(ds1_keep, ds1_keep)
        ds2_name_map <- setNames(ds2_keep, ds2_keep)
      }
      
      # 3. Prepare Node Info (Case & Control Stats)
      
      # Helper to extract stats
      # Helper to extract stats for ALL groups
      extract_stats_all_groups <- function(df, taxa, taxa_prefixed, domain, all_groups) {
        sub_df <- df[taxa, , drop=FALSE]
        
        # Base info
        out <- data.frame(
          taxon = taxa_prefixed,
          original_name = taxa,
          domain = domain,
          stringsAsFactors = FALSE
        )
        
        # Add prop/prev for each group
        for (grp in all_groups) {
          prop_col <- paste0("median.prop.", grp)
          prev_col <- paste0("prev.", grp)
          
          # Sanitize group name for column naming (replace spaces/special chars)
          grp_safe <- gsub("[^A-Za-z0-9]", "_", grp)
          
          out[[paste0("prop_", grp_safe)]] <- if (prop_col %in% colnames(sub_df)) sub_df[[prop_col]] else NA
          out[[paste0("prev_", grp_safe)]] <- if (prev_col %in% colnames(sub_df)) sub_df[[prev_col]] else NA
        }
        
        return(out)
      }
      
      ds1_info <- extract_stats_all_groups(ds1_stats_df, ds1_keep, ds1_keep_prefixed, "Dataset1", common_events)
      ds2_info <- extract_stats_all_groups(ds2_stats_df, ds2_keep, ds2_keep_prefixed, "Dataset2", common_events)
      
      node_info_df <- rbind(ds1_info, ds2_info)
      rownames(node_info_df) <- node_info_df$taxon

      # 4. Prepare CLR Data
      ds1_clr <- ds1.batch.correct.res[[lvl]][["correctedTable"]][evt_samps, ds1_keep, drop=F]
      ds2_clr <- ds2.batch.correct.res[[lvl]][["correctedTable"]][evt_samps, ds2_keep, drop=F]
      
      # [NEW v2.3] Rename columns with prefix if Paired Analysis
      if (is_paired_analysis) {
        colnames(ds1_clr) <- ds1_keep_prefixed
        colnames(ds2_clr) <- ds2_keep_prefixed
      }
      
      merged_clr <- cbind(as.matrix(ds1_clr), as.matrix(ds2_clr))
      
      # 5. Run Correlation (FastCCLasso)
      set.seed(1223)
      res <- tryCatch({
        fastCCLasso_CLR(
          clr_data = merged_clr,
          k_cv = 3,
          lam_min_ratio = 1E-4,
          k_max = 20,
          n_boot = 100
        )
      }, error=function(e) NULL)
      
      if (!is.null(res)) {
        corr_mat <- res$correlation_matrix
        raw_p_mat <- res$p_values
        
        # Add names (already prefixed if Paired Analysis)
        rownames(corr_mat) <- colnames(corr_mat) <- colnames(merged_clr)
        rownames(raw_p_mat) <- colnames(raw_p_mat) <- colnames(merged_clr)
        
        # Mask Within-Dataset Correlations (Keep only Cross-Dataset)
        n_ds1 <- length(ds1_keep_prefixed)
        n_tot <- ncol(merged_clr)
        p_mat <- adjust_fastCCLasso_pvalues(
          raw_p_mat,
          scope = "cross_block",
          split_index = n_ds1,
          method = "BH"
        )
        rownames(p_mat) <- colnames(p_mat) <- colnames(merged_clr)
        
        corr_mat[1:n_ds1, 1:n_ds1] <- NA
        raw_p_mat[1:n_ds1, 1:n_ds1] <- NA
        p_mat[1:n_ds1, 1:n_ds1] <- NA
        
        corr_mat[(n_ds1+1):n_tot, (n_ds1+1):n_tot] <- NA
        raw_p_mat[(n_ds1+1):n_tot, (n_ds1+1):n_tot] <- NA
        p_mat[(n_ds1+1):n_tot, (n_ds1+1):n_tot] <- NA
        
        # Round
        corr_mat <- round(corr_mat, 6)
        raw_p_mat <- round(raw_p_mat, 6)
        p_mat <- round(p_mat, 6)
        
        # Store Result
	crossdomain.corr.res[[lvl]][[compcol]][[evt]] <- list(
          correlationTable = corr_mat,
          p.value = p_mat,
          raw.p.value = raw_p_mat,
          node_info = node_info_df, # Contains all groups stats + original_name
          metadata = list(
            ds1_taxa = ds1_keep_prefixed,
            ds2_taxa = ds2_keep_prefixed,
            bacteria_taxa = ds1_keep_prefixed,
            fungi_taxa = ds2_keep_prefixed,
            n_ds1 = n_ds1,
            n_ds2 = length(ds2_keep_prefixed),
            n_bacteria = n_ds1,
            n_fungi = length(ds2_keep_prefixed),
            ref_group = ref_group,
            all_groups = common_events,
            is_paired_analysis = is_paired_analysis,
            ds1_name_map = ds1_name_map,
            ds2_name_map = ds2_name_map,
            fastCCLasso_k_cv = 3,
            fastCCLasso_n_boot = 100,
            edge_p_adjust_method = "BH",
            edge_p_adjust_scope = "cross-dataset pairs only",
            default_edge_adjusted_p_cutoff = 0.05,
            default_edge_abs_correlation_cutoff = 0.3
          )
        )
      }
    }
  }
}

################################################################################
# Step 3: Save Results
################################################################################

if (!dir.exists(outputpath)) dir.create(outputpath, recursive = TRUE)
save(crossdomain.corr.res, file = file.path(outputpath, "crossdomain.Rdata"))

################################################################################
# [NEW v2.4] Step 4: Update parameters_info.txt with Detection Info
################################################################################

param_info_file <- file.path(outputpath, "parameters_info.txt")
batch_methods_file <- file.path(outputpath, "batch_methods.txt")

format_batch_kv_lines <- function(lines, taxalevels) {
  if (length(lines) == 0) return(character(0))

  parsed <- lapply(lines, function(x) {
    m <- regexec("^(16S|ITS)\\s*\\(([^)]+)\\)\\s*=\\s*(.+)$", x)
    r <- regmatches(x, m)[[1]]
    if (length(r) != 4) return(NULL)
    list(domain = r[2], level = trimws(r[3]), method = trimws(r[4]))
  })
  parsed <- parsed[!vapply(parsed, is.null, logical(1))]
  if (length(parsed) == 0) return(character(0))

  df <- bind_rows(lapply(parsed, as.data.frame))

  # Order: 16S -> ITS; taxa level follows the user-requested taxalevels order (if present)
  df$domain_order <- match(df$domain, c("16S", "ITS"))
  df$level_order  <- match(df$level, taxalevels)
  df$level_order[is.na(df$level_order)] <- 999

  df <- df %>% arrange(domain_order, level_order)

  kv <- paste0("Batch Correction - ", df$domain, " (", df$level, "): ", df$method)
  return(kv)
}

batch_kv_lines <- character(0)
if (file.exists(batch_methods_file)) {
  raw_lines <- readLines(batch_methods_file, warn = FALSE)
  raw_lines <- raw_lines[nzchar(trimws(raw_lines))]
  batch_kv_lines <- format_batch_kv_lines(raw_lines, taxalevels)
}

if (file.exists(param_info_file)) {
  existing_lines <- readLines(param_info_file, warn = FALSE)

  updated_lines <- c()
  in_detection <- FALSE
  in_params <- FALSE
  injected_params <- FALSE

  for (line in existing_lines) {

    # -----------------------------
    # Replace [Detection Info] block
    # -----------------------------
    if (grepl("^\\[Detection Info\\]", line)) {
      updated_lines <- c(
        updated_lines,
        "[Detection Info]",
        paste0("Analysis Type: ", detection_info$analysis_type),
        paste0("Overlapping Samples: ", detection_info$overlapping_samples),
        paste0("Overlapping Taxa: ", detection_info$overlapping_taxa),
        ""
      )
      in_detection <- TRUE
      next
    }
    if (in_detection) {
      if (grepl("^\\[", line) || grepl("^=+$", line)) {
        in_detection <- FALSE
        updated_lines <- c(updated_lines, line)
      }
      next
    }

    # ---------------------------------------
    # Update [Analysis Parameters] block
    # (inject Batch Correction lines; dedupe)
    # ---------------------------------------
    if (grepl("^\\[Analysis Parameters\\]", line)) {
      updated_lines <- c(updated_lines, line)
      in_params <- TRUE
      next
    }

    if (in_params) {
      # End of section -> inject batch lines before next section
      if (grepl("^\\[", line) && !grepl("^\\[Analysis Parameters\\]", line)) {
        if (!injected_params && length(batch_kv_lines) > 0) {
          updated_lines <- c(updated_lines, batch_kv_lines)
          injected_params <- TRUE
        }
        updated_lines <- c(updated_lines, "", line)
        in_params <- FALSE
        next
      }

      # Skip existing Batch Correction lines to avoid duplicates
      if (!grepl("^Batch Correction\\s*-", line)) {
        updated_lines <- c(updated_lines, line)
      }
      next
    }

    updated_lines <- c(updated_lines, line)
  }

  # If file ends while still inside [Analysis Parameters], inject at the end
  if (in_params && !injected_params && length(batch_kv_lines) > 0) {
    updated_lines <- c(updated_lines, batch_kv_lines, "")
  }

  writeLines(updated_lines, param_info_file)
  cat("Updated parameters_info.txt with Detection Info + Batch Correction\n")

} else {
  # Create new parameters_info.txt if it doesn't exist
  new_lines <- c(
    "================================================================================",
    "Cross-Dataset Correlation Analysis - Parameters Summary",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "================================================================================",
    "",
    "[Analysis Mode]",
    "Mode: (Generated by R script)",
    "",
    "[Dataset 1]",
    paste0("Source: ", bacteria_rdata),
    "",
    "[Dataset 2]",
    paste0("Source: ", fungi_rdata),
    "",
    "[Analysis Parameters]",
    paste0("Taxa Levels: ", paste(taxalevels, collapse = ", ")),
    paste0("Dataset1 Min Prevalence: ", bacteria_prevcut),
    paste0("Dataset2 Min Prevalence: ", fungi_prevcut),
    if (length(batch_kv_lines) > 0) batch_kv_lines else NULL,
    "",
    "[Detection Info]",
    paste0("Analysis Type: ", detection_info$analysis_type),
    paste0("Overlapping Samples: ", detection_info$overlapping_samples),
    paste0("Overlapping Taxa: ", detection_info$overlapping_taxa),
    "",
    "================================================================================"
  )

  new_lines <- unlist(new_lines)
  writeLines(new_lines, param_info_file)
  cat("Created parameters_info.txt with Detection Info + Batch Correction\n")
}

cat("\nAnalysis Completed.\n")
