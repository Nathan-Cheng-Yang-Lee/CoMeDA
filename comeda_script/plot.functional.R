## ===================================================================================================================
## function name : Functional Prediction Plotting & Calc
## CoMeDA v3.2 - Bubble Plot Updates (Effect Size & Tooltips)
## Updated: 2025-12-06
## ===================================================================================================================

# 1. Preprocessing (Returns both CLR and Median Prop)
func.preprocess <- function(funcres, sampletype = "16S") {
#  require(dplyr); require(tibble); require(ALDEx2); require(compositions)
  
  # Format Input Table
  if (sampletype %in% c("16S", "ITS")) {
    func.table <- funcres %>% 
      column_to_rownames(colnames(.)[2]) %>% 
      dplyr::select(!all_of(c(colnames(.)[1]))) %>% 
      as.matrix()
  } else {
    func.table <- funcres %>% column_to_rownames(colnames(.)[1]) %>% as.matrix()
  }
  
  row.names(func.table) <- gsub("##", " ", row.names(func.table))
  
  # Integer Conversion
  func.times <- (func.table %>% .[. > 0] %>% min %>% log10 %>% abs %>% as.integer) + 1
  func.table.int <- (func.table * 10^func.times) %>% round(., 0)
  
  # ALDEx2 CLR (Monte Carlo)
  func.aldex.clr <- suppressMessages(ALDEx2::aldex.clr(func.table.int, denom = "all", mc.samples = 128))
  
  # Calculate Median Proportion directly (DAM style)
  func.res.prop <- lapply(names(func.aldex.clr@dirichletData), function(samples) {
    apply(func.aldex.clr@dirichletData[[samples]], 1, median)
  }) %>% do.call(cbind, .)
  colnames(func.res.prop) <- names(func.aldex.clr@dirichletData)
  
  # Calculate CLR from the median proportion
  prop_t <- t(func.res.prop)
  clr_t <- compositions::clr(prop_t)
  
  # Return both
  return(list(clr = clr_t, prop = prop_t))
}

# 2. Perform DAM (Wilcoxon + Cliff's Delta)
perform_functional_dam <- function(func_clr, meta, comparecol, comparecase, compareref) {
  #require(dplyr); require(tibble)
  meta_sub <- meta %>% dplyr::filter(!!sym(comparecol) %in% c(comparecase, compareref))
  valid_samples <- rownames(meta_sub)
  dat <- func_clr[rownames(func_clr) %in% valid_samples, , drop = FALSE]
  meta_sub <- meta_sub[rownames(dat), , drop = FALSE]
  groups <- factor(meta_sub[[comparecol]], levels = c(compareref, comparecase))
  
  calc_cliff <- function(vals, grps) {
    v_ref <- vals[grps == compareref]; v_case <- vals[grps == comparecase]
    n1 <- length(v_ref); n2 <- length(v_case); if(n1==0 || n2==0) return(0)
    w <- wilcox.test(v_case, v_ref)$statistic
    d <- (2 * w) / (n1 * n2) - 1
    return(d)
  }
  
  results <- apply(dat, 2, function(x) {
    wt <- tryCatch(wilcox.test(x ~ groups), error = function(e) list(p.value = 1))
    cd <- calc_cliff(x, groups)
    return(c(p = wt$p.value, eff = cd))
  }) %>% t() %>% as.data.frame()
  
  out <- data.frame(row.names = rownames(results), effect.size = results$eff, wilcox.test.pvalue = results$p, adj.pvalue = p.adjust(results$p, method = "BH"))
  return(out)
}

# 3. Prepare Table
funcdamtablecalc <- function(funcdam, func_prop, meta, comparecol, comparecase, compareref) {
#  require(dplyr); require(tibble)
  
  funcprop_t <- t(func_prop) %>% data.frame(check.names=F)
  func.dam.res <- funcdam %>% merge(., funcprop_t, by = 0, sort = F) %>% column_to_rownames("Row.names")
  
  meta[[comparecol]] <- relevel(factor(meta[[comparecol]]), ref = compareref)
  
  props_only <- func.dam.res[, -(1:3)] %>% t %>% data.frame(check.names = F)
  props_merged <- merge(props_only, meta %>% dplyr::select(all_of(comparecol)) %>% 
                          dplyr::filter(!!sym(comparecol) %in% c(comparecase, compareref)), 
                        by = 0, sort = F)
  
  medians <- props_merged %>% 
    group_by(!!sym(comparecol)) %>% 
    dplyr::summarise(across(where(is.numeric), median)) %>% 
    column_to_rownames(comparecol) %>% 
    t %>% 
    data.frame(check.names = F)
  
  col_case <- comparecase; col_ref <- compareref
  medians[medians == 0] <- 1e-9

  # [FIX] Check if columns exist before calculation
  if (!col_case %in% colnames(medians) || !col_ref %in% colnames(medians)) {
    stop(paste("Comparison groups not found in median table. Expected:", col_case, "and", col_ref))
  }
  
  # [FIX] Use .data[[col]] for safer evaluation
  final_table <- medians %>%
    dplyr::mutate("log2MedianFC" = round(log2( .data[[col_case]] / .data[[col_ref]] ), 3)) %>%
    merge(func.dam.res[, 1:3], ., by = 0, sort = F) %>%
    dplyr::mutate(ef.category = ifelse(effect.size > 0, "case > control", "case < control")) %>%
    column_to_rownames("Row.names")

  final_table$log2MedianFC[is.infinite(final_table$log2MedianFC)] <- 99
  final_table <- final_table %>% dplyr::filter(!is.nan(log2MedianFC))
   
  return(final_table)
}

# 4. Bubble Plot (Modified)
drawfuncbubbleplot <- function(functable, efcut, pvaluetype, pcut, propcut, showname, fontsize = 3) {
  #require(ggplot2); require(ggrepel); require(ggiraph)
  require(ggrepel)	
  n <- ncol(functable); ref_col <- colnames(functable)[n-3]; case_col <- colnames(functable)[n-2]
  p_col <- if (pvaluetype == "adjp") "adj.pvalue" else "wilcox.test.pvalue"
  
  df <- functable %>% dplyr::filter(abs(effect.size) >= efcut & !!sym(p_col) <= pcut)
  keep_prop <- apply(df[, c(ref_col, case_col)], 1, function(x) max(x) >= (propcut/100))
  df <- df[keep_prop, ]
  if (nrow(df) == 0) return(NULL)
  
  # [MODIFIED] Use absolute Effect Size for bubble size
  df$abs.effect <- abs(df$effect.size)
  
  # [MODIFIED] Update Tooltip: Proper names and values
  df$tooltip <- paste0(
    rownames(df), 
    "\nEffect Size: ", round(df$effect.size, 3), 
    "\nP-val: ", sprintf("%.1e", df[[p_col]]), 
    "\nMedian Rel. Abund. (Control): ", round(df[[ref_col]]*100, 3), "%",
    "\nMedian Rel. Abund. (Case): ", round(df[[case_col]]*100, 3), "%"
  )
  
  # [MODIFIED] Map size to abs.effect
  p <- ggplot(df, aes_string(x = "effect.size", y = paste0("-log(", p_col, ")"), size = "abs.effect", col = "ef.category")) + 
    geom_point_interactive(aes(tooltip = tooltip, data_id = rownames(df)), alpha = 0.7) + 
    scale_size(range = c(3, 10)) + 
    scale_color_manual(values = c("case > control" = "firebrick", "case < control" = "steelblue3")) + 
    theme_minimal(base_size = 14) + 
    # [MODIFIED] Update Labels
    labs(x = "Effect Size", y = paste0("-log(", pvaluetype, ")"), color = "Effect", size = "|Effect Size|")
  
  if (showname) p <- p + geom_text_repel(label = rownames(df), size = fontsize, max.overlaps = 15)
  return(p)
}

# 5. Bar Plot (Unchanged)
drawfuncbarplot <- function(functable, efcut, pvaluetype, pcut, propcut, top_n = 30) {
  #require(ggplot2); require(ggiraph)
  n <- ncol(functable); ref_col <- colnames(functable)[n-3]; case_col <- colnames(functable)[n-2]
  p_col <- if (pvaluetype == "adjp") "adj.pvalue" else "wilcox.test.pvalue"
  
  df <- functable %>% dplyr::filter(abs(effect.size) >= efcut & !!sym(p_col) <= pcut)
  keep_prop <- apply(df[, c(ref_col, case_col)], 1, function(x) max(x) >= (propcut/100))
  df <- df[keep_prop, ]
  if (nrow(df) == 0) return(NULL)
  
  if (!is.null(top_n) && nrow(df) > top_n) df <- df %>% arrange(desc(abs(effect.size))) %>% head(top_n)
  
  df$Pathway <- rownames(df); df <- df %>% arrange(effect.size); df$Pathway <- factor(df$Pathway, levels = df$Pathway)
  df$tooltip <- paste0(df$Pathway, "\nEffect: ", round(df$effect.size, 3), "\nP-val: ", sprintf("%.1e", df[[p_col]]))
  
  p <- ggplot(df, aes(x = effect.size, y = Pathway, fill = ef.category)) +
    geom_col_interactive(aes(tooltip = tooltip, data_id = Pathway), width = 0.7) +
    scale_fill_manual(values = c("case > control" = "firebrick", "case < control" = "steelblue3")) +
    labs(x = "Effect Size", y = NULL, fill = "Enriched In") +
    theme_minimal(base_size = 14) + theme(legend.position = "bottom", axis.text.y = element_text(size = 10))
  return(p)
}
