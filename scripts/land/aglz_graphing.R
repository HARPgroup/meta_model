library(data.table)
library(zoo)
library(IHA)
library(PearsonDS)
library(ggplot2)
library(dplyr)
library(lubridate)
library(stats)



pwater <- fread("forA51800_pwater.csv")
pwater$date <- as.Date(pwater$index, format = "%m/%d/%y")
pwater$week <- week(pwater$date)
pwater$month <- month(pwater$date)
pwater$year <- year(pwater$date)
dailyAGWS <- aggregate(pwater$AGWS, by = list(pwater$date), FUN = "mean")
colnames(dailyAGWS) <- c("date", "AGWS") # Changing column names
weeklyAGWS <- aggregate(pwater$AGWS, by = list(pwater$week, pwater$year), FUN = "mean")
monthlyAGWS <- aggregate(pwater$AGWS, by = list(pwater$month, pwater$year), FUN = "mean")
colnames(weeklyAGWS) <- c("week", "yr", "AGWS")
colnames(monthlyAGWS) <- c("month", "yr", "AGWS")

years <- seq(1984,2020,1)
plot(monthlyAGWS$AGWS, type ='l', ylab = 'AGWS (in)', xaxt = 'n', xlab = NA, col = 'blue')
axis(1, at = seq(6,438,12), labels = years) 
title(main = 'Active groundwater storage', sub = 'Monthly average values are plotted')

# Graph type #2: Stacked plot

# Adding UZS and LZS to the table of daily data
dailyUZS <- aggregate(pwater$UZS, by = list(pwater$date), FUN = "mean")
colnames(dailyUZS) <- c('date', 'UZS')
dailyLZS <- aggregate(pwater$LZS, by = list(pwater$date), FUN = "mean")
colnames(dailyLZS) <- c('date', 'LZS')
dailyAGWS$UZS <- dailyUZS$UZS
dailyAGWS$LZS <- dailyLZS$LZS

# Manipulating data to graph
dailyAGWS$month <- month(dailyAGWS$date)
dailyAGWS$year <- year(dailyAGWS$date)
monthlyAGWS <- aggregate(dailyAGWS[ ,2:4], by = list(dailyAGWS$month, dailyAGWS$year), FUN = "mean")
colnames(monthlyAGWS) <- c('month','year','AGWS','UZS','LZS')
# Adding dates for graphing 
monthlyAGWS$date <-  as.Date(paste(monthlyAGWS$month, monthlyAGWS$year, '15'), '%m %Y %d')
# Graphing daily groundwater storage (UZS, LZS & AGWS) as a stacked plot:
ggplot(monthlyAGWS, aes(x=date)) + geom_area(aes(y=LZS, fill = 'blue'))+ geom_area(aes(y=UZS, fill ='red')) + 
  geom_area(aes(y=AGWS, fill='green')) + 
  labs(x='Date', y= 'Storage (in)') + 
  ggtitle('Groundwater storage for A51800') +
  scale_fill_identity(name =NULL, breaks=c('green','red','blue'), labels = c('Active groundwater','Upper zone','Lower zone'), guide = 'legend') +
  theme(legend.position = c(.9,.99))
# Converting AGWO in in/hr to cfs/mi^2
convert_cfs_sqm = 645.3333333
pwater$AGWO_ <- pwater$AGWO*convert_cfs_sqm # AGWO_ has units of cfs/sq mi

# Manipulating data to graph
dailyAGWO_ <- aggregate(pwater$AGWO_, by=list(pwater$date), FUN='mean')
colnames(dailyAGWO_) <- c('date','AGWO')
dailyAGWO_$month <- month(dailyAGWO_$date)
dailyAGWO_$year <- year(dailyAGWO_$date)
monthlyAGWO <- aggregate(dailyAGWO_$AGWO, by = list(dailyAGWO_$month, dailyAGWO_$year), FUN = "mean")
dailySummer <- dailyAGWO_ %>% filter(month==7|month==8|month==9|month==10)
monthlySummer <- aggregate(dailySummer$AGWO, by = list(dailySummer$month, dailySummer$year), FUN = "mean")
colnames(monthlyAGWO) <- c('Month', 'Year', 'AGWO')
colnames(monthlySummer) <- c('Month', 'Year', 'AGWO')
monthlyAGWO$date <-  as.Date(paste(monthlyAGWO$Month, monthlyAGWO$Year, '15'), '%m %Y %d')
monthlySummer$date <-  as.Date(paste(monthlySummer$Month, monthlySummer$Year, '15'), '%m %Y %d')

# Plotting type #3 on a monthly scale 
ggplot(monthlyAGWO, aes(x=date, y=AGWO)) + geom_line(aes(col = 'blue')) + geom_line(data = monthlySummer, aes(x=date, y=AGWO, group = Year, col = 'red')) + labs(x='Date', y= 'Baseflow (cfs/sq mi)') + 
  ggtitle('Summer baseflow') +
  scale_color_identity(name = NULL, breaks=c('red','blue'), labels = c('Summer months','Rest of Year'), guide = 'legend') +
  theme(legend.position = c(.85,.9))

# Manipulating data to graph
pwater$sum <- pwater$AGWO+pwater$IFWO+pwater$SURO
pwater$sum_ <- pwater$sum*convert_cfs_sqm         
monthlySum <- aggregate(pwater$sum_, by = list(pwater$month, pwater$year), FUN = 'mean')
colnames(monthlySum) <- c('month','year','sum')
monthlySum$date <- monthlyAGWO$date
monthlyAGWO$sum <- monthlySum$sum

# Plotting AGWO and sum of runoff, interflow, and baseflow on the same graph
plot(monthlyAGWO$date, monthlyAGWO$AGWO, type = 'l', col = 'blue', ylim = c(0,7.25), xlab = NA, ylab = 'Flow (cfs/sq mi)')
lines(monthlyAGWO$date, monthlyAGWO$sum, type ='l', col = 'red')
legend(x = 4800,y = 7.25, legend = c('Total outflow', 'Baseflow'), fill = c('red','blue'))
title(main = 'Baseflow vs total outflow to river segment', sub = 'Total outflow represents the sum of runoff, interflow, and baseflow')

# Plotting all variables contributing to the total outflow 
# First need to add all variables to monthly table 
monthlySURO <- aggregate(pwater$SURO, by = list(pwater$month, pwater$year), FUN = 'mean')
colnames(monthlySURO) <- c('month','year','SURO')
monthlySURO$SURO_ <- monthlySURO$SURO*convert_cfs_sqm # the SURO_ column is in units of cfs/sq mi
monthlyIFWO <- aggregate(pwater$IFWO, by = list(pwater$month, pwater$year), FUN = 'mean')
colnames(monthlyIFWO) <- c('month','year','IFWO')
monthlyIFWO$IFWO_ <- monthlyIFWO$IFWO*convert_cfs_sqm # the IFWO_ column is in units of cfs/sq mi
monthlyAGWO$SURO <- monthlySURO$SURO_
monthlyAGWO$IFWO <- monthlyIFWO$IFWO_

ggplot(monthlyAGWO, aes(date, AGWO)) + geom_line(aes(col = 'blue'))  + 
  geom_line(aes(y=SURO, col = 'red')) +
  geom_line(aes(y=IFWO, col = 'dark green')) +
  labs (x = NULL, y = 'Flow (cfs/sq mi)') + 
  ggtitle('Elements of total outflow to the river segment ') +
   scale_color_identity(name = NULL, breaks=c('red','dark green','blue'), labels = c('Runoff', 'Interflow', 'Baseflow'), guide = 'legend') +
  theme(legend.position = c(.75,.85))

#Finding a linear regression for baseflow over time 
AGWOlm <- lm(AGWO~date, data = dailyAGWO_) # Daily averages 
summary(AGWOlm) # Value in Estimate column and date row represents slope 
# Values for slope from daily and monthly linear regressions were found to be  very similar 

# Finding 90 day low flow values 
dailySum <- aggregate(pwater$sum_, by = list(pwater$date), FUN = 'mean')
colnames(dailySum) <- c('date','sum')
dailyAGWO_$sum <- dailySum$sum
dailyAGWOz <- zoo(dailyAGWO_$AGWO, order.by = dailyAGWO_$date)
dailySumz <- zoo(dailyAGWO_$sum, order.by = dailyAGWO_$date)
sum_g2 <- data.frame(group2(dailySumz))
l90_Runit <- min(sum_g2$X90.Day.Min)
AGWO_g2 <- data.frame(group2(dailyAGWOz))
l90_agwo_Runit <- min(AGWO_g2$X90.Day.Min)

l90_table <- matrix(nrow =2, ncol = 2)
l90_table[,2] <- c(l90_Runit,l90_agwo_Runit)
l90_table[,1] <- c('l90_Runit','l90_agwo_Runit')
l90_table
