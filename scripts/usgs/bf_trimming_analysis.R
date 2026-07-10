# dependencies
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(agws))


#set up command Args
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 2) {
  message("This script will take a time series of trimmed drought events and identify relevant recession coefficients.")
  message("Use: bf_trimming_analysis.R Drought_event_time_series_data_to_trim output_file ")
  q()
}


csv1_path <- argst[1]
output_file <- argst[2]

#Load data to trim
csv1_trimmed <- read.csv(csv1_path)


#1. Apply bf_event_stats to determine post trimming values of AGWRC and R Squared
csv1_event_stats <- csv1_trimmed %>%
  group_by(GroupID) %>%
  group_split() %>%
  map_df(~ {
    res <- agws::bf_event_stats(.x)
    .x %>% mutate(
      AGWRC = res$AGWRC,
      R_squared = res$R_squared
    )
  }) %>%
  ungroup()


#2. Filter for AGWRC values < 1 introduced by trimming
tol <- 1e-8

csv1_bf_events <- csv1_event_stats %>%
  filter(AGWRC < 1 - tol)


#3. Export as .csv files
#Save as .csv files
write.csv(csv1_bf_events, file = output_file,
          row.names = FALSE
)




