#!/bin/bash
target=$1
bundle=$2
ftype1=$3
ftype2=$4
DBHOST=$5
DBNAME=$6

q="WITH p6 as (
  select a.hydroid, a.hydrocode, b.dh_geofield_geom as geom
  from dh_feature as a 
  left outer join field_data_dh_geofield as b
  on (
    a.hydroid = b.entity_id
    and b.entity_type = 'dh_feature'
  )
  where a.bundle = '$bundle'
  and a.ftype = '$ftype2'
),
p5 as (
  select a.hydroid, a.hydrocode, b.dh_geofield_geom as geom
  from dh_feature as a 
  left outer join field_data_dh_geofield as b
  on (
    a.hydroid = b.entity_id
    and b.entity_type = 'dh_feature'
  )
  where a.bundle = '$bundle'
  and a.ftype = '$ftype1'
)
SELECT hydrocode from (
  SELECT p6.hydroid, p6.hydrocode,
    p6.geom <-> p5.geom as dist
  FROM p5, p6
  where p5.hydrocode = '$target'
  order by dist
  limit 1
) as foo
"

nearn=`echo $q | psql -t -h $DBHOST $DBNAME --pset="footer=off"`
nearn=`echo $nearn |tr -d " "`
echo $nearn
