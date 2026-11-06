# Description ####
#Calculate 90-day forecasts at input gages with an auto-selected start date as
#the minimum flow between May and July and either a BPJ or regression
#methodology based on database input 

# Initialize ####
library(hydrotools)
library(agws)
library(dataRetrieval)
library(lubridate)
library(stringr)
basepath <- '/var/www/R'
source(paste(basepath,'config.R',sep='/'))

# get command line args
argst <- commandArgs(trailingOnly=T)

# Ex:
# argst = c("02065500", '/tmp/',"norain_2002", TRUE, "norain_2002.csv","norainfc_2002.csv", "2002-07-10")
if (length(argst) < 6) {
  message(paste("Use: deq_norain.R gages( \"02065500\") output_path scenario adjust_start results_csv_name fc_csv_name [start_date] [end_date]"))
  q()
}

# Inputs ####
#Single gage input
gage_id <- argst[1]

#Save path
save_path <- argst[2]

#Set the file path name by user input or default
scenario <- argst[3]

#Should the start date be adjusted automatically?
adjust_start <- argst[4]

results_csv_name <- argst[5]
fc_csv_name <- argst[6]

# get or guess the date to aim for projection
if (length(argst) > 6) {
  proj_start_date <- as.Date(argst[7])
} else {
  proj_start_date <- as.Date(format(Sys.time(), "%Y-%m-%d")) - 1
}

if (length(argst) > 7) { 
  proj_end_date <- as.Date(argst[8])
} else {
  proj_end_date <- as.Date(proj_start_date) + 90
}

#Start year
yr <- lubridate::year(proj_start_date)

# Gage Object ####
#Load in hydrotools gage object
omgage <- hydrotools::WaterGageDaily$new(
  ds_in = ds, gage_id = gage_id,
  start_date = (proj_start_date - 365),
  end_date = (proj_end_date + 365),
  approval_status = 'all')
#Try to load the gage feature
omgage$load_wshd_feat()

#Skip if no data was loaded or a gage feature was not found
if (nrow(omgage$gage_data) == 0 || !inherits(omgage$gage_feature, "RomFeature")) {
  stop("No watershed feature found.")
}
## Obj QC ####
#Check QC properties - skip if fewer than 10 events found UNLESS rating set
#Get regression limits and set on object
agwrc_props <- omgage$agwrc_fun()
#Get prop
total_bf_events <- agwrc_props$propvalue[agwrc_props$propname == "total_bf_events"]
rating_class <- agwrc_props[agwrc_props$propname == "rating_class",]
#Skip if QC failed (no total events) or if there are fewer than 10 events and
#no set rating class
if(
  (nrow(rating_class) > 0 && rating_class$propvalue > 4) ||
  (total_bf_events < 10 && nrow(rating_class) == 0)
){
  stop("Insufficient data found or inappropriate rating class")
}

## clean_data ####
#Remove all NA flow values
clean_data <- omgage$gage_data[!is.na(omgage$gage_data[,omgage$flow_col]),]
names(clean_data)[names(clean_data) == omgage$flow_col] <- "Flow"
names(clean_data)[names(clean_data) == omgage$date_col] <- "Date"

## Adjust Start Date ####
message("Adjust_start is ", adjust_start)
if(!is.na(as.logical(paste(adjust_start))) && as.logical(adjust_start)){
  #Get the day index that is 30 rows behind the start date (if data is
  #contiguous, this is the date 30-days prior to the start date)
  message("Adjust_start is TRUE")
  start_date <- hydrotools::bf_forecast_start_date(
    start_date = proj_start_date,
    date_col = "Date",
    flow_col = "Flow",
    gage_data = clean_data,
    adjust_start_date = c(paste0(yr,"-05-01"), paste0(yr,"-07-15"))
  )
}else if(!is.na(as.numeric(adjust_start)) && as.numeric(adjust_start) > 0){
  #Get the day index that is 30 rows behind the start date (if data is
  #contiguous, this is the date 30-days prior to the start date)
  message("Adjust_start is integer")
  start_date <- hydrotools::bf_forecast_start_date(
    start_date = proj_start_date,
    date_col = "Date",
    flow_col = "Flow",
    gage_data = clean_data,
    adjust_start_date = as.numeric(adjust_start)
  )
}

Q0 <- clean_data$Flow[clean_data$Date == start_date]


## Forecast Inputs ####
#Select forecast methods for plotting. If Ce is not NA, it is either BPJ or
#regression limited. Otherwise, use regression.
if (!is.na(omgage$agwrc_default$method)) {
  AGWRC <- list(
    "lm_constant" = "lm_constant",
    "lm_variable" = "lm_variable",
    "WSPA Method" = "default"
  )
} else {
  AGWRC <- list(
    "lm_constant" = "lm_constant",
    "lm_variable" = "lm_variable"
  )
}


## Forecast  ####
if (length(argst) > 7) { 
  proj_end_date <- as.Date(argst[8])
} else {
  proj_end_date <- as.Date(proj_start_date) + 90
}

fc_end <- proj_end_date - start_date
bff <- omgage$plot_baseflow_forecast(
  forecast_days = 0:as.integer(fc_end),
  start_date = start_date,
  return_plotly = FALSE,
  AGWRC = AGWRC,
  return_data = TRUE
)

### Forecast Data ####
#If a rating class is set, use the recommended forecast. Otherwise, use a
#variably calculated AGWRC
if (!is.na(omgage$agwrc_default$method)) {
  #Use the default:
  fc <- bff$forecast[bff$forecast$name == "WSPA Method",]
  method <- omgage$agwrc_default$method
} else {
  # use the algorithmic regression C
  fc <- bff$forecast[bff$forecast$name == "lm_variable",]
  method <- "lm_variable"
}

#Make method more specific
if(method == "lm_variable"){
  method <- "regression_limited"
  if(!is.na(omgage$agwrc_default$use_limits) &&
     !omgage$agwrc_default$use_limits ){
    method <- "regression"
  }
}else if(is.numeric(method)){
  method <- "BPJ"
}


### Save Forecast Plot ####
# display ggplot
print(bff$plot) 
fpath <- paste0(save_path, "/norain_log_", gage_id, '_', yr, ".png")
ggplot2::ggsave(fpath)

## Results ####
Q90 <- fc$Forecast[nrow(fc)]
end_date <- fc$Date[nrow(fc)]

### Results Data Frame ####
Ce_out <- median(fc$AGWRC)
odf <- data.frame (
  hydroid = omgage$gage_feature$hydroid,
  gage_id = gage_id,
  gage_name = omgage$gage_feature$name,
  scenario = scenario,
  proj_start_date = start_date,
  proj_end_date = end_date,
  norain_fc = Q90,
  C = Ce_out,
  c_method = method
)

# Write files out ####
write.csv(odf, paste0(save_path, results_csv_name), row.names = FALSE)
write.csv(fc, paste0(save_path, fc_csv_name), row.names = FALSE)

