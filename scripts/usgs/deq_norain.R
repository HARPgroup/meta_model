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
# argst = c("02065500,02059500,02056000,02054530,02056900,02058400,02071000,02061500,02064000", '/tmp', 'norain_2026')
# argst = c("02065500,02059500,02056000,02054530,02056900,02058400,02071000,02061500,02064000", '/tmp', 'norain_2008', '2008-07-01')
# argst = c("03524000,03167000,01674500,01667500,01654000,01634000,02016000,02039500,02042500,02051500,02059500,02056650", '/tmp/test.csv')
# argst = c("02065500,02059500,02056000,02054530,02056900", '/tmp/',"norain_2002","norain_2002.csv", "2002-07-10")
# argst = c("02059500", '/tmp', "norain_2002", "norain_2002.csv", "2002-07-10")
# argst = c("02054530", '/tmp', "norain_1981", "norain_1981.csv", "1981-07-10")
if (length(argst) < 3) {
  message(paste("Use: deq_norain.R gages( \"02065500,02059500,...\") output_path scenario [csv_name] [start_date] [end_date]"))
  q()
}
# Inputs ####
#Allow users to input one or multiple gages via a large comma separated sting
gages <- as.character(argst[1])
#Parse for inidividual gages, if using several, and store as list
gages <- stringr::str_replace_all(gages,'"', '')
glist <- stringr::str_split(gages,",",simplify=TRUE)
save_path <- as.character(argst[2])

#Set the file path name by user input or default
scenario <- as.character(argst[3])
if (length(argst) > 3) {
  csv_name <- as.character(argst[4])
}else{
  csv_name <- NA
}

# get or guess the date to aim for projection
if (length(argst) > 4) {
  proj_start_date <- as.Date(argst[5])
} else {
  proj_start_date <- as.Date(format(Sys.time(), "%Y-%m-%d")) - 1
}

if (length(argst) > 5) { 
  proj_end_date <- as.Date(argst[6])
} else {
  proj_end_date <- as.Date(proj_start_date) + 90
}
#Start year
yr <- lubridate::year(proj_start_date)

if(is.na(csv_name)){
  csv_name <- paste0(scenario, "_Q90_", yr, ".csv")
}

# Allocate results data frame
odf <- data.frame(
  hydroid = integer(),
  gage_id = character(),
  gage_name = character(),
  norain_90 = numeric(),
  proj_date = character(),
  proj_emerg = character(),
  record_low = character(),
  C = numeric(),
  c_method = character()
)

# Gage loop ####
for (gage_id in glist) {
  ## Gage Object ####
  #Load in hydrotools gage object
  omgage <- hydrotools::WaterGageDaily$new(ds_in = ds, gage_id = gage_id,
                                           start_date = (proj_start_date - 365),
                                           end_date = (proj_end_date + 365),
                                           approval_status = 'all')
  #Try to load the gage feature
  omgage$load_wshd_feat()
  
  #Skip if no data was loaded or a gage feature was not found
  if (nrow(omgage$gage_data) == 0 || !inherits(omgage$gage_feature, "RomFeature")) {
    next
  }
  ## Obj QC ####
  #Check QC properties - skip if fewer than 10 events found UNLESS rating set
  agwrc_props <- omgage$get_model_or_scenario_props(model_prop_code = "AGWRC-1.0")
  #Get prop
  total_bf_events <- agwrc_props$propvalue[agwrc_props$propname == "total_bf_events"]
  rating_class <- agwrc_props[agwrc_props$propname == "rating_class",]
  #Skip if QC failed (no total events) or if there are fewer than 10 events and
  #no set rating class
  if(length(total_bf_events) == 0 || 
     (total_bf_events < 10 & nrow(rating_class) == 0) && rating_class <= 4){
    next
  }
  
  ## BPJ AGWRC Check ####
  # get bounds on relationship if set
  method <- 'regression'
  Ce <- NA
  if(nrow(rating_class) > 0 && rating_class$propvalue == 3){
    #Set BPJ agwrc and 
    method <- 'bpj'
    Ce <- as.numeric(rating_class$propcode)
  }else{
    ## AGWRC Regression ####
    #Get regression limits and set on object
    reg_coeff <- omgage$agwrc_fun()
    agwrc_reg_qlow <- omgage$agwrc_lm_limit$agwrc_reg_qlow
    agwrc_reg_clow <- omgage$agwrc_lm_limit$agwrc_reg_clow
    agwrc_reg_qhigh <- omgage$agwrc_lm_limit$agwrc_reg_qhigh
    agwrc_reg_chigh <- omgage$agwrc_lm_limit$agwrc_reg_chigh
  }
  
  ## clean_data ####
  #Remove all NA flow values
  clean_data <- omgage$gage_data[!is.na(omgage$gage_data[,omgage$flow_col]),]
  names(clean_data)[names(clean_data) == omgage$flow_col] <- "Flow"
  names(clean_data)[names(clean_data) == omgage$date_col] <- "Date"
  
  ## Adjust Start Date ####
  #Get the day index that is 30 rows behind the start date (if data is
  #contiguous, this is the date 30-days prior to the start date)
  start_date <- hydrotools::bf_forecast_start_date(
    start_date = proj_start_date,
    date_col = "Date",
    flow_col = "Flow",
    gage_data = clean_data,
    adjust_start_date = c(paste0(yr,"-05-01"), paste0(yr,"-07-03"))
  )
  
  Q0 <- clean_data$Flow[clean_data$Date == start_date]
  
  ## Plot Start Date ####
  # inspect for start date
  plot(
    Flow ~ Date, 
    data=clean_data[clean_data$Date <= (start_date + 30) & 
                      clean_data$Date >= (start_date - 30),],
    main=paste("Observed", omgage$gage_feature$name),
    ylim=c(0, max(clean_data$Flow))
  )
  points(start_date, Q0,
         col="red", bg="red", pch = 21, cex = 2)
  
  
  ## Regression limits ####
  # Adjust the initial AGWRC Ce for regression limits
  if ( !(method == 'bpj') ) {
    if(!is.na(agwrc_reg_qlow) && 
       Q0 < agwrc_reg_qlow){
      Ce <- agwrc_reg_clow
      method <- 'regression_limit'
    }else if(!is.na(agwrc_reg_qlow) && 
             Q0 > agwrc_reg_qhigh){
      Ce <- agwrc_reg_chigh
      method <- 'regression_limit'
    }
  }
  
  ## Forecast Inputs ####
  #Select forecast methods for plotting. If Ce is not NA, it is either BPJ or
  #regression limited. Otherwise, use regression.
  if (!is.na(Ce)) {
    if (method != 'regression_limit') {
      AGWRC <- list(
        "lm_constant" = "lm_constant",
        "lm_variable" = "lm_variable",
        "BPJ" = Ce
      )
    } else {
      AGWRC <- list(
        "lm_constant" = "lm_constant",
        "lm_variable" = "lm_variable",
        "Reg Limit" = Ce
      )
    }
  } else {
    AGWRC <- list(
      "lm_constant" = "lm_constant",
      "lm_variable" = "lm_variable"
    )
  }
  
  
  ## Forecast  ####
  bff <- omgage$plot_baseflow_forecast(
    start_date = start_date,
    return_plotly = FALSE,
    AGWRC = AGWRC,
    return_data = TRUE
  )
  
  ### Forecast Data ####
  if (!is.na(Ce)) {
    if (method != 'regression_limit') {
      # use a manually defined constant C
      fc <- bff$forecast[bff$forecast$name == "BPJ",]
    } else {
      fc <- bff$forecast[bff$forecast$name == "Reg Limit",]
    }
  } else {
    # use the algorithmic regression C
    fc <- bff$forecast[bff$forecast$name == "lm_variable",]
  }
  
  ### Save Forecast Plot ####
  # display ggplot
  print(bff$plot) 
  fpath <- paste0(save_path, "/Q90_norain_log_", gage_id, '_', yr, ".png")
  ggplot2::ggsave(fpath)
  
  ## Results ####
  Q90 <- fc$Forecast[nrow(fc)]
  end_date <- fc$Date[nrow(fc)]
  
  ### Defaults ####
  is_emerg <- 'No' 
  is_emerg_int <- 0
  is_hist <- 'No'
  is_hist_int <- 0
  
  ### Historic Min Flow ####
  Qmin <- min(clean_data$Flow)
  if (Q90 <= Qmin) {
    is_hist <- 'Yes'
    is_hist_int <- 1
  }
  
  ### NEP Comparison ####
  ntab <- omgage$nep_table()
  emo <- lubridate::month(end_date)
  emo_em <- ntab$`5%`[emo]
  if (Q90 <= emo_em) {
    is_emerg <- 'Yes'
    is_emerg_int <- 1
  }
  
  ### Results Plot ####
  fpath <- paste0(save_path, "/Q90_norain_", gage_id, "_", yr, ".png")
  yinc <- max(fc$Forecast) / 10
  png(fpath)
  plot(
    fc$Forecast ~ fc$Date,
    main=paste("Projected", omgage$gage_feature$name)
  )
  text(as.Date(end_date - 10), Q90 + yinc * 2, paste("Q90 =", round(Q90,1), "cfs"))
  text(as.Date(end_date - 10), Q90 + yinc * 3, paste("Qmin =", round(Qmin,1), "cfs"))
  dev.off()
  
  ### Results Data Frame ####
  Ce_out <- median(fc$AGWRC)
  odl <- data.frame (
    hydroid = omgage$gage_feature$hydroid,
    gage_id = gage_id,
    gage_name = omgage$gage_feature$name,
    norain_90 = Q90,
    hist_min = Qmin,
    proj_date = end_date,
    proj_emerg = is_emerg,
    record_low = is_hist,
    C = Ce_out,
    c_method = method
  )
  ### Rbind to previous ####
  odf <- rbind(
    odf,
    odl
  )
  
  ## POST Results ####
  # scenario is:
  # norain_[yr]_[mo]_[da]
  # Get AGWRC model property:
  model <- ModelElementBase$new(
      ds,
      config = list(
        hydroid = omgage$gage_feature$hydroid, version="AGWRC-1.0")
  )
  
  #Get norain scenario property:
  sceninfo <- list(
    varkey = 'om_scenario',
    propname = scenario,
    featureid = model$pid,
    entity_type = "dh_properties",
    bundle = "dh_properties"
  )
  scenprop <- RomProperty$new(ds, sceninfo, TRUE)
  # Set the property dates for that of the forecast
  scenprop$startdate <- as.numeric(as.POSIXct(start_date,tz="America/New_York"))
  scenprop$enddate <- as.numeric(as.POSIXct(end_date,tz="America/New_York"))
  scenprop$save(TRUE)
  
  #Set forecast statuses including flags, minimum flow, and 90-day forecast:
  scenprop$set_prop(propname="is_emerg", propvalue = is_emerg_int, propcode = is_emerg)
  scenprop$set_prop(propname="is_hist", propvalue = is_hist_int, propcode = is_hist)
  scenprop$set_prop(propname="Q90", propvalue = Q90)
  scenprop$set_prop(propname="Qmin", propvalue = Qmin)
  
}
# Write Results ####
write.csv(odf, file = csv_name)

