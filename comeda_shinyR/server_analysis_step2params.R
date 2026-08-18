## server_analysis_step2params.R; CoMeDA v2.2; Step 2 Parameter Configuration
## Generate on 2025.11.25
## Updated: 2025.12.11 (Added Demo Mode Auto-fill)

# ^=============================================================================
# Section 2.1: Auto-detection from Metadata (triggered after Step 1 validation)
# =============================================================================

# ^observeEvent: auto-detect parameters when step 1 validation passed
observeEvent(job_status$validation$simple_passed, {
  
  req(job_status$validation$simple_passed == TRUE)
  
  # ^get metadata
  metadata <- job_status$uploaded_files$metadata$data
  metadata_cols <- colnames(metadata)
  data_info <- job_status$uploaded_files$data
  # get metadata$
  
  # ^detect comparison columns with STRICT regex
  comp_cols <- grep("^comparison$|^comparison\\..+$", metadata_cols, value = TRUE)

  # ^auto-detect metadata columns
  job_status$auto_detected <- list(
    file_name_col = ifelse("file.name" %in% metadata_cols, "file.name", "none"),
    need_demultiplex = ifelse("barcode" %in% metadata_cols, "yes", "no"),
    barcode_col = ifelse("barcode" %in% metadata_cols, "barcode", "none"),
    fprimer_col = ifelse("Fprimer" %in% metadata_cols, "Fprimer", "none"),
    rprimer_col = ifelse("Rprimer" %in% metadata_cols, "Rprimer", "none"),
    batches_col = ifelse("batches" %in% metadata_cols, "batches", "none"),
    comparison_cols = if(length(comp_cols) > 0) comp_cols else "none"
  )
  # auto-detect metadata columns$
  
  # ^validation check
  validation_errors <- c()
  
  if (data_info$type == "sequencing" && job_status$auto_detected$file_name_col == "none") {
    validation_errors <- c(validation_errors, "file.name column not found (required for sequencing mode)")
  }
  
  if (identical(job_status$auto_detected$comparison_cols, "none")) {
    validation_errors <- c(validation_errors, "No valid comparison column found (required) (e.g., comparison or comparison.1)")
  }
  
  if (length(validation_errors) > 0) {
    job_status$validation$deep_passed <- FALSE
    job_status$validation$deep_errors <- validation_errors
    job_status$step2_expanded <- FALSE
    
    showNotification(paste0("Parameter detection failed: ", paste(validation_errors, collapse = "; ")), type = "error", duration = 6)
  } else {
    job_status$validation$deep_passed <- TRUE
    job_status$validation$deep_errors <- NULL
    job_status$step2_expanded <- TRUE
    
    showNotification("Parameters auto-detected successfully! Please configure Step 2.", type = "message", duration = 4)
    
    # ==========================================================================
    # [NEW] Demo Mode: Auto-fill Step 2 Parameters
    # ==========================================================================
    if (job_status$demo_mode == 1) {
      # 1. Update Data Type to 16S
      updateRadioButtons(session, "data_type", selected = "16S")
      
      # 2. Update Sequencing Platform to PacBio
      updateSelectInput(session, "sequencing_type", selected = "PacBio")
      
      # 3. Baseline selection is handled dynamically in output$ui_comparison_baselines
      
      showNotification("Demo Mode: Parameters auto-filled (16S / PacBio / Saliva_Control).", type = "message", duration = 5)
    }
    # ==========================================================================
  }
  
}, ignoreInit = TRUE)
# observeEvent: auto-detect parameters$

# ^output: step2_can_display
output$step2_can_display <- reactive({
  job_status$step2_expanded
})
outputOptions(output, "step2_can_display", suspendWhenHidden = FALSE)
# output: step2_can_display$

# ^output: is_sequencing_mode
output$is_sequencing_mode <- reactive({
  req(job_status$uploaded_files$data)
  job_status$uploaded_files$data$type == "sequencing"
})
outputOptions(output, "is_sequencing_mode", suspendWhenHidden = FALSE)
# output: is_sequencing_mode$

# ^=============================================================================
# Section 2.2: Dynamic UI for Comparison Baselines
# =============================================================================

output$ui_comparison_baselines <- renderUI({
  req(job_status$auto_detected$comparison_cols)
  cols <- job_status$auto_detected$comparison_cols
  
  if (identical(cols, "none")) return(NULL)
  
  metadata <- job_status$uploaded_files$metadata$data
  
  # Generate a selectInput for each detected comparison column
  lapply(cols, function(col) {
    # Get unique levels/values for this column
    vals <- unique(as.character(metadata[[col]]))
    vals <- vals[vals != "" & !is.na(vals)] 
    
    # [NEW] Determine default selection (Logic for Demo Mode)
    default_sel <- vals[1]
    
    # If in Demo Mode and "Saliva_Control" exists, select it
    if (job_status$demo_mode == 1 && "Saliva_Control" %in% vals) {
      default_sel <- "Saliva_Control"
    }
    
    tagList(
      tags$div(
        style = "margin-bottom: 10px;",
        tags$label(class = "control-label", paste0(col, " Baseline:")),
        selectInput(
          inputId = paste0("baseline_", col),
          label = NULL, 
          choices = vals,
          selected = default_sel, # Use calculated default
          width = "100%"
        )
      )
    )
  })
})

# ^=============================================================================
# Section 2.3: Sequencing Type Conversion
# =============================================================================

# ^reactive: convert UI sequencing type to backend readtype
readtype_value <- reactive({
  req(input$sequencing_type)
  switch(input$sequencing_type,
         "Illumina" = "short_reads",
         "PacBio" = "long_reads",
         "Nanopore" = "long_reads",
         "short_reads") 
})
# reactive: readtype_value$

# ^=============================================================================
# Section 2.3.5: Skip Chimera Parameter (NEW - 2025.12.20)
# =============================================================================

# ^reactive: get skip_chimera value (pass directly to shell script)
# Auto mode detection happens in shell script after QC (reads actual read length)
skip_chimera_value <- reactive({
  data_info <- job_status$uploaded_files$data
  
  # If not sequencing mode, return "no" (not applicable)
  if (is.null(data_info) || data_info$type != "sequencing") {
    return("no")
  }
  
  user_choice <- input$skip_chimera
  
  # Return user's choice directly: "auto", "yes", or "no"
  # Shell script will handle auto-detection based on actual read length
  if (is.null(user_choice)) {
    return("auto")  # Default
  }
  
  return(user_choice)
})
# reactive: skip_chimera_value$

# ^=============================================================================
# Section 2.4: Auto-update Default Values
# =============================================================================

# ^observeEvent: update QC parameters when sequencing type changes
observeEvent(input$sequencing_type, {
  req(input$sequencing_type)
  if (input$sequencing_type == "Illumina") {
    updateNumericInput(session, "qscore", value = 20)
    updateNumericInput(session, "minlen", value = 150)
    updateNumericInput(session, "maxlen", value = 600)
  } else if (input$sequencing_type == "PacBio") {
    updateNumericInput(session, "qscore", value = 30)
    updateNumericInput(session, "minlen", value = 400)
    updateNumericInput(session, "maxlen", value = 1800)
  } else if (input$sequencing_type == "Nanopore") {
    updateNumericInput(session, "qscore", value = 15)
    updateNumericInput(session, "minlen", value = 400)
    updateNumericInput(session, "maxlen", value = 1800)
  }
}, ignoreInit = TRUE)
# observeEvent: update QC parameters$

# ^observeEvent: update strict prevalence when data type changes
observeEvent(input$data_type, {
  req(input$data_type)
  if (input$data_type == "16S") {
    updateNumericInput(session, "strict_prevalence_cutoff", value = 0.3)
    updateNumericInput(session, "kraken2_confidence", value = 0.1)
  } else if (input$data_type == "ITS") {
    updateNumericInput(session, "strict_prevalence_cutoff", value = 0.2)
    updateNumericInput(session, "kraken2_confidence", value = 0.05)
  }
}, ignoreInit = TRUE)
# observeEvent: update strict prevalence$

# ^=============================================================================
# Section 2.5: Configuration Summary Outputs
# =============================================================================

output$summary_data_type <- renderUI({ req(input$data_type); data_type <- ifelse(input$data_type == "16S", "16S rRNA", "ITS"); tags$span(data_type, style = "color: forestgreen; font-weight: bold;") })
output$summary_sequencing_type <- renderUI({ data_info <- job_status$uploaded_files$data; if (is.null(data_info) || data_info$type == "taxatable") { tags$span("N/A (taxa-table mode)", style = "color: #999; font-style: italic;") } else { req(input$sequencing_type); if (input$sequencing_type == "") { tags$span("Not selected", style = "color: firebrick; font-weight: bold;") } else { tags$span(input$sequencing_type, style = "color: forestgreen; font-weight: bold;") } } })
output$summary_readtype <- renderUI({ data_info <- job_status$uploaded_files$data; if (is.null(data_info) || data_info$type == "taxatable") { tags$span("N/A (taxa-table)", style = "color: #999; font-style: italic;") } else { req(input$sequencing_type); tags$span(readtype_value(), style = "color: forestgreen; font-weight: bold;") } })
output$summary_param_mode <- renderUI({ req(input$use_default_params); params <- ifelse(input$use_default_params, "Default", "Custom"); tags$span(params, style = "color: forestgreen; font-weight: bold;") })
output$summary_comparison_baselines_list <- renderUI({ cols <- job_status$auto_detected$comparison_cols; if (identical(cols, "none")) return(NULL); tag_list <- lapply(cols, function(col) { selected_base <- input[[paste0("baseline_", col)]]; if (is.null(selected_base)) selected_base <- "Selecting..."; tags$div(style = "margin-bottom: 2px;", tags$strong(paste0(col, ": "), style = "font-size: 13px;"), tags$span(selected_base, style = "color: forestgreen; font-weight: bold;")) }); do.call(tagList, tag_list) })
output$summary_file_name_col <- renderUI({ req(job_status$auto_detected); col_name <- job_status$auto_detected$file_name_col; if (col_name == "none") { tags$span("Not found", style = "color: #999; font-style: italic;") } else { tags$span(col_name, style = "color: forestgreen; font-weight: bold;") } })
output$summary_need_demultiplex <- renderUI({ req(job_status$auto_detected); need_demux <- job_status$auto_detected$need_demultiplex; if (need_demux == "yes") { tags$span("Yes", style = "color: forestgreen; font-weight: bold;") } else { tags$span("No", style = "color: forestgreen; font-weight: bold;") } })
output$summary_barcode_col <- renderUI({ req(job_status$auto_detected); col_name <- job_status$auto_detected$barcode_col; if (col_name == "none") { tags$span("Not found", style = "color: #999; font-style: italic;") } else { tags$span(col_name, style = "color: forestgreen; font-weight: bold;") } })
output$summary_fprimer_col <- renderUI({ req(job_status$auto_detected); col_name <- job_status$auto_detected$fprimer_col; if (col_name == "none") { tags$span("Not found", style = "color: #999; font-style: italic;") } else { tags$span(col_name, style = "color: forestgreen; font-weight: bold;") } })
output$summary_rprimer_col <- renderUI({ req(job_status$auto_detected); col_name <- job_status$auto_detected$rprimer_col; if (col_name == "none") { tags$span("Not found", style = "color: #999; font-style: italic;") } else { tags$span(col_name, style = "color: forestgreen; font-weight: bold;") } })
output$summary_comparison_col <- renderUI({ req(job_status$auto_detected); cols <- job_status$auto_detected$comparison_cols; if (identical(cols, "none")) { tags$span("ERROR: Not found", style = "color: firebrick; font-weight: bold;") } else { tags$span(paste(cols, collapse=",\n"), style = "color: forestgreen; font-weight: bold;") } })
output$summary_batches_col <- renderUI({ req(job_status$auto_detected); col_name <- job_status$auto_detected$batches_col; if (col_name == "none") { tags$span("Not found (no batch correction)", style = "color: #999; font-style: italic;") } else { tags$span(col_name, style = "color: forestgreen; font-weight: bold;") } })
output$summary_qscore <- renderText({ req(input$qscore); as.character(input$qscore) })
output$summary_minlen <- renderText({ req(input$minlen); as.character(input$minlen) })
output$summary_maxlen <- renderText({ req(input$maxlen); as.character(input$maxlen) })
output$summary_uchimeref <- renderText({ req(input$use_uchime_ref); toupper(input$use_uchime_ref) })
output$summary_skip_chimera <- renderUI({
  data_info <- job_status$uploaded_files$data
  if (is.null(data_info) || data_info$type != "sequencing") {
    return(tags$span("N/A (taxa-table mode)", style = "color: #999; font-style: italic;"))
  }
  req(input$skip_chimera)
  choice <- input$skip_chimera
  if (choice == "auto") {
    tags$span("AUTO (detect after QC)", style = "color: #17a2b8; font-weight: bold;")
  } else if (choice == "yes") {
    tags$span("SKIP", style = "color: #e67e22; font-weight: bold;")
  } else {
    tags$span("EXECUTE", style = "color: forestgreen; font-weight: bold;")
  }
})
output$summary_taxa_levels <- renderText({ req(input$taxa_levels); input$taxa_levels })
output$summary_sample_richness <- renderText({ req(input$sample_richness_cutoff); as.character(input$sample_richness_cutoff) })
output$summary_sample_rc <- renderText({ req(input$sample_readcount_cutoff); as.character(input$sample_readcount_cutoff) })
output$summary_taxa_prev <- renderText({ req(input$taxa_prevalence_cutoff); as.character(input$taxa_prevalence_cutoff) })
output$summary_func_prev <- renderText({ req(input$func_prevalence_cutoff); as.character(input$func_prevalence_cutoff) })
output$summary_func_size <- renderText({ req(input$func_size_cutoff); as.character(input$func_size_cutoff) })
output$summary_strict_prop <- renderText({ req(input$strict_proportion_cutoff); as.character(input$strict_proportion_cutoff) })
output$summary_strict_prev <- renderText({ req(input$strict_prevalence_cutoff); as.character(input$strict_prevalence_cutoff) })

# ^=============================================================================
# Section 2.6: Proceed to Step 3 - Collect All Parameters
# =============================================================================

observeEvent(input$submit_analysis_btn, {
  
  # ^validation: check required fields
  validation_errors <- c()
  if (is.null(input$data_type) || input$data_type == "") validation_errors <- c(validation_errors, "Data Type is required")
  
  data_info <- job_status$uploaded_files$data
  if (!is.null(data_info) && data_info$type == "sequencing") {
    if (is.null(input$sequencing_type) || input$sequencing_type == "") validation_errors <- c(validation_errors, "Sequencing Platform is required for sequencing data")
  }
  
  if (length(validation_errors) > 0) {
    showNotification(paste0("Cannot proceed: ", paste(validation_errors, collapse = "; ")), type = "error", duration = 5)
    return(NULL)
  }

  # ^Collect Comparison Info
  comp_cols <- job_status$auto_detected$comparison_cols
  comparison_info_list <- list()
  for(col in comp_cols) {
    baseline_val <- input[[paste0("baseline_", col)]]
    if(!is.null(baseline_val)) {
      comparison_info_list[[col]] <- baseline_val
    }
  }
  
  # ^collect all parameters
  job_status$parameters <- list(
    data_type = input$data_type,
    readtype = if (data_info$type == "sequencing") readtype_value() else NA,
    sequencing_platform = if (data_info$type == "sequencing") input$sequencing_type else NA,
    seqfilecol = job_status$auto_detected$file_name_col,
    demultipx = job_status$auto_detected$need_demultiplex,
    barcocol = job_status$auto_detected$barcode_col,
    Fprimercol = job_status$auto_detected$fprimer_col,
    Rprimercol = job_status$auto_detected$rprimer_col,
    groupname = comp_cols[1],
    batchcolname = job_status$auto_detected$batches_col,
    comparison_info = comparison_info_list,
    qscore = input$qscore,
    minlen = input$minlen,
    maxlen = input$maxlen,
    uchimeref = input$use_uchime_ref,
    skipchimera = if (data_info$type == "sequencing") skip_chimera_value() else "no",
    taxalevels = input$taxa_levels,
    samplerichcut = input$sample_richness_cutoff,
    samplerccut = input$sample_readcount_cutoff,
    taxaprevcut = input$taxa_prevalence_cutoff,
    funcprevcut = input$func_prevalence_cutoff,
    funcsizecut = input$func_size_cutoff,
    strictedpropcut = input$strict_proportion_cutoff,
    strictedprevcut = input$strict_prevalence_cutoff,
    projectname = job_status$current_id,
    outname = "analysis_result",
    inputtype = data_info$type
  )
  
  job_status$step3_ready <- TRUE
  showNotification(paste0("Parameters configured successfully! Total ", length(job_status$parameters), " parameters collected."), type = "message", duration = 4)
  
}, ignoreInit = TRUE)
# observeEvent: proceed_to_step3$
