#!/bin/bash
# loads the args, the raster specific config and change to temp dir
geo_config=`find_config geo.config`
if [ "$geo_config" = "" ]; then
  geo_config="$META_MODEL_ROOT/models/raster_met/geo/geo.config"
fi
. $geo_config

#Put the new ratings files with variables for dh_timeseries onto dbase2
baseFileName=`basename RATINGS_TODBASE_FILE`
sftp dbase2:"/tmp/${baseFileName}" <<< "put ${RATINGS_TODBASE_FILE}"

#Create a temporary table to read in the ratings files into dbase2. Then join and insert into dh_timeseries
ratings_sql="
\\set ratingsVarkey '$RATINGS_VARKEY' \n
\\set scenarioPropName '$SCENARIO_PROP_NAME' \n
\\set hydrocode  '$coverage' \n
SELECT hydroid AS ratingsVarid FROM dh_variabledefinition WHERE varkey = :'ratingsVarkey' \\gset \n

CREATE TEMPORARY TABLE tmp_ratings as
SELECT tstime,tsendtime,tsvalue,featureid,entity_type
FROM dh_timeseries
LIMIT 0;

COPY tmp_ratings FROM '${RATINGS_DBASE_FILE}' with csv header;

INSERT INTO dh_timeseries ( tstime,tsendtime, tsvalue, featureid, varid, entity_type)
SELECT a.tstime, a.tsendtime, a.tsvalue, a.featureid, v.hydroid, a.entity_type
FROM tmp_ratings AS a
LEFT JOIN dh_variabledefinition as v
ON v.hydroid = :'hydroid'
LEFT JOIN dh_timeseries AS dupe
ON (
 a.tstime = dupe.tstime 
 AND a.tsendtime = dupe.tsendtime
 AND a.featureid = dupe.featureid
 AND a.entity_type = dupe.entity_type
 AND v.hydroid = dupe.varid
)
WHERE dupe.tid IS NULL;

UPDATE dh_timeseries AS a SET
    tstime = b.tstime,
    tsendtime = b.tsendtime,
	tsvalue = b.tsvalue,
	featureid = b.featureid,
	varid = b.varid,
	entity_type = b.entity_type
from (
	SELECT a.tstime, a.tsendtime, a.tsvalue, a.featureid, v.hydroid as varid, a.entity_type
	FROM tmp_ratings AS a
	LEFT JOIN dh_variabledefinition as v
	ON v.hydroid = :'hydroid'
	LEFT JOIN dh_timeseries AS dupe
	ON (
	a.tstime = dupe.tstime 
		AND a.tsendtime = dupe.tsendtime
		AND a.featureid = dupe.featureid
		AND a.entity_type = dupe.entity_type
	)
	WHERE dupe.tid IS NOT NULL) as b;
"

# turn off the expansion of the asterisk
set -f
#Delete previous dh_timeseries entries
echo -e $ratings_sql > $ratings_sql_file 
cat $ratings_sql_file | psql -h $db_host $db_name