
# Script for exporting run data from an h5 to CSV
# Script will have 3 inputs: h5_file_path, output_file_path, and data_source_table 
options(warn=-1)

suppressPackageStartupMessages(library(rhdf5))
suppressPackageStartupMessages(library(R.utils))

# Accepting command arguments:
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 3) {
  message("Use: Rscript export_hsp_h5.R h5_file_path output_file_path data_source_path");
  message("Ex: Rscript export_hsp_h5.R soyN51069.h5 soyN51069.csv /RESULTS/PERLND_P001/PWATER/table")
  q()
}
h5_file_path <- argst[1] # arguments default as class 'character' ; name of the .h5
output_file_path <- argst[2] #name of csv being created
data_source_path <- argst[3] # Path to data table within h5 that begins with /[groupname]

# Reading in table from h5
fid = H5Fopen(h5_file_path) # Opens the h5 file, fid is a h5 identifier
data <- h5read(fid,data_source_path, bit64conversion = "double")
H5close()
data <- data$table
origin <- "1970-01-01"
data$index <- as.POSIXct((data$index)/10^9, origin = origin, tz = "UTC")

# Exporting to a csv
write.table(data,file = output_file_path, sep = ",", row.names = FALSE) # Maybe .csv should be added to the end of file argument?

