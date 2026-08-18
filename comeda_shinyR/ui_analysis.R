## ui_analysis.R; CoMeDA v2.3

tagList(
  shinyjs::useShinyjs(),	
  
  # ^job id management area (Header)
  fluidRow(
    style = "padding: 10px; background-color: whitesmoke; margin-bottom: 20px; border-bottom: 1px solid #ddd;",
    
    # [修改] 移除按鈕，保留 UUID 與警告資訊
    # [修改] 取消 align="center"，恢復預設靠左對齊
    column(12, align = "center",
           h3(textOutput("current_job_id_display", inline = TRUE), 
              style = "font-weight: bold; color: forestgreen; margin: 10px 0;"),
           
           h5("Your data will be retained for 14 days from today.", 
              style = "color: firebrick; font-weight: bold; margin: 5px 0;"),
           
           h5("It is recommended that you use the local version, please click on tutorial for more information.", 
              style = "color: firebrick; font-weight: bold; margin: 5px 0;")
    )
  ),
  # job id management area$
  
  # ^tabsetPanel
  tagList(
    # CSS: 強制修改 Tab 樣式為 United Orange (#E95420)
    tags$style(HTML("
      .nav-tabs { border-bottom: 2px solid #E95420 !important; }
      .nav-tabs > li.active > a, .nav-tabs > li.active > a:focus, .nav-tabs > li.active > a:hover {
        border-color: #E95420 #E95420 transparent #E95420 !important;
        color: #E95420 !important;
        font-weight: bold;
        background-color: #fff;
      }
      .nav-tabs > li > a:hover { background-color: #fff5f0; border-color: #ffccbc #ffccbc #E95420 #ffccbc; }
    ")),

    div(
      tabsetPanel(
        id = "analysis_workflow",
        selected = "upload_tab", 
        type = "tabs",
        
        # ^tab 1: Step A (名稱已修改)
        tabPanel(
          title = tagList("Upload and Analyze"),
	  value = "upload_tab",
          fluidRow(
            style = "padding: 20px;",
            column(12,
                   # [新增] Step A 頂部按鈕列
                   fluidRow(
	             column(12, br()),		    
                     column(3,
                            actionButton("use_demo_btn_stepA", 
                                         label = "Use the example data for demonstration", 
                                         icon = icon("person-chalkboard"),
					 style = "background-color: #E95420; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2);",
                                         width = "98%"
                            )
                     ),
                     column(3,
                            actionButton("import_job_id_btn_stepA", 
                                         label = "Change to the current / other job id", 
                                         icon = icon("circle-check"),
					 style = "background-color: dimgrey; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2);",
                                         width = "98%"
                            )
                     ),
	             column(6)		    
                   ),
                   hr(style = "border-top: 1px dashed #ccc; margin: 20px 0;"),
                   
                   source(paste(comedashinypath, "shinyR", "ui_analysis_step1upload.R", sep = "/"), local = TRUE)$value,
                   source(paste(comedashinypath, "shinyR", "ui_analysis_step2params.R", sep = "/"), local = TRUE)$value,
                   source(paste(comedashinypath, "shinyR", "ui_analysis_step3execute.R", sep = "/"), local = TRUE)$value
            )
          )
        ),
        # tab 1$
        
        # ^tab 2: Step B (名稱已修改)
        tabPanel(
          title = tagList(icon("right-long"), "View Analysis Results"),
	  value = "view_kingdom_specific_tab",
          fluidRow(
            style = "padding: 20px;",
            column(12,
                   # [新增] Step B 頂部按鈕列
		     column(12, br()),	    
                     column(3,
                            actionButton("use_demo_btn_stepB", 
                                         label = "Use the example data for demonstration", 
                                         icon = icon("person-chalkboard"),
                                         style = "background-color: #E95420; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2);",
					 width = "98%"
			    )
                     ),
                     column(3,
                            actionButton("import_job_id_btn_stepB", 
                                         label = "Change to the current / other job id", 
                                         icon = icon("circle-check"),
                                         style = "background-color: dimgrey; color: whitesmoke; font-weight: bold; border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2);",
					 width = "98%"
			    )
                     ),
	             column(6)		    
                   ),
              column(12, hr(style = "border-top: 1px dashed #ccc; margin: 20px 0;")),
              column(12,		     
                   h3("Analysis Results of Kingdom-Specific data", 
                      style = "color: #333; font-weight: bold; border-bottom: 2px solid forestgreen; padding-bottom: 10px;")
	      ),
	      column(12, br()),	     
              column(12, uiOutput("result_overview_ui"))
	    )	   
        ),
        # tab 2$
       
        # ^tab 3: Step C (名稱已修改)
        tabPanel(
          title = tagList("Run Cross-Dataset Correlation Analysis"),
          fluidRow(
            style = "padding: 20px;",
            column(12,
                   source(paste(comedashinypath, "shinyR", "ui_analysis_crosskingdom.R", sep = "/"), local = TRUE)$value
            )
          )
        )
        # tab 3$
      )
    )
  )
)
