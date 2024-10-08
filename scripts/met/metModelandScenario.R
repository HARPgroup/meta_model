#Creates the appropriate model and scenario properties for a given geo run and
#stores ratings:

#Example Inputs:
# coverage_hydrocode <- "usgs_ws_01668000"
# coverage_ftype <- 'usgs_full_drainage'
# coverage_bundle <- 'watershed'
# model_version <- 'met1.0'
# scenarioPropName <- 'simple_lm'
# ratingsFile <- "C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-nldas-storm_volume-rating-ts.csv"


#Load in hydrotools and connect to REST
library(hydrotools)
basepath='/var/www/R'
source('/var/www/R/config.R')
ds <- RomDataSource$new("http://deq1.bse.vt.edu/d.dh", rest_uname)
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

#Create a name for the model property to be created on the feature:
model_name <- paste(coverage_hydrocode,model_version)
# if a matching model does not exist, this will go ahead and create one using
# romProperty
model <- om_model_object(ds, feature, model_version, 
                         model_name = model_name)


# this will create or retrieve a model scenario to house this summary data using
# romProperty
scenario <- om_get_model_scenario(ds, model, scenarioPropName)

ratings$featureid <- scenario$pid
ratings$entity_type <- "dh_properties"

out <- data.frame(tstime = as.integer(ratings$start_date_sec),
                  tsendtime = as.integer(ratings$end_date_sec),
                  tsvalue = ratings$rating,
                  featureid = ratings$featureid,
                  entity_type = ratings$entity_type)

write.csv(out,pathToWrite,row.names = FALSE)
