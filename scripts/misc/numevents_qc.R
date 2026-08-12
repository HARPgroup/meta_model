# A script that will take in a csv, groups by a column, and identifies monthly
# and total counts
#For local testing:
# commandArgs <- function(...){
#   c(paste0("step6_","01634000", ".csv"), "output.csv")
# }

suppressPackageStartupMessages(library(agws))

args <- commandArgs(trailingOnly = T)
if (length(args) < 2){
  stop("Use Rscript numevents_qc.R input_06_file output_file [date_col = 'start_date'] [group_col = 'GroupID']")
}

# get arguments
input_06_file <- args[1]
output_file <- args[2]

if(length(args) >= 4){
  date_col <- args[3]
  group_col <- args[4]
}else{
  date_col <- "start_date"
  group_col <- "GroupID"
}

message(paste0("DEBUG with: args <- c('",paste(args,collapse="', '")),"')")

# read in the data and use the same name as bf workflow output
if(file.exists(input_06_file)){
  reg_df <- read.csv(input_06_file)
  # get event counts (monthly and gage total)
  monthly_events <- agws::monthly_group_count(reg_df,
                                              date_col = start_date,
                                              group_col = group_col)
}else{
  monthly_events <- data.frame(
    month = 1:12,
    event_cnt = 0,
    gage_total = 0
  )
}


# Write csvs
#Monthly event total
write.csv(monthly_events, output_file, row.names = FALSE)


