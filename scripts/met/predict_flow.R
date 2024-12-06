suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(R6))

# Arguments passed in from command line;
#1 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#2 = The path to write out the full model JSON to

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

# Inputs
stormStatsPath <- args[1]
monthEventOut <- args[2]

stormStats <- read.csv(stormStatsPath)

# adding predicted flow to storm stats also
stormStats[,"predicted_flow_MG"]=numeric()

# Set start and end dtates as dates
stormStats$startDate <- as.Date(stormStats$startDate)
stormStats$endDate <- as.Date(stormStats$endDate)

# Add in predicted flow data
predict.flow <- function(storm_data,ratings_data){
  # Create empty dataframe, for values ot be added to
  predicted_data <- storm_data[0,]
  # Find predicted values for each month
  for(i in 1:12){
    # Obtaining coefficients
    month <- as.numeric(i)
    coefficients <- ratings_data$atts$lms[[month]]$coefficients
    intercept <- coefficients[1]
    slope <- coefficients[2]
    # Getting STorm Data from the correct month
    message("Obtaining data from input month")
    storm_data_new <- subset(storm_data, beginMonth %in% month )
    # Inserting predicted flow into precip data frame (guessing column name? Units?)
    message("Calculating predicted flow")
    storm_data_new$predicted_flow_MG <- slope*storm_data_new$rollDayWStorm_MG + intercept
    
    #Adding data to dataframe
    # predicted_data$predicted_flow_MG <- with(predicted_data,precip_data_new$predicted_flow[match(obs_date,precip_data_new$obs_date)]
    predicted_data <- rbind(predicted_data,storm_data_new)
  }
  return(predicted_data)
}

predicted_data <- predict.flow(stormStats,monthEventOut)

# Adding Error using rating = 1 - abs(qobs-qmodel)/qobs
predicted_data$rating <- 1-(abs(predicted_data$volumeAboveBaseQMG-predicted_data$predicted_flow_MG)/predicted_data$volumeAboveBaseQMG)

predicted_data <- predicted_data[,c("startDate","endDate","rating")]

names(predicted_data)<-c("start_date", "end_date", "rating")

# Writing out predicted flow data as csv
write.csv(predicted_data,pathToWriteData)
