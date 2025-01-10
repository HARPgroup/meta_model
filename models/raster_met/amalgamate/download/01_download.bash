#!/bin/bash
# loads the args, the raster specific config and change to temp dir
ama_config=`find_config amalgamate.config`
if [ "$ama_config" = "" ]; then
  ama_config="$META_MODEL_ROOT/models/raster_met/amalgamate/amalgamate.config"
fi
. $ama_config


