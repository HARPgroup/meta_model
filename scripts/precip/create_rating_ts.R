# R file to take a rating file (monthly, or datetime based) and create a timeseries with ratings
library(sqldf)

argst <- commandArgs(trailingOnly = T)
if (length(argst) != 4){
  message("Usage: Rscript create_rating_ts.R precip_data_file rating_csv rating_ts_file rating_timescale(monthly,date_based)")
  q()
}

base_ts_file <- argst[1]
rating_file <- argst[2]
rating_ts_file <- argst[3]
rating_timescale <- argst[4]

# Load the data
ratings <- read.csv(rating_file)
base_ts <- read.csv(base_ts_file)
r_names <- names(ratings)

# Verify
if (rating_timescale == 'monthly') {
  req_cols = c('mo', 'rating')
} else {
  req_cols = c('obs_date', 'rating')
}
# check for required cols
if (!all(req_cols %in% r_names)) {
  message(paste("Error: Required columns", req_cols, "not complete. Given columns: ", r_names, "in rating file:", rating_file))
  q()
}

# merge
if (rating_timescale == 'monthly') {
  rating_sql <- "
    select a.obs_date, b.rating
    from base_ts as a
    left outer join ratings as b
    on (
      a.mo = b.mo
    )
    order by a.obs_date
  "
} else {
  rating_sql <- "
    select a.start_date, a.end_data, b.rating
    from base_ts as a
    left outer join ratings as b
    on (
      a.yr = b.yr
      a.mo = b.mo
      a.dy = b.dy
    )
  "
}
rating_ts <- sqldf(rating_sql)

message(paste("Saving ratings to",rating_ts_file))
write.csv(rating_ts, rating_ts_file, row.names=FALSE)
