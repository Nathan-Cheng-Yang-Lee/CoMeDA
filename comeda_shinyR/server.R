## server.R; CoMeDA v2.2; 2025.10.17

function(input, output, session) { # ^function
	# ^home page
	source(paste(comedashinypath, "shinyR", "server_homepage.R", sep = "/"), local = T)
	# home page$

	# ^metagenomics analysis
	source(paste(comedashinypath, "shinyR", "server_analysis.R", sep = "/"), local = T)
	# metagenomics analysis$

	# ^Tutorial
	source(paste(comedashinypath, "shinyR", "server_tutorial.R", sep = "/"), local = T)
	# Tutorial$

} # function$
