suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(R6))
source("https://raw.githubusercontent.com/HARPgroup/meta_model/master/scripts/precip/lm_analysis_plots.R")

# Arguments passed in from command line;
#1 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#2 = The path to write out the full model JSON to

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

#Example:
# args[1]<-"http://deq1.bse.vt.edu:81/met/stormVol_prism/flow/usgs_ws_01615000-stormevent-stats.csv"
# args[2]<-"http://deq1.bse.vt.edu:81/met/stormVol_prism/stats/usgs_ws_01615000-model.json"

# Inputs
stormEventStatsPath <- args[1]
JSONPath <- args[2]
pathToWriteData <- args[3]

storm_event_data <- read.csv(stormEventStatsPath)

monthEventOut <-plotBin$new()
monthEventOut$fromJSON(JSONPath, TRUE)

# adding predicted flow to storm stats also MG
storm_event_data[,"predicted_flow"] <- numeric()

# Set start and end dtates as dates
storm_event_data$startDate <- as.Date(storm_event_data$startDate)
storm_event_data$endDate <- as.Date(storm_event_data$endDate)


predicted_data <- predict.flow(storm_event_data,monthEventOut, "rollDayWStorm_MG", "beginMonth")

# Adding Error using rating = 1 - abs(qobs-qmodel)/qobs
predicted_data$rating <- 1-(abs(predicted_data$predicted_flow-predicted_data$volumeAboveBaseQMG)/predicted_data$volumeAboveBaseQMG)


# Writing out predicted flow data as csv
write.csv(predicted_data,pathToWriteData,row.names = FALSE)
