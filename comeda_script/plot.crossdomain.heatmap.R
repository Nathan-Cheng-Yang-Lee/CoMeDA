# 比較兩組間bacteria-fungi相關性的函數（增加原始統計版）
cross_compare_correlations <- function(data_list,
                                 taxarank = "genus",
                                 comparison = "Rhinosinusitis_Type",
                                 groups = c("AdjNormal", "Fungal"),
                                 threshold_corr = 0.6,
                                 threshold_p = 0.05) {
  
  # 檢查必須提供兩個組別
  if(length(groups) != 2) {
    stop("Must provide exactly 2 groups for comparison")
  }
  
  # 提取taxarank層級的數據
  taxa_data <- data_list[[taxarank]]
  
  # 檢查taxarank是否存在
  if(is.null(taxa_data)) {
    stop(paste("Taxarank", taxarank, "not found in data"))
  }
  
  # 提取comparison層級的數據
  comp_data <- taxa_data[[comparison]]
  
  # 檢查comparison是否存在
  if(is.null(comp_data)) {
    stop(paste("Comparison", comparison, "not found in taxarank", taxarank))
  }
  
  group1 <- groups[1]
  group2 <- groups[2]
  
  # 檢查兩個組別是否存在
  if(!group1 %in% names(comp_data) | !group2 %in% names(comp_data)) {
    stop(paste("One or both groups not found in", comparison))
  }
  
  # 分別從兩個組別的metadata中取得bacteria和fungi的名稱
  if(is.null(comp_data[[group1]]$metadata$bacteria_taxa)) {
    stop(paste("bacteria_taxa not found in metadata of", group1))
  }
  if(is.null(comp_data[[group1]]$metadata$fungi_taxa)) {
    stop(paste("fungi_taxa not found in metadata of", group1))
  }
  if(is.null(comp_data[[group2]]$metadata$bacteria_taxa)) {
    stop(paste("bacteria_taxa not found in metadata of", group2))
  }
  if(is.null(comp_data[[group2]]$metadata$fungi_taxa)) {
    stop(paste("fungi_taxa not found in metadata of", group2))
  }
  
  bacteria_names_g1 <- comp_data[[group1]]$metadata$bacteria_taxa
  fungi_names_g1 <- comp_data[[group1]]$metadata$fungi_taxa
  
  bacteria_names_g2 <- comp_data[[group2]]$metadata$bacteria_taxa
  fungi_names_g2 <- comp_data[[group2]]$metadata$fungi_taxa
  
  cat(paste0("Group1 (", group1, "): ", length(bacteria_names_g1), " bacteria, ", 
             length(fungi_names_g1), " fungi\n"))
  cat(paste0("Group2 (", group2, "): ", length(bacteria_names_g2), " bacteria, ", 
             length(fungi_names_g2), " fungi\n"))
  
  # 取交集，用於比較分析（concordant和discordant）
  bacteria_names_common <- intersect(bacteria_names_g1, bacteria_names_g2)
  fungi_names_common <- intersect(fungi_names_g1, fungi_names_g2)
  
  if(length(bacteria_names_common) == 0) {
    stop("No common bacteria taxa found between the two groups")
  }
  if(length(fungi_names_common) == 0) {
    stop("No common fungi taxa found between the two groups")
  }
  
  cat(paste0("Common taxa: ", length(bacteria_names_common), " bacteria, ", 
             length(fungi_names_common), " fungi\n"))
  
  # 提取兩組的correlation和p.value matrix
  corr1 <- comp_data[[group1]]$correlationTable
  p1 <- comp_data[[group1]]$p.value
  
  corr2 <- comp_data[[group2]]$correlationTable
  p2 <- comp_data[[group2]]$p.value
  
  # ===== 處理共同taxa（用於concordant和discordant）=====
  # 在group1中找出共同bacteria和fungi的索引
  bacteria_idx_g1_common <- which(rownames(corr1) %in% bacteria_names_common)
  fungi_idx_g1_common <- which(colnames(corr1) %in% fungi_names_common)
  
  # 在group2中找出共同bacteria和fungi的索引
  bacteria_idx_g2_common <- which(rownames(corr2) %in% bacteria_names_common)
  fungi_idx_g2_common <- which(colnames(corr2) %in% fungi_names_common)
  
  # 提取共同taxa的子矩陣
  corr1_sub_common <- corr1[bacteria_idx_g1_common, fungi_idx_g1_common, drop = FALSE]
  p1_sub_common <- p1[bacteria_idx_g1_common, fungi_idx_g1_common, drop = FALSE]
  
  corr2_sub_common <- corr2[bacteria_idx_g2_common, fungi_idx_g2_common, drop = FALSE]
  p2_sub_common <- p2[bacteria_idx_g2_common, fungi_idx_g2_common, drop = FALSE]
  
  # 確保兩個子矩陣的行名和列名順序一致
  common_bacteria <- intersect(rownames(corr1_sub_common), rownames(corr2_sub_common))
  common_fungi <- intersect(colnames(corr1_sub_common), colnames(corr2_sub_common))
  
  # 重新排序
  corr1_sub_common <- corr1_sub_common[common_bacteria, common_fungi, drop = FALSE]
  p1_sub_common <- p1_sub_common[common_bacteria, common_fungi, drop = FALSE]
  
  corr2_sub_common <- corr2_sub_common[common_bacteria, common_fungi, drop = FALSE]
  p2_sub_common <- p2_sub_common[common_bacteria, common_fungi, drop = FALSE]
  
  cat(paste0("Final common taxa in both matrices: ", length(common_bacteria), 
             " bacteria, ", length(common_fungi), " fungi\n"))
  
  # ===== 處理各組的所有taxa（用於only_in分析）=====
  # Group1的所有bacteria vs fungi
  bacteria_idx_g1_all <- which(rownames(corr1) %in% bacteria_names_g1)
  fungi_idx_g1_all <- which(colnames(corr1) %in% fungi_names_g1)
  
  corr1_sub_all <- corr1[bacteria_idx_g1_all, fungi_idx_g1_all, drop = FALSE]
  p1_sub_all <- p1[bacteria_idx_g1_all, fungi_idx_g1_all, drop = FALSE]
  
  # Group2的所有bacteria vs fungi
  bacteria_idx_g2_all <- which(rownames(corr2) %in% bacteria_names_g2)
  fungi_idx_g2_all <- which(colnames(corr2) %in% fungi_names_g2)
  
  corr2_sub_all <- corr2[bacteria_idx_g2_all, fungi_idx_g2_all, drop = FALSE]
  p2_sub_all <- p2[bacteria_idx_g2_all, fungi_idx_g2_all, drop = FALSE]
  
  cat(paste0("Group1 all taxa in matrix: ", nrow(corr1_sub_all), " bacteria, ", 
             ncol(corr1_sub_all), " fungi\n"))
  cat(paste0("Group2 all taxa in matrix: ", nrow(corr2_sub_all), " bacteria, ", 
             ncol(corr2_sub_all), " fungi\n"))
  
  # ===== 統計原始組別中的正負相關數量 =====
  # Group1 的統計
  sig1_all <- (abs(corr1_sub_all) >= threshold_corr) & (p1_sub_all <= threshold_p)
  g1_positive <- sum(sig1_all & (corr1_sub_all > 0), na.rm = TRUE)
  g1_negative <- sum(sig1_all & (corr1_sub_all < 0), na.rm = TRUE)
  g1_total <- g1_positive + g1_negative
  
  # Group2 的統計
  sig2_all <- (abs(corr2_sub_all) >= threshold_corr) & (p2_sub_all <= threshold_p)
  g2_positive <- sum(sig2_all & (corr2_sub_all > 0), na.rm = TRUE)
  g2_negative <- sum(sig2_all & (corr2_sub_all < 0), na.rm = TRUE)
  g2_total <- g2_positive + g2_negative
  
  # 初始化結果list
  results <- list()
  
  # ===== 1. Concordant: 使用共同taxa =====
  sig1_common <- (abs(corr1_sub_common) >= threshold_corr) & (p1_sub_common <= threshold_p)
  sig2_common <- (abs(corr2_sub_common) >= threshold_corr) & (p2_sub_common <= threshold_p)
  
  concordant_mask <- sig1_common & sig2_common & 
    (((corr1_sub_common > 0) & (corr2_sub_common > 0)) | 
     ((corr1_sub_common < 0) & (corr2_sub_common < 0)))
  
  corr_concordant <- corr1_sub_common
  corr_concordant[!concordant_mask] <- NA
  corr_concordant <- remove_empty_rows_cols(corr_concordant)
  
  if(nrow(corr_concordant) > 0) {
    results$concordant <- list(
      correlation_group1 = corr_concordant,
      correlation_group2 = corr2_sub_common[rownames(corr_concordant), 
                                            colnames(corr_concordant), drop = FALSE]
    )
  } else {
    results$concordant <- list(
      correlation_group1 = matrix(numeric(0), nrow = 0, ncol = 0),
      correlation_group2 = matrix(numeric(0), nrow = 0, ncol = 0)
    )
  }
  
  # ===== 2. Discordant: 使用共同taxa =====
  opposite_mask <- sig1_common & sig2_common & 
    ((corr1_sub_common > 0 & corr2_sub_common < 0) | 
     (corr1_sub_common < 0 & corr2_sub_common > 0))
  
  corr_opposite <- corr1_sub_common
  corr_opposite[!opposite_mask] <- NA
  corr_opposite <- remove_empty_rows_cols(corr_opposite)
  
  if(nrow(corr_opposite) > 0) {
    results$discordant <- list(
      correlation_group1 = corr_opposite,
      correlation_group2 = corr2_sub_common[rownames(corr_opposite), 
                                            colnames(corr_opposite), drop = FALSE]
    )
  } else {
    results$discordant <- list(
      correlation_group1 = matrix(numeric(0), nrow = 0, ncol = 0),
      correlation_group2 = matrix(numeric(0), nrow = 0, ncol = 0)
    )
  }
  
  # ===== 3. Only in group1: 使用group1的所有taxa =====
  # 建立group1的顯著性mask
  sig1_all <- (abs(corr1_sub_all) >= threshold_corr) & (p1_sub_all <= threshold_p)
  
  # 對於group1中的每個bacteria-fungi配對，檢查是否在group2中也顯著
  only_group1_mask <- sig1_all
  
  for(i in 1:nrow(corr1_sub_all)) {
    for(j in 1:ncol(corr1_sub_all)) {
      bact <- rownames(corr1_sub_all)[i]
      fung <- colnames(corr1_sub_all)[j]
      
      # 檢查這個配對是否在group2中
      if(bact %in% rownames(corr2_sub_all) && fung %in% colnames(corr2_sub_all)) {
        # 如果在group2中，檢查是否也顯著
        bact_idx_g2 <- which(rownames(corr2_sub_all) == bact)
        fung_idx_g2 <- which(colnames(corr2_sub_all) == fung)
        
        if(length(bact_idx_g2) > 0 && length(fung_idx_g2) > 0) {
          sig2_this <- (abs(corr2_sub_all[bact_idx_g2, fung_idx_g2]) >= threshold_corr) & 
                       (p2_sub_all[bact_idx_g2, fung_idx_g2] <= threshold_p)
          
          # 如果在group2中也顯著，則不算入only_in_group1
          if(sig2_this) {
            only_group1_mask[i, j] <- FALSE
          }
        }
      }
    }
  }
  
  corr_only_g1 <- corr1_sub_all
  corr_only_g1[!only_group1_mask] <- NA
  corr_only_g1 <- remove_empty_rows_cols(corr_only_g1)
  results[[paste0("only_in_", group1)]] <- corr_only_g1
  
  # ===== 4. Only in group2: 使用group2的所有taxa =====
  # 建立group2的顯著性mask
  sig2_all <- (abs(corr2_sub_all) >= threshold_corr) & (p2_sub_all <= threshold_p)
  
  # 對於group2中的每個bacteria-fungi配對，檢查是否在group1中也顯著
  only_group2_mask <- sig2_all
  
  for(i in 1:nrow(corr2_sub_all)) {
    for(j in 1:ncol(corr2_sub_all)) {
      bact <- rownames(corr2_sub_all)[i]
      fung <- colnames(corr2_sub_all)[j]
      
      # 檢查這個配對是否在group1中
      if(bact %in% rownames(corr1_sub_all) && fung %in% colnames(corr1_sub_all)) {
        # 如果在group1中，檢查是否也顯著
        bact_idx_g1 <- which(rownames(corr1_sub_all) == bact)
        fung_idx_g1 <- which(colnames(corr1_sub_all) == fung)
        
        if(length(bact_idx_g1) > 0 && length(fung_idx_g1) > 0) {
          sig1_this <- (abs(corr1_sub_all[bact_idx_g1, fung_idx_g1]) >= threshold_corr) & 
                       (p1_sub_all[bact_idx_g1, fung_idx_g1] <= threshold_p)
          
          # 如果在group1中也顯著，則不算入only_in_group2
          if(sig1_this) {
            only_group2_mask[i, j] <- FALSE
          }
        }
      }
    }
  }
  
  corr_only_g2 <- corr2_sub_all
  corr_only_g2[!only_group2_mask] <- NA
  corr_only_g2 <- remove_empty_rows_cols(corr_only_g2)
  results[[paste0("only_in_", group2)]] <- corr_only_g2
  
  # 輸出摘要信息
  cat(paste0("\n=== Correlation Comparison Analysis ===\n"))
  cat(paste0("Taxarank: ", taxarank, "\n"))
  cat(paste0("Comparison: ", comparison, "\n"))
  cat(paste0("Groups: ", group1, " vs ", group2, "\n"))
  cat(paste0("Threshold |correlation|: >= ", threshold_corr, "\n"))
  cat(paste0("Threshold BH-adjusted p-value: <= ", threshold_p, "\n\n"))
  
  # 顯示原始組別統計
  cat(paste0("=== Original Group Statistics ===\n"))
  cat(paste0(group1, " (", nrow(corr1_sub_all), " × ", ncol(corr1_sub_all), " pairs):\n"))
  cat(paste0("  - Total significant: ", g1_total, " pairs\n"))
  cat(paste0("  - Positive correlations: ", g1_positive, " pairs\n"))
  cat(paste0("  - Negative correlations: ", g1_negative, " pairs\n\n"))
  
  cat(paste0(group2, " (", nrow(corr2_sub_all), " × ", ncol(corr2_sub_all), " pairs):\n"))
  cat(paste0("  - Total significant: ", g2_total, " pairs\n"))
  cat(paste0("  - Positive correlations: ", g2_positive, " pairs\n"))
  cat(paste0("  - Negative correlations: ", g2_negative, " pairs\n\n"))
  
  # 顯示比較結果
  cat(paste0("=== Comparison Results ===\n"))
  cat(paste0("1. Concordant (same direction, both significant): ", 
             sum(!is.na(results$concordant$correlation_group1)), " pairs\n"))
  cat(paste0("2. Discordant (opposite direction, both significant): ", 
             sum(!is.na(results$discordant$correlation_group1)), " pairs\n"))
  cat(paste0("3. Only in ", group1, ": ", 
             sum(!is.na(results[[paste0("only_in_", group1)]])), " pairs\n"))
  cat(paste0("4. Only in ", group2, ": ", 
             sum(!is.na(results[[paste0("only_in_", group2)]])), " pairs\n\n"))
  
  # 保存參數信息和統計
  results$parameters <- list(
    taxarank = taxarank,
    comparison = comparison,
    groups = groups,
    bacteria_names_group1 = bacteria_names_g1,
    fungi_names_group1 = fungi_names_g1,
    bacteria_names_group2 = bacteria_names_g2,
    fungi_names_group2 = fungi_names_g2,
    bacteria_names_common = common_bacteria,
    fungi_names_common = common_fungi,
    threshold_corr = threshold_corr,
    threshold_p = threshold_p
  )
  
  # 保存原始統計
  results$original_statistics <- list(
    group1 = list(
      name = group1,
      total = g1_total,
      positive = g1_positive,
      negative = g1_negative,
      dimension = c(nrow(corr1_sub_all), ncol(corr1_sub_all))
    ),
    group2 = list(
      name = group2,
      total = g2_total,
      positive = g2_positive,
      negative = g2_negative,
      dimension = c(nrow(corr2_sub_all), ncol(corr2_sub_all))
    )
  )
  
  return(results)
}

# 輔助函數：移除全為NA的行和列
remove_empty_rows_cols <- function(mat) {
  if(nrow(mat) == 0 | ncol(mat) == 0) {
    return(matrix(numeric(0), nrow = 0, ncol = 0))
  }
  
  keep_rows <- rowSums(!is.na(mat)) > 0
  keep_cols <- colSums(!is.na(mat)) > 0
  
  if(sum(keep_rows) == 0 | sum(keep_cols) == 0) {
    return(matrix(numeric(0), nrow = 0, ncol = 0))
  }
  
  return(mat[keep_rows, keep_cols, drop = FALSE])
}

# 根據 compare_correlations 結果繪製 heatmap（字體大小可分別調整版）
plot_correlation_comparison <- function(comparison_results,
                                       cluster = TRUE,
                                       fontsize = 10,
                                       fontsize_row = NULL,
                                       fontsize_col = NULL,
                                       width = 40,
                                       height = 20,
                                       show.values = c(4, -4, 2, -2, 1, -1, 3, -3)) {

  # 如果沒有指定 fontsize_row 或 fontsize_col，則使用 fontsize
  if(is.null(fontsize_row)) {
    fontsize_row <- fontsize
  }
  if(is.null(fontsize_col)) {
    fontsize_col <- fontsize
  }

  # 提取參數
  params <- comparison_results$parameters
  g1name <- params$groups[1]
  g2name <- params$groups[2]

  # Step 1: 收集所有出現的 bacteria 和 fungi
  all_bacteria <- c()
  all_fungi <- c()

  # 從 concordant 收集
  if(nrow(comparison_results$concordant$correlation_group1) > 0) {
    all_bacteria <- c(all_bacteria, rownames(comparison_results$concordant$correlation_group1))
    all_fungi <- c(all_fungi, colnames(comparison_results$concordant$correlation_group1))
  }

  # 從 discordant 收集
  if(nrow(comparison_results$discordant$correlation_group1) > 0) {
    all_bacteria <- c(all_bacteria, rownames(comparison_results$discordant$correlation_group1))
    all_fungi <- c(all_fungi, colnames(comparison_results$discordant$correlation_group1))
  }

  # 從 only_in_group1 收集
  only_g1_key <- paste0("only_in_", g1name)
  if(nrow(comparison_results[[only_g1_key]]) > 0) {
    all_bacteria <- c(all_bacteria, rownames(comparison_results[[only_g1_key]]))
    all_fungi <- c(all_fungi, colnames(comparison_results[[only_g1_key]]))
  }

  # 從 only_in_group2 收集
  only_g2_key <- paste0("only_in_", g2name)
  if(nrow(comparison_results[[only_g2_key]]) > 0) {
    all_bacteria <- c(all_bacteria, rownames(comparison_results[[only_g2_key]]))
    all_fungi <- c(all_fungi, colnames(comparison_results[[only_g2_key]]))
  }

  # 去重並排序
  all_bacteria <- unique(all_bacteria)
  all_fungi <- unique(all_fungi)

  if(length(all_bacteria) == 0 | length(all_fungi) == 0) {
    stop("No significant correlations found to plot")
  }

  cat(paste0("Creating combined matrix with ", length(all_bacteria),
             " bacteria and ", length(all_fungi), " fungi\n"))

  # Step 2: 創建組合矩陣（初始化為0）
  combined_matrix <- matrix(0, nrow = length(all_bacteria), ncol = length(all_fungi))
  rownames(combined_matrix) <- all_bacteria
  colnames(combined_matrix) <- all_fungi

  # Step 3: 填入 concordant (兩組方向一致)
  if(nrow(comparison_results$concordant$correlation_group1) > 0) {
    concordant_g1 <- comparison_results$concordant$correlation_group1
    concordant_g2 <- comparison_results$concordant$correlation_group2

    for(i in 1:nrow(concordant_g1)) {
      for(j in 1:ncol(concordant_g1)) {
        if(!is.na(concordant_g1[i, j])) {
          bact <- rownames(concordant_g1)[i]
          fung <- colnames(concordant_g1)[j]

          # 判斷是正相關還是負相關
          if(concordant_g1[i, j] > 0) {
            # 兩組都是正相關
            combined_matrix[bact, fung] <- 4
          } else {
            # 兩組都是負相關
            combined_matrix[bact, fung] <- -4
          }
        }
      }
    }
  }

  # Step 4: 填入 discordant (兩組方向相反)
  if(nrow(comparison_results$discordant$correlation_group1) > 0) {
    discordant_g1 <- comparison_results$discordant$correlation_group1
    discordant_g2 <- comparison_results$discordant$correlation_group2

    for(i in 1:nrow(discordant_g1)) {
      for(j in 1:ncol(discordant_g1)) {
        if(!is.na(discordant_g1[i, j])) {
          bact <- rownames(discordant_g1)[i]
          fung <- colnames(discordant_g1)[j]

          # 判斷是 g1正g2負 還是 g1負g2正
          if(discordant_g1[i, j] > 0 & discordant_g2[i, j] < 0) {
            # g1是正相關，g2是負相關
            combined_matrix[bact, fung] <- -3
          } else if(discordant_g1[i, j] < 0 & discordant_g2[i, j] > 0) {
            # g1是負相關，g2是正相關
            combined_matrix[bact, fung] <- 3
          }
        }
      }
    }
  }

  # Step 5: 填入 only_in_group1
  if(nrow(comparison_results[[only_g1_key]]) > 0) {
    only_g1_mat <- comparison_results[[only_g1_key]]

    for(i in 1:nrow(only_g1_mat)) {
      for(j in 1:ncol(only_g1_mat)) {
        if(!is.na(only_g1_mat[i, j])) {
          bact <- rownames(only_g1_mat)[i]
          fung <- colnames(only_g1_mat)[j]

          # 判斷是正相關還是負相關
          if(only_g1_mat[i, j] > 0) {
            combined_matrix[bact, fung] <- 1
          } else {
            combined_matrix[bact, fung] <- -1
          }
        }
      }
    }
  }

  # Step 6: 填入 only_in_group2
  if(nrow(comparison_results[[only_g2_key]]) > 0) {
    only_g2_mat <- comparison_results[[only_g2_key]]

    for(i in 1:nrow(only_g2_mat)) {
      for(j in 1:ncol(only_g2_mat)) {
        if(!is.na(only_g2_mat[i, j])) {
          bact <- rownames(only_g2_mat)[i]
          fung <- colnames(only_g2_mat)[j]

          # 判斷是正相關還是負相關
          if(only_g2_mat[i, j] > 0) {
            combined_matrix[bact, fung] <- 2
          } else {
            combined_matrix[bact, fung] <- -2
          }
        }
      }
    }
  }

  # Step 7: 過濾矩陣（只保留指定值）
  filtered_table <- combined_matrix
  filtered_table[!(filtered_table %in% show.values)] <- 0

  # Step 8: 移除全為 0 的行與列
  row_keep <- rowSums(filtered_table != 0) > 0
  col_keep <- colSums(filtered_table != 0) > 0
  filtered_table <- filtered_table[row_keep, col_keep, drop = FALSE]

  if(nrow(filtered_table) == 0 | ncol(filtered_table) == 0) {
    stop("No data to plot after filtering")
  }

  cat(paste0("Final matrix size: ", nrow(filtered_table), " bacteria × ",
             ncol(filtered_table), " fungi\n"))
  cat(paste0("Row names fontsize: ", fontsize_row, "\n"))
  cat(paste0("Column names fontsize: ", fontsize_col, "\n"))

  # Step 9: 顏色對應定義
  color_map <- c(
    "4" = "firebrick",
    "-4" = "steelblue3",
    "2" = "darkorange",
    "-2" = "forestgreen",
    "1" = "goldenrod",
    "-1" = "slateblue",
    "-3" = "dimgray",
    "3" = "darkgray",
    "0" = "white"
  )

  # 保留顯示值與 0 的顏色對應
  show_levels <- as.character(sort(unique(c(show.values, 0))))
  combined.colors <- color_map[show_levels]

  # Step 10: Heatmap 主體（使用分別的字體大小）
  combined.heatmap <- ComplexHeatmap::Heatmap(
    filtered_table,
    name = "compared.status",
    col = combined.colors,
    rect_gp = grid::gpar(col = "whitesmoke", lwd = 0.5),
    cluster_rows = cluster,
    row_dend_width = grid::unit(2, "cm"),
    row_names_side = "right",
    row_names_max_width = grid::unit(9, "cm"),
    row_names_gp = grid::gpar(fontsize = fontsize_row),  # Y軸字體大小
    cluster_columns = cluster,
    column_dend_height = grid::unit(2.2, "cm"),
    column_names_side = "bottom",
    column_names_max_height = grid::unit(8, "cm"),
    column_names_rot = 90,
    column_names_gp = grid::gpar(fontsize = fontsize_col),  # X軸字體大小
    show_heatmap_legend = FALSE,
    heatmap_width = grid::unit(width, "cm"),
    heatmap_height = grid::unit(height, "cm")
  )

  # Step 11: 圖例標籤
  label_map <- c(
    "4" = "Positive in both groups",
    "-4" = "Negative in both groups",
    "2" = paste0("Positive only in ", g2name),
    "-2" = paste0("Negative only in ", g2name),
    "1" = paste0("Positive only in ", g1name),
    "-1" = paste0("Negative only in ", g1name),
    "3" = paste0("Positive in ", g2name, " & Negative in ", g1name),
    "-3" = paste0("Negative in ", g2name, " & Positive in ", g1name)
  )

  legend_labels <- label_map[as.character(show.values)]
  legend_colors <- color_map[as.character(show.values)]

  combined.legend <- ComplexHeatmap::Legend(
    title = "Correlation Status",
    labels = legend_labels,
    legend_gp = grid::gpar(fill = legend_colors),
    border = TRUE,
    background = "black"
  )

  # Step 12: 繪圖
  ComplexHeatmap::draw(
    combined.heatmap,
    annotation_legend_list = list(combined.legend)
  )

  # 返回組合矩陣供後續使用
  invisible(list(
    combined_matrix = combined_matrix,
    filtered_matrix = filtered_table
  ))
}
