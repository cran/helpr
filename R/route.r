#' Load an html page from the console.
#' 
#' @param ... site to be loaded
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @export
load_html <- function(...) {
  url_path <- str_c(as.character(substitute(...)), collapse = "/")

  if (str_sub(url_path, end = 1) != "/") {
    url_path <- str_c("/", url_path, collapse = "")
  }

  if (str_sub(url_path, end = 2) == "//") {
    url_path <- str_sub(url_path, start = 2)
  }
  
  browseURL(paste(base_html_path(), url_path, sep = ""), getOption("browser"))
}

#' Base html path needed to load a website.
#' 
#' @param ... site to be loaded
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @keywords internal
base_html_path <- function() {
  str_c("http://127.0.0.1:", tools:::httpdPort, collapse = "")
}

#' Check to see if a package exists.
#' 
#' @param package package in question
#' @keywords internal
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @examples
#'   #check_for_package("stats")
#'   #check_for_package("does_not_exist")
check_for_package <- function(package) {
  package %in% installed_packages()$Package
}


   

#' Start helpr.
#' 
#' @export
#' @param installed use TRUE if the package is installed on from CRAN
#' @author Hadley Wickham and Barret Schloerke \email{schloerke@@gmail.com}
helpr <- function() {
  path <- helpr_path()

  router <- Router$clone()

  # Show list of all packages on home page
  router$get("/index.html", function(...) {
    page_info <- helpr_home()
    page_info$html <- "/index.html"
    render_brew("index", page_info, path = path)
  })

  # Redirect old home location to new
  router$get("/doc/html/index.html", function(...) {
    redirect("/index.html")
  })

  router$get("/", function(...) {
    redirect("/index.html")
  })

  # If package path, missing trailing /, redirect
  router$get("/package/:package", function(package, ...) {
    redirect(str_c("/package/", package, "/"))
  })

  # Package index page, list topics etc
  router$get("/package/:package/", function(package, ...) {
    html <- str_c("/package/", package, "/", collapse = "")
    if (check_for_package(package)) {
      page_info <- helpr_package(package)
      page_info$html <- html
      render_brew("package", page_info, path = path)    
    } else {
      render_brew("whistle", list(package = package, url = deparse(html)), path = path)      
    }
  })
  
  # Package Vignette
  router$get("/package/:package/vignette/:vignette", function(package, vignette, ...) {
    html <- str_c("/package/", package, "/vignette/", vignette, collapse = "")
    if (check_for_package(package)) {
      static_file(system.file("doc", str_c(vignette, ".pdf"), package = package))
    } else {
      render_brew("whistle", list(package = package, url = deparse(html)), path = path)      
    }
  })

  # Package Demo
  router$get("/package/:package/demo/:demo", function(package, demo, ...) {
    html <- str_c("/package/", package, "/demo/", demo, collapse = "")
    page_info <- helpr_demo(package, demo)
    page_info$html <- html
    if (check_for_package(package)) {
      render_brew("demo", page_info, path = path)
    } else {
      render_brew("whistle", list(package = package, url = deparse(html)), path = path)      
    }
  })
  
  # Individual topic source
  router$get("/package/:package/topic/:topic/source", function(package, topic, ...) {
    html <- str_c("/package/", package, "/topic/", topic, "/source", collapse = "")
    page_info <- helpr_function(package, topic)
    page_info$html <- html
    if (check_for_package(package)) {
      render_brew("source", page_info, path = path)
    } else {
      render_brew("whistle", list(package = package, url = deparse(html)), path = path)      
    }
  })

  # Individual help topic
  router$get("/package/:package/topic/:topic", function(package, topic, query, ...) {
    highlight <- ""
    if (!missing(query)) {
      if ("h" %in% names(query)) {
        highlight <- query[names(query) == "h"]
      }
    } else {
      query <- NULL
    }

    query_string <- str_c("?", solr_combine_param(query))
    if (identical(query_string, "?"))
      query_string <- ""
    
    html <- str_c("/package/", package, "/topic/", topic, query_string, collapse = "")
    page_info <- helpr_topic(package, topic, highlight)
    page_info$html <- html
    
    if (check_for_package(package)) {
      render_brew("topic", page_info, path = path)
    } else {
      render_brew("whistle", list(package = package, url = deparse(html)), path = path)      
    }
  })
  router$get("/library/:package/html/:topic.html", function(package, topic, ...) {
    redirect(str_c("/package/", package, "/topic/", topic))
  })
  router$get("/library/:package/help/:topic", function(package, topic) {
    redirect(str_c("/package/", package, "/topic/", topic))
  })

  # Individual help topic with multiple reponses
  router$get("/multiple_help_paths", function(query, ...) {

    pkg <- names(query)
    topic <- unname(query)
    descriptions <- c()
    for(i in seq_along(pkg)) {
      descriptions[i] <- package_description(pkg[i], topic[i])
    }
    
    html <- str_c("/multiple_help_paths?", solr_combine_param(topic, pkg))
    
    render_brew("help", list(pkg = pkg, topic = topic, desc = descriptions, html = html), path = path)
  })
  
  # Search
  router$get("/search", function(query, ...) {
    query_string <- solr_combine_param(query)

    other <- query[! names(query) %in% c("start", "q")]
    query_list <- list(
      start = query[names(query) == "start"],
      query = query[names(query) == "q"],
      other = solr_combine_param(other)
    )
      
    
    html <- str_c("/search?", query_string)
    page_info <- helpr_solr_search(query_list)
    page_info$html <- html
    
    render_brew("search", page_info, path = path)  
  })
  
  
  
  # AJAX
  router$get("/package/old.json", function(...) {
    helpr_render_json(old_package_names())
  })
  router$get("/package/index.json", function(...) {
    helpr_render_json(installed_packages())
  })
  router$get("/package/update.json/:all_packs", function(all_packs, ...) {
    helpr_render_json(update_packs(all_packs))
  })
  router$get("/package/install.json/:pkg", function(pkg, ...) {
    install_packages(pkg)
    helpr_render_json(TRUE)
  })
  router$get("/package/:package/rating.json", function(package, ...) {
    string <- rating_text(package)
    helpr_render_json(string)
  })
  router$get("/package/:package/exec_demo/:demo", function(package, demo, ...) {
    exec_pkg_demo(package, demo)
    helpr_render_json(TRUE)
  })
  router$get("/package/:package/topic/:topic/exec_example", function(package, topic, ...) {
    exec_example(package, topic)
    helpr_render_json(TRUE)
  })

  
  
  # Manual HTML Files
  router$get("/manuals/:name.html", function(name, ...) {
    file_loc <- as.character(subset(get_manuals(), file_name == name, select = "file_loc"))
    static_file(file_loc)
  })
  
  
  
  #execute code  
  router$get("/eval_text/*", function(splat, ...) {
    decoded_text <- URLdecode(splat)
    cat("\n")
    evaluate:::replay.list(evaluate:::evaluate(decoded_text, envir = .GlobalEnv))
    cat(options("prompt")$prompt)

    helpr_render_json(TRUE)
  })

  router$get("/eval_demo/:package~:demo_name", function(package, demo_name, ...) {
		require(package, character.only = TRUE)
    list(payload = evaluate_text(demo_src(package, demo_name), pic_base_name = str_c(package, "_", pkg_version(package),"_demo_", demo_name)))
  })

  router$get("/eval_example/:package~:topic", function(package, topic, ...) {
		require(package, character.only = TRUE)
    list(payload = evaluate_text(reconstruct(untag(pkg_topic(package, topic)$examples), package), pic_base_name = str_c(package, "_", pkg_version(package),"_topic_", topic)))
  })
  

  # Individual help topic 
  router$get("/g", function(...) {
    redirect("package/stats/demo/glm.vr")
  })
  router$get("/n", function(...) {
    redirect("package/stats/topic/nlm")
  })
  

  # pictures
  router$get("/picture/:file_name", function(file_name, ...) {
    file_path <- file.path(base::tempdir(), file_name)
    static_file(file_path)
  })

  # Use file in public, if present
  router$get("/*", function(splat, ...) {
    static_file(file.path(path, "public", splat))
  })

  render_path <- function(path, query, ...) router$route(path, query)
  assignInNamespace("httpd", render_path, "tools")
  if (tools:::httpdPort == 0L) {
    help.start()
    options("help_type" = "html")
    if(!solr_exists()) solr_FAIL()
    
  } else if (FALSE) {
    # load the home page
    load_html()
  }

  return(invisible(router))
}

#' Render JSON
#'
#' Remove the warnings from the rendering of the JSON
#'
#' @param obj object to be rendered
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @keywords internal 
helpr_render_json <- function(obj) {
  suppressWarnings(sinartra:::render_json(obj))
}


#' Helpr Home.
#'
#' @return all the information necessary to produce the home site ("index.html")
#' @author Hadley Wickham and Barret Schloerke \email{schloerke@@gmail.com}
#' @keywords internal 
helpr_home <- function() {

  ten_funcs <- ten_functions()

  last_ten_length <- NROW(ten_funcs$last_ten)
  top_ten_length <- NROW(ten_funcs$top_ten)

  list(
    packages = installed_packages(), 
  
    last_ten_funcs_str = pluralize(
      "Last Function", 
      bool_statement = (last_ten_length > 1), 
      plural = str_c("Last ", last_ten_length, " Functions")
    ),
    last_ten_funcs = ten_funcs$last_ten,
    top_ten_funcs_str = pluralize(
      "Top Function", 
      bool_statement = (top_ten_length > 1), 
      plural = str_c("Top ", top_ten_length, " Functions")
    ),
    top_ten_funcs = ten_funcs$top_ten,
    manuals = get_manuals()
  )
}

#' Route to the topics with multiple files to correct page.
#'
#' Modified from \code{utils:::print.help_files_with_topic}
#'
#' @method print help_files_with_topic
#' @param x path to help
#' @param ... other arguments ignored
#' @author Barret Schloerke \email{schloerke@@gmail.com}
#' @keywords internal 
print.help_files_with_topic <- function (x, ...) 
{
    browser <- getOption("browser")
    topic <- attr(x, "topic")
    type <- attr(x, "type")
    paths <- as.character(x)
    if (!length(paths)) {
        writeLines(c(gettextf("No documentation for '%s' in specified packages and libraries:", 
            topic), gettextf("you could try '??%s'", topic)))
        return(invisible(x))
    }
    if (attr(x, "tried_all_packages")) {
        paths <- unique(dirname(dirname(paths)))
        msg <- gettextf("Help for topic '%s' is not in any loaded package but can be found in the following packages:", 
            topic)
        if (type == "html" && tools:::httpdPort > 0L) {
            path <- file.path(tempdir(), ".R/doc/html")
            dir.create(path, recursive = TRUE, showWarnings = FALSE)
            out <- paste("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n", 
                "<html><head><title>R: help</title>\n", "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=\"UTF-8\">\n", 
                "<link rel=\"stylesheet\" type=\"text/css\" href=\"/doc/html/R.css\">\n", 
                "</head><body>\n\n<hr>\n", sep = "")
            out <- c(out, "<p>", msg, "</p><br>")
            out <- c(out, "<table width=\"100%\" summary=\"R Package list\">\n", 
                "<tr align=\"left\" valign=\"top\">\n", "<td width=\"25%\">Package</td><td>Library</td></tr>\n")
            pkgs <- basename(paths)
            links <- paste("<a href=\"", base_html_path(), 
                "/library/", pkgs, "/help/", topic, "\">", pkgs, 
                "</a>", sep = "")
            out <- c(out, paste("<tr align=\"left\" valign=\"top\">\n", 
                "<td>", links, "</td><td>", dirname(paths), "</td></tr>\n", 
                sep = ""))
            out <- c(out, "</table>\n</p>\n<hr>\n</body></html>")
            writeLines(out, file.path(path, "all.available.html"))
            browseURL(paste(base_html_path(), 
                "/doc/html/all.available.html", sep = ""), browser)
        }
        else {
            writeLines(c(strwrap(msg), "", paste(" ", formatDL(c(gettext("Package"), 
                basename(paths)), c(gettext("Library"), dirname(paths)), 
                indent = 22))))
        }
    }
    else {
        if (tools:::httpdPort == 0L) 
            tools::startDynamicHelp()
        file <- paths
        pkgname <- basename(dirname(dirname(file)))
        topic <- basename(file)

        if (length(pkgname) > 1) {
          browseURL(paste(base_html_path(), 
          "/multiple_help_paths?", solr_combine_param(topic, pkgname), sep = ""), browser)
        } else {
          browseURL(paste(base_html_path(), 
          "/library/", pkgname, "/html/", topic, 
          ".html", sep = ""), browser)            
        }
    }
    invisible(x)
}
