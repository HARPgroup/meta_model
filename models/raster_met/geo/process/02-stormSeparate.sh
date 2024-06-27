#!/bin/bash
#First argument should be USGS gage of interest
USGSgage=$1
#Second argument is path to USGS gage csvs downloaded in geo -> download
gageDataPath=$2
#Third argument is TRUE or FALSE and determines if stormSep should plot
doPlots=$3
#If plotting, where should output files be plotted to?
plotStormPath=$4
#Are we interested in baseline storms or all local minima? Recommended to set 
#to TRUE as of 06/27/2024 due to lack of development on FALSE side
allMinimaStorms=$5
#How should baselineFlow be calculated? Recommended by "Months"
baselineFlowOption=$6
#Where should files be written out to?
pathToWrite=$7

#File path of the gage data of interest:
gageFilePath="${gageDataPath}/${USGSgage}_data.csv"

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormSep_cmd.R $gageFilePath $doPlots $plotStormPath $allMinimaStorms $baselineFlowOption $pathToWrite"    
echo "Running: $cmd"
eval $cmd