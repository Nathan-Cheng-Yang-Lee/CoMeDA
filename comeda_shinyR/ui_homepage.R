## ui_home.R
## Home Tab UI for CoMeDA
## Structure: Hero Header (w/ Advantages) -> Workflow Image -> Action Buttons
## Updated: 2025-12-07 (White Theme, Advantages Added, Footer Removed)

tagList(
  
  # ============================================================================
  # 1. Hero Header (White Theme with OrangeRed Border)
  # ============================================================================
  fluidRow(
    column(12, 
           style = "padding: 0;", 
           div(
             # White background, Black text, Top OrangeRed Border
             style = "background-color: #ffffff; padding: 60px 40px; text-align: center; color: #333333; border-top: 10px solid #E95420; border-bottom: 1px solid #eee;",
             
             # Title
             h1("batch-corrected Compositional Metabarcoding Data Analysis (CoMeDA)", 
                style = "font-weight: 800; font-size: 42px; margin-bottom: 20px; letter-spacing: 1px; color: #2c3e50;"),
             
             # Subtitle
             div(style = "max-width: 1400px; margin: 0 auto; font-size: 18px; line-height: 1.6; font-weight: 400; color: #555;",
                 tagList("CoMeDA is a user-friendly platform for comparative metabarcoding analysis with batch correction and compositional data handling. Designed to address the inherent challenges of metabarcoding data, including constant sum constraint, taxonomic sparsity, and spurious correlation, our R Shiny-based interface provides interactive visualization and downloadable results. CoMeDA is free available for all users without login requirement.")
             ),
             
             br(), 
             
             # [Image Embed: Concept Diagram]
             div(
               style = "margin-top: 20px; margin-bottom: 40px;",
               img(src = "CoMeDAoverview.png", 
                   style = "max-width: 80%; height: auto; border: 4px solid gainsboro; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);")
             ),
             
             # Advantages Section
             div(style = "max-width: 1000px; margin: 0 auto; text-align: left; background-color: #f9f9f9; padding: 30px; border-radius: 8px; border-left: 5px solid #E95420;",
                 h3(icon("thumbs-up"), " Advantages of CoMeDA", style = "color: #E95420; font-weight: bold; margin-top: 0; margin-bottom: 20px;"),
                 
                 tags$ul(style = "font-size: 16px; line-height: 1.8; color: #444; list-style: none; padding-left: 10px;",
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), "Metabarcoding analysis through compositional data analysis (CoDA) approaches."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), "Support for both short (Illumina) and long (PacBio/Nanopore) read technologies."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), strong("Cross-Kingdom or Paired-Condition association analysis"), " by combining 16S (Bacteria) and ITS (Fungi) data."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), strong("Batch effect correction"), " using PLSDA-batch to handle experimental variations."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), "Interactive graphical visualization for Heatmaps, Networks, and PCoA."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), "Comprehensive management interface for viewing and searching project history."),
                         tags$li(icon("check-circle", style="color:forestgreen; margin-right:8px;"), "Local version available for privacy and performance (see Tutorial).")
                 )
             )
           )
    )
  ),
  
  # ============================================================================
  # 2. Workflow Diagram
  # ============================================================================
  fluidRow(
    column(12,
           div(style = "padding: 50px 20px; text-align: center; background-color: #ffffff;",
               
               h2(icon("project-diagram"), " Analysis Workflow", 
                  style = "color: #333; font-weight: bold; margin-bottom: 30px; border-bottom: 2px solid #eee; display: inline-block; padding-bottom: 10px;"),
               
               # [Image Embed: Workflow Diagram]
               # Sized identically to the Hero Concept Image (max-width: 80%)
               div(
                 img(src = "CoMeDAworkflow.png", 
                     style = "max-width: 80%; height: auto; border: 4px solid gainsboro; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);")
               )
           )
    )
  ),
  
  # ============================================================================
  # 3. Action Area
  # ============================================================================
  fluidRow(
    column(12,
           div(style = "background-color: #f8f9fa; padding: 60px 0; text-align: center; border-top: 1px solid #dee2e6;",
               h3("Ready to start?", style = "color: #555; margin-bottom: 30px; font-weight: bold;"),
               
               # Buttons Container
               div(style = "display: flex; justify-content: center; gap: 30px; flex-wrap: wrap;",
                   
                   # Button 1: Start New Analysis (ForestGreen)
                   actionButton("home_start_analysis", "Start New Analysis", icon = icon("rocket"),
                                style = "color: white; background-color: forestgreen; border-color: forestgreen; 
                                         padding: 15px 30px; font-size: 18px; font-weight: bold; border-radius: 50px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);"),
                   
                   # Button 2: View Demo Results (OrangeRed)
                   actionButton("home_load_demo", "View Demo Results", icon = icon("laptop-code"),
                                style = "color: white; background-color: #E95420; border-color: #E95420; 
                                         padding: 15px 30px; font-size: 18px; font-weight: bold; border-radius: 50px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);"),

		   # Buttun 3: Download Demo Datasets (SteelBlue)
		   actionButton("home_download_demo", "Download Demo Datasets", icon = icon("download"),
                                style = "color: white; background-color: steelblue; border-color: steelblue;
                                         padding: 15px 30px; font-size: 18px; font-weight: bold; border-radius: 50px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);"),		
                   
                   # Button 4: View Tutorial (Orange)
                   actionButton("home_view_tutorial", "View Tutorial", icon = icon("book-reader"),
                                style = "color: white; background-color: orange; border-color: orange; 
                                         padding: 15px 30px; font-size: 18px; font-weight: bold; border-radius: 50px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);")
               )
           )
    )
  ),
  br(),

  # 4. contact information
  fluidRow(
    column(12,
      div(style = "background-color: #f8f9fa; padding: 20px; border-top: 3px solid steelblue;",
      h4(icon("envelope"), " Contact & Support"),
      p("For bug reports, feature requests, or collaboration inquiries, please contact:"),
      tags$ul(
        tags$li(strong("Developer: "), "Nathan Lee (nathanlee@tmu.edu.tw)"),
        tags$li(strong("Office: "), "Bioinformatics Center, Office of Data Science, Taipei Medical University")
      ),
      br(),
      p(style = "font-size: 0.85em; color: #999;",
        icon("shield-alt"), " Data Policy: Raw uploaded files are deleted immediately after analysis. Analysis results are retained for 14 days for download, after which all data is permanently removed.")
      )
    )	   
  )  	       
)
