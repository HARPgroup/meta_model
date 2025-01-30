# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")
suppressPackageStartupMessages(library(hydrotools)) 
suppressPackageStartupMessages(library(jsonlite)) #for exporting values as json

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
fcode <- argst[1]
scenario_name <- argst[2]
model_version <- argst[3]
bundlee <- argst[4]
ftype <- argst[5]

message(paste("Searching for feature hydrocode=", fcode,"with ftype",ftype))
feature<- RomFeature$new(
  ds,
  list(
    hydrocode=fcode,
    ftype=ftype,
    bundle=bundle
  ),
  TRUE
)
message(paste("Searching for model", model_version,"on feature",feature$hydroid))
model <- RomProperty$new(
  ds,
  list(
    featureid=feature$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
if (is.na(model$pid)) {
  model$propname = paste(feature$name, model_version)
  model$varid = ds$get_vardef('om_water_model_node')$varid
  model$save(TRUE)
}
message(paste("pid=",model$pid))
cat(model$pid)
