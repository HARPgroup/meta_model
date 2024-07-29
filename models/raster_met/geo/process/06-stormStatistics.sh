#!/bin/bash
# loads the args, the raster specific config and change to temp dir
geo_config=`find_config geo.config`
if [ "$geo_config" = "" ]; then
  geo_config="$META_MODEL_ROOT/models/raster_met/geo/geo.config"
fi
. $geo_config

if [[ "$GEO_MET_MODEL" != "storm_volume" ]]; then
  exit
fi

echo "Setting statistics for each storm event found"

#First argument should be The path to the storm separated data from step 02 for this gage
stormSepPath=$STORM_EVENT_FLOW_FILE
#Where should files be written out to?
pathToWrite=$STORM_EVENT_STATS_FILE


cmd="Rscript $META_MODEL_ROOT/scripts/met/stormAnalysis_cmd.R $stormSepPath $pathToWrite"
echo "Running: $cmd"
eval $cmd


#NEXT STEPS ARE TO MAKE A STEP FOR THE ACTUAL ANALYSIS AND FOR OPTIONAL PRECIP PLOTS