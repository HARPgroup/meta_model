# Test datasets CSV
library("sqldf")
library("dataRetrieval")
library("lubridate")
library("R6")
library("jsonlite")
#Get all arguments explicitly passed in from command line:
#1 = The file path to the combined precip and flow data at that USGS gage
#2 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#3 = The file path to the storms output by stormSep_USGS script
#4 = The rolling duration of precip to include prior to the storm. So, at
#rollingDur = 1 all precip will be summed from the storm duration only. At
#rollingDur = 2, the precip will be summed for the storm duration AND will
#include 1-day prior to the storm
#5 = Path out to write to full model JSON to
#6 = Path out to write csv of the regresison stats/ratings to
#7 = STORMSEP_REGRESSION_METHOD = Should the regressions performed be power
#regression or linear regression
args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")
comp_dataFilePath <- args[1]
stormStatsPath <- args[2]
stormPath <- args[3]
rollingDur <- as.numeric(args[4])
pathToWriteJSON <- args[5]
pathToWriteRatings <- args[6]
pathToWritePlots <- args[7]

if(is.na(args[8])){
  regressionMethod <- "LINEAR"
}else{
  regressionMethod <- args[8]
  if(!(regressionMethod %in% c("POWER","LINEAR"))){
    print(paste0("No method exists for ",regressionMethod," regression. Performing linear regression instead. Check config file..."))
    regressionMethod <- "LINEAR"
  }
  
}

#Need plotBin R6 and mon_lm functions
source("https://raw.githubusercontent.com/HARPgroup/HARParchive/master/HARP-2024-2025/functions/lm_analysis_plots.R")

print("Reading in data from arguments...")
#Read in the combined precipitation and flow data for that USGS gage
comp_data <- read.csv(comp_dataFilePath,
                      stringsAsFactors = FALSE)

#Can we learn anything based on what stormSep gives us? e.g. the number of
#storms that occur in a given week, month, day, etc.?
#First, create a dataset where USGS flow is not NA
stormStats <- read.csv(stormStatsPath,stringsAsFactors = FALSE)

stormSepDF <- read.csv(stormPath,stringsAsFactors = FALSE)

#For each storm, sum precip leading up to it and including the storm (past 3, 5,
#7, and 14 days?). Go through each storm and find the sum of precip of each
#dataset. For further exploration in the future: What about stream length? What
#about DA or other NHDPLus factors? Can we get at travel time and or lag? Land
#use?

print("Parsing storms outside of comp_data or with bad timestamps...")
#Convert relevant fields to date
stormStats$startDate <- as.Date(stormStats$startDate)
stormSepDF$timestamp <- as.Date(stormSepDF$timestamp)
comp_data$obs_date <- as.Date(comp_data$obs_date)

#Remove any storms that occur prior to the precip record:
stormStats <- stormStats[stormStats$startDate >= min(comp_data$obs_date),]
stormSepDF <- stormSepDF[stormSepDF$timestamp >= min(comp_data$obs_date),]
#Remove any storms that occur after precip record
stormStats <- stormStats[stormStats$endDate <= max(comp_data$obs_date),]
stormSepDF <- stormSepDF[stormSepDF$timestamp <= max(comp_data$obs_date),]

#Throw out any storms that have inconsistent durations compared to start and end
#date. This can occur when a gage goes offline as StormSep doesn't check for
#this
QCStorms <- stormStats$ID[(as.Date(stormStats$endDate) - as.Date(stormStats$startDate) + 1) == stormStats$durAll]
stormEvents <- stormSepDF[stormSepDF$stormID %in% QCStorms,]
stormStats <- stormStats[(as.Date(stormStats$endDate) - as.Date(stormStats$startDate) + 1) == stormStats$durAll,]

#Get a list of storm IDs:
stormIDs <- unique(stormEvents$stormID)

#A function that gets precip from the rollingDur period but will include the
#full stormDuration
getRollPrecip <- function(comp_data,stormDuration,
                          rollingDur,endDate,
                          precipColName = "prism_p_cfs",
                          obs_date = "obs_date"){
  #Convert input date to date, just in case
  sDate <- as.Date(endDate)
  #Get the index in comp_date df where the endDate occurs
  dateIndex <- grep(endDate,comp_data[,obs_date])
  #Get all values from the precipColName in comp_data for the target duration
  #adjusted for the storm duration. So, if there is a five-day storm,
  #stormDuration is 5. If we are interested in rolling 7-day precip prior to and
  #throughout the storm, we'd want rollingDur = 7. So, we need dateIndex - 7 - 5
  #The precip data is in:
  precipData <- comp_data[,precipColName]
  precipStorm <- precipData[(dateIndex - rollingDur - stormDuration + 2) : dateIndex]
  #Return total precip. Adjust for NAs that may occur due to indexing numbers
  #prior to start of comp_data
  totalPrecip <- sum(precipStorm * 86400,na.rm = TRUE)
  return(totalPrecip)
}

#Add to stormStats the sum of precipitation from the 3-, 7-, and 14-day periods
#leading up to the storm and including the full storm duration. Convert to MG
cfToMG <- 12*12*12/231/1000000
#Only precip during the storm iteself
print("Finding rolling precip over each storm duration...")
stormStats$rollDayWStorm_MG <- mapply(SIMPLIFY = TRUE, USE.NAMES = FALSE,
                                            FUN = getRollPrecip, stormDuration = stormStats$durAll,
                                            endDate = stormStats$endDate,
                                            MoreArgs = list(comp_data = comp_data,rollingDur = rollingDur,
                                                            precipColName = "precip_cfs",
                                                            obs_date = "obs_date")
)
stormStats$rollDayWStorm_MG <- stormStats$rollDayWStorm_MG * cfToMG

#Includes 1-day prior to the storm:
# stormStats$roll2DayWStorm_MG <- mapply(SIMPLIFY = TRUE, USE.NAMES = FALSE,
#                                             FUN = getRollPrecip, stormDuration = stormStats$durAll,
#                                             endDate = stormStats$endDate,
#                                             MoreArgs = list(comp_data = comp_data,rollingDur = 2,
#                                                             precipColName = "prism_p_cfs")
# )
# stormStats$roll2DayWStorm_MG <- stormStats$roll2DayWStorm_MG * cfsToMGD


#The relationship will improve as we look only at specific months. Add month
#based on the startDate of the storm
stormStats$beginMonth <- as.numeric(format(as.Date(stormStats$startDate),"%m"))

#There may be some heavy influence from high storm events. May want to consider
#power regressions or non-linear exponential regressions to reduce their
#influence or evens a Cooks Distance analysis to remove errant data points
if(regressionMethod == "POWER"){
  print("Conducting power regressions on storm and precip event volume...")
  stormStats$LOGvolumeAboveBaseQMG <- log(stormStats$volumeAboveBaseQMG)
  stormStats$LOGrollDayWStorm_MG <- log(stormStats$rollDayWStorm_MG)
  #What are the monthly relationships?
  monthEventOut <- mon_lm_stats(stormStats, y_var = "LOGvolumeAboveBaseQMG",
                               x_var = "LOGrollDayWStorm_MG",
                               mo_var = "beginMonth")
}else if(regressionMethod == "LINEAR"){
  print("Conducting linear regressions on storm and precip event volume...")
  #What are the monthly relationships?
  monthEventOut <- mon_lm_stats(stormStats, y_var = "volumeAboveBaseQMG",
                               x_var = "rollDayWStorm_MG",
                               mo_var = "beginMonth")
}

print("Writing out data to JSON and ratings to csv...")
# This outputs our residuals
for (i in 1:12){
  png(paste0(pathToWritePlots, "_Month",i,".png"))
  plot(monthEventOut$atts$lms[[i]],1)
  dev.off()
}


print("Writing out data to JSON and ratings to csv...")
#WRITE OUT DATA. GET STATS OR JSON OUTPUT
out <- monthEventOut$toJSON()
write(out,pathToWriteJSON)
write.csv(monthEventOut$atts$stats,pathToWriteRatings)


