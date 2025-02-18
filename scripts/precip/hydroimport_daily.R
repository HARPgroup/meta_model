# Inputs (args):
# 1 = File path of csv from VA Hydro
# 2 = End path of new csv
# 3 = Data source "nldas2, daymet, prism"
# Outputs:
# Csv file with manipulated data at end filepath

# Library necessary packages
print("Accessing necessary libraries")
suppressPackageStartupMessages(library("sqldf"))
suppressPackageStartupMessages(library("lubridate"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3){
  message("Missing or extra inputs. Usage: Rscript hydroimport_daily.R data_csv_location write_location MET_DATA_SOURCE")
  q()
}
# Set up command args
print("Reading command args")
#this accepts links and file locations on device
data_csv_location <- args[1]
write_location <- args[2]
met_data_source <- args[3]

# Pull csv from input file path
print("Reading csv")
hydro_daily <- read.csv(data_csv_location)


if(met_data_source == "nldas2"){
  #If data comes from nladas2 (hourly), it must be converted into daily data
  #that matches the days established in the PRISM and daymet datasets i.e. from
  #7AM - 7AM EST (noon to noon UTC). First, create a column that shows the hours
  #in the "PRISM" day from 7AM to 7AM EST as 0:23. We can do this by adjusting
  #the current hours which are in EST
  hydro_daily$PRISMDayhr <- hydro_daily$hr + 17 - (24 * (floor(hydro_daily$hr / 7) > 0))
  #Now, get the orginal EST dates and adjust all those that are misclassified.
  #For PRISM, 05/30/2023 is the day that is 7AM 05/29 to 7AM 05/30 EST. So,
  #compared to the orginal dates, the PRISM days need to be adjusted before hour
  #17 to match the 7AM to 7AM
  hydro_daily$PRISMDate <- as.Date(hydro_daily$obs_date)
  hydro_daily$PRISMDate[hydro_daily$PRISMDayhr <= 16] <- hydro_daily$PRISMDate[hydro_daily$PRISMDayhr <= 16] + 1
  
  
  # Add in more date information
  print("Adding date information")
  hydro_daily[,c('yr', 'mo', 'da', 'wk')] <- cbind(year(as.Date(hydro_daily$PRISMDate)),
                                                   month(as.Date(hydro_daily$PRISMDate)),
                                                   day(as.Date(hydro_daily$PRISMDate)),
                                                   week(as.Date(hydro_daily$PRISMDate)))
  
  
  print("Summing to daily data based on PRISM day (7AM to 7AM EST")
  #Convert the date field to character for sqldf since sqldf expects either a
  #character or a posixct string
  hydro_daily$PRISMDate <- as.character(hydro_daily$PRISMDate)
  hydro_daily <- sqldf(
    "select featureid, PRISMDate as obs_date, yr, mo, da, wk, 
     sum(precip_in) as precip_in
   from hydro_daily 
   group by yr, mo, da, wk, PRISMDate
   order by yr, mo, da, wk, PRISMDate
  "
  )
  
}else if(met_data_source %in% c("PRISM","daymet")){
  # Add in more date information
  print("Adding date information")
  hydro_daily[,c('yr', 'mo', 'da', 'wk')] <- cbind(year(as.Date(hydro_daily$obs_date)),
                                                   month(as.Date(hydro_daily$obs_date)),
                                                   day(as.Date(hydro_daily$obs_date)),
                                                   week(as.Date(hydro_daily$obs_date)))
  # If data comes from nladas2 (hourly), it must be converted into daily data
  print("Summing to daily data based on PRISM day (7AM to 7AM EST")
  hydro_daily <- sqldf(
    "select featureid, min(obs_date) as obs_date, yr, mo, da, wk, 
     sum(precip_in) as precip_in
   from hydro_daily 
   group by yr, mo, da, wk
   order by yr, mo, da, wk")
}

# Write csv in new file path
print(paste0("Write csv in new file path: ",write_location))
write.csv(hydro_daily,write_location,row.names = FALSE)
