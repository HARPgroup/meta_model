#A script to calculate AGWRC and delta AGWRC from gage data (using todays and
#yesterday's flow). From there, identifies days in flow recession that may later
#quality as baseflow events
#For local testing:
# commandArgs <- function(...){
#   c("strasGage.csv", "Date", "Flow", FALSE, "strasEvent.csv")
# }
agst <- commandArgs(trailingOnly = T)
if (length(agst) < 5){
  message("Use Rscript event_identification.R input_file date_column flow_column manual(TRUE/FALSE) output_file")
  q()
}

suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(agws))
suppressPackageStartupMessages(library(dplyr))

# get arguments
input_file <- as.character(agst[1])
input_file <- str_replace_all(input_file, '\"', '') # quotes coming in give troubles
date_col <- as.character(agst[2])
flow_col <- as.character(agst[3])
manual_opt <- as.logical(agst[4])
end_path <- as.character(agst[5])
#If user wants to input the maximum number of days for gap filling, set it.
#Otherwise, default to just three days.
if(length(agst) > 5){
  gap_days <- as.character(agst[6])
}else{
  gap_days <- 3
}


message(paste0("DEBUG with: agst <- c('",paste(agst,collapse = "', '")),"')")

message(paste("Reading", input_file))

#Read in flow csv and ensure standard names
flow_csv <- read.csv(input_file)
flow_csv$Date <- as.Date(flow_csv[[date_col]])
flow_csv$Flow <- flow_csv[[flow_col]]

#calculate AGWR and delta_AGWR
flow_csv$AGWR <- agws::calc_AGWR(flow_csv[[flow_col]])
flow_csv$delta_AGWR <- agws::calc_delta_AGWR(flow_csv$AGWR)
#Add the season in
flow_csv <- agws::add_month_season(flow_csv)


if(manual_opt == TRUE){
  flow_csv$GroupID <- 1
  flow_csv$RecessionDay <- TRUE
}else{
  #Identify when flow is in recession
  flow_csv <- agws::flag_stable_baseflow(flow_csv, flow_csv[[flow_col]], max_gap = gap_days)
}

#remove NAs
flow_csv <- flow_csv[!is.na(flow_csv$RecessionDay), ]
flow_csv$Year <- year(flow_csv$Date)
flow_csv$Day <- day(flow_csv$Date)

# Write final csvs out
write.csv(flow_csv, end_path,row.names = FALSE)


