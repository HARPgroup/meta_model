# Inputs (args):
# 1 = Gage id you want to use
# 2 = End path of new csv
suppressPackageStartupMessages(library(dataRetrieval))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(sqldf))
suppressPackageStartupMessages(library(dplyr))
argst <- commandArgs(trailingOnly = TRUE)
if (length(argst) < 2) {
  message("Usage: Rscript usgs_to_om_flows.R sta_id outfile mstart mend area_reach drop_cache")
  q()
}

basepath='/var/www/R'
source('/var/www/R/config.R')
sta_id <- as.character(argst[1])
outfile <- argst[2]
if (length(argst) > 2) {
  mstart <- as.character(argst[2])
} else {
  mstart = FALSE
}
if (length(argst) > 3) {
  mend <- as.character(argst[3])
} else {
  mend = FALSE
}
area_reach = 0 # we will not scale if not requested
if (length(argst) > 4) {
  area_reach <- as.numeric(argst[5]) 
}
drop_cache = 0
if (length(argst) > 5) {
  drop_cache = as.integer(argst[6])
}
#historic <- dataRetrieval::readNWISdv(sta_id,'00060')
if (drop_cache == 1) {
  drop_cache(memo_readNWISsite)(sta_id)
  drop_cache(memo_readNWISdv)(sta_id,'00060')
}
historic <- memo_readNWISdv(sta_id,'00060')
gage_info <- memo_readNWISsite(sta_id)
gage_name <- gage_info$station_nm
area_factor = 1.0
if (area_reach > 0) {
  area_factor <- as.numeric(area_reach) / gage_info$drain_area_va
}

dat_formatted <- zoo(historic, order.by = historic$Date)
dat_formatted <- window(dat_formatted, start = mstart, end = mend)
historic <- as.data.frame(dat_formatted)
# add dates
historic[,c('yr', 'mo', 'da')] <- cbind(year(as.Date(historic$Date)),
                                         month(as.Date(historic$Date)),
                                         day(as.Date(historic$Date)))
# zoo clobbers the number type this restores it
historic$X_00060_00003 <- as.numeric(historic$X_00060_00003)
historic$Qout <- historic$X_00060_00003 * area_factor
historic$area_sqmi <- gage_info$drain_area_va
historic$thisdate <- historic$Date
historic$ps_mgd <- 0.0
historic$ps_cumulative_mgd <- 0.0
historic$wd_cumulative_mgd <- 0.0
historic$Runit <- historic$Qout / gage_info$drain_area_va
# this needs to create an epoch...
# historic$timestamp <- as.POSIXct(historic$Date)
if ( is.logical(mstart) ) {
  mstart <- min(historic$thisdate)
}
if ( is.logical(mend) ) {
  mend <- max(historic$thisdate)
}
write.csv(historic, outfile, row.names=FALSE)
