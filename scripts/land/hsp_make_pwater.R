# Makes a pwater summary data frame from a collection of landuse specific suro, ifwo and agwo columns
library(data.table)
library(lubridate)
library(zoo)

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 3 ) {
  message(paste("Args submited:", argst))
  message("Use: hsp_make_pwater.R eos_file_path(input file) pwater_file_path(output file) landuse")
  q()
}
fpath <- argst[1]
pwater_file_path <- argst[2]
landuse <- argst[3]

fdat<-fread(fpath)
fdat <- as.data.frame(fdat)
# extract and combine columns
lu_prefix <- paste0(landuse,'_') # this insure we don't have redundant matches
lu_dat_cols <- c('thisdate', names(fdat)[names(fdat) %like% lu_prefix])
fdat <- fdat[,lu_dat_cols]
# now get SURO, IFWO and AGWO
suro_cols <- names(fdat)[names(fdat) %like% "suro"]
suro <- as.data.frame(rowSums(as.data.frame(fdat[,suro_cols])))[,1]
names(suro) <- 'suro'
# interflow IFWO
ifwo_cols <- names(fdat)[names(fdat) %like% "ifwo"]
ifwo <- as.data.frame(rowSums(as.data.frame(fdat[,ifwo_cols])))[,1]
names(ifwo) <- 'ifwo'
# now do AGWO
agwo_cols <- names(fdat)[names(fdat) %like% "agwo"]
agwo <- as.data.frame(rowSums(as.data.frame(fdat[,agwo_cols])))[,1]
names(agwo) <- 'agwo'

pwater <- as.data.frame(fdat$thisdate)
pwater$suro <- suro
pwater$ifwo <- ifwo
pwater$agwo <- agwo
names(pwater) <- c('timestamp', 'suro', 'ifwo', 'agwo')

pwater$date <- as.Date(pwater$timestamp)
pwater$year <- year(as.POSIXct(pwater$timestamp))
pwater$month <- month(as.POSIXct(pwater$timestamp))
pwater$day <- day(as.POSIXct(pwater$timestamp))
pwater$hour <- hour(as.POSIXct(pwater$timestamp))

fwrite(pwater,file=pwater_file_path,col.names=TRUE)
