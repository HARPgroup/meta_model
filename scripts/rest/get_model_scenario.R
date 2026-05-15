#A simple function to create a property on a feature identified via hydrocode,
#bundle, and ftype or hydroid. The created prop has propname of model_version. A
#property is created on this property that the name scenarioPropName.
#Returns a list of the feature, model, and scenario R6 objects
om_model_and_scenario <- function(ds, coverage_hydrocode, coverage_bundle, coverage_ftype,
                                  coverage_hydroid = NA,
                                  model_version, scenarioPropName){
  
  if(is.na(coverage_hydroid) &
     (!is.na(coverage_hydrocode) & !is.na(coverage_bundle) & !is.na(coverage_ftype))
     ){
    # load the base feature for the coverage using romFeature and ds:
    message(paste("Searching for feature hydrocode=", coverage_hydrocode,"with ftype",coverage_ftype))
    feature <- RomFeature$new(
      ds,
      list(
        hydrocode = coverage_hydrocode,
        ftype = coverage_ftype,
        bundle = coverage_bundle
      ),
      TRUE
    )
  }else{
    # load the base feature using pkid:
    message(paste("Searching for feature hydrocode=", coverage_hydrocode,"with ftype",coverage_ftype))
    feature <- RomFeature$new(ds, list(hydroid = coverage_hydroid), TRUE)
  }

  message(paste("Found feature with hydroid =", feature$hydroid))
  
  #Create a name for the model property to be created on the feature:
  model_name <- paste(coverage_hydrocode,model_version)
  
  message(paste("Creating/finding model property on", feature$hydroid, "with propname =",model_name))
  # if a matching model does not exist, this will go ahead and create one using
  # romProperty
  model <- om_model_object(ds, feature, model_version, 
                           model_name = model_name)
  message(paste("Model property with propname =",model$propname," created/found with pid =",model$pid))
  #If there are multiple model properties, om_model_object returns the first
  #without checking propname. This will instead create a new property if the model
  #name doesn't match the returned propname
  if(model$propname != model_name){
    #Search for a property with the correct propname and other fields
    model <- RomProperty$new(ds, list(featureid = feature$hydroid, 
                                      entity_type = "dh_feature",
                                      propname = model_name,
                                      propcode = model_version), 
                             TRUE)
    model_varkey <- "om_model_element"
    #If nothing is found, create the new property
    if (is.na(model$pid)) {
      #Get the correct varid for the varkey used for the model
      model$varid = ds$get_vardef(model_varkey)$hydroid
      message(paste("Creating new feature model", model$propname, 
                    model$varid, model$featureid, model$propcode))
      #Save property
      model$save(TRUE)
    }
  }
  
  # this will create or retrieve a model scenario to house this summary data using
  # romProperty
  message(paste("Creating/finding model scenario on", model$pid, "with propname =",scenarioPropName))
  modelScenario <- om_get_model_scenario(ds, model, scenarioPropName)
  message(paste("Ranking Scenario property with propname =",modelScenario$propname," created/found with pid =",modelScenario$pid))
  
  return(
    list(
      feature = feature,
      model = model,
      modelScenario = modelScenario
    )
  )
}
