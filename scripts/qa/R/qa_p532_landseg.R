hostname = Sys.info()["nodename"]
basepath='/var/www/R';
source("/var/www/R/config.R")
options(scipen = 999)


argst <- commandArgs(trailingOnly = T)
if (length(argst) < 5) {
  message("Use: qa_p532_landseg met_scenario landseg")
  message("Ex: qa_p532_landseg nldas2rst A51149")
  q("no")
}
met_scenario = argst[1]
land_scenario = argst[2]
landseg = argst[3]

all_params <- c('PRC', 'TMP', 'PET', 'DPT', 'WND', 'RAD')
for (param in all_params) {
  iuri = paste0("/media/model/met/", met_scenario,"/lseg_csv/", landseg, ".", param)
  if ((substr(hostname, 1, 3) != "deq") && (substr(iuri,1,4) != "http")) {
    iuri <- stringr::str_replace(iuri,"/media/model", omsite)
  }
  met_data <- read.csv(iuri, header = FALSE)
  quantile(met_data$V5)
  if (param == 'PRC') {
    op = "sum"
  } else if (param == 'PET') {
    op = "sum"
  } else if (param == 'TMP') {
    op = "avg"
  } else {
    op = "avg"
  }
  yr_mo_data <- fn$sqldf(
    "
      select V1 as yr, V2 as mo, V1 || '-' || V2 as yr_mo,
        $op(V5) as $op
      from met_data
      group by V1, V2
      order by V1, V2
    ")
  barplot(
    yr_mo_data[,op] ~ yr_mo_data$yr_mo,
    main=paste(landseg, param, met_scenario)
  )
}


# show parameters
iuri = "/opt/model/p53/p532c-sova/input/param/for/p532sova_2021/PWATER.csv"
if ((substr(hostname, 1, 3) != "deq") && (substr(iuri,1,4) != "http")) {
  iuri <- stringr::str_replace(iuri,"/opt/model/p53/p532c-sova/", paste0(omsite,"/p532/" ))
}
pwater <- read.csv(iuri, header = FALSE)
names(pwater) <- paste(pwater[1,], pwater[2,])
pwater <- pwater[3:nrow(pwater),]

