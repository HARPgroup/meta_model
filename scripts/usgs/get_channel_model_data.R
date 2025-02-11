library(stringr)
# SETTING UP BASEPATH AND SOURCING FUNCTIONS
#----------------------------------------------
# site <- "http://deq2.bse.vt.edu/d.dh"    #Specify the site of interest, either d.bet OR d.dh
# this is set in config.R
#----------------------------------------------
# Load Libraries
basepath='/var/www/R';
source(paste(basepath,'config.R',sep='/'))
library(dataRetrieval)

# Read Args
# if testing:
# riverseg = 'PM7_4580_4820_difficult_run'
# runid = 2
# gage_number = '01646000'
# model_scenario = 'vahydro-1.0'
# argst <- c("01646000_PM7_4581_4580", PM7_4581_4580", 'vahydrosw_wshed_PM7_4581_4580', "vahydro", '01646000', 'usgs-2.0', 'vahydro-1.0')
argst <- commandArgs(trailingOnly=T)
pid <- as.integer(argst[1])

# load the model data
da = NULL
channel_prop <- RomProperty$new(
  ds,
  list(
    propname='0. River Channel',
    featureid=pid,
    entity_type='dh_properties'
  ),
  TRUE
)
if (is.na(channel_prop$pid)) {
  channel_prop <- RomProperty$new(
    ds,
    list(
      propname='local_channel',
      featureid=pid,
      entity_type='dh_properties'
    ),
    TRUE
  )
}
if (is.na(channel_prop$pid)) {
  message("Error: source model does not have channel object. Exiting.")
  q("no")
}
daprop <-  RomProperty$new(ds, list (
  propname = 'drainage_area',
  featureid = channel_prop$pid,
  entity_type = 'dh_properties'
), TRUE)
da <- as.numeric(daprop$propvalue)
aprop <-  RomProperty$new(ds, list (
  propname = 'area',
  featureid = channel_prop$pid,
  entity_type = 'dh_properties'
), TRUE)
local_area <- as.numeric(aprop$propvalue)
aprop <-  RomProperty$new(ds, list (
  propname = 'length',
  featureid = channel_prop$pid,
  entity_type = 'dh_properties'
), TRUE)
channel_length <- as.numeric(aprop$propvalue)

cat(paste(da,local_area,channel_length,sep=",")) # return to console