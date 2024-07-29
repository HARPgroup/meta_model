#Input variables are:
# 1 = The path to the storm separated data from step 02 for this gage
# 2 = The path to the statistics generated for the storms
# 3 = path = Directory to store plots in. 
# 4 = The USGS gage number or hydro ID of the coverage that will be used to store
# this data with unique names

#Call packages required by function if not called already:
library(grwat)
library(zoo)
library(sqldf)
#Get all arguments explicitly passed in from command line:
args <- commandArgs(trailingOnly = TRUE)
#Read in the flow data that features an ID column to designate each storm event:
stormSepDF <- read.csv(args[1],stringsAsFactors = FALSE)
#Read in the statistics created for each storm in step 03-stormStatistics
stormStats <- read.csv(args[2],stringsAsFactors = FALSE)
#The path to write plots out
pathToWrite <- args[3]
#The USGS gage number or hydro ID of the coverage that will be used to store
#this data with unique names
pathDetails <- args[4]

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
pathToWrite <- args[3]

#Plot each storm if requested and fit exponential curves to rising and falling
#limbs Store coefficients and statistics for each curve into a data frame,
#looking at shape of curve and the adjusted R square values. Store each storm as
#a PNG graph in the designated area. Need to prevent errors from zero flow.
#Added 0.0001 to all flow values. This WILL RESULT IN BIAS
ext <- ".png"

for (i in 1:length(stormsep)){
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
  
  #Look for where the max is
  maxtime <- storm$timestamp[storm$flow == max(storm$flow)][1]
  
  #Separate rising and falling limbs based on maxtime e.g. the rising limb is
  #all values leading up to maxtime
  rising <- storm[storm$timestamp <= maxtime,]
  falling <- storm[storm$timestamp >= maxtime,]
  #Using the coefficients stored in stormStats, get the rough fitted values of
  #the rising and falling limbs:
  risingLimb <- exp(stormStats$rising * seq(1,length(rising$flow)) + stormStats$risingInt - 0.0001)
  fallingLimb <- exp(stormStats$falling * seq(1,length(falling$flow)) + stormStats$fallingInt - 0.0001)
  
  #Plot the storm and the fitted rising and falling limbs and store them in
  #designated path. Include the baseflow and and the baseline flow brk
  #Set plot output path and dimensions
  png(paste0(pathToWrite,"pathDetails","storm",i,ext), width=1820,height=760)
  #Set plot margins
  par(mar=c(5,6,2,4))
  #Plot the storm, making the labels a little thicker and the lines of the
  #plot and labeling the axes
  plot(storm$timestamp, storm$flow, type='l',
       xlab='Date', ylab='Flow (cfs)',
       lwd=2, cex.axis=2, cex.lab=2)
  #Plot the fitted rising limb:
  lines(storm$timestamp[storm$timestamp <= maxtime],
        risingLimb,
        col = 'darkblue',lwd = 2)
  #Plot the fitted falling limb:
  lines(storm$timestamp[storm$timestamp >= maxtime],
        fallingLimb,
        col = 'darkred', lwd = 2)
  #Plot the baseflow
  lines(storm$timestamp, storm$baseQ,
        col = "darkgreen", lwd = 2)
  #Plot the baseline flow brk as a dashed line via lty = 3
  lines(storm$timestamp, storm$baselineQ,lty = 3,lwd = 2)
  #Put a small legend on the plot
  legend("topleft",c("Flow","Baseflow","Rise Limb","Fall Limb","Baseline"),
         col = c("black","darkgreen","darkblue","darkred","black"),
         lty = c(1,1,1,1,3),
         bty = "n")
  #Close the plot PNG and output the file
  dev.off()
}



