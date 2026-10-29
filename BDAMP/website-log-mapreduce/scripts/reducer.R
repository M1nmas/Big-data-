# Reducer and Multi-Chunk Combiner functions for MapReduce pipeline

reduce_counts <- function(shuffled_list, col_name = "key") {
  if (length(shuffled_list) == 0) {
    df <- data.frame(key = character(0), count = integer(0), stringsAsFactors = FALSE)
    colnames(df)[1] <- col_name
    return(df)
  }
  
  keys   <- names(shuffled_list)
  counts <- vapply(shuffled_list, sum, numeric(1), USE.NAMES = FALSE)
  
  df <- data.frame(
    key   = keys,
    count = as.integer(counts),
    stringsAsFactors = FALSE
  )
  colnames(df)[1] <- col_name
  return(df)
}

reduce_counts_and_bytes <- function(shuffled_multi, col_name = "key") {
  if (length(shuffled_multi) == 0) {
    df <- data.frame(key = character(0), requests = integer(0), total_bytes = numeric(0), stringsAsFactors = FALSE)
    colnames(df)[1] <- col_name
    return(df)
  }
  
  keys     <- names(shuffled_multi)
  requests <- vapply(shuffled_multi, function(x) sum(x$counts), numeric(1), USE.NAMES = FALSE)
  bytes    <- vapply(shuffled_multi, function(x) sum(x$bytes),  numeric(1), USE.NAMES = FALSE)
  
  df <- data.frame(
    key         = keys,
    requests    = as.integer(requests),
    total_bytes = bytes,
    stringsAsFactors = FALSE
  )
  colnames(df)[1] <- col_name
  return(df)
}

reduce_all_metrics <- function(shuffled_all) {
  list(
    urls       = reduce_counts_and_bytes(shuffled_all$shuffled_urls, "url"),
    ips        = reduce_counts_and_bytes(shuffled_all$shuffled_ips, "ip"),
    status     = reduce_counts(shuffled_all$shuffled_status, "status"),
    hourly     = reduce_counts_and_bytes(shuffled_all$shuffled_hourly, "timestamp"),
    methods    = reduce_counts(shuffled_all$shuffled_methods, "method"),
    errors_404 = reduce_counts(shuffled_all$shuffled_404, "url")
  )
}

# Multi-chunk merge helpers (Combiner)
merge_counts_df <- function(df1, df2, key_col = "key") {
  if (nrow(df1) == 0) return(df2)
  if (nrow(df2) == 0) return(df1)
  
  merged <- merge(df1, df2, by = key_col, all = TRUE)
  merged$count.x[is.na(merged$count.x)] <- 0L
  merged$count.y[is.na(merged$count.y)] <- 0L
  
  result <- data.frame(
    key   = merged[[key_col]],
    count = merged$count.x + merged$count.y,
    stringsAsFactors = FALSE
  )
  colnames(result)[1] <- key_col
  return(result)
}

merge_counts_bytes_df <- function(df1, df2, key_col = "key") {
  if (nrow(df1) == 0) return(df2)
  if (nrow(df2) == 0) return(df1)
  
  merged <- merge(df1, df2, by = key_col, all = TRUE)
  merged$requests.x[is.na(merged$requests.x)] <- 0L
  merged$requests.y[is.na(merged$requests.y)] <- 0L
  merged$total_bytes.x[is.na(merged$total_bytes.x)] <- 0
  merged$total_bytes.y[is.na(merged$total_bytes.y)] <- 0
  
  result <- data.frame(
    key         = merged[[key_col]],
    requests    = merged$requests.x + merged$requests.y,
    total_bytes = merged$total_bytes.x + merged$total_bytes.y,
    stringsAsFactors = FALSE
  )
  colnames(result)[1] <- key_col
  return(result)
}

reduce_merge_chunks <- function(accumulator, chunk_reduced) {
  if (is.null(accumulator)) {
    return(chunk_reduced)
  }
  
  list(
    urls       = merge_counts_bytes_df(accumulator$urls, chunk_reduced$urls, "url"),
    ips        = merge_counts_bytes_df(accumulator$ips, chunk_reduced$ips, "ip"),
    status     = merge_counts_df(accumulator$status, chunk_reduced$status, "status"),
    hourly     = merge_counts_bytes_df(accumulator$hourly, chunk_reduced$hourly, "timestamp"),
    methods    = merge_counts_df(accumulator$methods, chunk_reduced$methods, "method"),
    errors_404 = merge_counts_df(accumulator$errors_404, chunk_reduced$errors_404, "url")
  )
}
