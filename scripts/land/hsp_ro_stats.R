# This script will convert the pwater csv to a data table and perform 
# time series and trend analysis by generating graphs and summary statistics.
#install.packages("IHA", repos="http://R-Forge.R-project.org")
#install_github("HARPGroup/hydro-tools", force=TRUE)
basepath='/var/www/R';
source("/var/www/R/config.R") # will need file in same folder/directory

suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(zoo))
suppressPackageStartupMessages(library(PearsonDS))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(R.utils))


#message(R_TempDir)
# establishing location on server for storing images
omsite = "http://deq1.bse.vt.edu:81"

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
land_segment_name <- argst[1]
scenario_name <- argst[2]
pwater_file_path <- argst[3] 
image_directory_path <- argst[4] 
#cbp_export_dir=Sys.getenv(c('CBP_EXPORT_DIR'))[1]
#image_directory_path <- paste0(cbp_export_dir,'/land/', scenario, '/images')
#image_directory_path <- '/media/model/p532/out/land/hsp2_2022/images' # needs to be commented when running on the server 
model_version <- argst[5]
lseg_ftype <- argst[6]

# Get the data
pwater <- fread(pwater_file_path)
pwater$date <- as.Date(pwater$index, format = "%m/%d/%Y %H:%M")
pwater$week <- week(pwater$date)
pwater$month <- month(pwater$date)
pwater$year <- year(pwater$date)

minyr <- min(pwater$year)
maxyr <- max(pwater$year)
# 1. Decomposition: 
# response = trend + seasonal + random
# $trend, $seasonal, and $random can be individually plotted from the stacked plot

# 2. Yearly Median - stats

# Exporting to VAHydro

# Set up our data source
ds <- RomDataSource$new(site, rest_uname = rest_uname)
ds$get_token(rest_pw)

# TBD: get inputs from the comand line
#  For now we just load some samples
lseg_name=land_segment_name

landseg<- RomFeature$new(
  ds,
  list(
    hydrocode=lseg_name, 
    ftype=lseg_ftype,
    bundle='landunit'
  ), 
  TRUE
)

model <- RomProperty$new(
  ds,
  list(
    featureid=landseg$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
message(paste("Saving landseg model", model$propcode, model$entity_type, model$featureid, model$propcode))
if (is.na(model$pid)) {
  model$propname = landseg$name
  model$varid = ds$get_vardef('om_model_element')$varid
#  message(paste("Saving landseg model", model$propname, model$varid, model$featureid, $model$propcode))
  model$save(TRUE)
}


model_scenario <- RomProperty$new( #Re-ordered scenario to be within the model element and the land use within the scenario
  ds,
  list(
    varkey="om_scenario", 
    featureid=model$pid, 
    entity_type="dh_properties", 
    propname=scenario_name, 
    propcode=scenario_name 
  ), 
  TRUE
)
model_scenario$save(TRUE)

lu <- RomProperty$new(
  ds,
  list(
    varkey="om_hspf_landuse", 
    propname='landuses',
    featureid=model_scenario$pid, 
    entity_type="dh_properties"
  ), 
  TRUE
)
lu$save(TRUE)

# Create/Load a model scenario property
# tstime = the run time 
# note: do not set tstime when retrieving since if we have a previous
#       timesereies event already set, we want to gt it and may not know the tstime
# 


# Uploading constants to VaHydro:
# entity-type specifies what we are attaching the constant to 
#Implementing containers for VAHydro

model_out_file <- RomProperty$new(
  ds, list(
    varkey="external_file",
    featureid=model_scenario$pid,
    entity_type='dh_properties',
    propcode = pwater_file_path,
    propname = 'outfile'
  ),
  TRUE
)
model_out_file$save(TRUE)

