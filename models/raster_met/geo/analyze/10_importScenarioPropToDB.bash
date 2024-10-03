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

echo "Checking ${db_name} to confirm that scenario property ${scenarioPropName} exists"
#Run a query to confirm existence of ${modelPropName}
modelProp_sql="
\\set scenarioPropVarkey '$scenarioPropVarkey' \n
\\set scenarioPropName '$scenarioPropName' \n
\\set modelPropName '$modelPropName' \n
\\set fname '${scenarioPropfname}' \n

copy ( 
	SELECT count(*)
	FROM dh_properties as p
	LEFT JOIN dh_variabledefinition as v
	ON (v.varkey = :'scenarioPropVarkey')
	LEFT JOIN dh_properties as modelProp
		ON p.featureid = modelProp.pid
	WHERE modelProp.propname= :'modelPropName'
		AND p.propname = :'scenarioPropName';
	
) to :'scenarioPropfname' WITH HEADER CSV;"

# turn off the expansion of the asterisk
set -f
echo -e $modelProp_sql > $scenarioProp_sql_file 
cat $scenarioProp_sql_file | psql -h $db_host $db_name
#Get file with count
sftp ${db_host}:"${scenarioPropfname}" "${tempdir}/${outfile}"

#If there are no rows, than this model property must be written into $db_name
content=`cat ${tempdir}/${outfile}`
if [ "$content" -eq 0 ];then 
	modelProp_sql="
	\\set scenarioPropVarkey '$scenarioPropVarkey' \n
	\\set scenarioPropName '$scenarioPropName' \n
	\\set modelPropName '$modelPropName' \n
	\\set fname '${scenarioPropfname}' \n
	
	insert into dh_properties(propvalue,featureid,varid,status,module,
						  propname,startdate,enddate,bundle,entity_type)
	SELECT '',p.pid,v.hydroid,1,'',
		:'scenarioPropName','','','dh_properties','dh_properties'
	FROM dh_properties as p
	LEFT JOIN dh_variabledefinition as v
	ON (v.varkey = :'scenarioPropVarkey')
	LEFT JOIN dh_feature as f
	ON p.featureid = f.hydroid
	WHERE f.hydrocode = :'hydrocode'
		AND p.propname = :'modelPropName';"

	# turn off the expansion of the asterisk
	set -f
	echo -e $modelProp_sql > $scenarioProp_sql_file 
	cat $scenarioProp_sql_file | psql -h $db_host $db_name
fi