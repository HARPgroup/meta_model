# Plot out the various components of stored underground water
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(zoo))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(stats))
suppressPackageStartupMessages(library(R.utils))

# Get arguments (or supply defaults)
argst <- commandArgs(trailingOnly=T)
if (length(argst) == 8) {
# Accepting command arguments:
  lseg_name <- argst[1]
  scenario_name <- argst[2]
  landuse <- as.character(argst[3]) # don't need quotes around landuse argument anymore
  pwater_file <- argst[4] 
  image_path <- argst[5] 
  model_version <- argst[6]
  lseg_ftype <- argst[7]
  image_url <- argst[8]
} else {
  message("Use: Rscript aglzuz_storage.R land_segment_name scenario_name landuse pwater_file image_path model_version lseg_ftype image_url")
  q()
}


# Set up our data source
basepath='/var/www/R';
source("/var/www/R/config.R") # will need file in same folder/directory

# TBD: get inputs from the comand line
#  For now we just load some samples

landseg<- RomFeature$new(
  ds,
  list(
    hydrocode=lseg_name, 
    ftype=lseg_ftype,
    bundle='landunit'
  ), 
  TRUE
)

model <- RomProperty$new(
  ds,
  list(
    featureid=landseg$hydroid, 
    entity_type="dh_feature", 
    propcode=model_version
  ), 
  TRUE
)
model$save(TRUE)
if (is.na(model$pid)) {
  model$propname = landseg$name
  model$varid = ds$get_vardef('om_model_element')$varid
  model$save(TRUE)
}


model_scenario <- RomProperty$new( #Re-ordered scenario to be within the model element and the land use within the scenario
  ds,
  list(
    varkey="om_scenario", 
    featureid=model$pid, 
    entity_type="dh_properties", 
    propname=scenario_name, 
    propcode=scenario_name 
  ), 
  TRUE
)
model_scenario$save(TRUE)

lu <- RomProperty$new(
  ds,
  list(
    varkey="om_hspf_landuse", 
    propname=landuse,
    featureid=model_scenario$pid, 
    entity_type="dh_properties", 
    propcode=landuse 
  ), 
  TRUE
)
lu$save(TRUE)


# Test:
# pwater_file = "http://deq1.bse.vt.edu:81/p6/out/land/subsheds/pwater/forN51101_pwater.csv"

pwater <- fread(pwater_file)

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

years <- seq(min(pwater$year),max(pwater$year),1)

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
  ggtitle(paste('Groundwater storage for',lseg_name)) +
  scale_fill_identity(name =NULL, breaks=c('green','red','blue'), labels = c('Active groundwater','Upper zone','Lower zone'), guide = 'legend') +
  theme(legend.position = c(.9,.99))

ggsave(image_path)
# attach this to the lu property
message(paste("saving fig.aglzuz at",image_url,"to pid", lu$pid))
vahydro_post_metric_to_scenprop(lu$pid, 'dh_image_file', image_url, 'fig.aglzuz', NULL, ds)
