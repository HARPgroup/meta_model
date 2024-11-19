# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")
suppressPackageStartupMessages(library(hydrotools)) 
suppressPackageStartupMessages(library(jsonlite)) #for exporting values as json

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
entity_type <- argst[1]
entity_id <- argst[2]
prop_name <- argst[3]
return_name <- argst[4]

# Set up our data source
ds <- RomDataSource$new(site, rest_uname = rest_uname)
ds$get_token(rest_pw)
message(paste("Searching for prop", prop_name,"on ",entity_id))
model <- RomProperty$new(
  ds,
  list(
    featureid=entity_id, 
    entity_type=entity_type, 
    propname=prop_name
  ), 
  TRUE
)
if (return_name == 'json') {
  retval = serialize(model)
} else {
  retval <- model$to_list()[[return_name]]
}
cat(retval)
