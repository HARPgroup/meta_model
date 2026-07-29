library(sqldf)
argst <- commandArgs(trailingOnly=T)
if (length(argst) < 3) {
  message("Use: update_csv.R src_file dest_file pkcol")
  q()
}
src_file=as.character(argst[1])
dest_file=as.character(argst[2])
pkcol=as.character(argst[3])

sdf <- read.csv(src_file)
ddf <- read.csv(dest_file)

ddf <- sqldf(fn$paste0("select * from ddf where $pkcol not in (select $pkcol from sdf)"))
ddf <- rbind(ddf, sdf)
write.csv(ddf,dest_file)
