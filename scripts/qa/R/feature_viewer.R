wsheds <- sqldf(
  "
    select *
    from dh_feature_fielded 
    where ftype = 'cbp532_landseg'
    and bundle = 'landunit'
    order by st_area2d(dh_geofield_geom) DESC
  ",
  connection = ds$connection
)
wsheds <- wsheds[which(!is.na(wsheds$dh_geofield)),]
wshed_st <- st_as_sf(
  wsheds, 
  wkt='dh_geofield',
  crs=4326
)
lmap <- leaflet::leaflet()
lmap <- leaflet::addPolygons(
  lmap,
  #  lng=st_coordinates(wshed_st)[,1],
  #  lat=st_coordinates(wshed_st)[,2],
  data=wshed_st,
  layerId = ~hydroid,
  popup = ~hydrocode,
  group = "watershed"
) 
lmap <- leaflet::addProviderTiles(lmap, c('Esri.WorldStreetMap'))
leaflet::addProviderTiles(lmap, c('Esri.WorldImagery'))
