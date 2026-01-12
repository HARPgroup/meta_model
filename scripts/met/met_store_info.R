# Insert info about this event into database
# attach a property showing the path to the original raster file
# attach a property with a web URL to the origina raster file
basepath='/var/www/R';
library("lubridate")
source("/var/www/R/config.R")

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 6) {
  message("Use: Rscript met_store_info.R scenario coverage_hydrocode coverage_bundle coverage_ftype model_version met_file")
  message("Ex: Rscript met_store_info.R nldas2 N5113 landunit cbp6_landseg met_file")
  q('n')
}
scenario_name <- argst[1]
coverage_hydrocode <- argst[2]
coverage_bundle <- argst[3]
coverage_ftype <- argst[4]
model_version <- argst[5] 
met_file <- argst[6] 
# load the feature -- get feature hydroid
# find the dh_timeseries_weather record for this event
# attach an image property to the record
# return 

message(paste("Searching for feature hydrocode =", coverage_hydrocode,"with ftype",coverage_ftype))
feature <- RomFeature$new(
  ds,
  list(
    hydrocode=coverage_hydrocode,
    ftype=coverage_ftype,
    bundle=coverage_bundle
  ),
  TRUE
)
# this will create or retrieve a model scenario to house this summary data.
model <- om_model_object(ds, feature, model_version)
# if a matching model does not exist, this will go ahead and create one
scenario <- om_get_model_scenario(ds, model, scenario_name)
# THIS DOES NOT DO ANYTHING - this is copied from elsewhere as a template but
# no data model has been created to detail what we would like to store
# maybe this should be a timeseries?  Just have a link to the file with a 
# tstime stamp that indicates what day/hour it is?
met_data <- read.table(met_file, header = TRUE, sep=",")
numrecs <- nrow(met_data)
vahydro_post_metric_to_scenprop(scenario$pid, 'om_class_Constant', NULL, 'num_records', numrecs, ds)
