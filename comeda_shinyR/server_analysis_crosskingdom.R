## server_analysis_crosskingdom.R
## Logic for Step C: Cross-Kingdom / Paired Correlation Analysis
## Updated: 2025.12.15 (Auto-Load on ID Change, Regex Fix, Removed Tabset)

source(paste(comedashinypath, "script", "plot.corrnetwork.R", sep = "/"), local = TRUE)

# Define Waiter for Plot
w_ck_net <- Waiter$new(
  id = "ck_network_plot",
  html = tagList(spin_clock(), h4("Generating Network...")),
  color = "rgba(0,0,0,0.4)"
)

ck_values <- reactiveValues(
  analysis_finished = FALSE, 
  output_path = NULL, 
  result_data = NULL,
  current_plot_params = NULL, 
  modeB_cols = NULL, 
  summary_params = list(),
  plot_trigger = 0,
  auto_plot = FALSE,
  is_demo = FALSE,
  current_demo_key = NULL,
  event_ready = FALSE
)

# ==============================================================================
# Demo Mode Indicator for conditionalPanel
# ==============================================================================
output$ck_is_demo_mode <- reactive({
  isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo"
})
outputOptions(output, "ck_is_demo_mode", suspendWhenHidden = FALSE)

# ==============================================================================
# Demo Info Pop-up Modal
# ==============================================================================
observeEvent(input$ck_demo_info_btn, {
  showModal(modalDialog(
    title = tagList(icon("database"), " Cross-Dataset Demo Datasets Information"),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Close"),
    
    # Cross-Kingdom: Crohn's Disease
    div(style = "background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
        h5(icon("bacteria"), " Cross-Kingdom: Pediatric Crohn's Disease", style = "color: #1565c0; font-weight: bold; margin-top: 0;"),
        tags$ul(style = "margin-bottom: 5px;",
                tags$li(tags$strong("Analysis Type: "), "Bacteria (16S) + Fungi (ITS) Correlation"),
                tags$li(tags$strong("BioProject: "), tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1156939", target = "_blank", "PRJNA1156939 (16S)"), " and ", tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1156940", target = "_blank", "PRJNA1156940 (ITS)") ),
                tags$li(tags$strong("Platform: "), "Illumina"),
                tags$li(tags$strong("Samples: "), "90 (Crohn's Disease patients)"),
                tags$li(tags$strong("Comparison: "), "CD vs Control across different sites"),
                tags$li(tags$strong("Demo Feature: "), "Cross-kingdom microbiome interactions")
        ),
        p(style = "font-size: 0.85em; color: #666; margin-bottom: 0;", 
          "Kim et al. (2025) iScience, 28, 113160.")
    ),
    
    # Paired-Condition: Saliva & Subgingival
    div(style = "background-color: #e8f5e9; border: 1px solid #a5d6a7; padding: 15px; border-radius: 5px;",
        h5(icon("tooth"), " Paired-Condition: Saliva & Subgingival", style = "color: #2e7d32; font-weight: bold; margin-top: 0;"),
        tags$ul(style = "margin-bottom: 5px;",
                tags$li(tags$strong("Analysis Type: "), "Same microbiome (16S) from different oral sites"),
                tags$li(tags$strong("BioProject: "), tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA933120", target = "_blank", "PRJNA933120")),
                tags$li(tags$strong("Platform: "), "PacBio"),
                tags$li(tags$strong("Samples: "), "40 (Periodontitis 20 vs Control 20)"),
                tags$li(tags$strong("Comparison: "), "Perio vs Control"),
                tags$li(tags$strong("Demo Feature: "), "Paired-condition correlation analysis")
        ),
        p(style = "font-size: 0.85em; color: #666; margin-bottom: 0;", 
          "Buetas et al. (2024) BMC Genomics, 25, 310.")
    )
  ))
})

ck_demo_config <- list(
  # Cross-Kingdom: Crohn's Disease (Mode B 分析)
  cross_kingdom_ck = list(
    label = "Cross-Kingdom (Crohn's Disease)",
    cross_kingdom_folder = "cross_kingdom_ck",
    analysis_mode = "B",  # Mode B: File Upload
    dataset1 = list(
      description = "Bacteria (16S)",
      taxa_table = "CD_16S.taxatable.txt",
      metadata = "CD_16S.metadata.txt"
    ),
    dataset2 = list(
      description = "Fungi (ITS)",
      taxa_table = "CD_ITS.taxatable.txt",
      metadata = "CD_ITS.metadata.txt"
    )
  ),
  # Paired-Condition: Saliva & Subgingival (Mode A 分析)
  cross_kingdom_pc = list(
    label = "Paired-Condition (Saliva & Subgingival)",
    cross_kingdom_folder = "cross_kingdom_pc",
    analysis_mode = "A",  # Mode A: CoMeDA UUID
    dataset1 = list(
      job_id = "comedademo",
      result_folder = "analysis_result_PacBio.Saliva(demo.dataset2)",
      description = "Saliva (16S)"
    ),
    dataset2 = list(
      job_id = "comedademo",
      result_folder = "analysis_result_PacBio.Subgingival(demo.dataset1)",
      description = "Subgingival (16S)"
    )
  )
)

# ==============================================================================
# Helper: Get Current Demo Configuration based on selection
# ==============================================================================
get_current_demo_config <- function() {
  selected <- isolate(input$ck_demo_dataset_select)
  if (is.null(selected) || selected == "") selected <- "paired_condition"

  if (selected %in% names(ck_demo_config)) {
    return(ck_demo_config[[selected]])
  } else {
    return(ck_demo_config[["paired_condition"]])  # Default fallback
  }
}

# 0. UI Reset Logic (Updated: exclude demo button changes)
observeEvent(c(input$ck_input_mode, input$ck_uuid_16s, input$ck_uuid_its, 
               input$ck_file_16s, input$ck_file_its, input$ck_file_meta), {
  # Only reset if NOT in demo mode (to prevent demo being cleared)
  if (!ck_values$is_demo) {
    ck_values$analysis_finished <- FALSE
    ck_values$result_data <- NULL
    ck_values$output_path <- NULL
    ck_values$summary_params <- list()
    ck_values$plot_trigger <- 0
    ck_values$auto_plot <- FALSE
  }
})

# ==============================================================================
# Helper Function: Parse parameters_info.txt (FIXED REGEX)
# ==============================================================================
parse_parameters_info <- function(filepath) {
  if (!file.exists(filepath)) return(NULL)
  
  lines <- readLines(filepath, warn = FALSE)
  # Initialize with "Unknown"/Empty to prevent UI rendering issues
  result <- list(
    mode = "Unknown",
    dataset1 = list(),
    dataset2 = list(),
    parameters = list(),
    detection = list()
  )
  
  current_section <- NULL
  
  for (line in lines) {
    line <- trimws(line)
    if (line == "" || grepl("^=+$", line)) next
    
    # [FIX] Robust Regex for Section Headers (Allow spaces, ignore case)
    if (grepl("^\\[\\s*Analysis Mode\\s*\\]", line, ignore.case = TRUE)) { current_section <- "mode"; next }
    if (grepl("^\\[\\s*Dataset 1\\s*\\]", line, ignore.case = TRUE)) { current_section <- "dataset1"; next }
    if (grepl("^\\[\\s*Dataset 2\\s*\\]", line, ignore.case = TRUE)) { current_section <- "dataset2"; next }
    if (grepl("^\\[\\s*Analysis Parameters\\s*\\]", line, ignore.case = TRUE)) { current_section <- "parameters"; next }
    if (grepl("^\\[\\s*Detection Info\\s*\\]", line, ignore.case = TRUE)) { current_section <- "detection"; next }
    
    # Parse key-value pairs
    if (grepl(":", line)) {
      parts <- strsplit(line, ":", fixed = TRUE)[[1]]
      if (length(parts) >= 1) {
        key <- trimws(parts[1])
        # Reconstruct value (in case value itself contains colon)
        value <- if(length(parts) > 1) trimws(paste(parts[-1], collapse = ":")) else ""
        
        if (!is.null(current_section)) {
          if (current_section == "mode" && grepl("Mode", key, ignore.case=TRUE)) {
            result$mode <- value
          } else if (current_section == "dataset1") {
            result$dataset1[[key]] <- value
          } else if (current_section == "dataset2") {
            result$dataset2[[key]] <- value
          } else if (current_section == "parameters") {
            result$parameters[[key]] <- value
          } else if (current_section == "detection") {
            result$detection[[key]] <- value
          }
        }
      }
    }
  }
  return(result)
}

# ==============================================================================
# Helper: Load Cross-Kingdom Demo Results
# ==============================================================================
load_ck_demo_results <- function() {
  
  # Get current demo config based on selection
  selected <- input$ck_demo_dataset_select
  if (is.null(selected) || selected == "") selected <- "cross_kingdom_ck"
  
  demo_cfg <- ck_demo_config[[selected]]
  if (is.null(demo_cfg)) {
    showNotification("Demo configuration not found.", type = "error")
    return()
  }
  
  # Construct path to cross-kingdom results
  ck_path <- paste0(comedainvpath, "/comedademo/", demo_cfg$cross_kingdom_folder)
  rdata_file <- paste0(ck_path, "/crossdomain.Rdata")
  
  if (!file.exists(rdata_file)) {
    showNotification(paste("Demo results not found:", demo_cfg$label), type = "warning")
    return()
  }
  
  tryCatch({
    w <- Waiter$new(html = tagList(spin_clock(), h4("Loading Demo Results...")), color = "rgba(0,0,0,0.4)")
    w$show()
    
    e <- new.env()
    load(rdata_file, envir = e)
    
    ck_values$result_data <- e$crossdomain.corr.res
    ck_values$output_path <- ck_path
    ck_values$analysis_finished <- TRUE
    ck_values$auto_plot <- TRUE
    ck_values$is_demo <- TRUE
    ck_values$current_demo_key <- selected
    
    # Parse Parameters Info
    param_file <- paste0(ck_path, "/parameters_info.txt")
    if (file.exists(param_file)) {
      ck_values$summary_params <- parse_parameters_info(param_file)
    } else {
      levels_found <- names(ck_values$result_data)
      ck_values$summary_params <- list(
        mode = paste0("Demo (", demo_cfg$analysis_mode, ")"),
        dataset1 = list(source = demo_cfg$dataset1$description),
        dataset2 = list(source = demo_cfg$dataset2$description),
        parameters = list("Taxa Levels" = paste(levels_found, collapse = ", ")),
        detection = list(mode = demo_cfg$label, overlapping_samples = "N/A")
      )
    }
    
    # Update plot controls
    levels_found <- names(ck_values$result_data)
    lvl <- levels_found[1]
    updateSelectInput(session, "ck_plot_level", choices = levels_found, selected = lvl)
    if (!is.null(ck_values$result_data[[lvl]])) {
      comps <- names(ck_values$result_data[[lvl]])
      updateSelectInput(session, "ck_plot_comp", choices = comps, selected = comps[1])
    }
    
    w$hide()
    showNotification(paste("Loaded:", demo_cfg$label), type = "message")
    
  }, error = function(e) {
    w$hide()
    showNotification(paste("Error loading demo:", e$message), type = "error")
  })
}

# ==============================================================================
# Global Job ID Watcher & Auto-Loader (THE CORE LOGIC)
# ==============================================================================
observeEvent(job_status$current_id, {
  
  # 1. Reset current visualization
  ck_values$analysis_finished <- FALSE
  ck_values$result_data <- NULL
  ck_values$output_path <- NULL
  ck_values$summary_params <- list()
  
  # 2. Check if new ID has results
  req(job_status$current_id)

  # For demo mode, let the demo selection handler manage loading
  if (job_status$current_id == "comedademo") {
    # If entering demo mode, load based on current selection
    if (isTRUE(ck_values$is_demo) || job_status$demo_mode == 1) {
      load_ck_demo_results()
    }
    return()
  }

  current_path <- paste0(comedainvpath, "/", job_status$current_id)
  ck_path <- paste0(current_path, "/cross_kingdom")
  rdata_file <- paste0(ck_path, "/crossdomain.Rdata")
  
  if (file.exists(rdata_file)) {
    # === Auto-Load Found Results ===
    tryCatch({
      w <- Waiter$new(html = tagList(spin_clock(), h4("Loading Cross-Kingdom Results...")), color = "rgba(0,0,0,0.4)")
      w$show()
      
      e <- new.env()
      load(rdata_file, envir = e)
      
      ck_values$result_data <- e$crossdomain.corr.res
      ck_values$output_path <- ck_path
      ck_values$analysis_finished <- TRUE
      ck_values$auto_plot <- TRUE
      
      # Determine if this is demo
      ck_values$is_demo <- (job_status$current_id == "comedademo")
      
      # Parse Parameters Info
      param_file <- paste0(ck_path, "/parameters_info.txt")
      if (file.exists(param_file)) {
        ck_values$summary_params <- parse_parameters_info(param_file)
      } else {
        # Fallback
        levels_found <- names(ck_values$result_data)
        ck_values$summary_params <- list(
          mode = if(ck_values$is_demo) "Demo" else "Loaded Result",
          dataset1 = list(source = job_status$current_id),
          dataset2 = list(source = job_status$current_id),
          parameters = list("Taxa Levels" = paste(levels_found, collapse = ", ")),
          detection = list(mode = "Unknown", overlapping_samples = "N/A")
        )
      }
      
      # Init UI inputs
      levels_found <- names(ck_values$result_data)
      lvl <- levels_found[1]
      updateSelectInput(session, "ck_plot_level", choices = levels_found, selected = lvl)
      if (!is.null(ck_values$result_data[[lvl]])) {
        comps <- names(ck_values$result_data[[lvl]])
        updateSelectInput(session, "ck_plot_comp", choices = comps, selected = comps[1])
      }
      
      w$hide()
      showNotification("Cross-Kingdom analysis results loaded.", type = "message")
      
    }, error = function(e) {
      w$hide()
      showNotification(paste("Error loading results:", e$message), type = "error")
    })
    
  } else {
    # === No Results Found ===
    # If triggered by "Change Job ID" button in this tab, show specific warning
    if (!is.null(job_status$trigger_source) && job_status$trigger_source == "cross_kingdom") {
      showNotification("Job ID switched, but no Cross-Kingdom analysis found. Please run a new analysis below.", 
                       type = "warning", duration = 6)
    }
  }
})

# ==============================================================================
# Demo Button Logic (Simplified)
# ==============================================================================
observeEvent(input$ck_use_demo, {
  # 1. Set Global ID to "comedademo" (This triggers the observer above to load results)
  if (job_status$demo_mode == 0) {
    job_status$user_mode <- 0
    job_status$demo_mode <- 1
    job_status$new_id <- ifelse(is.null(job_status$new_id), job_status$current_id, job_status$new_id)
    job_status$current_id <- "comedademo"
    job_status$results_version <- job_status$results_version + 1
  }

  # 2. Set demo flag and load demo dataset
  ck_values$is_demo <- TRUE

  # 3. Load cross-kingdom results based on current selection
  load_ck_demo_results()

  # 4. Sync Step 1 Data (So Analysis Tab is also ready)
  load_demo_dataset()
})

# ==============================================================================
# [NEW] Global Demo Mode Watcher - Fill Mode A inputs when ANY demo button is clicked
# ==============================================================================
observeEvent(job_status$demo_mode, {
  # Only trigger when demo mode is activated (not when deactivated)
  if (job_status$demo_mode == 1 && job_status$current_id == "comedademo") {

    # Set local demo flag
    ck_values$is_demo <- TRUE

    # Fill Mode A inputs with demo configuration
    updateTextInput(session, "ck_uuid_16s", value = ck_demo_config$dataset1$job_id)
    updateTextInput(session, "ck_uuid_its", value = ck_demo_config$dataset2$job_id)

    # Update validation messages
    output$ck_valid_16s <- renderUI({
      tags$div(style = "color: #28a745; font-weight: bold; margin-bottom: 5px; font-size: 0.9em;",
               icon("check-circle"), " Demo Dataset 1 (Subgingival)")
    })
    output$ck_valid_its <- renderUI({
      tags$div(style = "color: #28a745; font-weight: bold; margin-bottom: 5px; font-size: 0.9em;",
               icon("check-circle"), " Demo Dataset 2 (Saliva)")
    })

    # Update result folder dropdowns - Dataset 1
    path_16s <- paste0(comedainvpath, "/", ck_demo_config$dataset1$job_id, "/analysis")
    if (dir.exists(path_16s)) {
      dirs_16s <- list.dirs(path_16s, full.names = FALSE, recursive = FALSE)
      results_16s <- grep("^analysis_result_", dirs_16s, value = TRUE) %>% sort(decreasing = TRUE)
      updateSelectInput(session, "ck_res_16s",
                        choices = results_16s,
                        selected = ck_demo_config$dataset1$result_folder)
    }

    # Update result folder dropdowns - Dataset 2
    path_its <- paste0(comedainvpath, "/", ck_demo_config$dataset2$job_id, "/analysis")
    if (dir.exists(path_its)) {
      dirs_its <- list.dirs(path_its, full.names = FALSE, recursive = FALSE)
      results_its <- grep("^analysis_result_", dirs_its, value = TRUE) %>% sort(decreasing = TRUE)
      updateSelectInput(session, "ck_res_its",
                        choices = results_its,
                        selected = ck_demo_config$dataset2$result_folder)
    }
  }
})
# Global Demo Mode Watcher$

# ==============================================================================
# [NEW] Dynamic Mode A UI Rendering (Demo vs Normal Mode)
# ==============================================================================
output$ck_modeA_dataset1_ui <- renderUI({
  if (isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo") {

    selected <- input$ck_demo_dataset_select
    if (is.null(selected) || selected == "") selected <- "cross_kingdom_ck"
    demo_cfg <- ck_demo_config[[selected]]

    # Demo Mode: Read-only display
    wellPanel(
      style = "background-color: #fff8e1; border: 2px solid #E95420;",
      h5(style = "color: forestgreen; font-weight: bold;", icon("bacterium"), " Dataset 1 (Demo)"),
      div(style = "padding: 10px; background-color: #fff; border-radius: 5px; margin-top: 10px;",
          if (demo_cfg$analysis_mode == "A") {
            tagList(
              tags$p(tags$strong("Job ID: "), demo_cfg$dataset1$job_id, style = "margin-bottom: 5px;"),
              tags$p(tags$strong("Result Folder: "), demo_cfg$dataset1$result_folder, style = "margin-bottom: 5px;")
            )
          } else {
            tagList(
              tags$p(tags$strong("Taxa Table: "), demo_cfg$dataset1$taxa_table, style = "margin-bottom: 5px;"),
              tags$p(tags$strong("Metadata: "), demo_cfg$dataset1$metadata, style = "margin-bottom: 5px;")
            )
          },
          tags$p(tags$strong("Description: "), demo_cfg$dataset1$description, style = "margin-bottom: 0;")
      ),
      div(style = "color: #E95420; font-size: 0.85em; margin-top: 10px;",
          icon("info-circle"), " This is a demonstration dataset. Switch to your own Job ID to run custom analysis.")
    )
  } else {
    # Normal Mode: Editable inputs
    wellPanel(
      style = "background-color: #fff; border: 1px solid #ddd;",
      h5(style = "color: forestgreen; font-weight: bold;", icon("bacterium"), " Dataset 1 (e.g., Bacteria / pre-treatment)"),
      textInput("ck_uuid_16s", "Job ID (UUID):", placeholder = "e.g., a1b2c3d4..."),
      uiOutput("ck_valid_16s"),
      selectInput("ck_res_16s", "Select Analysis Result Folder:", choices = NULL)
    )
  }
})

output$ck_modeA_dataset2_ui <- renderUI({
  if (isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo") {

    selected <- input$ck_demo_dataset_select
    if (is.null(selected) || selected == "") selected <- "cross_kingdom_ck"
    demo_cfg <- ck_demo_config[[selected]]

    # Demo Mode: Read-only display
    wellPanel(
      style = "background-color: #fff8e1; border: 2px solid #E95420;",
      h5(style = "color: steelblue; font-weight: bold;", icon("leaf"), " Dataset 2 (Demo)"),
      div(style = "padding: 10px; background-color: #fff; border-radius: 5px; margin-top: 10px;",
          if (demo_cfg$analysis_mode == "A") {
            tagList(
              tags$p(tags$strong("Job ID: "), demo_cfg$dataset2$job_id, style = "margin-bottom: 5px;"),
              tags$p(tags$strong("Result Folder: "), demo_cfg$dataset2$result_folder, style = "margin-bottom: 5px;")
            )
          } else {
            tagList(
              tags$p(tags$strong("Taxa Table: "), demo_cfg$dataset2$taxa_table, style = "margin-bottom: 5px;"),
              tags$p(tags$strong("Metadata: "), demo_cfg$dataset2$metadata, style = "margin-bottom: 5px;")
            )
          },
          tags$p(tags$strong("Description: "), demo_cfg$dataset2$description, style = "margin-bottom: 0;")
      ),
      div(style = "color: #E95420; font-size: 0.85em; margin-top: 10px;",
          icon("info-circle"), " This is a demonstration dataset. Switch to your own Job ID to run custom analysis.")
    )
  } else {
    # Normal Mode: Editable inputs
    wellPanel(
      style = "background-color: #fff; border: 1px solid #ddd;",
      h5(style = "color: steelblue; font-weight: bold;", icon("leaf"), " Dataset 2 (e.g., Fungi / pro-treatment)"),
      textInput("ck_uuid_its", "Job ID (UUID):", placeholder = "e.g., e5f6g7h8..."),
      uiOutput("ck_valid_its"),
      selectInput("ck_res_its", "Select Analysis Result Folder:", choices = NULL)
    )
  }
})

# ==============================================================================
# Dynamic Input Mode & Dataset Configuration UI
# ==============================================================================
output$ck_input_config_ui <- renderUI({
  
  # Check if in demo mode
  if (isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo") {
    
    # Get current demo config
    selected <- input$ck_demo_dataset_select
    if (is.null(selected) || selected == "") selected <- "cross_kingdom_ck"
    demo_cfg <- ck_demo_config[[selected]]
    
    # Determine which mode to show
    is_mode_b <- (demo_cfg$analysis_mode == "B")
    mode_label <- if (is_mode_b) "Mode B: File Upload" else "Mode A: CoMeDA UUID"
    
    tagList(
      # Fixed Mode Display (Read-only)
      fluidRow(
        column(12,
               div(style = "background-color: #fff3cd; padding: 10px; border-radius: 5px; margin-bottom: 15px;",
                   icon("lock"), tags$strong(" Operation Mode: "), 
                   tags$span(mode_label, style = "background-color: #E95420; color: white; padding: 3px 10px; border-radius: 3px; font-weight: bold;"),
                   tags$span(" (Fixed in Demo Mode)", style = "color: #856404; font-style: italic; margin-left: 10px;")
               )
        )
      ),
      
      hr(style = "border-top: 1px dashed #ccc; margin-top: 5px; margin-bottom: 15px;"),
      
      # Dataset 1 & 2 Display
      fluidRow(
        column(6, 
               wellPanel(
                 style = "background-color: #fff8e1; border: 2px solid #E95420;",
                 h5(style = "color: forestgreen; font-weight: bold;", icon("bacterium"), " Dataset 1 (Demo)"),
                 div(style = "padding: 10px; background-color: #fff; border-radius: 5px; margin-top: 10px;",
                     if (is_mode_b) {
                       tagList(
                         tags$p(tags$strong("Taxa Table: "), demo_cfg$dataset1$taxa_table, style = "margin-bottom: 5px;"),
                         tags$p(tags$strong("Metadata: "), demo_cfg$dataset1$metadata, style = "margin-bottom: 5px;")
                       )
                     } else {
                       tagList(
                         tags$p(tags$strong("Job ID: "), demo_cfg$dataset1$job_id, style = "margin-bottom: 5px;"),
                         tags$p(tags$strong("Result Folder: "), demo_cfg$dataset1$result_folder, style = "margin-bottom: 5px;")
                       )
                     },
                     tags$p(tags$strong("Description: "), demo_cfg$dataset1$description, style = "margin-bottom: 0;")
                 )
               )
        ),
        column(6, 
               wellPanel(
                 style = "background-color: #fff8e1; border: 2px solid #E95420;",
                 h5(style = "color: steelblue; font-weight: bold;", icon("leaf"), " Dataset 2 (Demo)"),
                 div(style = "padding: 10px; background-color: #fff; border-radius: 5px; margin-top: 10px;",
                     if (is_mode_b) {
                       tagList(
                         tags$p(tags$strong("Taxa Table: "), demo_cfg$dataset2$taxa_table, style = "margin-bottom: 5px;"),
                         tags$p(tags$strong("Metadata: "), demo_cfg$dataset2$metadata, style = "margin-bottom: 5px;")
                       )
                     } else {
                       tagList(
                         tags$p(tags$strong("Job ID: "), demo_cfg$dataset2$job_id, style = "margin-bottom: 5px;"),
                         tags$p(tags$strong("Result Folder: "), demo_cfg$dataset2$result_folder, style = "margin-bottom: 5px;")
                       )
                     },
                     tags$p(tags$strong("Description: "), demo_cfg$dataset2$description, style = "margin-bottom: 0;")
                 )
               )
        )
      ),
      
      # Demo Parameters Display (Read-only)
      fluidRow(
        column(12,
               div(style = "background-color: #e8f5e9; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px; margin-top: 10px;",
                   h5(icon("sliders-h"), " Analysis Parameters (Demo)", style = "color: #155724; font-weight: bold; margin-top: 0; margin-bottom: 10px;"),
                   fluidRow(
                     if (is_mode_b) {
                       # Mode B parameters
                       tagList(
                         column(3, div(style = "text-align: center;",
                                       tags$strong("Taxa Levels"), tags$br(),
                                       tags$span("genus, species", style = "color: #155724;"))),
                         column(3, div(style = "text-align: center;",
                                       tags$strong("Min Proportion"), tags$br(),
                                       tags$span("0.0001", style = "color: #155724;"))),
                         column(3, div(style = "text-align: center;",
                                       tags$strong("Bac Min Prev"), tags$br(),
                                       tags$span("0.3", style = "color: #155724;"))),
                         column(3, div(style = "text-align: center;",
                                       tags$strong("Fun Min Prev"), tags$br(),
                                       tags$span("0.2", style = "color: #155724;")))
                       )
                     } else {
                       # Mode A parameters
                       tagList(
                         column(4, div(style = "text-align: center;",
                                       tags$strong("Taxa Levels"), tags$br(),
                                       tags$span("genus, species", style = "color: #155724;"))),
                         column(4, div(style = "text-align: center;",
                                       tags$strong("Dataset1 Min Prev"), tags$br(),
                                       tags$span("0.3", style = "color: #155724;"))),
                         column(4, div(style = "text-align: center;",
                                       tags$strong("Dataset2 Min Prev"), tags$br(),
                                       tags$span("0.3", style = "color: #155724;")))
                       )
                     }
                   )
               )
        )
      ),
      
      # Info message
      div(style = "color: #E95420; font-size: 0.9em; margin-top: 15px; text-align: center;",
          icon("info-circle"), " This is a demonstration. To run your own analysis, please switch to a different Job ID.")
    )
    
  } else {
    # Normal Mode: Show editable inputs
    tagList(
      # Input Mode Selection
      fluidRow(
        column(12,
               radioButtons("ck_input_mode", "Select Operation Mode:",
                            choices = c("Mode A: Run New Analysis (Use CoMeDA UUIDs)" = "uuid",
                                        "Mode B: Run New Analysis (Upload Files)" = "upload"),
                            inline = TRUE, width = "100%")
        )
      ),
      
      hr(style = "border-top: 1px dashed #ccc; margin-top: 5px; margin-bottom: 15px;"),
      
      # --- Mode A: UUID Inputs ---
      conditionalPanel(
        condition = "input.ck_input_mode == 'uuid'",
        fluidRow(
          column(6, 
                 wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                           h5(style="color:forestgreen; font-weight:bold;", icon("bacterium"), " Dataset 1 (e.g., Bacteria / pre-treatment)"),
                           textInput("ck_uuid_16s", "Job ID (UUID):", placeholder = "e.g., a1b2c3d4..."),
                           uiOutput("ck_valid_16s"),
                           selectInput("ck_res_16s", "Select Analysis Result Folder:", choices = NULL)
                 )
          ),
          column(6, 
                 wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                           h5(style="color:steelblue; font-weight:bold;", icon("leaf"), " Dataset 2 (e.g., Fungi / pro-treatment)"),
                           textInput("ck_uuid_its", "Job ID (UUID):", placeholder = "e.g., e5f6g7h8..."),
                           uiOutput("ck_valid_its"),
                           selectInput("ck_res_its", "Select Analysis Result Folder:", choices = NULL)
                 )
          )
        ),
        div(style = "color: #0c5460; background-color: #d1ecf1; padding: 10px; border-radius: 5px; font-size: 0.9em; margin-bottom: 15px;",
            icon("info-circle"), " Comparison columns will be automatically detected and matched between datasets.")
      ),
      
      # --- Mode B: File Uploads ---
      conditionalPanel(
        condition = "input.ck_input_mode == 'upload'",
        div(style = "background-color: #fff3cd; color: #856404; padding: 10px; border-radius: 5px; margin-bottom: 15px; font-size: 0.9em;",
            icon("exclamation-triangle"), 
            " Important: Sample names and Comparison(s) must be IDENTICAL across Dataset1 and Dataset2, and Sample names must be consistent between each dataset's Taxa Table and Metadata."
        ),
        fluidRow(
          column(6,
                 wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                           h5(style="color:forestgreen; font-weight:bold;", icon("bacterium"), " Dataset 1 (e.g., Bacteria / pre-treatment)"),
                           fileInput("ck_file_16s", "Taxa Table:", accept = ".txt"),
                           fileInput("ck_meta_16s", "Metadata:", accept = ".txt")
                 )
          ),
          column(6,
                 wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                           h5(style="color:steelblue; font-weight:bold;", icon("leaf"), " Dataset 2 (e.g., Fungi / pro-treatment)"),
                           fileInput("ck_file_its", "Taxa Table:", accept = ".txt"),
                           fileInput("ck_meta_its", "Metadata:", accept = ".txt")
                 )
          )
        ),
        fluidRow(column(12, uiOutput("ck_modeB_refs"))),
        actionButton("ck_format_guide", tagList(icon("circle-info"), "View File Format Guide"),
                     style = "color: #333; background-color: #e2e6ea; border-color: #dae0e5; margin-bottom: 10px;")
      )
    )
  }
})

# ==============================================================================
# Demo Dataset Selection Change Handler
# ==============================================================================
observeEvent(input$ck_demo_dataset_select, {
  # Only trigger reload if already in demo mode
  if (isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo") {
    # Check if selection actually changed
    current_key <- isolate(ck_values$current_demo_key)
    new_key <- input$ck_demo_dataset_select

    if (is.null(current_key) || current_key != new_key) {
      # Load new demo results (this will set auto_plot = TRUE)
      load_ck_demo_results()
    }
  }
}, ignoreInit = TRUE)

# ==============================================================================
# Change Job ID Button Logic
# ==============================================================================
observeEvent(input$ck_import_job_id, {
  job_status$trigger_source <- "cross_kingdom"
  if (job_status$demo_mode != 1) { job_status$new_id <- job_status$current_id }
  showModal(job_id_modal())
})

# ==============================================================================
# Helper Function: Generate parameters_info.txt (For new analysis)
# ==============================================================================
generate_parameters_info <- function(mode, params, output_path) {
  lines <- c(
    "================================================================================",
    "Cross-Dataset Correlation Analysis - Parameters Summary",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "================================================================================",
    "",
    "[Analysis Mode]",
    paste0("Mode: ", params$mode_label),
    ""
  )
  
  # Dataset 1 Info
  lines <- c(lines, "[Dataset 1]")
  for (key in names(params$dataset1)) {
    lines <- c(lines, paste0(key, ": ", params$dataset1[[key]]))
  }
  lines <- c(lines, "")
  
  # Dataset 2 Info
  lines <- c(lines, "[Dataset 2]")
  for (key in names(params$dataset2)) {
    lines <- c(lines, paste0(key, ": ", params$dataset2[[key]]))
  }
  lines <- c(lines, "")
  
  # Analysis Parameters
  lines <- c(lines, "[Analysis Parameters]")
  for (key in names(params$parameters)) {
    lines <- c(lines, paste0(key, ": ", params$parameters[[key]]))
  }
  lines <- c(lines, "")
  
  # Detection Info (placeholder - will be updated by R script)
  lines <- c(lines, "[Detection Info]")
  lines <- c(lines, "Analysis Type: (Determined after execution)")
  lines <- c(lines, "Overlapping Samples: (Determined after execution)")
  lines <- c(lines, "")
  
  lines <- c(lines, "================================================================================")
  
  writeLines(lines, file.path(output_path, "parameters_info.txt"))
}

# ==============================================================================
# 1. Job ID Validation (Mode A)
# ==============================================================================
validate_job_id <- function(uuid, output_id, select_id) {
  req(uuid); path <- paste0(comedainvpath, "/", uuid)
  if (dir.exists(path)) {
    output[[output_id]] <- renderUI({ tags$div(style = "color: #E95420; font-weight: bold; margin-bottom: 5px; font-size: 0.9em;", icon("check-circle"), " Job ID confirmed.") })
    analysis_path <- paste0(path, "/analysis")
    if (dir.exists(analysis_path)) {
      dirs <- list.dirs(analysis_path, full.names=F, recursive=F)
      results <- grep("^analysis_result_", dirs, value=T) %>% sort(decreasing=T)
      updateSelectInput(session, select_id, choices = results)
    } else { updateSelectInput(session, select_id, choices = c("No results found" = "")) }
  } else {
    output[[output_id]] <- renderUI({ tags$div(style = "color: firebrick; font-weight: bold; margin-bottom: 5px; font-size: 0.9em;", icon("times-circle"), " Job ID does not exist.") })
    updateSelectInput(session, select_id, choices = NULL)
  }
}
# New modified on 2025.12.18
observeEvent(input$ck_uuid_16s, {
  req(input$ck_uuid_16s)

  # Check if user manually entered "comedademo"
  if (tolower(trimws(input$ck_uuid_16s)) == "comedademo" && !isTRUE(ck_values$is_demo)) {
    showModal(modalDialog(
      title = tagList(icon("exclamation-triangle", style = "color: #E95420;"), " Demo Mode Job ID Detected"),
      tags$div(
        style = "padding: 10px; font-size: 14px;",
        tags$p("You have entered ", tags$strong("comedademo"), ", which is the reserved Job ID for demonstration purposes."),
        tags$hr(),
        tags$p(tags$strong("Please choose one of the following options:")),
        tags$ul(
          tags$li("Enter a ", tags$strong("different Job ID"), " to run your own analysis."),
          tags$li("Click the ", tags$span(style = "color: #E95420; font-weight: bold;", "\"Use the example data for demonstration\""),
                  " button to view the demo results.")
        )
      ),
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
    updateTextInput(session, "ck_uuid_16s", value = "")
    return()
  }

  # Only reset demo mode and validate if user manually changed the value (not from demo button)
  if (!isTRUE(ck_values$is_demo) || input$ck_uuid_16s != ck_demo_config$dataset1$job_id) {
    ck_values$is_demo <- FALSE
    validate_job_id(input$ck_uuid_16s, "ck_valid_16s", "ck_res_16s")
  }
})
observeEvent(input$ck_uuid_its, {
  req(input$ck_uuid_its)

  # Check if user manually entered "comedademo"
  if (tolower(trimws(input$ck_uuid_its)) == "comedademo" && !isTRUE(ck_values$is_demo)) {
    showModal(modalDialog(
      title = tagList(icon("exclamation-triangle", style = "color: #E95420;"), " Demo Mode Job ID Detected"),
      tags$div(
        style = "padding: 10px; font-size: 14px;",
        tags$p("You have entered ", tags$strong("comedademo"), ", which is the reserved Job ID for demonstration purposes."),
        tags$hr(),
        tags$p(tags$strong("Please choose one of the following options:")),
        tags$ul(
          tags$li("Enter a ", tags$strong("different Job ID"), " to run your own analysis."),
          tags$li("Click the ", tags$span(style = "color: #E95420; font-weight: bold;", "\"Use the example data for demonstration\""),
                  " button to view the demo results.")
        )
      ),
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
    updateTextInput(session, "ck_uuid_its", value = "")
    return()
  }

  # Only reset demo mode and validate if user manually changed the value (not from demo button)
  if (!isTRUE(ck_values$is_demo) || input$ck_uuid_its != ck_demo_config$dataset2$job_id) {
    ck_values$is_demo <- FALSE
    validate_job_id(input$ck_uuid_its, "ck_valid_its", "ck_res_its")
  }
})

# ==============================================================================
# 2. Mode B: Dynamic Reference
# ==============================================================================
observe({
  req(input$ck_meta_16s, input$ck_meta_its)
  ck_values$is_demo <- FALSE  # User is uploading files, not demo
  tryCatch({
    df_16s <- read.table(input$ck_meta_16s$datapath, header=T, sep="\t", comment.char="", stringsAsFactors=F)
    df_its <- read.table(input$ck_meta_its$datapath, header=T, sep="\t", comment.char="", stringsAsFactors=F)
    cols_16s <- grep("comparison", colnames(df_16s), value=T, ignore.case=T)
    cols_its <- grep("comparison", colnames(df_its), value=T, ignore.case=T)
    common_cols <- intersect(cols_16s, cols_its)
    if(length(common_cols) > 0) {
      ck_values$modeB_cols <- common_cols
      output$ck_modeB_refs <- renderUI({
        lapply(common_cols, function(col) {
          vals <- intersect(df_16s[[col]], df_its[[col]])
          div(style="display:inline-block; width:32%; margin-right:1%; vertical-align:top;",
              selectInput(paste0("ck_ref_", col), label=paste0("Baseline for ", col, ":"), choices=vals))
        })
      })
    } else {
      ck_values$modeB_cols <- NULL
      output$ck_modeB_refs <- renderUI({ div(style="color:red;", "No overlapping 'comparison' columns found.") })
    }
  }, error=function(e) warning(e))
})

# ==============================================================================
# 3. Defaults & Guide
# ==============================================================================
observeEvent(input$ck_input_mode, {
  if (input$ck_input_mode == "uuid") updateSelectInput(session, "ck_taxalevel_a", selected = c("genus", "species"))
  else if (input$ck_input_mode == "upload") updateSelectInput(session, "ck_taxalevel_b", selected = "genus")
})

observeEvent(input$ck_format_guide, {
  showModal(modalDialog(
    title = tagList(icon("info-circle"), " File Format Guide"),
    tags$div(
      style = "text-align: center; padding: 10px;",
      tags$img(
	src = "file_info_crosskingdom.png",
	alt = "Format Guide",
	style = "max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);"
      )      
    ),
    size = "l", easyClose = TRUE, footer = modalButton("Close")
  ))
})

# ==============================================================================
# 4. Core Analysis Logic
# ==============================================================================
run_cross_kingdom_pipeline <- function(mode) {
  
  # Demo Mode Protection
  if (isTRUE(ck_values$is_demo) || identical(job_status$current_id, "comedademo")) {
    showModal(modalDialog(
      title = tagList(icon("ban", style="color: #d9534f;"), " Action Not Permitted"),
      tags$div(
        style = "padding: 10px; font-size: 15px; color: #333;",
        tags$p("You are currently viewing the ", tags$strong("Demo Mode"), "."),
        tags$p("You cannot submit a new analysis in Demo Mode."),
        tags$hr(),
        tags$p(tags$strong("To run your own analysis:")),
        tags$ul(
          tags$li("Please switch to a ", tags$strong("New Job ID"), " using the 'Change to the current / other job id' button."),
          tags$li("Or refresh the page.")
        )
      ),
      easyClose = TRUE, footer = modalButton("Close")
    ))
    return()
  }
  
  req(job_status$current_id)
  ck_values$is_demo <- FALSE  # Running new analysis
  
  if (mode == "uuid") {
    req(input$ck_uuid_16s, input$ck_uuid_its, input$ck_res_16s, input$ck_res_its)
    taxa_levels <- input$ck_taxalevel_a; prev_bac <- input$ck_prev_bac_a; prev_fun <- input$ck_prev_fun_a; min_prop <- NULL
  } else {
    req(input$ck_file_16s, input$ck_meta_16s, input$ck_file_its, input$ck_meta_its)
    taxa_levels <- input$ck_taxalevel_b; prev_bac <- input$ck_prev_bac_b; prev_fun <- input$ck_prev_fun_b; min_prop <- input$ck_min_prop
  }
  
  if (length(taxa_levels) == 0) { showNotification("Select at least one Taxa Level.", type="error"); return() }
  
  project_dir <- paste0(comedainvpath, "/", job_status$current_id)
  ck_dir <- paste0(project_dir, "/cross_kingdom")
  if(!dir.exists(ck_dir)) dir.create(ck_dir, recursive=T)
  
  levels_str <- paste(taxa_levels, collapse=",")
  comp_info_path <- paste0(ck_dir, "/auto_comp_info.txt")
  
  w <- Waiter$new(html=tagList(spin_clock(), h2("Running Analysis..."), h4("Please wait.")), color="rgba(0,0,0,0.4)")
  w$show()
  
  tryCatch({
    script_6_1 <- paste0(comedashinypath, "/script/6.1_crossdomaincorrelation_wReport.r")
    
    # Prepare parameters info structure
    params_info <- list(
      mode_label = if(mode == "uuid") "A (CoMeDA UUID)" else "B (File Upload)",
      dataset1 = list(),
      dataset2 = list(),
      parameters = list(
        "Taxa Levels" = levels_str,
        "Dataset1 Min Prevalence" = prev_bac,
        "Dataset2 Min Prevalence" = prev_fun
      )
    )
    
    if (mode == "uuid") {
      # === Mode A ===
      rdata_16s <- paste0(comedainvpath, "/", input$ck_uuid_16s, "/analysis/", input$ck_res_16s, "/CoMeDA.Rdata")
      rdata_its <- paste0(comedainvpath, "/", input$ck_uuid_its, "/analysis/", input$ck_res_its, "/CoMeDA.Rdata")
      comp_file_16s <- paste0(comedainvpath, "/", input$ck_uuid_16s, "/analysis/", input$ck_res_16s, "/compinfotable.txt")
      comp_file_its <- paste0(comedainvpath, "/", input$ck_uuid_its, "/analysis/", input$ck_res_its, "/compinfotable.txt")
      
      if(!file.exists(rdata_16s) || !file.exists(rdata_its) || !file.exists(comp_file_16s)) stop("Files missing.")
      
      info_16s <- read.table(comp_file_16s, header=T, sep="\t", check.names=F)
      info_its <- read.table(comp_file_its, header=T, sep="\t", check.names=F)
      common <- intersect(colnames(info_16s), colnames(info_its))
      if(length(common) == 0) stop("No common comparison columns.")
      
      write.table(info_16s[, common, drop=F], comp_info_path, sep="\t", row.names=F, quote=F)
      
      # Store Mode A dataset info
      params_info$dataset1 <- list("Job ID" = input$ck_uuid_16s, "Analysis Result" = input$ck_res_16s)
      params_info$dataset2 <- list("Job ID" = input$ck_uuid_its, "Analysis Result" = input$ck_res_its)
      
      # Generate initial parameters_info.txt
      generate_parameters_info(mode, params_info, ck_dir)
      
      system2("Rscript", args = c(script_6_1, paste0(comedashinypath, "/script"), rdata_16s, rdata_its, levels_str, prev_bac, prev_fun, comp_info_path, ck_dir))
      
    } else {
      # === Mode B ===
      raw_dir <- paste0(ck_dir, "/raw_inputs"); if(!dir.exists(raw_dir)) dir.create(raw_dir)
      f_16s_tab <- file.path(raw_dir, "16s_taxa.txt"); file.copy(input$ck_file_16s$datapath, f_16s_tab, overwrite=T)
      f_16s_meta <- file.path(raw_dir, "16s_meta.txt"); file.copy(input$ck_meta_16s$datapath, f_16s_meta, overwrite=T)
      f_its_tab <- file.path(raw_dir, "its_taxa.txt"); file.copy(input$ck_file_its$datapath, f_its_tab, overwrite=T)
      f_its_meta <- file.path(raw_dir, "its_meta.txt"); file.copy(input$ck_meta_its$datapath, f_its_meta, overwrite=T)
      
      cols <- ck_values$modeB_cols
      refs <- sapply(cols, function(col) input[[paste0("ck_ref_", col)]])
      comp_df <- data.frame(refs, stringsAsFactors=F) %>% t %>% as.data.frame
      colnames(comp_df) <- cols
      write.table(comp_df, comp_info_path, sep="\t", row.names=F, quote=F)
      
      # Store Mode B dataset info
      params_info$dataset1 <- list("Taxa Table" = input$ck_file_16s$name, "Metadata" = input$ck_meta_16s$name)
      params_info$dataset2 <- list("Taxa Table" = input$ck_file_its$name, "Metadata" = input$ck_meta_its$name)
      params_info$parameters[["Min Proportion"]] <- min_prop
      
      generate_parameters_info(mode, params_info, ck_dir)
      
      script_6_2 <- paste0(comedashinypath, "/script/6.2_crossdomaincorrealtion_wTaxatable.sh")
      res <- system2("bash", args = c(script_6_2, ck_dir, f_16s_tab, f_16s_meta, f_its_tab, f_its_meta, comp_info_path, levels_str, prev_bac, prev_fun, min_prop))
      if(res != 0) stop("Script 6.2 failed.")
      
      batch_file <- paste0(ck_dir, "/batch_methods.txt")
      if(file.exists(batch_file)) {
        lines <- readLines(batch_file)
        if(length(lines) > 0) params_info$parameters[["Batch Correction"]] <- paste(lines, collapse="; ")

	param_info_file <- file.path(ck_dir, "parameters_info.txt")
	if (file.exists(param_info_file)) {
          existing_lines <- readLines(param_info_file, warn = FALSE)
          updated_lines <- c()
          for (i in seq_along(existing_lines)) {
	    updated_lines <- c(updated_lines, existing_lines[i])
            if (grepl("^Min Proportion:", existing_lines[i])) {
	      updated_lines <- c(updated_lines, paste0("Batch Correction: ", paste(lines, collapse="; ")))	    
	    }	  
	  }
          writeLines(updated_lines, param_info_file)	  
	}
      }
    }
    
    # Analysis finished, set flag
    ck_values$output_path <- ck_dir
    ck_values$analysis_finished <- TRUE
    ck_values$auto_plot <- TRUE
    
    # Reload Results to update UI
    # We trigger the observer by "pretending" current_id changed, or just reload directly
    # Direct reload is safer here to ensure immediate UI update
    if(file.exists(paste0(ck_dir, "/crossdomain.Rdata"))) {
      e <- new.env(); load(paste0(ck_dir, "/crossdomain.Rdata"), envir=e)
      ck_values$result_data <- e$crossdomain.corr.res
      
      lvl <- names(ck_values$result_data)[1]
      updateSelectInput(session, "ck_plot_level", choices=names(ck_values$result_data), selected=lvl)
      if(!is.null(ck_values$result_data[[lvl]])) {
        comps <- names(ck_values$result_data[[lvl]])
        updateSelectInput(session, "ck_plot_comp", choices=comps, selected=comps[1])
      }
      
      # Load Updated Info
      param_info_file <- paste0(ck_dir, "/parameters_info.txt")
      if (file.exists(param_info_file)) {
        ck_values$summary_params <- parse_parameters_info(param_info_file)
      }
    }
    w$hide(); showNotification("Success!", type="message")
    
  }, error=function(e) { w$hide(); showNotification(paste("Error:", e$message), type="error", duration=10) })
}

observeEvent(input$ck_run_analysis_a, { run_cross_kingdom_pipeline("uuid") })
observeEvent(input$ck_run_analysis_b, { run_cross_kingdom_pipeline("upload") })


# ==============================================================================
# 5. Summary UI (Enhanced Card-Based Layout)
# ==============================================================================
output$ck_param_summary_ui <- renderUI({
  req(ck_values$analysis_finished, ck_values$summary_params)
  
  params <- ck_values$summary_params
  
  # Mode Card
  mode_label <- if (!is.null(params$mode)) params$mode else "Unknown"
  
  # Dataset 1 Card
  ds1_items <- if (length(params$dataset1) > 0) {
    lapply(names(params$dataset1), function(k) { tags$li(tags$strong(paste0(k, ": ")), params$dataset1[[k]]) })
  } else { list(tags$li(tags$em("No information available"))) }
  
  # Dataset 2 Card
  ds2_items <- if (length(params$dataset2) > 0) {
    lapply(names(params$dataset2), function(k) { tags$li(tags$strong(paste0(k, ": ")), params$dataset2[[k]]) })
  } else { list(tags$li(tags$em("No information available"))) }
  
  # Parameters Card
  param_items <- if (length(params$parameters) > 0) {
    lapply(names(params$parameters), function(k) { tags$li(tags$strong(paste0(k, ": ")), params$parameters[[k]]) })
  } else { list(tags$li(tags$em("No parameters recorded"))) }
  
  # Detection Info Card
  detection_mode <- if (!is.null(params$detection$`Analysis Type`)) params$detection$`Analysis Type` else "Unknown"
  overlapping_samples <- if (!is.null(params$detection$`Overlapping Samples`)) params$detection$`Overlapping Samples` else "N/A"
  
  wellPanel(
    style = "background-color: #e8f5e9; border: 2px solid #4caf50; padding: 20px;",
    h4(icon("clipboard-check"), "2. Analysis Parameters Summary", style = "color:#155724; font-weight:bold; margin-bottom: 15px;"),
    fluidRow(
      column(12,
             div(style = "background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 5px; padding: 10px; margin-bottom: 15px;",
                 tags$span(icon("cogs"), tags$strong(" Analysis Mode: "), 
                           tags$span(mode_label, style = "background-color: #28a745; color: white; padding: 3px 10px; border-radius: 3px; font-weight: bold;"))
             )
      )
    ),
    fluidRow(
      column(6, div(style = "background-color: #fff; border: 1px solid #ddd; border-left: 4px solid forestgreen; border-radius: 5px; padding: 15px; margin-bottom: 10px; min-height: 120px;", h5(icon("bacterium", style="color:forestgreen;"), " Dataset 1", style="color:forestgreen; font-weight:bold; margin-top:0;"), tags$ul(style="list-style:none; padding-left:5px; margin-bottom:0;", ds1_items))),
      column(6, div(style = "background-color: #fff; border: 1px solid #ddd; border-left: 4px solid steelblue; border-radius: 5px; padding: 15px; margin-bottom: 10px; min-height: 120px;", h5(icon("leaf", style="color:steelblue;"), " Dataset 2", style="color:steelblue; font-weight:bold; margin-top:0;"), tags$ul(style="list-style:none; padding-left:5px; margin-bottom:0;", ds2_items)))
    ),
    fluidRow(
      column(6, div(style = "background-color: #fff; border: 1px solid #ddd; border-left: 4px solid #6c757d; border-radius: 5px; padding: 15px; min-height: 100px;", h5(icon("sliders-h", style="color:#6c757d;"), " Parameters", style="color:#6c757d; font-weight:bold; margin-top:0;"), tags$ul(style="list-style:none; padding-left:5px; margin-bottom:0;", param_items))),
      column(6, div(style = "background-color: #fff; border: 1px solid #ddd; border-left: 4px solid #E95420; border-radius: 5px; padding: 15px; min-height: 100px;", h5(icon("search", style="color:#E95420;"), " Detection Info", style="color:#E95420; font-weight:bold; margin-top:0;"), tags$ul(style="list-style:none; padding-left:5px; margin-bottom:0;", tags$li(tags$strong("Analysis Type: "), detection_mode), tags$li(tags$strong("Overlapping Samples: "), overlapping_samples))))
    )
  )
})

# ==============================================================================
# 6. Plotting Logic (Auto-trigger & Isolation)
# ==============================================================================
output$ck_analysis_finished <- reactive({ ck_values$analysis_finished })
outputOptions(output, "ck_analysis_finished", suspendWhenHidden=F)

# Updates
observeEvent(input$ck_plot_level, {
  req(ck_values$result_data, input$ck_plot_level); lvl <- input$ck_plot_level
  if(!is.null(ck_values$result_data[[lvl]])) updateSelectInput(session, "ck_plot_comp", choices=names(ck_values$result_data[[lvl]]))
})
observeEvent(input$ck_plot_comp, {
  req(ck_values$result_data, input$ck_plot_level, input$ck_plot_comp)
  lvl <- input$ck_plot_level; comp <- input$ck_plot_comp
  if(!is.null(ck_values$result_data[[lvl]][[comp]])) {
    evts <- names(ck_values$result_data[[lvl]][[comp]])

    # [NEW] Reorder events: put ref_group first (for proper facet ordering)
    # Try to get ref_group from the first available event's metadata
    ref_group <- NULL
    for (e in evts) {
      if (!is.null(ck_values$result_data[[lvl]][[comp]][[e]]$metadata$ref_group)) {
        ref_group <- ck_values$result_data[[lvl]][[comp]][[e]]$metadata$ref_group
        break
      }
    }
    
    if (!is.null(ref_group) && ref_group %in% evts) {
      other_evts <- setdiff(evts, ref_group)
      evts <- c(ref_group, sort(other_evts))
    }

    updateSelectInput(session, "ck_plot_event", choices=evts, selected=evts)

    if (isTRUE(ck_values$auto_plot)) {
      shinyjs::delay(100, {
        ck_values$plot_trigger <- ck_values$plot_trigger + 1
        ck_values$auto_plot <- FALSE	
      })	    
    }
  }
})
# Update Focal Taxa based on filtered results (p-value, correlation, Top N)
observeEvent(c(input$ck_plot_event, input$ck_plot_pcut, input$ck_plot_corrcut, input$ck_plot_topn, input$ck_plot_ptype), {
  req(ck_values$result_data, input$ck_plot_level, input$ck_plot_comp, input$ck_plot_event)

  lvl <- input$ck_plot_level
  comp <- input$ck_plot_comp
  events <- input$ck_plot_event
  pcut <- input$ck_plot_pcut
  corrcut <- input$ck_plot_corrcut
  topn <- input$ck_plot_topn
  pfield <- if (isTRUE(input$ck_plot_ptype == "adjusted")) "p.value" else "raw.p.value"
  
  # Collect taxa and their degree (number of significant edges)
  taxa_degree <- list()
  
  for (evt in events) {
    if (is.null(ck_values$result_data[[lvl]][[comp]][[evt]])) next
    
    cor_mat <- ck_values$result_data[[lvl]][[comp]][[evt]]$correlationTable
    pval_mat <- ck_values$result_data[[lvl]][[comp]][[evt]][[pfield]]
    if (is.null(pval_mat)) pval_mat <- ck_values$result_data[[lvl]][[comp]][[evt]]$p.value  # fallback: older results lack raw.p.value
    
    # Filter edges by p-value and correlation thresholds
    sig_mask <- (pval_mat < pcut) & (abs(cor_mat) >= corrcut)
    sig_mask[is.na(sig_mask)] <- FALSE
    diag(sig_mask) <- FALSE  # Exclude self-loops
    
    # Count edges for each taxon (degree)
    edge_counts <- rowSums(sig_mask, na.rm = TRUE)
    
    # Accumulate degree across events
    for (taxon in names(edge_counts)) {
      if (edge_counts[taxon] > 0) {
        if (is.null(taxa_degree[[taxon]])) {
          taxa_degree[[taxon]] <- edge_counts[taxon]
        } else {
          taxa_degree[[taxon]] <- taxa_degree[[taxon]] + edge_counts[taxon]
        }
      }
    }
  }
  
  # Convert to data frame and sort by degree
  if (length(taxa_degree) > 0) {
    degree_df <- data.frame(
      taxon = names(taxa_degree),
      degree = unlist(taxa_degree),
      stringsAsFactors = FALSE
    )
    degree_df <- degree_df[order(-degree_df$degree), ]
    
    # Apply Top N filter
    if (!is.null(topn) && is.numeric(topn) && topn > 0 && nrow(degree_df) > topn) {
      degree_df <- degree_df[1:topn, ]
    }
    
    valid_taxa <- degree_df$taxon
  } else {
    valid_taxa <- character(0)
  }
  
  # Preserve current selection if still valid
  current_focal <- isolate(input$ck_plot_focal)
  new_selected <- if (!is.null(current_focal) && current_focal %in% valid_taxa) current_focal else ""
  
  updateSelectizeInput(session, "ck_plot_focal", 
                       choices = c("None" = "", valid_taxa), 
                       selected = new_selected, 
                       server = TRUE)
})

# Auto-plot Trigger
observe({
  req(ck_values$auto_plot, ck_values$result_data)
  req(input$ck_plot_level, input$ck_plot_comp, input$ck_plot_event)
  
  lvl <- input$ck_plot_level
  comp <- input$ck_plot_comp
  
  if (!is.null(ck_values$result_data[[lvl]][[comp]])) {
    ck_values$plot_trigger <- ck_values$plot_trigger + 1
    ck_values$auto_plot <- FALSE
  }
})

# Manual Update Trigger
observeEvent(input$ck_update_plot, {
  ck_values$plot_trigger <- ck_values$plot_trigger + 1
})

output$ck_network_plot <- renderGirafe({
  req(ck_values$plot_trigger > 0)
  
  isolate({
    req(ck_values$result_data, input$ck_plot_event)
    
    w_ck_net$show()
    on.exit(w_ck_net$hide())  # 確保 waiter 關閉
    
    lvl <- input$ck_plot_level
    comp <- input$ck_plot_comp
    evts <- input$ck_plot_event
    
    # 儲存當前參數
    ck_values$current_plot_params <- list(
      lvl = lvl, comp = comp, evt = evts, 
      p = input$ck_plot_pcut, corr = input$ck_plot_corrcut,
      ptype = input$ck_plot_ptype,
      layout = input$ck_plot_layout, labels = input$ck_plot_labels,
      focal = input$ck_plot_focal, topn = input$ck_plot_topn,
      unified = input$ck_plot_unified
    )
    
    # 使用 tryCatch 處理可能的錯誤
    p <- tryCatch({
      plot_interactive_networks(
        corr_res = ck_values$result_data, 
        taxalevel = lvl, 
        compcol = comp, 
        compevent = evts, 
        pcut = input$ck_plot_pcut,
        corrcut = input$ck_plot_corrcut,
        ptype = input$ck_plot_ptype,
        layout_type = input$ck_plot_layout,
        show_labels = input$ck_plot_labels,
        hubdegree = 12,
        focal_taxon = if(input$ck_plot_focal == "") NULL else input$ck_plot_focal,
        toptaxa = input$ck_plot_topn,
        unified_layout = input$ck_plot_unified,
        analysis_type = "cross_domain"
      )
    }, error = function(e) {
      # 如果有定義 plot_error_message，使用它；否則回傳 NULL
      if (exists("plot_error_message", mode = "function")) {
        plot_error_message(e$message)
      } else {
        NULL
      }
    })
    
    # 在呼叫 girafe 前檢查 p 是否為 NULL
    if (is.null(p)) return(NULL)
    
    girafe(
      ggobj = p, 
      width_svg = 18, 
      height_svg = 10, 
      options = list(
        opts_tooltip(opacity = 0.8), 
        opts_toolbar(saveaspng = FALSE), 
        opts_zoom(max = 5)
      )
    )
  })
})

# Define Waiter for Download (Full screen)
w_ck_download <- Waiter$new(
  html = tagList(
    spin_clock(),
    h4("Downloading results ...", style = "color: dimgrey; margin-top: 15px;")
  ),
  color = "rgba(255, 255, 255, 0.8)"
)

output$ck_download_btn_ui <- renderUI({
  if (isTRUE(ck_values$is_demo) && job_status$current_id == "comedademo") {
    # Demo Mode: Download all demo datasets
    downloadButton(
      "ck_download_demo_all",
      label = tagList(" Download All Demos"),
      style = "color: #fff; background-color: #28a745; border-color: #28a745; width: 100%; font-weight: bold;"
    )
  } else {
    # Normal Mode: Download current analysis
    downloadButton(
      "ck_download_zip",
      label = tagList(" Download (ZIP)"),
      style = "color: #333; background-color: #fff; border-color: #ccc; width: 100%;"
    )
  }
})

# ==============================================================================
# Demo Mode Download Handler (Download Both Demo Datasets)
# ==============================================================================
output$ck_download_demo_all <- downloadHandler(
  filename = function() {
    "CoMeDA_CrossDataset_Demo_Results.zip"
  },
  content = function(file) {
    
    w <- Waiter$new(html = tagList(spin_clock(), h4("Preparing Demo Download...")), color = "rgba(0,0,0,0.4)")
    w$show()
    on.exit(w$hide())
    file.copy("/nfs/CoMeDA/projects_v2/comedademo/CoMeDA_CrossDataset_Demo_Results.zip", file)
  }
)

output$ck_download_zip <- downloadHandler(
  filename = function() { paste0("CrossDataset_Network_", format(Sys.time(), "%Y%m%d_%H%M"), ".zip") },
  content = function(file) {
    # Show full-screen waiter
    w_ck_download$show()
    on.exit(w_ck_download$hide())
    
    req(ck_values$result_data, ck_values$current_plot_params)
    temp_dir <- tempdir()
    params <- ck_values$current_plot_params
    
    # Generate static plot
    p_static <- plot_interactive_networks(
      corr_res = ck_values$result_data, 
      taxalevel = params$lvl, 
      compcol = params$comp, 
      compevent = params$evt, 
      pcut = params$p,
      corrcut = params$corr,
      ptype = if(is.null(params$ptype)) "raw" else params$ptype,
      layout_type = params$layout,
      show_labels = params$labels,
      hubdegree = 12,
      focal_taxon = if(params$focal == "") NULL else params$focal,
      toptaxa = params$topn,
      unified_layout = params$unified,
      analysis_type = "cross_domain"
    )
    
    # Save PDF
    plot_file_pdf <- file.path(temp_dir, "Network_Plot.pdf")
    ggsave(plot_file_pdf, plot = p_static, width = 18, height = 10, device = "pdf")
    
    # Save PNG (high resolution)
    plot_file_png <- file.path(temp_dir, "Network_Plot.png")
    ggsave(plot_file_png, plot = p_static, width = 18, height = 10, dpi = 300, device = "png")
    
    files_to_zip <- c(plot_file_pdf, plot_file_png)
    
    # Generate correlation tables for each event
    for(evt in params$evt) {
      res <- ck_values$result_data[[params$lvl]][[params$comp]][[evt]]
      if(!is.null(res)) {
        ft <- merge(
          reshape2::melt(res$correlationTable), 
          reshape2::melt(res$p.value), 
          by = c("Var1", "Var2")
        ) %>% 
          setNames(c("Taxon1", "Taxon2", "Correlation", "P_value")) %>% 
          dplyr::filter(Correlation != 0 & !is.na(Correlation)) %>% 
          dplyr::arrange(desc(abs(Correlation)))
        
        tf <- file.path(temp_dir, paste0("Correlation_Table_", evt, ".txt"))
        write.table(ft, tf, sep = "\t", quote = FALSE, row.names = FALSE)
        files_to_zip <- c(files_to_zip, tf)
      }
    }
    
    # [NEW] Include parameters_info.txt in download
    if (!is.null(ck_values$output_path)) {
      param_file <- file.path(ck_values$output_path, "parameters_info.txt")
      if (file.exists(param_file)) {
        files_to_zip <- c(files_to_zip, param_file)
      }
    }
    
    zip(file, files = files_to_zip, flags = "-j")
  }
)

# Focal Taxon Info Modal (Correlation Network)
observeEvent(input$ck_focal_taxon_info, {
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

