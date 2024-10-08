#Develops a batch insert query for dh_timeseries for user input featureid and
#varid
#Testing Variables:
# ratingsFile <- "C:/Users/gcw73279.COV/Desktop/gitBackups/gitHome/usgs_ws_01668000-nldas-storm_volume-rating-ts.csv"

argst <- commandArgs(trailingOnly = T)
#The varkey that will be used to look up a varid to include in dh_timeseries for
#these entries
ratingsVarkey <- argst[1]
#The model scenario property name
scenarioPropName <- argst[2]
#The model property name for the feature
modelPropName <- argst[2]
#The base feature
hydrocode <- argst[3]
#Input ratings file path to insert
ratingsFile <- argst[4]
#Path to write final SQL to:
pathToWrite <- argst[5]

#Read in the ratings file
ratings <- read.csv(ratingsFile)

#Convert the ratings start and end dates to seconds after epoch to insert into
#DB
ratings$start_date_sec <- as.numeric(as.POSIXct(ratings$start_date,tz = "EST"))
ratings$end_date_sec <- as.numeric(as.POSIXct(ratings$end_date,tz = "EST"))


sql <- paste0("
\\set ratingsVarkey '",ratingsVarkey,"'
\\set scenarioPropName '",scenarioPropName,"'
\\set modelPropName '",modelPropName,"'
\\set hydrocode  '",hydrocode,"' \n
SELECT hydroid AS ratingsVarid FROM dh_variabledefinition WHERE varkey = :'ratingsVarkey' \\gset \n

SELECT p.pid AS scenarioPID 
FROM dh_properties as p 
LEFT JOIN dh_properties as prop 
ON p.featureid = prop.pid 
LEFT JOIN dh_feature as f 
ON prop.featureid = f.hydroid 
WHERE p.propname = :'scenarioPropName' 
AND prop.propname = :'modelPropName' 
AND f.hydrocode = :'hydrocode' \\gset \n

insert into dh_timeseries(tstime,tsendtime,tsvalue,featureid,varid,entity_type)
VALUES
",paste0("(",ratings$start_date_sec,",",ratings$end_date_sec,",",ratings$rating,",:'scenarioPID',:'hydroid','dh_properties')",collapse=", \n"))

#Write out SQL
write(sql,pathToWrite)