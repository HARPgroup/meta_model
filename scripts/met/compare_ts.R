# Compare two met CSV files
basepath='/var/www/R';
source("/var/www/R/config.R")
library("data.table")

message("Use: Rscript met_compare_ts.R entity_type featureid varkey met_file1 met_file2 ")

lseg="N51660" # H51113 N51047 N51113
scen1="nldas2_resamptile"
scen2="met2date" #"1984010100-2022123123"
met_file1=paste(omsite,"met/out/lseg_csv",scen1,paste0(lseg,".PRC"), sep="/")
met_file2=paste(omsite,"met/out/lseg_csv",scen2,paste0(lseg,".PRC"), sep="/")
met1 <- fread(met_file1)
met2 <- fread(met_file2)
names(met2)
names(met1)
met_co <- sqldf(
  "select a.V1 as yr, a.V2 as mo, a.V3 as da, a.V4 as hr, 
   a.V5 as met1, b.V5 as met2
   from met1 as a 
   left outer join met2 as b
   on (
     a.V1 = b.V1
     and a.V2 = b.V2
     and a.V3 = b.V3
     and a.V4 = b.V4
   )
   where b.V5 is not null
   order by a.V1, a.V2, a.V3, a.V4
  "
)
met_co_daily <-
  sqldf(
    "select yr, mo, da, sum(met1) as met1, sum(met2) as met2
     from met_co
     group by yr, mo, da
    "
  )

plot(met_co_daily$met1 ~ met_co_daily$met2, main=lseg)

quantile(met_co$met1, probs=c(0,0.25,0.5,0.8, 0.9, 0.95,0.99,1.0))
quantile(met_co$met2, probs=c(0,0.25,0.5,0.8, 0.9, 0.95,0.99,1.0))
plot(met_co$met1 ~ met_co$met2)

met_lm <- lm(met_co$met1 ~ met_co$met2)
met_daily_lm <- lm(met_co_daily$met1 ~ met_co_daily$met2)
summary(met_daily_lm)

summary(met_lm)
plot(met_lm)
