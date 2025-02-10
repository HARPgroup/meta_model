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
gmodel_name <- as.character(argst[1])
riverseg <- as.character(argst[2])
hydrocode <- as.character(argst[3])
ftype <- as.character(argst[4])
gage_number <- as.character(argst[5])
model_version <- as.character(argst[6])
# what model to compare drainage area to
base_model_version <- as.character(argst[7])
# Inputs if using CBP Model -- otherwise, can ignore
model_root <- Sys.getenv(c('CBP_MODEL_ROOT'))[1]

# ESSENTIAL INPUTS
# If a gage is used -- all data is trimmed to gage timeframe.  Otherwise, start/end date defaults
# can be found in the gage.timespan.trimmed loop.

gage <- try(readNWISsite(gage_number))

# Load the VAHydro watershed entity via a river segment based hydrocode (useful in testing)
message(paste("searching for watershed", riverseg,"with hydrocode", hydrocode))
feature <- RomFeature$new(ds,list(hydrocode=hydrocode,bundle="watershed", ftype=ftype),TRUE)
hydroid = feature$hydroid

# any allow om_water_model_node, om_model_element as varkeys
gm <- RomProperty$new(
  ds,list(
    featureid = hydroid,
    entity_type = 'dh_feature',
    propname = gmodel_name,
    propcode = model_version
  ), TRUE)
if (is.na(gm$pid)) {
  # create new model
  gm$varid <- as.integer(ds$get_vardef('om_model_element')$varid)
  gm$save(TRUE)
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

if (base_model_version == FALSE) {
  message("Warning: No base model given. Exiting.")
}
# load the model data
da = NULL
base_model <- RomProperty$new(
  ds,
  list(
    featureid=feature$hydroid,
    propcode=base_model_version,
    entity_type='dh_feature'
  ),
  TRUE
)
if (is.na(base_model$pid)) {
  message(
    paste(
      "Warning: Base model not found for version",base_model_version,"... Exiting.")
    )
  q("no")
}
channel_prop <- RomProperty$new(
  ds,
  list(
    propname='0. River Channel',
    featureid=base_model$pid,
    entity_type='dh_properties'
  ),
  TRUE
)
if (is.na(channel_prop$pid)) {
  channel_prop <- RomProperty$new(
    ds,
    list(
      propname='local_channel',
      featureid=base_model$pid,
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

wscale = 1.0
# now, if da is not NULL we scale, otherwise assume gage area and watershed area are the same
if (is.na(da)) {
  message("Error: source model does not have drainage area object. Exiting.")
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

cat(gm$pid) # to act as positive returning function