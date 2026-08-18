## ui_analysis_crosskingdom.R
## Cross-Kingdom / Paired Correlation Analysis
## Layout: Block 1 (Input) -> Block 2 (Summary) -> Block 3 (Plot/Download)
## Modified: 2025.12.15 (Removed TabsetPanel, Simplified Layout)

tagList(
  
  # ^Title Section
  fluidRow(
    column(12, br()),	   
    column(12,
           h3("Cross-Kingdom Correlation (Bacteria and Fungi) & Paired-Condition (pre- and pro-treatment) Correlation Analysis", 
              style = "color: #333; font-weight: bold; border-bottom: 2px solid forestgreen; padding-bottom: 10px; margin-bottom: 20px;")
    )
  ),

  # ^Description Section
  fluidRow(
    column(12,
           div(style = "background-color: #f0f7ff; border-left: 4px solid #2c3e50; padding: 15px; margin-bottom: 20px; border-radius: 0 5px 5px 0;",
               h5(icon("info-circle"), " About This Analysis", style = "color: #2c3e50; font-weight: bold; margin-top: 0;"),
               p(style = "margin-bottom: 10px; color: #333;",
                 "This module performs ", tags$b("Cross-Dataset Correlation Analysis"), " to identify associations between bacterial (16S) and fungal (ITS) communities or two different conditions from two datasets. Two primary use cases are supported:"
               ),
               tags$ul(style = "margin-bottom: 5px; color: #333;",
                 tags$li(
                   tags$b("Cross-Kingdom Analysis: "), 
                   "Correlate bacteria and fungi from the ", tags$em("same samples"), ". ",
                   tags$span(style = "color: #666;", 
                     "Example: 16S data (Case vs Control) + ITS data (Case vs Control) from identical subjects."
                   )
                 ),
                 tags$li(
                   tags$b("Paired-Condition Analysis: "), 
                   "Compare microbiome correlations across different conditions or time points. ",
                   tags$span(style = "color: #666;", 
                     "Example: Pre-treatment (Case vs Control) vs Post-treatment (Case vs Control)."
                   )
                 )
               ),
               p(style = "margin-bottom: 0; font-size: 0.9em; color: #666;",
                 icon("lightbulb"), " Tip: Ensure sample IDs are consistent between two datasets for accurate correlation analysis."
               )
           )
    )
  ),
  
  # ^BLOCK 1: Data Input & Analysis Configuration
  fluidRow(
    column(12,
           wellPanel(
             style = "background-color: #f8f9fa; border: 2px solid #2c3e50; border-radius: 5px; padding: 20px;",
             
             # Block Title with Demo Button on Right
             fluidRow(
               column(6,
                      h4(icon("database"), "1. Data Input & Configuration",
                         style = "font-weight: bold; color: #2c3e50; margin-top: 5px; margin-bottom: 0;")
               ),
               column(3, align = "right",
                      actionButton("ck_use_demo",
                                   label = tagList(icon("person-chalkboard"), "Use the example data for demonstration"),
                                   style = "background-color: #E95420; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2); width: 98%;"
                      )
               ),
               column(3, align = "right",
                      actionButton("ck_import_job_id",
                                   label = tagList(icon("circle-check"), "Change to the current / other job id"),
                                   style = "background-color: dimgrey; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2); width: 100%;"
                      )
               )
             ),
             
             hr(style = "border-top: 1px solid #ddd; margin-top: 10px; margin-bottom: 15px;"),
             
             # Input Mode Selection
             fluidRow(
               column(12, uiOutput("ck_input_config_ui"))
             ),
             
             hr(style = "border-top: 1px dashed #ccc; margin-top: 5px; margin-bottom: 15px;"),
             
#             # --- Mode A Parameters ---
             conditionalPanel(
               condition = "input.ck_input_mode == 'uuid' && output.ck_is_demo_mode == false",
               fluidRow(
                 column(3, selectInput("ck_taxalevel_a", "Taxa Levels:", choices = c("Phylum"="phylum", "Class"="class", "Order"="order", "Family"="family", "Genus"="genus", "Species"="species"), selected = c("genus", "species"), multiple = TRUE)),
                 column(3, numericInput("ck_prev_bac_a", "Dataset1 Min Prevalence:", value = 0.3, min = 0, max = 1, step = 0.05)),
                 column(3, numericInput("ck_prev_fun_a", "Dataset2 Min Prevalence:", value = 0.2, min = 0, max = 1, step = 0.05)),
                 column(3, div(style = "margin-top: 25px;", actionButton("ck_run_analysis_a", "Submit Analysis", icon = icon("rocket"), style = "color: #fff; background-color: #e95420; border-color: #d43f3a; width: 100%; font-size: 16px; font-weight: bold; box-shadow: 0 2px 5px rgba(0,0,0,0.2);")))
               )
             ),
             
             # --- Mode B Parameters ---
             conditionalPanel(
               condition = "input.ck_input_mode == 'upload' && output.ck_is_demo_mode == false",
               fluidRow(
                 column(9,
                        fluidRow(
                          column(3, selectInput("ck_taxalevel_b", "Taxa Levels:", choices = c("Phylum"="phylum", "Class"="class", "Order"="order", "Family"="family", "Genus"="genus", "Species"="species"), selected = "genus", multiple = TRUE)),
                          column(3, numericInput("ck_min_prop", "Min Proportion:", value = 0.0001, min = 0, max = 1, step = 0.0001)),
                          column(3, numericInput("ck_prev_bac_b", "Bac Min Prev:", value = 0.3, min = 0, max = 1, step = 0.05)),
                          column(3, numericInput("ck_prev_fun_b", "Fun Min Prev:", value = 0.2, min = 0, max = 1, step = 0.05))
                        )
                 ),
                 column(3,
                        div(style = "margin-top: 25px;",
                            actionButton("ck_run_analysis_b", "Submit Analysis", icon = icon("rocket"),
                                         style = "color: #fff; background-color: #e95420; border-color: #d43f3a; width: 100%; font-size: 16px; font-weight: bold; box-shadow: 0 2px 5px rgba(0,0,0,0.2);")
                        )
                 )
               )
             ),
             
             # Status Message
             div(style = "margin-top: 15px;", uiOutput("ck_status_message"))
           )
    )
  ),
  
  # ^BLOCK 1.5: Demo Dataset Selection (Only visible in Demo Mode)
  conditionalPanel(
    condition = "output.ck_is_demo_mode == true",
    br(),
    fluidRow(
      column(12,
             wellPanel(
               style = "background-color: #fff8e1; border: 2px solid #E95420; border-radius: 5px; padding: 15px;",
               fluidRow(
                 # Column 1: SelectInput for demo dataset
                 column(4,
                        h5(icon("flask"), " Select Demo Dataset:", style = "color: #E95420; font-weight: bold; margin-top: 0;"),
                        selectInput("ck_demo_dataset_select", 
                                    label = NULL,
                                    choices = c("Cross-Kingdom (Crohn's Disease)" = "cross_kingdom_ck",
                                                "Paired-Condition (Saliva & Subgingival)" = "cross_kingdom_pc"),
                                    selected = "cross_kingdom_ck",
                                    width = "100%")
                 ),
                 # Column 2: Brief description
                 column(5,
                        h5(icon("info-circle"), " Dataset Description:", style = "color: #555; font-weight: bold; margin-top: 0;"),
			div(style = "background-color: white; padding: 10px; border-radius: 5px; border-left: 3px solid #1565c0;",
			    tags$p(style = "margin: 0; font-size: 13px;",
			      "1. ", tags$strong("Cross-Kingdom Analysis :"), " Bacteria (16S) + Fungi (ITS) from ", tags$em("Pediatric Crohn's Disease"), " samples."	   
			    ),
			    tags$p(style = "margin: 0; font-size: 13px;",
			      "2. ", tags$strong("Paired-Condition Analysis :"), " Saliva vs Subgingival from ", tags$em("Periodontitis"), " samples."
			    )
			)
                 ),
                 # Column 3: More details link
                 column(3,
                        h5(icon("book-open"), " Learn More:", style = "color: #555; font-weight: bold; margin-top: 0;"),
                        div(style = "padding-top: 5px;",
                            actionLink(
                              inputId = "ck_demo_info_btn",
                              label = tagList(icon("info-circle"), " This is the demo mode. Click here for more details."),
                              style = "color: forestgreen; font-weight: bold; text-decoration: none; font-size: 14px;"
                            )
                        )
                 )
               )
             )
      )
    )
  ),

  # ^BLOCK 2: Parameter Summary
  conditionalPanel(
    condition = "output.ck_analysis_finished == true",
    br(),
    fluidRow(column(12, uiOutput("ck_param_summary_ui")))
  ),
  
  # ^BLOCK 3: Correlation Network Plot
  conditionalPanel(
    condition = "output.ck_analysis_finished == true",
    br(),
    fluidRow(
      column(12,
             wellPanel(
               style = "background-color: #fff; border: 2px solid #E95420; padding: 20px; min-height: 600px;",
               h4(icon("project-diagram"), "3. Correlation Network Visualization", 
                  style = "font-weight: bold; color: #E95420; margin-top: 0; border-bottom: 1px solid #ddd; padding-bottom: 10px; margin-bottom: 15px;"),
               
               fluidRow(
                 # Left: Plot (10 cols) - Increased height
                 column(10, 
                        div(style = "border: 1px solid #ddd; background-color: white; padding: 5px; border-radius: 5px; height: 950px; overflow: hidden; position: relative;",
                            girafeOutput("ck_network_plot", height = "100%", width = "100%")
                        )
                 ),
                 
                 # Right: Settings (2 cols) - Increased height
                 column(2, 
                        div(style = "background-color: #f1f1f1; padding: 10px; border-radius: 5px; border: 1px solid #ccc; height: 950px; overflow-y: auto; font-size: 0.9em;",
                            
                            h5(icon("filter"), " Data", style="border-bottom: 2px solid #999; padding-bottom: 5px; font-weight:bold;"),
                            selectInput("ck_plot_level", "Taxa Level:", choices = NULL),
                            selectInput("ck_plot_comp", "Comparison:", choices = NULL),
                            selectInput("ck_plot_event", "Group/Event:", choices = NULL, multiple = TRUE),
                            
                            h5(icon("sliders-h"), " Thresholds", style="border-bottom: 2px solid #999; padding-bottom: 5px; margin-top: 20px; font-weight:bold;"),
                            radioButtons("ck_plot_ptype", "Edge p-value:", choices = c("Raw" = "raw", "Adjusted (BH)" = "adjusted"), selected = "raw", inline = TRUE),
                            numericInput("ck_plot_pcut", "P-value <", value = 0.05, step = 0.01),
                            numericInput("ck_plot_corrcut", "Corr >", value = 0.3, step = 0.1),
                            
                            h5(icon("network-wired"), " Topology", style="border-bottom: 2px solid #999; padding-bottom: 5px; margin-top: 20px; font-weight:bold;"),
                            numericInput("ck_plot_topn", "Top N:", value = 50, min = 10),
			    tags$div(
			      style = "display: flex; align-items: center; margin-bottom: 3px;",
                              tags$label("Focal Taxon:", style = "font-weight: normal; margin-right: 5px;"),
                              actionLink("ck_focal_taxon_info", label = NULL, icon = icon("info-circle"), style = "color: #0275d8; font-size: 14px;")	     
			    ),
                            selectizeInput("ck_plot_focal", label = NULL, choices = NULL, multiple = FALSE, options = list(placeholder = "Search...")),
                            
                            h5(icon("draw-polygon"), " Style", style="border-bottom: 2px solid #999; padding-bottom: 5px; margin-top: 20px; font-weight:bold;"),
                            selectInput("ck_plot_layout", "Algorithm:", choices = c("Fruchterman-Reingold" = "fr", "Kamada-Kawai" = "kk", "Nicely" = "nicely", "Graphopt" = "graphopt", "Grid" = "grid", "Circle" = "circle")),
                            checkboxInput("ck_plot_unified", "Unified Layout", value = TRUE),
                            checkboxInput("ck_plot_labels", "Show Labels", value = TRUE),
                            
                            hr(style="border-top: 1px solid #999; margin: 15px 0;"),
                            
                            actionButton("ck_update_plot", "Update Plot", icon = icon("sync"), 
                                         style = "color: #fff; background-color: #E95420; border-color: #d43f3a; width: 100%; margin-bottom: 10px;"),
                            
			    uiOutput("ck_download_btn_ui")
                        )
                 )
               )
             )
      )
    )
  ),
  
  br()
)
