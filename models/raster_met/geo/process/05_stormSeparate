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

echo "Finding storm events from gage flow"


#File path of the gage data of interest:
gageFilePath=$COVERAGE_FLOW_FILE
#Are we interested in baseline storms or all local minima? Recommended to set 
#to TRUE as of 06/27/2024 due to lack of development on FALSE side
allMinimaStorms=$SEARCH_ALL_STORM
#How should baselineFlow be calculated? Recommended by "Month"
baselineFlowOption=$BASELINE_FLOW_METHOD
#Where should files be written out to?
pathToWrite=$STORM_EVENT_FLOW_FILE


cmd="Rscript $META_MODEL_ROOT/scripts/met/stormSep_cmd.R $gageFilePath $allMinimaStorms $baselineFlowOption $pathToWrite"    
echo "Running: $cmd"
eval $cmd