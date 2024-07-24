#Will join a column of 1 table to a different table 
#Assuming: csv1 is hourly data and does not yet have columns for hour, day, etc. 
#  and csv2 either has headers with an index column or is in wdm format (no headers but set column order)
suppressPackageStartupMessages(library(data.table)) 
suppressPackageStartupMessages(library(sqldf))
suppressPackageStartupMessages(library(lubridate))

#setwd("/Users/glenncampagna/Desktop/HARPteam22/Data") # for testing only (Glenn)
#df1<- fread("OR1_7700_7980_hydr.csv") # for testing only 
#df2 <- fread("OR1_7700_7980_divr.csv") # for testing only

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 5) {
   message("Use: join_col_yrmodawk.R file1 file2 col_to_copy new_col_name timestep[hour or day]")
  q()
}
csv1 <- argst[1]
csv2 <- argst[2]
old_col <- argst[3] #should be 'values' when wdm is used 
new_col <- argst[4]
timestep <- argst[5] # either hour or day 

df1 <- fread(csv1)
df2 <- fread(csv2)

# remove the target column if it exists already
if (new_col %in% names(df1)) {
  df1[,new_col] <- NULL
}
#this sqldf syntax selects a as primary table and b to be joined, we capitalized sqldf operator words to exclude syntax errors

if (timestep == 'hour') {
  join_sql <- paste0(
    "SELECT a.*, b.'", old_col,"' AS '", new_col, "'
     FROM df1 AS a 
     ORDER BY a.yr,a.mo,a.da,a.hr"
  )
}

if (timestep == 'day') {
  join_sql <- paste0(
    "SELECT a.*, b.'", old_col,"' AS '", new_col, "'
     FROM df1 AS a 
     LEFT OUTER JOIN df2 AS b ON (a.yr = b.yr AND a.mo = b.mo AND a.da = b.da)
     ORDER BY a.obs_date"
  )
}
message(paste("SQL:",join_sql))
df1_joined <- sqldf(join_sql)
#Comparing lengths of table and column to be joined
rows_df1 <- nrow(df1)
rows_df1j <- nrow(df1_joined)
if (rows_df1 != rows_df1j) {
  stop('Table and column are different lengths, unable to join')
}

# output to original file
write.table(df1_joined,file = csv1, sep = ",", row.names = FALSE)
