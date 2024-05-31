# Insert info about this event into database
# attach a property showing the path to the original raster file
# attach a property with a web URL to the origina raster file
basepath='/var/www/R';
source("/var/www/R/config.R")

message("Use: Rscript met_store_info.R $ddate $datasource $extent_hydrocode $extent_ftype $img_varkey $met_file")
# load the feature -- get feature hydroid
# find the dh_timeseries_weather record for this event
# attach an image property to the record
# return 