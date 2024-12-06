suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(R6))

# Arguments passed in from command line;
#1 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#2 = The path to write out the full model JSON to
#3 = STORMSEP_REGRESSION_METHOD = Should the regressions performed be power
#regression or linear regression

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

# Inputs
stormStatsPath <- args[1]
# Outputs
pathToWriteJSON <- args[2]
pathTOWriteRatings <- args[3]


stormStats <- read.csv(stormStatsPath,stringsAsFactors = FALSE)

# Specify type of regression
if(is.na(args[4])){
  regressionMethod <- "LINEAR"
}else{
  regressionMethod <- args[4]
  if(!(regressionMethod %in% c("POWER","LINEAR"))){
    print(paste0("No method exists for ",regressionMethod," regression. Performing linear regression instead. Check config file..."))
    regressionMethod <- "LINEAR"
  }
  
}

#Need plotBin R6 and mon_lm functions
source("https://raw.githubusercontent.com/HARPgroup/meta_model/master/scripts/precip/lm_analysis_plots.R")


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


#Rename the ratings before writing them out
ratingsOut <- monthEventOut$atts$stats
names(ratingsOut) <- c('mo', 'rating') 

#WRITE OUT DATA. GET STATS OR JSON OUTPUT
out <- monthEventOut$toJSON()
write(out,pathToWriteJSON)
write.csv(ratingsOut,pathToWriteRatings)