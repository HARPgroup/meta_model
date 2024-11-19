# Libraries
suppressPackageStartupMessages(library(sqldf))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(R6))
suppressPackageStartupMessages(library(jsonlite))

# Get all arguments passed in from command line
#1 = The file path to the weekly data for USGS gage
#2 = Filepath to JSON containing ratings and formula
#3 = Output filepath of new dataframe conteining predicted values and error ratings

source("https://raw.githubusercontent.com/HARPgroup/meta_model/master/scripts/precip/lm_analysis_plots.R")


# Setting arguments
args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

weekly_dataFilePath <- args[1]
StatsPath <- args[2]
outPath <- args[3]

# Loading in files
precip_data <- read.csv(weekly_dataFilePath)
simpleLMs <-plotBin$new()
simpleLMs$fromJSON(StatsPath, TRUE)


# Confirming date column tyoe
precip_data$start_date <- as_date(precip_data$start_date)
precip_data$end_date <- as_date(precip_data$end_date)

# Creating emtoy column for predicted flow
precip_data[,"predicted_flow_cfs"]=numeric()


predict.flow.weekly <- function(precip_data,simple_lm_model){
  # Create empty dataframe, for values ot be added to
  predicted_data <- precip_data[0,]
  # Find predicted values for each month
  for(i in 1:12){
    # Obtaining coefficients
    month <- as.numeric(i)
    coefficients <- simple_lm_model$atts$lms[[month]]$coefficients
    intercept <- coefficients[1]
    slope <- coefficients[2]
    # Getting Precip Data from the correct month
    message("Obtaining data from current month")
    new_predicted <- subset(precip_data, mo %in% month )
    # Inserting predicted flow into precip data frame (Units?)
    message("Calculating predicted flow")
    new_predicted$predicted_flow_cfs <- slope*new_predicted$precip_cfs + intercept
    
    #Adding data to dataframe
    predicted_data <- rbind(predicted_data,new_predicted)
  }
  return(predicted_data)
}


predicted_data <- predict.flow.weekly(precip_data,simpleLMs)

predicted_data$rating <- 1-(abs(predicted_data$predicted_flow_cfs-predicted_data$obs_flow)/predicted_data$obs_flow)


# Write out new dataframe
write.csv(predicted_data,outPath)





