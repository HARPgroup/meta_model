#!/bin/bash
#First argument should be The path to the storm separated data from step 02 for this gage
stormSepPath=$1
#Where should files be written out to?
pathToWrite=$2

#File path of the gage data of interest:
gageFilePath="${tempPath}/Gage${USGSgage}_StormflowData.csv")

cmd="Rscript $META_MODEL_ROOT/scripts/met/stormAnalysis_cmd.R $stormSepPath $pathToWrite
echo "Running: $cmd"
eval $cmd


#NEXT STEPS ARE TO MAKE A STEP FOR THE ACTUAL ANALYSIS AND FOR OPTIONAL PRECIP PLOTS