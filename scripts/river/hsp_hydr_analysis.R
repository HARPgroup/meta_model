# This script will take in our hydr csv as an argument and perform analysis on 
# variables Qout, ps, wd, and demand and pushes to VAhydro.
# The values calculated are based on waterSupplyModelNode.R
basepath='/var/www/R';
source("/var/www/R/config.R")

suppressPackageStartupMessages(library(data.table)) 
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(zoo))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(caTools))
suppressPackageStartupMessages(library(RColorBrewer))
suppressPackageStartupMessages(library(IHA))
suppressPackageStartupMessages(library(PearsonDS))
suppressPackageStartupMessages(library(R.utils))
suppressPackageStartupMessages(library(hydroTSM))
suppressPackageStartupMessages(library(stats)) #for window()
suppressPackageStartupMessages(library(jsonlite)) #for exporting values as json

# establishing location on server for storing images
omsite = "http://deq1.bse.vt.edu:81"

# setwd("/Users/glenncampagna/Desktop/HARPteam22/Data") # for testing only 
# setwd("/Users/VT_SA/Documents/HARP") # for testing only
# hydr <- fread("OR1_7700_7980_hydrd.csv") # no wd or ps 
# hydr <- fread("JL1_6770_6850_hydrd.csv") # has wd but no ps 
# river_seg <- 'OR1_7700_7980'
# scenario_name <- 'hsp2_2022'
# hydr_file_path <- '/media/model/p532/out/river/hsp2_2022/hydr/OR1_7700_7980_hydr.csv'
# argst <- c("PM7_4581_4580","pubsheds", "http://deq1.bse.vt.edu:81/p6/out/river/pubsheds/hydr/PM7_4820_0001_hydrd_wy.csv","cbp-6.1","vahydro")
# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
river_seg <- argst[1]
scenario_name <- argst[2]
hydr_file_path <- argst[3]
model_version <- argst[4]
rseg_ftype <- argst[5]
json_dir <- argst[6] #including / @ end of path

# The hydr file columns have been modifed with a conversion script, 
# and ps and demand were added from the 'timeseries' in the h5
hydr <- fread(hydr_file_path)
# count before zoo'ing
cec <- sqldf(paste("select count(*) from hydr where year=",max(hydr$year)))

#Creating vectors for index and date to be passed in later before writing
# index <- hydr$index
# date <- hydr$date
hydr$timestamp <- as.POSIXct(hydr$index,origin="1970-01-01")
hydr <- zoo(hydr, order.by = hydr$index)
#trimming to water year and adding the buffer
syear = as.integer(min(hydr$year))
eyear = as.integer(max(hydr$year))
# make sure we didn't overlap into a single day January 1st as this will break IHA calendar analysis
if (cec < 365) {
  eyear = eyear - 1
}
model_run_start <- min(hydr$date)
model_run_end <- max(hydr$date)
years <- seq(syear,eyear)

if (syear < (eyear - 2)) {
  sdate <- as.POSIXct(paste0(syear,"-10-01"), tz = "UTC")
  edate <- as.POSIXct(paste0((eyear),"-09-30"), tz = "UTC")
  flow_year_type <- 'water'
} else {
  sdate <- as.POSIXct(paste0(syear,"-02-01"), tz = "UTC")
  edate <- as.POSIXct(paste0(eyear,"-12-31"), tz = "UTC")
  flow_year_type <- 'calendar'
}

#Reverted back to using window(), which requires a ts or zoo:
hydr <- window(hydr, start = sdate, end = edate)

cols <- names(hydr)

#Convert hydr to numeric
mode(hydr) <- 'numeric'

#Add the removed columns back to the hydr zoo (removed by setting zoo to numeric)
# hydr$index <- index
# hydr$date <- date

# This removes the hydr file from the end of the hydr_file_path, so that later
# we can use input_file_path in order to post it on VAhydro
file_path_text = paste(hydr_file_path)
split <- strsplit(file_path_text, split = "/")
input_file_path <- gsub(split[[1]][[9]],'',file_path_text)

### Exporting to VAHydro

# Set up our data source
if (rseg_ftype == 'vahydro') {
  # we have a hinky prefix, so add it
  rseg_code=paste0('vahydrosw_wshed_',river_seg)
} else {
  rseg_code=river_seg
}

message(paste("Searching for feature hydrocode=", rseg_code,"with ftype",rseg_ftype))
riverseg<- RomFeature$new(
  ds,
  list(
    hydrocode=rseg_code,
    ftype=rseg_ftype,
    bundle='watershed'
  ),
  TRUE
)
message(paste("Searching for model", model_version,"on feature",riverseg$hydroid))
model <- RomProperty$new(
  ds,
  list(
    featureid=riverseg$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
if (is.na(model$pid)) {
  model$propname = paste(riverseg$name, model_version)
  model$varid = ds$get_vardef('om_water_model_node')$varid
  model$save(TRUE)
}
# set the river seg property if it is not there or empty
message(paste("Checking if model has riverseg set = ", river_seg))
rseg <- RomProperty$new(
  ds,
  list(
    featureid=model$pid, 
    entity_type="dh_properties", 
    propname='riverseg'
  ), 
  TRUE
)
overwrite_riverseg = FALSE
if (is.na(rseg$propcode) || is.null(rseg$propcode) || (rseg$propcode == '')) {
#  message(paste("*** riverseg appears empty, setting to ", river_seg))
  rseg$propcode = river_seg
  overwrite_riverseg = TRUE
}
if (is.na(rseg$pid) || (overwrite_riverseg == TRUE)) {
  message(paste("*** setting riverseg = ", rseg$propcode))
  rseg$varid = ds$get_vardef('om_class_textField')$varid
  rseg$save(TRUE)
}


model_scenario <- RomProperty$new(
  ds,
  list(
    featureid=model$pid, 
    entity_type="dh_properties", 
    propcode=scenario_name
  ), 
  TRUE
)
if (is.na(model_scenario$pid)) {
  model_scenario$propname = paste(scenario_name)
  model_scenario$varid = ds$get_vardef('om_scenario')$varid
  model_scenario$save(TRUE)
}


# Uploading constants to VaHydro:
# entity-type specifies what we are attaching the constant to 

model_constant_hydr_path <- RomProperty$new(
  ds, list(
    varkey="om_class_textField", 
    featureid=model_scenario$pid,
    entity_type='dh_properties',
    propname = 'hydr_file_path'
  ),
  TRUE
)

hydr_path_hourly <- gsub('d_wy','',hydr_file_path)

model_constant_hydr_path$propcode <- as.character(hydr_path_hourly)
model_constant_hydr_path$save(TRUE)


model_constant_hydrd_path <- RomProperty$new(
  ds, list(
    varkey="om_class_textField", 
    featureid=model_scenario$pid,
    entity_type='dh_properties',
    propname = 'hydrd_wy_file_path'
  ),
  TRUE
)
model_constant_hydrd_path$propcode <- as.character(hydr_file_path)
model_constant_hydrd_path$save(TRUE)




#Assumption
imp_off = 1
hydr$imp_off = 1 # set to 1 meaning there will be no impoundment 


## Primary Analysis on Qout, ps and wd:
wd_mgd <- mean(as.numeric(hydr$wd_mgd))

wd_imp_child_mgd <- mean(as.numeric(hydr$wd_imp_child_mgd) )
if (is.na(wd_imp_child_mgd)) {   # setting this to zero since it doesn't exist
  wd_imp_child_mgd = 0.0
}

wd_mgd <- wd_mgd + wd_imp_child_mgd   # the official wd_mgd

wd_cumulative_mgd <- mean(as.numeric(hydr$wd_cumulative_mgd) )
if (is.na(wd_cumulative_mgd)) {   # setting this to zero since it doesn't exist
  wd_cumulative_mgd = 0.0
}

ps_mgd <- mean(as.numeric(hydr$ps_mgd) )


ps_cumulative_mgd <- mean(as.numeric(hydr$ps_cumulative_mgd))
if (is.na(ps_cumulative_mgd)) {   # setting this to zero since it doesn't exist
  ps_cumulative_mgd = 0.0
}

ps_nextdown_mgd <- mean(as.numeric(hydr$ps_nextdown_mgd))
if (is.na(ps_nextdown_mgd)) {   # setting this to zero since it doesn't exist
  ps_nextdown_mgd = 0.0
}

# net consumption
net_consumption_mgd <- mean(as.numeric(wd_cumulative_mgd - ps_cumulative_mgd))
if (is.na(net_consumption_mgd)) {
  net_consumption_mgd = 0.0
}

# Qout, Q baseline
Qout <- mean(as.numeric(hydr$Qout))

# alter calculation to account for pump store
if (imp_off == 0) {
  if("impoundment_Qin" %in% cols) {
    if (!("ps_cumulative_mgd" %in% cols)) {
      hydr$ps_cumulative_mgd <- 0.0
    }
    hydr$Qbaseline <- hydr$impoundment_Qin +
      (hydr$wd_cumulative_mgd - hydr$ps_cumulative_mgd) * 1.547
  }
}

Qbaseline <- mean(as.numeric(hydr$Qbaseline))

#Adding unmet demand:
hydr$unmet_demand_mgd = as.numeric(hydr$demand_mgd) - as.numeric(hydr$wd_mgd)

# Unmet demand
unmet_demand_mgd <- mean(as.numeric(hydr$unmet_demand_mgd)) #Need to add unmet_demand col to hydr
if (is.na(unmet_demand_mgd)) {
  unmet_demand_mgd = 0.0
}

# The total flow method of consumptive use calculation
consumptive_use_frac <- 1.0 - (Qout / Qbaseline)
hydr$consumptive_use_frac <- 1.0 - (as.numeric(hydr$Qout) / as.numeric(hydr$Qbaseline))
# This method is more appropriate for impoundments that have long
# periods of zero outflow... but the math is not consistent with elfgen
daily_consumptive_use_frac <-  mean(as.numeric(hydr$consumptive_use_frac) )
if (is.na(daily_consumptive_use_frac)) {
  daily_consumptive_use_frac <- 1.0 - (Qout / Qbaseline)
}
# Since Qout = Qbaseline, these fractions will equal 1

vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'net_consumption_mgd', net_consumption_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'wd_mgd', wd_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'wd_cumulative_mgd', wd_cumulative_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'ps_mgd', ps_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'ps_cumulative_mgd', ps_cumulative_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'Qout', Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'Qbaseline', Qbaseline, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'ps_nextdown_mgd', ps_nextdown_mgd, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'consumptive_use_frac', consumptive_use_frac, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'daily_consumptive_use_frac', daily_consumptive_use_frac, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'unmet_demand_mgd', unmet_demand_mgd, ds)

# L90, l30, l07, l01
# h1
flows <- zoo(as.numeric(as.character( hydr$Qout )), order.by = index(hydr))
iout <- fn_iha_flow_extreme(flows, "1 Day Max", "max")
h1_Qout <- iout[1]
h1_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'max1_Qout', h1_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'max1_year', h1_year, ds)
# h3
iout <- fn_iha_flow_extreme(flows, "3 Day Max", "max")
h3_Qout <- iout[1]
h3_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'max3_Qout', h3_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'max3_year', h3_year, ds)

# l90
iout <- fn_iha_flow_extreme(flows, "90 Day Min")
l90_Qout <- iout[1]
l90_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l90_Qout', l90_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l90_year', l90_year, ds)

iout <- fn_iha_flow_extreme(flows, "30 Day Min")
l30_Qout <- iout[1]
l30_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l30_Qout', l30_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l30_year', l30_year, ds)
iout <- fn_iha_flow_extreme(flows, "7 Day Min")
l7_Qout <- iout[1]
l7_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l07_Qout', l7_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l07_year', l7_year, ds)

iout <- fn_iha_flow_extreme(flows, "3 Day Min")
l3_Qout <- iout[1]
l3_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l03_Qout', l3_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l03_year', l3_year, ds)

iout <- fn_iha_flow_extreme(flows, "1 Day Min")
l1_Qout <- iout[1]
l1_year <- iout[2]
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l01_Qout', l1_Qout, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'l01_year', l1_year, ds)


# alf
fn_iha_mlf <- function(zoots, targetmo) {
  modat <- group1(zoots,'water','min')  # IHA function that calculates minimum monthly statistics for our data by water year	 
  print(paste("Grabbing ", targetmo, " values ", sep=''))
  g1vec <- as.vector(as.matrix(modat[,targetmo]))  # gives only August statistics
  print("Performing quantile analysis")
  x <- quantile(g1vec, 0.5, na.rm = TRUE);
  return(as.numeric(x));
}
Qout_zoo <- zoo(hydr$Qout)
alf <- fn_iha_mlf(Qout_zoo,'August') #The median flow of the annual minumum flows in august 


# Sept. 10%
sept_flows <- subset(hydr, month == '9') 
sept_10 <- as.numeric(round(quantile(as.numeric(sept_flows$Qout), 0.10),6)) # September 10th percentile value of Qout flows with quantile 

fn_iha_7q10 <- function(zoots) {
  g2 <- group2(zoots) 
  x <- as.vector(as.matrix(g2["7 Day Min"]))
  for (k in 1:length(x)) {
    if (x[k] <= 0) {
      x[k] <- 0.00000001
      print (paste("Found 0.0 average in year", g2["year"], sep = " "))
    }
  }
  x <- log(x)
  pars <- PearsonDS:::pearsonIIIfitML(x)
  x7q10 <- exp(qpearsonIII(0.1, params = pars$par))
  return(x7q10);
}

# Avg 7-day low flow over a year period -- Move this? 
x7q10 <- fn_iha_7q10(hydr$Qout)  

vahydro_post_metric_to_scenprop(model_scenario$pid, '7q10', NULL, '7q10', x7q10, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'ml8', alf, ds)
vahydro_post_metric_to_scenprop(model_scenario$pid, 'om_class_Constant', NULL, 'mne9_10', sept_10, ds)


#For JSON:
values <- list(imp_off,l90_year)
names(values) <- c("imp_off", "l90_year")

values_json <- serializeJSON(values) # converting to a json

# exporting as json file 
jfile=paste0(json_dir, river_seg, "_summ.json")
message(paste("Writing JSON info in", jfile))
write(values_json, file=jfile, sep = ",", append = FALSE)

