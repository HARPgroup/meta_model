# Test datasets CSV
library("sqldf")
library("dataRetrieval")
library("lubridate")

#Get all arguments explicitly passed in from command line:
#1 = The file path to the combined precip and flow data at that USGS gage
#2 = The file path to the storms output by stormSep_USGS script
#3 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#4 = The path to write out plots to
#5 = details to include in the path to make file path more informative
args <- commandArgs(trailingOnly = TRUE)

comp_dataFilePath <- args[1]
stormPath <- args[2]
stormStatsPath <- args[3]
#The path to write plots out
pathToWrite <- args[4]
#The USGS gage number or hydro ID of the coverage that will be used to store
#this data with unique names
pathDetails <- args[5]

source(paste0(MET_SCRIPT_PATH,"/R/plotStorm.R"))

#Read in the combined precipitation and flow data for that USGS gage
comp_data <- read.csv(comp_dataFilePath,
                      stringsAsFactors = FALSE)

#Can we learn anything based on what stormSep gives us? e.g. the number of
#storms that occur in a given week, month, day, etc.?
#First, create a dataset where USGS flow is not NA
stormStats <- read.csv(stormStatsPath,stringsAsFactors = FALSE)
stormEvents <- read.csv(stormPath,stringsAsFactors = FALSE)

#Get a list of storm IDs:
stormIDs <- unique(stormEvents$stormID)

#For each storm in stormOut$Storms, use the storm start and end-date to find the
#7-day period leading up to the storm and the 7-day period following the storm.
#Show precip during this period and throughout storm duration. Then, highlight
#the separated storm hydrograph
for(i in 1:length(stormIDs)){
  print(i)
  #Get the current storm flow data which will be used for highlighting that
  #hydrograph
  stormi <- stormEvents[stormEvents$stormID == stormIDs[i],]
  #Only need non-NA values since stormSep will output full timeseries but leave
  #values as NA if they are not included in storm
  stormi <- stormi[!is.na(stormi$flow),]
  
  #Get the start and end date of the storm from stormStats:
  stormStart <- as.Date(stormStats$startDate[i])
  stormEnd <- as.Date(stormStats$endDate[i])
  #Adjust these values to increase the window:
  plotStart <- stormStart - 7
  plotEnd <- stormEnd + 7
  
  #Get the stream flow and baseflow from stormSep
  flowData <- stormEvents[stormEvents$timestamp >= plotStart & 
                            stormEvents$timestamp <= plotEnd,]
  #Join in the precip "flow" from comp_data:
  flowDataAll <- sqldf("SELECT flowData.*,
                          comp.precip_cfs,
                          comp.precip_in
                        FROM flowData
                        LEFT JOIN comp_data as comp
                          ON flowData.timeStamp = comp.obs_date")
  pathOut <- paste0(pathToWrite,"/stormPlot_",pathDetails,"_",i,".PNG")
  plotStorm(pathOut,stormi,flowDataAll)
}
