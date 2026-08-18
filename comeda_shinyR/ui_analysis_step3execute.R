# ui_analysis_step3execute.R
# CoMeDA v2.2 - Step 3: Execute Analysis Pipeline (UI ONLY)
# This file contains ONLY UI elements, dynamic content is rendered in server
# Created: 2025-11-26
# Fixed: 2025-11-26 - Separated UI and Server logic properly

# ^step 3 execute ui
tagList(
  
  # ^step 3 conditional display
  conditionalPanel(
    condition = "output.step3_can_display == true",
    
    div(
      id = "step3_execute_container",
      style = "margin-top: 30px; padding: 25px; background-color: #f8f9fa; border-radius: 10px; border: 2px solid #3498db;",
      
      # ^header
      div(
        style = "border-bottom: 3px solid #3498db; padding-bottom: 15px; margin-bottom: 20px;",
        h3(
          style = "color: #2c3e50; margin: 0;",
          icon("rocket"),
          "Step 3: Submit Analysis Pipeline"
        )
      ),
      # header$
      
      # ^pipeline workflow section (dynamic content from server)
      uiOutput("pipeline_workflow_display"),
      # pipeline workflow section$
      
      # ^browser warning section (dynamic content from server)
      uiOutput("browser_warning_message"),
      # browser warning section$
      
      # ^execution status section
      div(
        style = "background-color: #2c3e50; padding: 25px; border-radius: 8px; margin-top: 20px; color: #ecf0f1; font-family: 'Courier New', monospace;",
        
        # Status header with Job ID (dynamic)
        uiOutput("execution_status_header"),
        
        # Phase status display (dynamic)
        uiOutput("phase_status_display"),
        
        # Separator
        hr(style = "border-color: #7f8c8d; margin: 20px 0;"),
        
        # Log messages section (dynamic)
        uiOutput("log_messages_section"),
        
        # Time information (dynamic)
        uiOutput("time_information_display")
        
#        # Tip for closing browser (dynamic)
#        uiOutput("browser_close_tip")
      )
      # execution status section$
    )
  )
  # step 3 conditional display$
)
# step 3 execute ui$
