# R file to take a rating file (monthly, or datetime based) and create a timeseries 
#with ratings
library(sqldf)
library(lubridate)
argst <- commandArgs(trailingOnly = T)
if (length(argst) != 4){
  message("Usage: Rscript create_rating_ts.R precip_data_file rating_csv rating_ts_file rating_timescale(monthly,date_based)")
  q()
}

#A file with a timeseries to which the rating will be joined based on month or
#month/day/year based on rating_timescale below
base_ts_file <- argst[1]
#The rating file that should contain monthly ratings if rating_timescale is
#monthly or should otherwise be obs_date and rating
rating_file <- argst[2]
#The file path to which write the timeseries ratings
rating_ts_file <- argst[3]
#Either monthly or obs_date and expresses what kind of ratings are in
#rating_file. Monthly would contain a column "mo" that has 1:12 in it such that
#there are only 12 rows in the dataset
rating_timescale <- argst[4]

# Load the data
ratings <- read.csv(rating_file)
base_ts <- read.csv(base_ts_file)
r_names <- names(ratings)

# Verify
if (rating_timescale == 'monthly') {
  req_cols = c('mo', 'rating')
} else {
  req_cols = c('start_date', 'end_date', 'rating')
}
# check for required cols
if (!all(req_cols %in% r_names)) {
  message(paste("Error: Required columns", req_cols, "not complete. Given columns: ", r_names, "in rating file:", rating_file))
  q()
}

#Convert posixCT date-time fields to date fields for easier comparison:
base_ts$obs_date <- as.Date(base_ts$obs_date)
if (rating_timescale != 'monthly') {
  ratings$start_date <- as.Date(ratings$start_date)
  ratings$end_date <- as.Date(ratings$end_date)
}

# Based on rating_timescale, join the ratings data frame to base_ts based on the
# month or the observed date obs_date. The output file will have a start_date
# and end_date column as the monthly data will be grouped by month
if (rating_timescale == 'monthly') {
  rating_sql <- "
    select mon_base_ts.start_date,
    mon_base_ts.end_date,
    b.rating
    from (
      select min(a.obs_date) as start_date,
      max(a.obs_date) as end_date,
      mo,yr
      from base_ts as a
      group by mo,yr
    ) as mon_base_ts
    left outer join ratings as b
    on (
      mon_base_ts.mo = b.mo
    )
    order by mon_base_ts.start_date
  "
} else if (rating_timescale == 'weekly'){
  message("Determining week for each record in R")
  base_ts$wk <- week(base_ts$obs_date)
  rating_sql <- "
    select wk_base_ts.start_date,
    wk_base_ts.end_date,
    b.rating
    from (
      select min(a.obs_date) as start_date,
      max(a.obs_date) as end_date,
      wk,yr
      from base_ts as a
      group by wk,yr
    ) as wk_base_ts
    left outer join ratings as b
    on (
      wk_base_ts.start_date >= b.start_date
      AND wk_base_ts.end_date <= b.end_date
    )
    order by wk_base_ts.start_date
  "
} else if (rating_timescale == 'daily'){
  #For a daily rating expansion, include the start and end date
  rating_sql <- "
    select a.obs_date as start_date, a.obs_date as end_date,b.rating
    from base_ts as a
    left outer join ratings as b
    on (
      a.obs_date >= b.start_date
      and a.obs_date <= b.end_date
    )
  "
}

rating_ts <- sqldf(rating_sql)

message(paste("Saving ratings to",rating_ts_file))
write.csv(rating_ts, rating_ts_file, row.names=FALSE)
