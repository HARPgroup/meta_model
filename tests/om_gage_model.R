rseg_hydrocode = 'vahydrosw_wshed_PU2_3090_4050'
riverseg_feature <- RomFeature$new(ds, list(hydrocode=rseg_hydrocode,bundle='watershed',ftype='vahydro'), TRUE)
rseg_model <- RomProperty$new(ds, list(featureid=riverseg_feature$hydroid, propcode='vahydro-1.0', entity_type='dh_feature' ), TRUE)
rseg_nested <- ds$get_json_prop(rseg_model$pid)

riverseg_feature$propvalues()

gage_mname = "01619500_PU2_3090_4050"
gage_model <- RomProperty$new(
  ds, list(
    propname=gage_mname,
    entity_type="dh_feature",
    featureid=riverseg_feature$hydroid
  ), TRUE
)
gage_nested <- ds$get_json_prop(gage_model$pid)

gage_nested <- ds$get_json_prop(7701223)

# for testing R om summary 
argst <- c(7700740, "01625000_PS3_6460_6230", 400, "/media/model/met/usgs/usgs/01625000_PS3_6460_6230.out")
argst <- c(7701272, "01619500_PU2_3090_4050", "usgs", "http://deq1.bse.vt.edu:81/usgs/usgs/01619500_PU2_3090_4050.out")

# for testing the scaling method
argst <- c("01646000", "http://deq1.bse.vt.edu:81/usgs/400/01646000_PM7_4581_4580.out", "1984-01-01", "2020-12-31", 58.24)


