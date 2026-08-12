#A script to calculate potential outliers from a regression
#For local testing:
# commandArgs <- function(...){
#   c("https://deq1.bse.vt.edu/usgs/agws/baseflow_summary_df_01634000.csv", paste0("step8_","01634000", ".csv"))
# }
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 2){
  message("Use Rscript regression_qc.R reg_event_df output_file")
  q()
}

suppressPackageStartupMessages(library(agws))

# get arguments
reg_event_file <- argst[1]
reg_event_file <- str_replace_all(reg_event_file, '\"', '') # quotes coming in give troubles
end_path <- argst[2]

#Read in summarized baseflow recession stats
event_df <- read.csv(reg_event_file)
#Create regression from all events
model <- agws::fit_agwrc_regression(event_df)

### These two functions flags outliers ###
# IQR uses boundaries to detect unusually high or low values in the data
# Cook's distance detects influential observations that affect the model fit
IQR_outlier_flags <- agws::flag_outliers_IQR(c(lm_model$model$logQ,0.001))
cooks_outlier_flags <- agws::flag_cooks(model)

#Write to output df
event_df$IQR_outlier_flags <- IQR_outlier_flags
event_df$cooks_outlier_flags <- cooks_outlier_flags

# Write final csvs out
write.csv(event_df, end_path, row.names = FALSE)

