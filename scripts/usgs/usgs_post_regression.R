#Creates the appropriate model and scenario properties for a USGS feature and
#stores regression coefficients
#For local testing:
# commandArgs <- function(...){
#   c("01613900", "watershed", "usgs_full_drainage", "AGWRC-1.0", 'NA', "https://deq1.bse.vt.edu/usgs/agws/baseflow_regression_df_01613900.csv")
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
#Optional scenario prop name
scenario_propcode <- argst[5]
#The file containing the baseflow recession regression coefficients
regressionFile <- argst[6]
regressionFile <- str_replace_all(regressionFile, '\"', '') # quotes coming in give troubles

#Create a hydrocode based on the provided gage_id
coverage_hydrocode <- paste0("usgs_ws_",gage_id)

#Get all regression data
regression_coeff <- read.csv(regressionFile)

#Get the watershed feature
this_feature <- RomFeature$new(
  ds, list(
    hydrocode = coverage_hydrocode,
    bundle = coverage_bundle, 
    ftype = coverage_ftype
  ), TRUE)

#Get or create the model to post on:
model_prop <- hydrotools::om_model_object(
  ds = ds, feature = this_feature,
  model_version = model_version,
  model_name = paste(coverage_hydrocode, model_version)
) 

#Which property should values be set on? Either model or scenario:
parent_prop <- model_prop
if(!is.na(scenario_propcode) && scenario_propcode != "NA"){
  #Get or create the model to post on:
  parent_prop <- hydrotools::om_get_model_scenario(
    ds = ds, model = model_prop,
    scenario_name = scenario_propcode
  ) 
}

#Post value to scenario prop and output message with new pid
postValue <- function(propname, value, parent_prop){
  new_prop <- parent_prop$set_prop(
    propname = propname, propvalue = value
  )
  message(paste0("Stored ",propname," in pid = ",new_prop$pid,
                 " on parent entity pid = ",parent_prop$pid))
}
#Post the slope
postValue(propname = "regression_m",value = regression_coeff$m, 
          parent_prop = parent_prop)
#Post the intercept
postValue(propname = "regression_b",value = regression_coeff$b, 
          parent_prop = parent_prop)
#Post the R Squared of the regression
postValue(propname = "regression_Rsq",value = regression_coeff$Rsq, 
          parent_prop = parent_prop)
#Post the slope p value
postValue(propname = "regression_m_pvalue",value = regression_coeff$m_pvalue, 
          parent_prop = parent_prop)
#Post the intercept p value
postValue(propname = "regression_b_pvalue",value = regression_coeff$b_pvalue, 
          parent_prop = parent_prop)

#Post the lowest event median Q
postValue(propname = "agwrc_reg_qlow",value = regression_coeff$low_Q, 
          parent_prop = parent_prop)
#Post the AGWRC of the lowest event median Q
postValue(propname = "agwrc_reg_clow",value = regression_coeff$low_Q_agwrc, 
          parent_prop = parent_prop)

#Post the highest event median Q
postValue(propname = "agwrc_reg_qhigh",value = regression_coeff$high_Q, 
          parent_prop = parent_prop)
#Post the AGWRC of the highest event median Q
postValue(propname = "agwrc_reg_chigh",value = regression_coeff$high_Q_agwrc, 
          parent_prop = parent_prop)

