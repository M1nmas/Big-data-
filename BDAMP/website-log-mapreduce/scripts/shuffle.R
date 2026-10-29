# Shuffle and Sort functions for MapReduce pipeline

shuffle_single_value <- function(mapped_df) {
  if (nrow(mapped_df) == 0) return(list())
  grouped <- split(mapped_df$value, mapped_df$key)
  sorted_keys <- sort(names(grouped))
  return(grouped[sorted_keys])
}

shuffle_multi_value <- function(mapped_df) {
  if (nrow(mapped_df) == 0) return(list())
  
  counts_by_key <- split(mapped_df$count, mapped_df$key)
  bytes_by_key  <- split(mapped_df$bytes, mapped_df$key)
  sorted_keys   <- sort(names(counts_by_key))
  
  shuffled_groups <- vector("list", length(sorted_keys))
  names(shuffled_groups) <- sorted_keys
  
  for (k in sorted_keys) {
    shuffled_groups[[k]] <- list(
      counts = counts_by_key[[k]],
      bytes  = bytes_by_key[[k]]
    )
  }
  
  return(shuffled_groups)
}

shuffle_all <- function(mapped_streams) {
  list(
    shuffled_urls     = shuffle_multi_value(mapped_streams$url_map),
    shuffled_ips      = shuffle_multi_value(mapped_streams$ip_map),
    shuffled_status   = shuffle_single_value(mapped_streams$status_map),
    shuffled_hourly   = shuffle_multi_value(mapped_streams$hourly_map),
    shuffled_methods  = shuffle_single_value(mapped_streams$method_map),
    shuffled_404      = shuffle_single_value(mapped_streams$error404_map)
  )
}
