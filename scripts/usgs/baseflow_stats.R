#A script that will take in a flow file that has baseflow periods identified and
#then run linear regression to identify potential recession coefficients from
#each event
#For local testing:
# commandArgs <- function(...){
#   c("strasBF.csv", "for", "strasstats.csv")
# }

args <- commandArgs(trailingOnly = T)
if (length(args) < 3){
  message("Use Rscript baseflow_stats.R input_file luname_seg output_file")
  q()
}
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(agws))

# get arguments
input_file <- as.character(args[1])
input_file <- str_replace_all(input_file, '\"', '') # quotes coming in give troubles
land_type_code <- as.character(args[2]) # for example, "forN51171"
end_path <- as.character(args[3])

message(paste0("DEBUG with: args <- c('",paste(args,collapse="', '")),"')")

message(paste("Reading", input_file))

analysis_df <- read.csv(input_file)
#Coerce character back to date
analysis_df$Date <- as.Date(analysis_df$Date)

analysis_df <- agws::attach_event_stats(analysis_df, r_lim = 0)

# Write final csvs out
write.csv(analysis_df, end_path, row.names = FALSE)
