rseg_hydrocode = 'vahydrosw_wshed_PS5_5240_5200'
riverseg_feature <- RomFeature$new(ds, list(hydrocode=rseg_hydrocode,bundle='watershed',ftype='vahydro'), TRUE)
rseg_model <- RomProperty$new(ds, list(featureid=riverseg_feature$hydroid, propcode='vahydro-1.0', entity_type='dh_feature' ), TRUE)
rseg_nested <- ds$get_json_prop(rseg_model$pid)

riverseg_feature$propvalues()


gage_mname = "01631000_PS5_5240_5200"
gage_model <- RomProperty$new(
  ds, list(
    featureid=riverseg_feature$hydroid, 
    propname=gage_mname, 
    entity_type='dh_feature' 
  ), TRUE
)
gage_nested <- ds$get_json_prop(gage_model$pid)


# for testing R om summary 
argst <- c(7700740, "01646000_PM7_4581_4580", 400, "http://deq1.bse.vt.edu:81/usgs/400/01646000_PM7_4581_4580.out")
# for testing the scaling method
argst <- c("01646000", "http://deq1.bse.vt.edu:81/usgs/400/01646000_PM7_4581_4580.out", "1984-01-01", "2020-12-31", 58.24)
