#!/bin/bash
# loads the args, the raster specific config and change to temp dir
geo_config=`find_config geo.config`
if [ "$geo_config" = "" ]; then
  geo_config="$META_MODEL_ROOT/models/raster_met/geo/geo.config"
fi
. $geo_config

if [[ "$STORMSEP_PLOT" ]]; then
  exit
fi
if [[ "$GEO_MET_MODEL" != "storm_volume" ]]; then
  exit
fi


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