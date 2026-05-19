#Creates the appropriate model and scenario properties for a USGS feature and
#stores regression coefficients
# Example Inputs:
# gage_id <- "01634000"
# coverage_bundle <- 'watershed'
# coverage_ftype <- 'usgs_full_drainage'
# model_version <- 'agwrc-1.0'
# regressionPropName <- 'simple_lm'


#For local testing:
# commandArgs <- function(...){
#   c("01634000", "watershed", "usgs_full_drainage", "agwrc-1.0", 'simple_lm', "strasAGWRCRegression.csv")
# }

#Load in hydrotools and connect to db
library(hydrotools)
suppressPackageStartupMessages(library(stringr))
basepath='/var/www/R'
source('/var/www/R/config.R')


argst <- commandArgs(trailingOnly = T)
#The USGS gage id
gage_id <- argst[1]
#For USGS watersheds, this is 'watershed'
coverage_bundle <- argst[2]
#For USGS Watersheds, this is 'usgs_full_drainage'
coverage_ftype <- argst[3]
#agwrc-1.0 or some equivalent
model_version <- argst[4] 
#The model scenario property name specific to the workflow and defined in config
#file
regressionPropName <- argst[5]
#The file containing the baseflow recession regression coefficients
regressionFile <- argst[6]
regressionFile <- str_replace_all(regressionFile, '\"', '') # quotes coming in give troubles

#Create a hydrocode based on the provided gage_id
coverage_hydrocode <- paste0("usgs_ws_",gage_id)

source("https://raw.githubusercontent.com/HARPgroup/meta_model/refs/heads/drought_20260514/scripts/rest/get_model_scenario.R")

regression_coeff <- read.csv(regressionFile)

model_list <- om_model_and_scenario(ds = ds, coverage_hydrocode = coverage_hydrocode,
                                    coverage_bundle = coverage_bundle, 
                                    coverage_ftype = coverage_ftype,
                                    model_version = model_version,
                                    scenarioPropName = regressionPropName)
#Post value to scenario prop and output message with new pid
postValue <- function(propname, value, scenarioProp){
  new_prop <- scenarioProp$set_prop(
    propname = propname, propvalue = value
  )
  message(paste0("Stored ",propname," in pid = ",new_prop$pid,
                 " on parent entity pid = ",scenarioProp$pid))
}
#Post the slope
postValue(propname = "regression_m",value = regression_coeff$m, 
          scenarioProp = model_list$modelScenario)
#Post the intercept
postValue(propname = "regression_b",value = regression_coeff$b, 
          scenarioProp = model_list$modelScenario)
#Post the R Squared of the regression
postValue(propname = "regression_Rsq",value = regression_coeff$Rsq, 
          scenarioProp = model_list$modelScenario)
#Post the slope p value
postValue(propname = "regression_m_pvalue",value = regression_coeff$m_pvalue, 
          scenarioProp = model_list$modelScenario)
#Post the intercept p value
postValue(propname = "regression_b_pvalue",value = regression_coeff$b_pvalue, 
          scenarioProp = model_list$modelScenario)

