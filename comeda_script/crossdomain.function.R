################################################################################
# File    : crossdomain.function.R
# Purpose : Helper functions for cross-domain correlation analysis
# Author  : CoMeDA Pipeline
# Date    : 2025
################################################################################

#' Validate Overlapping Samples
#'
#' Checks if there are sufficient overlapping samples between two datasets
#'
#' @param bac_samples Character vector of bacteria sample names
#' @param fun_samples Character vector of fungi sample names
#' @param min_samples Minimum required overlapping samples (default: 5)
#'
#' @return List containing overlap_samples and validation status
#'
validate_overlap <- function(bac_samples, fun_samples, min_samples = 5) {
  
  overlap <- intersect(bac_samples, fun_samples)
  
  valid <- length(overlap) >= min_samples
  
  if (!valid) {
    warning(paste("Insufficient overlapping samples:",
                  length(overlap), "found, minimum", min_samples, "required"))
  }
  
  return(list(
    overlap_samples = overlap,
    n_overlap = length(overlap),
    is_valid = valid
  ))
}


#' Extract Cross-Domain Correlations
#'
#' Extracts only bacteria-fungi correlations from a full correlation matrix
#'
#' @param corr_matrix Full correlation matrix with bacteria and fungi
#' @param p_matrix Corresponding BH-adjusted p-value matrix
#' @param n_bacteria Number of bacteria taxa (first n columns/rows)
#'
#' @return List with cross-domain correlation and p-value matrices
#'
extract_crossdomain_only <- function(corr_matrix, p_matrix, n_bacteria) {
  
  n_total <- nrow(corr_matrix)
  n_fungi <- n_total - n_bacteria
  
  if (n_bacteria <= 0 || n_fungi <= 0) {
    stop("Invalid number of bacteria or fungi taxa")
  }
  
  # Extract bacteria-fungi block (upper right)
  bac_fun_corr <- corr_matrix[1:n_bacteria, (n_bacteria+1):n_total, drop = FALSE]
  bac_fun_pval <- p_matrix[1:n_bacteria, (n_bacteria+1):n_total, drop = FALSE]
  
  # Extract fungi-bacteria block (lower left) - should be symmetric
  fun_bac_corr <- corr_matrix[(n_bacteria+1):n_total, 1:n_bacteria, drop = FALSE]
  fun_bac_pval <- p_matrix[(n_bacteria+1):n_total, 1:n_bacteria, drop = FALSE]
  
  return(list(
    bacteria_fungi = list(
      correlation = bac_fun_corr,
      p_value = bac_fun_pval
    ),
    fungi_bacteria = list(
      correlation = fun_bac_corr,
      p_value = fun_bac_pval
    ),
    dimensions = list(
      n_bacteria = n_bacteria,
      n_fungi = n_fungi,
      total = n_total
    )
  ))
}


#' Summarize Cross-Domain Correlations
#'
#' Generates summary statistics for cross-domain correlation results
#'
#' @param corr_matrix Correlation matrix with NA in within-domain blocks
#' @param p_matrix BH-adjusted p-value matrix
#' @param n_bacteria Number of bacteria taxa
#' @param p_cutoff Adjusted p-value cutoff for significance (default: 0.05)
#'
#' @return List with summary statistics
#'
summarize_crossdomain_corr <- function(corr_matrix, p_matrix, 
                                       n_bacteria, p_cutoff = 0.05) {
  
  n_total <- nrow(corr_matrix)
  
  # Create mask for cross-domain correlations
  cross_domain_mask <- matrix(FALSE, n_total, n_total)
  cross_domain_mask[1:n_bacteria, (n_bacteria+1):n_total] <- TRUE
  cross_domain_mask[(n_bacteria+1):n_total, 1:n_bacteria] <- TRUE
  
  # Extract cross-domain values
  cd_corr <- corr_matrix[cross_domain_mask]
  cd_pval <- p_matrix[cross_domain_mask]
  
  # Remove NAs and zeros (NA-safe operations)
  valid_idx <- !is.na(cd_corr) & !is.na(cd_pval) & cd_corr != 0
  cd_corr <- cd_corr[valid_idx]
  cd_pval <- cd_pval[valid_idx]
  
  # Calculate statistics
  if (length(cd_corr) == 0) {
    return(list(
      total_correlations = 0,
      significant_correlations = 0,
      positive_correlations = 0,
      negative_correlations = 0,
      mean_correlation = NA,
      median_correlation = NA,
      range_correlation = c(NA, NA)
    ))
  }
  
  n_sig <- sum(cd_pval < p_cutoff, na.rm = TRUE)
  n_pos <- sum(cd_corr > 0, na.rm = TRUE)
  n_neg <- sum(cd_corr < 0, na.rm = TRUE)
  
  return(list(
    total_correlations = length(cd_corr),
    significant_correlations = n_sig,
    positive_correlations = n_pos,
    negative_correlations = n_neg,
    mean_correlation = mean(cd_corr, na.rm = TRUE),
    median_correlation = median(cd_corr, na.rm = TRUE),
    range_correlation = range(cd_corr, na.rm = TRUE),
    proportion_significant = n_sig / length(cd_corr)
  ))
}


#' Identify Top Cross-Domain Interactions
#'
#' Finds the strongest bacteria-fungi correlations
#'
#' @param corr_matrix Correlation matrix
#' @param p_matrix BH-adjusted p-value matrix
#' @param n_bacteria Number of bacteria taxa
#' @param top_n Number of top interactions to return (default: 10)
#' @param p_cutoff Adjusted p-value cutoff (default: 0.05)
#'
#' @return Data frame with top interactions
#'
identify_top_interactions <- function(corr_matrix, p_matrix, n_bacteria, 
                                     top_n = 10, p_cutoff = 0.05) {
  
  n_total <- nrow(corr_matrix)
  
  # Create result data frame
  interactions <- data.frame()
  
  # Iterate through bacteria-fungi pairs
  for (i in 1:n_bacteria) {
    for (j in (n_bacteria+1):n_total) {
      
      corr_val <- corr_matrix[i, j]
      pval <- p_matrix[i, j]
      
      # Skip NA values and zeros
      if (is.na(corr_val) || is.na(pval)) next
      if (corr_val == 0) next
      if (pval >= p_cutoff) next
      
      interactions <- rbind(interactions, data.frame(
        bacteria = rownames(corr_matrix)[i],
        fungi = colnames(corr_matrix)[j],
        correlation = corr_val,
        p_value = pval,
        abs_correlation = abs(corr_val),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  # Sort by absolute correlation strength
  if (nrow(interactions) > 0) {
    interactions <- interactions[order(-interactions$abs_correlation), ]
    interactions <- head(interactions, top_n)
    interactions$abs_correlation <- NULL  # Remove helper column
    rownames(interactions) <- NULL
  }
  
  return(interactions)
}


#' Generate Cross-Domain Analysis Report
#'
#' Creates a comprehensive text report of cross-domain correlation results
#'
#' @param crossdomain_results Nested list of cross-domain correlation results
#' @param output_file Path to output text file (optional)
#'
#' @return Character vector with report lines (invisibly)
#'
generate_crossdomain_report <- function(crossdomain_results, output_file = NULL) {
  
  report_lines <- c()
  
  report_lines <- c(report_lines,
                    "========================================",
                    "Cross-Domain Correlation Analysis Report",
                    "========================================",
                    paste("Generated:", Sys.time()),
                    "")
  
  for (lvl in names(crossdomain_results)) {
    report_lines <- c(report_lines,
                      paste("\n--- Taxonomic Level:", lvl, "---"))
    
    for (compcol in names(crossdomain_results[[lvl]])) {
      report_lines <- c(report_lines,
                        paste("\nComparison:", compcol))
      
      for (evt in names(crossdomain_results[[lvl]][[compcol]])) {
        
        result <- crossdomain_results[[lvl]][[compcol]][[evt]]
        corr_mat <- result$correlationTable
        p_mat <- result$p.value
        
        # Get bacteria count from metadata (if available)
        if (!is.null(result$metadata) && !is.null(result$metadata$n_bacteria)) {
          n_bac <- result$metadata$n_bacteria
          n_fun <- result$metadata$n_fungi
        } else {
          # Fallback: try to determine from matrix structure
          # Assume bacteria are in the first half (this is a guess)
          warning("Metadata not found, estimating bacteria/fungi split")
          n_bac <- floor(nrow(corr_mat) / 2)
          n_fun <- nrow(corr_mat) - n_bac
        }
        
        # Generate summary
        summary_stats <- summarize_crossdomain_corr(corr_mat, p_mat, n_bac)
        
        report_lines <- c(report_lines,
                          paste("\n  Event:", evt),
                          paste("    Total bacteria taxa:", n_bac),
                          paste("    Total fungi taxa:", nrow(corr_mat) - n_bac),
                          paste("    Cross-domain correlations:", 
                                summary_stats$total_correlations),
                          paste("    Significant (p < 0.05):", 
                                summary_stats$significant_correlations),
                          paste("    Positive correlations:", 
                                summary_stats$positive_correlations),
                          paste("    Negative correlations:", 
                                summary_stats$negative_correlations),
                          paste("    Mean correlation:", 
                                round(summary_stats$mean_correlation, 3)),
                          paste("    Median correlation:", 
                                round(summary_stats$median_correlation, 3)))
      }
    }
  }
  
  report_lines <- c(report_lines,
                    "\n========================================",
                    "End of Report",
                    "========================================")
  
  # Write to file if specified
  if (!is.null(output_file)) {
    writeLines(report_lines, output_file)
    cat("Report written to:", output_file, "\n")
  }
  
  return(invisible(report_lines))
}
