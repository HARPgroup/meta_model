library("sqldf")

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 5) {
  message("Use: scale_cc_ts.R src_file dest_file target_id col_name factor_file")
  message("Ex: scale_cc_ts.R src_file nldas2/precip/N51137-nldas2-all.csv cc10/precip/N51137-nldas2-all.csv N51137 precip_in P10/factors/precip.csv")
  q("no")
}

src_file = argst[1]
dest_file = argst[2]
target_id = argst[3]
col_name = argst[4]
factor_file = argst[5]

met_data <- read.csv(src_file)
factor_data <- read.csv(factor_file)

target_mo_data <- factor_data[which(factor_data$FIPS_NHL == target_id),]
target_factors <- as.data.frame(t(target_mo_data[,month.abb]))
target_factors$mo <- c(1:nrow(target_factors))
names(target_factors) <- c('pct', 'mo')
target_factors$factor <- target_factors$pct / 100.0

# applying a % increase to a negative/positive range is tricky
# we must take the absolute magnitude of the base value when multiplying
# for a + base value and + change, the result is +, a + factor = increase
# for a negative base value and positive change, the result is positive
met_data_adjusted <- sqldf(
  paste0(
    "select a.featureid, a.obs_date, a.tstime, a.tsendtime, a.yr, a.mo, a.da, a.hr, 
     (a.",col_name," + abs(a.", col_name,") * b.factor) as ", col_name," 
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
