## ui_analysis_resultoverview_download.R
## Step B: Download Tab Structure (Redesigned)
## Updated: 2025-12-07
## Changes: Taxa Community 3 modes, Alpha metric, Beta method/axis, Network multiple events, Func ZIP

tagList(
  br(),
  
  # ^1. Common Settings
  fluidRow(
    column(12,
           div(style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; border: 1px solid #dee2e6;",
               h4(icon("sliders-h"), " Common Settings", style="font-weight:bold; margin-top:0; color:#495057; border-bottom: 2px solid #dee2e6; padding-bottom: 10px;"),
               p("These settings apply to all visualizations and downloads.", style="color: #666; font-size: 0.9em; margin-bottom: 15px;"),
               fluidRow(
                 column(6, selectInput("dl_global_taxalevel", "Taxa Level:", choices = NULL, width = "100%")),
                 column(6, selectInput("dl_global_comparecol", "Comparison Column:", choices = NULL, width = "100%"))
               )
           )
    )
  ),
  
  # ^2. One-Click Download
  fluidRow(
    column(12,
           div(style="background-color: #d4edda; padding: 15px; border: 1px solid #c3e6cb; border-radius: 5px; margin-bottom: 20px; display: flex; align-items: center; justify-content: space-between;",
               div(
                 h4(icon("file-archive"), " One-Click Download", style="color: #155724; margin: 0; font-weight: bold;"),
                 span("Download all Tables, Plots (with default parameters), and PDF Report in a single ZIP file.", style="color: #155724;")
               ),
               downloadButton("dl_master_zip", "Download Complete Package (.zip)", class = "btn-success", style="font-weight: bold;")
           )
    )
  ),
  
  # ^3. Core Data & Results (Gray)
  fluidRow(
    column(12,
           wellPanel(style = "background-color: #fff; border-left: 5px solid #6c757d;",
                     h4(icon("table"), "3.1 Core Data & Results", style="margin-top:0; color: #6c757d; font-weight:bold;"),
                     p("Includes: Raw Counts, Normalized Data (CLR), Batch Corrected Data, Metadata, DAM Results, Correlation Tables, and Functional Predictions.", style="color: #666; font-size: 0.9em;"),
                     hr(),
                     fluidRow(
                       column(12, 
                              downloadButton("dl_tables_zip", "Download All Tables (.zip)", style="width: 200px; color: #333;")
                       )
                     )
           )
    )
  ),
  
  # ^4. Visualization Export (SteelBlue)
  fluidRow(
    column(12,
           wellPanel(style = "background-color: #fff; border-left: 5px solid steelblue;",
                     h4(icon("image"), "3.2 Visualization Export", style="margin-top:0; color: steelblue; font-weight:bold;"),
                     p("Configure parameters for each visualization. These settings are used for PDF Report generation.", style="color: #666; font-size: 0.9em;"),
                     
                     # ========== 1. Taxa Community ==========
                     div(style="border: 1px solid #ddd; padding: 15px; border-radius: 5px; margin-bottom: 15px; background-color: #fafafa;",
                         h5(icon("users"), " 1. Taxa Community", style="font-weight:bold; margin-bottom: 15px;"),
                         
                         # Shared Parameters
                         div(style="background-color: #e9ecef; padding: 10px; border-radius: 5px; margin-bottom: 15px;",
                             tags$label("Shared Parameters:", style="font-weight:bold; color: #495057;"),
                             fluidRow(
                               column(6, numericInput("dl_hm_min_abund", "Min Abundance %:", 1, min=0, step=0.5, width="100%")),
                               column(6, numericInput("dl_hm_min_prev", "Min Prevalence %:", 10, min=0, step=1, width="100%"))
                             )
                         ),
                         
                         # Abundance Mode
                         div(style="border: 1px solid #ccc; padding: 10px; border-radius: 5px; margin-bottom: 10px;",
                             fluidRow(
                               column(9,
                                      tags$label("Abundance Mode (Heatmap)", style="font-weight:bold; color: steelblue;"),
                                      fluidRow(
                                        column(4, numericInput("dl_hm_topn", "Top N:", 30, min=5, max=100, step=5, width="100%"))
                                      )
                               ),
                               column(3, style="display: flex; align-items: center; justify-content: flex-end; height: 80px;",
                                      downloadButton("dl_plot_taxa_abundance", "Download PNG", style="width: 130px;")
                               )
                             )
                         ),
                         
                         # DAM Mode
                         div(style="border: 1px solid #ccc; padding: 10px; border-radius: 5px; margin-bottom: 10px;",
                             fluidRow(
                               column(9,
                                      tags$label("DAM Mode (Heatmap)", style="font-weight:bold; color: steelblue;"),
                                      fluidRow(
                                        column(4, selectInput("dl_hm_dam_event", "Event:", choices = NULL, width="100%")),
                                        column(4, numericInput("dl_hm_dam_eff", "Effect Size >", 0.33, min=0, step=0.1, width="100%")),
                                        column(4, numericInput("dl_hm_dam_p", "P-value <", 0.05, min=0, max=1, step=0.01, width="100%"))
                                      )
                               ),
                               column(3, style="display: flex; align-items: center; justify-content: flex-end; height: 80px;",
                                      downloadButton("dl_plot_taxa_dam", "Download PNG", style="width: 130px;")
                               )
                             )
                         ),
                         
                         # Custom Mode (Violin)
                         div(style="border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
                             fluidRow(
                               column(9,
                                      tags$label("Custom Mode (Violin Plot)", style="font-weight:bold; color: steelblue;"),
                                      selectizeInput("dl_hm_custom_taxa", "Select Taxa (Max 15):", choices=NULL, multiple=TRUE, 
                                                     options=list(maxItems=15, placeholder="Select taxa..."), width="100%")
                               ),
                               column(3, style="display: flex; align-items: center; justify-content: flex-end; height: 80px;",
                                      downloadButton("dl_plot_taxa_custom", "Download PNG", style="width: 130px;")
                               )
                             )
                         )
                     ),
                     
                     # ========== 2. Alpha Diversity ==========
                     div(style="border: 1px solid #ddd; padding: 15px; border-radius: 5px; margin-bottom: 15px; background-color: #fafafa;",
                         h5(icon("chart-bar"), " 2. Alpha Diversity (Violin)", style="font-weight:bold; margin-bottom: 10px;"),
                         fluidRow(
                           column(9,
                                  fluidRow(
                                    column(4, selectInput("dl_alpha_metric", "Metric:", 
                                                          choices = c("Shannon" = "shannon", "Simpson" = "simpson"), 
                                                          selected = "shannon", width="100%"))
                                  ),
                                  helpText("Includes statistical test results (Wilcoxon rank-sum test).")
                           ),
                           column(3, style="display: flex; align-items: center; justify-content: flex-end;",
                                  downloadButton("dl_plot_alpha", "Download PNG", style="width: 130px;")
                           )
                         )
                     ),
                     
                     # ========== 3. Beta Diversity ==========
                     div(style="border: 1px solid #ddd; padding: 15px; border-radius: 5px; margin-bottom: 15px; background-color: #fafafa;",
                         h5(icon("project-diagram"), " 3. Beta Diversity (Scatter)", style="font-weight:bold; margin-bottom: 10px;"),
                         fluidRow(
                           column(9,
                                  fluidRow(
                                    column(4, selectInput("dl_beta_method", "Method:", 
                                                          choices = c("PCoA" = "PCoA", "PCA" = "PCA", "NMDS" = "NMDS"), 
                                                          selected = "PCoA", width="100%")),
                                    column(4, selectInput("dl_beta_xaxis", "X Axis:", choices = 1:5, selected = 1, width="100%")),
                                    column(4, selectInput("dl_beta_yaxis", "Y Axis:", choices = 1:5, selected = 2, width="100%"))
                                  ),
                                  helpText("Distance: Aitchison. Includes ellipses and PERMANOVA results."),
                                  uiOutput("dl_beta_axis_warning")
                           ),
                           column(3, style="display: flex; align-items: center; justify-content: flex-end;",
                                  downloadButton("dl_plot_beta", "Download PNG", style="width: 130px;")
                           )
                         )
                     ),
                     
                     # ========== 4. Correlation Network ==========
                     div(style="border: 1px solid #ddd; padding: 15px; border-radius: 5px; margin-bottom: 15px; background-color: #fafafa;",
                         h5(icon("share-alt"), " 4. Correlation Network", style="font-weight:bold; margin-bottom: 10px;"),
                         fluidRow(
                           column(9,
                                  fluidRow(
                                    column(6, selectizeInput("dl_net_events", "Events (Multiple):", choices = NULL, multiple = TRUE,
                                                             options = list(placeholder = "Select events..."), width="100%")),
                                    column(6, selectInput("dl_net_layout", "Layout Algorithm:", 
                                                          choices = c("Fruchterman-Reingold" = "fr", 
                                                                      "Circle" = "circle", 
                                                                      "Grid" = "grid", 
                                                                      "Kamada-Kawai" = "kk", 
                                                                      "Nicely" = "nicely", 
                                                                      "GraphOpt" = "graphopt"),
                                                          selected = "fr", width="100%"))
                                  ),
                                  fluidRow(
                                    column(4, numericInput("dl_net_p", "P-value <", 0.05, min=0, max=1, step=0.01, width="100%")),
                                    column(4, numericInput("dl_net_cor", "Correlation >", 0.4, min=0, max=1, step=0.1, width="100%")),
                                    column(4, numericInput("dl_net_topn", "Top N Taxa:", 50, min=10, max=200, step=10, width="100%"))
                                  ),
                                  fluidRow(
                                    column(12, radioButtons("dl_net_ptype", "Edge p-value:", choices = c("Raw" = "raw", "Adjusted (BH)" = "adjusted"), selected = "raw", inline = TRUE))
                                  ),
                                  helpText("Method: fastCCLasso correlation. Multiple events will be displayed in facets.")
                           ),
                           column(3, style="display: flex; align-items: center; justify-content: flex-end;",
                                  downloadButton("dl_plot_network", "Download PNG", style="width: 130px;")
                           )
                         )
                     ),
                     
                     # ========== 5. Functional Prediction ==========
                     div(style="border: 1px solid #ddd; padding: 15px; border-radius: 5px; background-color: #fafafa;",
                         h5(icon("dna"), " 5. Functional Prediction", style="font-weight:bold; margin-bottom: 10px;"),
                         fluidRow(
                           column(9,
                                  fluidRow(
                                    column(3, selectInput("dl_func_event", "Event:", choices = NULL, width="100%")),
                                    column(3, numericInput("dl_func_p", "P-value <", 0.05, min=0, max=1, step=0.01, width="100%")),
                                    column(3, numericInput("dl_func_eff", "Effect Size >", 0.0, min=0, step=0.1, width="100%")),
                                    column(3, numericInput("dl_func_prop", "Min Rel. Abund % >", 0.1, min=0, step=0.1, width="100%"))
                                  ),
                                  helpText("Database: KEGG Pathway. Method: PICRUSt2 + ALDEx2.")
                           ),
                           column(3, style="display: flex; align-items: center; justify-content: flex-end;",
                                  downloadButton("dl_plot_func", "Download ZIP", style="width: 130px;")
                           )
                         )
                     )
           )
    )
  ),
  
  # ^5. Summary Report (OrangeRed)
  fluidRow(
    column(12,
           wellPanel(style = "background-color: #fff; border-left: 5px solid #E95420;",
                     h4(icon("file-pdf"), "3.3 Summary Report", style="margin-top:0; color: #E95420; font-weight:bold;"),
                     p("Generates a PDF report using the parameters configured above in Visualization Export section.", style="color: #666; font-size: 0.9em;"),
                     hr(),
                     downloadButton("dl_report_pdf", "Download Report (.pdf)", style="background-color: #E95420; color: white; border-color: #d43f3a;")
           )
    )
  ),
  br()
)
