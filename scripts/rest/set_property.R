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
if (length(argst) < 5) {
  message("Use: set_property.R entity_type entity_id varkey (can use 'auto') propname propvalue [propcode] [data_matrix (json string)]")
  q()
}
entity_type <- argst[1]
entity_id <- as.integer(argst[2])
varkey <- argst[3]
if (varkey == 'auto') {
  varkey = NULL # uses guessing feature of routine
}
propname <- argst[4]
propvalue <- argst[5]
if (propvalue == "NA") {
  propvalue = NA
}
propcode = NA
if (length(argst) > 5) {
  propcode <- argst[6]
  if (propcode == "NA") {
    propcode = NA
  }
}
data_matrix=NA
if (length(argst) > 6) {
  data_matrix <- argst[7]
  if (data_matrix == "NA") {
    data_matrix = NA
  }
}
parent = FALSE
if (entity_type == "dh_feature") {
  parent = RomFeature$new(ds,list(hydroid=entity_id),TRUE)
} else if (entity_type == "dh_properties") {
  parent = RomProperty$new(ds,list(pid=entity_id),TRUE)
}

if (is.logical(parent)) {
  message(paste("Cannot handle entity_type ",entity_type,". quitting."))
  q()
}
if (!("RomEntity" %in% class(parent))) {
  message(paste("Cannot find entity of entity_type ",entity_type, "id", entity_id,". quitting."))
  q()
}
if (!(parent$get_id() > 0)) {
  message(paste("Cannot find entity of entity_type ",entity_type, "id", entity_id,". quitting."))
  q()
}
if (!is.na(propvalue)) {
  parent$set_prop(propname,propvalue=propvalue,varkey=varkey)
}
if (!is.na(propcode)) {
  parent$set_prop(propname,propcode=propcode,varkey=varkey)
}
if (!is.na(data_matrix)) {
  parent$set_matrix(propname,jsonlite::fromJSON(data_matrix))
}

message("Complete.")
