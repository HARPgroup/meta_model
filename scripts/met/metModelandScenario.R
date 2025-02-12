#Creates the appropriate model and scenario properties for a given geo run and
#stores ratings:
# Example Inputs:
# coverage_hydrocode <- "usgs_ws_02021500"
# coverage_bundle <- 'watershed'
# coverage_ftype <- 'usgs_full_drainage'
# model_version <- 'met-1.0'
# rankingPropName <- 'simple_lm_PRISM'
# amalgamatePropName <- 'amalgamate_simple_lm'
# ratingsFile <- "http://deq1.bse.vt.edu:81/met/stormVol_prism/out/usgs_ws_02021500-PRISM-storm_volume-rating-ts.csv"


#Load in hydrotools and connect to REST
library(hydrotools)
basepath='/var/www/R'
source('/var/www/R/config.R')


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
rankingPropName <- argst[5]
#The model scenario property name specific to the workflow and defined in config
#file
amalgamatePropName <- argst[6]
#Input ratings file path to insert
ratingsFile <- argst[7]
#Area to write updated csv file to:
pathToWrite <- argst[8]

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
#If there are multiple model properties, om_model_object returns the first
#without checking propname. This will instead create a new property if the model
#name doesn't match the returned propname
if(model$propname != model_name){
  #Search for a property with the correct propname and other fields
  model <- RomProperty$new(ds, list(featureid = feature$hydroid, 
                                    entity_type = "dh_feature",
                                    propname = model_name,
                                    propcode = model_version), 
                           TRUE)
  model_varkey <- "om_model_element"
  #If nothing is found, create the new property
  if (is.na(model$pid)) {
    #Get the correct varid for the varkey used for the model
    model$varid = ds$get_vardef(model_varkey)$hydroid
    message(paste("Creating new feature model", model$propname, 
                  model$varid, model$featureid, model$propcode))
    #Save property
    model$save(TRUE)
  }
}

# this will create or retrieve a model scenario to house this summary data using
# romProperty
message(paste("Creating/finding model scenario on", model$pid, "with propname =",rankingPropName))
rankingScenario <- om_get_model_scenario(ds, model, rankingPropName)
message(paste("Ranking Scenario property with propname =",rankingScenario$propname," created/found with pid =",rankingScenario$pid))

# this will create or retrieve a model scenario to house the data selected by amalgamate
message(paste("Creating/finding model scenario on", model$pid, "with propname =",amalgamatePropName))
amalgamateScenario <- om_get_model_scenario(ds, model, amalgamatePropName)
message(paste("Amalgamate Scenario property with propname =",amalgamateScenario$propname," created/found with pid =",amalgamateScenario$pid))


if(!is.na(pathToWrite) & !is.na(ratingsFile)){
  #Read in the ratings file
  ratings <- read.csv(ratingsFile)
  
  #Convert the ratings start and end dates to seconds after epoch to insert into
  #DB
  ratings$start_date_sec <- as.numeric(as.POSIXct(ratings$start_date,tz = "EST"))
  ratings$end_date_sec <- as.numeric(as.POSIXct(ratings$end_date,tz = "EST"))
  
  #Add featureid and entity_type to ratings for proper export to dh_timeseries
  ratings$featureid <- rankingScenario$pid
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
}
