#For local testing:
# commandArgs <- function(...){
#   c("01613900")
# }

# Initialize ####
library(hydrotools)
basepath <- '/var/www/R'
source(paste(basepath,'config.R',sep='/'))

# get command line args
argst <- commandArgs(trailingOnly=T)

# Inputs ####
#Allow users to input one or multiple gages via a large comma separated sting
gages <- as.character(argst[1])


