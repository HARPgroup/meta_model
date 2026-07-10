#A script  to summarize the recession coefficients from a flow gage data frame
#with identified recession coefficients
#For local testing:
# commandArgs <- function(...){
#   c("strasTrimStats.csv", "01634000", "strasSummaryStats.csv")
# }
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 2){
  message("Use Rscript baseflow_regression_df.R input_file output_file gage_id [regression_flow_col='Flow'] [add_inches_day=FALSE]")
  q()
}

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(hydrotools))
suppressPackageStartupMessages(library(agws))

# get arguments
input_file <- as.character(argst[1])
input_file <- str_replace_all(input_file, '\"', '') # quotes coming in give troubles
gage_id <- as.character(argst[2])
end_path <- as.character(argst[3])
#Check if regression_flow_col was input or if default should be used
if (length(argst) > 3) {
  regression_flow_col <- as.character(argst[4])
} else {
  regression_flow_col <- "Flow"
}
#Check if add_inches_day was input or if default should be used
if (length(argst) > 4) {
  add_inches_day <- as.logical(argst[5])
} else {
  add_inches_day <- FALSE
}

#Read in baseflow recession event stats (either pre- or post-event trimming)
points_df <- read.csv(input_file)
#Ensure standard column data types
points_df <- agws::bf_standardize_analysis_df(points_df, gage_id = gage_id)

#Convert flow to inches per day on user request
if (add_inches_day || regression_flow_col == "flow_in_day") {
  #Get drainage area from hydrotools::WaterGageBase()
  gage_obj <- hydrotools::WaterGageBase$new(config = list(gage_id = gage_id))
  gage_obj$load_sf_da()
  area_sqmi <- gage_obj$drainage_area

  points_df <- agws::add_flow_in_day(
    points_df = points_df,
    area_sqmi = area_sqmi,
    source_flow_col = "Flow",
    new_col = "flow_in_day"
  )
}
#Summarize regression events
event_df <- agws::make_event_regression_df(
  points_df = points_df,
  regression_flow_col = regression_flow_col
)

# Write final csvs out
write.csv(event_df, end_path,row.names = FALSE)
