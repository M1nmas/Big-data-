# Map functions for MapReduce pipeline

map_urls <- function(records) {
  if (nrow(records) == 0) return(data.frame(key = character(0), count = integer(0), bytes = numeric(0)))
  data.frame(
    key   = records$url,
    count = 1L,
    bytes = records$bytes,
    stringsAsFactors = FALSE
  )
}

map_client_ips <- function(records) {
  if (nrow(records) == 0) return(data.frame(key = character(0), count = integer(0), bytes = numeric(0)))
  data.frame(
    key   = records$ip,
    count = 1L,
    bytes = records$bytes,
    stringsAsFactors = FALSE
  )
}

map_status_codes <- function(records) {
  if (nrow(records) == 0) return(data.frame(key = character(0), value = integer(0)))
  data.frame(
    key   = as.character(records$status),
    value = 1L,
    stringsAsFactors = FALSE
  )
}

map_hourly_traffic <- function(records) {
  if (nrow(records) == 0) return(data.frame(key = character(0), count = integer(0), bytes = numeric(0)))
  hourly_keys <- paste0(records$date, " ", sprintf("%02d:00", records$hour))
  data.frame(
    key   = hourly_keys,
    count = 1L,
    bytes = records$bytes,
    stringsAsFactors = FALSE
  )
}

map_http_methods <- function(records) {
  if (nrow(records) == 0) return(data.frame(key = character(0), value = integer(0)))
  data.frame(
    key   = records$method,
    value = 1L,
    stringsAsFactors = FALSE
  )
}

map_404_errors <- function(records) {
  error_idx <- which(records$status == 404)
  if (length(error_idx) == 0) {
    return(data.frame(key = character(0), value = integer(0), stringsAsFactors = FALSE))
  }
  data.frame(
    key   = records$url[error_idx],
    value = 1L,
    stringsAsFactors = FALSE
  )
}

map_all_metrics <- function(records) {
  list(
    url_map      = map_urls(records),
    ip_map       = map_client_ips(records),
    status_map   = map_status_codes(records),
    hourly_map   = map_hourly_traffic(records),
    method_map   = map_http_methods(records),
    error404_map = map_404_errors(records)
  )
}
