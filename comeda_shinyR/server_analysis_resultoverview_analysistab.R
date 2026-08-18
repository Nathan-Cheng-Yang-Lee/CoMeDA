## server_analysis_resultoverview_analysistab.R
## Logic for Analysis Results Tab (Taxa + Diversity + Network + Function)
## Updated: 2025-12-11 (Fixed: Auto-trigger on Global Control Changes)

require(waiter)

# 0. Load Scripts
heatmap_script_path <- paste(comedashinypath, "script", "plot.taxaheatmap.R", sep = "/")
if (file.exists(heatmap_script_path)) source(heatmap_script_path, local = TRUE)
alpha_script_path <- paste(comedashinypath, "script", "plot.alphadiversity.R", sep = "/")
if (file.exists(alpha_script_path)) source(alpha_script_path, local = TRUE)
beta_script_path <- paste(comedashinypath, "script", "plot.betadiversity.R", sep = "/")
if (file.exists(beta_script_path)) source(beta_script_path, local = TRUE)
network_script_path <- paste(comedashinypath, "script", "plot.corrnetwork.R", sep = "/")
if (file.exists(network_script_path)) source(network_script_path, local = TRUE)
func_script_path <- paste(comedashinypath, "script", "plot.functional.R", sep = "/")
if (file.exists(func_script_path)) source(func_script_path, local = TRUE)

plot_error_message <- function(msg) {
  ggplot() + annotate("text", x = 0.5, y = 0.5, label = paste("Error:\n", msg), color = "#d9534f", size = 5, fontface = "bold", hjust = 0.5) + theme_void() + theme(plot.background = element_rect(fill = "#fff3f3", color = "#d9534f"))
}

# 0.1 Waiters
# [NOTE] Ensure IDs here match the UI container IDs for waiters to work properly
w_heatmap <- Waiter$new(id = "taxa_heatmap_plot", html = tagList(spin_fading_circles(), h4("Generating Heatmap...", style = "color: #555; margin-top: 10px;")), color = "rgba(255, 255, 255, 0.9)", fadeout = TRUE)
w_alpha <- Waiter$new(id = "alpha_diversity_plot", html = tagList(spin_fading_circles(), h4("Calculating Alpha Diversity...", style = "color: #555; margin-top: 10px;")), color = "rgba(255, 255, 255, 0.9)", fadeout = TRUE)
w_beta <- Waiter$new(id = "beta_diversity_plot", html = tagList(spin_fading_circles(), h4("Calculating Beta Diversity...", style = "color: #555; margin-top: 10px;")), color = "rgba(255, 255, 255, 0.9)", fadeout = TRUE)
w_network <- Waiter$new(id = "corr_network_plot", html = tagList(spin_fading_circles(), h4("Generating Network...", style = "color: #555;")), color = "rgba(255,255,255,0.8)", fadeout = TRUE)
w_func <- Waiter$new(id = "func_plot", html = tagList(spin_fading_circles(), h4("Calculating Pathway Analysis...", style = "color: #555;")), color = "rgba(255,255,255,0.8)", fadeout = TRUE)

# 0.5 Tab Visibility
observe({
  req(job_status$current_id, input$selected_analysis_result)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return()
  
  func_result_dir <- file.path(comedainvpath, job_status$current_id, "analysis", input$selected_analysis_result, "functional_prediction")
  pre_taxa_dir <- file.path(comedainvpath, job_status$current_id, "analysis", "preTaxaTable")
  pre_proc_dir <- file.path(comedainvpath, job_status$current_id, "analysis", "preTaxaTable", "preprocessing")
  cond_no_result <- !dir.exists(func_result_dir)
  cond_is_taxatable <- (dir.exists(pre_taxa_dir) && !dir.exists(pre_proc_dir))
  if (cond_no_result || cond_is_taxatable) hideTab(inputId = "ar_modules_tabs", target = "tab_functional") else showTab(inputId = "ar_modules_tabs", target = "tab_functional")
})

# ==============================================================================
# 1. Global Controls - Taxa Level & Comparison Column
# ==============================================================================

# 1.1 Update Taxa Level Dropdown (Default: Genus if available)
observe({
  job_status$results_version
  req(job_status$current_id, input$selected_analysis_result)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return()
  
  params <- all_params()
  
  # Use parameters for Taxa levels
  if (!is.null(params) && !is.null(params$taxalevels) && params$taxalevels != "") {
    levels <- strsplit(params$taxalevels, ",")[[1]]
    levels <- trimws(levels)
    
    if (length(levels) > 0) {
      current <- isolate(input$ar_taxalevel)
      # Logic: Prefer 'genus', else keep current if valid, else first available
      selected <- if ("genus" %in% levels) "genus" else if (!is.null(current) && current %in% levels) current else levels[1]
      updateSelectInput(session, "ar_taxalevel", choices = levels, selected = selected)
    } else {
      updateSelectInput(session, "ar_taxalevel", choices = NULL)
    }
  } else {
    # Fallback
    env <- current_rdata()
    if (!is.null(env) && !is.null(env$aldex.prop)) {
      levels <- names(env$aldex.prop)
      selected <- if ("genus" %in% levels) "genus" else levels[1]
      updateSelectInput(session, "ar_taxalevel", choices = levels, selected = selected)
    }
  }
})

# 1.2 Update Comparison Column Dropdown
observe({
  job_status$results_version
  req(job_status$current_id, input$selected_analysis_result)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return()
  
  refs <- comparereflist()
  comp_choices <- names(refs)
  
  if (length(comp_choices) == 0) {
    params <- all_params()
    if (!is.null(params) && !is.null(params$groupname) && params$groupname != "") {
      comp_choices <- params$groupname
    }
  }
  
  if (length(comp_choices) > 0) {
    current <- isolate(input$ar_comparecol)
    selected <- if (!is.null(current) && current %in% comp_choices) current else comp_choices[1]
    updateSelectInput(session, "ar_comparecol", choices = comp_choices, selected = selected)
  } else {
    updateSelectInput(session, "ar_comparecol", choices = NULL)
  }
})

# ==============================================================================
# 2. Taxa Community
# ==============================================================================

plot_ctrl <- reactiveValues(
  trigger = 0,
  internal_mode = "dam" # Default
)

# Sync internal mode with UI input (when user manually changes radio button)
observeEvent(input$hm_filtermode, {
  plot_ctrl$internal_mode <- input$hm_filtermode
})

# Handle Result Switching: force DAM to avoid stale Custom selections
observeEvent(input$selected_analysis_result, {
  if (!is.null(input$hm_filtermode) && input$hm_filtermode == "custom") {
    updateRadioButtons(session, "hm_filtermode", selected = "dam")
  }
  plot_ctrl$internal_mode <- "dam"
  plot_ctrl$trigger <- plot_ctrl$trigger + 1
}, priority = 10)

# Manual Update Button
observeEvent(input$hm_update_btn, {
  plot_ctrl$trigger <- plot_ctrl$trigger + 1
})

# ----------------------------------------------------------------------
# [FIX] Auto-trigger plot when Global Controls change
#  - If currently in Custom mode, switch back to DAM (your requested behavior)
#  - Then trigger redraw
# ----------------------------------------------------------------------
observeEvent(list(input$ar_taxalevel, input$ar_comparecol), {
  req(input$ar_taxalevel, input$ar_comparecol)

  if (!is.null(isolate(plot_ctrl$internal_mode)) && isolate(plot_ctrl$internal_mode) == "custom") {
    updateRadioButtons(session, "hm_filtermode", selected = "dam")
    plot_ctrl$internal_mode <- "dam"

    # Optional: clear taxa selection to prevent confusion
    updateSelectizeInput(session, "hm_custom_taxa", selected = character(0))
  }

  plot_ctrl$trigger <- plot_ctrl$trigger + 1
}, priority = 20)

# 2.1 Update DAM Choices
observe({
  req(input$ar_taxalevel, input$ar_comparecol)
  env <- current_rdata()
  if (is.null(env) || is.null(env$dam.res)) return()

  refs <- comparereflist()
  ref_grp <- if (!is.null(refs[[input$ar_comparecol]])) refs[[input$ar_comparecol]] else "Ref"

  if (!is.null(env$dam.res[[input$ar_taxalevel]]) && !is.null(env$dam.res[[input$ar_taxalevel]][[input$ar_comparecol]])) {
    cases <- names(env$dam.res[[input$ar_taxalevel]][[input$ar_comparecol]])
    labels <- paste0(cases, ".vs.", ref_grp)
    choices <- setNames(cases, labels)
    updateSelectInput(session, "hm_dam_event", choices = choices)
  } else {
    updateSelectInput(session, "hm_dam_event", choices = character(0))
  }
})

# 2.2 Update Group Choices
observe({
  req(input$ar_taxalevel, input$ar_comparecol)
  env <- current_rdata()
  if (is.null(env) || is.null(env$filtered.meta)) return()

  if (!is.null(env$filtered.meta[[input$ar_taxalevel]])) {
    meta_df <- env$filtered.meta[[input$ar_taxalevel]]
    if (input$ar_comparecol %in% colnames(meta_df)) {
      groups <- levels(factor(meta_df[[input$ar_comparecol]]))
      updateSelectInput(session, "hm_topn_group", choices = as.character(groups))
      updateSelectizeInput(session, "hm_selected_grps_abund", choices = groups, selected = groups)
      updateSelectizeInput(session, "hm_selected_grps_custom", choices = groups, selected = groups)
    }
  }
})

# 2.3 Update Custom Taxa + annotations (keep your original logic)
observe({
  req(input$ar_taxalevel, input$ar_comparecol)
  input$hm_min_abund; input$hm_min_prev

  env <- current_rdata()
  if (is.null(env)) return()

  if (!is.null(env$aldex.prop) && !is.null(env$filtered.meta) &&
      !is.null(env$aldex.prop[[input$ar_taxalevel]]) &&
      !is.null(env$filtered.meta[[input$ar_taxalevel]])) {

    prop <- env$aldex.prop[[input$ar_taxalevel]]
    meta <- env$filtered.meta[[input$ar_taxalevel]]

    abund_val <- if(!is.null(input$hm_min_abund)) input$hm_min_abund * 100 else 1
    prev_val  <- if(!is.null(input$hm_min_prev))  input$hm_min_prev  * 100 else 10

    valid_taxa <- tryCatch({
      perform_global_prefilter(prop, meta, input$ar_comparecol, abund_val, prev_val)
    }, error = function(e) {
      if (!is.null(env$batch.correct.res[[input$ar_taxalevel]])) {
        colnames(env$batch.correct.res[[input$ar_taxalevel]]$correctedTable)
      } else character(0)
    })

    max_n <- 30
    if(isolate(input$hm_filtermode) == "custom" &&
       !is.null(isolate(input$hm_plot_type)) &&
       isolate(input$hm_plot_type) == "violin") max_n <- 15

    current_sel <- isolate(input$hm_custom_taxa)
    new_sel <- if(!is.null(current_sel)) current_sel[current_sel %in% valid_taxa] else NULL

    updateSelectizeInput(session, "hm_custom_taxa",
                         choices = valid_taxa, selected = new_sel,
                         server = TRUE, options = list(maxItems = max_n))
  }

  if (!is.null(env$filtered.meta) && !is.null(env$filtered.meta[[input$ar_taxalevel]])) {
    meta_cols <- colnames(env$filtered.meta[[input$ar_taxalevel]])
    current_anno <- isolate(input$hm_annotations)
    selected_anno <- if (is.null(current_anno)) input$ar_comparecol else current_anno
    updateSelectizeInput(session, "hm_annotations", choices = meta_cols, selected = selected_anno)
  }
})

# Wrapper UI (unchanged)
output$taxa_heatmap_ui_wrapper <- renderUI({
  plot_ctrl$trigger
  f_mode <- isolate(plot_ctrl$internal_mode)
  p_type <- isolate(input$hm_plot_type)

  if (f_mode == "custom" && !is.null(p_type) && p_type == "violin") {
    girafeOutput("taxa_violin_plot", width = "100%", height = "900px")
  } else {
    w_in <- isolate(input$hm_width); h_in <- isolate(input$hm_height)
    if(is.null(w_in) || w_in < 1) w_in <- 23
    if(is.null(h_in) || h_in < 1) h_in <- 12
    plotOutput("taxa_heatmap_plot",
               width = paste0(w_in * 72, "px"),
               height = paste0(h_in * 72, "px"))
  }
})

# ----------------------------------------------------------------------
# [FIX] Heatmap plot: add Smart Fallback for Abundance/Custom group selections
# ----------------------------------------------------------------------
output$taxa_heatmap_plot <- renderPlot({
  req(plot_ctrl$trigger)

  current_mode <- isolate(plot_ctrl$internal_mode)
  if (current_mode == "custom" && isolate(input$hm_plot_type) == "violin") return(NULL)

  taxalevel  <- isolate(input$ar_taxalevel)
  comparecol <- isolate(input$ar_comparecol)
  req(taxalevel, comparecol)

  env <- current_rdata()
  if (is.null(env) || is.null(env$aldex.prop)) return(NULL)

  if (is.null(env$aldex.prop) || is.null(env$batch.correct.res) || is.null(env$filtered.meta)) return(NULL)

  meta_df <- env$filtered.meta[[taxalevel]]
  if (is.null(meta_df) || !(comparecol %in% colnames(meta_df))) return(NULL)

  valid_groups <- levels(factor(meta_df[[comparecol]]))

  refs <- comparereflist()
  compareref <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else NULL

  w_heatmap$show(); on.exit(w_heatmap$hide())

  input_dam_data <- NULL
  target_event <- NULL
  groups_to_plot <- "all"

  # TopN group fallback (avoid stale selection)
  top_grp <- isolate(input$hm_topn_group)
  if (is.null(top_grp) || !(top_grp %in% valid_groups)) {
    top_grp <- if (length(valid_groups) > 0) valid_groups[1] else NULL
  }

  # Custom taxa (may be empty)
  custom_taxa <- isolate(input$hm_custom_taxa)

  if (current_mode == "dam") {
    current_dam_event <- isolate(input$hm_dam_event)
    available_events <- if (!is.null(env$dam.res[[taxalevel]][[comparecol]])) names(env$dam.res[[taxalevel]][[comparecol]]) else NULL

    if (!is.null(available_events)) {
      target_event <- if (!is.null(current_dam_event) && current_dam_event %in% available_events) current_dam_event else available_events[1]
      input_dam_data <- env$dam.res[[taxalevel]][[comparecol]][[target_event]]
      groups_to_plot <- c(target_event, compareref)
    } else {
      return(NULL)
    }

  } else if (current_mode == "abundance_prevalence") {

    sel <- isolate(input$hm_selected_grps_abund)
    sel2 <- intersect(sel %||% character(0), valid_groups)

    groups_to_plot <- if (is.null(sel) || length(sel) == 0 || length(sel2) == 0) valid_groups else sel2

  } else if (current_mode == "custom") {

    # If no taxa selected for Custom heatmap, show a friendly message instead of blank/error
    if (is.null(custom_taxa) || length(custom_taxa) == 0) {
      grid.newpage()
      grid.text("Please select at least one taxon in Custom mode.", gp = gpar(col = "red", fontsize = 14))
      return(invisible(NULL))
    }

    sel <- isolate(input$hm_selected_grps_custom)
    sel2 <- intersect(sel %||% character(0), valid_groups)

    groups_to_plot <- if (is.null(sel) || length(sel) == 0 || length(sel2) == 0) valid_groups else sel2
  }

  hm_fontsize <- isolate(input$hm_fontsize)
  if (is.null(hm_fontsize) || !is.numeric(hm_fontsize)) hm_fontsize <- 9
  hm_show_sample_names <- isolate(input$hm_show_sample_names)
  if (is.null(hm_show_sample_names)) hm_show_sample_names <- FALSE

  tryCatch({
    drawtaxaheatmap(
      input_prop = env$aldex.prop[[taxalevel]],
      input_clr  = env$batch.correct.res[[taxalevel]]$correctedTable,
      input_meta = meta_df,
      input_dam  = input_dam_data,
      taxalevel  = taxalevel,
      comparecol = comparecol,
      compareref = compareref,
      filter_mode = current_mode,
      compevents  = target_event,
      dam_pvalue_type = isolate(input$hm_dam_type),
      dam_pvalue_cut  = isolate(input$hm_dam_pval),
      dam_effect_cut  = isolate(input$hm_dam_eff),
      abundance_mode  = "topn",
      top_n           = isolate(input$hm_topn),
      top_n_group     = top_grp,
      propcutvalue    = isolate(input$hm_min_abund) * 100,
      prevcutvalue    = isolate(input$hm_min_prev)  * 100,
      custom_taxa     = custom_taxa,
      comparecase     = groups_to_plot,
      sample_order    = isolate(input$hm_sample_order),
      annotation_cols = isolate(input$hm_annotations),
      show_sample_names = hm_show_sample_names,
      fontsize = hm_fontsize,
      width  = isolate(input$hm_width),
      height = isolate(input$hm_height)
    )
  }, error = function(e) {
    grid.newpage()
    grid.text(paste("Error:", e$message), gp = gpar(col = "red", fontsize = 14))
  })
})

# ----------------------------------------------------------------------
# [FIX] Custom violin: Smart fallback for group selection (avoid stale groups)
# ----------------------------------------------------------------------
output$taxa_violin_plot <- renderGirafe({
  req(plot_ctrl$trigger)

  current_mode <- isolate(plot_ctrl$internal_mode)
  if (current_mode != "custom" || isolate(input$hm_plot_type) != "violin") return(NULL)

  taxalevel  <- isolate(input$ar_taxalevel)
  comparecol <- isolate(input$ar_comparecol)
  req(taxalevel, comparecol)

  env <- current_rdata()
  if (is.null(env)) return(NULL)

  batch.correct.res <- env$batch.correct.res
  filtered.meta <- env$filtered.meta
  if (is.null(batch.correct.res) || is.null(filtered.meta)) return(NULL)

  meta_df <- filtered.meta[[taxalevel]]
  if (is.null(meta_df) || !(comparecol %in% colnames(meta_df))) return(NULL)
  valid_groups <- levels(factor(meta_df[[comparecol]]))

  refs <- comparereflist()
  compareref <- if (!is.null(refs) && !is.null(refs[[comparecol]])) refs[[comparecol]] else NULL

  custom_taxa <- isolate(input$hm_custom_taxa)
  if (is.null(custom_taxa) || length(custom_taxa) == 0) {
    return(girafe(ggobj = plot_error_message("Please select at least one taxon in Custom mode.")))
  }

  sel <- isolate(input$hm_selected_grps_custom)
  sel2 <- intersect(sel %||% character(0), valid_groups)
  comparecase <- if (is.null(sel) || length(sel) == 0 || length(sel2) == 0) valid_groups else sel2

  h_svg <- 10

  tryCatch({
    p <- drawtaxaviolinplot(
      input_clr = batch.correct.res[[taxalevel]]$correctedTable,
      input_meta = meta_df,
      taxa_list = custom_taxa,
      comparecol = comparecol,
      comparecase = comparecase,
      compareref = compareref,
      input_palette = comedacolors
    )
    girafe(
      ggobj = p, width_svg = 16, height_svg = h_svg,
      options = list(
        opts_tooltip(opacity = 0.8),
        opts_hover(css = "fill:black;"),
        opts_toolbar(saveaspng = FALSE)
      )
    )
  }, error = function(e) {
    girafe(ggobj = plot_error_message(e$message))
  })
})

# ==============================================================================
# 3. Diversity - Alpha & Beta
# ==============================================================================

# 3.1 Update Diversity Filter Groups
observe({
  job_status$results_version
  taxalevel <- input$ar_taxalevel
  comparecol <- input$ar_comparecol

  if (is.null(taxalevel) || taxalevel == "" || is.null(comparecol) || comparecol == "") return()

  env <- current_rdata()
  if (is.null(env) || is.null(env$filtered.meta)) return()

  if (!is.null(env$filtered.meta[[taxalevel]])) {
    meta_df <- env$filtered.meta[[taxalevel]]
    if (comparecol %in% colnames(meta_df)) {
      groups <- levels(factor(meta_df[[comparecol]]))
      if (length(groups) > 0) {
        updateSelectizeInput(session, "div_filter_groups", choices = groups, selected = groups)
      }
    }
  }
})

# 3.2 Alpha Diversity Plot
output$alpha_diversity_plot <- renderGirafe({
  # Trigger 1: Manual Update
  input$div_update_btn

  # Trigger 2: Global Auto-Update (Not Isolated)
  comparecol <- input$ar_comparecol
  taxalevel <- input$ar_taxalevel

  w_alpha$show(); on.exit(w_alpha$hide())
  req(taxalevel, comparecol)

  env <- current_rdata()
  if (is.null(env) || is.null(env$aldex.prop) || is.null(env$filtered.meta)) return(NULL)

  meta_df <- env$filtered.meta[[taxalevel]]
  if (is.null(meta_df) || !(comparecol %in% colnames(meta_df))) return(NULL)

  valid_groups <- levels(factor(meta_df[[comparecol]]))
  refs <- comparereflist()
  compareref <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else NULL

  # === Smart Fallback Logic ===
  user_selection <- isolate(input$div_filter_groups)

  # If user selection is NULL or contains items NOT in current valid_groups (stale data)
  if (is.null(user_selection) || length(user_selection) == 0 || !all(user_selection %in% valid_groups)) {
    # Fallback: Plot ALL groups
    comparecase <- valid_groups
  } else {
    # Valid selection: Use it
    comparecase <- user_selection
  }

  p <- tryCatch({
    drawalphaviolinplot(
      input_prop = env$aldex.prop[[taxalevel]],
      input_meta = meta_df,
      comparecol = comparecol,
      comparecase = comparecase,
      compareref = compareref,
      alpha_metric = isolate(input$div_alpha_metric), # Isolated
      show_stat = if(isolate(input$div_alpha_stats)) "yes" else "no", # Isolated
      dotsize = isolate(input$div_dotsize) # Isolated
    )
  }, error = function(e) plot_error_message(e$message))

  if (is.null(p)) return(NULL)
  girafe(ggobj = p, width_svg = 8, height_svg = 6, options = list(opts_tooltip(opacity = 0.8), opts_toolbar(saveaspng = FALSE)))
})

# 3.3 Beta Diversity Plot
output$beta_diversity_plot <- renderGirafe({
  # Trigger 1: Manual Update
  input$div_update_btn

  # Trigger 2: Global Auto-Update (Not Isolated)
  comparecol <- input$ar_comparecol
  taxalevel <- input$ar_taxalevel

  w_beta$show(); on.exit(w_beta$hide())
  req(taxalevel, comparecol)

  env <- current_rdata()
  if (is.null(env) || is.null(env$aldex.prop)) return(NULL)

  meta_df <- env$filtered.meta[[taxalevel]]
  if (is.null(meta_df) || !(comparecol %in% colnames(meta_df))) return(NULL)

  valid_groups <- levels(factor(meta_df[[comparecol]]))
  refs <- comparereflist()
  compareref <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else NULL

  # === Smart Fallback Logic ===
  user_selection <- isolate(input$div_filter_groups)
  if (is.null(user_selection) || length(user_selection) == 0 || !all(user_selection %in% valid_groups)) {
    comparecase <- valid_groups
  } else {
    comparecase <- user_selection
  }

  beta_x <- isolate(input$div_beta_x); beta_y <- isolate(input$div_beta_y)
  if(is.null(beta_x)) beta_x <- 1; if(is.null(beta_y)) beta_y <- 2

  p <- tryCatch({
    drawbetaplot(
      input_prop = env$aldex.prop[[taxalevel]],
      input_clr = env$batch.correct.res[[taxalevel]]$correctedTable,
      input_meta = meta_df,
      comparecol = comparecol,
      comparecase = comparecase,
      compareref = compareref,
      ord_method = isolate(input$div_beta_method), # Isolated
      display_axes = c(as.numeric(beta_x), as.numeric(beta_y)),
      dotsize = isolate(input$div_dotsize) # Isolated
    )
  }, error = function(e) plot_error_message(e$message))

  if (is.null(p)) return(NULL)
  girafe(ggobj = p, width_svg = 8, height_svg = 6, options = list(opts_tooltip(opacity = 0.8), opts_hover(css = "fill:orange;stroke:black;"), opts_toolbar(saveaspng = FALSE)))
})

# ==============================================================================
# 4. Correlation Network (Hybrid Triggering Implemented)
# ==============================================================================

# 4.1 Update comparison event choices
observe({
  job_status$results_version
  req(input$ar_taxalevel, input$ar_comparecol)

  env <- current_rdata()
  if (is.null(env) || is.null(env$corr.res)) return()

  refs <- comparereflist()
  ref_grp <- if (!is.null(refs[[input$ar_comparecol]])) refs[[input$ar_comparecol]] else "Ref"

  if (!is.null(env$corr.res[[input$ar_taxalevel]]) && !is.null(env$corr.res[[input$ar_taxalevel]][[input$ar_comparecol]])) {
    events <- names(env$corr.res[[input$ar_taxalevel]][[input$ar_comparecol]])
    choices <- c(ref_grp, events)
    updateSelectizeInput(session, "cn_compevent", choices = choices, selected = choices)
  } else {
    updateSelectizeInput(session, "cn_compevent", choices = character(0))
  }

  if (!is.null(env$batch.correct.res) && !is.null(env$batch.correct.res[[input$ar_taxalevel]])) {
    taxa <- colnames(env$batch.correct.res[[input$ar_taxalevel]]$correctedTable)
    updateSelectizeInput(session, "cn_focal_taxon", choices = c("None"="", taxa), server = TRUE)
  }
})

# 4.3 Network Plot
output$corr_network_plot <- renderGirafe({
  input$cn_update_btn # Trigger 1

  taxalevel <- input$ar_taxalevel # Trigger 2 (Global)
  comparecol <- input$ar_comparecol # Trigger 2 (Global)

  w_network$show(); on.exit(w_network$hide())
  req(taxalevel, comparecol)

  env <- current_rdata()
  if (is.null(env) || is.null(env$corr.res)) return(NULL)

  corr_res <- env$corr.res
  if (is.null(corr_res[[taxalevel]]) || is.null(corr_res[[taxalevel]][[comparecol]])) return(NULL)

  # Valid events in current data
  valid_events <- names(corr_res[[taxalevel]][[comparecol]])
  refs <- comparereflist()
  ref_grp <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else "Ref"
  valid_choices <- c(ref_grp, valid_events)

  # === Smart Fallback Logic ===
  user_selection <- isolate(input$cn_compevent)

  if (is.null(user_selection) || length(user_selection) == 0 || !all(user_selection %in% valid_choices)) {
    # Fallback: All valid events + Ref (Default behavior)
    compevents <- valid_choices
  } else {
    compevents <- user_selection
  }

  if (length(compevents) == 0) return(NULL)

  p <- tryCatch({
    plot_interactive_networks(
      corr_res = corr_res,
      taxalevel = taxalevel,
      compcol = comparecol,
      compevent = compevents,
      pcut = isolate(input$cn_pcut), # Isolated
      corrcut = isolate(input$cn_corrcut), # Isolated
      ptype = isolate(input$cn_ptype), # Isolated: "raw" or "adjusted"
      layout_type = isolate(input$cn_layout), # Isolated
      show_labels = isolate(input$cn_labels), # Isolated
      labelsize = isolate(input$cn_labelsize),
      hubdegree = isolate(input$cn_hubdegree),
      focal_taxon = if(isolate(input$cn_focal_taxon) == "") NULL else isolate(input$cn_focal_taxon),
      toptaxa = isolate(input$cn_toptaxa),
      unified_layout = isolate(input$cn_unified),
      show_legend = isolate(input$cn_legend),
      analysis_type = "within_domain"
    )
  }, error = function(e) plot_error_message(e$message))

  if (is.null(p)) return(NULL)
  girafe(ggobj = p, width_svg = 18, height_svg = 10, options = list(opts_tooltip(opacity = 0.8), opts_toolbar(saveaspng = FALSE), opts_zoom(max = 5)))
})

# ==============================================================================
# 5. Functional Prediction (Hybrid Triggering Implemented)
# ==============================================================================

# 5.1 Load Data (Same as before)
func_data <- reactiveValues(clr = NULL, prop = NULL, loaded = FALSE, error_msg = "")
observe({
  job_status$results_version
  req(job_status$current_id, input$selected_analysis_result)

  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") {
    func_data$loaded <- FALSE; return()
  }
  f_path <- file.path(comedainvpath, job_status$current_id, "analysis", input$selected_analysis_result, "functional_prediction", paste0(job_status$current_id, ".pathway_kegg.txt"))

  if (file.exists(f_path)) {
    tryCatch({
      raw <- read.table(f_path, header=T, sep="\t", quote="", comment.char="", check.names=F)
      res <- func.preprocess(raw, sampletype = "16S")
      func_data$clr <- res$clr; func_data$prop <- res$prop; func_data$loaded <- TRUE
    }, error = function(e) { func_data$loaded <- FALSE })
  } else { func_data$loaded <- FALSE }
})

# 5.2 Update Event Choices
observe({
  job_status$results_version
  req(input$selected_analysis_result, input$ar_comparecol)

  env <- current_rdata(); comparecol <- input$ar_comparecol
  taxalevel <- if(!is.null(input$ar_taxalevel) && input$ar_taxalevel != "") input$ar_taxalevel else "genus" # Default

  if (is.null(env) || is.null(env$filtered.meta) || is.null(env$filtered.meta[[taxalevel]])) return()
  meta <- env$filtered.meta[[taxalevel]]

  if (comparecol %in% colnames(meta)) {
    refs <- comparereflist()
    ref_grp <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else levels(factor(meta[[comparecol]]))[1]
    all_grps <- levels(factor(meta[[comparecol]]))
    case_groups <- setdiff(all_grps, ref_grp)

    if (length(case_groups) > 0) {
      labels <- paste0(case_groups, " vs. ", ref_grp)
      choices <- setNames(case_groups, labels)
      updateSelectInput(session, "fp_event", choices = choices, selected = case_groups[1])
    } else {
      updateSelectInput(session, "fp_event", choices = character(0))
    }
  }
})
# 5.3 Render Plot
output$func_plot <- renderGirafe({
  input$fp_update_btn # Trigger 1
  comparecol <- input$ar_comparecol # Trigger 2 (Global)

  w_func$show(); on.exit(w_func$hide())
  req(comparecol)

  if (!func_data$loaded) return(girafe(ggobj=plot_error_message("No Functional Data Found")))

  env <- current_rdata()
  lvl <- if(!is.null(input$ar_taxalevel) && input$ar_taxalevel != "") input$ar_taxalevel else names(env$filtered.meta)[1]
  meta <- env$filtered.meta[[lvl]]
  if(is.null(meta)) return(NULL)

  # Determine valid events from metadata
  valid_groups <- levels(factor(meta[[comparecol]]))

  # === Smart Fallback Logic ===
  user_selection <- isolate(input$fp_event)

  if (is.null(user_selection) || user_selection == "" || !user_selection %in% valid_groups) {
    # Fallback: Need to calculate case vs ref.
    # Since we can't guess easily without the ref logic again, we try to pick the first non-ref group
    refs <- comparereflist()
    ref_grp <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else valid_groups[1]
    cases <- setdiff(valid_groups, ref_grp)
    if(length(cases) > 0) comparecase <- cases[1] else return(NULL)
  } else {
    comparecase <- user_selection
  }

  # Determine Reference
  refs <- comparereflist()
  compareref <- if (!is.null(refs[[comparecol]])) refs[[comparecol]] else levels(factor(meta[[comparecol]]))[1]

  if (comparecase == compareref) return(girafe(ggobj=plot_error_message("Case and Reference cannot be the same")))

  fp_view_mode <- isolate(input$fp_view_mode)
  if(is.null(fp_view_mode)) fp_view_mode <- "bubble"

  p <- tryCatch({
    funcdam <- perform_functional_dam(
      func_clr = func_data$clr,
      meta = meta,
      comparecol = comparecol,
      comparecase = comparecase,
      compareref = compareref
    )
    tbl <- funcdamtablecalc(
      funcdam = funcdam,
      func_prop = func_data$prop,
      meta = meta,
      comparecol = comparecol,
      comparecase = comparecase,
      compareref = compareref
    )
    if (fp_view_mode == "bubble") {
      drawfuncbubbleplot(
        functable = tbl,
        efcut = isolate(input$fp_efcut), # Isolated
        pvaluetype = isolate(input$fp_pval_type), # Isolated
        pcut = isolate(input$fp_pcut), # Isolated
        propcut = isolate(input$fp_propcut), # Isolated
        showname = isolate(input$fp_show_labels), # Isolated
        fontsize = isolate(input$fp_label_size) # Isolated
      )
    } else {
      drawfuncbarplot(
        functable = tbl,
        efcut = isolate(input$fp_efcut), # Isolated
        pvaluetype = isolate(input$fp_pval_type), # Isolated
        pcut = isolate(input$fp_pcut), # Isolated
        propcut = isolate(input$fp_propcut), # Isolated
        top_n = isolate(input$fp_top_n) # Isolated
      )
    }
  }, error = function(e) plot_error_message(e$message))

  if (is.null(p)) return(girafe(ggobj=plot_error_message("No significant pathways found")))
  girafe(ggobj = p, width_svg = 18, height_svg = 10, options = list(opts_tooltip(opacity = 0.8), opts_toolbar(saveaspng = FALSE), opts_zoom(max = 5)))
})

# Filter Mode Info Modal
observeEvent(input$hm_filtermode_info, {
  showModal(modalDialog(
    title = tagList(icon("info-circle"), " Filter Mode Description"),
    size = "m",
    easyClose = TRUE,
    footer = modalButton("Close"),

    # DAM Mode
    div(style = "background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
      h5(strong("DAM"), " (Differential Abundance Analysis)", style = "color: #721c24; margin-top: 0;"),
      p(style = "margin-bottom: 0; color: #721c24;",
        "Display only taxa with statistically significant differences between groups. ",
        "Default thresholds: Wilcoxon test P-value ≤ 0.05, Effect size (Cliff's Delta) ≥ 0.33. ",
        "Useful for identifying microbial biomarkers."
      )
    ),

    # Abundance Mode
    div(style = "background-color: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
      h5(strong("Abundance (Top N)"), style = "color: #155724; margin-top: 0;"),
      p(style = "margin-bottom: 0; color: #155724;",
        "Display the top N most abundant taxa across all samples without statistical filtering. ",
        "Shows overall community composition as a heatmap. ",
        "Useful for exploratory analysis of taxa distribution."
      )
    ),

    # Custom Mode
    div(style = "background-color: #cce5ff; border: 1px solid #b8daff; padding: 15px; border-radius: 5px;",
      h5(strong("Custom"), style = "color: #004085; margin-top: 0;"),
      p(style = "color: #004085;",
        "Manually select specific taxa of interest for visualization. Provides two plot types:"
      ),
      tags$ul(style = "color: #004085; margin-bottom: 0;",
        tags$li(strong("Heatmap:"), " Visualize multiple selected taxa across all samples."),
        tags$li(strong("Violin Plot:"), " Clearly display the abundance distribution of selected taxa across different groups, ideal for detailed comparison of specific species.")
      )
    )
  ))
})

# Focal Taxon Info Modal (Correlation Network)
observeEvent(input$cn_focal_taxon_info, {
  showModal(modalDialog(
    title = tagList(icon("info-circle"), " Focal Taxon"),
    size = "m",
    easyClose = TRUE,
    footer = modalButton("Close"),

    div(style = "background-color: #e7f3ff; border: 1px solid #b6d4fe; padding: 15px; border-radius: 5px;",
      h5(icon("crosshairs"), strong(" What is Focal Taxon?"), style = "color: #0a58ca; margin-top: 0;"),
      p(style = "color: #084298;",
        "Select a specific taxon of interest to focus the network visualization. ",
        "The network will display only the selected taxon and its directly correlated partners (ego network)."
      ),
      hr(style = "border-color: #b6d4fe;"),
      h6(strong("When to use:"), style = "color: #0a58ca;"),
      tags$ul(style = "color: #084298; margin-bottom: 0;",
        tags$li("Investigating interactions of a potential ", strong("biomarker"), " or ", strong("keystone species")),
        tags$li("Simplifying complex networks to focus on a specific microbe"),
        tags$li("Exploring positive/negative correlations of a taxon of interest")
      ),
      hr(style = "border-color: #b6d4fe;"),
      p(style = "color: #6c757d; font-style: italic; margin-bottom: 0;",
        icon("lightbulb"), " Tip: Leave empty or None to display the full correlation network."
      )
    )
  ))
})
