#!/bin/bash
#First argument should be USGS gage of interest
USGSgage=$1
#Second argument is path in which storm CSVs are stored for the gage created in
#step 2
tempPath=$2
#Where should files be written out to?
pathToWrite=$3

#File path of the gage data of interest:
gageFilePath="${tempPath}/Gage${USGSgage}_StormflowData.csv")

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormAnalysis_cmd.R $gageFilePath $pathToWrite
echo "Running: $cmd"
eval $cmd


#NEXT STEPS ARE TO MAKE A STEP FOR THE ACTUAL ANALYSIS AND FOR OPTIONAL PRECIP PLOTS