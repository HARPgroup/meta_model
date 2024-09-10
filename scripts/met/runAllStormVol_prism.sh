gage_coverage_file="usgsgageList.csv"
gage_coverage_SQLfile=usgsgageList.sql
gageSQL="
\\set fname '/tmp/${gage_coverage_file}' \n
 

copy ( select hydrocode
FROM dh_feature
WHERE bundle = 'watershed' AND ftype = 'usgs_full_drainage'
) to :'fname';"
# turn off the expansion of the asterisk
set -f
echo -e $gageSQL > $gage_coverage_SQLfile 
cat $gage_coverage_SQLfile | psql -h dbase2 -d drupal.dh03
sftp dbase2:"/tmp/${gage_coverage_file}" "/home/cobrogan/${gage_coverage_file}"

filename="/home/cobrogan/${gage_coverage_file}"
for i in `cat $filename`; do
	echo $i
done

filename="/home/cobrogan/${gage_coverage_file}"
for i in `cat $filename`; do
  echo "Running: sbatch /opt/model/meta_model/run_model raster_met stormVol_nldas2 \"$i\" auto geo"
  sbatch /opt/model/meta_model/run_model raster_met stormVol_nldas2 "$i" auto geo 
done

#First one below giving trouble:
sbatch /opt/model/meta_model/run_model raster_met stormVol_nldas2 "usgs_ws_01613900" auto geo
sbatch /opt/model/meta_model/run_model raster_met stormVol_nldas2 "usgs_ws_01616100" auto geo
