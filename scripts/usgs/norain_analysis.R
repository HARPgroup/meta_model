# Description ####
#Looks at no rain forecasts and runs basic analyses on results

# Initialize ####
library(hydrotools)
library(dataRetrieval)
basepath <- '/var/www/R'
source(paste(basepath,'config.R',sep='/'))

# get command line args
argst <- commandArgs(trailingOnly=T)

# Ex:
# argst = c("02065500", 'results.csv',"fc.csv", "/tmp/", "analysis.csv")
if (length(argst) < 5) {
  stop(paste("Use: norain_analysis.R gageid results_csv fc_csv save_path analysis_csv_name"))
}

# Inputs ####
gage_id <- argst[1]
results <- read.csv(argst[2])
fc <- read.csv(argst[3])
save_path <- argst[4]
analysis_csv_name <- argst[5]

## Set classes ####
results$proj_start_date <- as.Date(results$proj_start_date)
results$proj_end_date <- as.Date(results$proj_end_date)
fc$Date <- as.Date(fc$Date)

# Gage Object ####
#Load in hydrotools gage object
omgage <- hydrotools::WaterGageDaily$new(
  ds_in = ds, gage_id = gage_id,
  approval_status = 'all')

# Defaults ####
is_emerg <- 'No' 
is_emerg_int <- 0
is_hist <- 'No'
is_hist_int <- 0

# Historic Min Flow ####
Qmin <- min(omgage$gage_data[,omgage$flow_col])
if (results$norain_fc <= Qmin) {
  is_hist <- 'Yes'
  is_hist_int <- 1
}

# NEP Comparison ####
ntab <- omgage$nep_table()
emo <- lubridate::month(results$proj_end_date)
emo_em <- ntab$`5%`[emo]
if (results$norain_fc <= emo_em) {
  is_emerg <- 'Yes'
  is_emerg_int <- 1
}

# Analysis df ####
analysis_out <- cbind(
  results,
  data.frame(
    hist_min = Qmin,
    is_emerg = is_emerg,
    is_emerg_int = is_emerg_int,
    is_hist = is_hist,
    is_hist_int = is_hist_int
  )
)

# Results Plot ####
fpath <- paste0(save_path, "/norain_", gage_id, "_", yr, ".png")
yinc <- max(fc$Forecast) / 10
png(fpath)
plot(
  x = as.Date(fc$Date), y = fc$Forecast,
  main=paste("Projected", omgage$station_name)
)
text(analysis_out$proj_end_date - 10, analysis_out$norain_fc + yinc * 2,
     paste("norain_fc =", round(analysis_out$norain_fc,1), "cfs"))
text(analysis_out$proj_end_date - 10, analysis_out$norain_fc + yinc * 3,
     paste("hist_Qmin =", round(analysis_out$hist_min,1), "cfs"))
dev.off()

# Write csv ####
write.csv(row.names = FALSE, x = analysis_out, file = analysis_csv_name)

