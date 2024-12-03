# convert WDM format to CSV format
suppressPackageStartupMessages(library(data.table)) 
suppressPackageStartupMessages(library(lubridate))

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 3) {
  message("Usage: Rscript wdm_export_csv_format.R input_path output_path column [add_col] [add_col_val]")
  q()
}
input_path <- argst[1]
output_path <- argst[2]
col_name <- argst[3]
add_col = FALSE # these are reserved for adding things like featureid etc
add_col_val = 0
if (length(argst) >= 4) {
  add_col <- argst[4]
}
if (length(argst) >= 5) {
  add_col_val <- argst[5]
}


dfile <- fread(input_path)
names(dfile) <- c('yr','mo','da','hr', col_name)
dfile$tsendtime <- as.integer(as.POSIXct(make_datetime(dfile$yr,dfile$mo,dfile$da,dfile$hr,tz = Sys.timezone())))
dt <- dfile[2,]$tsendtime - dfile[1,]$tsendtime
dfile$tstime <- dfile$tsendtime - dt
if (!is.logical(add_col)) {
  dfile[,add_col] <- add_col_val
}
write.table(hydr_df, file = output_path, sep = ',', row.names = FALSE, col.names = TRUE, quote = FALSE)
