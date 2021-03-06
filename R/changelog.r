#' Package news.
#'
#' @param package package name
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @keywords internal
pkg_news <- function(package) {
  package_news <- tryCatch(
    news(package = package),
    error = function(e) 
      NULL)
  if (is.null(package_news)) return(NULL)
  
  # retain only the latest version infomation
  latest <- package_news$Version[1]
  package_news <- package_news[package_news$Version %in% latest, ]
  
  list(
    title = "Change Log",
    date = unique(package_news$Version),
    news = split(package_news$Text, addNA(package_news$Category))
  )
}

#' Function news.
#'
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @param package package name
#' @param topic demo name
#' @keywords internal
function_news <- function(package, topic) {
  package_news <- news(package = package)
  if (is.null(package_news)) return("")
  
  # retain only the infomation that contains the topic name
  package_news <- package_news[str_detect(package_news$Text, topic), ]
  if (!dataframe_has_rows(package_news)) return("")
    
  package_news$title <- str_c(package_news$Version, " - ", package_news$Category)
  
  list(
    title = str_c("Change Log for '", topic, "'", collapse = ""),
    news = split(package_news$Text, addNA(package_news$title))
  )
}



#' Locate all R manuals on the local computer.
#'
#' @keywords internal
#' @author Barret Schloerke \email{schloerke@@gmail.com}
get_manuals <- memoise(function() {
  # get files in the manual directory with full path
  manual_dir <- file.path(Sys.getenv("R_DOC_DIR"), "manual")
  manuals <- dir(manual_dir)
  
  file_loc <- file.path(manual_dir, manuals)
  file_name <- str_replace_all(manuals, ".html", "")
  link <- str_c("manuals/", file_name, ".html")

	if(link == "manuals/.html")
		link <- character(0)

  data.frame(
    title = sapply(file_loc, function(x) {
      strip_html(readLines(x, 3)[3])
    }),
    file_loc = file_loc,
    link = link,
    file_name = file_name,
    stringsAsFactors = FALSE
  )
})
