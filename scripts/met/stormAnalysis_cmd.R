#Input variables are:
# 1 = The path to the storm separated data from step 02 for this gage
# pathToWrite = the path to write out csv output files to 

#WE MAY CONSIDER EVENTS AS BREAKS IN PRECIPIATION, PARTICULARLY FOR GAGES
#DOWNSTREAM WHERE WE MAY START TO SEE EVENTS BLENDING. WE MAY ALSO NEED TO LOOP
#IN DATA FROM DOWNSTREAM

#Call packages required by function if not called already:
library(zoo)
library(sqldf)
#Get all arguments explicitly passed in from command line:
args <- commandArgs(trailingOnly = TRUE)

print("Beginning storm analysis. Setting arguments")
#Read in the flow data that features an ID column to designate each storm event:
stormSepDF <- read.csv(args[1],stringsAsFactors = FALSE)

#Convert timestamps to date:
stormSepDF$timestamp <- as.Date(stormSepDF$timestamp)

#Get the vector of unique identifiers for each storm. This is tricky since some
#rows of this field may be NA (e.g. no storm) or may have multiple values for a
#storm that ends on the same day another storm begins. Below, we convert to
#numeric to coerce these multi-IDs to NA. We are only interested in the maximum
#ID, which will never overlap as it is the last storm on record:
stormID <- unique(as.numeric(stormSepDF$stormID))
#The IDs can be represented as a sequence of 1 to the maximum storm ID
stormID <- 1 : max(stormID,na.rm = TRUE)

#Additional arguments to determine if plots should be generated and where they
#should be written
pathToWrite <- args[2]

#Using a trapezoidal approach, get the area of each trapezoid to estimate
#volume of the storm.
trapzArea <- function(timeDiff,stormFlow){
  out <- timeDiff * ((stormFlow[1:(length(stormFlow) - 1)] + stormFlow[2:length(stormFlow)]) / 2)
}

#Store coefficients and statistics for each curve into a data frame,
#looking at shape of curve and the adjusted R square values. Store each storm as
#a PNG graph in the designated area. Need to prevent errors from zero flow.
#Added 0.0001 to all flow values. This WILL RESULT IN BIAS
#Empty data frame to store statistics
transients <- data.frame(ID = numeric(length(stormID)), 
                         startDate = character(length(stormID)),
                         endDate = NA, maxDate = NA,
                         rising = NA, risingInt = NA, RsqR = NA,
                         falling = NA, fallingInt = NA, RsqF = NA,
                         durAll = NA,durF = NA,durR = NA,
                         volumeTotalMG = NA,
                         volumeAboveBaseQMG = NA,
                         volumeAboveBaselineQMG = NA,
                         volumeTotalMG_rise = NA,
                         volumeAboveBaseQMG_rise = NA,
                         volumeAboveBaselineQMG_rise = NA,
                         volumeTotalMG_fall = NA,
                         volumeAboveBaseQMG_fall = NA,
                         volumeAboveBaselineQMG_fall = NA)
print(paste0("Evaluating ",length(stormID)," storms for statistics"))
for (i in 1:length(stormID)){
  #Find the storm of interest. Note that storms can overlap as stomrs were
  #identified via local minima. It is possible for two storms to share this
  #minima as the end date of the first storm and the start date of the second.
  #So, we need to find all cases in which stormID contains the whole number of
  #the stormID
  storm <- stormSepDF[grepl(paste0("(^",stormID[i],"$)|(^",
                                   stormID[i],",)|(,",
                                   stormID[i],"$)"), stormSepDF$stormID),]
  #remove nas:
  storm <- storm[!is.na(storm$flow),]
  
  #Set the ID of the storm
  transients$ID[i] <- stormID[i]
  
  #Look for where the max is
  maxtime <- storm$timestamp[storm$flow == max(storm$flow)][1]
  
  #Store the start and end time of the storm
  transients$startDate[i] <- format(storm$timestamp[1],"%Y-%m-%d")
  transients$endDate[i] <- format(storm$timestamp[nrow(storm)],"%Y-%m-%d")
  transients$maxDate[i] <- format(maxtime,"%Y-%m-%d")
  
  #Separate rising and falling limbs based on maxtime e.g. the rising limb is
  #all values leading up to maxtime
  rising <- storm[storm$timestamp <= maxtime,]
  falling <- storm[storm$timestamp >= maxtime,]
  
  #What is the volume of the storm streamflow i.e. total volume? First, get
  #the difference in timestamps throughout the storm from one time to the
  #next:
  timeDiff <- difftime(storm$timestamp[2:nrow(storm)], storm$timestamp[1:(nrow(storm) - 1)],
                       units = "secs")
  timeDiff <- as.numeric(timeDiff)
  #Repeat for rising and falling limbs only:
  #Rising:
  timeDiff_rise <- difftime(rising$timestamp[2:nrow(rising)], rising$timestamp[1:(nrow(rising) - 1)],
                            units = "secs")
  timeDiff_rise <- as.numeric(timeDiff_rise)
  #Falling:
  timeDiff_fall <- difftime(falling$timestamp[2:nrow(falling)], falling$timestamp[1:(nrow(falling) - 1)],
                            units = "secs")
  timeDiff_fall <- as.numeric(timeDiff_fall)
  #Get area "under the curve" of the storm flow.  Use three approaches. Total
  #storm volume, volume above baseflow, volume above baseline flow Total storm
  #flow:
  trapz_total <- trapzArea(timeDiff,storm$flow)
  #Only flow above baseflow:
  trapz_abovebaseQ <- trapzArea(timeDiff,(storm$flow - storm$baseQ))
  #Only flow above baseline flow. THIS CAN BE NEGATIVE AND THEREFORE
  #UNRELIABLE?:
  trapz_abovebaselineQ <- trapzArea(timeDiff,(storm$flow - storm$baselineQ))
  
  #Rising/falling storm flow:
  trapz_total_rise <- trapzArea(timeDiff_rise,rising$flow)
  trapz_total_fall <- trapzArea(timeDiff_fall,falling$flow)
  #Only flow above baseflow:
  trapz_abovebaseQ_rise <- trapzArea(timeDiff_rise,(rising$flow - rising$baseQ))
  trapz_abovebaseQ_fall <- trapzArea(timeDiff_fall,(falling$flow - falling$baseQ))
  #Only flow above baseline flow. THIS CAN BE NEGATIVE AND THEREFORE
  #UNRELIABLE?:
  trapz_abovebaselineQ_rise <- trapzArea(timeDiff_rise,(rising$flow - rising$baselineQ))
  trapz_abovebaselineQ_fall <- trapzArea(timeDiff_fall,(falling$flow - falling$baselineQ))
  
  #Total volume is the sum of area of the trapezoids found above converted to
  #MG from CF (1 CF * 12^3 in^3/cf * 231 gal/in^3 * 1 MG/1000000 gal):
  volume_total <- sum(trapz_total) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaseQ <- sum(trapz_abovebaseQ) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaselineQ <- sum(trapz_abovebaselineQ) * 12 * 12 * 12 / 231 / 1000000
  #Rising Limb
  volume_total_rise <- sum(trapz_total_rise) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaseQ_rise <- sum(trapz_abovebaseQ_rise) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaselineQ_rise <- sum(trapz_abovebaselineQ_rise) * 12 * 12 * 12 / 231 / 1000000
  #Falling limb:
  volume_total_fall <- sum(trapz_total_fall) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaseQ_fall <- sum(trapz_abovebaseQ_fall) * 12 * 12 * 12 / 231 / 1000000
  volume_abovebaselineQ_fall <- sum(trapz_abovebaselineQ_fall) * 12 * 12 * 12 / 231 / 1000000
  #Store results:
  transients$volumeTotalMG[i] <- volume_total
  transients$volumeAboveBaseQMG[i] <- volume_abovebaseQ
  transients$volumeAboveBaselineQMG[i] <- volume_abovebaselineQ
  transients$volumeTotalMG_rise[i] <- volume_total_rise
  transients$volumeAboveBaseQMG_rise[i] <- volume_abovebaseQ_rise
  transients$volumeAboveBaselineQMG_rise[i] <- volume_abovebaselineQ_rise
  transients$volumeTotalMG_fall[i] <- volume_total_fall
  transients$volumeAboveBaseQMG_fall[i] <- volume_abovebaseQ_fall
  transients$volumeAboveBaselineQMG_fall[i] <- volume_abovebaselineQ_fall
  
  #Create an exponential regression for the rising limb to roughly fit the
  #rising limb based on an "ideal" hydrograph
  modelR <- lm(log(rising$flow + 0.0001) ~ seq(1,length(rising$flow)))
  #Store exponential coefficient and adjusted r squared values
  transients$rising[i] <- summary(modelR)$coefficients[2]
  transients$risingInt[i] <- summary(modelR)$coefficients[1]
  transients$RsqR[i] <- summary(modelR)$adj.r.squared
  
  #Create an exponential regression for the falling limb
  modelF <- lm(log(falling$flow + 0.0001) ~ seq(1,length(falling$flow)))
  transients$falling[i] <- summary(modelF)$coefficients[2]
  transients$fallingInt[i] <- summary(modelF)$coefficients[1]
  transients$RsqF[i] <- summary(modelF)$adj.r.squared
  
  #Finds duration of the storm, rising and falling limbs combined
  transients$durAll[i] <- length(storm$timestamp)
  #Finds duration of the rising limb
  transients$durF[i] <- length(rising$timestamp)
  #Finds duration of the falling limb
  transients$durR[i] <- length(falling$timestamp)

}
print(paste0("Writing data to ",paste0(pathToWrite,"Gage",stormSepDF$gageID[1],"_StormStats.csv")))
#Write out data to the appropriate location
write.csv(transients,
          paste0(pathToWrite,"Gage",stormSepDF$gageID[1],"_StormStats.csv"),
          row.names = FALSE)


