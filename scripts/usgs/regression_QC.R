#A script to calculate heteroscedasticity metrics and append to the regression
#summary data frame
#For local testing:
# commandArgs <- function(...){
#   c("https://deq1.bse.vt.edu/usgs/agws/baseflow_summary_df_01634000.csv", step07a_lm, paste0("step8_","01634000", ".csv"))
# }
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 3){
  message("Use Rscript regression_qc.R reg_event_df reg_summary_input_file output_file")
  q()
}

suppressPackageStartupMessages(library(agws))
suppressPackageStartupMessages(library(stringr))

# get arguments
reg_event_file <- argst[1]
reg_event_file <- str_replace_all(reg_event_file, '\"', '') # quotes coming in give troubles
reg_summary_file <- argst[2]
reg_summary_file <- str_replace_all(reg_summary_file, '\"', '')
end_path <- argst[3]

#Read in summarized baseflow recession stats
event_df <- read.csv(reg_event_file)
reg_summary_df <- read.csv(reg_summary_file)
#Create regression from all events
model <- agws::fit_agwrc_regression(event_df)
model_summary <- summary(model)

# run function
hetero_df <- agws::heteroscedasticity(model = model)

reg_summary_df <- cbind(reg_summary_df, hetero_df)

# Write final csvs out
write.csv(reg_summary_df, end_path, row.names = FALSE)

