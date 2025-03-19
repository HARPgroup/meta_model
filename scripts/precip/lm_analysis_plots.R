# across all months of the year
# do all months and assemble a barplot of R^2
plotBin <- R6Class(
  "plotBin", 
  public = list(
    data=list(), atts=list(), r_col='',
    initialize = function(data = list(), data_is_json = FALSE){ 
      if (!data_is_json) {
        self.data=data; 
      } else {
        self$fromJSON(data)
      }
      
    },
    asJSON = function() {
      self.toJSON()
    },
    toJSON = function() {
      #Write JSON files individually as separate strings/JSON dictionaries
      json_self <- jsonlite::serializeJSON(self)
      json_data <- jsonlite::serializeJSON(self$data, pretty=TRUE)
      json_atts <- jsonlite::serializeJSON(self$atts, pretty=TRUE)
      json_r_col <- jsonlite::serializeJSON(self$r_col, pretty=TRUE)
      #Combine into a single JSON array
      json_out <- paste0("[",json_self,",",json_data,",",json_atts,",",json_r_col,"]")
      
      return(json_out)
    },
    fromJSON = function(jsonFileOrString,fromJSONFile = FALSE) {
      #Method takes two arguments:
      #jsonFileOrString = Either a string with raw serialized JSON or a file
      #                   path to a serialzed plotBin JSON file
      #fromJSONFile = If jsonFileOrString is a file path, this MUST be TRUE.
      #               Otherwise set to FALSE (default)
      
      if(fromJSONFile){
        #If fromJSONFile is TRUE, detect if jsonFileOrString is character data
        #or a URL
        if(grepl("^https?://",jsonFileOrString)){
          #Read the URL as raw character data
          json_out <- RCurl::getURL(jsonFileOrString)
        }else{
          #Read in the raw serialized JSON data as a large character
          json_out <- readChar(jsonFileOrString, file.info(jsonFileOrString)$size)
        }
      }else{
        #JSON is already input by user as character string
        json_out <- jsonFileOrString
      }
      
      #The JSON is coming in as an array of dictionaries. To jsonlite::fromJSON
      #can read these in, but the returned format is a messy, very long list
      #that would take some effort to decipher programatically. Instead, we can
      #parse the JSON for each component of plotBin that we need. This may be
      #more complicated if the object grows significantly, but for now is quite
      #simple. Using regular expression, we group the JSON dictionaries one at a
      #time using parentheses. We search for data after the R6 environment
      #dictionary by specifying our first group is after a literal bracket,
      #literal curly brace, followed by any character any number of times
      #enclosed by },{. We repeatedly look for },{ to find remaining
      #dictionaries
      dictionaryParse <-"\\[\\{.*\\},\\{(.+)\\},\\{(.+)\\},\\{(.*)\\}\\]" 
      #As we select groups, we can store the JSON of that dictionary into a
      #variable and use this variable to populate the various data within
      #plotBin. It's important to note that this method is inherently tied to
      #toJSON(). Any changes in the order with which data is written out in
      #toJSON() must be reflected here
      jsonData <- gsub(dictionaryParse,
                       "\\{\\1\\}",
                       json_out)
      jsonAtts <- gsub(dictionaryParse,
                       "\\{\\2\\}",
                       json_out)
      jsonR_Col <- gsub(dictionaryParse,
                       "\\{\\3\\}",
                       json_out)
      
      #Populate data on self using unserializeJSON to read in the data using the
      #'correct' format from the unserialized style
      self$data <- jsonlite::unserializeJSON(jsonData)
      self$atts <- jsonlite::unserializeJSON(jsonAtts)
      self$r_col <- jsonlite::unserializeJSON(jsonR_Col)
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
    if(nrow(mo_data) >= 3){
      weekmo_data <- lm(mo_data[,y_var] ~ mo_data[,x_var])
      plot_out$atts$lms[[i]] <- weekmo_data
      dsum <- summary(weekmo_data)
      nwd_stats <- rbind(nwd_stats, data.frame(month = i, rsquared_a = dsum$adj.r.squared))
    }else{
      print(paste0("Less than 3 data points for month ",i,". Cannot conduct linear regression. Skipping."))
      plot_out$atts$lms[[i]] <- NA
      nwd_stats <- rbind(nwd_stats, data.frame(month = i, rsquared_a = NA))
    }
  }
  plot_out$atts$stats <- nwd_stats
  names(plot_out$atts$stats) <- c('mo', 'r_squared')
  return(plot_out)
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


# Week
mon_lm <- function(sample_data, y_var, x_var, mo_var, data_name, label_name){
  # deprecated.  
  message("Notice: mon_lm() is deprecated, and now returns only the output pf mon_lm_stats().  PLots can be done by calling mon_lm_plot()")
  return(mon_lm_stats(sample_data, y_var, x_var, mo_var))
}
