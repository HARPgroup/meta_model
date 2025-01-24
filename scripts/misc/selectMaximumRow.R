#Given a timeseries with "rankings" as developed by raster_met > amalgamate >
#process > 01_acquire, create a timeseries that selects the best available for
#the day using the column name
suppressPackageStartupMessages(library(sqldf))

#Testing variables:
# csvInput <- "C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-nldas-storm_volume-rating-ts.csv,C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-daymet-storm_volume-rating-ts.csv,C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-PRISM-storm_volume-rating-ts.csv"
# ratingColumns <- "nldas2_precip_hourly_tiled_16x16,daymet_mod_daily,prism_mod_daily"
# defaultColumn <- "nldas2_precip_hourly_tiled_16x16"

#Input ratings file
csvInput <- argst[1]
#The column names containing the rankings for that day/coverage input as a
#single comma separate string. Note that these column names will be stored to
#inform the user of the maximum ranking
ratingColumns <- argst[2]

#QC Inputs: csvInput should be length 1
if(length(csvInput) != 1){
  stop('There should only be one input rating file and the columns must be defined as a comma separate character string')
}

#Arguments to script are strings that contain commas to denote separate entries.
#Convert to vectors:
ratingColumns <- unlist(strsplit(ratingColumns,","))

#QC Inputs: Default column must be in ratingColumns
if(!any(grepl(defaultColumn,ratingColumns))){
  stop('The default column must be included in the second argument string input')
}

#Ensure the default column is first, which makes the sql below select it as long
#as it has the maximum rating, even in case of ties
ratingColumns <- c(defaultColumn,ratingColumns[!grepl(defaultColumn,ratingColumns)])

#Read in the ratings file
ratings <- read.csv(csvInput)

#Find all other columns in the ratings files to ensure the are preserved. Use
#grepl to leverage regex to find any of the arguments in ratingColumns in
#names(ratings)
otherNames <- names(ratings)[!grepl(paste0(ratingColumns,collapse="|"),names(ratings))]

#Find the maximum rating for each row in the table
ratings$maxRating <- mapply(function(dfIn,colsIn,iter){max(dfIn[iter,colsIn],na.rm = TRUE)},
                    iter = 1:nrow(ratings),
                    MoreArgs = list(dfIn = ratings, colsIn = ratingColumns)
)

#Select the ratingColumns name for the column that has the greatest rating. In
#the case of ties, use the default column. If only 2 of ratingColumns are tied
#but they are the maximum, ratingColumns has been ordered to ensure the default
#column's WHEN statement is first:
sql <- paste0("SELECT a.*,
              CASE
                WHEN ",paste0("a.",ratingColumns[1:2]," = a.",ratingColumns[2:3],collapse = " & ")," THEN '",defaultColumn,"'
                ",paste0("WHEN a.",ratingColumns," = a.maxRating THEN '",ratingColumns,"'",collapse = "\n"),"
              END AS varkey
              FROM ratings as a
")

outDF <- sqldf(sql)
