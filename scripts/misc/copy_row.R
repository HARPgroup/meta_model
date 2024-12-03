# creates values for newname within a dataset by copying parent watershed's values
# works for both 1 entry per rseg and 1 entry per lrseg
library("sqldf")
#-arguments----
argst <- commandArgs(trailingOnly = T)
if (length(argst) < 4) {
  message("Use: copy_row.R src_file newname srcname keycol [overwrite(=1)]")
  message("Ex: copy_row.R P10/factors/precip.csv newname srcname keycol 1")
  q("no")
}
src_file <- argst[1]
newname <- argst[2]
srcname <- argst[3]
keycol <- argst[4]
overwrite <- 1
if (length(argst) > 4) {
  overwrite <- as.integer(argst[5])
}

#-load file & manipulate----
dtable <- read.csv(src_file, sep=',', check.names = F) 
# Check for existing
xrows <- sqldf(paste0("select * from dtable where ", keycol," = '", newname, "'"))
if (nrow(xrows) >= 1) {
  if (overwrite == 0) {
    message(paste("Entry already exists for",newname,"and overwrite == 0. Exiting."))
    q("no")
  }
}
# remove existing for new line
dtable <- sqldf(paste0("select * from dtable where ", keycol," <> '", newname, "'"))
# create a copy
new_line <- sqldf(paste0("select * from dtable where ", keycol," = '", srcname, "'"))
# append the copy
if (nrow(new_line) > 0) {
  new_line[,keycol] <- newname
  dtable <- rbind(dtable, new_line)
}
#-save----
write.table(dtable,
            file=src_file,
            append = FALSE,
            quote = FALSE,
            sep = ",",
            row.names = FALSE,
            col.names = TRUE)

message('created newname containing parent values')
