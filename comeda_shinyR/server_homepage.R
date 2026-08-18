## server_home.R
## Logic for Home Tab Buttons
## Updated: 2025-12-07

# 1. Start New Analysis -> Jump to Analysis / Step A
observeEvent(input$home_start_analysis, {
  # Update main navbar
  updateNavbarPage(session, "CoMeDA", selected = "Metabarcoding Analysis")
  # Update internal tabset to Step A
  updateTabsetPanel(session, "analysis_workflow", selected = "Step A: Upload & Parameters")
})

# 2. Load Demo Data -> Trigger Demo Mode & Jump to Step B
observeEvent(input$home_load_demo, {
  # Set Demo Mode
  job_status$user_mode <- 0
  job_status$demo_mode <- 1
  job_status$new_id <- ifelse(is.null(job_status$new_id), job_status$current_id, job_status$new_id)
  job_status$current_id <- "comedademo"
  
  if (exists("load_demo_dataset")) {
    load_demo_dataset()
  }

  job_status$results_version <- job_status$results_version + 1

  # Switch to Analysis Tab
  updateNavbarPage(session, "CoMeDA", selected = "Metabarcoding Analysis")
  
  # Jump to Step B directly (Assuming demo data is pre-analyzed)
  # We add a slight delay to allow the UI to render the tabset first
  shinyjs::delay(200, {
    updateTabsetPanel(session, "analysis_workflow", selected = "view_kingdom_specific_tab")
  })
  
  showNotification("Demo data loaded successfully!", type = "message", duration = 5)
})

# 3. Download Demo Datasets -> Jump to Tutorial / Quick Start
observeEvent(input$home_download_demo, {
  updateNavbarPage(session, "CoMeDA", selected = "Tutorial")
  updateNavlistPanel(session, "tutorial_nav", selected = "quick_start_demo")
  shinyjs::runjs("window.scrollTo(0, 0);")
})

# 4. View Tutorial -> Jump to Tutorial Tab / Analysis Workflow tab
observeEvent(input$home_view_tutorial, {
  updateNavbarPage(session, "CoMeDA", selected = "Tutorial")
  updateNavlistPanel(session, "tutorial_nav", selected = "analysis_workflow")
  shinyjs::runjs("window.scrollTo(0, 0);")
})
