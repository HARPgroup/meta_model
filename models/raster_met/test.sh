#!/bin/bash

raster_config=`find_config raster.config`
. $raster_config
echo ${config_nldas2["datasource"]}

echo "$testvar"
