output$download_demo_data <- downloadHandler(
  filename = function() {
    "comedademo_datasets.zip"
  },
  content = function(file) {
    file.copy("/nfs/CoMeDA/projects_v2/comedademo/comedademo_datasets.zip", file)
  }
)

output$download_demo_results <- downloadHandler(
  filename = function() {
    "CoMeDA_Results_Full_comedademo.zip"
  },
  content = function(file) {
    file.copy("/nfs/CoMeDA/projects_v2/comedademo/CoMeDA_Results_Full_comedademo.zip", file)
  }
)

# [NEW] Cross-Dataset Demo Results Download
output$download_demo_crossdataset <- downloadHandler(
  filename = function() {
    "CoMeDA_CrossDataset_Demo_Results.zip"
  },
  content = function(file) {
    file.copy("/nfs/CoMeDA/projects_v2/comedademo/CoMeDA_CrossDataset_Demo_Results.zip", file)
  }
)
