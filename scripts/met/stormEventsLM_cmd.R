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
#7 = Path to write lm resid plots to
#8 = Plot name details
#9 = STORMSEP_REGRESSION_METHOD = Should the regressions performed be power
#regression or linear regression

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")


comp_dataFilePath <- args[1]
stormStatsPath <- args[2]
stormPath <- args[3]
rollingDur <- as.numeric(args[4])
pathToWriteJSON <- args[5]
pathToWriteRatings <- args[6]
pathToWriteData <- args[7]

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
source("https://raw.githubusercontent.com/HARPgroup/meta_model/master/scripts/precip/lm_analysis_plots.R")

print("Reading in data from arguments...")
#Read in the combined precipitation and flow data for that USGS gage
comp_data <- read.csv(comp_dataFilePath,
                      stringsAsFactors = FALSE)

#If there are no non-NA flow values (may occur for a gage record that is
#incongruous with precip data timeframe), exit script and warn user
if(all(is.na(comp_data$obs_flow)) || all(is.na(comp_data$precip_cfs))){
  stop("No data was found in comp_data. Check to ensure precip and flow files have been populated.")
}

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

# add MG column to comp_data ####################################
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

# Optional: removing ratings if they ar enot between -1 and 1
# predicted_data$rating <- replace(predicted_data$rating, -1 > predicted_data$rating, NA)
# predicted_data$rating <- replace(predicted_data$rating, 1 < predicted_data$rating, NA)



# default to r-squared value for the month
# 

print("Writing out data to JSON and ratings to csv...")

#Rename the ratings before writing them out
ratingsOut <- monthEventOut$atts$stats
names(ratingsOut) <- c('mo', 'rating') 

#WRITE OUT DATA. GET STATS OR JSON OUTPUT
out <- monthEventOut$toJSON()
write(out,pathToWriteJSON)
write.csv(monthEventOut$atts$stats,pathToWriteRatings)
write.csv(predicted_data,pathToWriteData)
