# across all months of the year
# do all months and assemble a barplot of R^2
plotBin <- R6Class(
  "plotBin", 
  public = list(
    plot = NULL, data=list(), atts=list(), r_col='',
    initialize = function(plot = NULL, data = list()){ 
      self.plot = plot; self.data=data; 
    }
  )
)



# Week
#This takes in sample data, y_var, x_var, and mo_var and outputs an environment of
#lm stats, residuals, and our r_squared stats we use
mon_lm_stats <- function(sample_data, y_var, x_var, mo_var){
  plot_out <- plotBin$new(data = sample_data)
  plot_out$atts$lms <- list()
  nwd_stats <- data.frame(row.names=c('month', 'rsquared_a'))
  for (i in 1:12) {
    mo_data=sample_data[which((sample_data[,mo_var] == i)),]
    weekmo_data <- lm(mo_data[,y_var] ~ mo_data[,x_var])
    plot_out$atts$lms[[i]] <- weekmo_data
    dsum <- summary(weekmo_data)
    nwd_stats <- rbind(nwd_stats, data.frame(i, dsum$adj.r.squared))
  }
  plot_out$atts$stats <- nwd_stats
  names(plot_out$atts$stats) <- c('mo', 'r_squared')
  return(plot_out)
}

mon_lm_new <- function(sample_data, y_var, x_var, mo_var){
  full_list <- list(resid = list(),
                    fitted = list(),
                    coeff=list(),rsq = numeric(),data=list(), mo = list())
  for (i in 1:12) {
    mo_data=sample_data[which((sample_data[,mo_var] == i)),]
    weekmo_data <- lm(mo_data[,y_var] ~ mo_data[,x_var])
    dsum <- summary(weekmo_data)
    rsq <- dsum$adj.r.squared
    full_list$resid[[i]] <- weekmo_data$residuals
    full_list$fitted[[i]] <- weekmo_data$fitted.values
    full_list$coeff[[i]] <- dsum$coefficients
    full_list$rsq[i] <- rsq
    full_list$data[[i]] <- mo_data
    full_list$mo[[i]] <- i
  }
  
  return(full_list)
}
#Takes in the stats that are output from mon_lm_stats and uses them to generate out barplots
#This also uses data_name and label_name in order to put them on the plot
#Generally we use the precipitation dataset and gageide as a way to generally show these plots
mon_lm_plot <- function(stats,data_name,label_name){
  bp <- barplot(
    stats$r_squared ~ stats$mo,
    ylim=c(0,1.0),
    main=paste("lm(Q ~ P), monthly,",data_name,label_name))
}

# Old function that combined graphing and analysis, deprecated in favor of above
# but kept here in case there are scripts that use it for demo
mon_lm <- function(sample_data, y_var, x_var, mo_var, data_name, label_name){
  plot_out <- plotBin$new(data = sample_data)
  plot_out$atts$lms <- list()
  nwd_stats <- data.frame(row.names=c('month', 'rsquared_a'))
  for (i in 1:12) {
    mo_data=sample_data[which((sample_data[,mo_var] == i)),]
    weekmo_data <- lm(mo_data[,y_var] ~ mo_data[,x_var])
    plot_out$atts$lms[[i]] <- weekmo_data
    dsum <- summary(weekmo_data)
    nwd_stats <- rbind(nwd_stats, data.frame(i, dsum$adj.r.squared))
  }
  plot_out$atts$stats <- nwd_stats
  bp <- barplot(
    nwd_stats$dsum.adj.r.squared ~ nwd_stats$i,
    ylim=c(0,1.0),
    main=paste("lm(Q ~ P), monthly,",data_name,label_name)
  )
  plot_out$r_col <- paste0('r_', data_name)
  names(plot_out$atts$stats) <- c('mo', plot_out$r_col)
  plot_out$plot <- recordPlot()
  return(plot_out)
}