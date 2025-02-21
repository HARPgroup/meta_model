# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")
suppressPackageStartupMessages(library(hydrotools)) 
suppressPackageStartupMessages(library(jsonlite)) #for exporting values as json

# Accepting command arguments:
# argst = c("dh_properties", 7700740, "drainage_area", "propvalue")
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 4) {
  message("Use: set_property.R entity_type entity_id propname propvalue [propcode] [data_matrix (json string)]")
  q()
}
entity_type <- argst[1]
entity_id <- as.integer(argst[2])
prop_name <- argst[3]
propvalue <- argst[4]
if (propvalue == "NA") {
  propvalue = NA
}
propcode = NA
if (length(argst) > 4) {
  propcode <- argst[5]
  if (propcode == "NA") {
    propcode = NA
  }
}
data_matrix=NA
if (length(argst) > 5) {
  data_matrix <- argst[6]
  if (data_matrix == "NA") {
    data_matrix = NA
  }
}
parent = FALSE
if (entity_type = "dh_feature") {
  parent = RomFeature$new(ds,list(hydroid=entity_id))
} else if (entity_type = "dh_properties") {
  parent = RomProperty$new(ds,list(featureid=entity_id))
}

if ( (parent == FALSE)) {
  message(paste("Cannot handle entity_type ",entity_type,". quitting."))
  q()
}
if (is.na(parent$pid)) {
  message(paste("Cannot find entity of entity_type ",entity_type, "id", entity_id,". quitting."))
  q()
}
if (!is.na(propvalue)) {
  parent$set_prop(propname,propvalue=propvalue)
}
if (!is.na(propcode)) {
  parent$set_prop(propname,propcode=propcode)
}
if (!is.na(data_matrix)) {
  parent$set_matrix(propname,jsonlite::fromJSON(data_matrix))
}

message("Complete.")
