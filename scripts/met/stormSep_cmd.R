#Input variables are:
# 1 = The path to the USGS gage data downloaded in a previous step of geo
# 2 = allMinimaStorms = Considers ALL local minima as potnetial storm endpoints.
# Will distinguish between peaks in the case of a multi-day storm hydrograph if
# set to TRUE. Otherwise, a storm is only considered as two subseuqnet local
# minima that fall below baseline flow
# 3 = baselineFlowOption = One of c("Water Year","Month","Calendar Year","Climate Year","All").
# Defaults to "All". Determines how program will develop baseline flow. Uses
# horizontal line regression of baseflow and breaks it down based on all time,
# 4 = water year, calendar year, or month based on user selection
# 5 = pathToWrite = the path to write out csv output files to 

print("Calling stormSep_cmd.R")
#Call packages required by function if not called already:
library(grwat)
library(zoo)
library(sqldf)
print("Setting arguments")
#Get all arguments explicitly passed in from command line:
args <- commandArgs(trailingOnly = TRUE)
#Read in the USGS gage data:
usgsGage <- read.csv(args[1],stringsAsFactors = FALSE)

#Set variables required by script:
timeIn <- as.Date(usgsGage$Date)
inflow <- usgsGage$X_00060_00003
allMinimaStorms <- as.logical(args[2])
baselineFlowOption <- args[3]
pathToWrite <- args[4]

#Below function hreg (horizontal regression) will try to fit mulitple
#horizontal lines through subset of data involving every point below that line
#until best fit is found. This becomes baseline flow, brk
hreg <- function(x, limit = 1){
  #What is the numeric percentile of x that is of percent limit?
  lim <- as.numeric(quantile(x,limit))
  #Give all of x below the percentile of limit:
  x <- x[x <= lim]
  #Get all percentiles of x from 0 to 100% by 0.1%:
  lns <- as.numeric(quantile(x, seq(0,1,0.001)))
  #Keep only values above 0
  lns <- lns[lns != 0]
  #A vector for mean square error
  mse <- numeric(length(lns))
  #For each values in lns, determine the mean square error if this is a
  #horizontal regression of the data in x
  for (i in 1:length(lns)){
    line <- lns[i]
    mse[i] <- mean((x - line)^2)
  }
  #Return the percentile x that created the minimum least square error:
  return(lns[which.min(mse)])
}

print("Finding baseflow and local mins/maxes")
#First, get baseflow associated with inflow. Use defaults of grwat for now
#which involves three passes and the Lyne-Hollick (1979) hydrograph separation
#method with coefficient a as 0.925
baseQ <- grwat::gr_baseflow(inflow)

#Add timestamp to the baseflow separation for convenience by creating a
#dataframe
baseQ <- data.frame(timestamp = timeIn, Year = as.numeric(format(timeIn,"%Y")),
                    baseQ = baseQ,flow = inflow,gageID = usgsGage$site_no[1])

#Find mins/maxes of three consecutive points such that the extreme is in the
#middle. These represent potential local mins and maxes
maxes <- rollapply(baseQ$flow,3,function(x) which.max(x) == 2,# & (x[2]!=x[1] & x[2]!= x[3]),
                   align = "left")
mins <- rollapply(baseQ$flow,3,function(x) which.min(x) == 2,# & (x[2]!=x[1] & x[2]!= x[3]),
                  align = "left")
#Create data frames of these local minima/maxima with the corresponding
#timestamp from the original data frame. Note that the rolling looks at the
#first three data points. If the first triplet has a local max as its second
#value, the first value in maxes will be TRUE.The timestamp to be associated
#with this should be that of the middle data point e.g. the second timestamp
#of the triplet!
mins <- data.frame(timestamp = baseQ$timestamp[c(FALSE,mins,FALSE)],
                   mins = baseQ$flow[c(FALSE,mins,FALSE)])
maxes <- data.frame(timestamp = baseQ$timestamp[c(FALSE,maxes,FALSE)],
                    maxes = baseQ$flow[c(FALSE,maxes,FALSE)])

#Need to find mins/maxes below baseline flow. But first baseline flow must be
#defined. hreg() will try to fit mulitple horizontal lines through subset of
#data involving every point below that line until best fit is found. This
#becomes baseline flow, brk
#Find the break associated with this run and buffer by 10%. Based the hreg on
#the timescale selected by the user
# baselineFlowOption = One of c("Water Year","Month","Calendar Year","All")
print("Setting baseline flow")
if(baselineFlowOption == "All"){
  #Use the entire baseflow dataset to get baseline flow, brk
  brk <- hreg(baseQ$baseQ,limit = 1)
  brk <- brk * 1.1
  #Make as long as timeseries
  brk <- rep(brk,nrow(baseQ))
}else if(baselineFlowOption %in% c("Calendar Year", "Climate Year","Water Year")){
  #Based on the user option, determine the start month of the year
  #designation. Water Years run from October - September, Climate years from
  #April - March, and Calendar Years from January - December
  if(baselineFlowOption == "Water Year"){
    WYS <- "10-01"
  }else if(baselineFlowOption == "Climate Year"){
    WYS <- "04-01"
  }else{
    WYS <- "01-01"
  }
  #Make dates of the input timesteps:
  dataDates <- as.Date(timeIn)
  #Create an emtpty vector for the new annual designations
  dataWY <- NA
  
  #Identify months in the next year that are classified as the previous year's
  #water/climate year e.g. January 2021 is in Water Year 2020 that begins in
  #October. Get the month using gsub to get only the characters prior to first
  #dash
  WYM <- as.numeric(gsub("-.*","",WYS))
  if(WYM > 1){
    WYP <- seq(1,(WYM - 1))
  }else{
    WYP <- 0
  }
  
  #Add leading zeros to month number January - September
  WYP[nchar(WYP) == 1]<-paste0("0",WYP[nchar(WYP) == 1])
  #Combine to form a regex pattern that searches for any of the months at the
  #END of a string ($)
  WYP <- paste0(WYP,"$",collapse = "|")
  #Get the year and month associated with the dates
  WY <- format(dataDates,"%Y-%m")
  
  #Initialize water year by making it the calendar year + 1
  dataWY <- as.numeric(gsub("-.*","",WY)) + 1
  
  #Search for all months from January to the start of the water year. These
  #months need to be assigned previous water year number (current calendar
  #year)
  dataWY[grepl(WYP,WY)] <- dataWY[grepl(WYP,WY)] - 1
  
  #Exception case occurs when water year is calendar year, in which case water
  #year ends in calendar year such that calendar year = water year
  if(WYS == "01-01"){
    dataWY <- as.numeric(format(dataDates,"%Y"))
  }
  #Store the years in the appropriate column in baseQ data frame
  baseQ$Year <- dataWY
  #Create an empty vector the length of the baseQ data frame
  brk <- numeric(nrow(baseQ))
  #For each unique water year, calendar year, etc., run the hreg and store in
  #brk
  for (i in unique(dataWY)){
    baseQsubset <- baseQ[baseQ$Year == i,]
    #Use the subset of the baseflow dataset to get baseline flow, brk
    brki <- hreg(baseQsubset$baseQ,limit = 1)
    brki <- brki * 1.1
    #Store results
    brk[baseQ$Year == i] <- brki
  }
}else if(baselineFlowOption == "Month"){
  #Make dates of the input timesteps:
  dataDates <- as.Date(timeIn)
  
  #Create a vector of the months and years, essentially getting a vector of
  #all months in the timeIn vector
  monthYears <- format(dataDates,"%m-%Y")
  
  #Create an empty vector the length of the baseQ data frame
  brk <- numeric(nrow(baseQ))
  for (i in unique(monthYears)){
    baseQsubset <- baseQ[monthYears == i,]
    #Use the subset of the baseflow dataset to get baseline flow, brk
    brki <- hreg(baseQsubset$baseQ,limit = 1)
    brki <- brki * 1.1
    #Store results
    brk[monthYears == i] <- brki
  }
}
#Add baseline flow to baseQ
baseQ$baselineQ <- brk

#Next step is to isolate storms. This can be accomplished by taking a minimum
#and the next point to fall below baseline flow, brk. Each storm is checked to
#ensure a maximum above some reference level, here 1.5*brk. This eliminates
#small storms with little or no peak or rises in baseflow. Only minimums below
#the brk value are considered as these are storms that occur at baseflow and
#fully rise/recede.
print("Setting storm hydrograph thresholds")
#Get the times associated with minimums that are below baseline flow brk.
#First, join in the baseline flow for the timeperiod:
mins <- sqldf("SELECT mins.*, baseQ.baselineQ
        FROM mins 
        LEFT JOIN baseQ
        ON mins.timestamp = baseQ.timestamp")

if(allMinimaStorms){
  #Use all minima as potential storm start and stop points
  x <- mins$timestamp
  #Get the corresponding local maximums
  y <- maxes$maxes
}else{
  #Get only the minima timestamps that lie below baseline flow
  x <- mins$timestamp[mins$mins < mins$baselineQ]
  #Get the corresponding local maximums
  y <- maxes$maxes[mins$mins < mins$baselineQ]
}

#A data frame to build with storms in each column
stormsep <- list()
#An ID column to store the storm number in baseQ
baseQ$stormID <- NA

#Start evaluating each set of minima to evaluate if there is a qualifying
#storm event. If there is, store it with all relevant data
print(paste0("Evaluating ",length(x)," potential storms"))
for (i in 1:(length(x) - 1)){
  # if(i==73){browser()}
  endIndex <- 1
  #Initial guess at storm endpoints e.g. two local minimums
  storm <- c(x[i], x[i + endIndex])
  #initial stormflows and the times associated with those flows:
  stormflow <- inflow[timeIn >= storm[1] & timeIn <= storm[2]]
  
  #When using allMinimaStorms, some minima may be combined. Skip loops that
  #feature combined storms. So, if at frist storm and nextStorm are January
  #1st - Jan 10 and Jan 10 - Jan 12, but these are combined into one (Jan 1 -
  #Jan 12), then we can skip the loop of Jan 10 - Jan 12. First, make sure
  #there is a storm in stormsep and that this is not the first loop i.e. i !=
  #1
  if(i > 1 && length(stormsep) > 0){
    #Get the previous storm
    prevStorm <- stormsep[[length(stormsep)]]
    #Remove the NAs so we only have the timestamps associated with the current
    #storm
    prevStorm <- prevStorm[!is.na(prevStorm$flow),]
    #If the end point of the storm is in the previous storm, skip this
    #iteration. This storm has already been accounted for.
    if(storm[2] %in% prevStorm$timestamp){
      #Skip to next iteration of for loop:
      next
    }
  }
  
  #If the second minimum flow is practically equal to the next local maximum,
  #combine with the next storm as they are likely of the same storm (of
  #course, this assumes that the timestamps match up which they should in the
  #current set-up regardless of allMinimaStorms). But only do this if
  #allMinimaStorms is TRUE since otherwise baselineflow is the cut-off.
  if(allMinimaStorms & !is.na(x[i + 1 + endIndex])){
    #Initial guess at storm endpoints e.g. two local minimums
    nextStorm <- c(x[i + 1], x[i + 1 + endIndex])
    #initial stormflows and the times associated with those flows:
    nextStormflow <- inflow[timeIn >= nextStorm[1] & timeIn <= nextStorm[2]]
    #What is the maximum of this storm event?
    nextMaxStormFlow <- max(nextStormflow)
    
    while(!is.na(nextMaxStormFlow) & 
          stormflow[length(stormflow)] >= 0.8 * nextMaxStormFlow){
      endIndex <- endIndex + 1
      #Initial guess at storm endpoints e.g. two local minimums
      storm <- c(x[i], x[i + endIndex])
      #initial stormflows and the times associated with those flows:
      stormflow <- inflow[timeIn >= x[i] & timeIn <= x[i + endIndex]]
      
      if(!is.na(x[i + 1 + endIndex])){
        #Initial guess at storm endpoints e.g. two local minimums
        nextStorm <- c(x[i + endIndex], x[i + 1 + endIndex])
        #initial stormflows and the times associated with those flows:
        nextStormflow <- inflow[timeIn >= nextStorm[1] & timeIn <= nextStorm[2]]
        #What is the maximum of this storm event?
        nextMaxStormFlow <- max(nextStormflow)
      }else{
        nextMaxStormFlow <- NA
      }
    }
  }
  
  #Get the times associated with the storm
  stormtimes <- timeIn[timeIn >= x[i] & timeIn <= x[i + endIndex]]
  
  #When does the maximum flow associated with this storm occur?
  maxtime <- stormtimes[stormflow == max(stormflow)][1]
  
  #If there is a point at baseflow before next minimum, use it instead to
  #prevent over elongated tails. We just need to ensure it takes place before
  #the next minima, is over brk, and occurs after maxtime
  endAlt <- (baseQ$timestamp[baseQ$flow < baseQ$baselineQ & 
                               baseQ$timestamp > x[i] & 
                               baseQ$timestamp < x[i + endIndex] & 
                               baseQ$timestamp > maxtime])[1]
  #If an alternate endpoint for the storm was found, redefine the storm:
  if (!is.na(endAlt)){
    storm <- c(x[i],endAlt)
    stormflow <- inflow[timeIn >= x[i] & timeIn <= endAlt]
    stormtimes <- timeIn[timeIn >= x[i] & timeIn <= endAlt]
  }
  #data frame of storm data
  stormdat <- data.frame(
    timestamp = stormtimes,
    baseQ = baseQ$baseQ[baseQ$timestamp >= storm[1] & baseQ$timestamp <= storm[2]],
    flow = stormflow,
    baselineQ = baseQ$baselineQ[baseQ$timestamp >= storm[1] & baseQ$timestamp <= storm[2]]
  )
  
  #data frame of whole time series
  store <- data.frame(timestamp = baseQ$timestamp, flow = NA,baseflow = NA)
  #Fills in only flow data during storm, leaving rest as NA
  store$flow[store$timestamp >= storm[1] & 
               store$timestamp <= storm[2]] <- stormdat$flow
  store$baseflow[store$timestamp >= storm[1] & 
                   store$timestamp <= storm[2]] <- stormdat$baseQ
  store$baselineflow[store$timestamp >= storm[1] & 
                       store$timestamp <= storm[2]] <- stormdat$baselineQ
  
  #If maximum exceeds limit, add it to the stormsep list:
  if(any(store$flow > (2.0 * store$baselineflow),na.rm = TRUE)){
    #Set the storm number in baseQ
    baseQ$stormID[baseQ$timestamp >= storm[1] & baseQ$timestamp <= storm[2]] <- length(stormsep) + 1
    
    stormsep[[length(stormsep) + 1]] <- store
  }
}
print(paste0(length(stormsep)," storms found. Writing data."))
#Write out the full flow data with the stormIDs to create a file from which the
#storms may easily be extracted
write.csv(baseQ,
          paste0(pathToWrite,"Gage",usgsGage$site_no[1],"_StormflowData.csv"),
          row.names = FALSE)
