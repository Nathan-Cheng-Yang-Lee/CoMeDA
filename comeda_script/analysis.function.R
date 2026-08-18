## ========================================================================
## Global Parameter Adjustment Tracking
## For recording parameter adjustments during analysis execution
## ========================================================================

# Initialize global list to store adjustments
.param_adjustments <- list()

# Function to record parameter adjustment
record_parameter_adjustment <- function(parameter, adjusted_value, original_value, 
                                       reason, layer = "R_Function") {
  
  adjustment <- list(
    parameter = parameter,
    adjusted_value = as.character(adjusted_value),
    original_value = as.character(original_value),
    reason = reason,
    layer = layer,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  
  # Append to global list
  .param_adjustments <<- c(.param_adjustments, list(adjustment))
  
  # Also print to console for immediate visibility
  cat(sprintf("\n[PARAMETER ADJUSTMENT] %s: %s -> %s (%s)\n", 
              parameter, original_value, adjusted_value, reason))
  
  return(invisible(TRUE))
}

# Function to save adjustments to file (called at end of analysis)
save_parameter_adjustments <- function(output_path) {
  
  if (length(.param_adjustments) == 0) {
    cat("[INFO] No parameter adjustments to save\n")
    return(invisible(FALSE))
  }
  
  params_file <- paste0(output_path, "/parameters_info.txt")
  
  tryCatch({
    
    # Prepare SECTION 2 content
    section2_lines <- c(
      "",
      "# [SECTION 2: ADJUSTED PARAMETERS]",
      "# Parameters automatically adjusted during execution",
      "# Format: parameter | adjusted_value | original_value | reason | timestamp",
      "#"
    )
    
    # Add each adjustment
    for (i in seq_along(.param_adjustments)) {
      adj <- .param_adjustments[[i]]
      section2_lines <- c(
        section2_lines,
        paste0("# ADJUSTMENT_", i),
        "parameter\tadjusted_value\toriginal_value\treason\ttimestamp",
        paste(adj$parameter, adj$adjusted_value, adj$original_value, 
              adj$reason, adj$timestamp, sep = "\t"),
        "#"
      )
    }
    
    # Prepare SECTION 3 content
    n_adjustments <- length(.param_adjustments)
    critical_params <- c("batch_correction_status", "aldexdenom")
    critical_adjustments <- sum(sapply(.param_adjustments, function(x) {
      x$parameter %in% critical_params
    }))
    
    section3_lines <- c(
      "",
      "# [SECTION 3: ANALYSIS SUMMARY]",
      paste0("total_adjustments\t", n_adjustments),
      "has_adjustments\tTRUE",
      paste0("critical_adjustments\t", critical_adjustments),
      paste0("# Critical: ", paste(sapply(.param_adjustments, function(x) {
        if (x$parameter %in% critical_params) x$parameter else NULL
      }), collapse = ", "))
    )
    
    # Append to parameters_info.txt
    cat(c(section2_lines, section3_lines), 
        file = params_file, 
        sep = "\n", 
        append = TRUE)
    
    cat(sprintf("[SUCCESS] Saved %d parameter adjustments to %s\n", 
                n_adjustments, params_file))
    
    return(invisible(TRUE))
    
  }, error = function(e) {
    warning(sprintf("[WARNING] Failed to save parameter adjustments: %s", e$message))
    return(invisible(FALSE))
  })
}

## ========================================================================
## function name : calculate_taxa_stats
## description : calculate group median proportions and prevalence for taxa
## prop = raw proportion taxa-table (sample in row)
## meta = the metadata
## compcol = the comparison column name
## compref = the control name in the comparison
## prop_cutoff = proportion cutoff value for prevalence calculation
## output : taxa - prop/prev table
## ========================================================================
calculate_taxa_stats <- function(prop, meta, compcol, compref, prop_cutoff) {
	mat <- as.matrix(prop)
	comp <- relevel(factor(meta[[compcol]]), ref = compref)
	comp.lvl <- levels(comp)
	taxa.names <- colnames(mat)

	stat.res <- lapply(comp.lvl, function(group) {
				   group.data <- mat[comp == group, , drop = F]
				   nsamp <- sum(comp == group)
				   median.prop <- apply(group.data, 2, median)
				   prev <- colSums(group.data >= prop_cutoff) / nsamp
				   group.stat <- data.frame(median.prop = median.prop, prev = prev)
				   colnames(group.stat) <- paste0(c("median.prop.", "prev."), group)
				   group.stat
	})

	combined_stat <- do.call(cbind, stat.res) %>% dplyr::arrange(row.names(.))
	combined_stat
}

## =========================================================
## function name : aggregate_taxa
## description : aggregate taxa to specific taxa ranks
## df = species taxa-table (first column = taxa name; using ";" as delimiter)
## levels = taxa ranks (1=kingdom, 2=phylum, 3=class, 4=order, 5=family, 6=genus, 7=species)
## output : a taxa-table list with chose taxa ranks
## =========================================================
aggregate_taxa <- function(df, levels) {
        level_positions <- c(kingdom=1, phylum=2, class=3, order=4, family=5, genus=6, species=7)

        if (is.character(levels)) {
                level_nums <- level_positions[levels]
        } else {
                level_nums <- levels
                names(level_nums) <- names(level_positions)[levels]
        }

        sample_cols <- names(df)[-1]
        mat <- as.matrix(df[, sample_cols, drop = FALSE])
        taxa <- df[[1]]

        extractlevel <- function(taxstr, position) {
                parts <- strsplit(taxstr, ";", fixed = TRUE)[[1]]

                # remove prefix name (k__, p__ ...)
                parts <- gsub("^[a-z]_{1,2}", "", parts)
                parts <- trimws(parts)
                if (position > length(parts) || parts[position] == "") {return(NA_character_)}
                return(parts[position])
        }

        out_list <- lapply(seq_along(level_nums), function(i) {
                lvl_name <- names(level_nums)[i]
                position <- level_nums[i]
                rank_names <- vapply(taxa, extractlevel, position = position, FUN.VALUE = character(1))
                rank_names[is.na(rank_names)] <- "Unassigned"
                agg <- rowsum(mat, rank_names, reorder = FALSE)
                res <- as.data.frame(agg, check.names = FALSE)
                rownames(res) <- rownames(agg)
                res
        })

        names(out_list) <- names(level_nums)
        out_list
}

## =================================================================================================
## function name : aldex.transfer.batch
## description : Perform ALDEx2 CLR transformation with batch-aware processing.
##               If metadata contains 'batches' column, process each batch separately
##               then merge results using union or intersect mode.
##               Both CLR and proportion are extracted from single ALDEx2 run per batch.
## agg.taxatable = list of aggregated taxa tables (output from aggregate_taxa function)
## metadata = data frame containing sample metadata (rownames = sample IDs)
## aldexdenom = ALDEx2 denom parameter for CLR transformation (default: "iqlr", fallback: "median")
## mc.samples = number of Monte Carlo samples for ALDEx2 (default: 128)
## merge_mode = merge mode for combining batches: "union" (fill 0) or "intersect" (default: "union")
## output : a list containing:
##          - clr: list of CLR-transformed data frames (each taxonomic level)
##          - prop: list of normalized proportion data frames (each taxonomic level, row sums = 1)
##          - taxa_info: list of data frames with batch processing info
##                       (final_taxa_count, merge_mode, batch_id, taxa_per_batch)
## =================================================================================================
aldex.transfer.batch <- function(agg.taxatable,
                                  metadata,
                                  aldexdenom = "iqlr",
                                  mc.samples = 128,
                                  merge_mode = "union") {

  # ============================================================
  # Helper function: Execute ALDEx2 with denom fallback
  # ============================================================
  run_aldex_clr <- function(count_matrix, denom, mc_samples) {
    mat <- as.matrix(count_matrix)
    cond <- rep(1, ncol(mat))

    result <- tryCatch({
      ALDEx2::aldex.clr(mat, cond, mc.samples = mc_samples, denom = denom, verbose = FALSE)
    }, error = function(e) {
      if (exists("record_parameter_adjustment")) {
        record_parameter_adjustment("aldexdenom", "median", denom, "Failed")
      }
      ALDEx2::aldex.clr(mat, cond, mc.samples = mc_samples, denom = "median", verbose = FALSE)
    })

    return(result)
  }

  # ============================================================
  # Helper function: Extract CLR and Proportion from aldex result
  # ============================================================
  extract_clr_prop <- function(aldex_res) {
    clr <- t(sapply(ALDEx2::getMonteCarloInstances(aldex_res), function(x) apply(x, 1, median)))
    prop <- t(sapply(ALDEx2::getDirichletInstances(aldex_res), function(x) apply(x, 1, median)))
    return(list(clr = clr, prop = prop))
  }

  # ============================================================
  # Helper function: Normalize proportion (row sums = 1)
  # ============================================================
  normalize_prop <- function(prop_matrix) {
    prop_df <- as.data.frame(prop_matrix)
    row_sums <- rowSums(prop_df)
    prop_normalized <- prop_df / row_sums
    return(as.data.frame(prop_normalized))
  }

  # ============================================================
  # Helper function: Merge matrices with union mode (fill 0 for missing)
  # ============================================================
  merge_union <- function(matrix_list) {
    all_taxa <- unique(unlist(lapply(matrix_list, colnames)))

    merged_list <- lapply(matrix_list, function(mat) {
      mat_df <- as.data.frame(mat)
      missing_taxa <- setdiff(all_taxa, colnames(mat_df))

      if (length(missing_taxa) > 0) {
        missing_df <- as.data.frame(matrix(0, nrow = nrow(mat_df), ncol = length(missing_taxa)))
        colnames(missing_df) <- missing_taxa
        rownames(missing_df) <- rownames(mat_df)
        mat_df <- cbind(mat_df, missing_df)
      }

      mat_df[, all_taxa, drop = FALSE]
    })

    names(merged_list) <- NULL
    do.call(rbind, merged_list)
  }

  # ============================================================
  # Helper function: Merge matrices with intersect mode
  # ============================================================
  merge_intersect <- function(matrix_list) {
    common_taxa <- Reduce(intersect, lapply(matrix_list, colnames))

    merged_list <- lapply(matrix_list, function(mat) {
      mat_df <- as.data.frame(mat)
      mat_df[, common_taxa, drop = FALSE]
    })

    names(merged_list) <- NULL
    do.call(rbind, merged_list)
  }

  # ============================================================
  # Preprocessing: Unify rownames format
  # ============================================================
  rownames(metadata) <- gsub("-", ".", rownames(metadata))

  # ============================================================
  # Check for batches column
  # ============================================================
  has_batches <- "batches" %in% colnames(metadata)

  # ============================================================
  # Initialize output
  # ============================================================
  clr_output <- list()
  prop_output <- list()
  taxa_info_list <- list()

  # ============================================================
  # Process each taxonomic level
  # ============================================================
  for (level_name in names(agg.taxatable)) {

    count_table <- agg.taxatable[[level_name]]
    colnames(count_table) <- gsub("-", ".", colnames(count_table))

    # --------------------------------------------------------
    # No batches: Process all samples together
    # --------------------------------------------------------
    if (!has_batches) {

      aldex_res <- run_aldex_clr(count_table, aldexdenom, mc.samples)
      extracted <- extract_clr_prop(aldex_res)

      clr_output[[level_name]] <- as.data.frame(extracted$clr)
      prop_output[[level_name]] <- normalize_prop(extracted$prop)

      taxa_info_list[[level_name]] <- data.frame(
        batch_id = c("final_taxa_count", "merge_mode", "all"),
        taxa_per_batch = c(ncol(count_table), "none", ncol(count_table)),
        stringsAsFactors = FALSE
      )

    # --------------------------------------------------------
    # Has batches: Process each batch separately then merge
    # --------------------------------------------------------
    } else {

      batch_ids <- unique(metadata$batches)
      batch_clr_list <- list()
      batch_prop_list <- list()
      batch_taxa_counts <- c()

      # Process each batch
      for (batch_id in batch_ids) {

        # Get samples for this batch
        batch_samples <- rownames(metadata)[metadata$batches == batch_id]
        batch_samples <- intersect(batch_samples, colnames(count_table))

        if (length(batch_samples) < 2) {
          warning(paste0("Batch '", batch_id, "' has fewer than 2 samples, skipping."))
          next
        }

        # Subset count table for this batch
        batch_count <- count_table[, batch_samples, drop = FALSE]

        # Remove taxa with all zeros in this batch
        batch_count <- batch_count[rowSums(batch_count) > 0, , drop = FALSE]

        # Run ALDEx2
        aldex_res <- run_aldex_clr(batch_count, aldexdenom, mc.samples)
        extracted <- extract_clr_prop(aldex_res)

        batch_clr_list[[batch_id]] <- extracted$clr
        batch_prop_list[[batch_id]] <- extracted$prop
        batch_taxa_counts[batch_id] <- ncol(extracted$clr)
      }

      # Merge based on mode
      if (merge_mode == "union") {
        merged_clr <- merge_union(batch_clr_list)
        merged_prop <- merge_union(batch_prop_list)
      } else {
        merged_clr <- merge_intersect(batch_clr_list)
        merged_prop <- merge_intersect(batch_prop_list)
      }

      # Normalize proportion
      merged_prop <- normalize_prop(merged_prop)

      # Store results
      clr_output[[level_name]] <- as.data.frame(merged_clr)
      prop_output[[level_name]] <- as.data.frame(merged_prop)

      # Build taxa_info
      final_taxa_count <- ncol(merged_clr)
      taxa_info_list[[level_name]] <- data.frame(
        batch_id = c("final_taxa_count", "merge_mode", names(batch_taxa_counts)),
        taxa_per_batch = c(as.character(final_taxa_count), merge_mode, as.character(batch_taxa_counts)),
        stringsAsFactors = FALSE
      )
    }
  }

  # ============================================================
  # Return results
  # ============================================================
  return(list(
    clr = clr_output,
    prop = prop_output,
    taxa_info = taxa_info_list
  ))
}

## ================================================================================
## Batch Correction Classification System - Version 3
## Date: 2025-12-20
## 
## Version History:
##   v1 (Original): Single-stage, 3 classifications (plsda.batch, splsda.batch, weighted_plsda.batch)
##   v2 (Three-stage): cv_cells, any_missing_group, 4 classifications
##   v3 (Hybrid): Nested detection from v2 + Original metrics from v1 + 4 classifications
##
## Key Features of v3:
##   - Stage 1: Nested design detection (from v2) - forces Weighted
##   - Stage 2: Weighted/Unweighted using original metrics (inter.v > 0.030 || nesting.degree > 0.3)
##   - Stage 3: Sparse/Non-Sparse using original metrics (ratio < 0.5 || (batch.v > 0.3 && n < 100))
##   - Output: 4 classifications (uw_plsda, uw_splsda, w_plsda, w_splsda)
## ================================================================================

## =========================================================================
## function name : classify_batchtype (v3)
## description : Classify batch correction method using hybrid approach
## =========================================================================
classify_batchtype <- function(clr, metadata, batchcol, compcol) {
  
  # ==========================================================================
  # Step 0: Factor conversion and basic validation
  # ==========================================================================
  batch_f <- factor(metadata[[batchcol]])
  comp_f <- factor(metadata[[compcol]])
  
  cat("\n=== Batch Type Classification (v3) ===\n")
  cat(sprintf("  Total Samples: %d\n", nrow(metadata)))
  cat(sprintf("  Batch Column: %s (%d levels)\n", batchcol, nlevels(batch_f)))
  cat(sprintf("  Comp Column: %s (%d levels)\n", compcol, nlevels(comp_f)))
  
  # Validation: require at least 2 levels for both
  if (nlevels(batch_f) < 2) {
    warning(paste0("[WARNING] Batch column '", batchcol, "' has < 2 levels. Skipping batch correction."))
    return(list(
      final_type = "nobatches",
      diagnostics = list(reason = "batch_levels < 2"),
      plsda_params = list(balance = TRUE, keepX.trt = NULL)
    ))
  }
  if (nlevels(comp_f) < 2) {
    warning(paste0("[WARNING] Comparison column '", compcol, "' has < 2 levels. Skipping batch correction."))
    return(list(
      final_type = "nobatches",
      diagnostics = list(reason = "comp_levels < 2"),
      plsda_params = list(balance = TRUE, keepX.trt = NULL)
    ))
  }
  
  # ==========================================================================
  # Step 1: Calculate all metrics (same as v1)
  # ==========================================================================
  meta.factors <- data.frame(comp = comp_f, batch = batch_f)
  
  # pRDA variance decomposition
  rda.res <- tryCatch({
    vegan::varpart(clr, ~ comp, ~ batch, data = meta.factors, scale = TRUE)
  }, error = function(e) {
    cat("  [ERROR] varpart failed:", e$message, "\n")
    return(NULL)
  })
  
  if (is.null(rda.res)) {
    return(list(
      final_type = "nobatches",
      diagnostics = list(reason = "varpart_failed"),
      plsda_params = list(balance = TRUE, keepX.trt = NULL)
    ))
  }
  
  # Extract variance components
  rda.variance <- rda.res$part$indfract$Adj.R.squared
  rda.variance[rda.variance < 0] <- 0
  
  comp.v <- rda.variance[1]   # Treatment only
  batch.v <- rda.variance[2]  # Batch only
  inter.v <- rda.variance[3]  # Intersection
  
  total.v <- comp.v + batch.v + inter.v
  if (total.v == 0) {
    cat("  [WARNING] Total variance = 0, defaulting to uw_plsda\n")
    return(list(
      final_type = "uw_plsda",
      diagnostics = list(reason = "total_variance_zero"),
      plsda_params = list(balance = TRUE, keepX.trt = NULL)
    ))
  }
  
  # Calculate additional metrics
  n_samples <- nrow(clr)
  n_features <- ncol(clr)
  n_batches <- nlevels(batch_f)
  n_groups <- nlevels(comp_f)
  sample_feature_ratio <- n_samples / n_features
  
  # Cross-tabulation analysis
  sample.table <- table(metadata[[batchcol]], metadata[[compcol]])
  
  # Nesting degree (original v1 metric): proportion of batches with only 1 group
  comp.inbatches <- apply(sample.table, 1, function(x) sum(x > 0))
  nesting.degree <- sum(comp.inbatches == 1) / n_batches
  
  # Complete nesting ratio (v2 metric for Stage 1)
  complete_nesting_ratio <- sum(comp.inbatches == 1) / n_batches
  
  # Log all metrics
  cat("\n  --- Variance Decomposition (pRDA) ---\n")
  cat(sprintf("    comp.v (treatment): %.4f\n", comp.v))
  cat(sprintf("    batch.v (batch): %.4f\n", batch.v))
  cat(sprintf("    inter.v (intersection): %.4f\n", inter.v))
  cat(sprintf("    total.v: %.4f\n", total.v))
  
  cat("\n  --- Sample/Feature Metrics ---\n")
  cat(sprintf("    n_samples: %d\n", n_samples))
  cat(sprintf("    n_features: %d\n", n_features))
  cat(sprintf("    sample_feature_ratio: %.4f\n", sample_feature_ratio))
  cat(sprintf("    n_batches: %d\n", n_batches))
  cat(sprintf("    n_groups: %d\n", n_groups))
  
  cat("\n  --- Nesting Metrics ---\n")
  cat(sprintf("    nesting.degree: %.4f\n", nesting.degree))
  cat(sprintf("    complete_nesting_ratio: %.4f\n", complete_nesting_ratio))
  
  cat("\n  --- Cross-tabulation ---\n")
  print(sample.table)
  
  # ==========================================================================
  # Stage 1: Nested Design Detection (from v2)
  # If >= 50% of batches contain only one group, force Weighted
  # ==========================================================================
  cat("\n  === Stage 1: Nested Design Detection ===\n")
  
  is_nested <- (complete_nesting_ratio >= 0.5)
  
  if (is_nested) {
    cat(sprintf("    complete_nesting_ratio = %.2f >= 0.5\n", complete_nesting_ratio))
    cat("    → NESTED DESIGN DETECTED → Force Weighted\n")
  } else {
    cat(sprintf("    complete_nesting_ratio = %.2f < 0.5\n", complete_nesting_ratio))
    cat("    → Not nested, proceed to Stage 2\n")
  }
  
  # ==========================================================================
  # Stage 2: Weighted vs Unweighted (using v1 metrics)
  # Condition: is_nested OR inter.v > 0.030 OR nesting.degree > 0.3
  # inter.v 閾值 2026-07-28 由 0.3 下修至 0.030（sim7 決策規則校準，見 CLAUDE.md §14.4）：
  #   inter.v 有結構性上限 ~0.27，0.3 永遠觸發不了，導致 confounded/unbalanced 被錯判 unweighted。
  # ==========================================================================
  cat("\n  === Stage 2: Weighted vs Unweighted ===\n")
  cat(sprintf("    Checking: is_nested=%s OR inter.v=%.4f>0.030 OR nesting.degree=%.4f>0.3\n",
              is_nested, inter.v, nesting.degree))

  use_weighted <- (is_nested || inter.v > 0.030 || nesting.degree > 0.3)
  
  if (use_weighted) {
    weight_reason <- c()
    if (is_nested) weight_reason <- c(weight_reason, "nested_design")
    if (inter.v > 0.030) weight_reason <- c(weight_reason, sprintf("inter.v=%.3f>0.030", inter.v))
    if (nesting.degree > 0.3) weight_reason <- c(weight_reason, sprintf("nesting.degree=%.3f>0.3", nesting.degree))
    
    cat(sprintf("    → WEIGHTED (reason: %s)\n", paste(weight_reason, collapse = ", ")))
  } else {
    cat("    → UNWEIGHTED\n")
  }
  
  # ==========================================================================
  # Stage 3: Sparse vs Non-Sparse (using v1 metrics)
  # Condition: sample_feature_ratio < 0.5 OR (batch.v > 0.3 AND n_samples < 100)
  # ==========================================================================
  cat("\n  === Stage 3: Sparse vs Non-Sparse ===\n")
  cat(sprintf("    Checking: ratio=%.4f<0.5 OR (batch.v=%.4f>0.3 AND n=%d<100)\n",
              sample_feature_ratio, batch.v, n_samples))
  
  cond1_sparse <- (sample_feature_ratio < 0.5)
  cond2_sparse <- (batch.v > 0.3 && n_samples < 100)
  use_sparse <- (cond1_sparse || cond2_sparse)
  
  if (use_sparse) {
    sparse_reason <- c()
    if (cond1_sparse) sparse_reason <- c(sparse_reason, sprintf("ratio=%.3f<0.5", sample_feature_ratio))
    if (cond2_sparse) sparse_reason <- c(sparse_reason, sprintf("batch.v=%.3f>0.3 AND n=%d<100", batch.v, n_samples))
    
    cat(sprintf("    → SPARSE (reason: %s)\n", paste(sparse_reason, collapse = ", ")))
  } else {
    cat("    → NON-SPARSE\n")
  }
  
  # ==========================================================================
  # Final Classification: Combine Weighted/Unweighted × Sparse/Non-Sparse
  # ==========================================================================
  if (use_weighted && use_sparse) {
    final_type <- "w_splsda"
  } else if (use_weighted && !use_sparse) {
    final_type <- "w_plsda"
  } else if (!use_weighted && use_sparse) {
    final_type <- "uw_splsda"
  } else {
    final_type <- "uw_plsda"
  }
  
  cat("\n  === Final Classification ===\n")
  cat(sprintf("    Weighted: %s | Sparse: %s\n", use_weighted, use_sparse))
  cat(sprintf("    → %s\n", final_type))
  cat("==========================================\n\n")
  
  # ==========================================================================
  # Build result with diagnostics
  # ==========================================================================
  diagnostics <- list(
    # Variance components
    comp.v = comp.v,
    batch.v = batch.v,
    inter.v = inter.v,
    total.v = total.v,
    
    # Sample/feature metrics
    n_samples = n_samples,
    n_features = n_features,
    sample_feature_ratio = sample_feature_ratio,
    n_batches = n_batches,
    n_groups = n_groups,
    
    # Nesting metrics
    nesting.degree = nesting.degree,
    complete_nesting_ratio = complete_nesting_ratio,
    
    # Stage decisions
    stage1_is_nested = is_nested,
    stage2_use_weighted = use_weighted,
    stage3_use_sparse = use_sparse,
    
    # Thresholds used (for reference)
    thresholds = list(
      nested_ratio = 0.5,
      inter_v = 0.030,   # 2026-07-28 由 0.3 下修（sim7 校準，見 CLAUDE.md §14.4）
      nesting_degree = 0.3,
      sample_feature_ratio = 0.5,
      batch_v = 0.3,
      small_n = 100
    )
  )
  
  # Map to PLSDA parameters
  plsda_params <- list(
    balance = !use_weighted,  # balance=TRUE for Unweighted, FALSE for Weighted
    keepX.trt = if (use_sparse) "tuned" else NULL
  )
  
  return(list(
    final_type = final_type,
    diagnostics = diagnostics,
    plsda_params = plsda_params
  ))
}


## =========================================================================
## function name : plsda_correction (v3 compatible)
## description : Execute PLSDA-batch correction based on classification
## =========================================================================
plsda_correction <- function(clr, metadata, batchcol, compcol, compref, bctype, variancecut = 0.95) {
  require(PLSDAbatch)
  
  # Helper function: select optimal components
  select_opt_comp <- function(explainvar, cumvalue = variancecut) {
    cum.var <- cumsum(as.numeric(explainvar))
    opt.comp <- which(cum.var >= cumvalue)[1]
    if (is.na(opt.comp)) {
      opt.comp <- length(explainvar)
    }
    return(max(1, opt.comp))
  }
  
  # Prepare factors
  comp <- factor(metadata[[compcol]]) %>% relevel(., ref = compref)
  batch <- factor(metadata[[batchcol]])
  
  # ==========================================================================
  # Map v3 classification to internal parameters
  # ==========================================================================
  # v3 types: uw_plsda, uw_splsda, w_plsda, w_splsda
  # 
  # Mapping:
  #   uw_plsda  → balance = TRUE,  use_sparse = FALSE
  #   uw_splsda → balance = TRUE,  use_sparse = TRUE
  #   w_plsda   → balance = FALSE, use_sparse = FALSE
  #   w_splsda  → balance = FALSE, use_sparse = TRUE
  
  if (bctype %in% c("uw_plsda", "uw_splsda", "w_plsda", "w_splsda")) {
    # v3 format
    use_balance <- grepl("^uw_", bctype)
    use_sparse <- grepl("splsda$", bctype)
    cat(sprintf("\n[PLSDA Correction] v3 type: %s → balance=%s, sparse=%s\n", 
                bctype, use_balance, use_sparse))
  } else {
    # v1 format (backward compatibility)
    use_balance <- (bctype == "balance")
    use_sparse <- (bctype == "sparse")
    cat(sprintf("\n[PLSDA Correction] v1 type: %s → balance=%s, sparse=%s\n", 
                bctype, use_balance, use_sparse))
  }
  
  # ==========================================================================
  # Sample size check
  # ==========================================================================
  group_counts <- table(comp)
  min_group_n <- min(group_counts)
  
  cat("=== Sample Size Check ===\n")
  cat("Group distribution:\n")
  print(group_counts)
  cat("Minimum group sample size:", min_group_n, "\n")
  
  if (min_group_n < 5) {
    warning("Detected group sample size < 5, skipping PLSDA-batch correction\n")
    cat("Returning original CLR data (uncorrected)\n\n")
    
    record_parameter_adjustment(
      parameter = "batch_correction_status",
      adjusted_value = "skipped",
      original_value = "enabled",
      reason = sprintf("Insufficient sample size (min_group_n=%d < 5)", min_group_n)
    )
    
    return(list(
      correctedTable = data.frame(clr, check.names = FALSE),
      parameters = list(
        comparison_comp = NA,
        batch_comp = NA,
        balance_type = bctype,
        skipped = TRUE,
        skip_reason = paste0("Insufficient sample size (minimum group n=", min_group_n, " < 5)")
      ),
      explained_var = list(comparison_var = NA, batch_var = NA)
    ))
  }
  cat("Sample size check passed\n\n")
  
  # ==========================================================================
  # Feature count check
  # ==========================================================================
  X.no <- ncol(clr)
  cat("=== Feature Number Check ===\n")
  cat("Number of features:", X.no, "\n")
  
  if (X.no <= 10) {
    warning("Detected feature number <= 10, skipping PLSDA-batch correction\n")
    cat("Returning original CLR data (uncorrected)\n\n")
    
    record_parameter_adjustment(
      parameter = "batch_correction_status",
      adjusted_value = "skipped",
      original_value = "enabled",
      reason = sprintf("Insufficient features (n_features=%d <= 10)", X.no)
    )
    
    return(list(
      correctedTable = data.frame(clr, check.names = FALSE),
      parameters = list(
        comparison_comp = NA,
        batch_comp = NA,
        balance_type = bctype,
        skipped = TRUE,
        skip_reason = paste0("Insufficient features (n=", X.no, " <= 10)")
      ),
      explained_var = list(comparison_var = NA, batch_var = NA)
    ))
  }
  cat("Feature number check passed\n\n")
  
  # ==========================================================================
  # Step 1: Tune comparison components
  # ==========================================================================
  max.ncomp <- min(nlevels(comp) - 1, 5, ncol(clr))
  comp.tune <- mixOmics::plsda(X = clr, Y = comp, ncomp = max.ncomp)
  comp.ncomp <- select_opt_comp(comp.tune[["prop_expl_var"]][["Y"]], variancecut)
  
  cat("=== Component Tuning ===\n")
  cat("Optimal comparison components:", comp.ncomp, "\n")
  
  # ==========================================================================
  # Step 2: Sparse feature selection (if needed)
  # ==========================================================================
  opt.keepX <- NULL
  
  if (use_sparse) {
    cat("\n=== Sparse PLSDA Tuning ===\n")
    
    # Check if sparse tuning is feasible
    if (min_group_n < 10 || X.no < 20) {
      warning("Insufficient samples/features for sparse tuning, switching to non-sparse\n")
      use_sparse <- FALSE
      
      record_parameter_adjustment(
        parameter = "sparse_mode",
        adjusted_value = "disabled",
        original_value = "enabled",
        reason = sprintf("Insufficient for sparse tuning (min_group_n=%d, X.no=%d)", min_group_n, X.no)
      )
    } else {
      # Define test keepX values
      test_keepX <- if (X.no <= 50) {
        c(seq(10, X.no, 5), X.no)
      } else if (X.no <= 80) {
        c(seq(10, X.no, 10), X.no)
      } else {
        c(seq(10, 50, 10), seq(60, min(200, X.no), 20))
      }
      test_keepX <- unique(test_keepX[test_keepX <= X.no])
      
      cat("Test keepX values:", test_keepX, "\n")
      
      # Tune sparse PLSDA (seed the Mfold CV for reproducibility; RNG restored below)
      .old_seed <- if (exists(".Random.seed", envir = .GlobalEnv)) get(".Random.seed", envir = .GlobalEnv) else NULL
      set.seed(1223)
      sparse.tune <- tryCatch({
        mixOmics::tune.splsda(
          X = clr, 
          Y = comp, 
          ncomp = comp.ncomp, 
          test.keepX = test_keepX, 
          validation = 'Mfold', 
          folds = 4, 
          nrepeat = 30
        )
      }, error = function(e) {
        warning("Sparse tuning failed: ", conditionMessage(e), "\n")
        return(NULL)
      })
      if (!is.null(.old_seed)) assign(".Random.seed", .old_seed, envir = .GlobalEnv)

      if (is.null(sparse.tune)) {
        # Fallback keepX
        opt.keepX <- rep(min(20, floor(X.no * 0.3), floor(min_group_n * 0.5)), comp.ncomp)
        cat("Using fallback keepX:", opt.keepX, "\n")
        
        record_parameter_adjustment(
          parameter = "splsda_keepX",
          adjusted_value = paste(opt.keepX, collapse = ","),
          original_value = "auto_tuned",
          reason = "Sparse PLSDA tuning failed, using conservative fallback values"
        )
      } else {
        opt.keepX <- sparse.tune$choice.keepX
        cat("Optimal keepX:", opt.keepX, "\n")
      }
    }
  }
  
  # ==========================================================================
  # Step 3: Tune batch components
  # ==========================================================================
  max.nbatch <- min(nlevels(batch) - 1, 10)
  
  batch.tune <- PLSDAbatch::PLSDA_batch(
    X = clr, 
    Y.trt = comp, 
    Y.bat = batch, 
    ncomp.trt = comp.ncomp, 
    ncomp.bat = max.nbatch, 
    balance = use_balance
  )
  batch.ncomp <- select_opt_comp(batch.tune[["explained_variance.bat"]][["Y"]])
  
  cat("Optimal batch components:", batch.ncomp, "\n\n")
  
  # ==========================================================================
  # Step 4: Execute batch correction
  # ==========================================================================
  cat("=== Executing Batch Correction ===\n")
  cat(sprintf("  balance = %s\n", use_balance))
  cat(sprintf("  sparse = %s\n", use_sparse))
  if (use_sparse && !is.null(opt.keepX)) {
    cat(sprintf("  keepX = %s\n", paste(opt.keepX, collapse = ", ")))
  }
  
  if (use_sparse && !is.null(opt.keepX)) {
    bc.res <- PLSDAbatch::PLSDA_batch(
      X = clr, 
      Y.trt = comp, 
      Y.bat = batch, 
      ncomp.trt = comp.ncomp, 
      ncomp.bat = batch.ncomp, 
      keepX.trt = opt.keepX, 
      balance = use_balance
    )
  } else {
    bc.res <- PLSDAbatch::PLSDA_batch(
      X = clr, 
      Y.trt = comp, 
      Y.bat = batch, 
      ncomp.trt = comp.ncomp, 
      ncomp.bat = batch.ncomp, 
      balance = use_balance
    )
  }
  
  cat("Batch correction completed successfully\n\n")
  
  # ==========================================================================
  # Step 5: Build result
  # ==========================================================================
  result <- list(
    correctedTable = data.frame(bc.res[["X.nobatch"]], check.names = FALSE),
    parameters = list(
      comparison_comp = comp.ncomp, 
      batch_comp = batch.ncomp, 
      balance_type = bctype,
      balance = use_balance,
      sparse = use_sparse,
      skipped = FALSE
    ),
    explained_var = list(
      comparison_var = cumsum(comp.tune[["prop_expl_var"]][["Y"]])[comp.ncomp], 
      batch_var = cumsum(batch.tune[["explained_variance.bat"]][["Y"]])[batch.ncomp]
    )
  )
  
  if (use_sparse && !is.null(opt.keepX)) {
    result$parameters$feature_select <- opt.keepX
    result$selected_features <- bc.res$loadings.trt
  }
  
  return(result)
}

## =========================================================================================
## function name : calculate_dam
## description : calculate differential abundance microbiomes (DAMs) with additional metrics
## clr = clr table after batch correction
## meta = metadata table
## compcol = the comparison column name
## compcase = the comparison case name
## compref = the comparison control name
## output = dam table including median clr of each group and log2 FC
## =========================================================================================
calculate_dam <- function(clr, meta, compcol, compcase, compref) {
	extract.meta <- meta %>% dplyr::select(all_of(compcol)) %>% dplyr::filter(!!sym(compcol) %in% c(compcase, compref))
	extract.clr <- merge(clr, extract.meta, by = 0, sort = F) %>% column_to_rownames("Row.names")
	taxanum <- ncol(extract.clr) - 1
	group.case <- extract.clr %>% dplyr::filter( !!sym(compcol) == compcase )
	group.ref <- extract.clr %>% dplyr::filter( !!sym(compcol) == compref )
	table <- sapply(1:taxanum, function(taxnum) {
			      case.values <- group.case[[taxnum]]
			      ref.values <- group.ref[[taxnum]]
			      median.case <- median(case.values, na.rm = TRUE) %>% round(., 5)
			      median.ref <- median(ref.values, na.rm = TRUE) %>% round(., 5)
			      log2fc <- (median.case - median.ref)/log(2) %>% round(., 5)
			      # Cliff's delta + 95% CI（Cliff consistent-variance 非對稱區間，effsize 預設 conf.level=0.95）
			      # 一次取回 estimate 與 conf.int，避免重算；缺值時回 NA（向後相容）
			      cliff.res <- tryCatch(effsize::cliff.delta(case.values, ref.values),
			                            error = function(e) NULL)
			      cliff.effect  <- if (is.null(cliff.res)) NA else round(cliff.res$estimate, 5)
			      cliff.ci.low  <- if (is.null(cliff.res)) NA else round(as.numeric(cliff.res$conf.int)[1], 5)
			      cliff.ci.high <- if (is.null(cliff.res)) NA else round(as.numeric(cliff.res$conf.int)[2], 5)
			      #wilcox.test.pvalue <- wilcox.test(case.values, ref.values)$p.value
			      wilcox.test.pvalue <- tryCatch({
                                wilcox.test(case.values, ref.values)$p.value
                              }, error = function(e) NA)
			      return(cbind(median.case, median.ref, log2fc, cliff.effect, cliff.ci.low, cliff.ci.high, wilcox.test.pvalue))
	}) %>% t %>% data.frame %>% setNames(c(paste0("median.clr.", compcase), paste0("median.clr.", compref), "log2fc", "cliff.effect", "cliff.ci.low", "cliff.ci.high", "wilcox.test.p")) %>% dplyr::mutate(adj.pvalue = p.adjust(wilcox.test.p, method = "BH"), Row.names = colnames(extract.clr)[1:taxanum]) %>% column_to_rownames("Row.names") %>% dplyr::arrange(wilcox.test.p, desc(cliff.effect ))
	table
}


