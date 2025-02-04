# This script will convert the pwater csv to a data table and perform 
# time series and trend analysis by generating graphs and summary statistics.
#install.packages("IHA", repos="http://R-Forge.R-project.org")
#install_github("HARPGroup/hydro-tools", force=TRUE)
basepath='/var/www/R';
source("/var/www/R/config.R") # will need file in same folder/directory

suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(zoo))
suppressPackageStartupMessages(library(PearsonDS))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(R.utils))


#message(R_TempDir)
# establishing location on server for storing images
omsite = "http://deq1.bse.vt.edu:81"

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
land_segment_name <- argst[1]
scenario_name <- argst[2]
pwater_file_path <- argst[3] #test: pwater_file_path <- "http://deq1.bse.vt.edu:81/p6/out/land/subsheds/eos/N51113_0111-0211-0411.csv"
image_directory_path <- argst[4] 
cbp_export_dir=Sys.getenv(c('CBP_EXPORT_DIR'))[1]
image_url_path <- stringr::str_replace(image_directory_path, '/media/model', '')
model_version <- argst[5]
lseg_ftype <- argst[6]
message(
  paste0(
    "Running analysis. To test use: argst=c(",
    "'",land_segment_name,
    "', '", scenario_name,
    "', '", pwater_file_path,
    "', '", image_directory_path,
    "')"
  )
)
# todo: fix these
save_url <- omsite
landuse <- 'for' #allow to have a zoom in on a particular lu

# Get the data
pwater <- fread(pwater_file_path)
pwater <- as.data.frame(pwater)
pwater$year <- year(pwater$thisdate)
pwater$month <- month(pwater$thisdate)
pwater$week <- week(pwater$thisdate)
pwater$day <- day(pwater$thisdate)
pwater$date_only <- as.Date(paste(pwater$year, pwater$month, pwater$day,sep="-"))
# now make a daily of all non-date columns
pwater_nodate <- pwater[,!names(pwater) %in% c('thisdate','year','month','day','week','date_only')]
pwater_daily <- aggregate(pwater_nodate, list(pwater$date_only), 'sum')
pwater_daily$thisdate <- unique(pwater$date_only)
pwater_daily$year <- year(pwater_daily$thisdate)
pwater_daily$month <- month(pwater_daily$thisdate)
pwater_daily$week <- week(pwater_daily$thisdate)
pwater_daily$day <- day(pwater_daily$thisdate)


minyr <- min(pwater_daily$year)
maxyr <- max(pwater_daily$year)
# 1. Decomposition: 
# response = trend + seasonal + random
# $trend, $seasonal, and $random can be individually plotted from the stacked plot

# 2. Yearly Median - stats

# Exporting to VAHydro

# TBD: get inputs from the comand line
#  For now we just load some samples
lseg_name=land_segment_name

landseg<- RomFeature$new(
  ds,
  list(
    hydrocode=lseg_name, 
    ftype=lseg_ftype,
    bundle='landunit'
  ), 
  TRUE
)

model <- RomProperty$new(
  ds,
  list(
    featureid=landseg$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
message(paste("Saving landseg model", model$propcode, model$entity_type, model$featureid, model$propcode))
if (is.na(model$pid)) {
  model$propname = paste(landseg$name,model_version)
  model$varid = ds$get_vardef('om_model_element')$hydroid
#  message(paste("Saving landseg model", model$propname, model$varid, model$featureid, $model$propcode))
  model$save(TRUE)
}


model_scenario <- RomProperty$new( #Re-ordered scenario to be within the model element and the land use within the scenario
  ds,
  list(
    varkey="om_scenario", 
    featureid=model$pid, 
    entity_type="dh_properties", 
    propname=scenario_name, 
    propcode=scenario_name 
  ), 
  TRUE
)
model_scenario$save(TRUE)

lu <- RomProperty$new(
  ds,
  list(
    varkey="om_hspf_landuse", 
    propname='landuses',
    featureid=model_scenario$pid, 
    entity_type="dh_properties"
  ), 
  TRUE
)
lu$save(TRUE)

# Create/Load a model scenario property
# tstime = the run time 
# note: do not set tstime when retrieving since if we have a previous
#       timesereies event already set, we want to gt it and may not know the tstime
# 


# Uploading constants to VaHydro:
# entity-type specifies what we are attaching the constant to 
#Implementing containers for VAHydro

model_out_file <- RomProperty$new(
  ds, list(
    varkey="external_file",
    featureid=model_scenario$pid,
    entity_type='dh_properties',
    propcode = pwater_file_path,
    propname = 'outfile'
  ),
  TRUE
)
model_out_file$save(TRUE)

# do basic plotting
# extract and combine columns
lu_prefix <- paste0(landuse,'_') # this insure we don't have redundant matches
lu_dat_cols <- c('thisdate', names(pwater_daily)[names(pwater_daily) %like% lu_prefix])
lu_pwater <- pwater_daily[,lu_dat_cols]
# now get SURO, IFWO and AGWO
suro_cols <- names(pwater_daily)[names(pwater_daily) %like% "suro"]
suro <- as.data.frame(rowSums(as.data.frame(pwater_daily[,suro_cols])))[,1]
names(suro) <- 'suro'
# interflow IFWO
ifwo_cols <- names(pwater_daily)[names(pwater_daily) %like% "ifwo"]
ifwo <- as.data.frame(rowSums(as.data.frame(pwater_daily[,ifwo_cols])))[,1]
names(ifwo) <- 'ifwo'
# now do AGWO
agwo_cols <- names(pwater_daily)[names(pwater_daily) %like% "agwo"]
agwo <- as.data.frame(rowSums(as.data.frame(pwater_daily[,agwo_cols])))[,1]
names(agwo) <- 'agwo'

dat <- pwater_daily[,c('year', 'thisdate', 'month')]
dat$Runit <- as.data.frame(rowSums(as.data.frame(pwater_daily[,c(suro_cols,ifwo_cols,agwo_cols)])))[,1]

# Runoff boxplot
fname <- paste0(
  'Runit_boxplot_year_',
  lseg_name, '.png'
)
fpath <-  paste(
  image_directory_path,
  fname,
  sep='/'
)
furl <- paste(
  save_url, image_url_path,
  fname,
  sep='/'
)
png(fpath)
boxplot(
  as.numeric(dat$Runit) ~ dat$year, 
  ylim=c(0,3),
  main=paste("Runit",model$propname,"Run:",model_scenario$propname)
)
dev.off()
message(paste("Saved file: ", fname, "with URL", furl))
vahydro_post_metric_to_scenprop(model_scenario$pid, 'dh_image_file', furl, 'Runit_boxplot_year', 0.0, ds)

Runits <- zoo(as.numeric(as.character( dat$Runit )), order.by = as.POSIXct(dat$thisdate));
loflows <- group2(Runits, "calendar")
l90 <- loflows["90 Day Min"]
ndx = which.min(as.numeric(l90[,"90 Day Min"]))
l90_RUnit = round(loflows[ndx,]$"90 Day Min",6)
l90_year = loflows[ndx,]$"year"

if (is.na(l90_RUnit)) {
  l90_Runit = 0.0
  l90_year = 0
}
l90prop <- vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l90_RUnit', l90_RUnit, ds)
l90yr_prop <- vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l90_year', l90_year, ds)

Runit <- mean(as.numeric(dat$Runit) )
if (is.na(Runit)) {
  Runit = 0.0
}
Runitprop <- vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'Runit', Runit, ds)
