#A script  to develop a regression of log(Q) vs AGWRC from a series of
#summarized baseflow events (with estimated recession coefficients already
#incorporated)
#For local testing:
# commandArgs <- function(...){
#   c("strasSummaryStats.csv", "01634000", "strasAGWRCRegression.csv")
# }
args <- commandArgs(trailingOnly = T)
if (length(args) < 2){
  message("Use Rscript baseflow_regression_df.R input_file output_file gage_id [regression_flow_col='Flow']")
  q()
}

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(hydrotools))

source("https://raw.githubusercontent.com/HARPgroup/baseflow_storage/main/FinalRegression.R")

# get arguments
input_file <- paste0(args[1])
input_file <- str_replace_all(input_file, '\"', '') # quotes coming in give troubles
gage_id <- args[2]
end_path <- paste0(args[3])
#Check if regression_flow_col was input or if default should be used
if (length(args) > 3) {
  regression_flow_col <- paste0(args[4])
} else {
  regression_flow_col <- "Flow"
}

#Read in summarized baseflow recession stats 
event_df <- read.csv(input_file)
#Create regression from all events
coeffs <- fit_agwrc_regression(event_df)

#Output data frame
out <- data.frame(
  site_no = as.character(gage_id),
  flow_metric = regression_flow_col,
  m = coeffs$m,
  b = coeffs$b
)
message(paste0("Found coefficients m = ",coeffs$m," and b = ",coeffs$b))
# Write final csvs out
write.csv(out, end_path,row.names = FALSE)
