# creating a csv with wanted col and wdm format
options(scipen=999) # disable scientific notation in dataframes

suppressPackageStartupMessages(library(data.table)) 
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(R.utils))
suppressPackageStartupMessages(library(sqldf))

omsite = "http://deq1.bse.vt.edu:81"

#setwd("/Users/VT_SA/Documents/HARP") #for testing
#hydr <- fread("OR1_7700_7980_hydr.csv") #for testing

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 3) {
  message("Usage: Rscript csv_export_wdm_format.R input_path output_path column [time_fields=day(hr,min,string)] [temp_conv=none,day,hour] [conv_method=avg,sum]")
  q()
}
input_path <- argst[1]
output_path <- argst[2]
column <- argst[3]
if (length(argst) >= 4) {
  time_fields <- argst[4]
} else {
  time_fields = 'day'
}
if (length(argst) >= 5) {
  temp_conv <- argst[5]
} else {
  temp_conv = 'none'
}
if (length(argst) >= 6) {
  conv_method <- argst[6]
} else {
  conv_method = 'sum'
}
if (length(argst) >= 7) {
  src_tz <- argst[7]
} else {
  src_tz = FALSE
}
if (length(argst) >= 8) {
  dest_tz <- argst[8]
} else {
  dest_tz = src_tz
}

message(paste("Time field style", time_fields, "count of args is", length(argst)) )
  
hydr <- fread(input_path)
# must rename first several columns in case they are not time formatted, or not named at all
bnames <- colnames(hydr)
bnames[1:4] <- c('year','month','day','hour')
colnames(hydr) <- bnames

if (temp_conv == 'hour') {
   cstring = "select year, month, day, hour, 0 as minute, 0 as second"
   gstring = "group by year, month, day, hour"
}
if (temp_conv == 'day') {
   cstring = "select year, month, day, 0 as hour, 0 as minute, 0 as second"
   gstring = "group by year, month, day"
}
if (temp_conv != 'none') {
   print(paste(cstring, ", ", conv_method, "(", column,") as ", column," from hydr", gstring))
   hydr <- sqldf(paste(cstring, ", ", conv_method, "(", column,") as ", column," from hydr", gstring))
   if (src_tz == FALSE) {
     hydr$index <- as.POSIXct(make_datetime(hydr$year,hydr$month,hydr$day,hydr$hour,hydr$minute,hydr$second))
   } else {
     hydr$index <- as.POSIXct(make_datetime(hydr$year,hydr$month,hydr$day,hydr$hour,hydr$minute,hydr$second, tz = src_tz))
   }
}

# creating tables with OVOL3 and ROVOL
hydr_df = FALSE
if (time_fields == 'day') {
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr[[column]])
} 
if (time_fields == 'hour') {
  message("Using hourly export")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr[[column]])
} 
if (time_fields == 'minute') {
  message("Using minute export")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr$minute, hydr[[column]])
} 
if (time_fields == 'second') {
  message("Using second export (required by default wdmtoolbox imports)")
  hydr_df <- data.frame(hydr$year, hydr$month, hydr$day, hydr$hour, hydr$minute, hydr$second, hydr[[column]])
} 
if (time_fields == 'string') {
  message("Using date string export (required by default wdmtoolbox imports)")
  # Using index is a bad thing IMO (but I did it).  I think perhaps we should consider
  # using a string formatting of the year, month, day, hour, minute, second columns 
  #A insteawd of relying on the index to not be clobbered at a previous step 
  if (dest_tz == FALSE) {
    hydr_df <- data.frame(format(hydr$index, "%Y-%m-%d %H:%M:%S", usetz=TRUE ), hydr[[column]])
  } else {
    hydr_df <- data.frame(format(hydr$index, "%Y-%m-%d %H:%M:%S", usetz=TRUE, tz=dest_tz ), hydr[[column]])
  }
} 
if (is.logical(hydr_df)) {
  message(paste("Resolution", time_fields,"is not available"))
  q("n")
}
#Robustify by adding usage for hourly and daily data 

# exporting the tables
write.table(hydr_df, file = output_path, sep = ',', row.names = FALSE, col.names = FALSE, quote = FALSE)

message(paste("Finished exporting",column,"to", output_path))
