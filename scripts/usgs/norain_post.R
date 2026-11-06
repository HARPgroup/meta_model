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
if (length(argst) < 2) {
  message(paste("Use: deq_norain.R analysis_csv"))
  q()
}

# Inputs ####
analysis_df <- read.csv(argst[1])

## POST Results ####
# scenario is:
# norain_[yr]_[mo]_[da]
# Get AGWRC model property:
model <- ModelElementBase$new(
  ds,
  config = list(
    hydroid = analysis_df$hydroid, version = "AGWRC-1.0")
)

#Get norain scenario property:
sceninfo <- list(
  varkey = 'om_scenario',
  propname = analysis_df$scenario,
  featureid = model$pid,
  entity_type = "dh_properties",
  bundle = "dh_properties"
)
scenprop <- RomProperty$new(ds, sceninfo, TRUE)
# Set the property dates for that of the forecast
scenprop$startdate <- as.numeric(as.POSIXct(analysis_df$proj_start_date, tz="America/New_York"))
scenprop$enddate <- as.numeric(as.POSIXct(analysis_df$proj_end_date, tz="America/New_York"))
scenprop$save(TRUE)

#Set forecast statuses including flags, minimum flow, and 90-day forecast:
scenprop$set_prop(propname = "is_emerg", propvalue = analysis_df$is_emerg_int,
                  propcode = analysis_df$is_emerg)
scenprop$set_prop(propname = "is_hist", propvalue = analysis_df$is_hist_int,
                  propcode = analysis_df$is_hist)
scenprop$set_prop(propname = "norain_fc", propvalue = analysis_df$norain_fc)
scenprop$set_prop(propname = "hist_Qmin", propvalue = analysis_df$hist_min)

