# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")

suppressPackageStartupMessages(library(hydrotools)) 

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
river_seg <- argst[1]
scenario_name <- argst[2]
model_version <- argst[3]
rseg_ftype <- argst[4]
model_status_flag <- argst[5]
model_status_msg <- argst[6]

if (rseg_ftype == 'vahydro') {
  # we have a hinky prefix, so add it
  rseg_code=paste0('vahydrosw_wshed_',river_seg)
} else {
  rseg_code=river_seg
}

message(paste("Searching for feature hydrocode=", rseg_code,"with ftype",rseg_ftype))
riverseg<- RomFeature$new(
  ds,
  list(
    hydrocode=rseg_code,
    ftype=rseg_ftype,
    bundle='watershed'
  ),
  TRUE
)
message(paste("Searching for model", model_version,"on feature",riverseg$hydroid))
model <- RomProperty$new(
  ds,
  list(
    featureid=riverseg$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
if (is.na(model$pid)) {
  model$propname = paste(riverseg$name, model_version)
  model$varid = ds$get_vardef('om_water_model_node')$varid
  model$save(TRUE)
}

model_scenario <- RomProperty$new(
  ds,
  list(
    featureid=model$pid, 
    entity_type="dh_properties", 
    propcode=scenario_name
  ), 
  TRUE
)
if (is.na(model_scenario$pid)) {
  model_scenario$propname = paste(scenario_name)
  model_scenario$varid = ds$get_vardef('om_scenario')$varid
  model_scenario$save(TRUE)
}

model_status <- RomProperty$new(
  ds,
  list(
    featureid=model_scenario$pid, 
    entity_type="dh_properties", 
    propname='model_status'
  ), 
  TRUE
)
model_status$varid = ds$get_vardef('om_model_status')$hydroid
model_status$propvalue = model_status_flag
model_status$propcode = model_status_msg
model_status$save(TRUE)

if (is.na(model_status$pid)) {
  message(paste("Error: Could not set model status for",river_seg,">",rseg_ftype,">",model_version,">",scenario_name))
}
