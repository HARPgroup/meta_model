#Creates Summary analytic functions for workflow
#Use for VA HYDRO metrics
library(tidyr)
library(sqldf)
library(zoo)


## For ANY data

summary_analytics <- function(met_data){

  # Create daily summary to use for all data. This makes hourly data daily sums.
daily_summary <- 
  sqldf(
    "SELECT yr, mo, da, obs_date, SUM(precip_in) AS total_precip
  FROM met_data
  GROUP BY yr, mo, da"
  ) #include obs_date after SQL to data frame
precip_daily_max_in <- max(daily_summary$total_precip)


#creating a yearly summary with each year and its total precip
yearly_summary <- 
  sqldf(
  "SELECT COUNT(*) AS ndays, yr, SUM(total_precip) AS total_precip
  FROM daily_summary
  GROUP BY yr
  HAVING ndays >= 364"
)

#summary analytics

precip_annual_max_in <- 
  max(yearly_summary$total_precip)

precip_annual_max_year <- 
  yearly_summary$yr[which.max(yearly_summary$total_precip)]

precip_annual_mean_in <- 
  mean(yearly_summary$total_precip)


#For min values and years, we can exclude the first and last row since the 
#current year and first years are incomplete data
precip_annual_min_in <- 
  min(yearly_summary$total_precip)
precip_annual_min_year <- 
  yearly_summary$yr[which.min(yearly_summary$total_precip)]






#if else statement evaluates the amount of unique hours and if 24,
#then hourly max is taken. If not, hourly max is NA
if(length(unique(met_data$hr)) == 24){
  precip_hourly_max_in <- max(met_data$precip_in)
} else {
  precip_hourly_max_in <- NA
}
#Alternatively to a null value for hourly precip in daily data,
#we could look at the rainfall distribution table for a 
#type II storm and multiply by the max P(t)/P(24) value.
#this function uses NULL for daily data


#l90 using zoo package
l90_precip_in_roll <- 
  min(rollapply(daily_summary$total_precip, width = 90, FUN = mean, 
                fill = NA, align = "right"), 
    na.rm = TRUE)

#l90 using IHA
if(length(unique(met_data$hr)) == 24){
  Qout_zoo <- zoo(as.numeric(daily_summary$total_precip), order.by = as.POSIXct(daily_summary$obs_date))
  Qout_g2 <- data.frame(group2(Qout_zoo))
  l90_precip_in <- min(Qout_g2$X90.Day.Min)
} else {
  Qout_zoo <- zoo(as.numeric(met_data$precip_in), order.by = as.POSIXct(met_data$obs_date))
  Qout_g2 <- data.frame(group2(Qout_zoo))
  l90_precip_in <- min(Qout_g2$X90.Day.Min)
}



#makes data frame with all 9 metrics
metrics<- data.frame(precip_annual_max_in = precip_annual_max_in,
                        precip_annual_max_year = precip_annual_max_year, 
                        precip_annual_mean_in = precip_annual_mean_in,
                        precip_annual_min_in = precip_annual_min_in, 
                        precip_annual_min_year = precip_annual_min_year, 
                        precip_daily_max_in = precip_daily_max_in,
                        precip_hourly_max_in = precip_hourly_max_in,
                        l90_precip_in = l90_precip_in,
                        l90_precip_in_roll = l90_precip_in_roll)
}

