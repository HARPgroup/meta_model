#!/bin/bash
# loads the args, the raster specific config and change to temp dir
amalgamate_config=`find_config amalgamate.config`
if [ "$amalgamate_config" = "" ]; then
  amalgamate_config="$META_MODEL_ROOT/models/raster_met/amalgamate/amalgamate.config"
fi
. $amalgamate_config

#Create a best-fit raster based on the amalgamate scenario and the background varkey
#First, Grab the USGS full drainage geometries/coverages and assign ratings to inicate best 
#performing precip dataset
#Next, Union the best rated datasets together picking the last selected pixel value. Since the data is sorted by drainage area, 
#upstream areas will populate after larger, downstream coverages
#Then Use a full union to create a column with the amalgamateUnion raster and the nldasFulLDayResamp raster
#Then, union the rasters to get a raster in which the "background" is the nldasFullDayResamp and everything else is 
#the best fit raster
bestraster_sql="
\\set tsendin '1582002000' \n
\\set resample_varkey 'daymet_mod_daily' \n
\\set amalgamate_varkey 'amalgamate_simple_lm' \n
\\set background_varkey 'nldas2_precip_hourly_tiled_16x16' \n
\\set ratings_varkey 'met_rating' \n
select hydroid as covid from dh_feature where hydrocode = 'cbp6_met_coverage' \\gset \n
WITH usgsCoverage as (
	SELECT f.hydroid,f.hydrocode,
		ts.tstime,
		ts.tsendtime,
		ts.tsvalue as dataID,
		bestVarkey.varkey as dataVarkey,
		ST_AREA(f.dh_geofield_geom) as covArea
		,f.dh_geofield_geom as dh_geofield_geom
	FROM dh_feature_fielded as f
	LEFT JOIN dh_properties AS model
	ON model.featureid = f.hydroid
	LEFT JOIN dh_properties as scen
	ON scen.featureid = model.pid
	LEFT JOIN dh_timeseries as ts
	ON ts.featureid = scen.pid
	LEFT JOIN dh_variabledefinition as v
	on v.hydroid = ts.varid
	LEFT JOIN dh_variabledefinition as bestVarkey
	on bestVarkey.hydroid = ts.tsvalue
	WHERE f.bundle = 'watershed' AND f.ftype = 'usgs_full_drainage'
		AND model.propname ilike '%met-1.0'
		AND v.varkey = :'ratings_varkey'
		AND scen.propname = :'amalgamate_varkey'
		AND ts.tsendtime = :'tsendin'
	ORDER BY covArea DESC
)
,backgroundTemplate as (
	SELECT ST_SetValue(rt.rast, 1, ST_ConvexHull(rt.rast), v.hydroid) as rast
	FROM dh_variabledefinition as v
	LEFT JOIN (select rast from raster_templates where varkey = :'resample_varkey') as rt
	ON 1 = 1
	WHERE v.varkey = :'background_varkey'
)
,bestData as (
	SELECT cov.hydroid,cov.hydrocode,cov.tstime,cov.tsendtime,
	ST_SetValue(
		st_clip(rt.rast, cov.dh_geofield_geom),
		1, ST_Buffer(ST_ConvexHull(cov.dh_geofield_geom),0.125), cov.dataID
	) as rast
	FROM usgsCoverage as cov
	LEFT JOIN (select rast from raster_templates where varkey = :'resample_varkey') as rt
	ON 1 = 1
)
,amalgamateUnion as (
	SELECT ST_union(rast,'LAST') as rast
	FROM bestData
)
SELECT ST_union(fullUnion.rast,'LAST') as rast
FROM (
	SELECT rast FROM backgroundTemplate
    UNION ALL
    SELECT rast FROM amalgamateUnion 
) as fullUnion;
"