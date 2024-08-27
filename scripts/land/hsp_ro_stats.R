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
#cbp_export_dir=Sys.getenv(c('CBP_EXPORT_DIR'))[1]
#image_directory_path <- paste0(cbp_export_dir,'/land/', scenario, '/images')
#image_directory_path <- '/media/model/p532/out/land/hsp2_2022/images' # needs to be commented when running on the server 
model_version <- argst[5]
lseg_ftype <- argst[6]
# todo: fix these
save_url <- omsite
landuse <- 'for' #allow to have a zoom in on a particular lu

# Get the data
pwater <- fread(pwater_file_path)
pwater$week <- week(pwater$thisdate)
pwater$month <- month(pwater$thisdate)
pwater$year <- year(pwater$thisdate)
pwater <- as.data.frame(pwater)

minyr <- min(pwater$year)
maxyr <- max(pwater$year)
# 1. Decomposition: 
# response = trend + seasonal + random
# $trend, $seasonal, and $random can be individually plotted from the stacked plot

# 2. Yearly Median - stats

# Exporting to VAHydro

# Set up our data source
ds <- RomDataSource$new(site, rest_uname = rest_uname)
ds$get_token(rest_pw)

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
  model$propname = landseg$name
  model$varid = ds$get_vardef('om_model_element')$varid
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
lu_dat_cols <- c('thisdate', names(pwater)[names(pwater) %like% lu_prefix])
lu_pwater <- pwater[,lu_dat_cols]
# now get SURO, IFWO and AGWO
suro_cols <- names(pwater)[names(pwater) %like% "suro"]
suro <- as.data.frame(rowSums(as.data.frame(pwater[,suro_cols])))[,1]
suro$year <- as.data.frame(pwater$year)
names(suro) <- 'suro'
# interflow IFWO
ifwo_cols <- names(pwater)[names(pwater) %like% "ifwo"]
ifwo <- as.data.frame(rowSums(as.data.frame(pwater[,ifwo_cols])))[,1]
names(ifwo) <- 'ifwo'
# now do AGWO
agwo_cols <- names(pwater)[names(pwater) %like% "agwo"]
agwo <- as.data.frame(rowSums(as.data.frame(pwater[,agwo_cols])))[,1]
names(agwo) <- 'agwo'

dat <- pwater[,c('year', 'thisdate', 'month')]
dat$Runit <- as.data.frame(rowSums(as.data.frame(pwater[,c(suro_cols,ifwo_cols,agwo_cols)])))[,1]

# Runoff boxplot
fname <- paste0(
  'Runit_boxplot_year',
  lseg_name, '.png'
)
fpath <-  paste(
  image_directory_path,
  fname,
  sep='/'
)
furl <- paste(
  save_url,
  fname,
  sep='/'
)
png(fpath)
boxplot(as.numeric(dat$Runit) ~ dat$year, ylim=c(0,3))
dev.off()
message(paste("Saved file: ", fname, "with URL", furl))
vahydro_post_metric_to_scenprop(model_scenario$pid, 'dh_image_file', furl, 'Runit_boxplot_year', 0.0, ds)
