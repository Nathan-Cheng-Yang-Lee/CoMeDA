## ui_analysis_resultoverview_analysistab.R
## Structure: Global Controls + Taxa + Diversity + Network + Function
## Updated: 2025-12-06 (Updated Min Proportion Label)

tagList(
  
  # 1. Global Controls
  br(),
  fluidRow(
    column(12,
           div(style = "background-color: #e9ecef; padding: 15px; border-radius: 5px; border: 1px solid #ced4da; margin-bottom: 20px;",
               h4(icon("sliders-h"), " Global Controls", style = "margin-top: 0; margin-bottom: 15px; font-weight: bold; color: #495057; border-bottom: 2px solid #dee2e6; padding-bottom: 10px;"),
               fluidRow(
                 column(2, selectInput("ar_taxalevel", label = tags$span(icon("layer-group"), " Taxa Level:"), choices = NULL, width = "100%")),
                 column(3, selectInput("ar_comparecol", label = tags$span(icon("exchange-alt"), " Comparison:"), choices = NULL, width = "100%"))
               )
           )
    )
  ),
  br(),
  
  # 2. Analysis Modules
  fluidRow(
    column(12,
           tabsetPanel(id = "ar_modules_tabs", type = "tabs",
             
             # Tab 2.1: Taxa Community
             tabPanel(title = tagList(icon("users"), "2.1 Taxa Community"), value = "tab_community",
                      br(),
                      fluidRow(
                        column(10, div(style = "width: 100%; min-height: 600px; overflow: auto; border: 1px solid #ddd; background-color: #fff; position: relative; display: flex;", div(style = "margin: auto; width: 100%;", uiOutput("taxa_heatmap_ui_wrapper")))),
                        column(2, div(style = "background-color: peachpuff; padding: 10px; border-radius: 5px; border: 1px solid #ddd; font-size: 0.9em;",
                                   h4(icon("cogs"), "Options", style = "margin-top:0; border-bottom: 2px solid #666; padding-bottom: 5px;"),
                                   tags$label("Plot Size:", style="margin-top: 5px; font-weight:bold;"),
                                   fluidRow(column(6, numericInput("hm_width", "Width (inch):", 23, min=5)), column(6, numericInput("hm_height", "Height (inch):", 12, min=5))),
                                   hr(style = "border-top: 1px solid #999; margin: 10px 0;"),
                                   tags$label("Global Thresholds:", style="font-weight:bold;"),
                                   div(style = "background-color: rgba(255,255,255,0.5); padding: 5px; border-radius: 3px; border: 1px solid #ccc; margin-bottom: 10px;", numericInput("hm_min_abund", "Min Abund (any group) ≥", 0.001, step=0.001), helpText("(rel. abund, 0-1)", style="font-size:0.8em; margin-bottom:5px;"), numericInput("hm_min_prev", "Min Prev (any group) ≥", 0.3, step=0.01), helpText("(prevalence, 0-1)", style="font-size:0.8em; margin-bottom:0;")),
#                                   tags$label("Filter Mode:", style="font-weight:bold;"),
				   tags$div(
				     style = "display: flex; align-items: center;",
			             tags$label("Filter Mode:", style="font-weight:bold; margin-right: 5px;"),
				     actionLink("hm_filtermode_info", label = NULL, icon = icon("info-circle"), style = "color: #0275d8; font-size: 14px;")
				   ),
				   radioButtons("hm_filtermode", label = NULL, choices = c("DAM"="dam", "Abundance (Top N)"="abundance_prevalence", "Custom"="custom")),  
                                   div(style = "background-color: rgba(255,255,255,0.5); padding: 5px; border-radius: 3px; border: 1px dashed #999;", 
                                       conditionalPanel("input.hm_filtermode == 'dam'", selectInput("hm_dam_event", "DAM Comparison:", choices = NULL), radioButtons("hm_dam_type", "Sig. Type:", c("P-value"="pvalue", "Adj P"="adjp"), inline = TRUE), numericInput("hm_dam_pval", "Threshold ≤", 0.05, step=0.01), numericInput("hm_dam_eff", "Effect Size ≥", 0.33, step=0.1)), 
                                       conditionalPanel("input.hm_filtermode == 'abundance_prevalence'", selectizeInput("hm_selected_grps_abund", "Select Groups:", choices = NULL, multiple = TRUE, options = list(placeholder = "All groups")), numericInput("hm_topn", "Top N Taxa:", 30, min=1), selectInput("hm_topn_group", "Sort by Group:", choices = NULL)), 
                                       # [FIX] Added hm_plot_type radiobutton for Custom mode
                                       conditionalPanel("input.hm_filtermode == 'custom'", 
                                                        radioButtons("hm_plot_type", "Plot Type:", choices = c("Heatmap" = "heatmap", "Violin Plot" = "violin"), selected = "heatmap", inline = TRUE),
                                                        selectizeInput("hm_selected_grps_custom", "Select Groups:", choices = NULL, multiple = TRUE, options = list(placeholder = "All groups")), 
                                                        selectizeInput("hm_custom_taxa", "Select Taxa:", choices = NULL, multiple = TRUE, options = list(maxItems = 30)), 
                                                        conditionalPanel("input.hm_plot_type == 'heatmap'", helpText(icon("exclamation-circle"), " Max 30 taxa for Heatmap.", style="color:#d9534f;font-weight:bold;font-size:0.8em;")),
                                                        conditionalPanel("input.hm_plot_type == 'violin'", helpText(icon("exclamation-circle"), " Max 15 taxa for Violin.", style="color:#0275d8;font-weight:bold;font-size:0.8em;"))
                                       )
                                   ),
                                   div(style="margin-top:5px;color:#555;font-style:italic;", textOutput("hm_filter_status")),
                                   hr(style="border-top:1px solid #999;margin:10px 0;"),
                                   conditionalPanel("input.hm_filtermode != 'dam'", tags$label("Sample Order:", style="font-weight:bold;"), radioButtons("hm_sample_order", label=NULL, choices=c("Group by Comp."="group", "Clustering"="cluster"))),
                                   conditionalPanel("input.hm_filtermode != 'dam' && input.hm_sample_order == 'cluster'", tags$label("Annotations:", style="font-weight:bold;"), selectizeInput("hm_annotations", label=NULL, choices=NULL, multiple=TRUE)),
                                   hr(style="border-top:2px solid #666;margin:10px 0;"),
                                   actionButton("hm_update_btn", "Update Plot", icon=icon("sync"), style="color:#fff;background-color:#d9534f;border-color:#d43f3a;width:100%;")
                               )
                        )
                      ) 
             ),
             
             # Tab 2.2: Diversity
             tabPanel(
               title = tagList(icon("shapes"), "2.2 Diversity"), value = "tab_diversity",
               br(),
               fluidRow(
                 column(5, div(style = "border: 1px solid #ddd; padding: 10px; border-radius: 5px; background-color: #fff; min-height: 600px;", h4(icon("chart-bar"), "Alpha Diversity", style = "text-align: center; color: #555; border-bottom: 2px solid #eee; padding-bottom: 10px;"), girafeOutput("alpha_diversity_plot", height = "550px"))),
                 column(5, div(style = "border: 1px solid #ddd; padding: 10px; border-radius: 5px; background-color: #fff; min-height: 600px;", h4(icon("project-diagram"), "Beta Diversity", style = "text-align: center; color: #555; border-bottom: 2px solid #eee; padding-bottom: 10px;"), girafeOutput("beta_diversity_plot", height = "550px"))),
                 column(2, div(style = "background-color: peachpuff; padding: 10px; border-radius: 5px; border: 1px solid #ddd; font-size: 0.9em;",
                               h4(icon("cogs"), "Settings", style = "margin-top:0; border-bottom: 2px solid #666; padding-bottom: 5px;"),
                               tags$label(icon("filter"), " Filter Groups", style="color:#d9534f; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), selectizeInput("div_filter_groups", "Show Groups:", choices = NULL, multiple = TRUE, options = list(placeholder = "All groups selected")),
                               tags$label(icon("dot-circle"), " Alpha Settings", style="color:#d9534f; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), selectInput("div_alpha_metric", "Metric:", choices = c("Shannon" = "shannon", "Simpson" = "simpson")), checkboxInput("div_alpha_stats", "Show P-values", value = TRUE),
                               br(),
                               tags$label(icon("cloud"), " Beta Settings", style="color:#0275d8; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), p("Method: Aitchison (CLR)", style="font-style:italic; font-size:0.9em; color:#666; margin-bottom:5px;"), selectInput("div_beta_method", "Method:", choices = c("PCoA" = "PCoA", "PCA" = "PCA", "NMDS" = "NMDS")), fluidRow(column(6, numericInput("div_beta_x", "X Axis:", value = 1, min = 1, step = 1)), column(6, numericInput("div_beta_y", "Y Axis:", value = 2, min = 1, step = 1))),
                               br(),
                               tags$label(icon("paint-brush"), " Appearance", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), numericInput("div_dotsize", "Dot Size:", value = 2.0, min = 0.5, step = 0.5), hr(style = "border-top: 2px solid #666; margin: 20px 0 10px 0;"), actionButton("div_update_btn", "Update Diversity", icon = icon("sync"), style = "color: #fff; background-color: #d9534f; border-color: #d43f3a; width: 100%;")
                 ))
               )
             ),
             
             # Tab 2.3: Correlation Network
             tabPanel(
               title = tagList(icon("project-diagram"), "2.3 Correlation Network"), 
               value = "tab_network", 
               br(),
               fluidRow(
                 column(10, div(style = "width: 100%; height: 900px; overflow: auto; border: 1px solid #ddd; background-color: #fff; position: relative; display: flex; justify-content: center;", 
                                girafeOutput("corr_network_plot", height = "900px"))),
                 column(2, div(style = "background-color: peachpuff; padding: 10px; border-radius: 5px; border: 1px solid #ddd; font-size: 0.9em;", 
                               h4(icon("cogs"), "Settings", style = "margin-top:0; border-bottom: 2px solid #666; padding-bottom: 5px;"), 
                               tags$label(icon("filter"), " Data Filtering", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), 
                               selectInput("cn_compevent", "Select Event(s):", choices = NULL, multiple = TRUE), 
                               radioButtons("cn_ptype", "Edge p-value:", choices = c("Raw" = "raw", "Adjusted (BH)" = "adjusted"), selected = "raw", inline = TRUE),
                               numericInput("cn_pcut", "P-value Cutoff <", value = 0.05, step = 0.01),
                               numericInput("cn_corrcut", "Correlation Cutoff >", value = 0.3, step = 0.1),
                               tags$label(icon("compress-arrows-alt"), " Nodes", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), 
                               
                               numericInput("cn_toptaxa", "Top N Taxa:", value = 50, min = 1),
                               helpText("(Leave empty for all taxa)", style="font-size:0.8em; margin-top:-5px; margin-bottom:10px;"),

                               tags$div(
				 style = "display: flex; align-items: center; margin-bottom: 3px;",
                                 tags$label("Focal Taxon:", style = "font-weight: normal; margin-right: 5px;"),
                                 actionLink("cn_focal_taxon_info", label = NULL, icon = icon("info-circle"), style = "color: #0275d8; font-size: 14px;")
			       ),			       
                               selectizeInput("cn_focal_taxon", label = NULL, choices = NULL, multiple = FALSE, options = list(placeholder = "Search taxon...")),

                               tags$label(icon("draw-polygon"), " Layout", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), 
                               selectInput("cn_layout", "Algorithm:", choices = c("Fruchterman-Reingold" = "fr", "Kamada-Kawai" = "kk", "Nicely" = "nicely", "Graphopt" = "graphopt", "Grid" = "grid", "Circle" = "circle")), 
                               checkboxInput("cn_unified", "Unified Layout (Compare)", value = TRUE), 
                               tags$label(icon("eye"), " Display", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), 
                               fluidRow(column(6, checkboxInput("cn_labels", "Labels", value = TRUE)), column(6, checkboxInput("cn_legend", "Legend", value = TRUE))), 
                               numericInput("cn_labelsize", "Label Size:", value = 3, min = 1, step = 0.5), 
                               numericInput("cn_hubdegree", "Max Node Size:", value = 12, min = 5), 
                               hr(style = "border-top: 2px solid #666; margin: 20px 0 10px 0;"), 
                               actionButton("cn_update_btn", "Update Plot", icon = icon("sync"), style = "color: #fff; background-color: #d9534f; border-color: #d43f3a; width: 100%;")))
               )
             ),
             
             # Tab 2.4: Func. Prediction
             tabPanel(
               title = tagList(icon("dna"), "2.4 Functional Prediction"), 
               value = "tab_functional", 
               br(),
               fluidRow(
                 column(10,
                        div(style = "width: 100%; height: 900px; overflow: auto; border: 1px solid #ddd; background-color: #fff; position: relative; display: flex; justify-content: center;", 
                            girafeOutput("func_plot", height = "900px")
                        )
                 ),
                 column(2,
                        div(style = "background-color: peachpuff; padding: 10px; border-radius: 5px; border: 1px solid #ddd; font-size: 0.9em;",
                            h4(icon("cogs"), "Settings", style="margin-top:0; border-bottom: 2px solid #666; padding-bottom: 5px;"),
                            tags$label(icon("eye"), " View Mode", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"),
                            radioButtons("fp_view_mode", label = NULL, choices = c("Bubble Chart" = "bubble", "Bar Chart (Effect)" = "bar")),
                            tags$label(icon("filter"), " Data Selection", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"),
                            selectInput("fp_event", "Select Event:", choices = NULL),
                            tags$label(icon("calculator"), " Statistics", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"),
                            radioButtons("fp_pval_type", "Sig. Type:", choices = c("Wilcoxon" = "wilcox", "Adj. P" = "adjp")),
                            numericInput("fp_pcut", "P-value Cutoff <", 0.05, step = 0.01),
                            numericInput("fp_efcut", "Effect Size Cutoff >", 0.0, step = 0.1),
                            # [MODIFIED] Updated Label Name
                            numericInput("fp_propcut", "Min Median Rel. Abund. (%) >", 0.1, step = 0.1),
                            conditionalPanel("input.fp_view_mode == 'bubble'", tags$label(icon("font"), " Appearance", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), checkboxInput("fp_show_labels", "Show Pathway Names", value = TRUE), numericInput("fp_label_size", "Font Size:", value = 3, min = 1, step = 0.5)),
                            conditionalPanel("input.fp_view_mode == 'bar'", tags$label(icon("list-ol"), " Ranking", style="color:#555; margin-top:10px; border-bottom: 1px solid #999; width:100%;"), numericInput("fp_top_n", "Top N Pathways:", value = 30, min = 5)),
                            hr(style = "border-top: 2px solid #666; margin: 20px 0 10px 0;"),
                            actionButton("fp_update_btn", "Update Plot", icon = icon("sync"), style = "color: #fff; background-color: #d9534f; border-color: #d43f3a; width: 100%;")
                        )
                 )
               )
             )
           )
    )
  )
)
