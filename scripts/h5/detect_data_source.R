#Script will detect if a data table path is present in an h5 file
options(warn=-1)
suppressPackageStartupMessages(library(rhdf5))
suppressPackageStartupMessages(library(R.utils))
suppressPackageStartupMessages(library(stringr))

argst <- commandArgs(trailingOnly = T)
h5_file_path <- argst[1]
data_source_path <- argst[2] #path should begin with / and not contain 'table' at the end
#data_source_path <- '/RESULTS/PERLND_P001/PWATER'   #comment out
#h5_file_path <- '/media/model/p532/out/land/h5/for/hsp2_2022/forA51037.h5'   #comment out

fid = H5Fopen(h5_file_path)
data <- try(h5read(fid,data_source_path, bit64conversion = "double"))
if (class(data) == "try-error") {
  var1=0
} else {
  var1=1
}
H5close()
cat(var1)
#Testing is successful for pwater and iwater paths 
# hydr path in a river seg h5?
#Ouputs 1 if data source is present, 0 if not 
