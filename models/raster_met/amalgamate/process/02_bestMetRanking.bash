#!/bin/bash
# loads the args, the raster specific config and change to temp dir
amalgamate_config=`find_config amalgamate.config`
if [ "$amalgamate_config" = "" ]; then
  amalgamate_config="$META_MODEL_ROOT/models/raster_met/amalgamate/amalgamate.config"
fi
. $amalgamate_config

#Establish and insert best-fit ratings. Delete existing ratings as needed.
ratings_sql="
\\set ratingsVarkey '$RATINGS_VARKEY' \n
\\set scenarioPropName '$SCENARIO_PROP_NAME' \n
\\set hydrocode  '$ENTITY_HYDROCODE' \n
\\set metModel '$MET_MODEL_VERSION' \n
SELECT hydroid AS ratings FROM dh_variabledefinition WHERE varkey = :'ratingsVarkey' \\gset \n
SELECT scen.pid as scenariopid
FROM dh_properties as scen
LEFT JOIN dh_properties as model
ON model.pid =  scen.featureid
LEFT JOIN dh_feature as feat
on feat.hydroid = model.featureid
WHERE feat.hydrocode = :'hydrocode' 
AND feat.bundle = '$ENTITY_BUNDLE' 
and feat.ftype = '$ENTITY_FTYPE'
and scen.propname = :'scenarioPropName' \\gset \n

DELETE FROM dh_timeseries
WHERE varid = :ratings 
AND entity_type = 'dh_properties'
AND featureid = :scenariopid;

WITH maxRating AS (
	SELECT modelProp.featureid as featureid,
		ts.tstime as tstime,
		ts.tsendtime as tsendtime,
		max(ts.tsvalue) as maxtsvalue
	FROM dh_properties as modelProp
	LEFT JOIN dh_properties as scenProp
		ON scenProp.featureid = modelProp.pid
	LEFT JOIN dh_timeseries as ts
		ON ts.featureid = scenProp.pid
	WHERE modelProp.propcode = :'metModel'
		AND scenProp.propname = :'scenarioPropName'
	GROUP BY modelProp.featureid,
		to_timestamp(ts.tstime),
		to_timestamp(ts.tsendtime)
),
bestRating AS (
	SELECT modelProp.featureid AS featureid,
		to_timestamp(ts.tstime) as tstime,
		to_timestamp(ts.tsendtime) as tsendtime,
		ts.tsvalue,
		v.varkey 
	FROM dh_properties as modelProp
	LEFT JOIN dh_properties as scenProp
	ON scenProp.featureid = modelProp.pid
	LEFT JOIN dh_timeseries as ts
	ON ts.featureid = scenProp.pid
	LEFT JOIN dh_variabledefinition as v
	ON v.hydroid = ts.varid
	INNER JOIN maxRating
	ON ts.tstime = maxRating.tstime
	AND ts.tsendtime = maxRating.tsendtime
	AND ts.tsvalue = maxRating.maxtsvalue
	AND modelProp.featureid = maxRating.featureid
  WHERE modelProp.propcode = :'metModel'
  		AND scenProp.propname = :'scenarioPropName'
  ORDER BY ts.tstime
)

INSERT INTO dh_timeseries ( tstime,tsendtime, tsvalue, featureid, varid, entity_type )
SELECT a.tstime, a.tsendtime, a.tsvalue,
  :scenariopid as featureid, a.varid,
  'dh_properties' AS entity_type
FROM bestRating AS a
--This join is not really needed because of the delete above, but may serve as means of QA
LEFT JOIN dh_timeseries AS dupe
ON (
 a.tstime = dupe.tstime 
 AND a.tsendtime = dupe.tsendtime
 AND dupe.featureid = :scenariopid
 AND dupe.entity_type = 'dh_properties'
 AND a.hydroid = dupe.varid
)
WHERE dupe.tid IS NULL;
"

# turn off the expansion of the asterisk
set -f
#Delete previous dh_timeseries entries
echo "Writing sql insert to $RATINGS_SQL_FILE"
echo $ratings_sql
echo -e $ratings_sql > $RATINGS_SQL_FILE 
#cat $RATINGS_SQL_FILE | psql -h $db_host $db_name
echo "Finshed running query."