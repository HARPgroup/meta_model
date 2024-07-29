#!/bin/bash
#Where to get data from process 02-stormAnalysis
stormStatsPath=$STORM_EVENT_FLOW_FILE
#Where to get data from process 03-stormStatistics
stormPath=$STORM_EVENT_STATS_FILE
# Directory to store plots in. 
pathToWrite=$STORM_EVENT_PLOT_DIR
# The USGS gage number or hydro ID of the coverage that will be used to store
# this data with unique names
plotDetails=$USGS_GAGE

#While plotting, must clear existing plots. Can do so by deleting directory 
#using -r recursive and -f force, which ignores nonexistant files
rm -rf $pathToWrite
#Add directory:
mkdir $pathToWrite


cmd="Rscript $META_MODEL_ROOT/scripts/met/stormEventsLM_cmd.R $stormStatsPath $stormPath $pathToWrite $plotDetails"
echo "Running: $cmd"
eval $cmd