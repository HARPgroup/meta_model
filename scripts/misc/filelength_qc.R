# Find the number of non-na observations of a column in a csv
#For local testing:
# commandArgs <- function(...){
#   c("01634000", paste0("step1_","01634000", ".csv"),'lengthqc.csv')
# }
args <- commandArgs(trailingOnly = T)
if (length(args) < 3){
  stop("Use Rscript filelength_qc.R gageID input_01_file output_file [data_col = 'obs_flow']")
}

# get arguments
gageID <- args[1]
input_01_file <- args[2]
output_file <- args[3]

if(length(args) >= 4){
  data_col <- args[4]
}else{
  data_col <- "obs_flow"
}

message(paste0("DEBUG with: args <- c('",paste(args,collapse="', '")),"')")

### This script contains a list of QC functions to be added to ###
### the baseflow workflow ###
# read in the data and use the same name as bf workflow output
daily_df <- read.csv(input_01_file)

# Get total non-NA flow record count
gage_length <- sum(!is.na(daily_df[,data_col]))

# Write csvs
#Gage length and slope
write.csv(gage_length,
          output_file,
          row.names = FALSE)


