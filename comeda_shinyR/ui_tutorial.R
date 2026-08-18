## ui_tutorial.R
## Tutorial Tab UI for CoMeDA
## Structure: NavlistPanel (Left) -> Content (Right)
## Updated: 2025-12-07 (Detailed Batch Correction Logic Added)

tagList(
  br(),
  fluidRow(
    column(12,
      navlistPanel(
        id = "tutorial_nav",
        widths = c(3, 9),
        well = FALSE,
        
        # --- Header ---
        "User Guide",
        
        # ======================================================================
        # Section 1: Quick Start
        # ======================================================================
        tabPanel(title = tagList(icon("bolt"), "Quick Start with Demo Datasets"), value = "quick_start_demo",
          h3("Quick Start with Demo Datasets", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),
  
          p("Quick Start allows you to explore CoMeDA's full functionality without uploading your own data. Simply click a Demo button to load pre-analyzed results from published microbiome studies."),
  
          hr(),
  
  # ======================================================================
  # Section: How to Load Demo
  # ======================================================================
  h4(icon("play-circle"), " 1. How to Load Demo", style = "color: steelblue; font-weight: bold;"),

  p("Demo buttons are available at multiple locations throughout CoMeDA for different purposes:"),

  br(),

  # --- (1) Demo for Upload ---
  h5(icon("upload"), " 1.1 Demo for Data Upload", style = "color: #e65100; font-weight: bold;"),

  p("Experience the data upload workflow with pre-configured demo settings."),

  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "demo_button_upload.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
      "Figure: Demo button location in Metabarcoding Analysis > Upload tab.")
  ),
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "submit_button_upload.png", style = "width: 100%; max-width: 900px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
      "Figure: In demo mode, clicking the “Submit Analysis” button will display the analysis progress status.")
  ),		 

  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #fff3e0;",
      tags$tr(
        tags$th("Location", style = "width: 35%;"),
        tags$th("Function", style = "width: 65%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Metabarcoding Analysis > Upload")),
        tags$td("Auto-fill parameters (16S / PacBio / Saliva_Control) and demonstrate the upload workflow")
      )
    )
  ),

  br(),

  # --- (2) Demo for Analysis Results ---
  h5(icon("chart-bar"), " 1.2 Demo for Analysis Results", style = "color: #1565c0; font-weight: bold;"),

  p("Explore pre-analyzed results from the ", strong("Subgingival microbiome dataset (PacBio)"), " without running the pipeline."),

  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "demo_button_results.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
      "Figure: Demo button locations in Home Page and Metabarcoding Analysis > View Results tab.")
  ),
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "show_demo_results.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
      "Figure: In Demo mode, four results from different datasets can be selected and displayed.")
  ),		 

  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #e3f2fd;",
      tags$tr(
        tags$th("Location", style = "width: 35%;"),
        tags$th("Function", style = "width: 65%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Home Page")),
        tags$td("Quick entry to browse demo analysis results")
      ),
      tags$tr(
        tags$td(strong("Metabarcoding Analysis > View Results")),
        tags$td("Load pre-analyzed Subgingival dataset for interactive exploration")
      )
    )
  ),

  p("Available features: Overview, Alpha/Beta Diversity, Taxa Community, Correlation Network, and Functional Prediction."),

  br(),

  # --- (3) Demo for Cross-kingdom / Paired Correlation ---
  h5(icon("exchange-alt"), " 1.3 Demo for Cross-kingdom / Paired Correlation Analysis", style = "color: #2e7d32; font-weight: bold;"),

  p("Explore cross-condition correlation analysis between ", strong("Saliva and Subgingival"), " paired samples from the same subjects."),

  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "demo_button_crossdataset.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
      "Figure: Demo button location in Metabarcoding Analysis > Cross-Dataset tab.")
  ),
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "ck_demo_present.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
      "Figure: In Demo mode, two demo results can be selected. ")  
  ),
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "show_demo_crossdataset.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
      "Figure: In Demo mode, the network plot can be viewed directly. ")
  ),


  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #e8f5e9;",
      tags$tr(
        tags$th("Location", style = "width: 35%;"),
        tags$th("Function", style = "width: 65%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Metabarcoding Analysis > Cross-Dataset")),
        tags$td("Load paired correlation results for cross-condition analysis")
      )
    )
  ),

  p("Demonstrates how oral microbiome correlations differ between sampling sites within the same individuals."),

  div(style = "background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; border-radius: 5px; margin: 15px 0;",
    icon("info-circle"), strong(" Note: "),
    "Demo mode loads pre-analyzed results. You can explore all visualizations and download results, but cannot modify analysis parameters."
  ),

  hr(),


  # ======================================================================
  # Section: Available Demo Datasets
  # ======================================================================
  h4(icon("database"), " 2. Available Demo Datasets", style = "color: steelblue; font-weight: bold;"),
  
  p("CoMeDA includes four demo datasets from published microbiome studies, showcasing different analysis scenarios:"),
  
  tags$table(class = "table table-striped table-hover", style = "font-size: 0.92em;",
    tags$thead(style = "background-color: #343a40; color: white;",
      tags$tr(
        tags$th("Dataset", style = "width: 12%;"),
        tags$th("BioProject", style = "width: 32%;"),
        tags$th("Platform", style = "width: 10%;"),
        tags$th("Samples", style = "width: 10%;"),
        tags$th("Comparison", style = "width: 18%;"),
        tags$th("Demo Feature", style = "width: 18%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Periodontitis"), br(), strong("(Saliva & Subgingival)")),
        tags$td(tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA933120", target = "_blank", "PRJNA933120")),
        tags$td("PacBio"),
        tags$td("40"),
        tags$td("Perio (20) vs Control (20)"),
        tags$td("Long reads / Cross-condition")
      ),
      tags$tr(
        tags$td(strong("Crohn's Disease")),
        tags$td(tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1156939", target = "_blank", "PRJNA1156939 (16S dataset)"), " and ", br(),
	  tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1156940", target = "_blank", "PRJNA1156940 (ITS dataset, only for cross-kingdom analysis)")),
        tags$td("Illumina"),
        tags$td("90"),
        tags$td("Colon vs Stool vs Terminal ileum"),
        tags$td("Time-based batch correction /", br(), "Cross-kingdom")
      ),
      tags$tr(
        tags$td(strong("Gout")),
        tags$td(
          tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA550142", target = "_blank", "PRJNA550142"), " + ",		
          tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA754261", target = "_blank", "PRJNA754261"), " + ",
          tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA869365", target = "_blank", "PRJNA869365"), " + ",
	  tags$a(href = "https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1131142", target = "_blank", "PRJNA1131142")
        ),
        tags$td("Illumina"),
        tags$td("368"),
        tags$td("Gout vs Healthy Control"),
        tags$td("Multi-cohort batch correction")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Dataset Details
  # ======================================================================
  h4(icon("microscope"), " 3. Dataset Details", style = "color: steelblue; font-weight: bold;"),
  
  br(),
  
  # --- Dataset 1 & 2: Oral Microbiome ---
  div(style = "background-color: #e8f5e9; border: 1px solid #a5d6a7; padding: 20px; border-radius: 5px; margin-bottom: 20px;",
    h5(icon("tooth"), " Oral Microbiome: Saliva & Subgingival", style = "color: #2e7d32; font-weight: bold; margin-top: 0;"),
    
    p(style = "font-size: 0.95em;",
      strong("Study Design: "), "Paired saliva and subgingival plaque samples from periodontitis patients and healthy controls."
    ),
    
    tags$ul(style = "font-size: 0.95em;",
      tags$li(strong("Subjects: "), "40 participants (20 periodontitis patients, 20 healthy controls)"),
      tags$li(strong("Sample sites: "), "Saliva and subgingival plaque from the same individuals"),
      tags$li(strong("Sequencing: "), "PacBio full-length 16S rRNA gene sequencing"),
      tags$li(strong("Key feature: "), "Enables cross-condition analysis between paired sample sites")
    ),
    
    div(style = "background-color: #c8e6c9; padding: 10px; border-radius: 4px; margin-top: 10px;",
      strong("Reference: "),
      p(style = "font-size: 0.85em; color: #555;",
        "Buetas,E., Jordán-López,M., López-Roldán,A., D'Auria,G., Martínez-Priego,L., De Marco,G., Carda-Diéguez,M. and Mira,A. (2024) ",
        em("BMC Genomics"), ", ", strong("25"), ", 310."
      )
    )
  ),
  
  # --- Dataset 3: Crohn's Disease ---
  div(style = "background-color: #e3f2fd; border: 1px solid #90caf9; padding: 20px; border-radius: 5px; margin-bottom: 20px;",
    h5(icon("bacteria"), " Gut Microbiome: Pediatric Crohn's Disease", style = "color: #1565c0; font-weight: bold; margin-top: 0;"),
    
    p(style = "font-size: 0.95em;",
      strong("Study Design: "), "Site-specific gut microbiome profiling from pediatric Crohn's disease patients."
    ),
    
    tags$ul(style = "font-size: 0.95em;",
      tags$li(strong("Subjects: "), "30 pediatric patients with Crohn's disease"),
      tags$li(strong("Sample sites: "), "Colon, stool, and terminal ileum from each patient"),
      tags$li(strong("Sequencing: "), "Illumina paired-end 16S rRNA V3-V4 region"),
      tags$li(strong("Batches: "), "Samples collected from June 2020 to June 2021 (time-based batches)"),
      tags$li(strong("Key feature: "), "Demonstrates time-based batch effect correction")
    ),
    
    div(style = "background-color: #bbdefb; padding: 10px; border-radius: 4px; margin-top: 10px;",
      strong("Reference: "),
      p(style = "font-size: 0.85em; color: #555;",
        "Kim,D., Park,S.-Y., Lee,Y.Q., Kwon,Y., Choe,Y.H., Kim,M.J. and Lee,D.-Y. (2025) ",
        em("iScience"), ", ", strong("28"), ", 113160."
      )
    )
  ),
  
  # --- Dataset 4: Gout ---
  div(style = "background-color: #fff3e0; border: 1px solid #ffcc80; padding: 20px; border-radius: 5px; margin-bottom: 20px;",
    h5(icon("disease"), " Gut Microbiome: Hyperuricemia and Gout", style = "color: #e65100; font-weight: bold; margin-top: 0;"),
    
    p(style = "font-size: 0.95em;",
      strong("Study Design: "), "Multi-cohort analysis integrating four independent studies on gout."
    ),
    
    tags$ul(style = "font-size: 0.95em;",
      tags$li(strong("Cohorts: "), "Four independent studies (PRJNA550142, PRJNA754261, PRJNA869365, and PRJNA1131142)"),
      tags$li(strong("Subjects: "), "368 participants including gout patients and healthy controls"),
      tags$li(strong("Subgroups: "), "Gout, HUA (hyperuricemia), HC (healthy control)"),
      tags$li(strong("Sequencing: "), "Illumina paired-end 16S rRNA V3-V4 region or V4 region"),
      tags$li(strong("Key feature: "), "Demonstrates multi-cohort batch correction across different studies")
    ),
    
    div(style = "background-color: #ffe0b2; padding: 10px; border-radius: 4px; margin-top: 10px;",
      strong("Reference: "),
      p(style = "font-size: 0.85em; color: #555;",
        "Qie,J., Cao,M., Xu,M., Zhang,Y., Luo,L., Sun,C., Ke,D., Yuan,S., Jia,W., Qiu,T., Li,T., Du,X., Xiao,C., Hong,Z. and Zhang,B. (2025) ",
        em("mSystems"), ", ", strong("10"), ", e01091-25."
      )
    )
  ),
  
  hr(),

  # ======================================================================
# Section: Downloadable Demo Data and Results
# ======================================================================
h4(icon("download"), " 4. Downloadable Demo Data and Results", style = "color: steelblue; font-weight: bold;"),

p("Download demo files to test CoMeDA locally or explore pre-analyzed results:"),

# --- Demo Data (Mini Dataset) ---
div(style = "background-color: #e8f5e9; border-left: 5px solid #43a047; padding: 15px; border-radius: 5px; margin: 15px 0;",
  h5(icon("file-archive"), " Demo Data (Mini Dataset for Pipeline Testing)", style = "margin-top: 0; color: #2e7d32;"),
  tags$ul(style = "margin-bottom: 10px;",
    tags$li(strong("Source:"), " PRJNA933120 (Saliva samples)"),
    tags$li(strong("Content:"),
      tags$ol(
	tags$li(strong("Sequencing data input :"), "5 case + 5 control samples"),
	tags$li(strong("Taxa-table input :"), "20 case + 20 control samples"),
	tags$li(strong("Cross-datasets :"), "all of Saliva and Subgingival samples")
      )
    ),
    tags$li(strong("Files:"),
      tags$ol(
	tags$li(strong("Sequencing data input :"), "20 raw sequencing files (paired-end FASTQ) and a metadata file"),
        tags$li(strong("Taxa-table input :"), "A raw Taxa-table and a metadata file"),
	tags$li(strong("Cross-datasets: "), "Two taxa-table and two metadata files")
      )
    ),  
    tags$li(strong("Purpose:"), " Test CoMeDA pipeline with minimal computational resources")
  ),
  downloadButton("download_demo_data", "Download Demo Data (~270 MB)",
                 style = "background-color: #43a047; color: white; border: none;")
),

# --- Pre-analyzed Results (Full Dataset) ---
div(style = "background-color: #e3f2fd; border-left: 5px solid #1976d2; padding: 15px; border-radius: 5px; margin: 15px 0;",
  h5(icon("chart-bar"), " Pre-analyzed Results (Full Dataset Analysis Output)", style = "margin-top: 0; color: #1565c0;"),
  tags$ul(style = "margin-bottom: 10px;",
    tags$li(strong("Source:"), " PRJNA933120 (Saliva samples)"),
    tags$li(strong("Content:"), " 20 case + 20 control samples (complete analysis)"),
    tags$li(strong("Purpose:"), " Explore full analysis results without running the pipeline")
  ),

  p(strong("Included Tables:"), style = "margin-bottom: 5px; margin-top: 10px;"),
  p("Raw taxa-table, CLR-transformed taxa-table, DAM results, Correlation table, Functional prediction table",
    style = "font-size: 0.9em; color: #555; margin-left: 15px;"),

  p(strong("Included Plots:"), style = "margin-bottom: 5px;"),
  p("Taxa community heatmap, DAM heatmap, Alpha diversity violin plot (Shannon), Beta diversity PCoA, Correlation network, Functional bubble plot and bar plot",
    style = "font-size: 0.9em; color: #555; margin-left: 15px;"),

  downloadButton("download_demo_results", "Download Analysis Results (~5 MB)",
                 style = "background-color: #1976d2; color: white; border: none;")
),

# --- Cross-Dataset Analysis Results ---
div(style = "background-color: #fff3e0; border-left: 5px solid #ff9800; padding: 15px; border-radius: 5px; margin: 15px 0;",
  h5(icon("network-wired"), " Cross-Dataset Correlation Analysis Results", style = "margin-top: 0; color: #e65100;"),
  tags$ul(style = "margin-bottom: 10px;",
    tags$li(strong("Source:"), 
      tags$ul(
        tags$li("Crohn's Disease (16S & ITS cross-kingdom analysis)"),
        tags$li("Gout (16S & ITS cross-kingdom analysis)")
      )
    ),
    tags$li(strong("Content:"),
      tags$ul(
	tags$li("Cross-kingdom correlation networks between bacterial and fungal communities"),
	tags$li("Paired-sample correlaton networks between different conditions (multi-site; e.g., Saliva v.s. Subgingival)")
      )
    ),
    tags$li(strong("Purpose:"), " Explore pre-analyzed cross-dataset correlation results")
  ),

  p(strong("Included Tables:"), style = "margin-bottom: 5px; margin-top: 10px;"),
  p("Correlation tables (per taxa level and group) for both datasets",
    style = "font-size: 0.9em; color: #555; margin-left: 15px;"),

  p(strong("Included Plots:"), style = "margin-bottom: 5px;"),
  p("Cross-kingdom correlation network plots (PNG format)",
    style = "font-size: 0.9em; color: #555; margin-left: 15px;"),

  downloadButton("download_demo_crossdataset", "Download Cross-Dataset Results (~4 MB)",
                 style = "background-color: #ff9800; color: white; border: none;")
),

hr(), br()
),
        
        # ======================================================================
        # Section 2: Data Preparation
        # ======================================================================
        tabPanel(title = tagList(icon("file-alt"), "Data Preparation"),
                 h3("Data Preparation", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),
                 
                 # 1. Sequencing Data
                 h4(icon("dna"), " 1. Sequencing Data (for Mode 1)", style="color: steelblue;"),
                 p("Raw sequencing reads generated from Illumina, PacBio, or Nanopore platforms."),
                 tags$ul(
                   tags$li(strong("Format:"), " Compressed FASTQ files (", code(".fastq.gz"), ")."),
                   tags$li(strong("Requirements:"), " Files should be quality-controlled (optional) but raw reads are accepted. File mapping is handled in the Metadata file.")
                 ),
                 hr(),
                 
                 # 2. Taxa Table
                 h4(icon("table"), " 2. Taxa Table (for Mode 2)", style="color: steelblue;"),
                 p("A pre-calculated abundance matrix if you wish to skip the classification step."),
                 tags$ul(
                   tags$li(strong("Format:"), " Tab-delimited text file (", code(".txt"), ")."),
                   tags$li(strong("Structure:"), " Rows represent Taxa (features), and Columns represent Samples."),
                   tags$li(strong("Taxonomy Syntax:"), " Taxonomy levels (Kingdom to Species) must be separated by semicolons (", code(";"), "). Prefixes like 'k__' or 'k_' are optional. Example: ", code("Bacteria;Proteobacteria;..."), " or ", code("k_Bacteria;p_Proteobacteria;..."), ".")
                 ),
                 hr(),
                 
                 # 3. Metadata
                 h4(icon("list-alt"), " 3. Metadata File (Essential)", style="color: steelblue;"),
                 p("The central file linking your data to experimental conditions. Must be a tab-delimited text file (", code(".txt"), ")."),
                 
                 strong("Mandatory Columns:", style="color: #d9534f;"),
                 tags$ul(
                   tags$li(code("sample.id"), ": Unique identifier for each sample. Do not use special characters."),
                   tags$li(code("file.name"), ": The exact filename of the corresponding sequencing data. For pair-end reads, separate filenames with a comma (e.g., ", code("sampleA_R1.fastq.gz,sampleA_R2.fastq.gz"), "). Required for Sequencing Mode."),
                   tags$li(code("Fprimer"), ": Forward primer sequence used for trimming/demultiplexing."),
                   tags$li(code("Rprimer"), ": Reverse primer sequence used for trimming/demultiplexing.")
                 ),
                 
                 br(),
                 strong("Functional Columns:", style="color: #d9534f;"),
                 tags$ul(
                   tags$li(code("barcode"), ": Barcode sequence. Required if performing demultiplexing (Phase 1)."),
                   tags$li(code("comparison.XXX"), ": Grouping columns for statistical analysis. ", 
                           tags$ul(
                             tags$li("Must start with the prefix ", code("comparison.")),
                             tags$li("Example: ", code("comparison.Treatment"), ", ", code("comparison.Disease")),
                             tags$li(strong("Note:"), " The first comparison column found will be used as the Primary Comparison by default.")
                           )
                   ),
                   tags$li(code("batches"), ": (Optional) Information for batch effect correction.", code("Please note that within each batch, all comparison groups should be included if possible."))
                 ),
                 hr(),
                 
                 # 4. Format Diagram
                 h4(icon("image"), " 4. File Format Reference", style="color: steelblue;"),
                 div(style = "border: 2px dashed #ccc; padding: 20px; text-align: center; background-color: #f9f9f9; color: #666;",
                     tags$img(src = "file_info_overview.png", style = "width: 100%; max-width: 900px; border: 1px solid #eee;")
                 ),
		 hr(),br()
        ),
        
        # ======================================================================
        # Section 3: Analysis Workflow
        # ======================================================================
        tabPanel(title = tagList(icon("cogs"), "Analysis Workflow"), value = "analysis_workflow",
  h3("Analysis Workflow", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),
  
  # --- Introduction ---
  p("CoMeDA provides a comprehensive pipeline for metabarcoding data analysis, from raw sequencing reads to biological insights. The workflow is designed to handle both 16S rRNA (bacteria) and ITS (fungi) amplicon data with built-in batch effect correction."),
  
  # --- Workflow Diagram ---
  h4(icon("project-diagram"), " 1. Pipeline Flowchart", style = "color: steelblue;"),
  p("The following diagram illustrates the complete analysis workflow:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin-bottom: 20px; border-radius: 5px;",
      tags$img(src = "CoMeDAworkflow.png", style = "width: 100%; max-width: 1000px;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: CoMeDA analysis pipeline. Orange = Sequencing-specific steps; Green = Data transformation; Blue = Core analysis; Yellow = Advanced analysis.")
  ),
  
  hr(),
  
  # --- Two Input Modes ---
  h4(icon("code-branch"), " 2. Two Input Modes", style = "color: steelblue;"),
  p("CoMeDA supports two entry points depending on your data:"),
  
  fluidRow(
    # Mode 1: Sequencing
    column(6,
      div(style = "background-color: #fff3e0; border-left: 5px solid #E95420; padding: 15px; border-radius: 5px; height: 100%;",
          h5(icon("dna"), " Mode 1: Sequencing Data", style = "color: #E95420; font-weight: bold;"),
          p("Start from raw FASTQ files and perform the complete pipeline."),
          tags$ul(style = "margin-bottom: 0;",
            tags$li("Input: Raw FASTQ files (.fastq.gz)"),
            tags$li("Workflow: Steps 1 → 9"),
            tags$li("Includes: QC, classification, and all downstream analyses")
          )
      )
    ),
    # Mode 2: Taxa-table
    column(6,
      div(style = "background-color: #e3f2fd; border-left: 5px solid #1976d2; padding: 15px; border-radius: 5px; height: 100%;",
          h5(icon("table"), " Mode 2: Taxa Table", style = "color: #1976d2; font-weight: bold;"),
          p("Start from a pre-computed abundance table."),
          tags$ul(style = "margin-bottom: 0;",
            tags$li("Input: Taxa abundance table (.txt)"),
            tags$li("Workflow: Steps 5 → 9"),
            tags$li("Skips: QC and taxonomic classification")
          )
      )
    )
  ),
  
  br(),
  hr(),
  
  # --- Pipeline Steps Summary ---
  h4(icon("list-ol"), " 3. Pipeline Steps Summary", style = "color: steelblue;"),
  
  # Step description table
  div(style = "overflow-x: auto;",
    tags$table(class = "table table-striped table-hover", style = "font-size: 0.95em;",
      tags$thead(
        tags$tr(
          tags$th("Step", style = "width: 8%; text-align: center;"),
          tags$th("Name", style = "width: 20%;"),
          tags$th("Description", style = "width: 42%;"),
          tags$th("Key Tools / Methods", style = "width: 20%;"),
          tags$th("Required", style = "width: 10%; text-align: center;")
        )
      ),
      tags$tbody(
        # Step 1
        tags$tr(
          tags$td(style = "text-align: center; background-color: #9e9e9e; color: white; font-weight: bold;", "1"),
          tags$td(strong("Preprocessing")),
          tags$td("Demultiplexing: Separate pooled samples based on barcode sequences."),
          tags$td("cutadapt"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-default", "Optional"))
        ),
        # Step 2
        tags$tr(
          tags$td(style = "text-align: center; background-color: #E95420; color: white; font-weight: bold;", "2"),
          tags$td(strong("Quality Control")),
          tags$td("Filter low-quality reads, trim primers, and remove sequences outside length thresholds."),
          tags$td("cutadapt"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-warning", "Seq. Mode"))
        ),
        # Step 3
        tags$tr(
          tags$td(style = "text-align: center; background-color: #E95420; color: white; font-weight: bold;", "3"),
          tags$td(strong("Chimera Removal")),
          tags$td("Identify and remove chimeric sequences generated during PCR amplification."),
          tags$td("VSEARCH (uchime)"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-warning", "Seq. Mode"))
        ),
        # Step 4
        tags$tr(
          tags$td(style = "text-align: center; background-color: #E95420; color: white; font-weight: bold;", "4"),
          tags$td(strong("Taxonomy Classification")),
          tags$td("Assign taxonomic labels to sequences using reference databases (Greengenes2 for 16S, UNITE for ITS)."),
          tags$td("Kraken2 + Bracken"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-warning", "Seq. Mode"))
        ),
        # Step 5
        tags$tr(
          tags$td(style = "text-align: center; background-color: #4caf50; color: white; font-weight: bold;", "5"),
          tags$td(strong("CLR Transformation")),
          tags$td("Filter low-abundance taxa, handle zero values, and apply Centered Log-Ratio transformation for compositional data."),
          tags$td("ALDEx2"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-success", "Required"))
        ),
        # Step 6
        tags$tr(
          tags$td(style = "text-align: center; background-color: #4caf50; color: white; font-weight: bold;", "6"),
          tags$td(strong("Batch Correction")),
          tags$td("Evaluate and correct batch effects while preserving biological signals."),
          tags$td("PLSDAbatch"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-default", "Optional"))
        ),
        # Step 7
        tags$tr(
          tags$td(style = "text-align: center; background-color: #1976d2; color: white; font-weight: bold;", "7"),
          tags$td(strong("Core Analysis")),
          tags$td("Perform diversity analysis (alpha/beta), differential abundance testing, and intra-kingdom correlation analysis."),
          tags$td("vegan, ALDEx2, FastCCLasso"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-success", "Required"))
        ),
        # Step 8
        tags$tr(
          tags$td(style = "text-align: center; background-color: #1976d2; color: white; font-weight: bold;", "8"),
          tags$td(strong("Functional Prediction")),
          tags$td("Predict metabolic functions based on taxonomic composition (16S: gene families; ITS: ecological guilds)."),
          tags$td("PICRUSt2 (16S), FunFun (ITS)"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-warning", "Seq. Mode"))
        ),
        # Step 9
        tags$tr(
          tags$td(style = "text-align: center; background-color: #ff9800; color: white; font-weight: bold;", "9"),
          tags$td(strong("Cross-Kingdom Analysis")),
          tags$td("Integrate 16S and ITS data to explore bacteria-fungi interactions and cross-condition comparisons."),
          tags$td("FastCCLasso"),
          tags$td(style = "text-align: center;", tags$span(class = "label label-default", "Advanced"))
        )
      )
    )
  ),
  
  br(),
  hr(),
  
  # --- Mapping to UI Steps ---
  h4(icon("map-signs"), " 4. Mapping to Interface", style = "color: steelblue;"),
  p("The pipeline steps are organized into three main sections in the CoMeDA interface:"),
  
  fluidRow(
    column(4,
      div(style = "background-color: #fce4ec; padding: 15px; border-radius: 5px; text-align: center; height: 150px;",
        h5(strong("Upload & Analyze"), style = "color: #c2185b;"),
        icon("upload", style = "font-size: 2em; color: #c2185b;"),
        p(style = "margin-top: 10px;", "Upload data, configure parameters, and execute the pipeline"),
        p(style = "font-size: 0.85em; color: #666;", "Pipeline Steps 1-8")
      )
    ),
    column(4,
      div(style = "background-color: #e8f5e9; padding: 15px; border-radius: 5px; text-align: center; height: 150px;",
        h5(strong("View Results"), style = "color: #388e3c;"),
        icon("chart-bar", style = "font-size: 2em; color: #388e3c;"),
        p(style = "margin-top: 10px;", "View results: diversity, composition, networks, and DAM"),
        p(style = "font-size: 0.85em; color: #666;", "Pipeline Steps 7-8 results")
      )
    ),
    column(4,
      div(style = "background-color: #fff3e0; padding: 15px; border-radius: 5px; text-align: center; height: 150px;",
        h5(strong("Cross-Kingdom / Paired-Condition"), style = "color: #f57c00;"),
        icon("project-diagram", style = "font-size: 2em; color: #f57c00;"),
        p(style = "margin-top: 10px;", "Cross-kingdom analysis for multi-domain studies"),
        p(style = "font-size: 0.85em; color: #666;", "Pipeline Step 9")
      )
    )
  ),
  br(),
  hr(),

  # --- Analysis Tab Details ---
  h4(icon("map-signs"), " 5. Analysis Interface Details", style = "color: steelblue;"),
  br(),

  tabsetPanel(
    id = "tutorial_analysisworkflow",
    selected = "tt_upload_analyze_tab",
    type = "tabs",

    tabPanel(
      title = "Upload & Analyze",
      value = "tt_upload_analyze_tab",
#  h3("** Upload & Analyze", style = "color:#c2185b"),
  tagList(
  h4("Step 1. Upload Data Files", style = "color: #2c3e50; font-weight: bold; border-left: 5px solid #E95420; padding-left: 10px; margin-top: 30px;"),

  p("Upload your data files and metadata to begin analysis. CoMeDA will automatically detect the input type and validate the consistency between files."),

  # ======================================================================
  # Section: Upload Limits
  # ======================================================================
  h5(icon("cloud-upload-alt"), " 1.1 Upload Limits", style = "color: steelblue; font-weight: bold;"),

  tags$table(class = "table table-bordered", style = "max-width: 500px;",
    tags$tbody(
      tags$tr(
        tags$td(strong("Maximum files")),
        tags$td("100 files")
      ),
      tags$tr(
        tags$td(strong("Maximum total size")),
        tags$td("5 GB")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: File Format Overview (Single Image)
  # ======================================================================
  h5(icon("file-alt"), " 1.2 Input File Formats", style = "color: steelblue; font-weight: bold;"),

  p("The following figure summarizes the required formats for sequencing files, taxa table, and metadata:"),

  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "file_info_overview.png", style = "width: 100%; max-width: 950px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
        "Figure: Overview of input file formats for sequencing data, taxa table, and metadata.")
  ),

  hr(),

  # ======================================================================
  # Section: Automatic Validation
  # ======================================================================
  h5(icon("check-double"), " 1.3 Automatic Validation", style = "color: steelblue; font-weight: bold;"),

  p("Once both files are uploaded, CoMeDA automatically performs consistency checks. You must pass all validations before proceeding to Step 2."),

  # Validation checks
  strong("Validation Checks:"),
  tags$table(class = "table table-striped", style = "font-size: 0.95em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Check", style = "width: 35%;"),
        tags$th("Rule", style = "width: 45%;"),
        tags$th("Error Message", style = "width: 20%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td("First column name"),
        tags$td("Must be exactly ", code("sample.id")),
        tags$td(tags$code(style = "font-size: 0.85em;", "First column must be 'sample.id'"))
      ),
      tags$tr(
        tags$td("Sample ID uniqueness"),
        tags$td("No duplicate values allowed"),
        tags$td(tags$code(style = "font-size: 0.85em;", "Duplicate sample.ids found"))
      ),
      tags$tr(
        tags$td("Sample ID format"),
        tags$td("Cannot contain spaces"),
        tags$td(tags$code(style = "font-size: 0.85em;", "sample.id cannot contain spaces"))
      ),
      tags$tr(
        tags$td("Comparison column"),
        tags$td("At least one column starting with ", code("comparison.")),
        tags$td(tags$code(style = "font-size: 0.85em;", "Metadata missing 'comparison.' column"))
      ),
      tags$tr(style = "background-color: #fff3e0;",
        tags$td(strong("Sequencing mode only"), br(), "File mapping"),
        tags$td("All files listed in ", code("file.name"), " must be uploaded"),
        tags$td(tags$code(style = "font-size: 0.85em;", "Missing files defined in metadata"))
      ),
      tags$tr(style = "background-color: #e3f2fd;",
        tags$td(strong("Taxa-table mode only"), br(), "Sample matching"),
        tags$td("Sample IDs in metadata must match column names in taxa table"),
        tags$td(tags$code(style = "font-size: 0.85em;", "Some samples not found"))
      )
    )
  ),

  br(),

  # Validation result display
  fluidRow(
    column(6,
      div(style = "background-color: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px;",
        h6(icon("check-circle"), " Validation Passed", style = "color: #155724; margin-top: 0;"),
        p(style = "margin-bottom: 0; color: #155724;", "You can proceed to Step 2: Parameters.")
      )
    ),
    column(6,
      div(style = "background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px;",
        h6(icon("exclamation-triangle"), " Validation Failed", style = "color: #721c24; margin-top: 0;"),
        p(style = "margin-bottom: 0; color: #721c24;", "Please fix the errors listed and re-upload your files.")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Tips & Common Issues
  # ======================================================================
  h5(icon("lightbulb"), " 1.4 Tips & Common Issues", style = "color: steelblue; font-weight: bold;"),

  div(style = "background-color: #fff8e1; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px;",
    tags$ul(style = "margin-bottom: 0;",
      tags$li(
        strong("Overwrite Protection: "),
        "If you have previously uploaded files, the system will ask for confirmation before overwriting."
      ),
      tags$li(
        strong("Reset All: "),
        "Use the 'Reset' button to clear all uploaded files and start fresh."
      ),
      tags$li(
        strong("File naming: "),
        "Ensure your FASTQ filenames exactly match those specified in the metadata ", code("file.name"), " column."
      ),
      tags$li(
        strong("Taxa table format: "),
        "The first column should contain taxonomy strings (semicolon-separated). All other columns should be sample abundances."
      ),
      tags$li(
        strong("Character encoding: "),
        "Save your metadata as UTF-8 to avoid encoding issues with special characters."
      )
    )
  ),
  br(),
  hr(),

   h4("Step 2. Configure Parameters", style = "color: #2c3e50; font-weight: bold; border-left: 5px solid #E95420; padding-left: 10px; margin-top: 30px;"),

  p("After successful validation, CoMeDA automatically detects key information from your metadata and presents the parameter configuration panel. Most users can proceed with default settings."),

  hr(),

  # ======================================================================
  # Section: Auto-detected Information
  # ======================================================================
  h5(icon("magic"), " 2.1 Auto-detected from Metadata", style = "color: steelblue; font-weight: bold;"),

  p("CoMeDA automatically scans your metadata file and detects the following columns:"),

  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Item", style = "width: 30%;"),
        tags$th("Detection Rule", style = "width: 70%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("File Name Column")),
        tags$td("Column named ", code("file.name"))
      ),
      tags$tr(
        tags$td(strong("Demultiplexing")),
        tags$td("Enabled if ", code("barcode"), " column exists")
      ),
      tags$tr(
        tags$td(strong("Primer Columns")),
        tags$td("Columns named ", code("Fprimer"), " and ", code("Rprimer"))
      ),
      tags$tr(
        tags$td(strong("Batch Column")),
        tags$td("Column named ", code("batches"), " (enables batch correction)")
      ),
      tags$tr(
        tags$td(strong("Comparison Columns")),
        tags$td("Columns starting with ", code("comparison"), " or ", code("comparison."))
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Basic Configuration
  # ======================================================================
  h5(icon("sliders-h"), " 2.2 Basic Configuration", style = "color: steelblue; font-weight: bold;"),

  p("These are the essential settings you need to configure:"),

  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Options", style = "width: 35%;"),
        tags$th("Description", style = "width: 40%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Data Type"), tags$span(" *", style = "color: firebrick;")),
        tags$td(
          tags$ul(style = "margin: 0; padding-left: 20px;",
            tags$li(code("16S rRNA"), " (default)"),
            tags$li(code("ITS"))
          )
        ),
        tags$td("Select your metabarcoding marker gene. This determines the reference database (Greengenes2 for 16S, UNITE for ITS).")
      ),
      tags$tr(
        tags$td(strong("Sequencing Platform"), tags$span(" *", style = "color: firebrick;")),
        tags$td(
          tags$ul(style = "margin: 0; padding-left: 20px;",
            tags$li(code("Illumina"), " (short reads)"),
            tags$li(code("PacBio"), " (long reads)"),
            tags$li(code("Nanopore"), " (long reads)")
          )
        ),
        tags$td("Select your sequencing platform. This auto-adjusts QC parameters. ", em("Only for sequencing mode."))
      ),
      tags$tr(
        tags$td(strong("Comparison Baseline"), tags$span(" *", style = "color: firebrick;")),
        tags$td("Dynamically generated from your comparison columns"),
        tags$td("Select the reference (control) group for each comparison. The first group listed becomes the baseline for differential analysis.")
      ),
      tags$tr(
        tags$td(strong("Use Default Parameters")),
        tags$td(code("Checked"), " (default)"),
        tags$td("Keep checked to use optimized default values. Uncheck to access advanced parameter settings.")
      )
    )
  ),

  br(),

  div(style = "background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; border-radius: 5px;",
    icon("info-circle"), strong(" Tip: "),
    "For most analyses, the default parameters work well. Only modify advanced parameters if you have specific requirements."
  ),

  hr(),

  # ======================================================================
  # Section: Platform-specific Defaults
  # ======================================================================
  h5(icon("microchip"), " 2.3 Platform-specific Default Values", style = "color: steelblue; font-weight: bold;"),

  p("When you select a sequencing platform, the following QC parameters are automatically adjusted:"),

  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #f8f9fa;",
      tags$tr(
        tags$th("Parameter", style = "width: 30%;"),
        tags$th("Illumina", style = "width: 23%; text-align: center;"),
        tags$th("PacBio", style = "width: 23%; text-align: center;"),
        tags$th("Nanopore", style = "width: 24%; text-align: center;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Quality Score"), " (qscore)"),
        tags$td(style = "text-align: center;", "20"),
        tags$td(style = "text-align: center;", "30"),
        tags$td(style = "text-align: center;", "15")
      ),
      tags$tr(
        tags$td(strong("Min Length"), " (bp)"),
        tags$td(style = "text-align: center;", "150"),
        tags$td(style = "text-align: center;", "400"),
        tags$td(style = "text-align: center;", "400")
      ),
      tags$tr(
        tags$td(strong("Max Length"), " (bp)"),
        tags$td(style = "text-align: center;", "600"),
        tags$td(style = "text-align: center;", "1800"),
        tags$td(style = "text-align: center;", "1800")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Advanced Parameters
  # ======================================================================
  h5(icon("cogs"), " 2.4 Advanced Parameters", style = "color: steelblue; font-weight: bold;"),

  p("Uncheck ", strong("'Use Default Parameters'"), " to access these settings. Modify only if you understand their impact."),

  # --- QC Parameters ---
  strong("2.4.1 Quality Control Parameters:", style = "color: #856404;"),
  tags$table(class = "table table-striped", style = "font-size: 0.92em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Default", style = "width: 15%;"),
        tags$th("Range", style = "width: 15%;"),
        tags$th("Description", style = "width: 45%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("qscore")),
        tags$td("Platform-specific"),
        tags$td("0 - 40"),
        tags$td("Minimum Phred quality score for base filtering")
      ),
      tags$tr(
        tags$td(code("minlen")),
        tags$td("Platform-specific"),
        tags$td("50 - 1000 bp"),
        tags$td("Minimum read length after quality trimming")
      ),
      tags$tr(
        tags$td(code("maxlen")),
        tags$td("Platform-specific"),
        tags$td("100 - 2000 bp"),
        tags$td("Maximum read length after quality trimming")
      ),
      tags$tr(
        tags$td(code("chimera_mode")),
        tags$td("Auto"),
        tags$td("Auto / Execute / Skip"),
        tags$td("Strategy for chimera removal.", br(), "• Auto: Detects read length after QC. If ≤ 200bp (e.g., 2x150bp), skips merging/removal and uses paired-end Kraken2 to prevent read loss.", br(), "• Execute: Forces merging and VSEARCH.", br(), "• Skip: Bypasses removal manually.")
      ),
      tags$tr(
        tags$td(code("use_uchime_ref")),
        tags$td("No"),
        tags$td("Yes / No"),
        tags$td("Use reference-based chimera detection (slower but more accurate for long reads)")
      )
    )
  ),

  br(),

  # --- Filtering Parameters ---
  strong("2.4.2 Filtering Parameters:", style = "color: #856404;"),
  tags$table(class = "table table-striped", style = "font-size: 0.92em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Default", style = "width: 15%;"),
        tags$th("Range", style = "width: 15%;"),
        tags$th("Description", style = "width: 45%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("taxa_levels")),
        tags$td("Phylum, Genus, Species"),
        tags$td("Multiple options"),
        tags$td("Taxonomic levels to include in analysis")
      ),
      tags$tr(
        tags$td(code("sample_richness_cutoff")),
        tags$td("5"),
        tags$td("1 - 50"),
        tags$td("Minimum number of taxa required per sample")
      ),
      tags$tr(
        tags$td(code("sample_readcount_cutoff")),
        tags$td("500"),
        tags$td("100 - 10000"),
        tags$td("Minimum total read count per sample")
      ),
      tags$tr(
        tags$td(code("taxa_prevalence_cutoff")),
        tags$td("0.2"),
        tags$td("0 - 1"),
        tags$td("Minimum proportion of samples a taxon must appear in")
      )
    )
  ),

  br(),

  # --- Functional & Network Parameters ---
  strong("2.4.3 Functional Prediction & Network Analysis:", style = "color: #856404;"),
  tags$table(class = "table table-striped", style = "font-size: 0.92em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Default", style = "width: 15%;"),
        tags$th("Range", style = "width: 15%;"),
        tags$th("Description", style = "width: 45%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("func_prevalence_cutoff")),
        tags$td("0.3"),
        tags$td("0 - 1"),
        tags$td("Minimum prevalence for functional prediction input")
      ),
      tags$tr(
        tags$td(code("func_size_cutoff")),
        tags$td("0.0001"),
        tags$td("0 - 1"),
        tags$td("Minimum median relative abundance for functional prediction")
      ),
      tags$tr(
        tags$td(code("strict_prevalence_cutoff")),
        tags$td("0.3 (16S) / 0.2 (ITS)"),
        tags$td("0 - 1"),
        tags$td("Minimum prevalence for correlation network analysis")
      ),
      tags$tr(
        tags$td(code("strict_proportion_cutoff")),
        tags$td("0.0001"),
        tags$td("0 - 0.01"),
        tags$td("Minimum relative abundance for correlation network analysis")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Configuration Summary
  # ======================================================================
  h5(icon("clipboard-check"), " 2.5 Configuration Summary", style = "color: steelblue; font-weight: bold;"),

  p("Before submitting, review the Configuration Summary panel which displays:"),

  tags$ul(
    tags$li(strong("User Settings: "), "Your selected data type, platform, and baseline groups"),
    tags$li(strong("Auto-detected: "), "Columns detected from your metadata"),
    tags$li(strong("Current Parameters: "), "All parameter values that will be used")
  ),

  div(style = "background-color: #d4edda; border-left: 5px solid #28a745; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("check-circle"), strong(" Submit Analysis: "),
    "Click the green ", strong("'Confirm Parameters and Submit Analysis'"), " button to proceed. The system will validate your configuration and start the analysis pipeline."
  ),
  br(),
  hr(),

  h4("Step 3. Execute Analysis", style = "color: #2c3e50; font-weight: bold; border-left: 5px solid #E95420; padding-left: 10px; margin-top: 30px;"),

  p("After confirming your parameters, the analysis pipeline will start automatically. CoMeDA executes all analyses in the background, allowing you to close your browser and return later."),

  hr(),

  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
    tags$img(src = "step3_submit.png", style = "width: 100%; max-width: 900px; border: 1px solid #eee;"),
    p(style = "margin-top: 10px; font-size: 0.9em; color: #666;",
      "Figure: Execution status panel showing pipeline progress and phase status indicators.")
  ),
  hr(),

  # ======================================================================
  # Section: Pipeline Phases
  # ======================================================================
  h5(icon("tasks"), " 3.1 Pipeline Phases", style = "color: steelblue; font-weight: bold;"),

  p("The pipeline consists of multiple phases. The phases differ depending on your input mode:"),

  fluidRow(
    # Sequencing Mode
    column(6,
      div(style = "background-color: #fff3e0; border: 1px solid #ffcc80; padding: 15px; border-radius: 5px;",
        h6(icon("dna"), " Sequencing Mode", style = "color: #E95420; font-weight: bold; margin-top: 0;"),
        tags$table(class = "table table-sm", style = "font-size: 0.9em; margin-bottom: 0;",
          tags$tbody(
            tags$tr(tags$td(style = "width: 30%;", strong("Phase 0")), tags$td("File Transfer")),
            tags$tr(tags$td(strong("Phase 1")), tags$td("Demultiplexing (if needed)")),
            tags$tr(tags$td(strong("Phase 2")), tags$td("Quality Control")),
            tags$tr(tags$td(strong("Phase 3")), tags$td("Chimera Reads Removal")),
            tags$tr(tags$td(strong("Phase 4")), tags$td("Taxa-table Classification")),
            tags$tr(tags$td(strong("Phase 5")), tags$td("Taxa Analysis")),
            tags$tr(tags$td(strong("Phase 6")), tags$td("Functional Prediction"))
          )
        )
      )
    ),
    # Taxa-table Mode
    column(6,
      div(style = "background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 5px;",
        h6(icon("table"), " Taxa-table Mode", style = "color: #1976d2; font-weight: bold; margin-top: 0;"),
        tags$table(class = "table table-sm", style = "font-size: 0.9em; margin-bottom: 0;",
          tags$tbody(
            tags$tr(tags$td(style = "width: 30%;", strong("Phase 0")), tags$td("File Transfer")),
            tags$tr(tags$td(strong("Phase 1")), tags$td("Taxa Analysis"))
          )
        ),
        div(style = "margin-top: 15px; color: #666; font-size: 0.85em;",
          icon("info-circle"), " Taxa-table mode skips sequencing preprocessing steps."
        )
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Phase Status Indicators
  # ======================================================================
  h5(icon("signal"), " 3.2 Phase Status Indicators", style = "color: steelblue; font-weight: bold;"),

  p("Each phase displays a status indicator showing its current state:"),

  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #f8f9fa;",
      tags$tr(
        tags$th("Indicator", style = "width: 15%; text-align: center;"),
        tags$th("Status", style = "width: 20%;"),
        tags$th("Description", style = "width: 65%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #95a5a6;", "[ ]"),
        tags$td("Queued"),
        tags$td("Phase is waiting to start")
      ),
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #17a2b8;", "[...]"),
        tags$td("Preparing"),
        tags$td("Phase is being initialized")
      ),
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #3498db;", "[RUN]"),
        tags$td("Running"),
        tags$td("Phase is currently executing (shows elapsed time)")
      ),
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #2ecc71;", "[OK]"),
        tags$td("Completed"),
        tags$td("Phase finished successfully (shows total time)")
      ),
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #f39c12;", "[SKIP]"),
        tags$td("Skipped"),
        tags$td("Phase was skipped (e.g., no demultiplexing needed)")
      ),
      tags$tr(
        tags$td(style = "text-align: center; font-family: monospace; color: #e74c3c; font-weight: bold;", "[X]"),
        tags$td(strong("Failed")),
        tags$td("Phase encountered an error - check log messages for details")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Background Execution
  # ======================================================================
  h5(icon("server"), " 3.3 Background Execution", style = "color: steelblue; font-weight: bold;"),

  p("CoMeDA runs analyses in the background, which means:"),

  fluidRow(
    column(6,
      div(style = "background-color: #d4edda; border-left: 5px solid #28a745; padding: 15px; border-radius: 5px;",
        h6(icon("check"), " You CAN:", style = "color: #155724; margin-top: 0;"),
        tags$ul(style = "margin-bottom: 0; color: #155724;",
          tags$li("Close your browser tab after analysis starts running"),
          tags$li("Return later to check results"),
          tags$li("Use your Job ID to access your analysis")
        )
      )
    ),
    column(6,
      div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px;",
        h6(icon("exclamation-triangle"), " Keep in mind:", style = "color: #856404; margin-top: 0;"),
        tags$ul(style = "margin-bottom: 0; color: #856404;",
          tags$li("Keep browser open during ", strong("initialization"), " phase"),
          tags$li("Save your Job ID to return later"),
          tags$li("Progress monitoring stops if you close the browser")
        )
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: Job ID and Returning
  # ======================================================================
  h5(icon("key"), " 3.4 Job ID & Returning to Your Analysis", style = "color: steelblue; font-weight: bold;"),

  p("Each analysis session is assigned a unique ", strong("Job ID (UUID)"), ". This ID is essential for returning to your analysis."),

  div(style = "background-color: #e7f3ff; border: 1px solid #b6d4fe; padding: 15px; border-radius: 5px; margin: 15px 0;",
    fluidRow(
      column(1,
        div(style = "font-size: 2em; color: #0d6efd; text-align: center;", icon("id-card"))
      ),
      column(11,
        strong("Your Job ID is displayed:"),
        tags$ul(style = "margin-bottom: 0; margin-top: 5px;",
          tags$li("In the execution status panel during analysis"),
          tags$li("In the Result Overview page"),
          tags$li("Example format: ", code("a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
        )
      )
    )
  ),

  strong("To return to your analysis:"),
  tags$ol(
    tags$li("Navigate to CoMeDA"),
    tags$li("Go to ", strong("Result Overview"), " (Step B)"),
    tags$li("Click ", strong("'Switch to Other Job ID'"), " button"),
    tags$li("Enter your saved Job ID"),
    tags$li("Your results will be loaded automatically")
  ),

  hr(),

  # ======================================================================
  # Section: Execution Status Panel
  # ======================================================================
  h5(icon("desktop"), " 3.5 Execution Status Panel", style = "color: steelblue; font-weight: bold;"),

  p("The execution status panel provides real-time monitoring information:"),

  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Component", style = "width: 30%;"),
        tags$th("Description", style = "width: 70%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Job ID")),
        tags$td("Your unique analysis identifier - save this!")
      ),
      tags$tr(
        tags$td(strong("Phase Status")),
        tags$td("Current status of each pipeline phase with timing information")
      ),
      tags$tr(
        tags$td(strong("Log Messages")),
        tags$td("Latest 30 lines from the analysis log (auto-updates)")
      ),
      tags$tr(
        tags$td(strong("Time Information")),
        tags$td("Start time and elapsed time counter")
      )
    )
  ),

  hr(),

  # ======================================================================
  # Section: What Happens After Completion
  # ======================================================================
  h5(icon("flag-checkered"), " 3.6 After Completion", style = "color: steelblue; font-weight: bold;"),

  p("When all phases complete successfully:"),

  tags$ul(
    tags$li("A success notification will appear"),
    tags$li("You will be automatically redirected to ", strong("Result Overview"), " (Step B)"),
    tags$li("All analysis results will be available for exploration"),
    tags$li("You can download results and generate reports")
  ),

  div(style = "background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("info-circle"), strong(" Tip: "),
    tags$div("1. If you closed your browser before completion, simply return using your Job ID."), 
    tags$div("2. If the analysis is complete, you'll see the results immediately."),
    tags$div("3. If it's still running, you can continue monitoring."),
    tags$div("4. If possible, please keep this page open and avoid closing the browser during the run.")
  ),

  hr(),

  # ======================================================================
  # Section: Troubleshooting Failures
  # ======================================================================
  h5(icon("exclamation-circle"), " 3.7 If Analysis Fails", style = "color: steelblue; font-weight: bold;"),

  p("If a phase fails (shows ", tags$code("[X]", style = "color: #e74c3c;"), "):"),

  tags$ol(
    tags$li(strong("Check the Log Messages: "), "Error details are displayed in the log section"),
    tags$li(strong("Common causes:"),
      tags$ul(
        tags$li("Insufficient reads passing quality filters"),
        tags$li("Sample/file naming mismatches"),
        tags$li("Incompatible file formats"),
        tags$li("Memory limitations for very large datasets")
      )
    ),
    tags$li(strong("To retry: "), "Fix the issue in your input files, then re-upload and re-run")
  ),

  div(style = "background-color: #f8d7da; border-left: 5px solid #dc3545; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("life-ring"), strong(" Need Help? "),
    "If you encounter persistent errors, please contact the support team (nathanlee@tmu.edu.tw) with your Job ID and error messages."
  ),
  br(),
  hr()
  ) # tagList for upload tab
  ), # tabPanel of upload tab

    tabPanel( # ^tabPanel of view result tab
      title = "View Results",
      value = "tt_view_results_tab",
      fluidRow(
 h4("Result Overview", style = "color: #2c3e50; font-weight: bold; border-left: 5px solid #E95420; padding-left: 10px; margin-top: 30px;"),
  
  p("After analysis completion, the Result Overview provides comprehensive visualization and statistical analysis of your microbiome data. Results are organized into multiple tabs for easy navigation."),
  
  hr(),
  
  # ======================================================================
  # Tab Navigation Overview
  # ======================================================================
  h5(icon("th-large"), " 1. Available Tabs", style = "color: steelblue; font-weight: bold;"),
  
  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #f8f9fa;",
      tags$tr(
        tags$th("Tab", style = "width: 25%;"),
        tags$th("Description", style = "width: 75%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Overview")),
        tags$td("Summary statistics, sample/taxa counts, and batch correction results (if applicable)")
      ),
      tags$tr(
        tags$td(strong("Alpha Diversity")),
        tags$td("Within-sample diversity metrics (Shannon, Simpson)")
      ),
      tags$tr(
        tags$td(strong("Beta Diversity")),
        tags$td("Between-sample diversity and ordination plots (PCoA, PCA, NMDS)")
      ),
      tags$tr(
        tags$td(strong("Taxa Composition")),
        tags$td("Taxonomic abundance heatmaps and differential abundance analysis (DAM)")
      ),
      tags$tr(
        tags$td(strong("Correlation Network")),
        tags$td("Co-occurrence network analysis and hub taxa identification")
      ),
      tags$tr(
        tags$td(strong("Functional Prediction")),
        tags$td("KEGG pathway analysis")
      ),
      tags$tr(
        tags$td(strong("Download")),
        tags$td("Export all figures and data tables")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # 1. Overview Tab
  # ======================================================================
  h5(icon("chart-pie"), " 2. Overview Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("The Overview tab provides a summary of your analysis results:"),
  
  # --- Summary Statistics ---
  strong("2.1 Summary Statistics"),
  p("Displays the number of samples and taxa retained after quality filtering:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_overview_summary.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Summary statistics showing sample and taxa counts after filtering.")
  ),
  
  tags$ul(
    tags$li(strong("Samples retained: "), "Number of samples passing quality thresholds"),
    tags$li(strong("Taxa retained: "), "Number of taxa at each taxonomic level (Phylum, Genus, Species)")
  ),
  
  br(),
  
  # --- Batch Correction ---
  strong("2.2 Batch Correction Results (Optional)"),
  p("If your metadata includes a ", code("batches"), " column, batch effect correction is automatically applied. The results show:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_overview_batch.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Batch correction results showing variance explained and correction method applied.")
  ),
  
  tags$ul(
    tags$li(strong("Correction method: "), "plsda_batch, weighted_plsda_batch, or splsda_batch (auto-selected)"),
    tags$li(strong("Variance explained: "), "Proportion of variance attributed to batch vs. biological factors"),
    tags$li(strong("Before/After comparison: "), "PCA plots showing batch effect reduction")
  ),
  
  hr(),
  
  # ======================================================================
  # 2. Alpha Diversity Tab
  # ======================================================================
  h5(icon("chart-line"), " 3. Alpha Diversity Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("Alpha diversity measures the diversity ", em("within"), " each sample. CoMeDA calculates three complementary metrics:"),
  
  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Metric", style = "width: 20%;"),
        tags$th("Description", style = "width: 50%;"),
        tags$th("Interpretation", style = "width: 30%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Shannon")),
        tags$td("Accounts for both richness and evenness"),
        tags$td("Higher = more diverse and evenly distributed")
      ),
      tags$tr(
        tags$td(strong("Simpson")),
        tags$td("Probability that two randomly selected individuals belong to different species"),
        tags$td("Higher = more diverse (less dominance)")
      )
    )
  ),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_alpha_diversity.png", style = "width: 100%; max-width: 600px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Alpha diversity violin plots comparing groups with statistical significance.")
  ),
  
  div(style = "background-color: #e7f3ff; border-left: 5px solid #0d6efd; padding: 15px; border-radius: 5px;",
    icon("mouse-pointer"), strong(" Interactive: "),
    "Hover over data points to see sample details and exact values."
  ),
  
  hr(),
  
  # ======================================================================
  # 3. Beta Diversity Tab
  # ======================================================================
  h5(icon("project-diagram"), " 4. Beta Diversity Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("Beta diversity measures the diversity ", em("between"), " samples, showing how different microbial communities are from each other."),
  
  strong("Ordination Methods:"),
  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Method", style = "width: 20%;"),
        tags$th("Description", style = "width: 80%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("PCoA")),
        tags$td("Principal Coordinates Analysis - linear projection with Aitchison distance")
      ),
      tags$tr(
	tags$td(strong("PCA")),
        tags$td("Principal Component Analysis - linear projection maximizing variance")	
      ),	       
      tags$tr(
        tags$td(strong("NMDS")),
        tags$td("Non-metric Multidimensional Scaling - with Aithison distance")
      )
    ) 
  ),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_beta_diversity.png", style = "width: 100%; max-width: 600px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: PCoA plot showing sample clustering by group with PERMANOVA results.")
  ),
  
  strong("Statistical Test:"),
  tags$ul(
    tags$li(strong("PERMANOVA: "), "Tests whether group centroids differ significantly"),
    tags$li("P-value < 0.05 indicates significant difference between groups")
  ),
  
  div(style = "background-color: #e7f3ff; border-left: 5px solid #0d6efd; padding: 15px; border-radius: 5px;",
    icon("mouse-pointer"), strong(" Interactive: "),
    "Hover over points to see sample IDs. Click and drag to zoom."
  ),
  
  hr(),
  
  # ======================================================================
  # 4. Taxa Composition Tab (includes DAM)
  # ======================================================================
  h5(icon("bacteria"), " 5. Taxa Composition Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("This tab contains two main sections: ", strong("Abundance Heatmap"), " and ", strong("Differential Abundance Analysis (DAM)"), "."),
  
  br(),
  
  # --- Abundance Heatmap ---
  strong("5.1 Abundance Heatmap"),
  p("Visualizes the relative abundance of taxa across samples:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_taxa_heatmap.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Abundance heatmap showing taxa distribution across samples with hierarchical clustering.")
  ),
  
  tags$ul(
    tags$li(strong("Rows: "), "Taxa (clustered by similarity)"),
    tags$li(strong("Columns: "), "Samples (grouped by comparison variable)"),
    tags$li(strong("Color scale: "), "CLR-transformed abundance values")
  ),
  
  br(),
  
  # --- DAM Section ---
  strong("5.2 Differential Abundance Analysis (DAM)"),
  p("Identifies taxa with significantly different abundances between groups."),
  
  # Statistical thresholds
  div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px; margin: 15px 0;",
    strong("Default Statistical Thresholds:"),
    tags$ul(style = "margin-bottom: 0; margin-top: 10px;",
      tags$li(strong("P-value cutoff: "), code("≤ 0.05"), " (Wilcoxon test, BH-adjusted)"),
      tags$li(strong("Effect size cutoff: "), code("≥ 0.33"), " (Cliff's Delta)")
    )
  ),
  
  # DAM Violin Plot
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_dam_violin.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Violin plots showing abundance distribution of significantly different taxai in Custom mode.")
  ),
  
  # DAM Heatmap
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_dam_heatmap.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Heatmap of differentially abundant taxa with effect size and significance annotations in DAM mode.")
  ),
  
  strong("**DAM Result Table Columns:"),
  tags$table(class = "table table-bordered", style = "font-size: 0.92em;",
    tags$thead(
      tags$tr(
        tags$th("Column", style = "width: 25%;"),
        tags$th("Description", style = "width: 75%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("median.control.clr")),
        tags$td("Median CLR abundance in the reference (control) group")
      ),
      tags$tr(
        tags$td(code("median.case.clr")),
        tags$td("Median CLR abundance in the case group")
      ),
      tags$tr(
        tags$td(code("effect.size")),
        tags$td("Cliff's Delta (-1 to 1): magnitude and direction of difference")
      ),
      tags$tr(
        tags$td(code("wilcox.test.p")),
        tags$td("Raw P-value from Wilcoxon Rank-Sum test")
      ),
      tags$tr(
        tags$td(code("adjust.p")),
        tags$td("BH-adjusted P-value (FDR-corrected)")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # 5. Correlation Network Tab
  # ======================================================================
  h5(icon("share-alt"), " 6. Correlation Network Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("The correlation network visualizes co-occurrence patterns between taxa, helping identify microbial interactions and hub taxa."),
  
  # Full Network
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_correlation_full.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Full co-occurrence network showing all significant correlations between taxa.")
  ),
  
  # Focal Taxa Network
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_correlation_focal.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Focal taxa network highlighting specific taxa and their direct connections.")
  ),
  
  strong("**Network Elements:"),
  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Element", style = "width: 20%;"),
        tags$th("Meaning", style = "width: 80%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Nodes")),
        tags$td("Taxa (size proportional to abundance or connectivity)")
      ),
      tags$tr(
        tags$td(strong("Green edges")),
        tags$td("Positive correlation (taxa co-occur together)")
      ),
      tags$tr(
        tags$td(strong("Red edges")),
        tags$td("Negative correlation (taxa mutually exclude)")
      ),
      tags$tr(
        tags$td(strong("Hub taxa")),
        tags$td("Highly connected nodes - potential keystone species")
      )
    )
  ),
  
  div(style = "background-color: #e7f3ff; border-left: 5px solid #0d6efd; padding: 15px; border-radius: 5px;",
    icon("mouse-pointer"), strong(" Interactive: "),
    "Hover over nodes to see taxa names and connectivity. Hover over edges to see correlation values."
  ),
  
  hr(),
  
  # ======================================================================
  # 6. Functional Prediction Tab
  # ======================================================================
  h5(icon("dna"), " 7. Functional Prediction Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("Functional prediction infers metabolic capabilities from taxonomic composition:"),
  
  tags$ul(
    tags$li(strong("16S data: "), "PICRUSt2 predicts gene families based on phylogenetic placement"),
    tags$li(strong("ITS data: "), "FunFun predicts ecological guilds and functions")
  ),
  
  strong("Visualization Options:"),
  
  # Bubble Plot
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_functional_bubble.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Bubble plot showing KEGG pathway enrichment (size = abundance, color = significance).")
  ),
  
  # Bar Plot
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_functional_barplot.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Bar plot comparing pathway abundances between groups.")
  ),
  
  div(style = "background-color: #e7f3ff; border-left: 5px solid #0d6efd; padding: 15px; border-radius: 5px;",
    icon("mouse-pointer"), strong(" Interactive: "),
    "Hover over bubbles or bars to see pathway names, abundances, and P-values."
  ),
  
  div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("info-circle"), strong(" Note: "),
    "Functional prediction is only available for ", strong("Sequencing Mode"), ". Taxa-table mode skips this step."
  ),
  
  hr(),
  
  # ======================================================================
  # 7. Download Tab
  # ======================================================================
  h5(icon("download"), " 8. Download Tab", style = "color: steelblue; font-weight: bold;"),
  
  p("The Download tab allows you to export all figures and data tables for publication or further analysis."),
  
  strong("Available Downloads:"),
  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Category", style = "width: 25%;"),
        tags$th("Formats", style = "width: 25%;"),
        tags$th("Contents", style = "width: 50%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Figures")),
        tags$td("PNG"),
        tags$td("All plots from each analysis tab are included, except the heatmap and violin plot generated in Taxa Community (Custom mode).")
      ),
      tags$tr(
        tags$td(strong("Data Tables")),
        tags$td("TXT"),
        tags$td("Taxa tables, diversity metrics, DAM results, correlation results, pathway abundances")
      ),
      tags$tr(
        tags$td(strong("Analysis Report")),
        tags$td("PDF"),
        tags$td("Comprehensive summary report with all results")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Interactive Features Summary
  # ======================================================================
  h5(icon("hand-pointer"), " 9. Interactive Features Summary", style = "color: steelblue; font-weight: bold;"),
  
  p("CoMeDA provides interactive visualizations for enhanced data exploration:"),
  
  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #f8f9fa;",
      tags$tr(
        tags$th("Tab", style = "width: 30%;"),
        tags$th("Hover Interaction", style = "width: 70%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td("Alpha Diversity"),
        tags$td("Sample details and exact diversity values")
      ),
      tags$tr(
        tags$td("Beta Diversity"),
        tags$td("Sample IDs, coordinates, and group membership")
      ),
      tags$tr(
        tags$td("Taxa Composition"),
        tags$td("Violin plots show sample-level abundance")
      ),
      tags$tr(
        tags$td("Correlation Network"),
        tags$td("Node: taxa name and connectivity; Edge: correlation value")
      ),
      tags$tr(
        tags$td("Functional Prediction"),
        tags$td("Pathway names, abundances, and statistical values")
      )
    )
  ),
  
  div(style = "background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("lightbulb"), strong(" Tip: "),
    "All downloadable files are available in the ", strong("Download Tab"), ". Navigate there to export figures and data for your publications."
  ),
  br()	       
      )
    ), # tabPanel of view result tab$

    tabPanel( # ^tabPanel of cross-dataset tab
      title = "Cross-Kingdom / Paired-Condition",
      value = "tt_cross_dataset_tab",
 h4("Cross-Kingdom Analysis", style = "color: #2c3e50; font-weight: bold; border-left: 5px solid #E95420; padding-left: 10px; margin-top: 30px;"),
  
  p("Cross-Kingdom Analysis enables you to explore correlations between different microbial domains or conditions, revealing potential inter-kingdom interactions and condition-specific patterns."),
  
  hr(),
  
  # ======================================================================
  # Section: When to Use
  # ======================================================================
  h5(icon("question-circle"), " 1. When to Use Cross-Kingdom Analysis", style = "color: steelblue; font-weight: bold;"),
  
  p("This advanced analysis is useful when you want to:"),
  
  fluidRow(
    column(6,
      div(style = "background-color: #e8f5e9; border: 1px solid #a5d6a7; padding: 15px; border-radius: 5px; height: 100%;",
        h6(icon("layer-group"), " Mode A: 16S + ITS Integration", style = "color: #2e7d32; font-weight: bold; margin-top: 0;"),
        p("Explore bacteria-fungi interactions within the same samples."),
        tags$ul(style = "margin-bottom: 0;",
          tags$li("Identify cross-kingdom co-occurrence patterns"),
          tags$li("Discover potential symbiotic or antagonistic relationships"),
          tags$li("Understand multi-domain community dynamics")
        )
      )
    ),
    column(6,
      div(style = "background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 5px; height: 100%;",
        h6(icon("exchange-alt"), " Mode B: Cross-Condition Comparison", style = "color: #1565c0; font-weight: bold; margin-top: 0;"),
        p("Compare microbial correlations between different conditions."),
        tags$ul(style = "margin-bottom: 0;",
          tags$li("Pre-treatment vs. Post-treatment"),
          tags$li("Different sampling sources (saliva vs stool) across disease and healthy cohorts")
        )
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Prerequisites
  # ======================================================================
  h5(icon("clipboard-check"), " 2. Prerequisites", style = "color: steelblue; font-weight: bold;"),
  
  p("Before running Cross-Kingdom Analysis, ensure you have the required data:"),
  
  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(style = "background-color: #f8f9fa;",
      tags$tr(
        tags$th("Mode", style = "width: 25%;"),
        tags$th("Requirements", style = "width: 75%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Mode A"), br(), "16S + ITS Integration"),
        tags$td(
          tags$ul(style = "margin-bottom: 0;",
            tags$li("Completed analysis of ", strong("both 16S and ITS datasets")),
            tags$li("Same samples sequenced for both markers"),
            tags$li("Matching sample IDs between datasets")
          )
        )
      ),
      tags$tr(
        tags$td(strong("Mode B"), br(), "Cross-Condition"),
        tags$td(
          tags$ul(style = "margin-bottom: 0;",
            tags$li("Two datasets (", strong("taxa-table + metadata"), ") for different conditions"),
            tags$li("Same marker gene (16S or ITS) for both conditions"),
            tags$li("Paired or matched samples between conditions")
          )
        )
      )
    )
  ),
  
  div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px; margin-top: 15px;",
    icon("exclamation-triangle"), strong(" Important: "),
    "Sample IDs must match between the two datasets for correlation analysis to work correctly."
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Parameter Configuration
  # ======================================================================
  h5(icon("sliders-h"), " 3. Parameter Configuration", style = "color: steelblue; font-weight: bold;"),
  
  p("Configure the following parameters for your Cross-Kingdom analysis:"),
  
  # --- Analysis Parameters ---
  strong("3.1 Analysis Parameters:"),
  tags$table(class = "table table-striped", style = "font-size: 0.92em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Description", style = "width: 55%;"),
        tags$th("Default", style = "width: 20%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("Taxa Level")),
        tags$td("Taxonomic level for correlation analysis"),
        tags$td("Genus")
      ),
      tags$tr(
        tags$td(code("Comparison")),
        tags$td("Select comparison variable from metadata"),
        tags$td("-")
      ),
      tags$tr(
        tags$td(code("Comparison Group/Event")),
        tags$td("Specific groups or events to compare"),
        tags$td("-")
      ),
      tags$tr(
        tags$td(code("P-value Cutoff")),
        tags$td("Significance threshold for correlations"),
        tags$td("0.05")
      ),
      tags$tr(
        tags$td(code("Correlation Cutoff")),
        tags$td("Minimum absolute correlation coefficient"),
        tags$td("0.3")
      ),
      tags$tr(
        tags$td(code("Top N")),
        tags$td("Display top N strongest correlations"),
        tags$td("50")
      ),
      tags$tr(
        tags$td(code("Focal Taxon")),
        tags$td("Select a specific taxon to view its correlations"),
        tags$td("-")
      )
    )
  ),
  
  br(),
  
  # --- Visualization Parameters ---
  strong("3.2 Visualization Parameters:"),
  tags$table(class = "table table-striped", style = "font-size: 0.92em; margin-top: 10px;",
    tags$thead(
      tags$tr(
        tags$th("Parameter", style = "width: 25%;"),
        tags$th("Description", style = "width: 75%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(code("Algorithm")),
        tags$td("Network layout algorithm (e.g., Fruchterman-Reingold, Kamada-Kawai, Circle)")
      ),
      tags$tr(
        tags$td(code("Unified Layout")),
        tags$td("Keep consistent node positions across different comparison events")
      ),
      tags$tr(
        tags$td(code("Show Labels")),
        tags$td("Display taxa names on network nodes")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Results
  # ======================================================================
  h5(icon("project-diagram"), " 4. Results", style = "color: steelblue; font-weight: bold;"),
  
  p("Cross-Kingdom Analysis generates interactive network visualizations and correlation tables."),
  
  br(),
  
  # --- Full Network ---
  strong("4.1 Full Correlation Network"),
  p("Displays all significant correlations between taxa from all of datasets:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_crosskingdom_full.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Full cross-kingdom network showing correlations between 16S (bacteria) and ITS (fungi) taxa.")
  ),
  
  br(),
  
  # --- Focal Taxa Network ---
  strong("4.2 Focal Taxon Network"),
  p("Focus on a specific taxon of interest and its direct correlations:"),
  
  div(style = "border: 1px solid #ddd; padding: 15px; text-align: center; background-color: #fafafa; margin: 15px 0; border-radius: 5px;",
      tags$img(src = "result_crosskingdom_focal.png", style = "width: 100%; max-width: 800px; border: 1px solid #eee;"),
      p(style = "margin-top: 10px; font-size: 0.9em; color: #666;", 
        "Figure: Focal taxon network highlighting a selected taxon and all its correlated partners.")
  ),
  
  br(),
  
  # --- Network Interpretation ---
  strong("4.3 Network Interpretation:"),
  tags$table(class = "table table-bordered", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Element", style = "width: 25%;"),
        tags$th("Meaning", style = "width: 75%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Node color")),
        tags$td("Distinguishes taxa from different domains (e.g., bacteria vs. fungi) or conditions")
      ),
      tags$tr(
        tags$td(strong("Node size")),
        tags$td("Number of connections")
      ),
      tags$tr(
        tags$td(strong("Red edges")),
        tags$td("Positive correlation (taxa increase/decrease together)")
      ),
      tags$tr(
        tags$td(strong("Blue edges")),
        tags$td("Negative correlation (inverse relationship)")
      ),
      tags$tr(
        tags$td(strong("Edge thickness")),
        tags$td("Correlation strength")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Download Results
  # ======================================================================
  h5(icon("download"), " 5. Download Results", style = "color: steelblue; font-weight: bold;"),
  
  p("Export your Cross-Kingdom analysis results:"),
  
  tags$table(class = "table table-striped", style = "font-size: 0.95em;",
    tags$thead(
      tags$tr(
        tags$th("Output", style = "width: 30%;"),
        tags$th("Format", style = "width: 20%;"),
        tags$th("Description", style = "width: 50%;")
      )
    ),
    tags$tbody(
      tags$tr(
        tags$td(strong("Network Plot")),
        tags$td("PNG"),
        tags$td("High-resolution network visualization")
      ),
      tags$tr(
        tags$td(strong("Correlation Table")),
        tags$td("TXT"),
        tags$td("Complete list of correlations with taxa pairs, coefficients, and P-values")
      )
    )
  ),
  
  hr(),
  
  # ======================================================================
  # Section: Tips & Limitations
  # ======================================================================
  h5(icon("lightbulb"), " 6. Tips & Limitations", style = "color: steelblue; font-weight: bold;"),
  
  div(style = "background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; border-radius: 5px;",
    strong("Tips:"),
    tags$ul(style = "margin-bottom: 0; margin-top: 10px;",
      tags$li("Start with ", strong("Top N = 50"), " to get an overview, then increase for more detail"),
      tags$li("Use ", strong("Focal Taxon"), " to explore specific taxa of biological interest"),
      tags$li("Enable ", strong("Unified Layout"), " when comparing multiple conditions for easier visual comparison"),
      tags$li("Adjust ", strong("Correlation Cutoff"), " higher (e.g., 0.5) for cleaner networks with fewer edges")
    )
  ),
  
  br(),
  
  div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px;",
    strong("Limitations:"),
    tags$ul(style = "margin-bottom: 0; margin-top: 10px;",
      tags$li("Correlation does not imply causation - validate findings experimentally"),
      tags$li("Requires sufficient sample size for reliable correlation estimates (recommended: n ≥ 30)"),
      tags$li("Rare taxa may show spurious correlations due to many zero values"),
      tags$li("Cross-condition comparisons require matched or paired samples")
    )
  ),
  br()
    ) # tabPanel of cross-dataset tab$
  ) # tabsetPanel

    
        ),
        
        # ======================================================================
        # Section 4: Methodology
        # ======================================================================
        tabPanel(title = tagList(icon("book"), "Methodology"),
		 h3("Methodological Background", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),

                 p("CoMeDA implements a rigorous pipeline designed for compositional data analysis. The methods below outline the statistical and bioinformatic frameworks used in each step."),

                 hr(),

                 # 1. Quality Control
                 h4("1. Quality Control & Preprocessing", style="color: steelblue;"),
                 p("Raw sequencing data undergoes rigorous quality filtering to ensure downstream accuracy:"),
                 tags$ul(
                   tags$li(strong("Trimming & Filtering:"), " ", strong("Cutadapt"), " is used to trim primer sequences and filter reads based on Phred quality scores (Q-score) and length constraints."),
                   tags$li(strong("Chimera Removal:"), " ", strong("VSEARCH (UCHIME)"), " is employed to identify and remove chimeric sequences (PCR artifacts) using reference-based detection methods.")
                 ),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("References:"), br(),
                   "Martin, M. (2011) Cutadapt removes adapter sequences from high-throughput sequencing reads. ", em("EMBnet.journal"), ", ", strong("17"), ", 10-12.", br(),
                   "Rognes, T., Flouri, T., Nichols, B., Quince, C., & Mahé, F. (2016) VSEARCH: a versatile open source tool for metagenomics. ", em("PeerJ"), ", ", strong("4"), ", e2584."
                 ),
                 hr(),

                 # 2. Taxonomic Classification (Updated Refs)
                 h4("2. Taxonomic Classification", style="color: steelblue;"),
                 p("Taxonomic assignment is performed using a high-speed, k-mer based approach followed by Bayesian abundance re-estimation:"),
                 tags$ul(
                   tags$li(strong("Classification:"), " ", strong("Kraken2"), " assigns taxonomy by mapping k-mers to the lowest common ancestor (LCA) in the reference database."),
                   tags$li(strong("Abundance Estimation:"), " ", strong("Bracken"), " (Bayesian Reestimation of Abundance with KrakEN) is used to re-estimate abundances at specific taxonomic levels (e.g., Species, Genus), correcting for reads assigned to higher taxonomic nodes."),
                   tags$li(strong("Databases:"), " We utilize ", strong("Greengenes2"), " for 16S rRNA and ", strong("UNITE"), " for ITS data.")
                 ),
		 div(style = "background-color: #f8f9fa; border-left: 3px solid steelblue; padding: 10px 15px; margin: 15px 0; border-radius: 3px;",
                  strong("Confidence Threshold Optimization:"), br(),
                  "To improve classification accuracy while maintaining sensitivity, CoMeDA adopts relaxed confidence thresholds based on empirical benchmarking studies. ",
                  "Higher thresholds increase precision but drastically reduce the proportion of classified reads, especially for amplicon data with limited k-mer coverage. ",
                  "These values are provided as adjustable defaults on the parameter page (Kraken2 Confidence, range 0-1) and can be tuned by the user:",
                  tags$ul(style = "margin-bottom: 0; margin-top: 5px;",
                    tags$li(strong("16S rRNA:"), " default confidence = 0.1"),
                    tags$li(strong("ITS:"), " default confidence = 0.05")
                  )
                 ),

                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("References:"), br(),
                   "Lu, J., Rincon, N., Wood, D. E., et al. (2022) Metagenome analysis using the Kraken software suite. ", em("Nat. Protoc."), ", ", strong("17"), ", 2815–2839.", br(),
                   "McDonald, D., Jiang, Y., Balaban, M., et al. (2023) Greengenes2 unifies microbial data in a single reference tree. ", em("Nat. Biotechnol."), ", ", strong("41"), ", 1327–1332.", br(),
                   "Abarenkov, K., Nilsson, R. H., Larsson, K. H., et al. (2024) The UNITE database for molecular identification and taxonomic communication of fungi and other eukaryotes: sequences, taxa and classifications reconsidered. ", em("Nucleic Acids Res."), ", ", strong("52"), ", D791–D797.", br(),
                   "Liu, Y., Ghaffari, M. H., Ma, T. and Tu, Y. (2024) Impact of database choice and confidence score on the performance of taxonomic classification using Kraken2. ", em("aBIOTECH"), ", ", strong("5"), ", 465–475."
                 ),
                 hr(),

                 # 3. Data Transformation
                 h4("3. Data Transformation (ALDEx2 CLR)", style="color: steelblue;"),
                 p("Microbiome sequencing data are compositional (sum-constrained). To address this, CoMeDA applies the **Centered Log-Ratio (CLR)** transformation via the **ALDEx2** package:"),
                 tags$ol(
                   tags$li("Generate Monte Carlo instances from the Dirichlet distribution to handle zeros (pseudo-counts)."),
                   tags$li("Apply CLR transformation to each instance."),
                   tags$li("Calculate the median CLR value for each taxon across instances to obtain a robust, log-ratio transformed abundance metric.")
                 ),
		 div(style = "background-color: #f8f9fa; border-left: 3px solid steelblue; padding: 10px 15px; margin: 15px 0; border-radius: 3px;",
                  strong("Denominator Selection (IQLR):"), br(),
                  "To mitigate the influence of outliers on the geometric mean calculation, CoMeDA employs the ",
                  strong("IQLR (Inter-Quartile Log-Ratio)"), " method as the denominator for CLR transformation. ",
                  "Unlike the standard approach that uses all features, IQLR calculates the geometric mean using only features whose variance falls within the inter-quartile range (IQR), effectively excluding highly variable or rare taxa that may distort the reference. ",
                  "This approach provides more stable and reliable CLR values, particularly for sparse microbiome datasets with many zero-inflated features."
                 ),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("Reference:"), br(),
                   "Fernandes, A.D. et al. (2013) ANOVA-like differential expression (ALDEx) analysis for mixed population RNA-Seq. ", em("PLoS One"), ", ", strong("8"), ", e67019."
                 ),
                 hr(),

                 # 4. Batch Correction (Detailed Logic Restored)
                 h4("4. Batch Effect Correction (PLSDAbatch)", style="color: steelblue;"),
                 p("CoMeDA utilizes the `PLSDAbatch` R package for batch effect removal. The optimal method is automatically determined by the system through a hierarchical evaluation process:"),

                 div(style="background-color: #f8f9fa; padding: 15px; border-left: 3px solid steelblue; border-radius: 5px; font-size: 0.95em;",
                   tags$ol(style="margin-bottom: 0;",
                     tags$li(
		       "Following the PLSDA-batch guidelines, CoMeDA assesses batch correction strategy using (1) ", strong("an RDA-based confounding check"), " and (2) ", strong("the batch × group contingency structure"), "."),

                     tags$li(
                       "When Batch and Group show a ", strong("higher degree of association"), ", a ", strong("weighted correction"), " is applied; when ", strong("the degree of association is lower"), ", an ", strong("unweighted correction"), " is used. In parallel, data ", strong("dimensionality/sparsity"), " is evaluated to choose ", strong("sparse versus non-sparse"), " correction."),

                     tags$li(
                             "These two decisions jointly define four correction modes, which are then applied to perform batch effect correction:",
                             tags$ul(
                               tags$li(strong("Unweighted PLSDA"), " (lower degree of association and lower sparsity)"),
                               tags$li(strong("Unweighted sPLSDA"), " (lower degree of association, but higher sparsity)"),
			       tags$li(strong("Weighted PLSDA"), " (higher degree of association, but lower sparsity)"),
			       tags$li(strong("Weighted sPLSDA"), " (higher degree of association and higher sparsity)")
                             )
                     )
                   )
                 ),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("Reference:"), br(),
		   "Wang, Y. & Lê Cao, K.A. (2023) PLSDA-batch: a multivariate framework to correct for batch effects in microbiome data. ", em("Brief. Bioinform."), ", ", strong("24"), ", bbac622."
                 ),
                 hr(),

                 # 5. Diversity Analysis
                 h4("5. Diversity Analysis", style="color: steelblue;"),
                 p("Diversity metrics are calculated to quantify community complexity and dissimilarity:"),
                 tags$ul(
                   tags$li(strong("Alpha Diversity:"), " Measures within-sample diversity using **Shannon** (richness & evenness) and **Simpson** (dominance) indices."),
                   tags$li(strong("Beta Diversity (Compositional):"), " CoMeDA emphasizes the use of **Aitchison Distance** (Euclidean distance on CLR-transformed data). Unlike traditional Bray-Curtis or UniFrac, Aitchison distance is robust to the constant-sum constraint (sub-compositional coherence), making it mathematically superior for microbiome compositional data.")
                 ),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("References:"), br(),
                   "Aitchison, J. (1986) The Statistical Analysis of Compositional Data. Chapman and Hall.", br(),
                   "Gloor, G.B. et al. (2017) Microbiome Datasets Are Compositional: And This Is Not Optional. ", em("Front. Microbiol."), ", ", strong("8"), ", 2224."
                 ),
                 hr(),

                 # 6. DAM
                 h4("6. Differential Abundance (DAM)", style="color: steelblue;"),
                 p("Differential abundance analysis is performed on the CLR-transformed profiles. The results table provides:"),
                 tags$ul(
                   tags$li(code("effect size"), ": **Cliff's Delta**, a non-parametric effect size measure quantifying the magnitude of difference between groups (range -1 to 1)."),
                   tags$li(code("p-value"), ": Derived from the **Wilcoxon Rank-Sum test**."),
                   tags$li(code("adjust.p"), ": FDR-adjusted P-value using the Benjamini-Hochberg (BH) procedure.")
                 ),
                 hr(),

                 # 7. Correlation Analysis
                 h4("7. Correlation Analysis (FastCCLasso)", style="color: steelblue;"),
                 p("Standard correlation methods (Pearson/Spearman) yield spurious results on compositional data. CoMeDA utilizes **FastCCLasso**, an efficient L1-regularization algorithm that estimates the correlation matrix directly from compositional data, ensuring accurate network inference."),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("Reference:"), br(),
                   "Zhang,S. et al. (2024) fastCCLasso: a fast and efficient algorithm for estimating correlation matrix from compositional data.", em("Bioinformatics"), ", ", strong("40"), ", btae314."
                 ),
                 hr(),

                 # 8. Functional Prediction
                 h4("8. Functional Prediction", style="color: steelblue;"),
		 p("Functional potential is inferred from taxonomic composition and summarized at the KEGG pathway level. The workflow starts from a raw taxa table with CLR values and applies prevalence/abundance-based filtering to retain robust taxa for downstream inference."),
		 div(style="background-color: #f8f9fa; padding: 15px; border-left: 3px solid steelblue; border-radius: 5px; font-size: 0.95em;",
		     strong("Reference sequence preparation (taxonomy-to-representative sequence mapping)"), br(),
		     "Because the ", strong("Kraken2 + Bracken"), " protocol outputs a taxa table without marker-gene sequences, representative sequences are constructed to enable sequence-based functional inference with PICRUSt2- and FunFun-style workflows. Specifically, all taxa-associated sequences are collected from", strong("Greengenes2 (16S) or UNITE (ITS)"), ", clustered using ", strong("vsearch at 95% similarity"), ", and a representative sequence is selected for each taxon to form a taxonomy-to-sequence reference."
		 ),
		 br(),
		 div(style="background-color: #f8f9fa; padding: 15px; border-left: 3px solid steelblue; border-radius: 5px; font-size: 0.95em;",
		     strong("Functional prediction and KEGG pathway aggregation"), br(),
		     "For ", strong("16S"), ", functional profiles are inferred using a phylogeny-informed approach (PICRUSt2-style logic) and aggregated to ", strong("KEGG pathways"), " using a ", strong("KO-to-KEGG pathway mapping."), " For ", strong("ITS"), ", functional profiles are inferred using a sequence-to-function mapping approach (FunFun-style logic) and summarized to ", strong("KEGG pathways"), " in the same output space."
		 ),
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("References:"), br(),
                   "Douglas, G.M. et al. (2020) PICRUSt2 for prediction of metagenome functions. ", em("Nat. Biotechnol."), ", ", strong("38"), ", 685–688.", br(),
		   "Krivonos, D.V. et al. (2023) FunFun: ITS-based functional annotator of fungal communities. ", em("Ecol. Evol."), ", ", strong("13"), ", e9874."
                 ),
		 hr(),
		 # 9. Cross-dataset Correlation Analysis
                h4("9. Cross-dataset Correlation Analysis", style="color: steelblue;"),
                p("Analyzing correlations across different compositional datasets (e.g., 16S vs. ITS, or samples from different body sites) presents unique statistical challenges. ",
                  "Directly merging compositional data from separate sequencing runs introduces spurious correlations due to the independent sum-constraints of each dataset."),

                p("CoMeDA implements the ", strong("Split CLR"), " approach to address this challenge:"),
                 tags$ol(
                   tags$li(strong("Independent CLR Transformation:"), " Each dataset is CLR-transformed separately, preserving its own compositional structure and avoiding cross-dataset artifacts."),
                   tags$li(strong("Sample Matching:"), " CLR-transformed tables are merged based on matched sample identifiers (e.g., same subject, same timepoint)."),
                   tags$li(strong("Cross-dataset Correlation:"), " FastCCLasso is then applied to the combined CLR matrix to infer correlations between taxa from different datasets.")
                 ),

                 div(style = "background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; border-radius: 5px; margin: 15px 0;",
                   icon("exclamation-triangle"), strong(" Requirements:"),
                   tags$ul(style = "margin-bottom: 0; margin-top: 10px;",
                     tags$li("Paired or matched samples are required (same subjects across both datasets)."),
                     tags$li("Sample identifiers must be consistent between datasets for proper merging.")
                   )
                 ),

                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("Reference:"), br(),
                   "Brunner, J.D., Robinson, A.J. and Chain, P.S.G. (2024) Combining compositional data sets introduces error in covariance network reconstruction. ", em("ISME Commun."), ", ", strong("4"), ", ycae057."
                 ),
                 hr(), br()
        ),
        
        # ======================================================================
        # Section 5: Local Installation
        # ======================================================================
        tabPanel(title = tagList(icon("laptop-code"), "Local Installation"),
		 h3("Local Installation Guide", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),

                 p("CoMeDA offers a containerized solution for local deployment via Docker. This ensures reproducibility and eliminates complex dependency management for tools like QIIME2, Kraken2, and PICRUSt2."),

                 hr(),

                 # 1. System Requirements
                 h4(icon("microchip"), " 1. System Requirements", style="color: steelblue;"),
                 p("Ensure your system meets the following minimum requirements to run the full pipeline (especially for memory-intensive steps like taxonomic classification):"),

                 tags$table(class = "table table-bordered", style = "max-width: 600px;",
                   tags$tbody(
                     tags$tr(
                       tags$td(strong("CPU"), style="width: 30%; background-color: #f9f9f9;"),
                       tags$td("8 Cores or more")
                     ),
                     tags$tr(
                       tags$td(strong("RAM"), style="width: 30%; background-color: #f9f9f9;"),
                       tags$td("16 GB minimum")
                     ),
                     tags$tr(
                       tags$td(strong("Disk Space"), style="width: 30%; background-color: #f9f9f9;"),
                       tags$td("10 GB free space (7GB for Docker Image + User Data)")
                     ),
                     tags$tr(
                       tags$td(strong("Software"), style="width: 30%; background-color: #f9f9f9;"),
                       tags$td("Docker Engine installed and running")
                     )
                   )
                 ),

                 hr(),

                 # 2. Database Setup
                 h4(icon("database"), " 2. Database Setup", style="color: steelblue;"),
                 div(style = "background-color: #d4edda; border-left: 5px solid #28a745; padding: 15px; border-radius: 5px;",
                     icon("check-circle"), strong(" No manual setup required!"),
                     p(style="margin-top: 5px; margin-bottom: 0;",
                       "All necessary reference databases (Greengenes2 and UNITE) are pre-packaged within the Docker image. You do not need to download or configure them separately.")
                 ),

                 hr(),

                 # 3. Docker Installation
                 h4(icon("docker"), " 3. Docker Installation (Recommended)", style="color: steelblue;"),
                 p("Follow these steps to deploy CoMeDA on your personal computer or cloud server:"),

                 strong("Step A: Pull the Docker Image"),
                 p("Download the latest image from DockerHub:"),
                 tags$pre(style = "background-color: #2d3436; color: #f8f9fa; padding: 10px; border-radius: 5px;",
                          "docker pull tmunathanlee/bccomeda:v2.local.20251215"),

                 br(),

                 strong("Step B: Run the Container"),
                 p("Use the following command to start the application. You must map a local folder to the container to access your data."),

                 div(style = "background-color: #e3f2fd; border-left: 5px solid #1976d2; padding: 15px; margin-bottom: 15px;",
                     strong("Command Explanation:"),
                     tags$ul(style = "margin-bottom: 0;",
                       tags$li(code("-p 3838:3838"), ": Maps the container's port 3838 to your local machine's port 3838."),
                       tags$li(code("-v \"/your/local/path:/nfs/CoMeDA/projects_v2\""), ": Mounts your local project folder to the container's working directory.")
                     )
                 ),

                 p("Replace ", code("/your/local/path"), " with the actual path where you want to store input/output files:"),
                 tags$pre(style = "background-color: #2d3436; color: #a9f542; padding: 15px; border-radius: 5px; font-weight: bold; overflow-x: auto;",
                          "docker run -p 3838:3838 -v \"/your/local/path:/nfs/CoMeDA/projects_v2\" tmunathanlee/bccomeda:v2.local.20251215"),

                 br(),

                 strong("Step C: Access the App"),
                 p("Once the container is running, open your web browser and navigate to:"),
		 tags$pre(style = "background-color: #2d3436; color: #f8f9fa; padding: 10px; border-radius: 5px;",
                          "http://localhost:3838"),
		 hr(), br()
        ),

        # ======================================================================
        # 6. Comparison with Other Webservers
        # ======================================================================

        tabPanel(title = tagList(icon("server"), "Comparison with other Webservers"),
		 h3("Comparison with other Webservers", style = "color: #E95420; font-weight: bold; border-bottom: 1px solid #ddd; padding-bottom: 10px;"),

                 p("To highlight the unique positioning of CoMeDA, we compared it with two major platforms: ",
                   strong("MicrobiomeAnalyst 2.0"), " and ", strong("MOCHI"),
                   ". The comparison focuses on four key dimensions: data input versatility, adherence to compositional data analysis (CoDA) principles, data integration, and functional prediction capabilities."),

		 hr(),

                 # Legend for symbols
                 p(style = "font-size: 0.85em; color: #666; margin-bottom: 10px;",
                   icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " Fully Supported / CoDA Compliant | ",
                   icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported | ",
                   icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Not Supported / Non-CoDA"
                 ),

                 # Detailed Comparison Table using HTML
                 div(style = "overflow-x: auto;",
                   tags$table(class = "table table-bordered table-hover", style = "font-size: 0.9em;",
                     # Table Header
                     tags$thead(style = "background-color: #f8f9fa;",
                       tags$tr(
                         tags$th("Category", style = "width: 12%; vertical-align: middle;"),
                         tags$th("Feature", style = "width: 20%; vertical-align: middle;"),
                         tags$th("CoMeDA", style = "width: 22%; vertical-align: middle; background-color: #e8f5e9; border-bottom: 2px solid #2e7d32;"),
                         tags$th("MicrobiomeAnalyst 2.0", style = "width: 23%; vertical-align: middle;"),
                         tags$th("MOCHI", style = "width: 23%; vertical-align: middle;")
                       )
                     ),
                     tags$tbody(
                       # --- Group 1: Data Input ---
                       tags$tr(style = "background-color: #e9ecef; font-weight: bold;",
                         tags$td(colspan = 5, "1. Data Input")
                       ),
                       tags$tr(
                         tags$td(rowspan = 3, style = "vertical-align: middle; font-weight: bold;", "Input & Settings"),
                         tags$td("Data Type"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("16S / ITS"), br(), "(Unified workflow)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " 16S / ITS / 18S / Shotgun"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " 16S / 18S", br(), "(No specific ITS support)")
                       ),
                       tags$tr(
                         tags$td("Sequencing Platform"),
                         tags$td(icon("square-check", style="color:green;", class = "fa-solid"), " ", strong("Short / Long Reads"), br(), "(Illumina / PacBio / Nanopore)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Mostly Short Reads", br(), "(Illumina / IonTorrent)"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " Short / Long Reads")
                       ),
                       tags$tr(
                         tags$td("Parameter Settings"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Flexible"), br(), "(Tunable QC & Analysis params)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Flexible", br(), "(Tunable filtering params)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Limited", br(), "(Basic pipeline settings)")
                       ),

		       # --- Group 2: Batch Effect Correction ---
                       tags$tr(style = "background-color: #e9ecef; font-weight: bold;",
                         tags$td(colspan = 5, "2. Batch Effect Correction")
                       ),
                       tags$tr(
                         tags$td(rowspan = 2, style = "vertical-align: middle; font-weight: bold;", "Batch Correction"),
                         tags$td("Method"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("PLSDA-batch"), br(), "(Automated strategy selection via pRDA)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Not Integrated", br(), "(External tools required)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Not Integrated", br(), "(External tools required)")
                       ),
                       tags$tr(
                         tags$td("Design Support"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Balanced / Unbalanced"), br(), "(Weighted & Sparse variants)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " None"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " None")
                       ),

                       # --- Group 3: Compositional Data Approach ---
                       tags$tr(style = "background-color: #e9ecef; font-weight: bold;",
                         tags$td(colspan = 5, "3. Suitable for Compositional Data Approach (CoDA)")
                       ),
                       tags$tr(
                         tags$td(rowspan = 5, style = "vertical-align: middle; font-weight: bold;", "Statistical Rigor"),
                         tags$td("Zero Handling", br(), "(Sparsity)"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Dirichlet Monte Carlo"), br(), "(via ALDEx2)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported", br(), "(Pseudo-counts / Mixed)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Ignored / Rarefaction")
                       ),
                       tags$tr(
                         tags$td("Transformation"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("CLR (IQLR)"), br(), "(Robust to outliers)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported", br(), "(CLR / TSS / CSS)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Rarefaction / TSS")
                       ),
                       tags$tr(
                         tags$td("Diversity Distance"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Aitchison"), br(), "(Euclidean on CLR)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported", br(), "(Bray-Curtis / UniFrac / Aitchison)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Bray-Curtis / UniFrac")
                       ),
                       tags$tr(
                         tags$td("Differential Analysis"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("CoDA-based"), br(), "(ALDEx2 / Cliff's Delta)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported", br(), "(ANCOM-BC / LEfSe / DESeq2)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Paritally Supported", br(), "(ANCOM / Wilcoxon)"),
                       ),
                       tags$tr(
                         tags$td("Correlation Inference"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("FastCCLasso"), br(), "(Bias-corrected for CoDA)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Partially Supported", br(), "(SparCC / Pearson / Spearman)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Pearson / Spearman")
                       ),

                       # --- Group 4: Data Integration ---
                       tags$tr(style = "background-color: #e9ecef; font-weight: bold;",
                         tags$td(colspan = 5, "4. Data Integration using CoDA")
                       ),
                       tags$tr(
                         tags$td(rowspan = 2, style = "vertical-align: middle; font-weight: bold;", "Integration"),
                         tags$td("Method"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Split-CLR"), br(), "(Preserves sub-compositional coherence)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Multi-omics Module", br(), "(DIABLO / Concatenation)"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " None")
                       ),
                       tags$tr(
                         tags$td("Application"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("Cross-Kingdom (16S+ITS)"), br(), strong("Paired-Condition (e.g., Multi-site)")),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " Microbiota vs Metabolome"),
                         tags$td(icon("square-xmark", style="color:firebrick", class="fa-solid fa-lg"), " Single Domain Only")
                       ),

                       # --- Group 5: Functional Prediction ---
                       tags$tr(style = "background-color: #e9ecef; font-weight: bold;",
                         tags$td(colspan = 5, "5. Functional Prediction")
                       ),
                       tags$tr(
                         tags$td(rowspan = 1, style = "vertical-align: middle; font-weight: bold;", "Function"),
                         tags$td("Method"),
                         tags$td(icon("square-check", style="color:forestgreen", class="fa-solid fa-lg"), " ", strong("PICRUSt2 (16S)"), " / ", strong("FunFun (ITS)"), br(), "(Bacteria + Fungi)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " Tax4Fun / PICRUSt2", br(), "(Bacteria only)"),
                         tags$td(icon("circle-info", style="color:lightgray", class="fa-lg"), " FAPROTAX", br(), "(Prokaryotes only)")
                       )
                     )
                   )
                 ),

                 # References
                 p(style="font-size: 0.9em; color: #666; margin-top: 10px; border-left: 3px solid #ccc; padding-left: 10px;",
                   strong("References:"), br(),
                   strong("1. MicrobiomeAnalyst: "), "Lu, Y. et al. (2023) MicrobiomeAnalyst 2.0. ", em("Nucleic Acids Res."), br(),
                   strong("2. MOCHI: "), "Zheng, J.J. et al. (2022) MOCHI. ", em("Bioinformatics"), br(),
                 ),

                 hr(), br()
	)
      )
    )
  )
)
