## ui_analysis_step1upload.R; CoMeDA v2.2; Step 1.1 Upload Area
## Generate on 2025.11.24
## Modified: 2025.11.24 - Added validation status display

# ^Step 1.1 upload area
tagList(
    # ^Demo mode notice (conditionalPanel)
  conditionalPanel(
    condition = "output.is_demo_mode == true",
    fluidRow(
      column(12,
             div(
               style = "background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 5px; padding: 20px; margin-bottom: 20px;",
               h4(icon("info-circle"), " Demo Mode Active", style = "color: #856404; margin-top: 0;"),
               p("You are currently using the demonstration dataset. File upload is disabled in Demo mode.", 
                 style = "color: #856404; margin-bottom: 10px;"),
               p(strong("To upload your own data:"), " Click 'Change to the current / other job id' button above and return to your user mode.",
                 style = "color: #856404; margin-bottom: 0;")
             )
      )
    ),
    hr(style = "border-top: 1px solid #ddd; margin-top: 30px; margin-bottom: 30px;")
  ),
  # Demo mode notice$
  
  # ^Upload area (conditionalPanel)
  conditionalPanel(
    condition = "output.is_demo_mode == false",
  
  # ^step 1 title
  fluidRow(
    column(12,
	   h3("Upload and Analyze Kingdom-Specific (Bacteria or Fungal) data",
	      style = "color: #333;
	               font-weight: bold;
                       border-bottom: 2px solid forestgreen;
                       padding-bottom: 10px;
                       margin-bottom: 20px;")
    ),
    column(12, br()),	   
    column(12,
           h4("Step 1: Upload Data Files", 
              style = "color: #333;
                       padding-bottom: 10px; 
                       margin-bottom: 20px;")
    ),
    column(12,
	   h5("We suggest a minimum of 10 samples per group for optimal performance. Analyses with fewer samples may yield less stable results.")
    )
  ),
  # step 1 title$
  
  # ^upload sections side by side
  fluidRow(
    
    # ^left side: data file upload
    column(6,
           
           # ^initial state - file input
           conditionalPanel(
             condition = "output.data_file_uploaded == false",
             wellPanel(
               style = "background-color: #f9f9f9; 
                        border: 1px solid #ddd; 
                        border-radius: 4px;
                        min-height: 320px;",
               
               fluidRow(
                 column(12,
                        h4(icon("file"), " Upload Data File (Required)", 
                           style = "color: #333; font-weight: bold; margin-bottom: 15px;")
                 )
               ),
               
               fluidRow(
                 column(12,
                        fileInput(
                          "upload_data_file",
                          label = NULL,
                          multiple = TRUE,
                          accept = c(".fastq", ".fq", ".fastq.gz", ".fq.gz", ".txt"),
                          width = "100%",
                          buttonLabel = "Browse...",
                          placeholder = "No file selected"
                        )
                 )
               ),
               
               fluidRow(
                 column(12,
                        tags$div(
                          style = "color: #666; font-size: 14px; margin-top: 10px;",
                          tags$strong("Accepted formats:"),
                          tags$ul(
                            style = "margin-top: 5px;",
                            tags$li("Sequencing: .fastq, .fq, .fastq.gz, .fq.gz"),
                            tags$li("Taxa-table: .txt")
                          )
                        )
                 )
               )
             )
           ),
           # initial state - file input$
           
           # ^uploaded state - show info
           conditionalPanel(
             condition = "output.data_file_uploaded == true",
             wellPanel(
               style = "background-color: #e8f5e9; 
                        border: 2px solid #4caf50; 
                        border-radius: 4px;
                        min-height: 320px;",
               
               fluidRow(
                 column(10,
                        h4(icon("check-circle", style = "color: forestgreen;"), 
                           " Data File",
                           style = "color: #333; font-weight: bold; margin-bottom: 15px;")
                 ),
                 column(2, 
                        align = "right",
                        actionButton(
                          "remove_data_file",
                          label = NULL,
                          icon = icon("times"),
                          style = "color: whitesmoke; 
                                   background-color: firebrick; 
                                   font-size: 14px; 
                                   width: 100%;
                                   padding: 6px;"
                        )
                 )
               ),
               
               fluidRow(
                 column(12,
                        uiOutput("data_file_info_display")
                 )
               )
             )
           )
           # uploaded state - show info$
    ),
    # left side: data file upload$
    
    # ^right side: metadata upload
    column(6,
           
           # ^initial state - file input
           conditionalPanel(
             condition = "output.metadata_uploaded == false",
             wellPanel(
               style = "background-color: #f9f9f9; 
                        border: 1px solid #ddd; 
                        border-radius: 4px;
                        min-height: 320px;",
               
               fluidRow(
                 column(12,
                        h4(icon("table"), " Upload Metadata (Required)", 
                           style = "color: #333; font-weight: bold; margin-bottom: 15px;")
                 )
               ),
               
               fluidRow(
                 column(12,
                        fileInput(
                          "upload_metadata",
                          label = NULL,
                          multiple = FALSE,
                          accept = c(".txt"),
                          width = "100%",
                          buttonLabel = "Browse...",
                          placeholder = "No file selected"
                        )
                 )
               ),
               
               fluidRow(
                 column(12,
                        tags$div(
                          style = "color: #666; font-size: 14px; margin-top: 10px;",
                          tags$strong("Accepted format:"), " .txt (tab-delimited)",
                          br(),
			  tags$strong("Required columns:"),
                          tags$ul(
                            style = "margin-top: 5px;",
			    tags$li(tags$code("sample.id"), " - First column (unique identifier)"),
			    tags$li(tags$code("comparison"), " or ", tags$code("comparison.1"), " - Primary grouping variable"),
			    tags$li(tags$code("file.name"), " - Fastq file names (", tags$span("only for sequencing data", style = "color: #e95420;"), ")")
                          ),
			  tags$strong("Note:"), " Hyphens (-) in sample.id will be converted to dots (.) during analysis"
                        )
                 )
               )
             )
           ),
           # initial state - file input$
           
           # ^uploaded state - show info
           conditionalPanel(
             condition = "output.metadata_uploaded == true",
             wellPanel(
               style = "background-color: #e8f5e9; 
                        border: 2px solid #4caf50; 
                        border-radius: 4px;
                        min-height: 320px;",
               
               fluidRow(
                 column(10,
                        h4(icon("check-circle", style = "color: forestgreen;"), 
                           " Metadata",
                           style = "color: #333; font-weight: bold; margin-bottom: 15px;")
                 ),
                 column(2, 
                        align = "right",
                        actionButton(
                          "remove_metadata",
                          label = NULL,
                          icon = icon("times"),
                          style = "color: whitesmoke; 
                                   background-color: firebrick; 
                                   font-size: 14px; 
                                   width: 100%;
                                   padding: 6px;"
                        )
                 )
               ),
               
               fluidRow(
                 column(12,
                        uiOutput("metadata_info_display")
                 )
               )
             )
           )
           # uploaded state - show info$
    )
    # right side: metadata upload$
    
  ),
  # upload sections side by side$
  
  br(),
  
  # ^NEW: validation status display
  conditionalPanel(
    condition = "output.show_validation_status == true",
    fluidRow(
      column(12,
             uiOutput("validation_status_display")
      )
    ),
    br()
  ),
  # validation status display$
  
  # ^reset button section
  # ===== v2.4.3 MODIFICATION - Add format guide button =====
  fluidRow(
    column(2, offset = 6, 
           align = "center",
	   # Download Demo Datasets Button
	   actionButton(
           "download_demo_btn",
           label = "Download Demo Datasets",
           icon = icon("download"),
           style = "color: white; background-color: #E95420; border-color: #E95420; margin-bottom: 10px;",
           width = "98%"
         )
    ),
    column(2,
	   align = "center",
	   # Format Guide Button
           actionButton(
             "format_guide_btn",
             label = "View File Format Guide",
             icon = icon("circle-info"),
             style = "color: #333; background-color: #e2e6ea; border-color: #dae0e5; margin-bottom: 10px;",
             width = "98%"
           )
    ),	   
    column(2, 
           align = "center",
           # Reset All Button
           actionButton(
             "reset_all_btn",
             label = "Reset All",
             icon = icon("rotate-left"),
             style = "color: whitesmoke; 
                      background-color: dimgrey; 
                      font-size: 14px; 
                      padding: 8px 20px;
                      width: 98%;"
           )
    )
  ),
  # ===== v2.4.3 MODIFICATION END =====
  # reset button section$
  
  hr(style = "border-top: 1px solid #ddd; margin-top: 30px; margin-bottom: 30px;")
  )
  # Upload area (conditionalPanel)$
)
# Step 1.1 upload area$
