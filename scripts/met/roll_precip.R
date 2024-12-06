suppressPackageStartupMessages(library(lubridate))
# Arguments passed in from command line:
#1 = The file path to the combined precip and flow data at that USGS gage
#2 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#3 = The rolling duration of precip to include prior to the storm. So, at
#rollingDur = 1 all precip will be summed from the storm duration only. At
#rollingDur = 2, the precip will be summed for the storm duration AND will
#include 1-day prior to the storm

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

# Inputs
comp_dataFilePath <- args[1]
stormStatsPath <- args[2]
rollingDur <- as.numeric(args[3])

# Reading in arguments
print("Reading in data from arguments...")
#Read in the combined precipitation and flow data for that USGS gage
comp_data <- read.csv(comp_dataFilePath,
                      stringsAsFactors = FALSE)

#If there are no non-NA flow values (may occur for a gage record that is
#incongruous with precip data timeframe), exit script and warn user
if(all(is.na(comp_data$obs_flow)) || all(is.na(comp_data$precip_cfs))){
  stop("No data was found in comp_data. Check to ensure precip and flow files have been populated.")
}

stormStats <- read.csv(stormStatsPath,stringsAsFactors = FALSE)

#A function that gets precip from the rollingDur period but will include the
#full stormDuration
getRollPrecip <- function(comp_data,stormDuration,
                          rollingDur,endDate,
                          precipColName = "prism_cfs",
                          obs_date = "obs_date"){
  #Convert input date to date, just in case
  sDate <- as.Date(endDate)
  #Get the index in comp_date df where the endDate occurs
  dateIndex <- grep(endDate,comp_data[,obs_date])
  
  #Adjust storm duration as needed. Necessary for daymet below:
  stormDurationAdj <- stormDuration
  
  #It is possible that dateIndex is NULL if the observed date doesn't exist in
  #comp_data. This could happen in daymet during leap years. So, check the next
  #day if the first doesn't exist and reduce the storm duration by 1
  if(length(dateIndex) == 0){
    dateIndex <- grep(sDate+ 1,comp_data[,obs_date])
    stormDurationAdj <- stormDurationAdj - 1
  }
  
  #Get all values from the precipColName in comp_data for the target duration
  #adjusted for the storm duration. So, if there is a five-day storm,
  #stormDuration is 5. If we are interested in rolling 7-day precip prior to and
  #throughout the storm, we'd want rollingDur = 7. So, we need dateIndex - 7 - 5
  #The precip data is in:
  precipData <- comp_data[,precipColName]
  precipStorm <- precipData[(dateIndex - rollingDur - stormDurationAdj + 2) : dateIndex]
  #Return total precip. Adjust for NAs that may occur due to indexing numbers
  #prior to start of comp_data
  totalPrecip <- sum(precipStorm * 86400,na.rm = TRUE)
  return(totalPrecip)
}

#Add to stormStats the sum of precipitation from the 3-, 7-, and 14-day periods
#leading up to the storm and including the full storm duration. Convert to MG
cfToMG <- 12*12*12/231/1000000

# add MG column to comp_data
comp_data$precip_MG<-cfToMG*86400*comp_data$precip_cfs

#Only precip during the storm iteself
print("Finding rolling precip over each storm duration...")
stormStats$rollDayWStorm_MG <- mapply(SIMPLIFY = TRUE, USE.NAMES = FALSE,
                                      FUN = getRollPrecip, stormDuration = stormStats$durAll,
                                      endDate = stormStats$endDate,
                                      MoreArgs = list(comp_data = comp_data, rollingDur = rollingDur,
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

write.csv(stormStats,stormStatsPath)
write.csv(comp_data,comp_dataFilePath)