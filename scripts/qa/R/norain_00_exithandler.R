#For local testing:
# commandArgs <- function(...){
#   c("01613900")
# }

# Description ####
#POSTs results of norain_analysis.R
# Initialize ####
library(hydrotools)
basepath <- '/var/www/R'
source(paste(basepath,'config.R',sep='/'))

# get command line args
argst <- commandArgs(trailingOnly=T)

# Ex:
# argst = c("analysis.csv")
if (length(argst) < 3) {
  message("Args are:",argst[1]," ", argst[2])
  stop(paste("Use: norain_00_exithandler gageid scenario"))
}

# Inputs ####
gageid <- argst[1]
scenario <- argst[2]

# Gage ####
omgage <- hydrotools::WaterGageDaily$new(
  ds_in = ds, gage_id = gage_id,
  approval_status = 'all')
#Try to load the gage feature
omgage$load_wshd_feat()
#Skip if no data was loaded or a gage feature was not found
if (nrow(omgage$gage_data) == 0 || !inherits(omgage$gage_feature, "RomFeature")) {
  stop("No watershed feature found.")
}

## POST Results ####
# scenario is:
# norain_[yr]_[mo]_[da]
# Get AGWRC model property:
model <- ModelElementBase$new(
  ds,
  config = list(
    hydroid = omgage$gage_feature$hydroid, version = "AGWRC-1.0")
)

#Get norain scenario property:
sceninfo <- list(
  varkey = 'om_scenario',
  propname = scenario,
  featureid = model$pid,
  entity_type = "dh_properties",
  bundle = "dh_properties"
)
scenprop <- RomProperty$new(ds, sceninfo, TRUE)
scenprop$save(TRUE)

#Set forecast statuses including flags, minimum flow, and 90-day forecast to
#NULL to indicate failure:
scenprop$set_prop(propname = "is_emerg", propvalue = "", propcode = "")
scenprop$set_prop(propname = "is_hist", propvalue = "", propcode = "")
scenprop$set_prop(propname = "norain_fc", propvalue = "")
scenprop$set_prop(propname = "hist_Qmin", propvalue = "")

