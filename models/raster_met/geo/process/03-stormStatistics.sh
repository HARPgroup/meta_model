#!/bin/bash
#First argument should be USGS gage of interest
USGSgage=$1
#Second argument is path in which storm CSVs are stored for the gage created in
#step 2
tempPath=$2
#Third argument is TRUE or FALSE and determines if stormSep should plot
doPlots=$3
#If plotting, where should output files be plotted to?
plotStormPath=$4
#Where should files be written out to?
pathToWrite=$5

#File path of the gage data of interest:
gageFilePath="${tempPath}/Gage${USGSgage}_StormflowData.csv")

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormAnalysis_cmd.R $gageFilePath $doPlots $plotStormPath $pathToWrite
echo "Running: $cmd"
eval $cmd


#NEXT STEPS ARE TO MAKE A STEP FOR THE ACTUAL ANALYSIS AND FOR OPTIONAL PRECIP PLOTS