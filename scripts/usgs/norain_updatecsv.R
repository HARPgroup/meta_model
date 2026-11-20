# Description ####
#POSTs results of norain_analysis.R
# Initialize ####
library(hydrotools)
basepath <- '/var/www/R'
source(paste(basepath,'config.R',sep='/'))

# get command line args
argst <- commandArgs(trailingOnly=T)

# Ex:
# argst = c("analysis.csv")
if (length(argst) < 2) {
  stop(paste("Use: deq_norain.R analysis_csv full_analysis_csv"))
}

# Inputs ####
analysis_df <- read.csv( argst[1] )
output_file <- argst[2]
full_analysis_df <- read.csv( argst[2] )

if (length(argst) > 2) {
  pkcol <- argst[4]
}else{
  pkcol <- "hydroid"
}

full_analysis_df[,pkcol == analysis_df[, pkcol]] <- analysis_df[, pkcol]

write.csv(full_analysis_df, output_file, row.names = FALSE)
