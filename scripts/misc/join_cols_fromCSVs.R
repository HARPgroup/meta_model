#User provides a comma separated vector of csv file paths. This script reads in
#each vector, searching for the the old_colVector fields. These fields are
#joined together view the date timestamps in dateIndexColVector (MUST be daily
#data) and renamed per new_colVector.
suppressPackageStartupMessages(library(sqldf))
suppressPackageStartupMessages(library(lubridate))

startDate <- "1984-01-01"
endDate <- "2023-12-31"
csvInput <- "C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-nldas-storm_volume-rating-ts.csv,C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-daymet-storm_volume-rating-ts.csv,C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-PRISM-storm_volume-rating-ts.csv"
oldColInput <- 'rating'
newColInput <- "nldas2_precip_hourly_tiled_16x16,daymet_mod_daily,prism_mod_daily"
startDateCol <- 'start_date'
endDateCol <- 'end_date'

#Inputs to the script are to be character strings with literal commas separating
#values.
argst <- commandArgs(trailingOnly = T)
#The start date of the anlysis
startDate <- argst[1]
#The end date of the anlysis
endDate <- argst[2]
#Character of csv file paths
csvInput <- argst[3]
#Character of names of columns to join from csv files
oldColInput <- argst[4]
#Character of names that rename the columns in oldColVector
newColInput <- argst[5] 
#Character of names of columns that have the dates that will be used to join the
#csv in csvVector
startDateCol <- argst[6] 
endDateCol <- argst[7] 
#Path to write final joined data frame to:
pathToWrite <- argst[8]


#Arguments to script are strings that contain commas to denote separate entries.
#Convert to vectors:
csvVector <- unlist(strsplit(csvInput,","))
oldColVector <- unlist(strsplit(oldColInput,","))
newColVector <- unlist(strsplit(newColInput,","))
startDateColVector <- unlist(strsplit(startDateCol,","))
endDateColVector <- unlist(strsplit(endDateCol,","))


#All inputs should either be length 1 or of equal length to csvVector.
#newColVector must be the same length as csvVector as these should be unique
errChk1 <- (length(oldColVector) != length(csvVector)) & (length(oldColVector) != 1)
errChk2 <- (length(newColVector) != length(csvVector))
errChk3 <- (length(startDateColVector) != length(csvVector)) & (length(startDateColVector) != 1)
errChk4 <- (length(endDateColVector) != length(csvVector)) & (length(endDateColVector) != 1)

if(any(errChk1,errChk2,errChk3,errChk4)){
  stop('Inputs must be length 1 or otherwise of equal length to the number of csvs in argument 1')
}

#For ease of loop, ensure all vectors are the same length by repeating values as
#necessary from those that are just one value:
if(length(oldColVector) != length(csvVector)){
  oldColVector <- rep(oldColVector,length(csvVector))
}
if(length(newColVector) != length(csvVector)){
  newColVector <- rep(newColVector,length(csvVector))
}
if(length(startDateColVector) != length(csvVector)){
  startDateColVector <- rep(startDateColVector,length(csvVector))
}
if(length(endDateColVector) != length(csvVector)){
  endDateColVector <- rep(endDateColVector,length(csvVector))
}

#Create a base timeseries from start to endDate to join all other data to:
outDF <- data.frame(date = seq.Date(from = as.Date(startDate),
                                    to = as.Date(endDate),
                                    by = 1))
outDF$day <- day(outDF$date)
outDF$month <- month(outDF$date)
outDF$year <- year(outDF$date)

#for date fields, the origin timestep and timezone
tzIn <- "UTC"
origin <- "1970-01-01"
#For each csv in csvVector, read in the csv and join to a central data frame
#renaming columns as necessary
for(i in 1:length(csvVector)){
  #It's possible that the ratings file will not exist for this gage for this
  #workflow. If this is the case, skip the file and set the ratings column to NA
  if(!file.exists(csvVector[i])){
    outDF[,newColVector[i]] <- NA
  }else{
    loopDF <- read.csv(csvVector[i])
    
    #Ensure date columns are read in correctly
    loopDF[,startDateColVector[i]] <- as.Date(loopDF[,startDateColVector[i]])
    loopDF[,endDateColVector[i]] <- as.Date(loopDF[,endDateColVector[i]])
    
    #Join to loop DF using the date information
    sql <- paste0("SELECT a.*, b.", oldColVector[i]," AS ", newColVector[i], "
                FROM outDF AS a 
                LEFT JOIN loopDF AS b
                  ON b.",startDateColVector[i]," <= a.date
                  AND (b.",endDateColVector[i]," >= a.date) 
                ORDER BY a.year,a.month,a.day"
    )
    
    outDF <- sqldf(sql)
  }
}

#Write out the joined data frames to the file path specified by user
write.csv(outDF,file = pathToWrite, row.names = FALSE)