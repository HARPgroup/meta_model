#!/bin/bash

#scenario, Location, directory

#First argument should be USGS gage of interest
USGSgage=$1
#Second argument is path to USGS gage csvs downloaded in geo -> download
gageDataPath=$2

#Lets output these via a config file so that we don't need to set these 
#individually which owould mess witht he meta model!

#Are we interested in baseline storms or all local minima? Recommended to set 
#to TRUE as of 06/27/2024 due to lack of development on FALSE side
allMinimaStorms=$3
#How should baselineFlow be calculated? Recommended by "Month"
baselineFlowOption=$4
#Where should files be written out to?
pathToWrite=$5

#File path of the gage data of interest:
gageFilePath="${gageDataPath}/${USGSgage}_data.csv"

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormSep_cmd.R $gageFilePath $allMinimaStorms $baselineFlowOption $pathToWrite"    
echo "Running: $cmd"
eval $cmd