## server_analysis_resultoverview.R
## CoMeDA v2.2 - Step B: Result Overview Server Logic
## Updated: 2025-12-15 (Added Taxa Level selector for Batch Correction plot)

w_overview_full <- Waiter$new(
  html = tagList(
    spin_clock(), 
    h3("Loading Analysis Results...", style = "color: white; font-weight: bold; margin-top: 15px;"),
    h5("Reading RData and Parameters...", style = "color: #eee;")
  ),
  color = "rgba(0, 0, 0, 0.8)"
)

# [NEW] Waiter for Batch Correction Plot (with PERMANOVA calculation)
w_batch_plot <- Waiter$new(
  id = "overview_batch_combined_plot",
  html = tagList(
    spin_clock(),
    h4("Generating PCoA plots...", style = "color: white; font-weight: bold; margin-top: 15px;"),
    h5("Calculating PERMANOVA statistics...", style = "color: #eee;")
  ),
  color = "rgba(0, 0, 0, 0.7)"
)

# ^=============================================================================
# Section 1: Data Loading & Helper Logic
# ==============================================================================

# 1.0 Helper: Get Result Folders
get_result_folders <- function() {
  req(job_status$current_id)
  project_path <- paste0(comedainvpath, "/", job_status$current_id)
  analysis_dir <- paste0(project_path, "/analysis")
  if (!dir.exists(analysis_dir)) return(character(0))
  dirs <- list.dirs(analysis_dir, full.names = FALSE, recursive = FALSE)
  results <- grep("^analysis_result_", dirs, value = TRUE)
  return(sort(results, decreasing = TRUE))
}

# 1.1 Reactive: Check if results exist
has_results <- reactive({
  job_status$results_version
  results <- get_result_folders()
  return(length(results) > 0)
})

# 1.1.1 Track previous job ID to detect job switches
prev_job_id <- reactiveVal(NULL)

# 1.2 Populate Dropdown
observeEvent(job_status$results_version, {

  current_job <- job_status$current_id
  req(current_job)

  previous_job <- isolate(prev_job_id())
  job_switched <- !is.null(previous_job) && previous_job != current_job
  prev_job_id(current_job)

  results <- get_result_folders()

  if (length(results) == 0) {
    session$onFlushed(function() {
      updateSelectInput(session, "selected_analysis_result",
                        choices = c("No results found" = ""),
                        selected = "")
    }, once = TRUE)
    return()
  }

  current_selection <- isolate(input$selected_analysis_result)
  new_selection <- if (job_switched ||
                       is.null(current_selection) ||
                       !(current_selection %in% results)) {
    results[1]
  } else {
    current_selection
  }

  session$onFlushed(function() {
    updateSelectInput(session, "selected_analysis_result",
                      choices = results,
                      selected = new_selection)
  }, once = TRUE)

}, ignoreInit = FALSE)

observeEvent({list(input$selected_analysis_result, job_status$results_version)}, {
  req(input$selected_analysis_result)
  if (input$selected_analysis_result != "" && input$selected_analysis_result != "No results found") {
    w_overview_full$show()
    
    # Optional: Small delay to ensure UI thread renders the waiter before heavy lifting
    # (Not strictly necessary if downstream calculations are heavy enough)
    # Sys.sleep(0.5) 
    
    # Hide waiter is handled by the UI rendering completion or explicit hide
    # Since reactive expressions are lazy, we hide it after a short delay or when UI is ready
    shinyjs::delay(1000, w_overview_full$hide())
  }
}, priority = 1000) # High priority to run first

# 1.3 Helper: Load Parameters (Section 1 Only - Used for Input Data Panel)
current_params <- reactive({
  job_status$results_version
  req(input$selected_analysis_result, job_status$current_id)
  
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return(NULL)
  
  param_file <- paste0(comedainvpath, "/", job_status$current_id, "/analysis/", input$selected_analysis_result, "/parameters_info.txt")
  if (!file.exists(param_file)) return(NULL)
  
  tryCatch({
    lines <- readLines(param_file, warn = FALSE)
    sec2_idx <- grep("\\[SECTION 2", lines)
    if (length(sec2_idx) > 0) {
      lines_sec1 <- lines[1:(sec2_idx[1] - 1)]
    } else {
      lines_sec1 <- lines
    }
    lines_sec1 <- lines_sec1[!grepl("^#", lines_sec1) & trimws(lines_sec1) != ""]
    if (length(lines_sec1) == 0) return(NULL)
    
    df <- read.table(text = paste(lines_sec1, collapse = "\n"), sep = "\t", header = TRUE, stringsAsFactors = FALSE, fill = TRUE)
    
    if (ncol(df) >= 2 && "parameter" %in% colnames(df) && "value" %in% colnames(df)) {
      stats::setNames(as.list(df$value), df$parameter)
    } else {
      NULL
    }
  }, error = function(e) { NULL })
})

# 1.4 Helper: Load Adjustments (Section 2 Only)
current_adjustments <- reactive({
  job_status$results_version
  req(input$selected_analysis_result, job_status$current_id)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return(NULL)
  
  param_file <- paste0(comedainvpath, "/", job_status$current_id, "/analysis/", input$selected_analysis_result, "/parameters_info.txt")
  if (!file.exists(param_file)) return(NULL)
  
  tryCatch({
    lines <- readLines(param_file, warn = FALSE)
    start_idx <- grep("\\[SECTION 2", lines)
    if (length(start_idx) == 0) return(NULL)
    
    end_idx <- grep("\\[SECTION 3", lines)
    if (length(end_idx) > 0) {
      raw_lines <- lines[(start_idx[1] + 1):(end_idx[1] - 1)]
    } else {
      raw_lines <- lines[(start_idx[1] + 1):length(lines)]
    }
    
    clean_lines <- raw_lines[!grepl("^#", raw_lines) & trimws(raw_lines) != ""]
    if (length(clean_lines) < 2) return(NULL) 
    
    df <- read.table(text = paste(clean_lines, collapse = "\n"), header = TRUE, sep = "\t", stringsAsFactors = FALSE, fill = TRUE)
    if (nrow(df) > 0 && "parameter" %in% colnames(df)) {
      df <- df[!is.na(df$parameter) & df$parameter != "" & df$parameter != "parameter", , drop = FALSE]
    }
    if (nrow(df) == 0) return(NULL)
    return(df)
  }, error = function(e) { NULL })
})

# [MODIFIED] 1.5 NEW all_params: Section 1 + Section 2 (Section 2 overrides Section 1)
all_params <- reactive({
  job_status$results_version
  req(input$selected_analysis_result, job_status$current_id)
  
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return(NULL)
  
  # 1. Get Base Parameters (Section 1)
  base_params <- current_params()
  if (is.null(base_params)) base_params <- list()
  
  # 2. Get Adjustments (Section 2)
  adjustments_df <- current_adjustments()
  
  # 3. Merge: If adjustment exists, override base param
  final_params <- base_params
  
  if (!is.null(adjustments_df) && nrow(adjustments_df) > 0) {
    for (i in 1:nrow(adjustments_df)) {
      key <- adjustments_df$parameter[i]
      new_val <- adjustments_df$adjusted_value[i]
      
      if (!is.na(key) && key != "") {
        final_params[[key]] <- new_val
      }
    }
  }
  
  return(final_params)
})

# 1.6 Helper: Load R Data
current_rdata <- reactive({
  job_status$results_version
  req(input$selected_analysis_result, job_status$current_id)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return(NULL)
  
  rdata_path <- paste0(comedainvpath, "/", job_status$current_id, "/analysis/", input$selected_analysis_result, "/CoMeDA.Rdata")
  if (!file.exists(rdata_path)) return(NULL)
  
  env <- new.env()
  tryCatch({ 
    load(rdata_path, envir = env)
    return(env) 
  }, error = function(e) { return(NULL) })
})

# [MODIFIED] 1.7 comparereflist: Parse comparison_info from all_params (Simple Dictionary)
comparereflist <- reactive({
  params <- all_params()
  if (is.null(params)) return(list())

  # 1. Check comparison_info
  comp_info_str <- params$comparison_info

  if (!is.null(comp_info_str) && comp_info_str != "" && comp_info_str != "NA") {
    tryCatch({
      # Parse "treatment=Control;group=Healthy"
      pairs <- strsplit(comp_info_str, ";")[[1]]
      if (length(pairs) == 0) return(list())

      result_list <- lapply(pairs, function(pair) {
        parts <- strsplit(trimws(pair), "=")[[1]]
        if (length(parts) == 2) {
          return(setNames(list(trimws(parts[2])), trimws(parts[1])))
        } else {
          return(NULL)
        }
      })
      result_list <- result_list[!sapply(result_list, is.null)]
      if (length(result_list) > 0) return(do.call(c, result_list))
    }, error = function(e) { return(list()) })
  }
  
  # 2. Fallback: If comparison_info is missing, try groupname (Primary comparison)
  # But we don't know the reference, so we skip or handle downstream.
  # For now, if comp_info is empty, we return empty list to be safe and clean.
  return(list())
})

# ^=============================================================================
# Section 2: Main UI Rendering
# ==============================================================================

output$demo_mode_indicator_ui <- renderUI({
#  if (job_status$demo_mode == 1) tags$div(style = "color: forestgreen; font-style: italic; font-weight: bold; font-size: 16px;", icon("info-circle"), " This is the demo mode.") else NULL
  if (job_status$demo_mode == 1) {
    fluidRow(
      column(7,
	tagList(
          strong("There are four demo datasets available for selection via the dropdown menu (Select Analysis Results):"), tags$br(),
	  "1. PacBio.Subgingival", tags$br(),
	  "2. PacBio.Saliva", tags$br(),
	  "3. Illumina.Gout", tags$br(),
	  "4. Illumina.CrohnDisease"
	)     
      ),	     
      column(5,	     
        tags$div(
          style = "color: forestgreen; font-style: italic; font-weight: bold; font-size: 16px;",
          actionLink(
            inputId = "demo_info_btn",
            label = tagList(icon("info-circle"), " This is the demo mode. Click here for more details."),
            style = "color: forestgreen; text-decoration: none;"
          )
        )
      )
    )
  } else {
    NULL
  }
})

observeEvent(input$demo_info_btn, {
  showModal(modalDialog(
    title = tagList(icon("database"), " Demo Datasets Information"),
    size = "l",
    easyClose = TRUE,
    footer = tagList(
      actionLink("demo_modal_download_link",
        label = tagList(icon("download"), " Download Demo Datasets"),
        style = "color: #E95420; font-weight: bold; margin-right: 20px;"),
      modalButton("Close")
    ),

    # Oral Microbiome
    div(style = "background-color: #e8f5e9; border: 1px solid #a5d6a7; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
      h5(icon("tooth"), " Oral Microbiome: Saliva & Subgingival", style = "color: #2e7d32; font-weight: bold; margin-top: 0;"),
      tags$ul(style = "margin-bottom: 5px;",
        tags$li(strong("BioProject: "), tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA933120", target = "_blank", "PRJNA933120")),
        tags$li(strong("Platform: "), "PacBio"),
        tags$li(strong("Samples: "), "40 (Perio 20 vs Control 20)"),
        tags$li(strong("Demo Feature: "), "Long reads / Cross-condition")
      ),
      p(style = "font-size: 0.8em; color: #666;", "Buetas et al. (2024) BMC Genomics, 25, 310.")	
    ),

    # Crohn's Disease
    div(style = "background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
      h5(icon("bacteria"), " Gut Microbiome: Pediatric Crohn's Disease", style = "color: #1565c0; font-weight: bold; margin-top: 0;"),
      tags$ul(style = "margin-bottom: 5px;",
        tags$li(strong("BioProject: "), tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1156939", target = "_blank", "PRJNA1156939")),
        tags$li(strong("Platform: "), "Illumina"),
        tags$li(strong("Samples: "), "90 (Colon vs Stool vs Terminal ileum)"),
        tags$li(strong("Demo Feature: "), "Time-based batch correction")
      ),
      p(style = "font-size: 0.8em; color: #666;", "Kim et al. (2025) iScience, 28, 113160.")	
    ),

    # Gout
    div(style = "background-color: #fff3e0; border: 1px solid #ffcc80; padding: 15px; border-radius: 5px;",
      h5(icon("disease"), " Gut Microbiome: Hyperuricemia and Gout", style = "color: #e65100; font-weight: bold; margin-top: 0;"),
      tags$ul(style = "margin-bottom: 5px;",
        tags$li(strong("BioProject: "),
		tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA550142", target = "_blank", "PRJNA550142"), " + ",
                tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA754261", target = "_blank", "PRJNA754261"), " + ",
                tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA869365", target = "_blank", "PRJNA869365"), " + ",
		tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1131142", target = "_blank", "PRJNA1131142")),
        tags$li(strong("Platform: "), "Illumina"),
        tags$li(strong("Samples: "), "~200 (Gout vs Healthy Control)"),
        tags$li(strong("Demo Feature: "), "Multi-cohort batch correction")
      ),
      p(style = "font-size: 0.8em; color: #666;", "Qie et al. (2025) mSystems, 10, e01091-25.")	
    )
  ))
})

# Demo Modal Download Link -> Jump to Tutorial / Quick Start
observeEvent(input$demo_modal_download_link, {
  removeModal()
  updateNavbarPage(session, "CoMeDA", selected = "Tutorial")
  shinyjs::delay(200, {
    updateNavlistPanel(session, "tutorial_nav", selected = "quick_start_demo")
  })
})

output$overview_main_ui <- renderUI({

  on.exit(w_overview_full$hide())
  if (!has_results()) {
    return(
      fluidRow(column(12, div(style = "text-align: center; padding: 60px; background-color: #f8f9fa; border: 2px dashed #ddd; border-radius: 10px; margin-top: 20px;",
                   h3(icon("box-open"), style = "color: #ccc; font-size: 40px; margin-bottom: 20px;"),
                   h4("No Analysis Results Found", style = "color: #666; font-weight: bold;"),
                   p("Please submit an analysis in Step A. Once completed, results will appear here automatically.", style = "color: #888;"))))
    )
  }
  
  folder_choices <- get_result_folders()
  
  tagList(
    fluidRow(column(12, div(style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; border: 1px solid #ddd; margin-bottom: 20px;",
                 fluidRow(
                   column(4, selectInput("selected_analysis_result", label = tags$span(icon("folder-open"), " Select Analysis Result:"), choices = folder_choices, width = "100%")),
                   column(8, div(style = "padding-top: 25px;", uiOutput("demo_mode_indicator_ui")))
                 )
             ))),
    fluidRow(column(12, uiOutput("result_summary_banner_ui"))), br(),
    fluidRow(column(12, tabsetPanel(id = "result_subtabs", type = "tabs",
               tabPanel(title = tagList(icon("chart-pie"), "1. Overview"), value = "tab_overview", br(),
                 div(style = "padding: 0 10px;",
                     h4("1.1 Analysis Parameters", style = "color: #333; padding-bottom: 10px; margin-bottom: 20px;"),
                     div(style = "display: flex; flex-wrap: wrap; margin-left: -15px; margin-right: -15px;",
                         div(class = "col-sm-4", style = "display: flex;", 
                             wellPanel(style = "width: 100%; background-color: #fff; border: 1px solid #ddd; padding: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
                                       h5(icon("folder"), " Input Data", style = "font-weight: bold; margin-top: 0; border-bottom: 1px solid #eee; padding-bottom: 10px;"),
                                       uiOutput("overview_input_data_ui")
                             )
                         ),
                         div(class = "col-sm-8", style = "display: flex;",
                             wellPanel(style = "width: 100%; background-color: #fff; border: 1px solid #ddd; padding: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);",
                                       h5(icon("cogs"), " Analysis Settings", style = "font-weight: bold; margin-top: 0; border-bottom: 1px solid #eee; padding-bottom: 10px;"),
                                       uiOutput("overview_settings_ui")
                             )
                         )
                     ),
                     br(),
                     h4("1.2 Data Statistics", style = "color: #333; padding-bottom: 10px; margin-bottom: 20px;"),
                     fluidRow(
                       column(2, wellPanel(style = "background-color: #f1f1f1; border: 1px solid #ccc;",
                                           h5("Plot Settings", style = "font-weight: bold; border-bottom: 2px solid #666; padding-bottom: 5px; margin-top: 0;"),
                                           selectInput("overview_stats_comp", "Comparison Group:", choices = NULL),
                                           hr(style = "border-top: 1px solid #ccc;"),
                                           numericInput("overview_stats_readcut", "Read Count Cutoff:", value = 500, min = 0, step = 100),
                                           tags$small(style="color:firebrick;", "--- Red dashed line"), br(), br(),
                                           numericInput("overview_stats_taxacut", "Taxa Count Cutoff:", value = 5, min = 0, step = 1),
                                           tags$small(style="color:firebrick;", "--- Red dashed line"))),
                       column(10, fluidRow(
                         column(6, wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                                             h5("Sample Read Count Distribution", style = "text-align: center; font-weight: bold;"),
                                             girafeOutput("overview_plot_read_count", height = "300px"),
                                             p("Violin plot grouped by selected comparison", style = "text-align: center; font-size: 12px; color: #777;"))),
                         column(6, wellPanel(style = "background-color: #fff; border: 1px solid #ddd;",
                                             h5("Taxa Count per Sample Distribution", style = "text-align: center; font-weight: bold;"),
                                             girafeOutput("overview_plot_taxa_count", height = "300px"),
                                             p("Violin plot grouped by selected comparison", style = "text-align: center; font-size: 12px; color: #777;")))
                       ))
                     ),
                     br(),
                     conditionalPanel(condition = "output.show_batch_correction_section == true",
                                      h4("1.3 Batch Correction Results", style = "color: #333; padding-bottom: 10px; margin-bottom: 20px;"),
                                      fluidRow(column(12, wellPanel(style = "background-color: #fff; border: 1px solid #ddd; padding: 20px;",
                                                                    # [NEW] Title row with Taxa Level selector
                                                                    fluidRow(
                                                                      column(9, h5("PCA Plots: Before vs After Batch Correction", 
                                                                                   style = "font-weight: bold; margin-top: 5px; color: #555;")),
                                                                      column(3, div(style = "display: flex; align-items: center; justify-content: flex-end;",
                                                                                    tags$label("Taxa Level:", style = "margin-right: 10px; font-weight: bold; color: #555;"),
                                                                                    div(style = "width: 150px;",
                                                                                        selectInput("overview_batch_taxa_level", 
                                                                                                    label = NULL,
                                                                                                    choices = NULL, 
                                                                                                    width = "100%"))))
                                                                    ),
                                                                    hr(style = "margin-top: 10px; margin-bottom: 15px; border-top: 1px solid #eee;"),
                                                                    girafeOutput("overview_batch_combined_plot", height = "900px"))))
                     )
                 ), br(), br()
               ),
               tabPanel(title = tagList(icon("chart-bar"), "2. Analysis Results"), value = "tab_analysis_results", br(),
                 source(paste(comedashinypath, "shinyR", "ui_analysis_resultoverview_analysistab.R", sep = "/"), local = TRUE)$value
               ),
               tabPanel(title = tagList(icon("download"), "3. Download"), value = "tab_download", br(),
                 source(paste(comedashinypath, "shinyR", "ui_analysis_resultoverview_download.R", sep = "/"), local = TRUE)$value
               )
             )))
  )
})

outputOptions(output, "overview_main_ui", suspendWhenHidden = FALSE)

# ^=============================================================================
# Section 3: Overview - 1.1 Parameter Display
# ==============================================================================

output$overview_input_data_ui <- renderUI({
  params <- current_params()
  if (is.null(params)) return(tags$span("No parameter info found."))
  tags$ul(style = "list-style-type: none; padding-left: 5px; line-height: 1.8;",
    tags$li(tags$strong("Input Type: "), params$inputtype),
    tags$li(tags$strong("Data Type: "), params$data_type),
    tags$li(tags$strong("Read Type: "), params$readtype),
    tags$li(tags$strong("Project Name: "), params$projectname)
  )
})

output$overview_settings_ui <- renderUI({
  param_display_map <- c(
    "groupname" = "Primary comparison",
    "comparison_info" = "All comparisons",
    "taxalevels" = "Taxa levels",
    "qscore" = "PHRed Score filtering",
    "minlen" = "Min length after trimming",
    "maxlen" = "Max length after trimming",
    "kraken2_confidence" = "Kraken2 confidence threshold",
    "uchimeref" = "Use reference method for chimera removal",
    "samplerichcut" = "Min feature(taxon) count of each sample for taxa-table pre-filtering",
    "samplerccut" = "Min read count of each sample for taxa-table pre-filtering",
    "taxaprevcut" = "Min prevalence of each taxon for taxa-table pre-filtering",
    "strictedpropcut" = "Min proportion of each taxon for correlation analysis",
    "strictedprevcut" = "Min prevalence of each taxon for correlation analysis",
    "funcsizecut" = "Min proportion of each taxon for functional prediction",
    "funcprevcut" = "Min prevalence of each taxon for functional prediction",
    "batch_correction_methods" = "Batch correction methods",
    "aldexdenom" = "Normalized parameter (denom) setting for ALDEx2",
    "batch_correction_status" = "Batch correction status"
  )
  ordered_keys <- names(param_display_map)

  # Use all_params() for final values
  final_list <- all_params()
  if (is.null(final_list)) return(tags$span("No parameter info found."))

  # Special Handling for aldexdenom
  adjustments <- current_adjustments()
  has_aldex_adjustment <- FALSE
  if (!is.null(adjustments) && "aldexdenom" %in% adjustments$parameter) {
    has_aldex_adjustment <- TRUE
  }
  
  if (has_aldex_adjustment) {
    final_list[["aldexdenom"]] <- "median (change to loosing setting)"
  } else {
    final_list[["aldexdenom"]] <- "iqlr"
  }

  display_items <- list()

  # 1. Standard Parameters
  for(key in ordered_keys) {
    if(key == "aldexdenom" || key == "batch_correction_status") next
    # [reviewer revision] Kraken2 confidence only applies to raw-sequencing classification;
    # hide it when the analysis was run in taxa-table input mode.
    if(key == "kraken2_confidence" && identical(as.character(final_list[["inputtype"]]), "taxatable")) next

    if(key %in% names(final_list)) {
      display_name <- param_display_map[[key]]
      val <- final_list[[key]]
      if(key == "taxalevels") val <- gsub(",", ", ", val)
      if(key == "comparison_info") val <- gsub(";", ", ", val)
      display_items[[length(display_items)+1]] <- tags$li(tags$strong(paste0(display_name, ": ")), val)
    }
  }

  # 2. Aldex Denom
  aldex_display_name <- param_display_map[["aldexdenom"]]
  if (has_aldex_adjustment) {
    display_items[[length(display_items)+1]] <- tags$li(
      tags$strong(style = "color: orangered;", paste0(aldex_display_name, ": ")),
      final_list[["aldexdenom"]]
    )
  } else {
    display_items[[length(display_items)+1]] <- tags$li(
      tags$strong(paste0(aldex_display_name, ": ")),
      final_list[["aldexdenom"]]
    )
  }

  # 3. Batch Correction Status (from Section 2 if exists)
  if (!is.null(adjustments)) {
    batch_rows <- which(adjustments$parameter == "batch_correction_status")
    if (length(batch_rows) > 0) {
      display_name <- param_display_map[["batch_correction_status"]]
      val_text <- paste0(adjustments$adjusted_value[batch_rows[1]], " (", adjustments$reason[batch_rows[1]], ")")
      display_items[[length(display_items)+1]] <- tags$li(
        tags$strong(style = "color: orangered;", paste0(display_name, ": ")),
        val_text
      )
    }
  }

  n <- length(display_items)
  if(n == 0) return(tags$span("No parameters to display."))

  half <- ceiling(n / 2)
  list1 <- display_items[1:half]
  list2 <- if(half < n) display_items[(half + 1):n] else list()

  fluidRow(
    column(6, tags$ul(style = "list-style-type: none; padding-left: 0; line-height: 1.8;", list1)),
    column(6, tags$ul(style = "list-style-type: none; padding-left: 0; line-height: 1.8;", list2))
  )
})

# ^=============================================================================
# Section 4: Overview - 1.2 Data Statistics
# ==============================================================================

observe({
  job_status$results_version
  req(job_status$current_id, input$selected_analysis_result)
  if (input$selected_analysis_result == "" || input$selected_analysis_result == "No results found") return()
  
  comp_file <- paste0(comedainvpath, "/", job_status$current_id, "/analysis/", input$selected_analysis_result, "/compinfotable.txt")
  if (file.exists(comp_file)) {
    tryCatch({
      cols <- read.table(comp_file, header = TRUE, nrows = 1)
      updateSelectInput(session, "overview_stats_comp", choices = colnames(cols))
    }, error = function(e) { updateSelectInput(session, "overview_stats_comp", choices = NULL) })
  } else {
    updateSelectInput(session, "overview_stats_comp", choices = NULL)
  }
})

output$overview_plot_read_count <- renderGirafe({
  env <- current_rdata(); req(env, input$overview_stats_comp)
  taxa <- env$raw.taxatable; meta <- env$raw.metadata; group_col <- input$overview_stats_comp
  if (is.null(taxa) || is.null(meta)) return(NULL)
  
  counts <- colSums(taxa[, -1])
  plot_df <- data.frame(Sample = names(counts), ReadCount = counts)
  if (group_col %in% colnames(meta)) plot_df$Group <- as.factor(meta[plot_df$Sample, group_col]) else plot_df$Group <- "All"
  plot_df$tooltip <- paste0("<b>Sample:</b> ", plot_df$Sample, "<br/><b>Reads:</b> ", format(plot_df$ReadCount, big.mark = ","))
  
  p <- ggplot(plot_df, aes(x = Group, y = ReadCount, fill = Group)) +
    geom_violin(trim = FALSE, alpha = 0.6) +
    geom_boxplot(width = 0.1, fill = "white", outlier.shape = NA) +
    geom_jitter_interactive(aes(tooltip = tooltip, data_id = Sample), width = 0.2, alpha = 0.6, size = 2) +
    geom_hline(yintercept = input$overview_stats_readcut, color = "firebrick", linetype = "dashed", linewidth = 1) +
    theme_minimal() + labs(x = NULL, y = "Total Reads") + scale_fill_manual(values = comedacolors) + theme(legend.position = "none")
  
  girafe(ggobj = p, width_svg = 8, height_svg = 4, options = list(opts_tooltip(opacity = 0.9), opts_selection(type = "none"), opts_toolbar(saveaspng = FALSE)))
})

output$overview_plot_taxa_count <- renderGirafe({
  env <- current_rdata(); req(env, input$overview_stats_comp)
  taxa <- env$raw.taxatable; meta <- env$raw.metadata; group_col <- input$overview_stats_comp
  if (is.null(taxa) || is.null(meta)) return(NULL)
  
  taxa_counts <- colSums(taxa[, -1] > 0)
  plot_df <- data.frame(Sample = names(taxa_counts), TaxaCount = taxa_counts)
  if (group_col %in% colnames(meta)) plot_df$Group <- as.factor(meta[plot_df$Sample, group_col]) else plot_df$Group <- "All"
  plot_df$tooltip <- paste0("<b>Sample:</b> ", plot_df$Sample, "<br/><b>Taxa:</b> ", plot_df$TaxaCount)
  
  p <- ggplot(plot_df, aes(x = Group, y = TaxaCount, fill = Group)) +
    geom_violin(trim = FALSE, alpha = 0.6) +
    geom_boxplot(width = 0.1, fill = "white", outlier.shape = NA) +
    geom_jitter_interactive(aes(tooltip = tooltip, data_id = Sample), width = 0.2, alpha = 0.6, size = 2) +
    geom_hline(yintercept = input$overview_stats_taxacut, color = "firebrick", linetype = "dashed", linewidth = 1) +
    theme_minimal() + labs(x = NULL, y = "Number of Taxa") + scale_fill_manual(values = comedacolors) + theme(legend.position = "none")
  
  girafe(ggobj = p, width_svg = 8, height_svg = 4, options = list(opts_tooltip(opacity = 0.9), opts_selection(type = "none"), opts_toolbar(saveaspng = FALSE)))
})

# ^=============================================================================
# Section 5: Overview - 1.3 Batch Correction
# ==============================================================================

output$show_batch_correction_section <- reactive({
  params <- current_params()
  if (is.null(params) || is.null(params$batchcolname)) return(FALSE)
  return(params$batchcolname != "none")
})
outputOptions(output, "show_batch_correction_section", suspendWhenHidden = FALSE)

# [NEW] Update Taxa Level choices for Batch Correction plot
observe({
  params <- current_params()
  req(params, params$taxalevels)
  
  # Parse taxa levels from parameter
  taxa_levels <- strsplit(params$taxalevels, ",")[[1]]
  taxa_levels <- trimws(taxa_levels)
  
  # Default selection: genus if available, otherwise first option
  default_selection <- if ("genus" %in% taxa_levels) "genus" else taxa_levels[1]
  
  updateSelectInput(session, "overview_batch_taxa_level", 
                    choices = taxa_levels, 
                    selected = default_selection)
})

get_primary_comp_col <- function() {
  req(job_status$current_id, input$selected_analysis_result)
  comp_file <- paste0(comedainvpath, "/", job_status$current_id, "/analysis/", input$selected_analysis_result, "/compinfotable.txt")
  if (file.exists(comp_file)) {
    cols <- read.table(comp_file, header = TRUE, nrows = 1)
    return(colnames(cols)[1])
  }
  return(NULL)
}

# [NEW] Calculate PERMANOVA R² and p-value
# Prepare one reusable beta-diversity space.
# The same distance and PCoA are reused for batch and group panels.
prepare_beta_space <- function(
  data_matrix,
  metadata,
  batch_col,
  group_col
) {
  if (
    is.null(data_matrix) ||
    is.null(metadata) ||
    is.null(batch_col) ||
    is.null(group_col)
  ) {
    return(NULL)
  }

  required <- c(batch_col, group_col)

  if (!all(required %in% colnames(metadata))) {
    return(NULL)
  }

  common_samples <- intersect(
    rownames(data_matrix),
    rownames(metadata)
  )

  if (length(common_samples) < 3L) {
    return(NULL)
  }

  X <- as.matrix(
    data_matrix[common_samples, , drop = FALSE]
  )

  md <- as.data.frame(
    metadata[common_samples, , drop = FALSE]
  )

  # Both conditional models require complete batch and group labels.
  valid <- complete.cases(
    md[, required, drop = FALSE]
  )

  X <- X[valid, , drop = FALSE]
  md <- md[valid, , drop = FALSE]

  if (
    nrow(X) < 3L ||
    ncol(X) < 2L ||
    any(!is.finite(X))
  ) {
    return(NULL)
  }

  md$batch <- droplevels(
    factor(md[[batch_col]])
  )

  md$group <- droplevels(
    factor(md[[group_col]])
  )

  if (
    nlevels(md$batch) < 2L ||
    nlevels(md$group) < 2L
  ) {
    return(NULL)
  }

  stopifnot(
    identical(rownames(X), rownames(md))
  )

  tryCatch({
    # Aitchison distance = Euclidean distance on CLR.
    D <- stats::dist(
      X,
      method = "euclidean"
    )

    # Calculate PCoA only once for this matrix.
    pcoa <- stats::cmdscale(
      D,
      k = 2,
      eig = TRUE
    )

    list(
      metadata = md,
      distance = D,
      pcoa = pcoa,

      batch_col = batch_col,
      group_col = group_col,

      n_samples = nrow(X),
      n_taxa = ncol(X)
    )
  }, error = function(e) {
    warning(
      "Overview beta-space preparation failed: ",
      conditionMessage(e)
    )

    NULL
  })
}


# Calculate one conditional PERMANOVA and its matching PERMDISP.
# beta_space already contains the distance matrix.
calculate_beta_tests <- function(
  beta_space,
  focal = c("batch", "group"),
  seed = 1223L,
  permutations = 999L
) {
  focal <- match.arg(focal)

  if (is.null(beta_space)) {
    return(NULL)
  }

  D <- beta_space$distance
  md <- beta_space$metadata

  if (focal == "batch") {
    focal_factor <- md$batch
    adjustment_factor <- md$group

    focal_col <- beta_space$batch_col
    adjust_col <- beta_space$group_col

    # Test batch after controlling for group.
    model_formula <- D ~ group + batch
    target_term <- "batch"
  } else {
    focal_factor <- md$group
    adjustment_factor <- md$batch

    focal_col <- beta_space$group_col
    adjust_col <- beta_space$batch_col

    # Test group after controlling for batch.
    model_formula <- D ~ batch + group
    target_term <- "group"
  }

  tryCatch({
    control <- permute::how(
      nperm = permutations
    )

    permute::setBlocks(control) <-
      adjustment_factor

    set.seed(seed)

    fit <- vegan::adonis2(
      model_formula,
      data = md,
      permutations = control,
      by = "terms"
    )

    # PERMDISP in its own guard so a dispersion failure does not void the PERMANOVA result.
    permd <- tryCatch({
      set.seed(seed)
      disp  <- vegan::betadisper(D, focal_factor)
      dtest <- vegan::permutest(disp, permutations = permutations)
      dtab  <- as.data.frame(dtest$tab)
      fcol  <- grep("^F", colnames(dtab), value = TRUE)[1]
      pcol  <- grep("Pr", colnames(dtab), value = TRUE)[1]
      list(F = unname(dtab[1, fcol]), p = unname(dtab[1, pcol]))
    }, error = function(e) {
      warning("Overview PERMDISP failed: ", conditionMessage(e))
      list(F = NA_real_, p = NA_real_)
    })

    list(
      R2 = unname(
        fit[target_term, "R2"]
      ),

      pvalue = unname(
        fit[target_term, "Pr(>F)"]
      ),

      permdisp_F = permd$F,

      permdisp_p = permd$p,

      focal_col = focal_col,
      adjust_col = adjust_col,

      n_samples = beta_space$n_samples,
      n_taxa = beta_space$n_taxa
    )
  }, error = function(e) {
    warning(
      "Overview beta-diversity test failed: ",
      conditionMessage(e)
    )

    NULL
  })
}

get_pcoa_ggplot <- function(
  beta_space,
  color_col,
  title,
  title_color,
  permanova_result = NULL,
  color_reverse = FALSE
) {
  if (is.null(beta_space)) {
    return(NULL)
  }

  meta_sub <- beta_space$metadata
  pcoa_res <- beta_space$pcoa

  if (
    is.null(meta_sub) ||
    is.null(pcoa_res) ||
    is.null(pcoa_res$points)
  ) {
    return(NULL)
  }

  if (
    is.null(color_col) ||
    !color_col %in% colnames(meta_sub)
  ) {
    color_col <- "Unknown_Group"
    meta_sub[[color_col]] <- factor("All")
  } else {
    meta_sub[[color_col]] <- factor(
      meta_sub[[color_col]]
    )
  }

  pcoa_df <- data.frame(
    PCoA1 = pcoa_res$points[, 1],
    PCoA2 = pcoa_res$points[, 2],
    row.names = rownames(meta_sub),
    check.names = FALSE
  )

  pcoa_df$Row.names <- rownames(pcoa_df)

  eig_vals <- pcoa_res$eig

  var_exp <- round(
    eig_vals[1:2] /
      sum(abs(eig_vals)) * 100,
    1
  )
  
  pcoa_wMeta <- cbind(pcoa_df, meta_sub)
  
  pcoa_centroid <- pcoa_wMeta %>% 
    dplyr::group_by(!!sym(color_col)) %>% 
    dplyr::summarise(centroidx = mean(PCoA1), centroidy = mean(PCoA2), .groups = 'drop')
  plot_data <- dplyr::left_join(pcoa_wMeta, pcoa_centroid, by = color_col)
  
  plot_data$tooltip <- paste0("<b>Sample:</b> ", plot_data$Row.names, "<br/><b>Group:</b> ", plot_data[[color_col]])
  
  if (!is.null(permanova_result)) {
  format_p <- function(p) {
    if (is.na(p)) {
      "NA"
    } else if (p <= 0.001) {
      "<= 0.001"
    } else {
      format(round(p, 3), nsmall = 3)
    }
  }

  dispersion_warning <- if (
    !is.na(permanova_result$permdisp_p) &&
    permanova_result$permdisp_p < 0.05
  ) {
    " [dispersion differs]"
  } else {
    ""
  }

  plot_title <- paste0(
    "PERMANOVA R²(",
    permanova_result$focal_col,
    " | ",
    permanova_result$adjust_col,
    ") = ",
    round(permanova_result$R2, 3),
    ", p ",
    format_p(permanova_result$pvalue),
    "\nPERMDISP F = ",
    round(permanova_result$permdisp_F, 2),
    ", p ",
    format_p(permanova_result$permdisp_p),
    dispersion_warning
  )
} else {
  plot_title <- NULL
}

  # [NEW] Select colors based on color_reverse parameter
  n_groups <- length(unique(plot_data[[color_col]]))
  colors_to_use <- if(exists("comedacolors")) {
    if(color_reverse) rev(comedacolors)[1:n_groups] else comedacolors[1:n_groups]
  } else {
    RColorBrewer::brewer.pal(8, "Set2")[1:n_groups]
  }

  p <- ggplot(plot_data, aes(x = PCoA1, y = PCoA2, color = .data[[color_col]])) +
    geom_segment(aes(xend = centroidx, yend = centroidy), linetype = "solid", linewidth = 0.5, alpha = 0.3) +
    stat_ellipse(data = plot_data %>% group_by(!!sym(color_col)) %>% filter(n() > 3),
                 type = "t", linetype = "dashed", linewidth = 0.5, alpha = 0.8) +
    geom_point_interactive(aes(tooltip = tooltip, data_id = Row.names), size = 3) +
    theme_minimal(base_size = 12) +
    labs(title = plot_title,
         x = paste0("PCoA1 (", var_exp[1], "%)"),
         y = paste0("PCoA2 (", var_exp[2], "%)"),
         color = color_col) +
    scale_color_manual(values = colors_to_use) +
    theme(legend.position = "bottom",
          plot.title = element_text(size = 11, face = "italic", hjust = 1, color = title_color),  # hjust = 1 靠右
          plot.title.position = "plot",
          panel.border = element_rect(colour = "grey", fill = NA, size = 0.5))
  
  return(p)
}

# Prepare and cache all expensive overview beta-diversity results.
overview_beta_bundle <- shiny::reactive({
  env <- current_rdata()
  params <- current_params()

  req(
    env,
    params,
    input$overview_batch_taxa_level
  )

  taxa_level <- input$overview_batch_taxa_level
  comp_col <- get_primary_comp_col()
  batch_col <- params$batchcolname

  req(
    comp_col,
    batch_col
  )

  if (
    is.null(env$aldex.clr[[taxa_level]]) ||
    is.null(
      env$batch.correct.res[[taxa_level]]
    ) ||
    is.null(
      env$batch.correct.res[[taxa_level]]$correctedTable
    ) ||
    is.null(env$filtered.meta[[taxa_level]])
  ) {
    return(NULL)
  }

  start_time <- proc.time()[["elapsed"]]

  before_space <- prepare_beta_space(
    data_matrix =
      env$aldex.clr[[taxa_level]],

    metadata =
      env$filtered.meta[[taxa_level]],

    batch_col = batch_col,
    group_col = comp_col
  )

  after_space <- prepare_beta_space(
    data_matrix =
      env$batch.correct.res[[taxa_level]]$correctedTable,

    metadata =
      env$filtered.meta[[taxa_level]],

    batch_col = batch_col,
    group_col = comp_col
  )

  if (
    is.null(before_space) ||
    is.null(after_space)
  ) {
    return(NULL)
  }

  tests <- list(
    batch_before = calculate_beta_tests(
      before_space,
      focal = "batch"
    ),

    batch_after = calculate_beta_tests(
      after_space,
      focal = "batch"
    ),

    group_before = calculate_beta_tests(
      before_space,
      focal = "group"
    ),

    group_after = calculate_beta_tests(
      after_space,
      focal = "group"
    )
  )

  # Do not void the whole bundle if a test is NULL; the PCoA must still render.
  # get_pcoa_ggplot() handles a NULL permanova_result by omitting the stats from the title.
  # if (any(vapply(tests, is.null, logical(1)))) {
  #   return(NULL)
  # }

  elapsed <- proc.time()[["elapsed"]] -
    start_time

  message(
    sprintf(
      paste0(
        "[Overview beta] job=%s, result=%s, ",
        "taxa=%s, elapsed=%.2f sec"
      ),
      job_status$current_id,
      input$selected_analysis_result,
      taxa_level,
      elapsed
    )
  )

  list(
    taxa_level = taxa_level,
    batch_col = batch_col,
    comp_col = comp_col,

    before = before_space,
    after = after_space,

    tests = tests,
    elapsed_seconds = elapsed
  )
})


# App-level cache:
# key uses small stable identifiers, not the CLR matrix itself.
overview_beta_bundle <- shiny::bindCache(
  overview_beta_bundle,

  job_status$current_id,
  input$selected_analysis_result,
  input$overview_batch_taxa_level,
  current_params()$batchcolname,
  get_primary_comp_col(),

  "conditional_beta_v1_seed1223_perm999",

  cache = "app"
)

output$overview_batch_combined_plot <- renderGirafe({
  w_batch_plot$show()
  on.exit(w_batch_plot$hide())

  env <- current_rdata(); req(env); params <- current_params()
  comp_col <- get_primary_comp_col()
  
  # [MODIFIED] Use selected taxa level instead of fixed "species"
  taxa_level <- input$overview_batch_taxa_level
  req(taxa_level)
  
  if (is.null(env$aldex.clr[[taxa_level]]) || is.null(env$batch.correct.res[[taxa_level]])) return(NULL)

  # Conditional PERMANOVA and PERMDISP
    beta <- overview_beta_bundle()

  req(beta)

  p1 <- get_pcoa_ggplot(
    beta_space = beta$before,
    color_col = beta$batch_col,
    title = "Before Correction (By Batches)",
    title_color = "firebrick",
    permanova_result =
      beta$tests$batch_before,
    color_reverse = TRUE
  )

  p2 <- get_pcoa_ggplot(
    beta_space = beta$after,
    color_col = beta$batch_col,
    title = "After Correction (By Batches)",
    title_color = "forestgreen",
    permanova_result =
      beta$tests$batch_after,
    color_reverse = TRUE
  )

  p3 <- get_pcoa_ggplot(
    beta_space = beta$before,
    color_col = beta$comp_col,
    title = "Before Correction (By Group)",
    title_color = "firebrick",
    permanova_result =
      beta$tests$group_before,
    color_reverse = FALSE
  )

  p4 <- get_pcoa_ggplot(
    beta_space = beta$after,
    color_col = beta$comp_col,
    title = "After Correction (By Group)",
    title_color = "forestgreen",
    permanova_result =
      beta$tests$group_after,
    color_reverse = FALSE
  )
  
  if (is.null(p1) || is.null(p2) || is.null(p3) || is.null(p4)) return(NULL)

  make_section_title <- function(label) {
    ggplot() +
      annotate("text", x = 0.5, y = 0.5, label = label,
               hjust = 0.5, vjust = 0.5, fontface = "bold", size = 6, colour = "gray20") +
      xlim(0, 1) + ylim(0, 1) +
      theme_void() +
      theme(plot.margin = margin(0, 0, 0, 0))
  }

  make_col_header <- function() {
    ggplot() +
      annotate("text", x = 0.25, y = 0.5, label = "Before batch correction",
               hjust = 0.5, vjust = 0.5, fontface = "bold", size = 4.5, colour = "firebrick") +
      annotate("text", x = 0.5, y = 0.5, label = "→",
               hjust = 0.5, vjust = 0.5, fontface = "bold", size = 5, colour = "black") +
      annotate("text", x = 0.75, y = 0.5, label = "After batch correction",
               hjust = 0.5, vjust = 0.5, fontface = "bold", size = 4.5, colour = "forestgreen") +
      xlim(0, 1) + ylim(0, 1) +
      theme_void() +
      theme(plot.margin = margin(0, 0, 0, 0))
  }

  common_margin <- margin(5, 5.5, 5.5, 5.5)
  p1 <- p1 + theme(plot.margin = common_margin)
  p2 <- p2 + theme(plot.margin = common_margin)
  p3 <- p3 + theme(plot.margin = common_margin)
  p4 <- p4 + theme(plot.margin = common_margin)

  section_title_batch <- make_section_title("Label by batches")
  section_title_primary <- make_section_title("Label by primary comparison")
  col_header_1 <- make_col_header()
  col_header_2 <- make_col_header()
  sep_line <- ggplot() + geom_hline(yintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.8) + theme_void() + theme(plot.margin = margin(5, 0, 5, 0))

  layout_design <- "
    AA
    ##
    BB
    CD
    EE
    FF
    ##
    GG
    HI
  "																   

  combined_plot <- section_title_batch +
                   col_header_1 +
                   p1 + p2 +
                   sep_line +
                   section_title_primary +
                   col_header_2 +
                   p3 + p4 +
    patchwork::plot_layout(
      design = layout_design,
      heights = c(0.8, 0.1, 0.45, 10, 0.25, 0.8, 0.1, 0.45, 10)
    )

  girafe(ggobj = combined_plot, width_svg = 18, height_svg = 11,
    options = list(opts_tooltip(opacity = 0.9), opts_selection(type = "none"), opts_toolbar(saveaspng = FALSE), opts_sizing(rescale = TRUE))
  )
})

## ^analysis result tab
source(paste(comedashinypath, "shinyR", "server_analysis_resultoverview_analysistab.R", sep = "/"), local = TRUE)
## analysis result tab$

## ^download tab
source(paste(comedashinypath, "shinyR", "server_analysis_resultoverview_download.R", sep = "/"), local = TRUE)
## download tab$
