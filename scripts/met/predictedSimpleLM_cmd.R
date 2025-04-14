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


# For example Data:
# args[1]<-"http://deq1.bse.vt.edu:81/met/simple_lm_PRISM/precip/usgs_ws_01615000_precip_weekly.csv"
# args[2]<-"http://deq1.bse.vt.edu:81/met/simple_lm_PRISM/stats/usgs_ws_01615000-model.json"

weeklyDataFilePath <- args[1]
StatsPath <- args[2]
outPath <- args[3]

# Loading in files
weekly_precip_data <- read.csv(weeklyDataFilePath)
simpleLMs <-plotBin$new()
simpleLMs$fromJSON(StatsPath, TRUE)


# Confirming date column tyoe
weekly_precip_data$start_date <- as_date(weekly_precip_data$start_date)
weekly_precip_data$end_date <- as_date(weekly_precip_data$end_date)

# Creating emto\py column for predicted flow cfs
weekly_precip_data[,"predicted_flow"]=numeric()

predicted_data <- predict.flow(weekly_precip_data, simpleLMs, "precip_cfs", "mo")

predicted_data$rating <- 1-(abs(predicted_data$predicted_flow-predicted_data$obs_flow)/predicted_data$obs_flow)

# Write out new dataframe
write.csv(predicted_data,outPath, row.names = FALSE)





