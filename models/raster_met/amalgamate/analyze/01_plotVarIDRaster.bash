#!/bin/bash
# loads the args, the raster specific config and change to temp dir
amalgamate_config=`find_config amalgamate.config`
if [ "$amalgamate_config" = "" ]; then
  amalgamate_config="$META_MODEL_ROOT/models/raster_met/amalgamate/amalgamate.config"
fi
. $amalgamate_config

echo "Plotting target raster:"
#Use amalgamate.sh to amalgamate the raster, one dataset at a time
cmd="${MET_SCRIPT_PATH}/sh/plotRaster.sh $TS_START_IN $TS_END_IN $AMALGAMATE_SCENARIO $RATINGS_VARKEY $EXTENT_HYDROCODE $EXTENT_BUNDLE $EXTENT_FTYPE $AMALGAMATE_SQL_FILE $db_host $db_name"
echo "Running ${cmd}"
eval $cmd