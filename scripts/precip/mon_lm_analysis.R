#Arguments
# 1 the location of the csv, can be comp_data or week_data
#2 y_variable
#3 x_variable
#4 month variable
#5 json write_path this is the full data_lm
#5 csv write_path this is just stats
suppressPackageStartupMessages(library("dataRetrieval"))
suppressPackageStartupMessages(library("lubridate"))
suppressPackageStartupMessages(library("sqldf"))
suppressPackageStartupMessages(library("R6"))
suppressPackageStartupMessages(library("jsonlite"))
#for testing purposes
#source("~/HarpData/HARParchive/HARP-2024-2025/functions/lm_analysis_plots.R")


#mon_lm functions
source("https://raw.githubusercontent.com/HARPgroup/meta_model/master/scripts/precip/lm_analysis_plots.R")


#checks for proper number of arguments
args <- commandArgs(trailingOnly = T)
if (length(args) != 6){
  message("Missing or extra inputs. Usage: Rscript analysis.R data_csv y_variable x_var month_var json_write_path csv_write_path ")
  q()
}
print("Assigning Arguments to Variables")
data_location <- args[1]
y_var <- args[2]
x_var <- args[3]
mo_var <- args[4]
json_write_path <- args[5]
ratings_write_path <-args[6]

print("Reading in data")
sample_data <- read.csv(data_location)

print("Running mon_lm function")
data_lm <- mon_lm_stats(sample_data,y_var,x_var,mo_var)

message(paste0("Write json in new file path: ",json_write_path))
json_data_lm <- data_lm$toJSON()
write(json_data_lm,json_write_path)

ratings <- data_lm$atts$stats
names(ratings) <- c('mo', 'rating') # this file should have either "mo", or "mo", "da", "yr" columns
message(paste("Saving rating data to:", ratings_write_path))
write.csv(ratings, ratings_write_path, row.names=FALSE)
