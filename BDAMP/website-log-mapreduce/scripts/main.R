# Main MapReduce execution script

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_file <- sub("^--file=", "", file_arg[1])
    return(dirname(normalizePath(script_file)))
  }
  
  try_frame <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(try_frame)) {
    return(dirname(normalizePath(try_frame)))
  }
  
  candidates <- c(
    file.path(getwd(), "website-log-mapreduce", "scripts"),
    file.path(getwd(), "scripts"),
    getwd()
  )
  for (cand in candidates) {
    if (file.exists(file.path(cand, "parser.R"))) {
      return(normalizePath(cand))
    }
  }
  return(file.path(getwd(), "website-log-mapreduce", "scripts"))
}

SCRIPT_DIR  <- get_script_dir()
PROJECT_DIR <- normalizePath(file.path(SCRIPT_DIR, ".."), mustWork = FALSE)

source(file.path(SCRIPT_DIR, "parser.R"))
source(file.path(SCRIPT_DIR, "mapper.R"))
source(file.path(SCRIPT_DIR, "shuffle.R"))
source(file.path(SCRIPT_DIR, "reducer.R"))
source(file.path(SCRIPT_DIR, "analysis.R"))
source(file.path(SCRIPT_DIR, "visualizer.R"))

open_output_directory <- function(output_dir) {
  output_path <- normalizePath(output_dir, mustWork = TRUE)

  if (.Platform$OS.type == "windows") {
    result <- shell.exec(output_path)
  } else if (Sys.info()[["sysname"]] == "Darwin") {
    result <- system2("open", shQuote(output_path))
  } else {
    result <- system2("xdg-open", shQuote(output_path))
  }

  if (!identical(result, 0L) && !is.null(result)) {
    warning("Could not open output directory: ", output_path)
  }

  invisible(output_path)
}

run_website_log_analysis <- function(
  log_file    = NULL,
  client_csv  = NULL,
  chunk_size  = 50000L,
  max_records = 150000L,
  output_dir  = file.path(PROJECT_DIR, "..", "analysis_outputs"),
  plot_dir    = file.path(PROJECT_DIR, "..", "analysis_outputs"),
  open_output = TRUE
) {
  if (is.null(log_file)) {
    candidates <- c(
      file.path(PROJECT_DIR, "data", "sample_access.log"),
      file.path(PROJECT_DIR, "..", "access.log"),
      file.path(PROJECT_DIR, "..", "access (2).log")
    )
    for (c_path in candidates) {
      if (file.exists(c_path)) {
        log_file <- c_path
        break
      }
    }
  }
  
  if (is.null(client_csv)) {
    candidate_csv <- file.path(PROJECT_DIR, "..", "client_hostname.csv")
    if (file.exists(candidate_csv)) client_csv <- candidate_csv
  }
  
  cat("Log File Target :", log_file, "\n")
  cat("Chunk Size      :", format(chunk_size, big.mark = ","), "lines\n\n")
  
  lookup_env <- NULL
  if (!is.null(client_csv) && file.exists(client_csv)) {
    lookup_env <- load_hostname_dictionary(client_csv)
  }
  
  if (!file.exists(log_file)) {
    stop("Input log file does not exist: ", log_file)
  }
  
  con <- file(log_file, open = "r", encoding = "UTF-8")
  on.exit(close(con))
  
  total_read_lines  <- 0L
  total_valid_lines <- 0L
  total_malformed   <- 0L
  chunk_number      <- 0L
  global_reduced    <- NULL
  start_total_time  <- Sys.time()
  
  cat("Processing chunks...\n")
  
  repeat {
    chunk_number <- chunk_number + 1L
    
    lines_to_read <- chunk_size
    if (max_records > 0) {
      remaining <- max_records - total_read_lines
      if (remaining <= 0) break
      if (remaining < chunk_size) lines_to_read <- remaining
    }
    
    raw_chunk <- readLines(con, n = lines_to_read, warn = FALSE)
    n_in_chunk <- length(raw_chunk)
    if (n_in_chunk == 0) break
    
    t_chunk_start <- Sys.time()
    total_read_lines <- total_read_lines + n_in_chunk
    
    parsed_res <- parse_log_chunk(raw_chunk, log_format = "AUTO")
    total_valid_lines <- total_valid_lines + parsed_res$valid_count
    total_malformed   <- total_malformed   + parsed_res$malformed_count
    
    if (parsed_res$valid_count > 0) {
      mapped_streams   <- map_all_metrics(parsed_res$records)
      shuffled_streams <- shuffle_all(mapped_streams)
      chunk_reduced    <- reduce_all_metrics(shuffled_streams)
      global_reduced   <- reduce_merge_chunks(global_reduced, chunk_reduced)
    }
    
    chunk_elapsed <- as.numeric(difftime(Sys.time(), t_chunk_start, units = "secs"))
    cat(sprintf("  Chunk %02d: Read %s lines | Valid: %s | Malformed: %d | Time: %.2f s\n",
                chunk_number,
                format(n_in_chunk, big.mark = ","),
                format(parsed_res$valid_count, big.mark = ","),
                parsed_res$malformed_count,
                chunk_elapsed))
  }
  
  total_time <- as.numeric(difftime(Sys.time(), start_total_time, units = "secs"))
  cat(sprintf("\nProcessing complete: %s lines in %.2f seconds.\n",
              format(total_read_lines, big.mark = ","), total_time))
  
  analysis_report <- generate_analysis_report(
    reduced_metrics = global_reduced,
    lookup_env      = lookup_env,
    total_lines     = total_read_lines,
    valid_lines     = total_valid_lines,
    malformed_lines = total_malformed
  )
  
  export_analysis_results(analysis_report, output_dir)
  generate_all_plots(analysis_report, plot_dir)
  print_console_summary(analysis_report)

  if (isTRUE(open_output)) {
    open_output_directory(output_dir)
  }
  
  return(invisible(list(
    aggregated_data = global_reduced,
    analysis_report = analysis_report,
    execution_time  = total_time
  )))
}

if (sys.nframe() == 0) {
  target_log <- file.path(PROJECT_DIR, "..", "access.log")
  if (!file.exists(target_log)) {
    target_log <- file.path(PROJECT_DIR, "data", "sample_access.log")
  }
  
  run_website_log_analysis(
    log_file    = target_log,
    chunk_size  = 50000L,
    max_records = 100000L
  )
}
