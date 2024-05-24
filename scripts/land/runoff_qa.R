# this attempts to summarize the general runoff characteristics
# i.e., non-landuse specific. 
# This is under development i.e. not yet functioning.
library(sqldf)
library(lubridate)
site <- "http://deq2.bse.vt.edu/d.dh"    #Specify the site of interest, either d.bet OR d.dh
#----------------------------------------------
# Load Libraries
basepath='/var/www/R';
source(paste(basepath,'config.R',sep='/'))
save_directory <-  "/var/www/html/data/proj3/out"
library(hydrotools)
# authenticate new way
ds <- RomDataSource$new(site, rest_uname)
ds$get_token(rest_pw)

datapath = "http://deq1.bse.vt.edu:81/p6/out/land/drought/eos/N51165_0111-0211-0411.csv"
datapath = "/media/model/p6/out/land/drought/eos/N51165_0111-0211-0411.csv"

dat <- read.table(datapath, sep=",", header=TRUE)
datanames <- names(dat[,-1])
sumstr <- FALSE
for (i in datanames) {
  if (is.logical(sumstr)) {
    sumstr <- i
  } else {
    sumstr <- paste(sumstr, i, sep="+")
  }
}

sdata <- sqldf(
  paste(
    "select thisdate,", sumstr, "as sumall
    from dat
    order by thisdate
    "
  )
)
sdata$year <- year(sdata$thisdate)
sdata$month <- year(sdata$thisdate)
sdata$month <- month(sdata$thisdate)
sdata$day <- day(sdata$thisdate)
ssdat <- sqldf(
  "
    select year, month, day, sum(sumall) as tsvalue 
    from sdata
    group by year, month, day
  "
)

sydat <- sqldf(
  "
    select year, min(sumall), max(sumall), sum(sumall) as tsvalue 
    from sdata
    group by year
  "
)

odat <- om_get_rundata(240537, 901, site=omsite)
dodat <- as.data.frame(odat)
sqldf("select year, avg(Qout) from dodat group by year order by year")



