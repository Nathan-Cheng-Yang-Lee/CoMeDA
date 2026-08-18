## ===================================================================================================================
## function name : drawbetaplot
## draw pcoa/pca/nmds plot (Aitchison fixed)
## CoMeDA v3.4 - Multi-group Selection & Fixed Ellipse & comedacolors support
## Updated: 2025-12-07
## ===================================================================================================================

drawbetaplot <- function(
    input_prop, input_clr, input_meta, 
    comparecol, comparecase = "all", compareref, 
    ord_method = "PCoA", 
    display_axes = c(1, 2), 
    # [MODIFIED] Removed show_ellipse argument (it is now forced)
    dotsize = 2,
    input_palette = NULL
) {
  
  require(dplyr); require(ggplot2); require(ggiraph); require(vegan); require(tibble)
  
  # Validation
  if (is.null(input_meta)) stop("Metadata is missing.")
  if (!comparecol %in% colnames(input_meta)) stop(paste0("Column '", comparecol, "' not found."))
  
  # [MODIFIED] Step 2: Filter Data based on vector selection
  meta_mod <- input_meta
  clr_mod <- input_clr
  
  if (!is.null(comparecase) && length(comparecase) > 0 && !("all" %in% comparecase)) {
    keepers <- rownames(meta_mod)[meta_mod[[comparecol]] %in% comparecase]
    meta_mod <- meta_mod[keepers, , drop = FALSE]
    if (!is.null(clr_mod)) clr_mod <- clr_mod[rownames(clr_mod) %in% keepers, , drop = FALSE]
  }
  
  # Check if enough samples remain
  if (nrow(meta_mod) < 3) return(NULL) # Need at least 3 points for ellipse/PCoA usually
  
  meta_mod[[comparecol]] <- factor(meta_mod[[comparecol]])
  if (compareref %in% levels(meta_mod[[comparecol]])) {
    meta_mod[[comparecol]] <- relevel(meta_mod[[comparecol]], ref = compareref)
  }
  
  # Distance (Fixed to Aitchison)
  if (is.null(clr_mod)) stop("CLR table missing for Aitchison distance.")
  
  # Ordination
  plot_coords <- NULL; var_exp <- c(0, 0); axis_labels <- c("", "")
  
  if (ord_method == "PCA") {
    pca_res <- prcomp(clr_mod)
    plot_coords <- data.frame(pca_res$x)
    eigs <- pca_res$sdev^2; var_exp <- round(100 * (eigs / sum(eigs)), 2)
    axis_labels <- c(paste0("PC", display_axes[1]), paste0("PC", display_axes[2]))
  } else if (ord_method == "PCoA") {
    dist_mat <- vegan::vegdist(clr_mod, method = "euclidean")
    # k must be < n-1
    max_k <- min(max(display_axes, 5), nrow(meta_mod)-1)
    pcoa_res <- cmdscale(dist_mat, k = max_k, eig = TRUE, add = TRUE)
    plot_coords <- data.frame(pcoa_res$points); colnames(plot_coords) <- paste0("PC", 1:ncol(plot_coords))
    denom <- if(any(pcoa_res$eig < 0)) sum(abs(pcoa_res$eig)) else sum(pcoa_res$eig)
    var_exp <- round(100 * (pcoa_res$eig / denom), 2)
    axis_labels <- c(paste0("PC", display_axes[1]), paste0("PC", display_axes[2]))
  } else if (ord_method == "NMDS") {
    dist_mat <- vegan::vegdist(clr_mod, method = "euclidean")
    nmds_res <- vegan::metaMDS(dist_mat, k = max(2, max(display_axes)), trymax = 20, trace = 0)
    plot_coords <- data.frame(nmds_res$points); colnames(plot_coords) <- paste0("NMDS", 1:ncol(plot_coords))
    var_exp <- c(NA, NA)
    axis_labels <- c(paste0("NMDS", display_axes[1]), paste0("NMDS", display_axes[2]))
  }
  
  # Plot Data
  x_ax_col <- axis_labels[1]; y_ax_col <- axis_labels[2]
  plot_data <- merge(plot_coords, meta_mod, by = 0, sort = F) %>% dplyr::mutate(Row.names = as.character(Row.names))
  
  # Statistics - PERMANOVA
  perm_pval <- "N/A"
  if (ord_method != "PCA" && nlevels(meta_mod[[comparecol]]) >= 2) {
    set.seed(801223)
    try({
      d <- vegan::vegdist(clr_mod, method = "euclidean")
      f <- reformulate(comparecol, response = "d")
      res <- vegan::adonis2(f, data = meta_mod, permutations = 999, na.action = na.exclude)
      perm_pval <- res[1, 5]
    }, silent = TRUE)
  }

  # Statistics - PERMDISP (multivariate dispersion homogeneity; betadisper)
  # Added (reviewer revision): checks whether a significant PERMANOVA result may be
  # driven by heterogeneous within-group dispersion, especially with imbalanced groups.
  permdisp_pval <- "N/A"
  if (ord_method != "PCA" && nlevels(meta_mod[[comparecol]]) >= 2) {
    set.seed(801223)
    try({
      d2 <- vegan::vegdist(clr_mod, method = "euclidean")
      bd <- vegan::betadisper(d2, meta_mod[[comparecol]])
      pt <- vegan::permutest(bd, permutations = 999)
      permdisp_pval <- pt$tab[1, "Pr(>F)"]
    }, silent = TRUE)
  }

  # Centroids
  centroids <- plot_data %>% dplyr::group_by(!!sym(comparecol)) %>% 
    dplyr::summarise(cx = mean(!!sym(x_ax_col), na.rm=T), cy = mean(!!sym(y_ax_col), na.rm=T))
  plot_data <- dplyr::left_join(plot_data, centroids, by = comparecol)
  
  # [MODIFIED] Palette - Use comedacolors if available and input_palette is NULL
  n_grps <- nlevels(plot_data[[comparecol]])
  if (!is.null(input_palette)) {
    p_cols <- rep(input_palette, length.out = n_grps)
  } else if (exists("comedacolors")) {
    p_cols <- rep(comedacolors, length.out = n_grps)
  } else {
    p_cols <- scales::hue_pal()(n_grps)
  }
  names(p_cols) <- levels(plot_data[[comparecol]])
  
  # Plot
  xl <- if (!is.na(var_exp[display_axes[1]])) paste0(x_ax_col, " (", var_exp[display_axes[1]], "%)") else x_ax_col
  yl <- if (!is.na(var_exp[display_axes[2]])) paste0(y_ax_col, " (", var_exp[display_axes[2]], "%)") else y_ax_col
  tl <- if (perm_pval != "N/A") {
    base_t <- paste0(ord_method, " (PERMANOVA p = ", round(as.numeric(perm_pval), 4))
    if (permdisp_pval != "N/A") base_t <- paste0(base_t, "; PERMDISP p = ", round(as.numeric(permdisp_pval), 4))
    paste0(base_t, ")")
  } else ord_method
  
  p <- ggplot(plot_data, aes_string(x = x_ax_col, y = y_ax_col, color = comparecol)) +
    geom_point(size = dotsize, alpha = 0.3) +
    geom_point_interactive(aes(tooltip = paste0("Sample: ", Row.names, "\nGroup: ", !!sym(comparecol)), data_id = Row.names), size = dotsize) +
    geom_segment(aes(xend = cx, yend = cy), linetype = "solid", linewidth = 0.5, alpha = 0.3) +
    scale_color_manual(values = p_cols) +
    labs(x = xl, y = yl, title = tl) + theme_minimal(base_size = 14) + theme(legend.position = "bottom")
  
  # [MODIFIED] Always show ellipse
  p <- p + stat_ellipse(type = "t", linetype = "dashed", linewidth = 0.5, alpha = 0.5)
  
  return(p)
}
