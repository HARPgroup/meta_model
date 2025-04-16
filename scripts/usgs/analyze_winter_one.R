# config.local.private sets: lib_directory, auth_directory, base_url, file_directory
# if running in RStudio this will not work as it forces path to the "working directory"
# Must open and run contents of config.local.private once per session
basepath='/var/www/R';
source("/var/www/R/config.R");
save_directory = "/media/model/usgs/mllr"
## Code to calculate the current drought condition estimates and create a graph to show all estimates by month and threshold
# This code will be updated using "chron" every March 1st
# Load necessary libraries
suppressPackageStartupMessages(library('zoo'))
suppressPackageStartupMessages(library('IHA'))
suppressPackageStartupMessages(library('stringr'))
suppressPackageStartupMessages(library('lubridate'))
suppressPackageStartupMessages(library('ggplot2'))
suppressPackageStartupMessages(library('scales'))
suppressPackageStartupMessages(library('httr'))
suppressPackageStartupMessages(library("hydrotools"))
#gage_feature$hydroid needed for retrieving beta properties via REST
#gage_feature$hydroid <- 58567
#
#target_year=2018
#gage <- c(01634000)
# authenticate

# Excpects:
# gage: usgs id
# target_year: recharge period ending year, i.e. 11/2020 to 3/2021 is 2021
# (unused, retrieved from system) gage_feature$hydroid: feature hydroid

# argst=c('01634000',1,2025)
argst <- commandArgs(trailingOnly=T)
overwrite_file = FALSE
target_year <- year(Sys.time())
message(paste("length of argst = ", length(argst)))
if (length(argst) < 1) {
  message(paste("Use: analyze_winter_one.R gage [year=", target_year,"] [save_directory=/media/model/usgs/mllr]"))
}
if (length(argst) > 0) {
  gage <- as.character(argst[1])
  gage <- sprintf("%08s", gage)
  if (length(argst) > 1) {
    overwrite_file <- as.logical(as.integer(argst[2]))
  }
  if (length(argst) > 2) {
    target_year = argst[3]
  }
}

# override the file save directory
file_directory = '/var/www/html/images/dh';
message(paste("Generating MLLR images for a set of", gage))
gage_hydrocode = paste0('usgs_', gage)
gage_feature <- RomFeature$new(ds, list(hydrocode = gage_hydrocode, bundle = 'usgsgage'), TRUE)
# Saving file to the correct location
filename <- paste("usgs", gage, "mllr_bar_winterflows", target_year, ".png", sep="_")
filepath <- paste(file_directory, filename, sep="/")
if (overwrite_file) {
  message("Overwrite Force call")
}
if (file.exists(filepath) & !overwrite_file) {
  # check in case the file is out of date, in which case overwrite it anyhow
  linfo = file.info(filepath)
  if (as.Date(linfo$mtime) > as.Date(paste0(target_year, '-03-01'),origin="America/New_York")) {
    message(paste( gage, "is up to date as of ",as.Date(linfo$mtime)  ))
    message("*********** SKIPPING ************* ")
    next
  } else {
    message(paste("File is out of date",as.Date(linfo$mtime) ))
  }
}

# Initialize variables
n_f_flow <- c()
year <- year(Sys.Date())
most_recent = -99999;
message(paste("Trying to retrieve data for gage", gage))
# Read flow for entire record to gather all historical flow data
historic <- dataRetrieval::readNWISdv(gage,'00060')
historic$mo <- month(historic$Date)
historic$yr <- year(historic$Date)
# Continuing with no data available
if (class(historic)=="try-error") {
  message(paste("NWIS Responded NO DATA for", gage, sep=''));
  q()
}
# Remove gages that don't even have a column for flow data on USGS
if (ncol(historic) < 4) {
  message(paste("NWIS Responded NO DATA for", gage, sep=''));
  q()
}

# Find first and last date on record
start.date <- as.Date(min(as.Date(as.character(historic$Date), origin="1970-01-01")))
end.date <- as.Date(max(as.Date(as.character(historic$Date), origin="1970-01-01")))

# Makes the StartDate the earliest year with November on record
if (start.date > as.Date(paste(year(start.date), '-11-01', sep=""), origin="1970-01-01")) {
	year <- year(start.date) + 1
} else { year <- year(start.date) }


# Iterate for all of the years in the gage's dataset
for (z in 1:(year(end.date)-year)) {

	StartDate <- as.Date(paste(year, "-11-01", sep=""))
	EndDate <- as.Date(paste((year+1), "-02-28", sep=""))

	# Extract flow data for the specified year from Nov - Feb (gathering all historic winter flows)
	f <- historic[,4][(as.Date(historic$Date)>=StartDate) & (as.Date(historic$Date)<=EndDate)]

	# Determine the average November through February mean daily flow
	n_f_flow[z] <- mean(na.omit(as.numeric(as.vector(f))))
	if ((year + 1) == target_year) {
	  most_recent <- round(tail(na.omit(n_f_flow), n=1), digits=0) # the target year's average winter flow
	}
	year <- year + 1
}

Qmedian <- round(median(na.omit(n_f_flow)), digits=0) # the median winter flow for the entire record
message(paste("Found ", most_recent, "cfs compared to long term median of ", Qmedian, sep=''));
# set up data frame for the most recent and median winter flow values
names <- c(paste(target_year," Winter Flow",sep=""), "Median Winter Flow")
if (most_recent != -99999) {
  values <- c(most_recent, Qmedian)
} else {
  values <- c(Qmedian, Qmedian)
}
lines <- data.frame(names, values)

plot_xtitle <- "Winter Flow, cfs"
plot_xsubtitle <- paste(
  "Mean flows from November to February of each year on record ",
  "(Updated ", Sys.Date(), ")", sep=""
);

# ******************************************************************************************
# Plot 1: Create histogram/density plot to show recent winter flow vs historic winter flows
# ******************************************************************************************
plt <- ggplot() +
  # plot the histogram
  geom_histogram(aes(x=n_f_flow), colour="black", fill = "lightblue",bins = 30) +

  # plot the lines at the most recent and median winter flows
  geom_vline(data=lines, aes(xintercept=values, color=names), linetype="longdash", linewidth=1, show.legend=TRUE) +

  # Y scale showing only integers
  scale_y_continuous(breaks= pretty_breaks()) +

  # customize the legend
  scale_color_manual(
    values=c("#CC6666", "#666666"),
    labels=c(paste(target_year, " Winter Flow =", most_recent, "cfs"), paste("Median Winter Flow =", Qmedian, "cfs")),
    name="") +
  theme(legend.position="bottom") +
  guides(color=guide_legend(ncol=2)) +

  # specify labels and title for the graph
  xlab(bquote(atop(.(plot_xtitle), italic(.(plot_xsubtitle), "")))) + ylab("Number of Winters") +
  ggtitle(paste("Distribution of Historic Winter Flows for", gage))
# ******************************************************************************************
# End Plot 1
# ******************************************************************************************
#--------------------------------------------------------------------------
# ******************************************************************************************
# Table 1: Retreive the table of MLLR coefficients
# ******************************************************************************************
#Retrieve b0 and b1 properties
month <- c('july','august','september')


beta_table <- data.frame('metric'=character(),
                         'b0'=character(),
                         'b1'=character(),
                         stringsAsFactors=FALSE)

#m <- 1
valid_months <- list(
  'july' = FALSE,
  'august' = FALSE,
  'september' = FALSE
)
for (m in 1:length(month)) {
  message(paste("Getting betas for", gage, "(hydroid=",gage_feature$hydroid,")", month[m]))
  #retrieve b0 property
  b0_inputs <- list(featureid = gage_feature$hydroid,varkey = paste('mllr_beta0_',month[m],'_10',sep=''),entity_type = 'dh_feature')

  # don't include the path here since rest properties may not always be singular by name
  b0 <- RomProperty$new(
    ds, b0_inputs,TRUE
  )
  if (is.logical(b0)) {
    message(paste("Gage", gage,"does not have valid b0 for", month(m)))
    b0 <- list(propvalue = NULL)
  }
  b0 <- as.numeric(as.character(b0$propvalue))

  #retrieve b1 property
  b1_inputs <- list(featureid = gage_feature$hydroid,varkey = paste('mllr_beta1_',month[m],'_10',sep=''),entity_type = 'dh_feature')
  b1 <- RomProperty$new(
    ds, b1_inputs,TRUE
  )
  if (is.logical(b1)) {
    message(paste("Gage", gage,"does not have valid b1 for", month(m)))
    b1 <- list(propvalue = NULL)
  }
  b1 <- as.numeric(as.character(b1$propvalue))

  if (length(b0) && length(b1)) {
	  print(paste("b0: ",b0,sep=""))
	  print(paste("b1: ",b1,sep=""))
	  valid_months[m] = TRUE;
	  beta_table_i <- data.frame(month[m],b0,b1)
	  beta_table <- rbind(beta_table, beta_table_i)
  } else {
    print(paste("Cannot calculate for month ", month[m], " with beta0 = ", b0," and beta1= ", b1, sep=""));
    valid_months[m] = FALSE;
  }
}
#--------------------------------------------------------------------------
# ******************************************************************************************
# END Table 1
# ******************************************************************************************
# Output the beta_table
message(beta_table)

# ******************************************************************************************
# Plot 2: Plot the equation of MLLR on graph to illustrate intersection of flow & prob
# ******************************************************************************************
#Add MLLR Curves to Plot
P_est <- function(b0, b1, x) {1/(1+exp(-(b0 + b1*x)))}

#remove any rows with "Ice" values for locating maximum historic flow value
if (length(which(historic[,4]== "Ice")) != 0 ){

  historic_no_ice <- historic[-which(historic[,4]== "Ice"),]
} else {
  historic_no_ice <- historic
}

#need to determine x-range to use for plotting mllr curves, currently set to go from zero to 95th percentile flow
#will cause number of histogram bins to be different than they were before
xmax <- as.numeric(as.character(quantile(as.numeric(as.character(historic_no_ice[,4])),0.95, na.rm=TRUE)))
x <- c(0:xmax)

# **************************************
# BEGIN - Handle NULLs
# Set default to assume no
# **************************************
labs = c(
  paste(target_year, " Winter Flow =", most_recent, "cfs"),
  paste("Median Winter Flow =", Qmedian, "cfs"),
  "July (undefined)",
  "August (undefined)",
  "September (undefined)"
)
# create a placeholder with the same number of values
no_line = P_est(0,0,x);
# set all values to 0.0
no_line[] = 0;
july_est <- no_line
august_est <- no_line
september_est <- no_line
# **************************************
# END - HANDLE NULLs
# **************************************

#add each month's P_est to plot
if (valid_months['july'] == TRUE) {
  july_est <- (P_est(beta_table[which(beta_table$month.m == "july"),"b0"], beta_table[which(beta_table$month.m == "july"),"b1"], x))*10
  labs[3] = "July 10th %ile"
}
if (valid_months['august'] == TRUE) {
  august_est <- (P_est(beta_table[which(beta_table$month.m == "august"),"b0"], beta_table[which(beta_table$month.m == "august"),"b1"], x))*10
  labs[4] = "August 10th %ile"
}
if (valid_months['september'] == TRUE) {
  september_est <- (P_est(beta_table[which(beta_table$month.m == "september"),"b0"], beta_table[which(beta_table$month.m == "september"),"b1"], x))*10
  labs[5] = "September 10th %ile"
}

message(valid_months);
message(july_est);
message(august_est);
message(september_est);
# put x and ys into a data frame for plotting
july_mllr <- data.frame(x,(july_est))
august_mllr <- data.frame(x,(august_est))
september_mllr <- data.frame(x,(september_est))

# Now Add the lines
plt<-plt+geom_line(
  data=july_mllr,
  aes(x=x,y=july_est,color="red"),
  show.legend = FALSE
)
plt<-plt+geom_line(
  data=august_mllr,
  aes(x=x,y=august_est,color="red1"),
  show.legend = FALSE
)
plt<-plt+geom_line(
  data=september_mllr,
  aes(x=x,y=september_est,color="red2"),
  show.legend = FALSE
)

plt<-plt+scale_color_manual(
  values=c("#CC6666", "#666666","seagreen4","blue","orangered3"),
  labels=labs,
  name=""
)

#add secondary y-axis to plot
plt<-plt+scale_y_continuous(sec.axis = sec_axis(~./0.1, name = "Probability Estimate"),breaks= pretty_breaks())

# ******************************************************************************************
# END Plot 2
# ******************************************************************************************
# END plotting function
# get timeseries value
ggsave(file=filename, path = file_directory , width=6, height=6)
# save this as a property
furl <- paste(
  '/images/dh',
  filename,
  sep='/'
)
message(paste("Saved file: ", filename, " in ", file_directory, "with URL", furl))
# todo: stash properties and timeseries
# get the current years 10%
# this calc fails if there si no flow for this gage, so screen it.
if (most_recent >= 0) {
  target_jul_10 <- P_est(
    beta_table[which(beta_table$month.m == "july"),"b0"],
    beta_table[which(beta_table$month.m == "july"),"b1"],
    most_recent)
  target_aug_10 <- P_est(
    beta_table[which(beta_table$month.m == "august"),"b0"],
    beta_table[which(beta_table$month.m == "august"),"b1"],
    most_recent)
  target_sep_10 <- P_est(
    beta_table[which(beta_table$month.m == "september"),"b0"],
    beta_table[which(beta_table$month.m == "september"),"b1"],
    most_recent)
  # find the month with the highest value
  target_mllr <- max(c(target_jul_10, target_aug_10, target_sep_10))
  tmo <- (c(target_jul_10, target_aug_10, target_sep_10) == target_mllr)
  # handle NA when a month is missing, i.e., has no b0/b1 and no value
  tmo[is.na(tmo)] <- FALSE
  target_month <- as.character(c('mllr_july_10', 'mllr_august_10', 'mllr_september_10')[tmo])

  # - stash a timeseries for the year using generic drought_status_mllr
  # - TBD: set tsvalue to max 10% val for site per dh_drought/src/sql/mllr-table.sql
  # - attach a property to this timeseries rec to hold pointer to image
  # q_nov_feb_mean_cfs, drought_status_mllr
  config_list = list(
    "featureid" = gage_feature$hydroid,
    "entity_type" = 'dh_feature',
    "varkey" = 'mllr_annual_risk10',
    "tstime" =  as.numeric(as.POSIXct(paste(target_year, "-03-01", sep=""),tz="America/New_York"))
  )
  ts <- RomTS$new(
    ds,
    config_list,
    TRUE
  )
  ts$tsvalue = target_mllr
  ts$tscode = target_month
  ts$save(TRUE)
}

# don't include the path here since rest properties may not always be singular by name
img_prop <- RomProperty$new(
  ds, list(
    propname="mllr_plot", entity_type="dh_timeseries",
    featureid=ts$tid, varkey = 'dh_image_file',
    bundle='dh_properties'
  ),TRUE
)
# now add the image
img_prop$propcode <- furl
img_prop$save(TRUE)

fw_historic <- sqldf(
  "select yr, mo, avg(X_00060_00003) as flow, 
     CASE 
       WHEN mo = 11 THEN 1 
       WHEN mo = 12 THEN 2 
       WHEN mo = 1 THEN 3 
       WHEN mo = 2 THEN 4 
     END as mo_index 
   from historic 
   where mo in (11,12,1,2)
   group by mo, mo_index, yr
   order by yr, mo_index
  "
)
ty = target_year
fw_target <- fn$sqldf(
  "select yr, mo, mo_index, flow
   from fw_historic 
   where (yr = ($ty -1) and mo in (11,12))
     OR (yr = $ty and mo in (1,2))
   order by mo_index
  "
)
fw_max = quantile(fw_historic$flow,probs=c(0.95))[1]

# Runoff boxplot
fname <- paste0(
  'recharge_context_', gage, '_',
  target_year, '.png'
)
fpath <-  paste(
  save_directory,
  fname,
  sep='/'
)
furl <- paste(
  str_replace(fpath,'/media/model', omsite),
  sep='/'
)
png(fpath)

boxplot(
  fw_historic$flow ~ fw_historic$mo_index, 
  ylim=c(0,fw_max), xaxt = "n", xlab="Month", ylab="Flow (cfs)",
  main=paste("Mean Flow",target_year,"\n vs. Hist. Monthly Mean \n USGS",gage)
)
axis(1, at = c(1,2,3,4),
     labels = c("Nov", "Dec", "Jan", "Feb"))
points(
  fw_target$flow ~ fw_target$mo_index, 
  pch=5, cex=2, lwd=3, add=TRUE, col="blue"
)
legend("topleft", cex=0.75, pch=c(5,1), legend=c("Hist",target_year))

dev.off()

# don't include the path here since rest properties may not always be singular by name
img_prop <- RomProperty$new(
  ds, list(
    propname="context_plot", entity_type="dh_timeseries",
    featureid=ts$tid, varkey = 'dh_image_file',
    bundle='dh_properties'
  ),TRUE
)
# now add the image
img_prop$propcode <- furl
img_prop$save(TRUE)
