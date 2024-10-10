#Creates the appropriate model and scenario properties for a given geo run and
#stores ratings:

#Example Inputs:
# coverage_hydrocode <- "usgs_ws_01668000"
# coverage_ftype <- 'usgs_full_drainage'
# coverage_bundle <- 'watershed'
# model_version <- 'met1.0'
# scenarioPropName <- 'simple_lm'
# ratingsFile <- "http://deq1.bse.vt.edu:81/met/stormVol_prism/out/usgs_ws_02021500-PRISM-storm_volume-rating-ts.csv"
# 

#Load in hydrotools and connect to REST
library(hydrotools)
basepath='/var/www/R'
source('/var/www/R/config.R')
ds <- RomDataSource$new(site = site, rest_uname)
ds$get_token(rest_pw)


argst <- commandArgs(trailingOnly = T)
#The base feature hydrocode e.g. the coverage on which ratings were developed
coverage_hydrocode <- argst[1]
#For USGS watersheds, this is 'watershed'
coverage_bundle <- argst[2]
#For USGS Watersheds, this is 'usgs_full_drainage'
coverage_ftype <- argst[3]
#met1.0 or some equivalent
model_version <- argst[4] 
#The model scenario property name specific to the workflow and defined in config
#file
scenarioPropName <- argst[5]
#Input ratings file path to insert
ratingsFile <- argst[6]
#Area to write updated csv file to:
pathToWrite <- argst[7]

#Read in the ratings file
ratings <- read.csv(ratingsFile)

#Convert the ratings start and end dates to seconds after epoch to insert into
#DB
ratings$start_date_sec <- as.numeric(as.POSIXct(ratings$start_date,tz = "EST"))
ratings$end_date_sec <- as.numeric(as.POSIXct(ratings$end_date,tz = "EST"))



# load the base feature for the coverage using romFeature and ds:
message(paste("Searching for feature hydrocode=", coverage_hydrocode,"with ftype",coverage_ftype))
feature <- RomFeature$new(
  ds,
  list(
    hydrocode = coverage_hydrocode,
    ftype = coverage_ftype,
    bundle = coverage_bundle
  ),
  TRUE
)
message(paste("Found feature with hydroid =", feature$hydroid))

#Create a name for the model property to be created on the feature:
model_name <- paste(coverage_hydrocode,model_version)

message(paste("Creating/finding model property on", feature$hydroid, "with propname =",model_name))
# if a matching model does not exist, this will go ahead and create one using
# romProperty
model <- om_model_object(ds, feature, model_version, 
                         model_name = model_name)
message(paste("Model property with propname =",model$propname," created/found with pid =",model$pid))

# this will create or retrieve a model scenario to house this summary data using
# romProperty
message(paste("Creating/finding model scenario on", model$pid, "with propname =",scenarioPropName))
scenario <- om_get_model_scenario(ds, model, scenarioPropName)
message(paste("Scenario property with propname =",scenario$propname," created/found with pid =",scenario$pid))

#Add featureid and entity_type to ratings for proper export to dh_timeseries
ratings$featureid <- scenario$pid
ratings$entity_type <- "dh_properties"
#Create a nicely formatted timeseries that will be easy to export to dh_timeseries
out <- data.frame(tstime = as.integer(ratings$start_date_sec),
                  tsendtime = as.integer(ratings$end_date_sec),
                  tsvalue = ratings$rating,
                  featureid = ratings$featureid,
                  entity_type = ratings$entity_type)
#Write out the formatted timeseries
message(paste("Writing out formatted timeseries to",pathToWrite))
write.csv(out,pathToWrite,row.names = FALSE)
