# Test datasets CSV
library("sqldf")
library("dataRetrieval")
library("lubridate")

#Get all arguments explicitly passed in from command line:
#1 = The file path to the combined precip and flow data at that USGS gage
#2 = The file path for MET_SCRIPT_PATH in the meta model e.g. the path from
#which to source scripts
#3 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#4 = The file path to the storms output by stormSep_USGS script
#5 = The rolling duration of precip to include prior to the storm. So, at
#rollingDur = 1 all precip will be summed from the storm duration only. At
#rollingDur = 2, the precip will be summed for the storm duration AND will
#include 1-day prior to the storm
#6 = powerRegressoin = Should the regressions performed be power regression?
args <- commandArgs(trailingOnly = TRUE)
comp_dataFilePath <- args[1]
MET_SCRIPT_PATH <- args[2]
stormStatsPath <- args[3]
stormPath <- args[4]
rollingDur <- args[5]

if(is.null(args[6])){
  powerRegressoin <- FALSE
}else{
  powerRegressoin <- args[7]
}


# source("C:/Users/gcw73279.COV/Desktop/gitBackups/OWS/HARParchive/HARP-2024-2025/stormSep_USGS.R")
source(paste0(MET_SCRIPT_PATH,"/stormSep_USGS.R"))

#Read in the combined precipitation and flow data for that USGS gage
comp_data <- read.csv(comp_dataFilePath,
                      stringsAsFactors = FALSE)

#Can we learn anything based on what stormSep gives us? e.g. the number of
#storms that occur in a given week, month, day, etc.?
#First, create a dataset where USGS flow is not NA

stormStats <- read.csv(stormStatsPath,stringsAsFactors = FALSE)

stormSepDF <- read.csv(stormPath,stringsAsFactors = FALSE)

# stormCompData <- comp_data[!is.na(comp_data$usgs_cfs),]

#For each storm, sum precip leading up to it and including the storm (past 3, 5,
#7, and 14 days?). Go through each storm and find the sum of precip of each
#dataset. For further exploration in the future: What about stream length? What
#about DA or other NHDPLus factors? Can we get at travel time and or lag? Land
#use?

#Throw out any storms that have inconsistent durations compared to start and end
#date. This can occur when a gage goes offline as StormSep doesn't check for
#this
QCStorms <- stormStats$ID[(as.Date(stormStats$endDate) - as.Date(stormStats$startDate) + 1) == stormStats$durAll]
stormEvents <- stormSepDF[stormSepDF$stormID %in% QCStorms]
stormStats <- stormStats[(as.Date(stormStats$endDate) - as.Date(stormStats$startDate) + 1) == stormStats$durAll,]

#Get a list of storm IDs:
stormIDs <- unique(stormEvents$stormID)

#A function that gets precip from the rollingDur period but will include the
#full stormDuration
getRollPrecip <- function(comp_data,stormDuration,
                          rollingDur,endDate,
                          precipColName = "prism_p_cfs"){
  #Convert input date to date, just in case
  sDate <- as.Date(endDate)
  #Get the index in comp_date df where the endDate occurs
  dateIndex <- grep(endDate,comp_data$date)
  #Get all values from the precipColName in comp_data for the target duration
  #adjusted for the storm duration. So, if there is a five-day storm,
  #stormDuration is 5. If we are interested in rolling 7-day precip prior to and
  #throughout the storm, we'd want rollingDur = 7. So, we need dateIndex - 7 - 5
  #The precip data is in:
  precipData <- comp_data[,precipColName]
  precipStorm <- precipData[(dateIndex - rollingDur - stormDuration + 2) : dateIndex]
  #Return total precip. Adjust for NAs that may occur due to indexing numbers
  #prior to start of comp_data
  totalPrecip <- sum(precipStorm,na.rm = TRUE)
  return(totalPrecip)
}

#Add to stormStats the sum of precipitation from the 3-, 7-, and 14-day periods
#leading up to the storm and including the full storm duration. Convert to MG
cfsToMGD <- 86400 * 12*12*12/231/1000000
#Only precip during the storm iteself
stormStats$rollDayWStorm_MG <- mapply(SIMPLIFY = TRUE, USE.NAMES = FALSE,
                                            FUN = getRollPrecip, stormDuration = stormStats$durAll,
                                            endDate = stormStats$endDate,
                                            MoreArgs = list(comp_data = comp_data,rollingDur = rollingDur,
                                                            precipColName = "prism_p_cfs")
)
stormStats$rollDayWStorm_MG <- stormStats$rollDayWStorm_MG * cfsToMGD

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

# A simple function that computes a linear regression of the input y_var and
# x_var for each month of the sample_data. Does not distinguish between years
# and will thus group all available data as possible. It will return the linear
# model object as well as a summary data frame showing the sample count and r^2
# produced each month
mon_lm <- function(sample_data, y_var, x_var, mo_var){
  #Create an empty list to store the linear models
  lms <- list()
  #Create an empty data frame to store the sample count "n" and the adjusted r
  #squared ("rsquared_a") for each month of the year
  lmStats <- data.frame('month' = 1:12, 'rsquared_a' = NA,'n' = NA)
  #For each month, create a linear model of y_var ~ x_var and store the relevant
  #information for output
  for (i in 1:12) {
    #Find only the data in this month of the loop, i
    mo_data <- sample_data[sample_data[,mo_var] == i,]
    #Return NA by default:
    lms[[i]] <- NA
    
    #If there is sufficient data, find the linear model between y_var and x_var
    if(length(mo_data[,y_var]) >= 2){
      #Create a linear model between this month's y_var and x_var
      weekmo_data <- lm(mo_data[,y_var] ~ mo_data[,x_var])
      #Store the linear model in the list lms in the index equal to the current
      #loop iteration i
      lms[[i]] <- weekmo_data
      #Get the summary of the linear model to find some summary statistics
      dsum <- summary(weekmo_data)
      #Store the sample count and the adjusted R squared:
      lmStats$rsquared_a[lmStats$month == i] <- dsum$adj.r.squared
      lmStats$n <- length(weekmo_data$residuals)
    }
  }
  #Return the linear models and stats:
  out <- list(lms = lms,lmStats = lmStats)
  
  return(out)
}


#There may be some heavy influence from high storm events. May want to consider
#power regressions or non-linear exponential regressions to reduce their
#influence or evens a Cooks Distance analysis to remove errant data points
if(powerRegressoin){
  stormStats$LOGvolumeAboveBaseQMG <- log(stormStats$volumeAboveBaseQMG)
  stormStats$LOGroll1DayWStorm_MG <- log(stormStats$roll1DayWStorm_MG)
  #What are the monthly relationships?
  monthEventOut <- mon_lm(stormStats, y_var = "volumeAboveBaseQMG",
                             x_var = "roll1DayWStorm_MG",
                             mo_var = "beginMonth", "Storm Event Vol")
}else{
  #What are the monthly relationships?
  monthEventOut <- mon_lm(stormStats, y_var = "LOGvolumeAboveBaseQMG",
                             x_var = "LOGroll1DayWStorm_MG",
                             mo_var = "beginMonth", "Storm Event Vol")
}

#WRITE OUT DATA. GET STATS OR JSON OUTPUT
write.csv(monthEventOut$stats)


#For each storm in stormEvents, use the storm start and end-date to find the
#7-day period leading up to the storm and the 7-day period following the storm.
#Show precip during this period and throughout storm duration. Then, highlight
#the separated storm hydrograph
for(i in 1:length(stormIDs)){
  print(i)
  #Get the current storm flow data which will be used for highlighting that
  #hydrograph
  stormi <- stormEvents[stormEvents$stormID == stormIDs[i]]
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
  flowData <- stormOut$flowData[stormOut$flowData$timestamp >= plotStart & 
                                  stormOut$flowData$timestamp <= plotEnd,]
  #Join in the precip "flow" from comp_data:
  flowDataAll <- sqldf("SELECT flowData.*,
                          comp.prism_p_in,
                          comp.daymet_p_in,
                          comp.nldas2_p_in,
                          comp.prism_p_cfs,
                          comp.daymet_p_cfs,
                          comp.nldas2_p_cfs
                        FROM flowData
                        LEFT JOIN comp_data as comp
                          ON flowData.timeStamp = comp.Date")
  pathOut <- paste0("StormPlotsNew/stormPlot",i,".PNG")
  plotStorm(pathOut,stormi,flowDataAll)
}
