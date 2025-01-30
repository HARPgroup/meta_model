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
hydr_file_path <- argst[3]
model_version <- argst[4]
rseg_ftype <- argst[5]

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

if (is.na(model_scenario$pid)) {
  message("Error: could not locate model and scenario")
} else {
  cat(model_scenario$pid)
}
