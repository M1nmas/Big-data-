# Web Server Log Parser

REGEX_CLF <- '^(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+\\[(.*?)\\]\\s+"(\\S+)?\\s*(.*?)(?:\\s+(HTTP\\/\\S+))?"\\s+(\\d{3}|-)\\s+(\\d+|-)'
REGEX_COMBINED <- '^(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+\\[(.*?)\\]\\s+"(\\S+)?\\s*(.*?)(?:\\s+(HTTP\\/\\S+))?"\\s+(\\d{3}|-)\\s+(\\d+|-)\\s+"(.*?)"\\s+"(.*?)"'

detect_log_format <- function(sample_lines) {
  combined_matches <- grepl('"[^"]*"\\s+"[^"]*"\\s*$', sample_lines[1:min(5, length(sample_lines))])
  if (mean(combined_matches, na.rm = TRUE) > 0.5) {
    return("COMBINED")
  }
  return("CLF")
}

parse_log_chunk <- function(lines, log_format = "AUTO") {
  total_lines <- length(lines)
  if (total_lines == 0) {
    return(list(records = data.frame(), total_count = 0, valid_count = 0, malformed_count = 0))
  }
  
  if (log_format == "AUTO") {
    log_format <- detect_log_format(lines)
  }
  
  target_regex <- if (log_format == "COMBINED") REGEX_COMBINED else REGEX_CLF
  matches <- regexec(target_regex, lines, perl = TRUE)
  extracted <- regmatches(lines, matches)
  
  valid_indices <- which(vapply(extracted, length, integer(1)) >= 9)
  valid_count <- length(valid_indices)
  malformed_count <- total_lines - valid_count
  
  if (valid_count == 0) {
    return(list(
      records = data.frame(),
      total_count = total_lines,
      valid_count = 0,
      malformed_count = malformed_count
    ))
  }
  
  valid_extracted <- extracted[valid_indices]
  
  ips <- vapply(valid_extracted, `[`, character(1), 2)
  raw_times <- vapply(valid_extracted, `[`, character(1), 5)
  methods <- toupper(vapply(valid_extracted, `[`, character(1), 6))
  raw_urls <- vapply(valid_extracted, `[`, character(1), 7)
  protocols <- vapply(valid_extracted, `[`, character(1), 8)
  statuses <- as.integer(vapply(valid_extracted, `[`, character(1), 9))
  
  raw_bytes <- vapply(valid_extracted, `[`, character(1), 10)
  bytes_num <- as.numeric(ifelse(raw_bytes == "-" | is.na(raw_bytes), "0", raw_bytes))
  
  clean_urls <- sub("\\?.*$", "", raw_urls)
  clean_urls[clean_urls == "" | is.na(clean_urls)] <- "/"
  
  date_strs <- substr(raw_times, 1, 11)
  hour_strs <- as.integer(substr(raw_times, 13, 14))
  parsed_dates <- as.Date(date_strs, format = "%d/%b/%Y")
  
  records <- data.frame(
    ip = ips,
    date = as.character(parsed_dates),
    hour = hour_strs,
    method = methods,
    url = clean_urls,
    protocol = protocols,
    status = statuses,
    bytes = bytes_num,
    stringsAsFactors = FALSE
  )
  
  if (log_format == "COMBINED") {
    records$referer <- vapply(valid_extracted, function(x) if (length(x) >= 11) x[11] else "-", character(1))
    records$user_agent <- vapply(valid_extracted, function(x) if (length(x) >= 12) x[12] else "-", character(1))
  }
  
  return(list(
    records = records,
    total_count = total_lines,
    valid_count = valid_count,
    malformed_count = malformed_count
  ))
}

load_hostname_dictionary <- function(csv_path) {
  if (!file.exists(csv_path)) {
    warning("Hostname mapping file not found at: ", csv_path)
    return(NULL)
  }
  
  cat(sprintf("Loading IP-to-Hostname dictionary from %s ...\n", basename(csv_path)))
  
  if (requireNamespace("data.table", quietly = TRUE)) {
    dt <- data.table::fread(csv_path, select = c("client", "hostname"), showProgress = FALSE)
  } else {
    dt <- read.csv(csv_path, colClasses = c("character", "character", "NULL", "NULL"))
  }
  
  lookup_env <- new.env(hash = TRUE, parent = emptyenv(), size = nrow(dt))
  clients <- dt$client
  hostnames <- dt$hostname
  
  for (i in seq_along(clients)) {
    h <- hostnames[i]
    if (is.na(h) || h == "" || h == "[Errno 1] Unknown host") {
      lookup_env[[clients[i]]] <- clients[i]
    } else {
      lookup_env[[clients[i]]] <- h
    }
  }
  
  cat(sprintf("Dictionary loaded: %s IP mappings indexed in memory.\n", format(length(clients), big.mark = ",")))
  return(lookup_env)
}

resolve_hostnames <- function(ips, lookup_env) {
  if (is.null(lookup_env)) return(ips)
  
  resolved <- vapply(ips, function(ip) {
    h <- lookup_env[[ip]]
    if (is.null(h)) ip else h
  }, character(1), USE.NAMES = FALSE)
  
  return(resolved)
}
