#!/bin/bash
# loads the args, the raster specific config and change to temp dir
geo_config=`find_config geo.config`
if [ "$geo_config" = "" ]; then
  geo_config="$META_MODEL_ROOT/models/raster_met/geo/geo.config"
fi
. $geo_config

#Need to confirm that model property is attached to feature
#Need to confirm that scenario property is attached to model property
#Need to send timeseries to db


outfile=`basename $scenarioPropfname`

echo "Deleting previous ratings for ${scenarioPropName} on ${modelPropName} for ${coverage}"
#Run a query to confirm existence of ${modelPropName}
modelProp_sql="
\\set ratingsVarkey '$ratingsVarkey' \n
\\set scenarioPropName '$scenarioPropName' \n
\\set modelPropName '$modelPropName' \n
\\set hydrocode  '$coverage' \n
\\set fname '${scenarioPropfname}' \n
SELECT hydroid AS ratingsVarid FROM dh_variabledefinition WHERE varkey = :'ratingsVarkey' \\gset \n

SELECT p.pid AS scenarioPID 
FROM dh_properties as p 
LEFT JOIN dh_properties as prop 
ON p.featureid = prop.pid 
LEFT JOIN dh_feature as f 
ON prop.featureid = f.hydroid 
WHERE p.propname = :'scenarioPropName' 
AND prop.propname = :'modelPropName' 
AND f.hydrocode = :'hydrocode' \\gset \n

DELETE FROM dh_timeseries
WHERE featureid = :'scenarioPID'
AND varid = :'ratingsVarid'
AND entity_type = 'dh_properties';"

# turn off the expansion of the asterisk
set -f
#Delete previous dh_timeseries entries
echo -e $modelProp_sql > $ratings_sql_file 
cat $ratings_sql_file | psql -h $db_host $db_name

#Insert the ratings files into dh_timeseries under the appropriate scenario property
#Call an RScript to create a batch insert query. Inputs to R script are scenarioPropVarkey, modelPropName, and coverage
modelProp_sql="
insert into dh_timeseries(tstime,tsendtime,tsvalue,featureid,varid,entity_type)
"
# turn off the expansion of the asterisk
set -f
echo -e $modelProp_sql > $scenarioProp_sql_file 
cat $scenarioProp_sql_file | psql -h $db_host $db_name