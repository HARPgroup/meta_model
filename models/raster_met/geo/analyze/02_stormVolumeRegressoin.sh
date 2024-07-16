#!/bin/bash
#First argument should be the combined file that contains the daily gage data 
#and precipitation data
USGSgage=$1

#Where are combined flow precip data file stored?
comp_dataFilePath=$1
#Where to get data from process 02-stormAnalysis
stormStatsPath=$2
#Where to get data from process 03-stormStatistics
stormPath=$3
#Should anydays prior to the storm start be included in precip volumes?
rollingDur=$4

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormEventsLM_cmd.R $comp_dataFilePath $MET_SCRIPT_PATH $stormStatsPath $stormPath $rollingDur"
echo "Running: $cmd"
eval $cmd