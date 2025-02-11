rseg_hydrocode = 'vahydrosw_wshed_PM7_4581_4580'
riverseg_feature <- RomFeature$new(ds, list(hydrocode=rseg_hydrocode,bundle='watershed',ftype='vahydro'), TRUE)
rseg_model <- RomProperty$new(ds, list(featureid=riverseg_feature$hydroid, propcode='vahydro-1.0', entity_type='dh_feature' ), TRUE)
rseg_nested <- ds$get_json_prop(rseg_model$pid)

riverseg_feature$propvalues()
gage_mname = "01646000_PM7_4581_4580"
gage_model <- RomProperty$new(
  ds, list(
    featureid=riverseg_feature$hydroid, 
    propname=gage_mname, 
    entity_type='dh_feature' 
  ), TRUE
)
gage_nested <- ds$get_json_prop(gage_model$pid)


