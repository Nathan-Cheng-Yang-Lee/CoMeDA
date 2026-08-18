## server_analysis_resultoverview_download.R
## Logic for Step B Download Tab (Redesigned)
## Updated: 2025-12-11 (Refined to use all_params + comparereflist clean logic)

w_download <- Waiter$new(
  html = tagList(spin_fading_circles(), h4("Preparing Download...", style = "color: #555;")), 
  color = "rgba(255, 255, 255, 0.9)"
)

# ==============================================================================
# Section 1: Update Input Choices
# ==============================================================================

# 1.1 Update Taxa Level and Comparison Column
observe({
  job_status$results_version
  req(job_status$current_id, input$selected_analysis_result)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return()
  
  # [FIX v6] Use all_params() (Section 1 + Section 2)
  params <- all_params()
  
  # Update Taxa Level
  if (!is.null(params) && !is.null(params$taxalevels) && params$taxalevels != "") {
    levels <- strsplit(params$taxalevels, ",")[[1]]
    levels <- trimws(levels)
    if (length(levels) > 0) {
      selected <- if ("genus" %in% levels) "genus" else levels[1]
      updateSelectInput(session, "dl_global_taxalevel", choices = levels, selected = selected)
    } else {
      updateSelectInput(session, "dl_global_taxalevel", choices = NULL)
    }
  } else {
    env <- current_rdata()
    if (!is.null(env) && !is.null(env$aldex.prop)) {
      levels <- names(env$aldex.prop)
      updateSelectInput(session, "dl_global_taxalevel", choices = levels, selected = levels[1])
    } else {
      updateSelectInput(session, "dl_global_taxalevel", choices = NULL)
    }
  }
  
  # [FIX v6] Update Comparison Column using comparereflist (Clean Dictionary)
  refs <- comparereflist()
  comp_cols <- names(refs)
  
  # Fallback: Use groupname if comparereflist is empty
  if (length(comp_cols) == 0) {
    if (!is.null(params) && !is.null(params$groupname) && params$groupname != "") {
      comp_cols <- params$groupname
    }
  }
  
  # Update SelectInput
  if (length(comp_cols) > 0) {
    updateSelectInput(session, "dl_global_comparecol", choices = comp_cols, selected = comp_cols[1])
  } else {
    updateSelectInput(session, "dl_global_comparecol", choices = NULL)
  }
})

# 1.2 Update Custom Taxa Choices
observe({
  job_status$results_version
  req(input$dl_global_taxalevel)
  env <- current_rdata()
  if (!is.null(env) && !is.null(env$batch.correct.res) && !is.null(env$batch.correct.res[[input$dl_global_taxalevel]])) {
    taxa_names <- colnames(env$batch.correct.res[[input$dl_global_taxalevel]]$correctedTable)
    updateSelectizeInput(session, "dl_hm_custom_taxa", choices = taxa_names, server = TRUE)
  } else {
    updateSelectizeInput(session, "dl_hm_custom_taxa", choices = NULL)
  }
})

# 1.3 Update Event Choices (DAM, Network, Functional)
observe({
  job_status$results_version
  req(input$dl_global_taxalevel, input$dl_global_comparecol)
  env <- current_rdata()
  lvl <- input$dl_global_taxalevel
  comp <- input$dl_global_comparecol
  
  # Get Ref Group
  refs <- comparereflist()
  ref_grp <- if (!is.null(refs[[comp]])) refs[[comp]] else "Ref"
  
  # DAM Events (Cases only, for Taxa DAM and Functional)
  if (!is.null(env) && !is.null(env$dam.res) && !is.null(env$dam.res[[lvl]]) && !is.null(env$dam.res[[lvl]][[comp]])) {
    dam_events <- names(env$dam.res[[lvl]][[comp]])
    dam_choices <- setNames(dam_events, paste0(dam_events, ".vs.", ref_grp))
    updateSelectInput(session, "dl_hm_dam_event", choices = dam_choices, selected = dam_events[1])
    updateSelectInput(session, "dl_func_event", choices = dam_choices, selected = dam_events[1])
  } else {
    updateSelectInput(session, "dl_hm_dam_event", choices = NULL)
    updateSelectInput(session, "dl_func_event", choices = NULL)
  }
  
  # Network Events (All groups: Cases + Control)
  if (!is.null(env) && !is.null(env$corr.res) && !is.null(env$corr.res[[lvl]]) && !is.null(env$corr.res[[lvl]][[comp]])) {
    net_events <- names(env$corr.res[[lvl]][[comp]])
    updateSelectizeInput(session, "dl_net_events", choices = net_events, selected = net_events[1])
  } else {
    updateSelectizeInput(session, "dl_net_events", choices = NULL)
  }
})

# 1.4 Beta Diversity Axis Warning
output$dl_beta_axis_warning <- renderUI({
  req(input$dl_beta_xaxis, input$dl_beta_yaxis)
  if (input$dl_beta_xaxis == input$dl_beta_yaxis) {
    tags$span(style="color: red; font-weight: bold;", icon("exclamation-triangle"), " X and Y axis cannot be the same!")
  } else {
    NULL
  }
})

# ==============================================================================
# Section 2: Table Generation Function
# ==============================================================================

generate_table_files <- function(save_dir, env, params, job_id, res_folder) {
  if (!is.null(env$raw.metadata)) {
    utils::write.table(env$raw.metadata, file.path(save_dir, "Metadata.txt"), sep="\t", quote=FALSE, col.names=NA)
  }
  
  if (!is.null(env$raw.taxatable)) {
    utils::write.table(env$raw.taxatable, file.path(save_dir, "Raw_Count_Table.txt"), sep="\t", quote=FALSE, row.names=FALSE)
  }
  
  taxalevels <- names(env$aldex.clr)
  for(lvl in taxalevels) {
    if(!is.null(env$aldex.clr[[lvl]])) {
      utils::write.table(env$aldex.clr[[lvl]], file.path(save_dir, paste0("CLR_Table_", lvl, ".txt")), sep="\t", quote=FALSE, col.names=NA)
    }
    if(!is.null(env$batch.correct.res[[lvl]]$correctedTable)) {
      utils::write.table(env$batch.correct.res[[lvl]]$correctedTable, file.path(save_dir, paste0("BatchCorrected_Table_", lvl, ".txt")), sep="\t", quote=FALSE, col.names=NA)
    }
    
    if(!is.null(env$dam.res[[lvl]])) {
      for(comp in names(env$dam.res[[lvl]])) {
        for(evt in names(env$dam.res[[lvl]][[comp]])) {
          df <- env$dam.res[[lvl]][[comp]][[evt]]
          fname <- paste0("DAM_", lvl, "_", comp, "_", evt, ".txt")
          utils::write.table(df, file.path(save_dir, fname), sep="\t", quote=FALSE, col.names=NA)
        }
      }
    }
    
    if(!is.null(env$corr.res[[lvl]])) {
      for(comp in names(env$corr.res[[lvl]])) {
        for(evt in names(env$corr.res[[lvl]][[comp]])) {
          res <- env$corr.res[[lvl]][[comp]][[evt]]
          if(is.list(res) && !is.null(res$correlationTable)) {
            df <- merge(reshape2::melt(res$correlationTable), reshape2::melt(res$p.value), by=c("Var1", "Var2"))
            colnames(df) <- c("Taxon1", "Taxon2", "Correlation", "P_value")
            df <- df[df$Correlation != 0 & !is.na(df$Correlation), ]
            fname <- paste0("Correlation_Network_", lvl, "_", comp, "_", evt, ".txt")
            utils::write.table(df, file.path(save_dir, fname), sep="\t", quote=FALSE, row.names=FALSE)
          }
        }
      }
    }
  }
  
  func_path <- paste0(comedainvpath, "/", job_id, "/analysis/", res_folder, "/functional_prediction")
  if(dir.exists(func_path)) {
    files <- list.files(func_path, pattern="pathway_kegg.txt", recursive=TRUE, full.names=TRUE)
    for(f in files) {
      fname <- paste0("Functional_Pathway_", basename(f))
      file.copy(f, file.path(save_dir, fname))
    }
  }
}

# ==============================================================================
# Section 3: Plot Generation Functions
# ==============================================================================

# 3.1 Taxa Community - Abundance Mode
generate_taxa_abundance_plot <- function(env, lvl, comp, ref, topn, min_abund, min_prev) {
  tryCatch({
    p_list <- drawtaxaheatmap(
      input_prop = env$aldex.prop[[lvl]], 
      input_clr = env$batch.correct.res[[lvl]]$correctedTable, 
      input_meta = env$filtered.meta[[lvl]], 
      input_dam = NULL,
      taxalevel = lvl, comparecol = comp, compareref = ref,
      filter_mode = "abundance_prevalence",
      compevents = NULL,
      dam_pvalue_type = "pvalue", dam_pvalue_cut = 0.05, dam_effect_cut = 0.33,
      abundance_mode = "topn", top_n = topn, top_n_group = ref,
      propcutvalue = min_abund, prevcutvalue = min_prev,
      sample_order = "group", show_sample_names = FALSE, fontsize = 9,
      annotation_cols = NULL, custom_taxa = NULL,
      comparecase = "all", return_object = TRUE
    )
    return(p_list$heatmap)
  }, error = function(e) { warning(paste("Taxa abundance error:", e$message)); return(NULL) })
}

# 3.2 Taxa Community - DAM Mode
generate_taxa_dam_plot <- function(env, lvl, comp, ref, event, effect_cut, p_cut, min_abund, min_prev) {
  tryCatch({
    if(is.null(env$dam.res[[lvl]][[comp]][[event]])) return(NULL)
    dam_data <- env$dam.res[[lvl]][[comp]][[event]]
    
    p_list <- drawtaxaheatmap(
      input_prop = env$aldex.prop[[lvl]], 
      input_clr = env$batch.correct.res[[lvl]]$correctedTable, 
      input_meta = env$filtered.meta[[lvl]], 
      input_dam = dam_data,
      taxalevel = lvl, comparecol = comp, compareref = ref,
      filter_mode = "dam",
      compevents = event,
      dam_pvalue_type = "pvalue", dam_pvalue_cut = p_cut, dam_effect_cut = effect_cut,
      abundance_mode = "topn", top_n = 30, top_n_group = ref,
      propcutvalue = min_abund, prevcutvalue = min_prev,
      sample_order = "group", show_sample_names = FALSE, fontsize = 9,
      annotation_cols = NULL, custom_taxa = NULL,
      comparecase = c(event, ref), return_object = TRUE
    )
    return(p_list$heatmap)
  }, error = function(e) { warning(paste("Taxa DAM error:", e$message)); return(NULL) })
}

# 3.3 Taxa Community - Custom Mode (Violin)
generate_taxa_custom_plot <- function(env, lvl, comp, ref, taxa_list) {
  tryCatch({
    if(is.null(taxa_list) || length(taxa_list) == 0) return(NULL)
    
    drawtaxaviolinplot(
      input_clr = env$batch.correct.res[[lvl]]$correctedTable,
      input_meta = env$filtered.meta[[lvl]],
      taxa_list = taxa_list,
      comparecol = comp, compareref = ref, comparecase = "all", ncol = 5
    )
  }, error = function(e) { warning(paste("Taxa custom error:", e$message)); return(NULL) })
}

# 3.4 Alpha Diversity
generate_alpha_plot <- function(env, lvl, comp, ref, metric) {
  tryCatch({
    drawalphaviolinplot(env$aldex.prop[[lvl]], env$filtered.meta[[lvl]], comp, "all", ref, metric, "yes", dotsize = 2.0)
  }, error = function(e) { warning(paste("Alpha error:", e$message)); return(NULL) })
}

# 3.5 Beta Diversity
generate_beta_plot <- function(env, lvl, comp, ref, method, x_axis, y_axis) {
  tryCatch({
    if(as.character(x_axis) == as.character(y_axis)) return(NULL)
    drawbetaplot(env$aldex.prop[[lvl]], env$batch.correct.res[[lvl]]$correctedTable, 
                 env$filtered.meta[[lvl]], comp, "all", ref, method, c(as.numeric(x_axis), as.numeric(y_axis)), 2.0)
  }, error = function(e) { warning(paste("Beta error:", e$message)); return(NULL) })
}

# 3.6 Correlation Network
generate_network_plot <- function(env, lvl, comp, events, p_cut, cor_cut, topn, layout, ptype = "raw") {
  tryCatch({
    if(is.null(events) || length(events) == 0) return(NULL)

    plot_interactive_networks(
      env$corr.res, lvl, comp, events,
      pcut = p_cut, corrcut = cor_cut,
      layout_type = layout, show_labels = TRUE, labelsize = 3,
      hubdegree = 12, toptaxa = topn, analysis_type = "within_domain",
      ptype = if(is.null(ptype)) "raw" else ptype
    )
  }, error = function(e) { warning(paste("Network error:", e$message)); return(NULL) })
}

# 3.7 Functional Prediction
generate_func_plot <- function(env, lvl, comp, ref, event, p_cut, effect_cut, prop_cut, plot_type) {
  tryCatch({
    res_folder <- isolate(input$selected_analysis_result)
    job_id <- isolate(job_status$current_id)
    if(is.null(res_folder) || is.null(job_id)) return(NULL)
    
    func_path <- file.path(comedainvpath, job_id, "analysis", res_folder, "functional_prediction", paste0(job_id, ".pathway_kegg.txt"))
    if(!file.exists(func_path)) {
      func_dir <- file.path(comedainvpath, job_id, "analysis", res_folder, "functional_prediction")
      func_path <- list.files(func_dir, pattern="pathway_kegg.txt", recursive=TRUE, full.names=TRUE)[1]
    }
    if(is.na(func_path) || !file.exists(func_path)) return(NULL)
    
    func_table <- utils::read.table(func_path, header=TRUE, sep="\t", check.names=FALSE, quote="", comment.char="")
    prep <- func.preprocess(func_table, sampletype = "16S")
    meta <- env$filtered.meta[[lvl]]
    
    dam <- perform_functional_dam(func_clr = prep$clr, meta = meta, comparecol = comp, comparecase = event, compareref = ref)
    final <- funcdamtablecalc(funcdam = dam, func_prop = prep$prop, meta = meta, comparecol = comp, comparecase = event, compareref = ref)
    
    if(plot_type == "bubble") {
      drawfuncbubbleplot(functable = final, efcut = effect_cut, pvaluetype = "wilcox", pcut = p_cut, propcut = prop_cut, showname = TRUE, fontsize = 3)
    } else {
      drawfuncbarplot(functable = final, efcut = effect_cut, pvaluetype = "wilcox", pcut = p_cut, propcut = prop_cut, top_n = 30)
    }
  }, error = function(e) { warning(paste("Func error:", e$message)); return(NULL) })
}

# ==============================================================================
# Section 4: Helper Functions
# ==============================================================================

create_empty_plot_png <- function(file, msg="Plot not available") {
  grDevices::png(file, width=8, height=6, units="in", res=150)
  grid::grid.newpage()
  grid::grid.text(msg, gp=grid::gpar(col="grey50", fontsize=20))
  grDevices::dev.off()
}

save_heatmap_png <- function(file, p, w=12, h=10) {
  if(is.null(p)) { create_empty_plot_png(file, "No data or filter too strict"); return(FALSE) }
  tryCatch({
    grDevices::png(file, width=w, height=h, units="in", res=300)
    ComplexHeatmap::draw(p)
    grDevices::dev.off()
    return(TRUE)
  }, error = function(e) { create_empty_plot_png(file, paste("Error:", e$message)); return(FALSE) })
}

save_ggplot_png <- function(file, p, w=10, h=8) {
  if(is.null(p)) { create_empty_plot_png(file, "No data or filter too strict"); return(FALSE) }
  tryCatch({
    ggplot2::ggsave(file, plot=p, width=w, height=h, dpi=300)
    return(TRUE)
  }, error = function(e) { create_empty_plot_png(file, paste("Error:", e$message)); return(FALSE) })
}

get_ref_group <- function(comp) {
  refs <- comparereflist()
  if(!is.null(refs[[comp]])) refs[[comp]] else "Ref"
}

# ==============================================================================
# Section 5: Individual Download Handlers
# ==============================================================================

# 5.1 Taxa Abundance
output$dl_plot_taxa_abundance <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    paste0("taxa_community_", lvl, "_top", input$dl_hm_topn, "_abundance.png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    p <- generate_taxa_abundance_plot(env, lvl, comp, ref, input$dl_hm_topn, input$dl_hm_min_abund, input$dl_hm_min_prev)
    save_heatmap_png(file, p)
  }
)

# 5.2 Taxa DAM
output$dl_plot_taxa_dam <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    ref <- get_ref_group(input$dl_global_comparecol)
    paste0("taxa_community_", lvl, "_", input$dl_hm_dam_event, ".vs.", ref, "_DAM.png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    p <- generate_taxa_dam_plot(env, lvl, comp, ref, input$dl_hm_dam_event, input$dl_hm_dam_eff, input$dl_hm_dam_p, input$dl_hm_min_abund, input$dl_hm_min_prev)
    save_heatmap_png(file, p)
  }
)

# 5.3 Taxa Custom (Violin)
output$dl_plot_taxa_custom <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    paste0("taxa_community_", lvl, "_custom_violin.png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    
    if(is.null(input$dl_hm_custom_taxa) || length(input$dl_hm_custom_taxa) == 0) {
      create_empty_plot_png(file, "No taxa selected")
      return()
    }
    
    p <- generate_taxa_custom_plot(env, lvl, comp, ref, input$dl_hm_custom_taxa)
    save_ggplot_png(file, p, w=12, h=8)
  }
)

# 5.4 Alpha Diversity
output$dl_plot_alpha <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    paste0("alpha_diversity_", lvl, "_", input$dl_alpha_metric, ".png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    p <- generate_alpha_plot(env, lvl, comp, ref, input$dl_alpha_metric)
    save_ggplot_png(file, p)
  }
)

# 5.5 Beta Diversity
output$dl_plot_beta <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    paste0("beta_diversity_", lvl, "_", input$dl_beta_method, "_axis", input$dl_beta_xaxis, "vs", input$dl_beta_yaxis, ".png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    
    if(input$dl_beta_xaxis == input$dl_beta_yaxis) {
      create_empty_plot_png(file, "X and Y axis cannot be the same")
      return()
    }
    
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    p <- generate_beta_plot(env, lvl, comp, ref, input$dl_beta_method, input$dl_beta_xaxis, input$dl_beta_yaxis)
    save_ggplot_png(file, p)
  }
)

# 5.6 Correlation Network
output$dl_plot_network <- downloadHandler(
  filename = function() {
    lvl <- input$dl_global_taxalevel
    events_str <- paste(input$dl_net_events, collapse = "_")
    paste0("correlation_network_", lvl, "_", events_str, ".png")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    
    if(is.null(input$dl_net_events) || length(input$dl_net_events) == 0) {
      create_empty_plot_png(file, "No events selected")
      return()
    }
    
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    p <- generate_network_plot(env, lvl, comp, input$dl_net_events, input$dl_net_p, input$dl_net_cor, input$dl_net_topn, input$dl_net_layout, input$dl_net_ptype)
    save_ggplot_png(file, p, w=14, h=10)
  }
)

# 5.7 Functional Prediction (ZIP with bubble + bar)
output$dl_plot_func <- downloadHandler(
  filename = function() {
    ref <- get_ref_group(input$dl_global_comparecol)
    paste0("functional_prediction_", input$dl_func_event, ".vs.", ref, ".zip")
  },
  content = function(file) {
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel; comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    
    tmp_dir <- tempfile(pattern = "func_plots_")
    dir.create(tmp_dir)
    
    p_bubble <- generate_func_plot(env, lvl, comp, ref, input$dl_func_event, input$dl_func_p, input$dl_func_eff, input$dl_func_prop, "bubble")
    bubble_file <- file.path(tmp_dir, paste0("functional_", input$dl_func_event, ".vs.", ref, "_bubble.png"))
    save_ggplot_png(bubble_file, p_bubble, w=12, h=12)
    
    p_bar <- generate_func_plot(env, lvl, comp, ref, input$dl_func_event, input$dl_func_p, input$dl_func_eff, input$dl_func_prop, "bar")
    bar_file <- file.path(tmp_dir, paste0("functional_", input$dl_func_event, ".vs.", ref, "_bar.png"))
    save_ggplot_png(bar_file, p_bar, w=12, h=12)
    
    old_wd <- getwd()
    setwd(tmp_dir)
    utils::zip(file, files = list.files(tmp_dir))
    setwd(old_wd)
    
    unlink(tmp_dir, recursive = TRUE)
  }
)

# ==============================================================================
# Section 6: Tables ZIP Handler
# ==============================================================================

output$dl_tables_zip <- downloadHandler(
  filename = function() { paste0("CoMeDA_Tables_", job_status$current_id, ".zip") },
  content = function(file) {
    w_download$show(); on.exit(w_download$hide())
    
    tmp_base <- tempfile(pattern = "comeda_tables_")
    dir.create(tmp_base)
    tables_dir <- file.path(tmp_base, "Tables")
    dir.create(tables_dir)
    
    tryCatch({
      # [FIX v6] Use all_params() for consistent parameter usage
      generate_table_files(tables_dir, current_rdata(), all_params(), job_status$current_id, input$selected_analysis_result)
      old_wd <- getwd(); setwd(tmp_base)
      utils::zip(file, files = "Tables")
      setwd(old_wd)
    }, error = function(e) {
      showNotification(paste("Table export failed:", e$message), type = "error")
    })
    
    unlink(tmp_base, recursive = TRUE)
  }
)

# ==============================================================================
# Section 7: One-Click Download
# ==============================================================================

output$dl_master_zip <- downloadHandler(
  filename = function() { paste0("CoMeDA_Results_Full_", job_status$current_id, ".zip") },
  content = function(file) {
    w_download$show(); on.exit(w_download$hide())
    
    tmp_base <- tempfile(pattern = "comeda_full_")
    dir.create(tmp_base)
    tables_dir <- file.path(tmp_base, "Tables")
    plots_dir <- file.path(tmp_base, "Plots")
    dir.create(tables_dir)
    dir.create(plots_dir)
    
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel
    comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    
    default_topn <- 30
    default_min_abund <- 1
    default_min_prev <- 10
    default_effect <- 0.33
    default_p <- 0.05
    default_cor <- 0.4
    default_net_topn <- 50
    default_func_prop <- 0.1
    
    all_dam_events <- if(!is.null(env$dam.res[[lvl]][[comp]])) names(env$dam.res[[lvl]][[comp]]) else c()
    all_net_events <- if(!is.null(env$corr.res[[lvl]][[comp]])) names(env$corr.res[[lvl]][[comp]]) else c()
    
    tryCatch({
      generate_table_files(tables_dir, env, all_params(), job_status$current_id, input$selected_analysis_result)
    }, error = function(e) warning(paste("Table export failed:", e$message)))
    
    p <- generate_taxa_abundance_plot(env, lvl, comp, ref, default_topn, default_min_abund, default_min_prev)
    if(!is.null(p)) save_heatmap_png(file.path(plots_dir, paste0("taxa_community_", lvl, "_top", default_topn, "_abundance.png")), p)
    
    for(evt in all_dam_events) {
      p <- generate_taxa_dam_plot(env, lvl, comp, ref, evt, default_effect, default_p, default_min_abund, default_min_prev)
      if(!is.null(p)) save_heatmap_png(file.path(plots_dir, paste0("taxa_community_", lvl, "_", evt, ".vs.", ref, "_DAM.png")), p)
    }
    
    custom_taxa <- input$dl_hm_custom_taxa
    if(!is.null(custom_taxa) && length(custom_taxa) > 0) {
      p <- generate_taxa_custom_plot(env, lvl, comp, ref, custom_taxa)
      if(!is.null(p)) save_ggplot_png(file.path(plots_dir, paste0("taxa_community_", lvl, "_custom_violin.png")), p, w=12, h=8)
    }
    
    for(metric in c("shannon", "simpson")) {
      p <- generate_alpha_plot(env, lvl, comp, ref, metric)
      if(!is.null(p)) save_ggplot_png(file.path(plots_dir, paste0("alpha_diversity_", lvl, "_", metric, ".png")), p)
    }
    
    for(method in c("PCoA", "PCA", "NMDS")) {
      p <- generate_beta_plot(env, lvl, comp, ref, method, 1, 2)
      if(!is.null(p)) save_ggplot_png(file.path(plots_dir, paste0("beta_diversity_", lvl, "_", method, "_axis1vs2.png")), p)
    }
    
    for(evt in all_net_events) {
      p <- generate_network_plot(env, lvl, comp, evt, default_p, default_cor, default_net_topn, "fr")
      if(!is.null(p)) save_ggplot_png(file.path(plots_dir, paste0("correlation_network_", lvl, "_", evt, ".png")), p, w=14, h=10)
    }
    
    for(evt in all_dam_events) {
      for(pt in c("bubble", "bar")) {
        p <- generate_func_plot(env, lvl, comp, ref, evt, default_p, 0, default_func_prop, pt)
        if(!is.null(p)) save_ggplot_png(file.path(plots_dir, paste0("functional_prediction_", evt, ".vs.", ref, "_", pt, ".png")), p, w=12, h=12)
      }
    }
    
    pdf_path <- file.path(tmp_base, "CoMeDA_Report.pdf")
    generate_pdf_report(pdf_path, env, lvl, comp, ref, all_dam_events, all_net_events, custom_taxa,
                        default_topn, default_min_abund, default_min_prev, default_effect, default_p,
                        default_cor, default_net_topn, default_func_prop, "fr", 1, 2, is_oneclick = TRUE)
    
    old_wd <- getwd(); setwd(tmp_base)
    utils::zip(file, files = c("Tables", "Plots", "CoMeDA_Report.pdf"))
    setwd(old_wd)
    
    unlink(tmp_base, recursive = TRUE)
  }
)

# ==============================================================================
# Section 8: PDF Report (User Parameters)
# ==============================================================================

output$dl_report_pdf <- downloadHandler(
  filename = "CoMeDA_Report.pdf",
  content = function(file) {
    w_download$show(); on.exit(w_download$hide())
    
    env <- current_rdata(); req(env)
    lvl <- input$dl_global_taxalevel
    comp <- input$dl_global_comparecol
    ref <- get_ref_group(comp)
    
    all_dam_events <- if(!is.null(env$dam.res[[lvl]][[comp]])) names(env$dam.res[[lvl]][[comp]]) else c()
    all_net_events <- if(!is.null(env$corr.res[[lvl]][[comp]])) names(env$corr.res[[lvl]][[comp]]) else c()
    custom_taxa <- input$dl_hm_custom_taxa
    
    generate_pdf_report(file, env, lvl, comp, ref, all_dam_events, all_net_events, custom_taxa,
                        input$dl_hm_topn, input$dl_hm_min_abund, input$dl_hm_min_prev,
                        input$dl_hm_dam_eff, input$dl_hm_dam_p,
                        input$dl_net_cor, input$dl_net_topn, input$dl_func_prop,
                        input$dl_net_layout, input$dl_beta_xaxis, input$dl_beta_yaxis,
                        is_oneclick = FALSE,
                        user_alpha_metric = input$dl_alpha_metric,
                        user_beta_method = input$dl_beta_method,
                        user_net_events = input$dl_net_events,
                        user_dam_event = input$dl_hm_dam_event,
                        user_func_event = input$dl_func_event,
                        user_func_p = input$dl_func_p,
                        user_func_eff = input$dl_func_eff)
  }
)

# ==============================================================================
# Section 9: PDF Generation Function
# ==============================================================================

generate_pdf_report <- function(file, env, lvl, comp, ref, all_dam_events, all_net_events, custom_taxa,
                                 topn, min_abund, min_prev, effect_cut, p_cut,
                                 cor_cut, net_topn, func_prop, net_layout, beta_x, beta_y,
                                 is_oneclick = TRUE,
                                 user_alpha_metric = NULL, user_beta_method = NULL,
                                 user_net_events = NULL, user_dam_event = NULL,
                                 user_func_event = NULL, user_func_p = NULL, user_func_eff = NULL) {
  
  draw_page <- function(p, title, desc_lines) {
    if(is.null(p)) return()
    if(inherits(p, "Heatmap")) {
      grid::grid.newpage()
      grid::pushViewport(grid::viewport(y=0.97, height=0.06))
      grid::grid.text(title, gp=grid::gpar(fontsize=14, fontface="bold"))
      grid::popViewport()
      grid::pushViewport(grid::viewport(y=0.55, height=0.70))
      ComplexHeatmap::draw(p, newpage = FALSE)
      grid::popViewport()
      grid::pushViewport(grid::viewport(y=0.10, height=0.18))
      grid::grid.rect(gp=grid::gpar(fill="#f8f9fa", col="#dee2e6"))
      grid::grid.text(paste(desc_lines, collapse="\n"), x=0.03, y=0.5, just=c("left", "center"), gp=grid::gpar(fontsize=9, fontfamily="mono", lineheight=1.2))
      grid::popViewport()
    } else {
      p_final <- p + ggplot2::ggtitle(title) + ggplot2::labs(caption = paste(desc_lines, collapse="\n")) +
        ggplot2::theme(plot.title = ggplot2::element_text(size=14, face="bold", hjust=0.5), plot.caption = ggplot2::element_text(size=8, hjust=0, family="mono", lineheight=1.1))
      print(p_final)
    }
  }
  
  grDevices::pdf(file, width=12, height=10)
  
  grid::grid.newpage()
  grid::grid.text("CoMeDA Analysis Report", y=0.60, gp=grid::gpar(fontsize=28, fontface="bold"))
  txt <- if(is_oneclick) "(Default Parameters)" else "(User-Customized Parameters)"
  col <- if(is_oneclick) "forestgreen" else "steelblue"
  grid::grid.text(txt, y=0.52, gp=grid::gpar(fontsize=14, col=col))
  grid::grid.text(paste("Job ID:", job_status$current_id), y=0.44, gp=grid::gpar(fontsize=16))
  grid::grid.text(paste("Taxa Level:", lvl, "| Comparison:", comp, "| Reference:", ref), y=0.36, gp=grid::gpar(fontsize=12))
  grid::grid.text(paste("Generated:", Sys.time()), y=0.28, gp=grid::gpar(fontsize=11, col="gray50"))
  
  p <- generate_taxa_abundance_plot(env, lvl, comp, ref, topn, min_abund, min_prev)
  if(!is.null(p)) draw_page(p, "Taxa Community (Abundance Mode)", c("Taxa Community Heatmap", paste("- Top N:", topn), paste("- Min Abund:", min_abund, "%"), paste("- Min Prev:", min_prev, "%")))
  
  if(is_oneclick) {
    for(evt in all_dam_events) {
      p <- generate_taxa_dam_plot(env, lvl, comp, ref, evt, effect_cut, p_cut, min_abund, min_prev)
      if(!is.null(p)) draw_page(p, paste("Taxa Community (DAM) -", evt, "vs", ref), c(paste("DAM -", evt), paste("- Effect >", effect_cut), paste("- P <", p_cut)))
    }
  } else {
    if(!is.null(user_dam_event) && user_dam_event %in% all_dam_events) {
      p <- generate_taxa_dam_plot(env, lvl, comp, ref, user_dam_event, effect_cut, p_cut, min_abund, min_prev)
      if(!is.null(p)) draw_page(p, paste("Taxa Community (DAM) -", user_dam_event, "vs", ref), c(paste("DAM -", user_dam_event), paste("- Effect >", effect_cut), paste("- P <", p_cut)))
    }
  }
  
  if(!is.null(custom_taxa) && length(custom_taxa) > 0) {
    p <- generate_taxa_custom_plot(env, lvl, comp, ref, custom_taxa)
    if(!is.null(p)) draw_page(p, "Taxa Community (Custom Violin)", c("Custom Violin Plot", paste("- Taxa:", length(custom_taxa))))
  }
  
  metrics <- if(is_oneclick) c("shannon", "simpson") else user_alpha_metric
  if(!is.null(metrics)) {
    for(metric in metrics) {
      p <- generate_alpha_plot(env, lvl, comp, ref, metric)
      if(!is.null(p)) draw_page(p, paste("Alpha Diversity (", tools::toTitleCase(metric), ")", sep=""), c(paste("Alpha -", metric), "- Test: Wilcoxon"))
    }
  }
  
  methods <- if(is_oneclick) c("PCoA", "PCA", "NMDS") else user_beta_method
  if(!is.null(methods)) {
    for(method in methods) {
      p <- generate_beta_plot(env, lvl, comp, ref, method, if(is_oneclick) 1 else beta_x, if(is_oneclick) 2 else beta_y)
      if(!is.null(p)) draw_page(p, paste("Beta Diversity (", method, ")", sep=""), c(paste("Beta -", method), "- Test: PERMANOVA"))
    }
  }
  
  net_evts <- if(is_oneclick) all_net_events else user_net_events
  if(!is.null(net_evts)) {
    if(is_oneclick) {
      for(evt in net_evts) {
        p <- generate_network_plot(env, lvl, comp, evt, p_cut, cor_cut, net_topn, "fr")
        if(!is.null(p)) draw_page(p, paste("Correlation Network -", evt), c(paste("Network -", evt), paste("- Cor >", cor_cut), paste("- P <", p_cut)))
      }
    } else {
      p <- generate_network_plot(env, lvl, comp, net_evts, p_cut, cor_cut, net_topn, net_layout)
      if(!is.null(p)) draw_page(p, "Correlation Network", c(paste("Network -", paste(net_evts, collapse=", ")), paste("- Cor >", cor_cut), paste("- P <", p_cut)))
    }
  }
  
  func_p_use <- if(is_oneclick) p_cut else user_func_p
  func_eff_use <- if(is_oneclick) 0 else user_func_eff
  func_evts <- if(is_oneclick) all_dam_events else user_func_event
  
  if(!is.null(func_evts)) {
    for(evt in func_evts) {
      if(evt %in% all_dam_events) {
        for(pt in c("bubble", "bar")) {
          p <- generate_func_plot(env, lvl, comp, ref, evt, func_p_use, func_eff_use, func_prop, pt)
          if(!is.null(p)) draw_page(p, paste("Functional (", tools::toTitleCase(pt), ") -", evt, "vs", ref, sep=""), c(paste("Functional -", evt), paste("- P <", func_p_use)))
        }
      }
    }
  }
  
  grDevices::dev.off()
}
