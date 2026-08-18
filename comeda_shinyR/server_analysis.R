## server_analysis.R; CoMeDA v2.3
## Updated: 2025.12.11 (Fix: Cross-Kingdom Button Support)

# [FIX] 1. Increase File Upload Size Limit (Default is 5MB, increase to 10GB)
options(shiny.maxRequestSize = 10000 * 1024^2)

# ^reactiveValues
job_status <- reactiveValues(
  user_mode = 1,
  demo_mode = 0,
  current_id = UUIDgenerate(),
  new_id = NULL,
  other_id = NULL,
  trigger_source = NULL,
  data_format = NULL,
  sample_type = NULL,
  uploaded_files = list(data = NULL, metadata = NULL),
  validation = list(simple_passed = FALSE, simple_errors = NULL, deep_passed = FALSE, deep_errors = NULL),
  auto_detected = list(file_name_col = NULL, need_demultiplex = NULL, barcode_col = NULL, fprimer_col = NULL, rprimer_col = NULL, batches_col = NULL, comparison_cols = NULL),
  parameters = list(),
  step2_expanded = FALSE,
  step3_ready = FALSE,
  analysis_submitted = FALSE,
  analysis_state = NULL,
  analysis_start_time = NULL,
  phase_status = list(),
  results_version = 0,
  # [NEW] Counter to force re-rendering of file inputs
  input_refresh = 0,
  analysis_completed = FALSE,
  analysis_input_type = NULL
)

# [NEW] Helper: Reset Job State (Clear Uploads & Params)
reset_job_state <- function() {
  job_status$uploaded_files <- list(data = NULL, metadata = NULL)
  job_status$validation <- list(simple_passed = FALSE, simple_errors = NULL, deep_passed = FALSE, deep_errors = NULL)
  job_status$auto_detected <- list(file_name_col = NULL, need_demultiplex = NULL, barcode_col = NULL, fprimer_col = NULL, rprimer_col = NULL, batches_col = NULL, comparison_cols = NULL)
  job_status$parameters <- list()
  job_status$step2_expanded <- FALSE
  job_status$step3_ready <- FALSE
  job_status$analysis_submitted <- FALSE
  job_status$analysis_state <- NULL
  job_status$phase_status <- list()
  job_status$log_content <- character(0)
  
  # [NEW] Increment refresh counter to force clean file inputs
  job_status$input_refresh <- job_status$input_refresh + 1

  # [NEW] Reset completion flag and input type
  job_status$analysis_completed <- FALSE
  job_status$analysis_input_type <- NULL
}

# [NEW] Helper: Load Demo Dataset (Shared by Step A & Step B)
load_demo_dataset <- function() {
  # 1. Read Metadata
  demo_meta_dir <- paste0(comedainvpath, "/comedademo/rawdata/metadata")
  if (dir.exists(demo_meta_dir)) {
    demo_meta_files <- list.files(demo_meta_dir, pattern = "\\.txt$", full.names = TRUE)
    if (length(demo_meta_files) > 0) {
      meta_file <- demo_meta_files[1]
      tryCatch({
        metadata <- read.table(meta_file, header = TRUE, sep = "\t", check.names = FALSE, comment.char = "", stringsAsFactors = FALSE)
        job_status$uploaded_files$metadata <- list(
          n_samples = nrow(metadata), n_features = ncol(metadata), 
          file_name = basename(meta_file), file_path = meta_file, 
          upload_time = Sys.time(), data = metadata
        )
      }, error = function(e) {
        dummy_meta <- data.frame(sample.id = c("S1", "S2"), file.name = c("d1.gz", "d2.gz"), comparison = c("A", "B"), stringsAsFactors = FALSE)
        job_status$uploaded_files$metadata <- list(data = dummy_meta, n_samples = 2, n_features = 3)
      })
    }
  }
  
  # 2. Read Data Files
  demo_taxa_dir <- paste0(comedainvpath, "/comedademo/rawdata/taxafile")
  if (dir.exists(demo_taxa_dir)) {
    demo_taxa_files <- list.files(demo_taxa_dir, full.names = TRUE)
    if (length(demo_taxa_files) > 0) {
      file_names <- basename(demo_taxa_files)
      file_extensions <- tools::file_ext(file_names)
      is_sequencing <- any(file_extensions %in% c("fastq", "fq", "gz"))
      is_taxatable <- length(file_names) == 1 && file_extensions[1] == "txt"
      
      if (is_sequencing) {
        has_r1 <- any(grepl("R1|_1\\.", file_names))
        has_r2 <- any(grepl("R2|_2\\.", file_names))
        platform <- if(has_r1 && has_r2) "Illumina paired-end short reads" else "Pacbio / Nanopore single-end long-reads"
        n_samples <- if(has_r1 && has_r2) length(file_names)/2 else length(file_names)
        
        job_status$uploaded_files$data <- list(
          type = "sequencing", platform = platform, n_files = length(file_names), 
          n_samples = floor(n_samples), file_names = file_names, file_paths = demo_taxa_files, upload_time = Sys.time()
        )
      } else if (is_taxatable) {
        tryCatch({
          taxa_table <- read.table(demo_taxa_files[1], header = TRUE, sep = "\t", check.names = FALSE, comment.char = "")
          job_status$uploaded_files$data <- list(
            type = "taxatable", n_files = 1, n_samples = ncol(taxa_table) - 1, 
            n_taxa = nrow(taxa_table), file_names = file_names, file_paths = demo_taxa_files, upload_time = Sys.time(), data = taxa_table
          )
        }, error = function(e) {
          job_status$uploaded_files$data <- list(type = "sequencing", platform = "Illumina", n_files = 2)
        })
      }
    }
  }
  
  # 3. Set Status
  job_status$validation$simple_passed <- TRUE
  job_status$step2_expanded <- TRUE
}

# [NEW] Helper: Reload Existing User Dataset (For Switching back to UUID)
reload_user_dataset <- function(uuid) {
  project_path <- paste0(comedainvpath, "/", uuid)
  raw_meta_dir <- paste0(project_path, "/rawdata/metadata")
  raw_taxa_dir <- paste0(project_path, "/rawdata/taxafile")
  
  # 1. Metadata
  if (dir.exists(raw_meta_dir)) {
    meta_files <- list.files(raw_meta_dir, pattern = "\\.txt$", full.names = TRUE)
    if (length(meta_files) > 0) {
      tryCatch({
        metadata <- read.table(meta_files[1], header = TRUE, sep = "\t", check.names = FALSE, comment.char = "", stringsAsFactors = FALSE)
        job_status$uploaded_files$metadata <- list(
          n_samples = nrow(metadata), n_features = ncol(metadata), 
          file_name = basename(meta_files[1]), file_path = meta_files[1], 
          upload_time = Sys.time(), data = metadata
        )
      }, error = function(e) {})
    }
  }
  
  # 2. Data Files
  if (dir.exists(raw_taxa_dir)) {
    taxa_files <- list.files(raw_taxa_dir, full.names = TRUE)
    if (length(taxa_files) > 0) {
      file_names <- basename(taxa_files)
      file_extensions <- tools::file_ext(file_names)
      is_sequencing <- any(file_extensions %in% c("fastq", "fq", "gz"))
      is_taxatable <- length(file_names) == 1 && file_extensions[1] == "txt"
      
      if (is_sequencing) {
        has_r1 <- any(grepl("R1|_1\\.", file_names))
        has_r2 <- any(grepl("R2|_2\\.", file_names))
        platform <- if(has_r1 && has_r2) "Illumina paired-end short reads" else "Pacbio / Nanopore single-end long-reads"
        n_samples <- if(has_r1 && has_r2) length(file_names)/2 else length(file_names)
        
        job_status$uploaded_files$data <- list(
          type = "sequencing", platform = platform, n_files = length(file_names), 
          n_samples = floor(n_samples), file_names = file_names, file_paths = taxa_files, upload_time = Sys.time()
        )
      } else if (is_taxatable) {
        tryCatch({
          taxa_table <- read.table(taxa_files[1], header = TRUE, sep = "\t", check.names = FALSE, comment.char = "")
          job_status$uploaded_files$data <- list(
            type = "taxatable", n_files = 1, n_samples = ncol(taxa_table) - 1, 
            n_taxa = nrow(taxa_table), file_names = file_names, file_paths = taxa_files, upload_time = Sys.time(), data = taxa_table
          )
        }, error = function(e) {})
      }
    }
  }
}

# Session Restoration
output$current_job_id_display <- renderText({
  if (job_status$user_mode == 1) {
    paste0("Your job id : ", job_status$current_id)
  } else if (job_status$demo_mode == 1) {
    "Use the example data for demonstration"
  }
})

# ==============================================================================
# Button Logic: Step A
# ==============================================================================
observeEvent(input$use_demo_btn_stepA, {
  if (job_status$demo_mode == 0) {
    job_status$user_mode <- 0
    job_status$demo_mode <- 1
    job_status$new_id <- ifelse(is.null(job_status$new_id), job_status$current_id, job_status$new_id)
    job_status$current_id <- "comedademo"
    job_status$results_version <- job_status$results_version + 1
  }
  load_demo_dataset()
  showNotification("Demo data loaded successfully! Please configure parameters in Step 2.", type = "message", duration = 5)
})

observeEvent(input$import_job_id_btn_stepA, {
  job_status$trigger_source <- "stepA" 
  if (job_status$demo_mode != 1) { job_status$new_id <- job_status$current_id }
  showModal(job_id_modal())
})

# ==============================================================================
# Button Logic: Step B
# ==============================================================================
observeEvent(input$use_demo_btn_stepB, {
  job_status$user_mode <- 0
  job_status$demo_mode <- 1
  job_status$new_id <- ifelse(is.null(job_status$new_id), job_status$current_id, job_status$new_id)
  job_status$current_id <- "comedademo"
  
  load_demo_dataset()
  
  job_status$results_version <- job_status$results_version + 1
  showNotification("Switched to Demo Data.", type = "message")
})

observeEvent(input$import_job_id_btn_stepB, {
  job_status$trigger_source <- "stepB"
  if (job_status$demo_mode != 1) { job_status$new_id <- job_status$current_id }
  showModal(job_id_modal())
})

# ==============================================================================
# Common Modal
# ==============================================================================
job_id_modal <- function() {
  modalDialog(
    title = tagList(tags$div("Switch Job ID", style = "padding-left: 2%; color: whitesmoke; font-size: 18px; font-weight: bold; background-color: #E95420;")), 
    fluidRow(
      column(12, textInput("input_other_job_id", "Enter Job ID:", value = "", placeholder = "e.g., a1b2c3d4...", width = "100%")),
      column(12, align = "center", uiOutput("validate_job_id_ui")),
      column(12, br()),
      column(12, align = "right", style = "color: firebrick; font-weight: bold;", h5("The data will be retained for 14 days.")),
      column(12, align = "right", style = "font-weight: bold; font-size: 16px", actionLink("link_to_tutorial", label = "Link to tutorial", class = "btn-link", style = "color: forestgreen;")),
      column(12, br()),
      column(6, actionButton("confirm_import_job_id", "Switch to this Job", icon = icon("check"), style = "color: whitesmoke; background-color: dimgrey; width: 100%;")),
      column(6, actionButton("cancel_import_job_id", "Return to New/Current Job", icon = icon("rotate-left"), style = "color: whitesmoke; background-color: dimgrey; width: 100%;"))
    ),
    easyClose = FALSE, footer = NULL, size = "l"
  )
}

output$validate_job_id_ui <- renderUI({
  req(input$input_other_job_id)
  if (!(input$input_other_job_id %in% list.dirs(comedainvpath, recursive = FALSE, full.names = FALSE))) {
    h3(style = "color: firebrick;", strong("== This Job ID does not exist, please try again =="))
  } else {
    h3(style = "color: forestgreen;", strong("== This Job ID is correct, please click the submit button below =="))
  }
})

# 5. Confirm Switch (FIXED: Reset State & Handle Manual Demo Entry)
observeEvent(input$confirm_import_job_id, {
  input_id <- input$input_other_job_id
  
  if (input_id %in% list.dirs(comedainvpath, recursive = FALSE, full.names = FALSE)) {
    
    # Always reset state first
    reset_job_state()
    
    # Set ID
    job_status$current_id <- input_id
    job_status$new_id <- input_id
    
    # Handle manual "comedademo" entry vs regular UUID
    if (input_id == "comedademo") {
      job_status$user_mode <- 0
      job_status$demo_mode <- 1
      load_demo_dataset() 
      showNotification("Switched to Demo Mode.", type = "message", duration = 4)
    } else {
      job_status$user_mode <- 1
      job_status$demo_mode <- 0
      reload_user_dataset(input_id)
      showNotification("Job ID loaded successfully.", type = "message", duration = 4)
    }
    
    job_status$results_version <- job_status$results_version + 1
    
    # [FIX] Do not switch tabs if triggered from Cross-Kingdom tab
    if (is.null(job_status$trigger_source) || job_status$trigger_source != "cross_kingdom") {
      updateTabsetPanel(session, "analysis_workflow", selected = "view_kingdom_specific_tab")
    }
    
    removeModal()
  }
}, ignoreInit = TRUE)

# 6. Return to New/Current
observeEvent(input$cancel_import_job_id, {
  if (job_status$demo_mode == 1) {
    reset_job_state()
  }
  
  job_status$user_mode <- 1
  job_status$demo_mode <- 0
  job_status$current_id <- job_status$new_id
  
  if (!is.null(job_status$new_id) && job_status$new_id != "") {
     reload_user_dataset(job_status$new_id)
  }
  
  if (!is.null(job_status$trigger_source) && job_status$trigger_source == "stepB") {
    job_status$results_version <- job_status$results_version + 1
  } else if (!is.null(job_status$trigger_source) && job_status$trigger_source == "cross_kingdom") {
    # Do nothing, stay on CK tab
  } else {
    updateTabsetPanel(session, "analysis_workflow", selected = "Upload and Analyze Kingdom-Specific (Bacterial or Fungal) Data")
  }
  removeModal()
}, ignoreInit = TRUE)

observeEvent(input$link_to_tutorial, {
  updateTabsetPanel(session, "CoMeDA", selected = "Tutorial")
  removeModal()
}, ignoreInit = TRUE)

output$result_overview_ui <- renderUI({
  source(paste(comedashinypath, "shinyR", "ui_analysis_resultoverview.R", sep = "/"), local = TRUE)$value
})

get_current_project_path <- reactive({ paste0(comedainvpath, "/", job_status$current_id) })
get_current_job_id <- reactive({ job_status$current_id })
get_current_job_mode <- reactive({ if (job_status$demo_mode == 1) "demo" else if (job_status$user_mode == 1) "user" else "unknown" })

source(paste(comedashinypath, "shinyR", "server_analysis_step1upload.R", sep = "/"), local = TRUE)
source(paste(comedashinypath, "shinyR", "server_analysis_step2params.R", sep = "/"), local = TRUE)
source(paste(comedashinypath, "shinyR", "server_analysis_step3execute.R", sep = "/"), local = TRUE)
source(paste(comedashinypath, "shinyR", "server_analysis_resultoverview.R", sep = "/"), local = TRUE)
source(paste(comedashinypath, "shinyR", "server_analysis_crosskingdom.R", sep = "/"), local = TRUE)
