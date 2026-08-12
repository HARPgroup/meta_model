# A script that finds the average watershed slope for a USGS gage
#For local testing:
# commandArgs <- function(...){
#   c("01634000", 'wshedslope.csv')
# }
args <- commandArgs(trailingOnly = T)
if (length(args) < 2){
  stop("Use Rscript watershed_slope.R gageID output_file")
}

# get arguments
gageID <- args[1]
output_file <- args[2]

message(paste0("DEBUG with: args <- c('",paste(args,collapse="', '")),"')")

# get basin slope
slope <- agws::get_basin_slope(gageID)

#Gage length and slope
write.csv(slope, output_file, row.names = FALSE)


