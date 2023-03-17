# creating a csv with wanted col and wdm format

suppressPackageStartupMessages(library(data.table)) 
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(R.utils))

omsite = "http://deq1.bse.vt.edu:81"

#setwd("/Users/VT_SA/Documents/HARP") #for testing
#hydr <- fread("OR1_7700_7980_hydr.csv") #for testing

argst <- commandArgs(trailingOnly = T)
input_path <- argst[1]
output_path <- argst[2]
column <- argst[3]
if (length(argst) >= 4) {
  temp_res <- argst[4]
} else {
  temp_res = 'day'
}
message(paste("Temp res", temp_res, "count of args is", length(argst)) )
  
hydr <- fread(input_path)
hydr %>% select(column) -> hydr_column


# creating tables with OVOL3 and ROVOL
hydr_df = FALSE
if (temp_res == 'day') {
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr_column)
} 
if (temp_res == 'hour') {
  message("Using hourly export")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr_column)
} 
if (temp_res == 'minute') {
  message("Using minute export")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr$minute, hydr_column)
} 
if (temp_res == 'second') {
  message("Using second export (required by default wdmtoolbox imports)")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr$minute, hydr$second, hydr_column)
} 
if (temp_res == 'string') {
  message("Using date string export (required by default wdmtoolbox imports)")
  # Using index is a bad thing IMO (but I did it).  I think perhaps we should consider
  # using a string formatting of the year, month, day, hour, minute, second columns 
  #A insteawd of relying on the index to not be clobbered at a previous step 
  hydr_df <- data.frame(format(hydr$index, "%Y-%m-%d %H:%M:%S", usetz=TRUE ), hydr_column)
} 
if (is.logical(hydr_df)) {
  message(paste("Resolution", temp_res,"is not available"))
  q("n")
}
#Robustify by adding usage for hourly and daily data 

# exporting the tables
write.table(hydr_df, file = output_path, sep = ',', row.names = FALSE, col.names = FALSE, quote = FALSE)

message(paste("Finished exporting",column,"to", output_path))
