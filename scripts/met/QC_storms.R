suppressPackageStartupMessages(library(lubridate))
# Arguments passed in from command line;
#1 = The file path to the combined precip and flow data at that USGS gage
#2 = The file path to the statistics output by the stormSep_USGS script for each
#storm found in the hydrographs
#3 = The file path to the storms output by stormSep_USGS script

args <- commandArgs(trailingOnly = TRUE)
print("Setting arguments...")

# Inputs
comp_dataFilePath <- args[1]
stormStatsPath <- args[2]
stormPath <- args[3]


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

stormSepDF <- read.csv(stormPath,stringsAsFactors = FALSE)

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


# write out outputs
write.csv(stormStats,stormStatsPath)
write.csv(stormEvents,stormPath)