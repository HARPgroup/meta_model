#For local testing:
# commandArgs <- function(...){
#   c("01613900")
# }

#Load in hydrotools and connect to db
library(hydrotools)
suppressPackageStartupMessages(library(stringr))
basepath='/var/www/R'
source('/var/www/R/config.R')

argst <- commandArgs(trailingOnly = T)
message(paste0("DEBUG with: argst <- c('",paste(argst,collapse="', '")),"')")
#The USGS gage id
gage_id <- argst[1]

gage_obj <- hydrotools::WaterGageDaily$new(gage_id = gage_id, ds_in = ds,
                                           data_source = data.frame(time = 0, value = 0),
                                           flow_col = "value", date_col = "time")

agws_props <- gage_obj$agwrc_fun()

if(all(agws_props$propname != "rating_class")){
  gage_obj$save_baseflow_context(data_type = "gage_conclusions",
                                 study_agwrc_method = 6,
                                 study_context = "No baseflow events over minimum
                                 threshold found. Workflow failed in Analyze Step 01 - 03.")
}else{
  message("No exit_handler rating_class property set as rating_class is already set as",
          agws_props$propvalue[agws_props$propname == "rating_class"])
}


