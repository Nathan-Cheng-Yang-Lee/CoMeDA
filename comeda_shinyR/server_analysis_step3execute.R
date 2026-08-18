# server_analysis_step3execute.R
# CoMeDA v2.4.5 - Step 3: Execute Analysis Pipeline Server Logic
# Version: v2.5.1 (Fixed Demo UI Blocking Issue)
# Updated: 2025-12-11 (Split Demo Logic to ensure UI renders before waiting)

# ^step 3 execute server logic

## ^conditional display control
output$step3_can_display <- reactive({
  !is.null(job_status$analysis_submitted) && job_status$analysis_submitted == TRUE
})
outputOptions(output, "step3_can_display", suspendWhenHidden = FALSE)

## ^dynamic ui: pipeline workflow display
output$pipeline_workflow_display <- renderUI({
  req(job_status$analysis_submitted)

  # [MODIFIED] Use stored input type if uploaded_files$data is NULL
  data_info <- job_status$uploaded_files$data
  inputtype <- if (!is.null(data_info)) {
    data_info$type
  } else if (!is.null(job_status$analysis_input_type)) {
    job_status$analysis_input_type
  } else {
    return(NULL)
  }

  req(data_info)
  inputtype <- data_info$type
  
  if (inputtype == "sequencing") {
    workflow_items <- tagList(
      tags$li("Phase 0: File Transfer"), tags$li("Phase 1: Demultiplexing (if needed)"), tags$li("Phase 2: Quality Control"),
      tags$li("Phase 3: Chimera Reads Removal"), tags$li("Phase 4: Taxa-table Classification"), tags$li("Phase 5: Taxa Analysis"),
      tags$li("Phase 6: Functional Prediction")
    )
  } else {
    workflow_items <- tagList(tags$li("Phase 0: File Transfer"), tags$li("Phase 1: Taxa Analysis"))
  }
  
  div(style = "background-color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #3498db;",
    h4(style = "color: #34495e; margin-top: 0;", icon("list-ol"), "Pipeline Workflow:"),
    tags$ul(style = "font-size: 15px; line-height: 1.8; color: #555;", workflow_items)
  )
})

## ^dynamic ui: browser warning message
output$browser_warning_message <- renderUI({
  req(job_status$analysis_state)
  req(job_status$current_id)
  
  if (job_status$analysis_state == "initializing") {
    div(style = "background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 5px; margin-bottom: 20px;",
      div(style = "color: #856404; font-weight: bold; margin-bottom: 5px;", icon("exclamation-triangle"), " Please keep this browser tab open during initialization."),
      div(style = "color: #856404; font-size: 14px;", "You can close the tab once analysis starts running in the background.")
    )
  } else if (job_status$analysis_state == "running") {
    div(style = "background-color: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; border-radius: 5px; margin-bottom: 20px;",
      div(style = "color: #0c5460; font-weight: bold; margin-bottom: 8px;", icon("info-circle"), " Analysis Running in Background"),
      div(style = "color: #0c5460; font-size: 14px; line-height: 1.6;", strong("You can now close this browser tab."), " The analysis will continue running.")
    )
  } else if (job_status$analysis_state == "failed") {
    div(style = "background-color: #f8d7da; border-left: 4px solid #e74c3c; padding: 15px; border-radius: 5px; margin-bottom: 20px;",
      div(style = "color: #721c24; font-weight: bold; margin-bottom: 8px;", icon("times-circle"), " Analysis Failed"),
      div(style = "color: #721c24; font-size: 14px;", "The analysis pipeline encountered an error and has stopped.")
    )
  } else { NULL }
})

## ^dynamic ui: execution status header
output$execution_status_header <- renderUI({
  req(job_status$current_id)
  div(style = "border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-bottom: 20px;",
    span(style = "color: #3498db; font-size: 18px; font-weight: bold;", ">_ Execution Status:"), br(),
    span(style = "color: #95a5a6; font-size: 14px; margin-top: 5px;", "Job ID: ", tags$strong(style = "color: #ecf0f1;", job_status$current_id))
  )
})

## ^dynamic ui: phase status display
output$phase_status_display <- renderUI({
  # [MODIFIED] Use stored input type if uploaded_files$data is NULL (after cleanup)
  data_info <- job_status$uploaded_files$data
  inputtype <- if (!is.null(data_info)) {
    data_info$type
  } else if (!is.null(job_status$analysis_input_type)) {
    job_status$analysis_input_type
  } else {
    return(NULL)  # Cannot determine, skip rendering
  }	
  
  if (inputtype == "sequencing") {
    phase_info <- list(
      phase0 = list(name = "File Transfer", num = "0"), phase1 = list(name = "Demultiplexing", num = "1"),
      phase2 = list(name = "Quality Control", num = "2"), phase3 = list(name = "Chimera Reads Removal", num = "3"),
      phase4 = list(name = "Taxa-table Classification", num = "4"), phase5 = list(name = "Taxa Analysis", num = "5"),
      phase6 = list(name = "Functional Prediction", num = "6")
    )
  } else {
    phase_info <- list(phase0 = list(name = "File Transfer", num = "0"), phase1 = list(name = "Taxa Analysis", num = "1"))
  }
  
  phase_elements <- lapply(names(phase_info), function(phase) {
    info <- phase_info[[phase]]; status <- job_status$phase_status[[phase]]
    if (is.null(status)) status <- "queued"
    
    if (status == "completed") {
      icon <- "[OK]"; color <- "#2ecc71"; font_weight <- "normal"; time_info <- job_status$phase_time_info[[phase]]
      text <- if (!is.null(time_info)) paste0(info$name, " (Completed - ", time_info, ")") else paste0(info$name, " (Completed)")
    } else if (status == "running") {
      icon <- "[RUN]"; color <- "#3498db"; font_weight <- "normal"; elapsed_info <- job_status$phase_elapsed_info[[phase]]
      text <- if (!is.null(elapsed_info)) paste0(info$name, " (Running - ", elapsed_info, " elapsed)") else paste0(info$name, " (Running)")
    } else if (status == "pending") {
      icon <- "[...]"; color <- "#17a2b8"; font_weight <- "normal"; text <- paste0(info$name, " (Preparing...)")
    } else if (status == "failed") {
      icon <- "[X]"; color <- "#e74c3c"; font_weight <- "bold"; text <- paste0(info$name, " (Failed)")
    } else if (status == "skipped") {
      icon <- "[SKIP]"; color <- "#f39c12"; font_weight <- "normal"; text <- paste0(info$name, " (Skipped)")
    } else {
      icon <- "[ ]"; color <- "#95a5a6"; font_weight <- "normal"; text <- paste0(info$name, " (Queued)")
    }
    
    div(style = paste0("color: ", color, "; margin: 8px 0; font-size: 15px; font-weight: ", font_weight, ";"), paste(icon, "Phase", info$num, ":", text))
  })
  do.call(tagList, phase_elements)
})

## ^dynamic ui: log messages section
output$log_messages_section <- renderUI({
  div(style = "margin-bottom: 15px;",
    div(style = "color: #3498db; font-weight: bold; margin-bottom: 10px;", icon("file-alt"), "Latest Log Messages: ", span(style = "color: #95a5a6; font-size: 13px; font-weight: normal;", textOutput("log_update_time", inline = TRUE))),
    div(id = "log_messages_container", style = "background-color: #1e272e; padding: 15px; border-radius: 5px; max-height: 200px; overflow-y: auto; font-size: 13px;", uiOutput("log_messages_display"))
  )
})

output$log_messages_display <- renderUI({
  log_content <- job_status$log_content
  if (is.null(log_content) || length(log_content) == 0) return(div(style = "color: #95a5a6; font-style: italic;", "No log messages yet..."))
  log_lines <- tail(log_content, 30)
  log_elements <- lapply(log_lines, function(line) div(style = "margin: 2px 0; color: #ecf0f1;", line))
  do.call(tagList, log_elements)
})

output$log_update_time <- renderText({ req(job_status$log_last_update); paste("(Last updated:", format(job_status$log_last_update, "%H:%M:%S"), ")") })

## ^dynamic ui: time information display
output$time_information_display <- renderUI({
  req(job_status$analysis_start_time)
  if (!is.null(job_status$analysis_state) && job_status$analysis_state %in% c("initializing", "running")) invalidateLater(1000)
  
  elapsed <- difftime(Sys.time(), job_status$analysis_start_time, units = "secs")
  elapsed_secs <- as.numeric(elapsed)
  hours <- floor(elapsed_secs / 3600); minutes <- floor((elapsed_secs %% 3600) / 60); seconds <- floor(elapsed_secs %% 60)
  elapsed_str <- sprintf("%d hours %d minutes %d seconds", hours, minutes, seconds)
  
  div(style = "color: #95a5a6; font-size: 14px;", div("Started: ", format(job_status$analysis_start_time, "%Y-%m-%d %H:%M:%S")), div("Elapsed: ", elapsed_str))
})

## ^initialize analysis execution
observeEvent(input$submit_analysis_btn, {
  # ========================================================================
  # DEMO MODE LOGIC: PART 1 (Initialize UI & Trigger Delay)
  # ========================================================================
  if (job_status$demo_mode == 1) {
    
    # 1. Set State to Show Step 3 UI
    job_status$analysis_submitted <- TRUE
    job_status$analysis_state <- "running"
    job_status$analysis_start_time <- Sys.time()

    # [NEW] Store input type for step3 display
#    job_status$analysis_input_type <- data_info$type
    
    # 2. Initialize Phases to simulate progress
    data_info <- job_status$uploaded_files$data

    job_status$analysis_input_type <- data_info$type
    
    if (data_info$type == "sequencing") {
      job_status$phase_status$phase0 <- "completed"
      job_status$phase_status$phase1 <- "completed"
      job_status$phase_status$phase2 <- "completed"
      job_status$phase_status$phase3 <- "completed"
      job_status$phase_status$phase4 <- "completed"
      job_status$phase_status$phase5 <- "running"  # Visual feedback: Processing
      job_status$phase_status$phase6 <- "queued"
    } else {
      job_status$phase_status$phase0 <- "completed"
      job_status$phase_status$phase1 <- "running"
    }
    
    # Dummy log
    job_status$log_content <- c("[Demo] Initializing demo analysis simulation...", "[Demo] Loading pre-calculated results...", "[Demo] Generating reports...")
    job_status$log_last_update <- Sys.time()
    
    showNotification("Running demo analysis simulation...", type = "message", duration = 2)
    
    # 3. Scroll to Step 3
    if (requireNamespace("shinyjs", quietly = TRUE)) {
      tryCatch({
        shinyjs::runjs("setTimeout(function() { var elem = document.getElementById('step3_execute_container'); if (elem) elem.scrollIntoView({behavior: 'smooth'}); }, 10);")
      }, error = function(e) {})
    }
    
    # 4. TRIGGER PART 2: Send message to browser to wait 500ms then call back R
    # This ensures the UI thread has time to render Step 3 before we start sleeping/jumping
    if (requireNamespace("shinyjs", quietly = TRUE)) {
      shinyjs::runjs("setTimeout(function(){ Shiny.setInputValue('demo_simulation_finish_trigger', Math.random()); }, 500);")
    }
    
    return() # End Part 1 immediately so UI can update
  }
  
  # ========================================================================
  # REAL ANALYSIS LOGIC
  # ========================================================================
  
  # Validate current_id exists
  if (is.null(job_status$current_id)) {
    showNotification("Error: No valid Job ID found. Please upload files again.", type = "error", duration = 10)
    return()
  }

  project_path <- paste0(comedainvpath, "/", job_status$current_id)

  tryCatch({
    for (phase_num in 0:6) {
      error_flag <- paste0(project_path, "/.phase", phase_num, "_error")
      success_flag <- paste0(project_path, "/.phase", phase_num, "_complete")
      if (file.exists(error_flag)) file.remove(error_flag)
      if (file.exists(success_flag)) file.remove(success_flag)
    }
    transfer_complete <- paste0(project_path, "/.transfer_complete")
    transfer_error <- paste0(project_path, "/.transfer_error")
    if (file.exists(transfer_complete)) file.remove(transfer_complete)
    if (file.exists(transfer_error)) file.remove(transfer_error)
  }, error = function(e) warning("Failed to clean old flags (non-critical):", e$message))
  
  # Set state flags
  job_status$analysis_submitted <- TRUE
  job_status$analysis_state <- "initializing"
  job_status$analysis_start_time <- Sys.time()
  
  data_info <- job_status$uploaded_files$data
  if (!is.null(data_info)) {
      job_status$analysis_input_type <- data_info$type
  }

  req(data_info)
  inputtype <- data_info$type
  
  phase_list <- if (inputtype == "sequencing") c("phase0", "phase1", "phase2", "phase3", "phase4", "phase5", "phase6") else c("phase0", "phase1")
  for (phase in phase_list) job_status$phase_status[[phase]] <- "queued"
  
  job_status$phase_status$phase0 <- "pending"
  
  job_status$phase_start_time <- list()
  job_status$phase_complete_time <- list()
  job_status$phase_time_info <- list()
  job_status$phase_elapsed_info <- list()
  
  job_status$log_content <- character(0)
  job_status$log_last_update <- Sys.time()
  
  script_info <- create_transfer_script()
  
  if (!script_info$success) {
    job_status$analysis_state <- "failed"
    job_status$phase_status$phase0 <- "failed"
    showNotification(paste("Failed to create transfer script:", script_info$error), type = "error", duration = 10)
    return()
  }
  
  job_status$transfer_script_path <- script_info$script_path
  job_status$transfer_flag_path <- script_info$flag_path
  job_status$transfer_error_flag <- script_info$error_flag
  job_status$transfer_trigger <- runif(1)
  
  if (requireNamespace("shinyjs", quietly = TRUE)) {
    tryCatch({
      shinyjs::runjs("setTimeout(function() { var elem = document.getElementById('step3_execute_container'); if (elem) elem.scrollIntoView({behavior: 'smooth'}); }, 10);")
    }, error = function(e) {})
  }
  
}, ignoreInit = TRUE)

# ==============================================================================
# DEMO MODE LOGIC: PART 2 (Wait & Jump)
# Triggered by JavaScript after Part 1 updates the UI
# ==============================================================================
observeEvent(input$demo_simulation_finish_trigger, {
  req(job_status$demo_mode == 1)
  req(job_status$analysis_state == "running")
  
  # 1. Wait 5 seconds (User sees the monitoring screen now)
  Sys.sleep(1)
  
  # 2. Finalize Demo State
  job_status$analysis_state <- "completed"
  data_info <- job_status$uploaded_files$data
  
  if (data_info$type == "sequencing") {
     job_status$phase_status$phase5 <- "completed"
     job_status$phase_status$phase6 <- "completed"
  } else {
     job_status$phase_status$phase1 <- "completed"
  }
  
  # 3. Jump to Results Tab
  job_status$results_version <- job_status$results_version + 1
  updateTabsetPanel(session, "analysis_workflow", selected = "view_kingdom_specific_tab")
})

# ^observe: start background transfer - launches shell script
observe({
  req(job_status$transfer_trigger)
  req(job_status$phase_status$phase0 == "pending")
  isolate({
    tryCatch({
      success_comp <- prepare_comparison_info_file()
      if (!success_comp) {
        job_status$analysis_state <- "failed"; job_status$phase_status$phase0 <- "failed"
        showNotification("Failed to prepare comparison info file.", type="error"); return()
      }
      success_params <- save_parameters_info()
      
      job_status$phase_status$phase0 <- "running"
      job_status$phase_start_time$phase0 <- Sys.time()
      
      script_path <- job_status$transfer_script_path
      cmd <- paste0("bash '", script_path, "' > '", dirname(script_path), "/transfer.log' 2>&1")
      system(cmd, wait = FALSE)
      
    }, error = function(e) {
      job_status$analysis_state <- "failed"; job_status$phase_status$phase0 <- "failed"
      showNotification(paste("Transfer error:", e$message), type="error")
    })
  })
})

observe({
  req(job_status$phase_status$phase0 == "running")
  invalidateLater(1000)
  flag_path <- job_status$transfer_flag_path
  error_flag <- job_status$transfer_error_flag
  
  if (file.exists(error_flag)) {
    job_status$phase_status$phase0 <- "failed"; job_status$analysis_state <- "failed"
    showNotification("File transfer failed.", type = "error")
  } else if (file.exists(flag_path)) {
    job_status$phase_status$phase0 <- "completed"
    job_status$phase_complete_time$phase0 <- Sys.time()
    elapsed <- difftime(Sys.time(), job_status$phase_start_time$phase0, units="mins")
    job_status$phase_time_info$phase0 <- paste(round(elapsed, 1), "min")
    
    success_scripts <- start_analysis_scripts()
    if (!success_scripts) { job_status$analysis_state <- "failed"; return() }
    
    job_status$analysis_state <- "running"
    showNotification("Analysis started successfully!", type = "message")
  }
})

observe({
  req(job_status$phase_status$phase0 == "running")
  invalidateLater(500)
  start_t <- job_status$phase_start_time$phase0
  if (!is.null(start_t)) {
    el <- round(as.numeric(difftime(Sys.time(), start_t, units="mins")), 1)
    job_status$phase_elapsed_info$phase0 <- paste(el, "min")
  }
})

## ^prepare comparison info file
prepare_comparison_info_file <- function() {
  tryCatch({
    comp_info <- job_status$parameters$comparison_info
    if (is.null(comp_info) || length(comp_info) == 0) return(FALSE)
    
    comp_info_df <- data.frame(col = names(comp_info), baseline = unlist(comp_info), stringsAsFactors = FALSE)
    comp_info_table <- rbind(as.character(comp_info_df$col), as.character(comp_info_df$baseline))
    
    project_path <- get_current_project_path()
    comp_info_path <- paste0(project_path, "/analysis/compinfotable.txt")
    analysis_dir <- paste0(project_path, "/analysis")
    if (!dir.exists(analysis_dir)) dir.create(analysis_dir, recursive = TRUE)
    
    write.table(comp_info_table, file = comp_info_path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
    return(TRUE)
  }, error = function(e) { warning("Error in prepare_comparison_info_file:", e$message); return(FALSE) })
}

## ^save parameters info
save_parameters_info <- function() {
  
  tryCatch({
    
    # Get all parameters
    params <- job_status$parameters
    
    if (is.null(params) || length(params) == 0) {
      return(FALSE)
    }
    
    # Define path
    project_path <- get_current_project_path()

    # If analysisname not yet created, generate it now and store
    if (is.null(job_status$analysisname)) {
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      job_status$analysisname <- paste0("analysis_result_", timestamp)
      cat("[Save Parameters] Generated analysisname:", job_status$analysisname, "\n")
    }

    analysisname <- job_status$analysisname

    # Create analysis directory using fixed analysisname
    analysis_dir <- paste0(project_path, "/analysis/", analysisname)
    if (!dir.exists(analysis_dir)) {
      dir.create(analysis_dir, recursive = TRUE)
      cat("[Save Parameters] Created directory:", analysis_dir, "\n")
    }

    params_path <- paste0(analysis_dir, "/parameters_info.txt")

    # ===== ADDED: Create SECTION 1 header =====
    header_lines <- c(
      "# ============================================================",
      "# CoMeDA Analysis Parameters",
      paste0("# Project: ", job_status$current_id),
      paste0("# Analysis Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "# ============================================================",
      "",
      "# [SECTION 1: SUBMITTED PARAMETERS]",
      "# Parameters submitted by user in Step 2"
    )

    # Write header first
    writeLines(header_lines, params_path)
    cat("[Save Parameters] Header written\n")
    # ===== HEADER END =====
    
    # ===== [NEW] Add kraken2_confidence (user-adjustable; reviewer revision) =====
    # Value is taken from the user-facing input (numericInput "kraken2_confidence").
    # If not set (e.g. taxa-table mode), fall back to the data_type-based default:
    # 16S: 0.1, ITS: 0.05. The two-stage fallback in 0.1_pretaxatablegeneration.sh
    # may still lower the value at runtime if classification fails.
    kraken2_confidence_fallback <- if (!is.null(params$data_type) && params$data_type == "ITS") {
      "0.05"
    } else {
      "0.1"  # Default for 16S
    }
    kraken2_confidence_default <- if (!is.null(input$kraken2_confidence) &&
                                      is.finite(suppressWarnings(as.numeric(input$kraken2_confidence)))) {
      as.character(input$kraken2_confidence)
    } else {
      kraken2_confidence_fallback
    }
    
    # Insert kraken2_confidence after uchimeref, before taxalevels
    # We need to reconstruct the params list with proper ordering
    param_names_original <- names(params)
    
    # Find position of uchimeref and taxalevels
    uchimeref_idx <- which(param_names_original == "uchimeref")
    taxalevels_idx <- which(param_names_original == "taxalevels")
    
    if (length(uchimeref_idx) > 0 && length(taxalevels_idx) > 0) {
      # Insert kraken2_confidence between uchimeref and taxalevels
      params_ordered <- c(
        params[1:uchimeref_idx],
        list(kraken2_confidence = kraken2_confidence_default),
        params[(uchimeref_idx + 1):length(params)]
      )
    } else {
      # Fallback: just append at the end
      params_ordered <- c(params, list(kraken2_confidence = kraken2_confidence_default))
    }
    # ===== kraken2_confidence insertion END =====
    
    # Prepare parameters as data frame
    # [FIX] Handle NULL/NA to prevent sapply coercion crash
    param_names <- names(params_ordered)
    param_values <- sapply(params_ordered, function(x) {
      if (is.null(x) || length(x) == 0 || all(is.na(x))) {
        return("NA")
      }
      if (is.list(x)) {
        # For comparison_info, convert to string
        paste(names(x), unlist(x), sep = "=", collapse = ";")
      } else {
        as.character(x)
      }
    })
    
    params_df <- data.frame(
      parameter = param_names,
      value = param_values,
      stringsAsFactors = FALSE
    )

    write.table(params_df,
            file = params_path,
            sep = "\t",
            row.names = FALSE,
            col.names = TRUE,
            quote = FALSE,
            append = TRUE)
    
    cat("Parameters saved to:", params_path, "\n")
    cat("Total parameters:", nrow(params_df), "\n")
    
    return(TRUE)
    
  }, error = function(e) {
    warning("Error in save_parameters_info:", e$message)
    return(FALSE)
  })
}
## save parameters info$

## ^create transfer script
create_transfer_script <- function() {
  tryCatch({
    project_path <- get_current_project_path()
    current_id <- job_status$current_id
    data_info <- job_status$uploaded_files$data
    meta_info <- job_status$uploaded_files$metadata
    inputtype <- data_info$type
    
    script_path <- paste0(project_path, "/transfer.sh")
    flag_path <- paste0(project_path, "/.transfer_complete")
    error_flag <- paste0(project_path, "/.transfer_error")
    
    if (file.exists(flag_path)) file.remove(flag_path)
    if (file.exists(error_flag)) file.remove(error_flag)
    
    rawtaxadata_dir <- paste0(project_path, "/rawdata/taxafile")
    rawmetadata_dir <- paste0(project_path, "/rawdata/metadata")
    
    script_lines <- c("#!/bin/bash", "set -e", "", "echo '[Transfer Script] Checking files in rawdata...'")
    
    if (inputtype == "sequencing") {
      script_lines <- c(script_lines, "echo 'Sequencing mode detected.'", "echo 'Files are ready in rawdata directory.'")
    } else {
      taxatable_src <- paste0(rawtaxadata_dir, "/", data_info$file_names[1])
      metadata_src <- paste0(rawmetadata_dir, "/", meta_info$file_name)
      pretaxa_dir <- paste0(project_path, "/analysis/preTaxaTable/rawTaxaTable")
      metadata_analysis_dir <- paste0(project_path, "/analysis/preTaxaTable/metadatafiles")
      taxatable_dst <- paste0(pretaxa_dir, "/", current_id, ".rawTaxaTable.txt")
      metadata_dst <- paste0(metadata_analysis_dir, "/", current_id, ".metadata.txt")
      
      script_lines <- c(script_lines, paste0("mkdir -p '", pretaxa_dir, "'"), paste0("mkdir -p '", metadata_analysis_dir, "'"), paste0("rm -f '", pretaxa_dir, "/*'"), paste0("rm -f '", metadata_analysis_dir, "/*'"), paste0("cp '", taxatable_src, "' '", taxatable_dst, "'"), paste0("cp '", metadata_src, "' '", metadata_dst, "'"))
    }
    
    script_lines <- c(script_lines, "", paste0("touch '", flag_path, "'"), "exit 0")
    writeLines(script_lines, script_path)
    Sys.chmod(script_path, mode = "0755")
    
    return(list(script_path = script_path, flag_path = flag_path, error_flag = error_flag, success = TRUE))
  }, error = function(e) { warning("Error in create_transfer_script:", e$message); return(list(success = FALSE, error = e$message)) })
}

## ^start analysis scripts
start_analysis_scripts <- function() {
  tryCatch({
    params <- job_status$parameters
    data_info <- job_status$uploaded_files$data
    inputtype <- data_info$type
    project_path <- get_current_project_path()
    
    script_0.1_path <- paste0(comedashinypath, "/script/0.1_pretaxatablegeneration.sh")
    script_0.2_path <- paste0(comedashinypath, "/script/0.2_analysisresultgeneration.sh")
    comp_info_path <- paste0(project_path, "/analysis/compinfotable.txt")
    log_dir <- paste0(project_path, "/logs"); if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
    
    if (is.null(job_status$analysisname)) {
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      job_status$analysisname <- paste0("analysis_result_", timestamp)
    }
    analysisname <- job_status$analysisname

    # [reviewer revision] Resolve user-adjustable Kraken2 confidence locally in this
    # function's scope (the value computed in save_parameters_info() is not visible here).
    # Fall back to the data_type-based default when the input is unset (e.g. taxa-table mode).
    kraken2_confidence_arg <- if (!is.null(input$kraken2_confidence) &&
                                  is.finite(suppressWarnings(as.numeric(input$kraken2_confidence)))) {
      as.character(input$kraken2_confidence)
    } else if (!is.null(params$data_type) && params$data_type == "ITS") {
      "0.05"
    } else {
      "0.1"
    }

    if (inputtype == "sequencing") {
      log_file <- paste0(log_dir, "/preprocessing.log")
#      script_args <- c(params$projectname, params$demultipx, params$barcocol, params$Fprimercol, params$Rprimercol, params$qscore, params$minlen, params$maxlen, params$seqfilecol, params$uchimeref, params$data_type, params$readtype)
      script_args <- c(params$projectname, params$demultipx, params$barcocol, params$Fprimercol, params$Rprimercol, params$qscore, params$minlen, params$maxlen, params$seqfilecol, params$uchimeref, params$data_type, params$readtype, params$skipchimera, kraken2_confidence_arg)
      system2("bash", args = c(script_0.1_path, script_args), stdout = log_file, stderr = log_file, wait = FALSE)
    } else {
      log_file <- paste0(log_dir, "/analysis.log")
      script_args <- c(params$projectname, params$data_type, params$groupname, comp_info_path, params$batchcolname, params$taxalevels, params$samplerichcut, params$samplerccut, params$taxaprevcut, params$funcprevcut, params$funcsizecut, params$strictedpropcut, params$strictedprevcut, params$inputtype, "none", analysisname)
      system2("bash", args = c(script_0.2_path, script_args), stdout = log_file, stderr = log_file, wait = FALSE)
    }
    return(TRUE)
  }, error = function(e) { warning("Error in start_analysis_scripts:", e$message); return(FALSE) })
}

## ^start analysis step 2 script
start_analysis_step2_script <- function() {
  tryCatch({
    params <- job_status$parameters
    project_path <- get_current_project_path()
    script_0.2_path <- paste0(comedashinypath, "/script/0.2_analysisresultgeneration.sh")
    comp_info_path <- paste0(project_path, "/analysis/compinfotable.txt")
    log_file <- paste0(project_path, "/logs/analysis.log")
    if (is.null(job_status$analysisname)) job_status$analysisname <- paste0("analysis_result_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    analysisname <- job_status$analysisname
    
    script_args <- c(params$projectname, params$data_type, params$groupname, comp_info_path, params$batchcolname, params$taxalevels, params$samplerichcut, params$samplerccut, params$taxaprevcut, params$funcprevcut, params$funcsizecut, params$strictedpropcut, params$strictedprevcut, params$inputtype, params$readtype, analysisname)
    system2("bash", args = c(script_0.2_path, script_args), stdout = log_file, stderr = log_file, wait = FALSE)
    return(TRUE)
  }, error = function(e) { warning("Error in start_analysis_step2_script:", e$message); return(FALSE) })
}

## ^phase monitoring logic
phase_monitor <- reactiveTimer(3000)
observe({
  req(job_status$analysis_state == "running")
  phase_monitor()
  data_info <- job_status$uploaded_files$data; req(data_info); inputtype <- data_info$type; project_path <- get_current_project_path()
  
  phases_to_check <- if (inputtype == "sequencing") c("phase1", "phase2", "phase3", "phase4", "phase5", "phase6") else c("phase1")
  
  for (phase in phases_to_check) {
    current_status <- job_status$phase_status[[phase]]
    if (is.null(current_status)) { job_status$phase_status[[phase]] <- "queued"; current_status <- "queued" }
    phase_num <- gsub("phase", "", phase)
    
    error_flag <- paste0(project_path, "/.phase", phase_num, "_error")
    success_flag <- paste0(project_path, "/.phase", phase_num, "_complete")
    
    if (file.exists(error_flag)) {
      if (current_status != "failed") {
        error_msg <- tryCatch({ readLines(error_flag, warn=F)[1] }, error = function(e) "Phase failed")
        job_status$phase_status[[phase]] <- "failed"; job_status$analysis_state <- "failed"
        showNotification(error_msg, type="error", duration=NULL)
      }
      next
    }
    
    if (file.exists(success_flag)) {
      if (current_status != "completed") {
        job_status$phase_status[[phase]] <- "completed"; job_status$phase_complete_time[[phase]] <- Sys.time()
        if (!is.null(job_status$phase_start_time[[phase]])) {
          job_status$phase_time_info[[phase]] <- paste(round(as.numeric(difftime(Sys.time(), job_status$phase_start_time[[phase]], units="mins")), 1), "min")
        }
      }
      next
    }
    
    if (phase == "phase1" && inputtype == "sequencing" && job_status$parameters$demultipx == "no") {
      if (current_status != "skipped") job_status$phase_status[[phase]] <- "skipped"
      next
    }
    
    if (phase == "phase6" && inputtype == "sequencing") {
      if (!is.null(job_status$phase_status$phase4) && job_status$phase_status$phase4 == "completed") {
        nochime_dir <- paste0(project_path, "/analysis/preTaxaTable/preprocessing/nochime")
        if (!dir.exists(nochime_dir) || length(list.files(nochime_dir)) == 0) {
          if (current_status != "skipped") job_status$phase_status[[phase]] <- "skipped"
          next
        }
      }
    }
    
    if (current_status == "queued") {
      if (inputtype == "sequencing" && phase == "phase5") {
        if (job_status$phase_status$phase4 == "completed") {
          if (start_analysis_step2_script()) { job_status$phase_status[[phase]] <- "running"; job_status$phase_start_time[[phase]] <- Sys.time() } 
          else { job_status$phase_status[[phase]] <- "failed"; job_status$analysis_state <- "failed" }
        }
        next
      }
      if (inputtype == "sequencing" && phase == "phase6") {
        if (job_status$phase_status$phase4 == "completed") { job_status$phase_status[[phase]] <- "running"; job_status$phase_start_time[[phase]] <- Sys.time() }
        next
      }
      
      prev_phase <- paste0("phase", as.numeric(phase_num)-1)
      if (phase == "phase1") prev_phase <- "phase0"
      prev_st <- job_status$phase_status[[prev_phase]]
      if (!is.null(prev_st) && prev_st %in% c("completed", "skipped")) {
        job_status$phase_status[[phase]] <- "running"; job_status$phase_start_time[[phase]] <- Sys.time()
      }
    }
    
    if (job_status$phase_status[[phase]] == "running") {
      st <- job_status$phase_start_time[[phase]]
      if (!is.null(st)) job_status$phase_elapsed_info[[phase]] <- paste(round(as.numeric(difftime(Sys.time(), st, units="mins")), 1), "min")
    }
  }
  
  all_done <- FALSE
  if (inputtype == "sequencing") {
    p5 <- job_status$phase_status$phase5; p6 <- job_status$phase_status$phase6
    if (!is.null(p5) && p5 == "completed" && !is.null(p6) && (p6 == "completed" || p6 == "skipped")) all_done <- TRUE
  } else {
    if (!is.null(job_status$phase_status$phase1) && job_status$phase_status$phase1 == "completed") all_done <- TRUE
  }
  
  if (all_done) {
    job_status$analysis_state <- "completed"; job_status$results_version <- job_status$results_version + 1

    # [NEW] Mark analysis as completed (for overwrite warning)
    job_status$analysis_completed <- TRUE
    
    # Generate Summary
    tryCatch({
      end_time <- Sys.time(); total <- difftime(end_time, job_status$analysis_start_time, units="secs")
      lines <- c("Pipeline Execution Summary", paste0("Runtime: ", round(as.numeric(total), 0), "s"), "Phase Status:")
      p_list <- if(inputtype=="sequencing") c("phase0","phase1","phase2","phase3","phase4","phase5","phase6") else c("phase0","phase1")
      for(ph in p_list) lines <- c(lines, paste0(ph, ": ", toupper(job_status$phase_status[[ph]])))
      writeLines(lines, paste0(project_path, "/analysis/pipeline_summary.txt"))
    }, error=function(e) warning("Summary generation failed"))
   
    showNotification("Analysis completed! You can now view the results.", type = "message", duration = 5)
    # Switch to View Results tab after a short delay
    shinyjs::delay(500, {
      updateTabsetPanel(session, "analysis_workflow", selected = "view_kingdom_specific_tab")
    }) 
  }
})

## ^log monitoring
log_monitor <- reactiveTimer(2000)
observe({
  req(job_status$analysis_state %in% c("running", "initializing")); log_monitor()
  log_file <- tryCatch({ get_current_log_file() }, error=function(e) NULL)
  if (!is.null(log_file) && file.exists(log_file)) {
    lines <- tryCatch({ readLines(log_file, warn=F) }, error=function(e) character(0))
    if (length(lines) > 0) { job_status$log_content <- lines; job_status$log_last_update <- Sys.time() }
  }
})

get_current_log_file <- function() {
  if (is.null(job_status$current_id) || is.null(job_status$uploaded_files$data)) return(NULL)
  project_path <- paste0(comedainvpath, "/", job_status$current_id); log_dir <- paste0(project_path, "/logs")
  if (!dir.exists(log_dir)) return(NULL)
  
  inputtype <- job_status$uploaded_files$data$type
  if (inputtype == "sequencing") {
    for (ph in c("phase1","phase2","phase3","phase4")) if (!is.null(job_status$phase_status[[ph]]) && job_status$phase_status[[ph]]=="running") return(paste0(log_dir, "/preprocessing.log"))
    if (!is.null(job_status$phase_status$phase5) && job_status$phase_status$phase5=="running") return(paste0(log_dir, "/analysis.log"))
    if (!is.null(job_status$phase_status$phase6) && job_status$phase_status$phase6=="running") return(if(file.exists(paste0(log_dir, "/branch2_function.log"))) paste0(log_dir, "/branch2_function.log") else paste0(log_dir, "/analysis.log"))
  } else {
    if (!is.null(job_status$phase_status$phase1) && job_status$phase_status$phase1=="running") return(paste0(log_dir, "/analysis.log"))
  }
  
  if (inputtype == "sequencing" && file.exists(paste0(log_dir, "/preprocessing.log"))) return(paste0(log_dir, "/preprocessing.log"))
  if (file.exists(paste0(log_dir, "/analysis.log"))) return(paste0(log_dir, "/analysis.log"))
  return(NULL)
}
