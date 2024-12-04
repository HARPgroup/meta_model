suppressPackageStartupMessages(library("sqldf"))

argst <- commandArgs(trailingOnly = T)
if (length(argst) < 5) {
  message("Use: scale_et_cbp_hargreaves.R base_et_file base_temp_file cc_temp_file col_name cc_et_file")
  message("Ex: scale_et_cbp_hargreaves.R nldas2/et/N51137-nldas2-all.csv nldas2/temp/N51137-nldas2-all.csv cc10/temp/N51137-nldas2-all.csv precip_in cc10/et/N51137-nldas2-all.csv")
  q("no")
}

base_et_file = argst[1]
base_temp_file = argst[2]
cc_temp_file = argst[3]
et_col_name = argst[4]
temp_col_name = argst[5]
cc_et_file = argst[6]

base_et_data <- read.csv(base_et_file)
base_temp_data <- read.csv(base_temp_file)
cc_temp_data <- read.csv(cc_temp_file)

base_temp_data$RS

# Hargreases is in the form ET = K * R * (T + 17.8)
# The proportion of cc to baseline ET would be ETcc / ETbase = (K*R*(Tcc + 17.8) / (K*R*(Tbase + 17.8)
# which simplifies to: (Tcc + 17.8)/(Tbase + 17.8)
et_factors <- ( cc_temp_data[,temp_col_name] + 17.8 ) / ( base_temp_data[,temp_col_name] + 17.8 )
et_factors[which(base_et_data[,et_col_name] <= 0)] <- 1.0
et_fqs <- quantile(et_factors,probs=c(0,0.01,0.10,0.5,0.9,0.99,1.0))
# apply some safe bounds, though this is a kludge just for demonstration purposes
p01 <- as.numeric(et_fqs["1%"])
p99 <- as.numeric(et_fqs["99%"])
et_factors[which(et_factors < p01)] <- p01
et_factors[which(et_factors > p99)] <- p99

cc_et_data <- base_et_data
cc_et_data[,et_col_name] <- et_factors * cc_et_data[,et_col_name]

write.table(cc_et_data,
            file=cc_et_file,
            append = FALSE,
            quote = FALSE,
            sep = ",",
            row.names = FALSE,
            col.names = TRUE)
