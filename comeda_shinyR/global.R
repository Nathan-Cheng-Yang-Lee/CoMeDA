library(shiny)
library(shinyBS)
library(shinyjs)
library(shinythemes)
library(uuid)
library(DT)
library(waiter)
library(tidyverse)
library(grid)
library(ggplot2)
library(ggiraph)
library(ggpubr)
library(patchwork)
library(tools)

## ^pre-setting
options(shiny.maxRequestSize = 10000 *1024^2) ## increase upload file size
options("DT.TOJSON_ARGS" = list(na = "string")) ## present na and inf on table

comedashinypath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826"
comedainvpath="/nfs/CoMeDA/projects_v2"
comedacolors <- c("steelblue", "tomato", "forestgreen", "darkorange", "darkslateblue", "firebrick", "mediumseagreen", "goldenrod", "slateblue", "darkgray", "dodgerblue", "lightgreen", "sienna", "blueviolet", "darkcyan", "salmon", "moccasin", "chocolate", "orchid", "cornflowerblue", "indianred", "darkolivegreen", "plum", "royalblue", "red", "seagreen", "peru", "slategray", "navy", "hotpink", "limegreen", "mediumvioletred", "orange", "#e5505a","#6caddf","#ffc600","#9fc54d","#a560e8","#D0B3A3","#fe5000","#a93c3b","#0057b8","#00b140","#4e2a84","#B78B6E","#ff9933","#e0393e","#1fbad6","#00af87","#694d88","#767676","#f58268","#f4979c","#007fae","#578230","#BDACE5","#000075","#1fbad6")
## pre-setting$


