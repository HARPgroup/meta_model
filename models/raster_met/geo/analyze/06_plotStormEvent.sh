#!/bin/bash

#Where are combined flow precip data file stored?
comp_dataFilePath=$1
#Where to get data from process 02-stormAnalysis
stormStatsPath=$2
#Where to get data from process 03-stormStatistics
stormPath=$3
# Directory to store plots in. 
pathToWrite=$4
# The USGS gage number or hydro ID of the coverage that will be used to store
# this data with unique names
plotDetails=$5


#While plotting, must clear existing plots. Can do so by deleting directory 
#using -r recursive and -f force, which ignores nonexistant files
rm -rf $pathToWrite
#Add directory:
mkdir $pathToWrite


cmd="Rscript $META_MODEL_ROOT/scripts/met/stormEventsLM_cmd.R $comp_dataFilePath $stormStatsPath $stormPath $pathToWrite $plotDetails"
echo "Running: $cmd"
eval $cmd