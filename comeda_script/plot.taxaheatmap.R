## ===================================================================================================================
## function name : drawtaxaheatmap
## draw a taxa * sample heatmap (overview of taxa community)
## CoMeDA v3.1 - Support Multi-Group Selection & Violin Plot
## Updated: 2025-12-06
## ===================================================================================================================

# ^=============================================================================
# Helper Functions
# ==============================================================================
calc_heatmap_size <- function(n_samples, n_taxa) {
  left_panel_width <- 4; row_names_width <- 8; legend_width <- 5
  row_dend_width <- 1.5; top_anno_height <- 1.5; col_dend_height <- 1.5; margin <- 1.5
  cell_width_min <- 0.15; cell_height_min <- 0.18
  cell_width_comfort <- 0.25; cell_height_comfort <- 0.30
  screen_width <- 48; screen_height <- 26
  
  ideal_cell_width <- (screen_width - left_panel_width - row_names_width - legend_width) / n_samples
  ideal_cell_height <- (screen_height - top_anno_height - col_dend_height) / n_taxa
  
  final_cell_width <- dplyr::case_when(ideal_cell_width >= cell_width_comfort ~ cell_width_comfort, ideal_cell_width >= cell_width_min ~ ideal_cell_width, TRUE ~ cell_width_min)
  final_cell_height <- dplyr::case_when(ideal_cell_height >= cell_height_comfort ~ cell_height_comfort, ideal_cell_height >= cell_height_min ~ ideal_cell_height, TRUE ~ cell_height_min)
  
  main_heatmap_width <- final_cell_width * n_samples
  main_heatmap_height <- final_cell_height * n_taxa
  
  total_width <- main_heatmap_width + left_panel_width + row_names_width + row_dend_width + legend_width + margin
  total_height <- main_heatmap_height + top_anno_height + col_dend_height + margin
  
  final_width <- min(max(total_width, 20), 100); final_height <- min(max(total_height, 15), 80)
  return(list(width = round(final_width, 1), height = round(final_height, 1), needs_scroll = (total_width > screen_width | total_height > screen_height)))
}

perform_global_prefilter <- function(prop, meta, comparecol, propcutvalue, prevcutvalue) {
  group_levels <- unique(na.omit(meta[[comparecol]]))
  keep_taxa <- c()
  for (grp in group_levels) {
    grp_samples <- rownames(meta)[meta[[comparecol]] == grp]
    grp_samples <- intersect(grp_samples, rownames(prop))
    if (length(grp_samples) > 0) {
      grp_prop <- prop[grp_samples, , drop = FALSE]
      grp_prev <- colSums(grp_prop >= (propcutvalue / 100), na.rm = TRUE) / length(grp_samples) * 100
      pass_taxa <- names(grp_prev)[grp_prev >= prevcutvalue]
      keep_taxa <- unique(c(keep_taxa, pass_taxa))
    }
  }
  return(keep_taxa)
}

filter_taxa_by_dam <- function(available_taxa, dam_result, dam_pvalue_type, dam_pvalue_cut, dam_effect_cut) {
  if (is.null(dam_result) || nrow(dam_result) == 0) return(list(taxa = character(0), message = "DAM result is empty."))
  pvalue_col <- if (dam_pvalue_type == "adjp") "adj.pvalue" else "wilcox.test.p"
  filtered <- dam_result %>% dplyr::filter(!!sym(pvalue_col) <= dam_pvalue_cut & abs(cliff.effect) >= dam_effect_cut)
  final_taxa <- intersect(rownames(filtered), available_taxa)
  if (length(final_taxa) == 0) return(list(taxa = character(0), message = "No taxa met DAM criteria."))
  return(list(taxa = final_taxa, message = NULL))
}

filter_taxa_by_abundance <- function(available_taxa, clr, meta, comparecol, compareref, top_n, top_n_group) {
  if (is.null(top_n_group) || top_n_group == "") top_n_group <- compareref
  group_samples <- rownames(meta)[meta[[comparecol]] == top_n_group]
  if (length(group_samples) == 0) return(list(taxa = character(0), message = "No samples found for sorting."))
  group_clr <- clr[rownames(clr) %in% group_samples, available_taxa, drop = FALSE]
  group_median <- apply(group_clr, 2, median, na.rm = TRUE)
  taxa_ranked <- sort(group_median, decreasing = TRUE)
  n_display <- min(top_n, length(taxa_ranked))
  final_taxa <- names(taxa_ranked)[1:n_display]
  if (length(final_taxa) == 0) return(list(taxa = character(0), message = "No taxa available."))
  return(list(taxa = final_taxa, message = NULL))
}

filter_taxa_by_custom <- function(available_taxa, custom_taxa) {
  if (is.null(custom_taxa) || length(custom_taxa) == 0) return(list(taxa = character(0), message = "No taxa selected."))
  valid_taxa <- custom_taxa[custom_taxa %in% available_taxa]
  if (length(valid_taxa) == 0) return(list(taxa = character(0), message = "Selected taxa did not meet global thresholds."))
  return(list(taxa = valid_taxa, message = NULL))
}

parse_compevents <- function(compevents) {
  if (is.null(compevents) || compevents == "") return(list(case = NULL, ref = NULL))
  parts <- strsplit(compevents, "\\.vs\\.")[[1]]
  if (length(parts) == 2) return(list(case = trimws(parts[1]), ref = trimws(parts[2])))
  return(list(case = NULL, ref = NULL))
}

# ^=============================================================================
# Main Function 1: drawtaxaheatmap
# ==============================================================================

drawtaxaheatmap <- function(
    input_prop, input_clr, input_meta, input_dam = NULL,
    taxalevel, comparecol, compareref,
    filter_mode = "abundance_prevalence",
    compevents = NULL, dam_pvalue_type = "pvalue", dam_pvalue_cut = 0.05, dam_effect_cut = 0.5,
    abundance_mode = "topn", top_n = 30, top_n_group = NULL, propcutvalue = 1, prevcutvalue = 10,
    custom_taxa = NULL,
    comparecase = "all", # [MODIFIED] Now accepts vector of groups
    sample_order = "group", annotation_cols = NULL, show_sample_names = FALSE, fontsize = 9,
    input_palette = NULL,
    width = NULL, height = NULL, return_object = FALSE
) {
  
  #require(dplyr); require(tidyr); require(ComplexHeatmap); require(circlize); require(grid)
  
  # Step 0: Validation
  if (is.null(input_prop) || is.null(input_clr) || is.null(input_meta)) stop("Input data is missing.")
  if (is.null(compareref) || compareref == "") stop("compareref is required.")
  if (!comparecol %in% colnames(input_meta)) stop(paste0("Column '", comparecol, "' not found."))
  
  dam_result <- NULL
  if (filter_mode == "dam") {
    if (is.null(input_dam)) stop("DAM result is missing.")
    dam_result <- input_dam
    sample_order <- "group"; annotation_cols <- NULL
  }
  
  # Step 1: Filter Metadata
  meta.wona <- input_meta %>% dplyr::filter(!is.na(!!sym(comparecol)))
  
  # [MODIFIED] Group Filtering Logic
  if (!is.null(comparecase) && length(comparecase) > 0 && !identical(comparecase, "all")) {
    meta.wona <- meta.wona %>% dplyr::filter(!!sym(comparecol) %in% comparecase)
  }
  
  # Ensure Ref is first level if present
  if (compareref %in% unique(meta.wona[[comparecol]])) {
    meta.wona[[comparecol]] <- relevel(factor(meta.wona[[comparecol]]), ref = compareref)
  } else {
    meta.wona[[comparecol]] <- factor(meta.wona[[comparecol]])
  }
  
  valid_samples <- rownames(meta.wona)
  if(length(valid_samples) == 0) {
	  grid::grid.newpage(); grid::pushViewport(viewport()); grid::grid.text("No samples selected.", gp = grid::gpar(col="red")); grid::popViewport(); return(invisible(NULL))
  }

  prop <- input_prop[rownames(input_prop) %in% valid_samples, , drop = FALSE]
  clr <- input_clr[rownames(input_clr) %in% valid_samples, , drop = FALSE]
  
  # Step 1.5: Global Pre-filtering
  prefiltered_taxa <- perform_global_prefilter(prop, meta.wona, comparecol, propcutvalue, prevcutvalue)
  if (length(prefiltered_taxa) == 0) {
    if (return_object) return(list(heatmap = NULL))
    grid::grid.newpage(); grid::pushViewport(viewport())
    grid::grid.text(paste0("No taxa met the Global Thresholds.\n(Abund >= ", propcutvalue, "% & Prev >= ", prevcutvalue, "%)"), gp = grid::gpar(col = "#d9534f", fontsize = 18, fontface = "bold"))
    grid::popViewport(); return(invisible(NULL))
  }
  
  # Step 2: Module Filtering
  filter_result <- switch(filter_mode,
                          "dam" = filter_taxa_by_dam(prefiltered_taxa, dam_result, dam_pvalue_type, dam_pvalue_cut, dam_effect_cut),
                          "abundance_prevalence" = filter_taxa_by_abundance(prefiltered_taxa, clr, meta.wona, comparecol, compareref, top_n, top_n_group),
                          "custom" = filter_taxa_by_custom(prefiltered_taxa, custom_taxa),
                          list(taxa = character(0), message = "Invalid filter_mode")
  )
  taxa_filtered_list <- filter_result$taxa
  
  if (length(taxa_filtered_list) == 0) {
    if (return_object) return(list(heatmap = NULL))
    grid::grid.newpage(); grid::pushViewport(grid::viewport())
    grid::grid.text(paste0("No taxa found.\nModule Reason: ", filter_result$message), gp = grid::gpar(col = "#d9534f", fontsize = 18, fontface = "bold"))
    grid::popViewport(); return(invisible(NULL))
  }
  
  if (sample_order == "cluster" && length(taxa_filtered_list) < 2) {
    grid::grid.newpage(); grid::pushViewport(grid::viewport())
    grid::grid.text("Too few taxa (n < 2) for clustering.\nSwitch to 'Group by Comp.'", gp = grid::gpar(col = "#d9534f", fontsize = 18, fontface = "bold"))
    grid::popViewport(); return(invisible(NULL))
  }
  
  # Step 4: Stats
  group_levels <- levels(meta.wona[[comparecol]])
  group_prev <- do.call(cbind, lapply(group_levels, function(grp) {
    samps <- rownames(meta.wona)[meta.wona[[comparecol]] == grp]
    if(length(samps)==0) return(rep(0, length(taxa_filtered_list)))
    colSums(prop[samps, taxa_filtered_list, drop=F] >= (propcutvalue/100), na.rm=T)/length(samps)*100
  })) %>% data.frame(check.names=F) %>% setNames(group_levels)
  
  group_median_abund <- do.call(cbind, lapply(group_levels, function(grp) {
    samps <- rownames(meta.wona)[meta.wona[[comparecol]] == grp]
    if(length(samps)==0) return(rep(0, length(taxa_filtered_list)))
    apply(clr[samps, taxa_filtered_list, drop=F], 2, median, na.rm=T)
  })) %>% data.frame(check.names=F) %>% setNames(group_levels)
  
  rownames(group_prev) <- taxa_filtered_list; rownames(group_median_abund) <- taxa_filtered_list
  
  # Step 5: Colors
  abund_col_func <- lapply(group_levels, function(grp) {
    val <- group_median_abund[[grp]]; mn <- min(val, na.rm=T); mx <- max(val, na.rm=T)
    if(mn >= 0) circlize::colorRamp2(c(0, mx), c("white", "darkorange")) else if(mx <= 0) circlize::colorRamp2(c(mn, 0), c("forestgreen", "white")) else circlize::colorRamp2(c(mn, 0, mx), c("forestgreen", "white", "darkorange"))
  })
  names(abund_col_func) <- group_levels
  prev_col_func <- circlize::colorRamp2(c(1, length(group_levels)), c("gainsboro", "dimgray"))
  
  clr_filtered <- clr[rownames(meta.wona), taxa_filtered_list, drop = FALSE]
  clr_scale <- base::scale(clr_filtered)
  heatmap_col_func <- circlize::colorRamp2(c(min(clr_scale, na.rm=T), 0, max(clr_scale, na.rm=T)), c("steelblue3", "white", "firebrick"))
  
  # Clustering
  sample_clust <- hclust(vegan::vegdist(clr[rownames(meta.wona), taxa_filtered_list], method="euclidean"), method="ward.D2")
  taxa_clust <- hclust(vegan::vegdist(t(clr[rownames(meta.wona), taxa_filtered_list]), method="euclidean"), method="ward.D2")
  
  # Step 8: Annotations
  abund_prev_anno <- ComplexHeatmap::rowAnnotation(
    df = group_median_abund,
    prevalence = ComplexHeatmap::anno_barplot(as.matrix(group_prev), beside=T, border=F, bar_width=0.8, width=unit(1.5, "cm"), gp=grid::gpar(fill=prev_col_func(seq_len(length(group_levels))))),
    col = abund_col_func, annotation_name_side="top", annotation_name_rot=90, annotation_name_gp=grid::gpar(fontsize=8), show_legend=FALSE
  )
  
  group_anno <- NULL
  if (!is.null(annotation_cols) && length(annotation_cols) > 0) {
    group_anno_df <- meta.wona[, annotation_cols, drop=F]
    palette_to_use <- if (!is.null(input_palette)) input_palette else c("steelblue", "tomato", "forestgreen", "darkorange", "firebrick")
    group_col_choice <- lapply(annotation_cols, function(col) {
      lvls <- levels(factor(group_anno_df[[col]])); setNames(rep(palette_to_use, length.out=length(lvls)), lvls)
    })
    names(group_col_choice) <- annotation_cols
    group_anno <- ComplexHeatmap::HeatmapAnnotation(df = group_anno_df, col = group_col_choice)
  }

  # Step 8.5: Comparison Group Annotation (for sample_order = "group")
  comp_group_anno <- NULL
  if (sample_order != "cluster") {
    comp_anno_df <- data.frame(Group = meta.wona[[comparecol]], row.names = rownames(meta.wona))
    palette_to_use <- if (!is.null(input_palette)) input_palette else c("steelblue", "tomato", "forestgreen", "darkorange", "firebrick")
    comp_lvls <- levels(meta.wona[[comparecol]])
    comp_col <- setNames(rep(palette_to_use, length.out = length(comp_lvls)), comp_lvls)
    comp_group_anno <- ComplexHeatmap::HeatmapAnnotation(
      Group = comp_anno_df$Group,
      col = list(Group = comp_col),
      show_annotation_name = F,
      show_legend = T,
      annotation_name_gp = grid::gpar(fontsize = 8),
      simple_anno_size = unit(0.4, "cm")
    )
  }
  
  # Step 9: Plot & Size
  n_s <- nrow(meta.wona); n_t <- length(taxa_filtered_list)
  if (is.null(width) || is.null(height)) { sc <- calc_heatmap_size(n_s, n_t); if(is.null(width)) width <- sc$width; if(is.null(height)) height <- sc$height }
  
  max_lbl_width <- ComplexHeatmap::max_text_width(taxa_filtered_list, gp = grid::gpar(fontsize = fontsize))
  
  common_args <- list(
    matrix = t(clr_scale), name = "normalized.clr", col = heatmap_col_func, 
    na_col = "whitesmoke", rect_gp = grid::gpar(col="whitesmoke", lwd=0.5), 
    row_dend_side="right", row_dend_width=unit(1.8, "cm"), 
    row_names_side="left", row_names_max_width=max_lbl_width, row_names_gp=grid::gpar(fontsize=fontsize), 
    cluster_rows=taxa_clust, 
    column_dend_side="bottom", column_dend_height=unit(1.8, "cm"), 
    column_names_side="top", column_names_max_height=unit(8, "cm"), column_names_rot=90, column_names_gp=grid::gpar(fontsize=fontsize), 
    show_column_names=show_sample_names, 
    show_heatmap_legend=FALSE, left_annotation=abund_prev_anno
  )
  
  if (sample_order == "cluster") heatmap_plot <- do.call(ComplexHeatmap::Heatmap, c(common_args, list(cluster_columns = sample_clust, top_annotation = group_anno)))
#  else heatmap_plot <- do.call(ComplexHeatmap::Heatmap, c(common_args, list(column_split = meta.wona[[comparecol]], cluster_columns = FALSE, column_title_gp = grid::gpar(fontsize = fontsize + 2, fontface = "bold"))))
  else heatmap_plot <- do.call(ComplexHeatmap::Heatmap, c(common_args, list(column_split = meta.wona[[comparecol]], cluster_columns = FALSE, column_title_gp = grid::gpar(fontsize = fontsize + 2, fontface = "bold"), top_annotation = comp_group_anno)))
  
  ref_for_lgd <- if(compareref %in% names(abund_col_func)) compareref else names(abund_col_func)[1]
  lgd_list <- list(
    ComplexHeatmap::Legend(title="Normalized CLR", col_fun=heatmap_col_func), 
    ComplexHeatmap::Legend(title=paste0("Median CLR\n(Abundance: ", ref_for_lgd, ")"), col_fun=abund_col_func[[ref_for_lgd]]), 
    ComplexHeatmap::Legend(title=paste0("Prevalence\n(prop >= ", propcutvalue, "%)"), labels=group_levels, legend_gp=grid::gpar(fill=prev_col_func(seq_len(length(group_levels)))))
  )
  
  if (return_object) return(list(heatmap = heatmap_plot)) 
  else { 
    ComplexHeatmap::draw(heatmap_plot, annotation_legend_list = lgd_list, padding = unit(c(10, 20, 10, 40), "mm"))
    return(invisible(NULL)) 
  }
}

# ^=============================================================================
# Main Function 2: drawtaxaviolinplot
# ==============================================================================
drawtaxaviolinplot <- function(
    input_clr, input_meta, taxa_list, comparecol, comparecase = "all", compareref,
    ncol = 5, dotsize = 2, input_palette = NULL
) {
  #require(dplyr); require(ggplot2); require(ggiraph); require(ggpubr); require(reshape2); require(tibble)
  
  if (is.null(input_clr) || is.null(input_meta)) stop("Input data missing")
  if (length(taxa_list) == 0) return(NULL)
  
  data_sub <- input_clr[, taxa_list, drop = FALSE]
  common <- intersect(rownames(data_sub), rownames(input_meta))
  data_sub <- data_sub[common, , drop=FALSE]
  meta_sub <- input_meta[common, , drop=FALSE]
  
  if (!is.null(comparecase) && length(comparecase) > 0 && !("all" %in% comparecase)) {
    keep <- meta_sub[[comparecol]] %in% comparecase
    data_sub <- data_sub[keep, , drop=FALSE]
    meta_sub <- meta_sub[keep, , drop=FALSE]
  }
  
  df_long <- data_sub %>% as.data.frame() %>% rownames_to_column("Sample") %>%
    tidyr::gather(key = "Taxon", value = "Value", -Sample) %>%
    left_join(meta_sub %>% rownames_to_column("Sample"), by = "Sample") %>%
    dplyr::filter(!is.na(!!sym(comparecol)))
  
  df_long[[comparecol]] <- factor(df_long[[comparecol]])
  if (compareref %in% levels(df_long[[comparecol]])) {
    df_long[[comparecol]] <- relevel(df_long[[comparecol]], ref = compareref)
  }
  
  n_groups <- nlevels(df_long[[comparecol]])
  my_cols <- if(!is.null(input_palette)) rep(input_palette, length.out=n_groups) else scales::hue_pal()(n_groups)
  names(my_cols) <- levels(df_long[[comparecol]])
  
  median_marks <- df_long %>% dplyr::group_by(Taxon, !!sym(comparecol)) %>% dplyr::summarise(mark.value = median(Value, na.rm = TRUE), .groups="drop")
 
  # [MODIFIED] Max Y calculation logic retained for potential scaling issues, 
  # but NOT used in stat_compare_means aesthetic anymore
  max_y_per_taxon <- df_long %>%
    dplyr::group_by(Taxon) %>%
    dplyr::summarise(max_y = max(Value, na.rm = TRUE) + 0.5, .groups = "drop")

  p <- ggplot(df_long, aes_string(x = comparecol, y = "Value", color = comparecol)) +
        geom_violin(adjust = 0.5, trim = FALSE, alpha = 0.3) +
        geom_jitter_interactive(aes(tooltip = paste0("Sample: ", Sample, "\nCLR: ", round(Value, 3)), data_id = Sample),
                                size = dotsize, width = 0.2, alpha = 0.7) +
        geom_segment(data = median_marks, aes(x = as.numeric(!!sym(comparecol)) - 0.4, xend = as.numeric(!!sym(comparecol)) + 0.4, y = mark.value, yend = mark.value),
                     color = "black", linetype = "solid", linewidth = 0.8) +
        facet_wrap(~ Taxon, ncol = ncol, scales = "free_y") +
        scale_color_manual(values = my_cols) +
        theme_minimal(base_size = 12) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "none", strip.text = element_text(face = "bold")) +
        labs(y = "Centered Log-Ratio (CLR) Abundance", x = NULL)

        if (n_groups >= 2) {
    
          # 1. Expand Y axis to make room for brackets and p-values
#          p <- p + scale_y_continuous(expand = expansion(mult = c(0.05, 0.2)))
    
          # 2. Dynamic Comparisons List
          # Create pairs for all groups against the reference
          all_levels <- levels(df_long[[comparecol]])
          case_levels <- setdiff(all_levels, compareref)
          my_comparisons <- lapply(case_levels, function(x) c(compareref, x))
    
          # 3. Add Pairwise Comparisons with Brackets
           p <- p + stat_compare_means(
             comparisons = my_comparisons,
             label = "p.format", 
             size = 3,
             step.increase = 0.08  # Stagger brackets nicely
           )
        }       
  return(p)
}
