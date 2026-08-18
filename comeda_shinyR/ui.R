## ui.R; CoMeDA v2.2; 2025.10.17

navbarPage( # ^navbarPage
	   windowTitle = "CoMeDA - Batch-Correction and Compositional Metabarcoding Data Analysis",
	   title = tags$b("CoMeDA", style = "color:wheat; padding: 20px; font-size: 40px; font-weight:bold;"),
	   id = "CoMeDA",
	   theme = shinytheme("united"),
	   selected = "Home",
	   position = "fixed-top",
	   collapsible = T,
	   footer = tags$div(
			     tags$span("CoMeDA does not use cookies or browser storage. No personal data is collected.", style = "float: left;"),
			     tags$span("Bioinformatics Center, Office of Data Science, Taipei Medical University"),
			     class = "navbarfooter"
	   ),
	   tags$style( # ^change css
		      type = "text/css",
		      ".shiny-output-error { visibility: hidden; }", # hide error massages on ui
		      ".shiny-output-error:before { visibility: hidden; }",
		      "li a {font-size:18px; color:dimgrey;}", # change fontsize and color
		      ".navbarfooter {position:fixed; bottom:0; width:100%; height:40px; background-color:#e95420; color:whitesmoke; text-align:right; font-size:18px; line-height:40px; padding:0 20px;}", # set footer
		      "body {margin-top: 80px; margin-bottom:40px;}", # fix margin for footer
	   ), # change css$

	   # ^home page
	   tabPanel(
		    "Home",
		    source(paste(comedashinypath, "shinyR", "ui_homepage.R", sep = "/"), local = T)$value
	   ),
	   # home page$

	   # ^metagenomics analysis
	   tabPanel(
		    "Metabarcoding Analysis",
		    useWaiter(),
		    source(paste(comedashinypath, "shinyR", "ui_analysis.R", sep = "/"), local = T)$value 
	   ),
	   # metagenomics analysis$

	   # ^tutorial
	   tabPanel(
		    "Tutorial",
		    source(paste(comedashinypath, "shinyR", "ui_tutorial.R", sep = "/"), local = T)$value
	   )
	   # tutorial$
) # navbarPage$
