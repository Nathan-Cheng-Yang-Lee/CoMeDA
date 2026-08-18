## ui_analysis_step2params.R; CoMeDA v2.2; Step 2 Parameter Configuration
## Generate on 2025.11.25
## Three-block structure: Basic Configuration, Advanced Parameters, Configuration Summary

tagList(
  
  # ^step 2 conditional display
  conditionalPanel(
    condition = "output.step2_can_display == true",
    
    # ^step 2 title
    fluidRow(
      column(12,
             h4("Step 2: Configure Analysis Parameters", 
                style = "color: #333;
                         padding-bottom: 10px; 
                         margin-bottom: 20px;")
      )
    ),
    # step 2 title$
    
    # ^block 1: basic configuration
    fluidRow(
      column(12,
             wellPanel(
               style = "background-color: #f8f9fa; 
                        border: 2px solid #e95420; 
                        border-radius: 4px;
                        padding: 20px;",
               
               # ^block 1 title
               fluidRow(
                 column(12,
                        h4(icon("sliders-h"), " Basic Configuration", 
                           style = "color: #333; 
                                    font-weight: bold; 
                                    margin-bottom: 20px;
                                    border-bottom: 2px solid #e95420;
                                    padding-bottom: 10px;")
                 )
               ),
               # block 1 title$
               
               # ^basic parameters - 4 columns
               fluidRow(
                 
                 # ^data type selection
                 column(3,
                        radioButtons(
                          "data_type",
                          label = tags$div(
                            tags$strong("Data Type"),
                            tags$span(" *", style = "color: firebrick;"),
                            style = "font-size: 16px;"
                          ),
                          choices = c("16S rRNA" = "16S", 
                                      "ITS" = "ITS"),
                          selected = "16S",
                          width = "98%"
                        ),
                        tags$div(
                          style = "color: #666; font-size: 13px; margin-top: -10px;",
                          "Select your metabarcoding marker gene"
                        )
                 ),
                 # data type selection$
                 
                 # ^sequencing platform selection (conditional)
                 column(3,
                        conditionalPanel(
                          condition = "output.is_sequencing_mode == true",
                          selectInput(
                            "sequencing_type",
                            label = tags$div(
                              tags$strong("Sequencing Platform"),
                              tags$span(" *", style = "color: firebrick;"),
                              style = "font-size: 16px;"
                            ),
                            choices = c("Please select..." = "",
                                        "Illumina (short reads)" = "Illumina",
                                        "PacBio (long reads)" = "PacBio",
                                        "Nanopore (long reads)" = "Nanopore"),
                            selected = "",
                            width = "98%"
                          ),
                          tags$div(
                            style = "color: #666; font-size: 13px; margin-top: -10px;",
                            "Select your sequencing platform"
                          )
                        ),
                        conditionalPanel(
                          condition = "output.is_sequencing_mode == false",
                          tags$div(
                            style = "color: #999; 
                                     font-style: italic; 
                                     padding: 10px; 
                                     background-color: #f0f0f0; 
                                     border-radius: 4px;
                                     margin-top: 25px;",
                            icon("info-circle"), 
                            " Sequencing platform not required for taxa-table input"
                          )
                        )
                 ),
                 # sequencing platform selection$

		 # ^Comparison Baselines (Dynamic)	
		 column(4,
			tags$div(
			  tags$strong("Comparison & Baseline"),
			  tags$span(" *", style = "color: firebrick;"),
                          style = "font-size: 16px; margin-bottom: 5px;"
			),
			# This UI output will generate multiple SelectInputs
			uiOutput("ui_comparison_baselines"),
			tags$div(
			  style = "color: #666; font-size: 13px;",
                          "Select baseline (reference) for each comparison group"	 
			)
		 ),
		 # Comparison Baselines (Dynamic)$	
                 
                 # ^use default parameters checkbox
                 column(2,
                        tags$div(
                          style = "margin-top: 25px;",
                          checkboxInput(
                            "use_default_params",
                            label = tags$div(
                              tags$strong("Use Default Parameters"),
                              style = "font-size: 16px;"
                            ),
                            value = TRUE,
                            width = "98%"
                          ),
                          tags$div(
                            style = "color: #666; font-size: 13px; margin-top: -10px;",
                            "Uncheck to customize advanced parameters"
                          )
                        )
                 )
                 # use default parameters checkbox$
                 
               )
               # basic parameters$
               
             )
      )
    ),
    # block 1: basic configuration$
    
    br(),
    
    # ^block 2: advanced parameters (conditional)
    conditionalPanel(
      condition = "input.use_default_params == false",
      
      fluidRow(
        column(12,
               wellPanel(
                 style = "background-color: #fff3cd; 
                          border: 2px solid #ffc107; 
                          border-radius: 4px;
                          padding: 20px;",
                 
                 # ^block 2 title with warning
                 fluidRow(
                   column(12,
                          h4(icon("exclamation-triangle", style = "color: #856404;"), 
                             " Advanced Parameters", 
                             style = "color: #856404; 
                                      font-weight: bold; 
                                      margin-bottom: 15px;
                                      border-bottom: 2px solid #ffc107;
                                      padding-bottom: 10px;"),
                          tags$p(
                            style = "color: #856404; font-size: 14px; margin-bottom: 20px;",
                            icon("info-circle"), 
                            " Only modify these parameters if you have specific requirements. ",
                            "Default values are optimized for most analyses."
                          )
                   )
                 ),
                 # block 2 title$
                 
                 # ^row 1: QC parameters
                 fluidRow(
                   column(4,
                          numericInput(
                            "qscore",
                            label = tags$div(
                              tags$strong("Quality Score Cutoff"),
                              tags$br(),
                              tags$span("(qscore)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 20,
                            min = 0,
                            max = 40,
                            step = 1,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "minlen",
                            label = tags$div(
                              tags$strong("Minimum Length"),
                              tags$br(),
                              tags$span("(minlen, bp)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 150,
                            min = 50,
                            max = 1000,
                            step = 10,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "maxlen",
                            label = tags$div(
                              tags$strong("Maximum Length"),
                              tags$br(),
                              tags$span("(maxlen, bp)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 600,
                            min = 100,
                            max = 2000,
                            step = 10,
                            width = "100%"
                          )
                   )
                 ),
                 # row 1$
                 
                 br(),
                 
                 # ^row 1.5: chimera removal settings (NEW - 2025.12.20)
                 conditionalPanel(
                   condition = "output.is_sequencing_mode == true",
                   fluidRow(
                     column(6,
                            radioButtons(
                              "skip_chimera",
                              label = tags$div(
                                tags$strong("Chimera Removal"),
                                tags$br(),
                                tags$span("(skip_chimera)", style = "font-size: 12px; color: #666;")
                              ),
                              choices = c(
                                "Auto (detect read length)" = "auto",
                                "Execute chimera removal" = "no",
                                "Skip chimera removal" = "yes"
                              ),
                              selected = "auto",
                              inline = FALSE,
                              width = "100%"
                            ),
                            tags$div(
                              style = "color: #666; font-size: 12px; margin-top: -5px; padding: 10px; background-color: #f8f9fa; border-radius: 4px;",
                              tags$strong("Auto mode:"),
                              tags$span(" Detects read length after QC. If ≤200bp, skips chimera removal and uses paired-end Kraken2.")
                            )
                     ),
                     column(6,
                            tags$div(
                              style = "margin-top: 25px; padding: 15px; background-color: #e8f4f8; border: 1px solid #bee5eb; border-radius: 4px;",
                              tags$div(style = "font-weight: bold; color: #0c5460; margin-bottom: 8px;",
                                       icon("info-circle"), " Why skip chimera removal?"),
                              tags$ul(style = "color: #0c5460; font-size: 12px; margin-bottom: 0; padding-left: 20px;",
                                tags$li("Short reads (e.g., 2×150bp) cannot merge for V3-V4 amplicons (~460bp)"),
                                tags$li("Merging failure causes significant read loss"),
                                tags$li("Paired-end Kraken2 mode preserves more reads for classification")
                              )
                            )
                     )
                   ),
                   br()
                 ),
                 # row 1.5$

                 # ^row 1.6: Kraken2 confidence (NEW - reviewer revision; user-adjustable)
                 conditionalPanel(
                   condition = "output.is_sequencing_mode == true",
                   fluidRow(
                     column(4,
                            numericInput(
                              "kraken2_confidence",
                              label = tags$div(
                                tags$strong("Kraken2 Confidence"),
                                tags$br(),
                                tags$span("(confidence, 0-1)", style = "font-size: 12px; color: #666;")
                              ),
                              value = 0.1,
                              min = 0,
                              max = 1,
                              step = 0.01,
                              width = "100%"
                            ),
                            tags$div(
                              style = "color: #666; font-size: 12px; margin-top: -5px;",
                              tags$span("Default 0.1 for 16S rRNA and 0.05 for ITS. Lower values increase sensitivity; higher values increase classification precision.")
                            )
                     )
                   ),
                   br()
                 ),
                 # row 1.6$

                 # ^row 2: processing parameters
                 fluidRow(
                   column(4,
                          radioButtons(
                            "use_uchime_ref",
                            label = tags$div(
                              tags$strong("Use UCHIME Reference"),
                              tags$br(),
                              tags$span("(uchimeref)", style = "font-size: 12px; color: #666;")
                            ),
                            choices = c("No" = "no", "Yes" = "yes"),
                            selected = "no",
                            inline = TRUE,
                            width = "100%"
                          )
                   ),
                   column(4,
                          selectInput(
                            "taxa_levels",
                            label = tags$div(
                              tags$strong("Taxa Levels"),
                              tags$br(),
                              tags$span("(taxalevels)", style = "font-size: 12px; color: #666;")
                            ),
                            choices = c("Phylum + Genus + Species (default)" = "phylum,genus,species",
                                        "All 6 levels" = "phylum,class,order,family,genus,species",
                                        "Genus + Species only" = "genus,species",
                                        "Species only" = "species"),
                            selected = "phylum,genus,species",
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "sample_richness_cutoff",
                            label = tags$div(
                              tags$strong("Sample Richness Cutoff"),
                              tags$br(),
                              tags$span("(samplerichcut)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 5,
                            min = 1,
                            max = 50,
                            step = 1,
                            width = "100%"
                          )
                   )
                 ),
                 # row 2$
                 
                 br(),
                 
                 # ^row 3: filtering cutoffs 1
                 fluidRow(
                   column(4,
                          numericInput(
                            "sample_readcount_cutoff",
                            label = tags$div(
                              tags$strong("Sample Read Count Cutoff"),
                              tags$br(),
                              tags$span("(samplerccut)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 500,
                            min = 100,
                            max = 10000,
                            step = 100,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "taxa_prevalence_cutoff",
                            label = tags$div(
                              tags$strong("Taxa Prevalence Cutoff"),
                              tags$br(),
                              tags$span("(taxaprevcut, 0-1)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 0.2,
                            min = 0,
                            max = 1,
                            step = 0.05,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "func_prevalence_cutoff",
                            label = tags$div(
                              tags$strong("Function Prevalence Cutoff"),
                              tags$br(),
                              tags$span("(funcprevcut, 0-1)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 0.3,
                            min = 0,
                            max = 1,
                            step = 0.01,
                            width = "100%"
                          )
                   )
                 ),
                 # row 3$
                 
                 br(),
                 
                 # ^row 4: filtering cutoffs 2
                 fluidRow(
                   column(4,
                          numericInput(
                            "func_size_cutoff",
                            label = tags$div(
                              tags$strong("Function Median Abundance Cutoff"),
                              tags$br(),
			      tags$span("(funcpropcut)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 0.0001,
                            min = 0,
                            max = 1,
                            step = 0.0001,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "strict_proportion_cutoff",
                            label = tags$div(
                              tags$strong("Strict Proportion Cutoff"),
                              tags$br(),
                              tags$span("(strictedpropcut)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 0.0001,
                            min = 0,
                            max = 0.01,
                            step = 0.0001,
                            width = "100%"
                          )
                   ),
                   column(4,
                          numericInput(
                            "strict_prevalence_cutoff",
                            label = tags$div(
                              tags$strong("Strict Prevalence Cutoff"),
                              tags$br(),
                              tags$span("(strictedprevcut, 0-1)", style = "font-size: 12px; color: #666;")
                            ),
                            value = 0.3,
                            min = 0,
                            max = 1,
                            step = 0.05,
                            width = "100%"
                          )
                   )
                 )
                 # row 4$
                 
               )
        )
      )
    ),
    # block 2: advanced parameters$
    
    br(),
    
    # ^block 3: configuration summary
    fluidRow(
      column(12,
             wellPanel(
               style = "background-color: #e8f5e9; 
                        border: 2px solid #4caf50; 
                        border-radius: 4px;
                        padding: 20px;",
               
               # ^block 3 title
               fluidRow(
                 column(12,
                        h4(icon("clipboard-check"), " Configuration Summary", 
                           style = "color: #155724; 
                                    font-weight: bold; 
                                    margin-bottom: 20px;
                                    border-bottom: 2px solid #4caf50;
                                    padding-bottom: 10px;")
                 )
               ),
               # block 3 title$
               
               # ^sub-block 1: user settings (left) & auto-detected (right)
               fluidRow(
                 
                 # ^left: user settings
                 column(4,
                        wellPanel(
                          style = "background-color: white; 
                                   border: 1px solid #c3e6cb; 
                                   border-radius: 4px;
                                   padding: 15px;
                                   min-height: 280px;",
                          
                          h5(icon("user-cog"), " User Settings", 
                             style = "color: #155724; 
                                      font-weight: bold; 
                                      margin-bottom: 15px;"),
                          
                          tags$div(
                            style = "font-size: 14px; line-height: 2;",
                            
                            tags$p(tags$strong("Data Type: "), 
                                   uiOutput("summary_data_type", inline = TRUE)),
                            
                            tags$p(tags$strong("Sequencing Type: "), 
                                   uiOutput("summary_sequencing_type", inline = TRUE)),
                            
                            tags$p(tags$strong("Read Type (backend): "), 
                                   uiOutput("summary_readtype", inline = TRUE)),
                            
                            tags$p(tags$strong("Parameter Mode: "), 
                                   uiOutput("summary_param_mode", inline = TRUE)),
			    tags$hr(style="margin: 10px 0; border-top: 1px dashed #ccc;"),
                            tags$strong("Comparison Baselines:"),
                                        uiOutput("summary_comparison_baselines_list")	   
                          )
                        )
                 ),
                 # left: user settings$
                 
                 # ^right: auto-detected from metadata
                 column(8,
                        wellPanel(
                          style = "background-color: white; 
                                   border: 1px solid #c3e6cb; 
                                   border-radius: 4px;
                                   padding: 15px;
                                   min-height: 280px;",
                          
                          h5(icon("magic"), " Auto-detected from Metadata", 
                             style = "color: #155724; 
                                      font-weight: bold; 
                                      margin-bottom: 15px;"),
                          fluidRow(
			    column(6,
				  tags$div(
				    style = "font-size: 14px; line-height: 2;",
				    tags$p(tags$strong("File Name Column: "),
				           uiOutput("summary_file_name_col", inline = T)),
			            tags$p(tags$strong("Comparison Column: "),
			                   uiOutput("summary_comparison_col", inline = T)),
				    tags$p(tags$strong("Batch Column: "),
				           uiOutput("summary_batches_col", inline = T))	   
				  ) 
			    ),
		            column(6,
				   tags$div(
				     style = "font-size: 14px; line-height: 2;",
                                     tags$p(tags$strong("Need Demultiplex: "),
					    uiOutput("summary_need_demultiplex", inline = T)),
			             tags$p(tags$strong("Barcode Column: "),
			                    uiOutput("summary_barcode_col", inline = T)),
			             tags$p(tags$strong("Forward Primer Column: "),
			                    uiOutput("summary_fprimer_col", inline = T)),
			             tags$p(tags$strong("Reverse Primer Column: "),
			                    uiOutput("summary_rprimer_col", inline = T)) 		    
				   )
			    )		   
			  )
			)
                 )
                 # right: auto-detected$
                 
               ),
               # sub-block 1$
               
               br(),
               
               # ^sub-block 2: current parameter values
               fluidRow(
                 column(12,
                        wellPanel(
                          style = "background-color: white; 
                                   border: 1px solid #c3e6cb; 
                                   border-radius: 4px;
                                   padding: 15px;",
                          
                          h5(icon("cogs"), " Current Parameter Values", 
                             style = "color: #155724; 
                                      font-weight: bold; 
                                      margin-bottom: 15px;"),
                          
                          # ^3 columns of parameters
                          fluidRow(
                            
                            # ^column 1: QC parameters
                            column(4,
                                   tags$div(
                                     style = "font-size: 13px; line-height: 1.8;",
                                     
                                     tags$h6("QC Parameters:", 
                                             style = "color: #856404; 
                                                      font-weight: bold; 
                                                      margin-bottom: 10px;
                                                      border-bottom: 1px solid #ffc107;
                                                      padding-bottom: 5px;"),
                                     
                                     tags$p(tags$strong("Quality Score: "), 
                                            textOutput("summary_qscore", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Min Read Length After Trimming: "), 
                                            textOutput("summary_minlen", inline = TRUE), " bp"),
                                     
                                     tags$p(tags$strong("Max Read Length After Trimming: "), 
                                            textOutput("summary_maxlen", inline = TRUE), " bp"),
                                     
                                     tags$p(tags$strong("Use Reference Method for Chimera Reads Removal: "), 
                                            textOutput("summary_uchimeref", inline = TRUE))
                                   )
                            ),
                            # column 1$
                            
                            # ^column 2: analysis parameters
                            column(4,
                                   tags$div(
                                     style = "font-size: 13px; line-height: 1.8;",
                                     
                                     tags$h6("Analysis Parameters:", 
                                             style = "color: #856404; 
                                                      font-weight: bold; 
                                                      margin-bottom: 10px;
                                                      border-bottom: 1px solid #ffc107;
                                                      padding-bottom: 5px;"),
                                     
                                     tags$p(tags$strong("Taxa Levels: "), 
                                            textOutput("summary_taxa_levels", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Sample Richness: "), 
                                            textOutput("summary_sample_richness", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Sample Min Read Count: "), 
                                            textOutput("summary_sample_rc", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Taxa Min Prevalence: "), 
                                            textOutput("summary_taxa_prev", inline = TRUE))
                                   )
                            ),
                            # column 2$
                            
                            # ^column 3: filtering cutoffs
                            column(4,
                                   tags$div(
                                     style = "font-size: 13px; line-height: 1.8;",
                                     
                                     tags$h6("Filtering Cutoffs:", 
                                             style = "color: #856404; 
                                                      font-weight: bold; 
                                                      margin-bottom: 10px;
                                                      border-bottom: 1px solid #ffc107;
                                                      padding-bottom: 5px;"),
                                     
                                     tags$p(tags$strong("Taxa Min Prevalence for Functional Prediction: "), 
                                            textOutput("summary_func_prev", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Taxa Min Medain Relative Abundance for Functional Prediction: "), 
                                            textOutput("summary_func_size", inline = TRUE)),
                                     
                                     tags$p(tags$strong("Taxa Min Prevalence for Co-occurrent Network Analysis: "), 
                                            textOutput("summary_strict_prev", inline = TRUE)),
					     
				     tags$p(tags$strong("Taxa Min Relative Abundance for Co-occurrent Network Analysis: "),
                                            textOutput("summary_strict_prop", inline = TRUE))
                                   )
                            )
                            # column 3$
                            
                          )
                          # 3 columns of parameters$
                          
                        )
                 )
               ),
               # sub-block 2$
               
               br(),
               
               # ^proceed button
               fluidRow(
                 column(12, 
                        align = "center",
                        actionButton(
                          "submit_analysis_btn",
                          label = "Confirm Parameters and Submit Analysis",
                          icon = icon("rocket"),
                          style = "color: whitesmoke; 
                                   background-color: #28a745; 
                                   font-size: 18px; 
                                   font-weight: bold;
                                   padding: 15px 40px;
                                   border-radius: 8px;",
                          width = "60%"
                        )
                 )
               )
               # proceed button$
               
             )
      )
    )
    # block 3: configuration summary$
    
  )
  # step 2 conditional display$
  
)
