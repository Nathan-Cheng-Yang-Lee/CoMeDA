## server_analysis_step1upload.R; CoMeDA v2.6; Step 1 Upload & Validation
## Modified: v2.6 - Added parameter reset logic to prevent drift on re-upload
##           v2.5 - Check existing files BEFORE transferring
##           v2.7 - Added Format Guide Modal (2025-12-07)

# ^=============================================================================
# Section 1.1: File Upload Handling with Overwrite Protection & State Reset
# =============================================================================

# ==============================================================================
# [NEW] Overwrite Warning Modal
# ==============================================================================
show_overwrite_warning_modal <- function() {
  showModal(modalDialog(
    title = tagList(
      tags$div(
        style = "padding: 10px; background-color: #ffc107; color: #856404;",
        icon("exclamation-triangle"), " Warning: Previous Analysis Detected"
      )
    ),

    div(style = "padding: 15px;",
        tags$p(style = "font-size: 16px; color: #333;",
               "You have already completed an analysis for this Job ID."),
        tags$p(style = "font-size: 14px; color: #666;",
               "Uploading new files will ", tags$strong("overwrite"), " the existing analysis results in the ",
               tags$code("analysis_result"), " folder."),
        hr(),
        tags$p(style = "font-size: 14px; color: #856404;",
               icon("lightbulb"), " Recommendations:"),
        tags$ul(style = "color: #555;",
                tags$li("To start a completely new analysis, ", tags$strong("refresh the page"), " to get a new Job ID."),
                tags$li("To continue with this Job ID and overwrite, click ", tags$strong("Proceed"), " below.")
        )
    ),

    footer = tagList(
      actionButton("cancel_overwrite", "Cancel", icon = icon("times"),
                   style = "background-color: #6c757d; color: white;"),
      actionButton("confirm_overwrite", "Proceed with Overwrite", icon = icon("check"),
                   style = "background-color: #dc3545; color: white;")
    ),

    easyClose = FALSE,
    size = "m"
  ))
}

# Define core transfer logic as functions to avoid duplication
execute_data_transfer <- function() {
  req(input$upload_data_file)
  req(job_status$current_id)
  
  tryCatch({
    # 1. Get info
    uploaded_files <- input$upload_data_file
    temp_paths <- uploaded_files$datapath
    file_names <- uploaded_files$name
    
    project_path <- paste0(comedainvpath, "/", job_status$current_id)
    raw_taxa_dir <- paste0(project_path, "/rawdata/taxafile")
    
    if (!dir.exists(raw_taxa_dir)) dir.create(raw_taxa_dir, recursive = TRUE)
    
    # 2. Clean old files (Confirmed overwrite)
    if (length(list.files(raw_taxa_dir)) > 0) {
      file.remove(list.files(raw_taxa_dir, full.names = TRUE))
    }
    
    # 3. Transfer new files
    final_paths <- file.path(raw_taxa_dir, file_names)
    file.copy(from = temp_paths, to = final_paths, overwrite = TRUE)

    unlink(temp_paths)
    
    # 4. Update Job Status
    file_extensions <- tools::file_ext(file_names)
    is_sequencing <- any(file_extensions %in% c("fastq", "fq", "gz"))
    is_taxatable <- length(file_names) == 1 && file_extensions[1] == "txt"
    
    if (!is_sequencing && !is_taxatable) {
      showNotification("Invalid file format!", type = "error")
      file.remove(final_paths) # Clean up invalid files
      return(NULL)
    }
    
    if (is_sequencing) {
      # Platform detection (Simplified)
      has_r1 <- any(grepl("R1|_1\\.", file_names))
      has_r2 <- any(grepl("R2|_2\\.", file_names))
      
      platform <- if(has_r1 && has_r2) "Illumina paired-end short reads" else "Pacbio / Nanopore single-end long-reads"
      n_samples <- if(has_r1 && has_r2) length(file_names)/2 else length(file_names)
      
      job_status$uploaded_files$data <- list(
        type = "sequencing",
        platform = platform,
        n_files = length(file_names),
        n_samples = floor(n_samples),
        file_names = file_names,
        file_paths = final_paths,
        upload_time = Sys.time()
      )
      msg <- paste0("Sequencing files uploaded! ", length(file_names), " files.")
    } else {
      # Taxatable
      taxa_table <- read.table(final_paths[1], header = TRUE, sep = "\t", check.names = FALSE, comment.char = "")
      job_status$uploaded_files$data <- list(
        type = "taxatable",
        n_files = 1,
        n_samples = ncol(taxa_table) - 1,
        n_taxa = nrow(taxa_table),
        file_names = file_names,
        file_paths = final_paths,
        upload_time = Sys.time(),
        data = taxa_table
      )
      msg <- "Taxa table uploaded successfully!"
    }
    
    # ==========================================================================
    # [CRITICAL FIX] Reset Step 2 & Step 3 status to prevent parameter drift
    # ==========================================================================
    job_status$auto_detected <- list(
      file_name_col = NULL, need_demultiplex = NULL, barcode_col = NULL,
      fprimer_col = NULL, rprimer_col = NULL, batches_col = NULL, comparison_cols = NULL
    )
    job_status$parameters <- list()
    job_status$step2_expanded <- FALSE
    job_status$step3_ready <- FALSE
    job_status$validation$deep_passed <- FALSE
    
    # Clear analysis state (if re-running)
    job_status$analysis_submitted <- FALSE
    job_status$analysis_state <- NULL
    # ==========================================================================
    
    showNotification(msg, type = "message")
    removeModal() # Close any open modal
    
  }, error = function(e) {
    showNotification(paste("Error saving files:", e$message), type = "error")
  })
}

execute_metadata_transfer <- function() {
  req(input$upload_metadata)
  req(job_status$current_id)
  
  tryCatch({
    uploaded_file <- input$upload_metadata
    
    if (tools::file_ext(uploaded_file$name) != "txt") {
      showNotification("Invalid metadata format! Please upload .txt", type = "error")
      return(NULL)
    }
    
    project_path <- paste0(comedainvpath, "/", job_status$current_id)
    raw_meta_dir <- paste0(project_path, "/rawdata/metadata")
    if (!dir.exists(raw_meta_dir)) dir.create(raw_meta_dir, recursive = TRUE)
    
    # Clean old files
    if (length(list.files(raw_meta_dir)) > 0) {
      file.remove(list.files(raw_meta_dir, full.names = TRUE))
    }
    
    # Transfer
    final_path <- file.path(raw_meta_dir, uploaded_file$name)
    file.copy(from = uploaded_file$datapath, to = final_path, overwrite = TRUE)
    
    # Read and Store
    metadata <- read.table(final_path, header = TRUE, sep = "\t", check.names = FALSE, comment.char = "", stringsAsFactors = FALSE)
    
    job_status$uploaded_files$metadata <- list(
      n_samples = nrow(metadata),
      n_features = ncol(metadata),
      file_name = uploaded_file$name,
      file_path = final_path,
      upload_time = Sys.time(),
      data = metadata
    )
    
    # ==========================================================================
    # [CRITICAL FIX] Reset Step 2 & Step 3 status to prevent parameter drift
    # ==========================================================================
    job_status$auto_detected <- list(
      file_name_col = NULL, need_demultiplex = NULL, barcode_col = NULL,
      fprimer_col = NULL, rprimer_col = NULL, batches_col = NULL, comparison_cols = NULL
    )
    job_status$parameters <- list()
    job_status$step2_expanded <- FALSE
    job_status$step3_ready <- FALSE
    job_status$validation$deep_passed <- FALSE
    
    # Clear analysis state (if re-running)
    job_status$analysis_submitted <- FALSE
    job_status$analysis_state <- NULL
    # ==========================================================================
    
    showNotification("Metadata uploaded successfully!", type = "message")
    removeModal()
    
  }, error = function(e) {
    showNotification(paste("Error saving metadata:", e$message), type = "error")
  })
}

# ^observeEvent: upload_data_file (TRIGGER)
observeEvent(input$upload_data_file, {
  req(job_status$current_id)

  # Check if in Demo mode
  if (!is.null(job_status$demo_mode) && job_status$demo_mode == 1) {
    showNotification(
      "File upload is disabled in Demo mode. Please switch to your user Job ID first.",
      type = "error",
      duration = 5
    )
    return()
  }

  # [NEW] Check if previous analysis exists - show warning
  if (isTRUE(job_status$analysis_completed)) {
    # Store the pending upload intent
    job_status$pending_data_upload <- TRUE
    show_overwrite_warning_modal()
    return()
  }
  
  execute_data_transfer()
})

# [NEW] Handle overwrite confirmation
observeEvent(input$confirm_overwrite, {
  removeModal()
  
  # Reset the completed flag
  job_status$analysis_completed <- FALSE
  job_status$analysis_submitted <- FALSE
  job_status$analysis_state <- NULL
  job_status$phase_status <- list()
  
  # Execute the pending upload
  if (isTRUE(job_status$pending_data_upload)) {
    execute_data_transfer()
    job_status$pending_data_upload <- FALSE
  }
})

# [NEW] Handle cancel
observeEvent(input$cancel_overwrite, {
  removeModal()
  job_status$pending_data_upload <- FALSE
  
  # Reset file input to clear selection
  shinyjs::reset("upload_data_file")
})

# ^observeEvent: confirm_data_overwrite (ACTION)
observeEvent(input$confirm_data_overwrite, {
  execute_data_transfer()
})


# ^observeEvent: upload_metadata (TRIGGER)
observeEvent(input$upload_metadata, {
  req(job_status$current_id)

  # Check if in Demo mode
  if (!is.null(job_status$demo_mode) && job_status$demo_mode == 1) {
    showNotification(
      "File upload is disabled in Demo mode. Please switch to your user Job ID first.",
      type = "error",
      duration = 5
    )
    return()
  }
  
  project_path <- paste0(comedainvpath, "/", job_status$current_id)
  raw_meta_dir <- paste0(project_path, "/rawdata/metadata")
  
  if (dir.exists(raw_meta_dir) && length(list.files(raw_meta_dir)) > 0) {
    showModal(modalDialog(
      title = tagList(icon("exclamation-triangle"), " Warning: Overwriting Metadata"),
      div(style = "color: #856404; font-weight: bold;", "This project already contains metadata."),
      p("Uploading new metadata will DELETE the existing metadata file."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_meta_overwrite", "Yes, Overwrite", class = "btn-danger")
      )
    ))
  } else {
    execute_metadata_transfer()
    shinyjs::reset("upload_metadata")
  }
})

# ^observeEvent: confirm_meta_overwrite (ACTION)
observeEvent(input$confirm_meta_overwrite, {
  execute_metadata_transfer()
})


# ^output: data_file_info_display
output$data_file_info_display <- renderUI({
  req(job_status$uploaded_files$data)
  data_info <- job_status$uploaded_files$data
  
  if (data_info$type == "sequencing") {
    tagList(
      tags$div(style = "font-size: 14px; line-height: 1.8;",
        tags$p(tags$strong("Type: "), "Sequencing"),
        tags$p(tags$strong("Platform: "), data_info$platform),
        tags$p(tags$strong("Files: "), paste0(data_info$n_files, " files")),
        tags$p(tags$strong("Samples: "), paste0(data_info$n_samples, " (estimated)"))
      )
    )
  } else {
    tagList(
      tags$div(style = "font-size: 14px; line-height: 1.8;",
        tags$p(tags$strong("Type: "), "Taxa-table"),
        tags$p(tags$strong("Samples: "), data_info$n_samples),
        tags$p(tags$strong("Taxa: "), data_info$n_taxa)
      )
    )
  }
})

# ^output: metadata_info_display
output$metadata_info_display <- renderUI({
  req(job_status$uploaded_files$metadata)
  meta_info <- job_status$uploaded_files$metadata
  tagList(
    tags$div(style = "font-size: 14px; line-height: 1.8;",
      tags$p(tags$strong("Samples: "), meta_info$n_samples),
      tags$p(tags$strong("Features: "), meta_info$n_features)
    )
  )
})

# ^output: data_file_uploaded & metadata_uploaded flags
output$data_file_uploaded <- reactive({ !is.null(job_status$uploaded_files$data) })
output$metadata_uploaded <- reactive({ !is.null(job_status$uploaded_files$metadata) })
outputOptions(output, "data_file_uploaded", suspendWhenHidden = FALSE)
outputOptions(output, "metadata_uploaded", suspendWhenHidden = FALSE)

# ^output: is_demo_mode flag for UI conditional display
output$is_demo_mode <- reactive({ 
  !is.null(job_status$demo_mode) && job_status$demo_mode == 1 
})
outputOptions(output, "is_demo_mode", suspendWhenHidden = FALSE)

# ^observeEvent: remove buttons (Clear job_status)
observeEvent(input$remove_data_file, {
  job_status$uploaded_files$data <- NULL
  job_status$validation$simple_passed <- FALSE
  job_status$step2_expanded <- FALSE
})

observeEvent(input$remove_metadata, {
  job_status$uploaded_files$metadata <- NULL
  job_status$validation$simple_passed <- FALSE
  job_status$step2_expanded <- FALSE
})

# ^=============================================================================
# Section 1.2: Consistency Check (Merged Logic)
# =============================================================================

both_files_uploaded <- reactive({
  !is.null(job_status$uploaded_files$data) && !is.null(job_status$uploaded_files$metadata)
})
output$show_validation_status <- reactive({ both_files_uploaded() })
outputOptions(output, "show_validation_status", suspendWhenHidden = FALSE)

observeEvent(both_files_uploaded(), {
  req(both_files_uploaded())
  
  data_info <- job_status$uploaded_files$data
  metadata <- job_status$uploaded_files$metadata$data
  metadata_cols <- colnames(metadata)
  validation_errors <- c()
  
  # 1. Check sample.id column
  if (metadata_cols[1] != "sample.id") {
    validation_errors <- c(validation_errors, paste0("First column must be 'sample.id', found '", metadata_cols[1], "'"))
  }
  
  # 2. Check sample.id content
  if (length(validation_errors) == 0) {
    sample_ids <- metadata[[1]]
    if (any(duplicated(sample_ids))) validation_errors <- c(validation_errors, "Duplicate sample.ids found.")
    if (any(grepl(" ", sample_ids))) validation_errors <- c(validation_errors, "sample.id cannot contain spaces.")
  }
  
  # 3. Check Consistency (Sequencing vs Taxatable)
  if (length(validation_errors) == 0) {
    if (data_info$type == "sequencing") {
      # Sequencing Mode: Check file.name match
      if (!"file.name" %in% metadata_cols) {
        validation_errors <- c(validation_errors, "Metadata missing 'file.name' column.")
      } else {
        expected_files <- unique(trimws(unlist(strsplit(as.character(metadata$file.name), ","))))
        expected_files <- expected_files[expected_files != ""]
        uploaded_files <- data_info$file_names
        
        missing_files <- setdiff(expected_files, uploaded_files)
        if (length(missing_files) > 0) {
          validation_errors <- c(validation_errors, paste0("Missing files defined in metadata: ", paste(head(missing_files, 2), collapse=", "), "..."))
        }
      }
    } else {
      # Taxatable Mode: Check sample columns
      taxa_table <- data_info$data
      taxa_samples <- colnames(taxa_table)[-1]
      sample_ids <- metadata[[1]]
      
      missing_in_taxa <- setdiff(sample_ids, taxa_samples)
      if (length(missing_in_taxa) > 0) validation_errors <- c(validation_errors, "Some metadata samples not found in taxa table.")
      
      missing_in_meta <- setdiff(taxa_samples, sample_ids)
      if (length(missing_in_meta) > 0) validation_errors <- c(validation_errors, "Some taxa table samples not found in metadata.")
    }
  }
  
  # 4. Check Comparison Column
  if (length(validation_errors) == 0) {
    if (length(grep("^comparison", metadata_cols)) == 0) {
      validation_errors <- c(validation_errors, "Metadata missing 'comparison' column.")
    }
  }
  
  # Store Result
  if (length(validation_errors) == 0) {
    job_status$validation$simple_passed <- TRUE
    job_status$validation$simple_errors <- NULL
    job_status$step2_expanded <- TRUE
    showNotification("Validation passed! Proceed to Step 2.", type = "message")
  } else {
    job_status$validation$simple_passed <- FALSE
    job_status$validation$simple_errors <- validation_errors
    job_status$step2_expanded <- FALSE
    showNotification("Validation failed.", type = "error")
  }
}, ignoreInit = TRUE)

# ^output: validation_status_display
output$validation_status_display <- renderUI({
  req(both_files_uploaded())
  if (job_status$validation$simple_passed) {
    div(class = "alert alert-success", icon("check-circle"), " Validation Passed. Proceed to Step 2.")
  } else {
    div(class = "alert alert-danger", 
        h4(icon("exclamation-triangle"), " Validation Failed"),
        tags$ul(lapply(job_status$validation$simple_errors, tags$li))
    )
  }
})

# ^Section 1.3: Reset All (Kept simple)
observeEvent(input$reset_all_btn, {
  job_status$uploaded_files$data <- NULL
  job_status$uploaded_files$metadata <- NULL
  job_status$validation$simple_passed <- FALSE
  job_status$step2_expanded <- FALSE
  
  # Also clean up backend data on full reset?
  # Optional: For safety, "Reset All" could also trigger folder cleaning
  # But usually "Reset" means "Reset UI". Let's keep it simple for now.
  
  showNotification("All files reset.", type = "warning")
})

# ^=============================================================================
# Section 1.4: Format Guide Modal [NEW]
# =============================================================================

observeEvent(input$format_guide_btn, {
  showModal(
    modalDialog(
      title = tagList(
        tags$div(
          icon("circle-info"),
          " File Format Guide",
          style = "color: whitesmoke; font-size: 18px; font-weight: bold; background-color: #E95420; padding: 10px 15px; margin: -16px -16px 15px -16px; border-radius: 5px 5px 0 0;"
        )
      ),
      
      # Content with embedded image
      fluidRow(
        column(12,
          tags$div(
            style = "text-align: center; padding: 10px;",
            tags$img(
              src = "file_info_overview.png",  # Image should be in www/ folder
              alt = "Format Guide",
              style = "max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);"
            )
          )
        ),
        column(12,
          tags$hr(),
          tags$div(
            style = "padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5(icon("lightbulb"), " Quick Tips:", style = "color: #5cb85c; margin-bottom: 10px;"),
            tags$ul(
              style = "margin-bottom: 0;",
              tags$li("Metadata file must be tab-delimited (.txt)"),
              tags$li("First column must be named 'sample.id'"),
              tags$li("Comparison column(s) must start with 'comparison'"),
              tags$li("For sequencing data, include 'file.name' column"),
              tags$li("Other columns: 'barcode', 'Fprimer', 'Rprimer', 'batches'")
            )
          )
        )
      ),
      
      size = "l",
      easyClose = TRUE,
      footer = tagList(
        modalButton("Close", icon = icon("times"))
      )
    )
  )
}, ignoreInit = TRUE)
# Section 1.4: Format Guide Modal$

# Download Demo Datasets Button -> Jump to Tutorial / Quick Start
observeEvent(input$download_demo_btn, {
  updateNavbarPage(session, "CoMeDA", selected = "Tutorial")
  updateNavlistPanel(session, "tutorial_nav", selected = "quick_start_demo")
})
