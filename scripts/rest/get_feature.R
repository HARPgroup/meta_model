# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")
suppressPackageStartupMessages(library(hydrotools)) 
suppressPackageStartupMessages(library(jsonlite)) #for exporting values as json

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
fcode <- argst[1]
bundle <- argst[2]
ftype <- argst[3]

message(paste("Searching for feature hydrocode=", fcode,"with ftype",ftype))
feature<- RomFeature$new(
  ds,
  list(
    hydrocode=fcode,
    ftype=ftype,
    bundle=bundle
  ),
  TRUE
)
if (!is.na(feature$hydroid)) {
  cat(feature$hydroid)
} else {
  message(paste("Error: Could not locate feature with hydrocode="fcode,"and ftype=",ftype))
}
