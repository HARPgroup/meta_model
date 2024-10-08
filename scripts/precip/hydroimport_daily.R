# Inputs (args):
# 1 = File path of csv from VA Hydro
# 2 = Data source "nldas2, daymet, prism"
# 3 = End path of new csv
# Outputs:
# Csv file with manipulated data at end filepath

# Library necessary packages
print("Accessing necessary libraries")
suppressPackageStartupMessages(library("dataRetrieval"))
suppressPackageStartupMessages(library("sqldf"))
suppressPackageStartupMessages(library("zoo"))
suppressPackageStartupMessages(library("lubridate"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2){
  message("Missing or extra inputs. Usage: Rscript hydroimport_daily.R data_csv_location write_location")
  q()
}
# Set up command args
print("Reading command args")
#this accepts links and file locations on device
data_csv_location <-args[1]
write_location <- args[2]

# Pull csv from input file path
print("Reading csv")
hydro_daily <- read.csv(data_csv_location)
# Add in more date information
print("Adding date information")
hydro_daily[,c('yr', 'mo', 'da', 'wk')] <- cbind(year(as.Date(hydro_daily$obs_date)),
                                                 month(as.Date(hydro_daily$obs_date)),
                                                 day(as.Date(hydro_daily$obs_date)),
                                                 week(as.Date(hydro_daily$obs_date)))

# If data comes from nladas2 (hourly), it must be converted into daily data
print("Summing to daily data")
  hydro_daily <- sqldf(
    "select featureid, min(obs_date) as obs_date, yr, mo, da, wk, 
     sum(precip_in) as precip_in
   from hydro_daily 
   group by yr, mo, da, wk
   order by yr, mo, da, wk
  "
  )

# Write csv in new file path
print(paste0("Write csv in new file path: ",write_location))
write.csv(hydro_daily,write_location)
