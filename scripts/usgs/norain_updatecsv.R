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
  message(paste("Use: deq_norain.R analysis_csv full_analysis_csv"))
  q()
}

# Inputs ####
analysis_df <- argst[1]
full_analysis_df <- argst[2]

