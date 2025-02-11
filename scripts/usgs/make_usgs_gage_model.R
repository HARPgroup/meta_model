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
gm_pid <- as.integer(argst[1]) # pid of the model that has been created
da <- as.character(argst[2]) # this is the area for this gage moe ltobe weighted to
gage_number <- as.character(argst[5])

# ESSENTIAL INPUTS
# If a gage is used -- all data is trimmed to gage timeframe.  Otherwise, start/end date defaults
# can be found in the gage.timespan.trimmed loop.
message(paste0("Calling readNWISsite(",gage_number.")"))
gage <- try(readNWISsite(gage_number))
# any allow om_water_model_node, om_model_element as varkeys
gm <- RomProperty$new(
  ds,list(
    pid = gm_pid
  ), TRUE
)
if (is.na(gm$pid)) {
  message("Error: No base model given. Exiting.")
  q("no")
}
site_no <- RomProperty$new(
  ds,list(
    featureid = gm$pid,
    entity_type = 'dh_properties',
    varkey = 'om_class_AlphanumericConstant',
    propname = 'site_no',
    propcode = gage_number
  ), TRUE
)
site_no$save(TRUE)

# load the model data

wscale = 1.0
# now, if da is not NULL we scale, otherwise assume gage area and watershed area are the same
if (is.na(da)) {
  message("Error: source model does not have drainage area object. Exiting.")
  cat(0)
  q("no")
}

# calc scaling factor
wscale <- as.numeric(as.numeric(da) / as.numeric(gage$drain_area_va))
# stash scaling factor
gda <- RomProperty$new(
  ds,list(
    featureid = gm$pid,
    entity_type = 'dh_properties',
    varkey = 'om_class_Constant',
    propname = 'drain_area_va',
    propvalue = as.numeric(gage$drain_area_va)
  ), TRUE
)
gda$save(TRUE)
# set the actual area of this moel segment
drainage_area <- RomProperty$new(
  ds,list(
    featureid = gm$pid,
    entity_type = 'dh_properties',
    varkey = 'om_class_Constant',
    propname = 'drainage_area',
    propvalue = as.numeric(drainage_area)
  ), TRUE
)
drainage_area$save(TRUE)
scaleprop <- RomProperty$new(
  ds,list(
    featureid = gm$pid,
    entity_type = 'dh_properties',
    varkey = 'om_class_Constant',
    propname = 'scale_factor',
    propvalue = as.numeric(wscale)
  ), TRUE
)
scaleprop$save(TRUE)

cat(1) # to act as positive returning function