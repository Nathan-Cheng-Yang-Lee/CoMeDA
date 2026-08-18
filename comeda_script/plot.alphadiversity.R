## ===================================================================================================================
## function name : drawalphaviolinplot
## draw violin plot of alpha diversity (Shannon/Simpson)
## CoMeDA v3.4 - Multi-group Selection Support & comedacolors support
## Updated: 2025-12-07
## ===================================================================================================================

drawalphaviolinplot <- function(
    input_prop, input_meta, 
    comparecol, comparecase = "all", compareref, 
    alpha_metric = "shannon", 
    show_stat = "yes",        
    dotsize = 2,
    input_palette = NULL
) {
  
  require(dplyr); require(ggplot2); require(ggiraph); require(ggpubr); require(vegan); require(tibble)
  
  # Validation
  if (is.null(input_prop) || is.null(input_meta)) stop("Input data is missing.")
  if (!comparecol %in% colnames(input_meta)) stop(paste0("Column '", comparecol, "' not found."))
  
  # Calc Index
  metric <- tolower(alpha_metric) 
  if (!metric %in% c("shannon", "simpson", "invsimpson")) metric <- "shannon"
  alpha_val <- vegan::diversity(input_prop, index = metric)
  
  # Merge Data
  plot_res <- data.frame(check.names = F, Value = alpha_val) %>%
    rownames_to_column("Row.names") %>%
    merge(., input_meta, by.x = "Row.names", by.y = "row.names", sort = F) %>%
    dplyr::filter(!is.na(!!sym(comparecol))) %>%
    column_to_rownames("Row.names")
  
  # [MODIFIED] Step 4: Filter based on selected groups (support vector)
  # Logic: If comparecase is NOT "all", retain only rows where group is in the comparecase vector
  if (!is.null(comparecase) && length(comparecase) > 0 && !("all" %in% comparecase)) {
    plot_res <- plot_res %>% dplyr::filter(!!sym(comparecol) %in% comparecase)
  }
  
  # Re-level
  plot_res[[comparecol]] <- factor(plot_res[[comparecol]])
  # Only relevel to ref if ref is present in the selected data
  if (compareref %in% levels(plot_res[[comparecol]])) {
    plot_res[[comparecol]] <- relevel(plot_res[[comparecol]], ref = compareref)
  }
  
  # Check if data remains
  if (nrow(plot_res) == 0) return(NULL)
  
  # [MODIFIED] Palette - Use comedacolors if available and input_palette is NULL
  n_groups <- nlevels(plot_res[[comparecol]])
  levels_groups <- levels(plot_res[[comparecol]])
  
  if (!is.null(input_palette)) {
    paired_colors <- rep(input_palette, length.out = n_groups)
  } else if (exists("comedacolors")) {
    paired_colors <- rep(comedacolors, length.out = n_groups)
  } else {
    paired_colors <- scales::hue_pal()(n_groups)
  }
  names(paired_colors) <- levels_groups
  
  # Plot
  median_marks <- plot_res %>% dplyr::group_by(!!sym(comparecol)) %>% summarise(mark.value = median(Value, na.rm = TRUE))
  y_lab_text <- paste0(tools::toTitleCase(metric), " index")
  
  p <- ggplot(plot_res, aes_string(x = comparecol, y = "Value", color = comparecol)) + 
    geom_violin(adjust = 0.5, trim = FALSE, alpha = 0.3) + 
    geom_jitter_interactive(aes(tooltip = row.names(plot_res), data_id = row.names(plot_res)), size = dotsize, width = 0.2, alpha = 0.7) + 
    geom_segment(data = median_marks, aes(x = as.numeric(as.factor(!!sym(comparecol))) - 0.4, xend = as.numeric(as.factor(!!sym(comparecol))) + 0.4, y = mark.value, yend = mark.value), color = "black", linetype = "solid", linewidth = 1) + 
    scale_color_manual(values = paired_colors) + 
    labs(x = comparecol, y = y_lab_text) + 
    theme_minimal(base_size = 11) + 
    theme(legend.position = "none", axis.text.x = element_text(angle=45, hjust=1))
  
  # Statistics
  # Only calculate stats if we have at least 2 groups
  if (nlevels(plot_res[[comparecol]]) >= 2) {
    if (show_stat == "yes") {
      comp.list <- combn(levels(plot_res[[comparecol]]), 2, simplify = FALSE)
      max_y <- max(plot_res$Value, na.rm = T); min_y <- min(plot_res$Value, na.rm = T); range_y <- max_y - min_y
      if(range_y == 0) range_y <- 1
      stat.h <- seq(from = max_y + (range_y * 0.1), by = (range_y * 0.15), length.out = length(comp.list))
      
      p <- p + ggpubr::stat_compare_means(comparisons = comp.list, label.y = stat.h) + 
        ggpubr::stat_compare_means(label.y = max(stat.h) + (range_y * 0.15))
    } else {
      p <- p + ggpubr::stat_compare_means(label.y = max(plot_res$Value, na.rm = T) * 1.1)
    }
  }
  
  return(p)
}
