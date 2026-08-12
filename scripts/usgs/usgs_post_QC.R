#Creates the appropriate model and scenario properties for a USGS feature and
#stores regression coefficients
#For local testing:
# commandArgs <- function(...){
#   c("01613900", "watershed", "usgs_full_drainage", "AGWRC-1.0", 'NA', "https://deq1.bse.vt.edu/usgs/agws/baseflow_regression_df_01613900.csv")
# }

#Load in hydrotools and connect to db
library(hydrotools)
suppressPackageStartupMessages(library(stringr))
basepath='/var/www/R'
source('/var/www/R/config.R')


argst <- commandArgs(trailingOnly = T)
#The USGS gage id
gage_id <- argst[1]
#For USGS watersheds, this is 'watershed'
coverage_bundle <- argst[2]
#For USGS Watersheds, this is 'usgs_full_drainage'
coverage_ftype <- argst[3]
#agwrc-1.0 or some equivalent
model_version <- argst[4]
#Optional scenario prop name
scenario_propcode <- argst[5]
#The files containing QC metrics
numevents_file <- argst[6]
filelength_file <- argst[7]
wshd_slope_file <- argst[8]


#Get all regression data
numevents_df <- read.csv(numevents_file)
filelength_df <- read.csv(filelength_file)

#Only load watershed file if it exists
if(file.exists(wshd_slope_file)){
  wshd_slope_df <- read.csv(wshd_slope_file)
}

#Create a hydrocode based on the provided gage_id
coverage_hydrocode <- paste0("usgs_ws_",gage_id)

#Get the watershed feature
this_feature <- RomFeature$new(
  ds, list(
    hydrocode = coverage_hydrocode,
    bundle = coverage_bundle,
    ftype = coverage_ftype
  ), TRUE)

#Get or create the model to post on:
model_prop <- hydrotools::om_model_object(
  ds = ds, feature = this_feature,
  model_version = model_version,
  model_name = paste(coverage_hydrocode, model_version)
)

#Which property should values be set on? Either model or scenario:
parent_prop <- model_prop
if(!is.na(scenario_propcode) && scenario_propcode != "NA"){
  #Get or create the model to post on:
  parent_prop <- hydrotools::om_get_model_scenario(
    ds = ds, model = model_prop,
    scenario_name = scenario_propcode
  )
}

#Post value to scenario prop and output message with new pid
postValue <- function(propname, value, target_prop){
  new_prop <- target_prop$set_prop(
    propname = propname, propvalue = value
  )
  message(paste0("Stored ",propname," in pid = ",new_prop$pid,
                 " on parent entity pid = ",target_prop$pid))
}

if(exists(wshd_slope_df)){
  #Post the average watershed slope
  postValue(propname = "wshd_slope",value = wshd_slope_df$slope,
            parent_prop = this_feature)
}

#Post the number of non-NA values from the gage record used in the AGWS workflow
postValue(propname = "non_na_flow_count",value = filelength_df$total,
          parent_prop = parent_prop)
#Post the number of events
postValue(propname = "total_bf_events",value = numevents_df$total,
          parent_prop = parent_prop)

#post monthly event totals
postValue(propname = "total_bf_events",value = numevents_df[1,2],
          parent_prop = parent_prop)
