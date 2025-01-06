library("sqldf")

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 5) {
  message("Use: scale_cc_ts.R src_file dest_file target_id col_name factor_file method(mult/add)")
  message("Ex: scale_cc_ts.R src_file nldas2/precip/N51137-nldas2-all.csv cc10/precip/N51137-nldas2-all.csv N51137 precip_in P10/factors/precip.csv")
  q("no")
}

argst <- commandArgs(trailingOnly = T)
src_file = argst[1]
dest_file = argst[2]
target_id = argst[3]
col_name = argst[4]
factor_file = argst[5]
method <- "mult"
if (length(argst) > 5) {
  method = argst[6]
}

met_data <- read.csv(src_file)
factor_data <- read.csv(factor_file)

target_mo_data <- factor_data[which(factor_data$FIPS_NHL == target_id),]
target_factors <- as.data.frame(t(target_mo_data[,month.abb]))
target_factors$mo <- c(1:nrow(target_factors))
names(target_factors) <- c('val', 'mo')
target_factors$factor <- target_factors$val / 100.0

# 2 methods supported: one uses value as a percent, the other, as an additive adjustment
# method mult assuems that the value given is actually percent and needs to be converted to a factor
# additive method assumes value is to be used as is
if (method == 'mult') {
  scale_sql = paste0("(a.",col_name," + a.", col_name," * b.factor) as ", col_name)
}
if (method == 'add') {
  # additive
  scale_sql = paste0("(a.", col_name," + b.val) as ", col_name)
}
met_data_adjusted <- sqldf(
  paste0(
    "select a.featureid, a.obs_date, a.tstime, a.tsendtime, a.yr, a.mo, a.da, a.hr, ",
     scale_sql, "
     from met_data as a 
     left outer join target_factors as b 
     on (a.mo = b.mo)
     order by a.tsendtime
    " 
  )
)

write.table(met_data_adjusted,
            file=dest_file,
            append = FALSE,
            quote = FALSE,
            sep = ",",
            row.names = FALSE,
            col.names = TRUE)
