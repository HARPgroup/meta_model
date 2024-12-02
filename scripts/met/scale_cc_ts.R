library("sqldf")
col_name = "precip_in"
target_id = "N51137"
src_file = "http://deq1.bse.vt.edu:81/met/nldas2_resamptile/precip/N51137-nldas2-all.csv"
factor_file = "/media/model/met/RCP45_Ensemble_CRT_2041_2070_P10/factors/precip.csv"
dest_file = "/tmp/adjustd_nldas2.csv"

met_data <- read.csv(src_file)
factor_data <- read.csv(factor_file)

target_mo_data <- factor_data[which(factor_data$FIPS_NHL == target_id),]
target_factors <- as.data.frame(t(target_mo_data[,month.abb]))
target_factors$mo <- c(1:nrow(target_factors))
names(target_factors) <- c('pct', 'mo')
target_factors$factor <- (100.0 + target_factors$pct) / 100.0

met_data_adjusted <- sqldf(
  paste0(
    "select a.featureid, a.obs_date, a.tstime, a.tsendtime, a.yr, a.mo, a.da, a.hr, 
     a.",col_name," * b.factor as ", col_name," 
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
