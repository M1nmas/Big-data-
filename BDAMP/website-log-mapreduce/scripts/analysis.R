# Analysis and reporting functions for log metrics

generate_analysis_report <- function(reduced_metrics, lookup_env = NULL, 
                                     total_lines = 0, valid_lines = 0, malformed_lines = 0) {
  
  total_requests   <- sum(reduced_metrics$urls$requests)
  unique_urls      <- nrow(reduced_metrics$urls)
  unique_ips       <- nrow(reduced_metrics$ips)
  total_bytes      <- sum(reduced_metrics$urls$total_bytes)
  total_mb         <- round(total_bytes / (1024^2), 2)
  total_gb         <- round(total_bytes / (1024^3), 3)
  avg_bytes_per_req<- if (total_requests > 0) round(total_bytes / total_requests, 2) else 0
  
  status_404_row   <- reduced_metrics$status[reduced_metrics$status$status == "404", ]
  count_404        <- if (nrow(status_404_row) > 0) status_404_row$count else 0
  error_404_rate   <- if (total_requests > 0) round((count_404 / total_requests) * 100, 2) else 0
  
  kpi_summary <- data.frame(
    Metric = c(
      "Total Raw Lines Read",
      "Valid Records Parsed",
      "Malformed Lines Dropped",
      "Total Valid Requests",
      "Unique URLs Requested",
      "Unique Client IPs",
      "Total Bandwidth Served (MB)",
      "Total Bandwidth Served (GB)",
      "Average Transfer / Request (Bytes)",
      "Total 404 (Not Found) Errors",
      "404 Error Rate (%)"
    ),
    Value = c(
      format(total_lines, big.mark = ","),
      format(valid_lines, big.mark = ","),
      format(malformed_lines, big.mark = ","),
      format(total_requests, big.mark = ","),
      format(unique_urls, big.mark = ","),
      format(unique_ips, big.mark = ","),
      as.character(total_mb),
      as.character(total_gb),
      as.character(avg_bytes_per_req),
      format(count_404, big.mark = ","),
      paste0(error_404_rate, "%")
    ),
    stringsAsFactors = FALSE
  )
  
  # Top 10 URLs
  urls_df <- reduced_metrics$urls[order(-reduced_metrics$urls$requests), ]
  top_10_urls <- head(urls_df, 10)
  top_10_urls$rank <- seq_len(nrow(top_10_urls))
  top_10_urls$share_pct <- round((top_10_urls$requests / total_requests) * 100, 2)
  top_10_urls$total_mb  <- round(top_10_urls$total_bytes / (1024^2), 2)
  top_10_urls <- top_10_urls[, c("rank", "url", "requests", "share_pct", "total_mb")]
  colnames(top_10_urls) <- c("Rank", "URL", "Requests", "Traffic_Share_Pct", "Bandwidth_MB")
  rownames(top_10_urls) <- NULL
  
  # Top 10 Client IPs
  ips_df <- reduced_metrics$ips[order(-reduced_metrics$ips$requests), ]
  top_10_ips <- head(ips_df, 10)
  top_10_ips$rank <- seq_len(nrow(top_10_ips))
  top_10_ips$share_pct <- round((top_10_ips$requests / total_requests) * 100, 2)
  top_10_ips$total_mb  <- round(top_10_ips$total_bytes / (1024^2), 2)
  
  if (!is.null(lookup_env)) {
    top_10_ips$hostname <- resolve_hostnames(top_10_ips$ip, lookup_env)
    top_10_ips <- top_10_ips[, c("rank", "ip", "hostname", "requests", "share_pct", "total_mb")]
    colnames(top_10_ips) <- c("Rank", "IP_Address", "Resolved_Hostname", "Requests", "Traffic_Share_Pct", "Bandwidth_MB")
  } else {
    top_10_ips <- top_10_ips[, c("rank", "ip", "requests", "share_pct", "total_mb")]
    colnames(top_10_ips) <- c("Rank", "IP_Address", "Requests", "Traffic_Share_Pct", "Bandwidth_MB")
  }
  rownames(top_10_ips) <- NULL
  
  # Status distribution
  status_df <- reduced_metrics$status[order(-reduced_metrics$status$count), ]
  status_df$status_code <- as.integer(status_df$status)
  status_df$category <- ifelse(status_df$status_code >= 200 & status_df$status_code < 300, "2xx Success",
                        ifelse(status_df$status_code >= 300 & status_df$status_code < 400, "3xx Redirection",
                        ifelse(status_df$status_code >= 400 & status_df$status_code < 500, "4xx Client Error",
                        ifelse(status_df$status_code >= 500 & status_df$status_code < 600, "5xx Server Error", "Other"))))
  status_df$share_pct <- round((status_df$count / total_requests) * 100, 2)
  status_summary <- status_df[, c("status", "category", "count", "share_pct")]
  colnames(status_summary) <- c("Status_Code", "Class", "Requests", "Percent")
  rownames(status_summary) <- NULL
  
  # HTTP Methods
  method_df <- reduced_metrics$methods[order(-reduced_metrics$methods$count), ]
  method_df$share_pct <- round((method_df$count / total_requests) * 100, 2)
  colnames(method_df) <- c("Method", "Requests", "Percent")
  rownames(method_df) <- NULL
  
  # Top 404 Errors
  errors_404_df <- reduced_metrics$errors_404[order(-reduced_metrics$errors_404$count), ]
  top_10_404 <- head(errors_404_df, 10)
  if (nrow(top_10_404) > 0) {
    top_10_404$rank <- seq_len(nrow(top_10_404))
    top_10_404$share_of_errors <- round((top_10_404$count / count_404) * 100, 2)
    top_10_404 <- top_10_404[, c("rank", "url", "count", "share_of_errors")]
    colnames(top_10_404) <- c("Rank", "Missing_URL", "Error_Count", "Share_Of_404s_Pct")
    rownames(top_10_404) <- NULL
  }
  
  # Hourly trends
  hourly_df <- reduced_metrics$hourly[order(reduced_metrics$hourly$timestamp), ]
  hourly_df$total_mb <- round(hourly_df$total_bytes / (1024^2), 2)
  colnames(hourly_df) <- c("Timestamp_Hour", "Requests", "Total_Bytes", "Total_MB")
  rownames(hourly_df) <- NULL
  
  # Anomaly indicators
  ip_requests <- reduced_metrics$ips$requests
  mean_req    <- mean(ip_requests)
  sd_req      <- sd(ip_requests)
  threshold   <- if (!is.na(sd_req) && sd_req > 0) mean_req + (3 * sd_req) else mean_req * 5
  anomalous_ips <- reduced_metrics$ips[reduced_metrics$ips$requests >= threshold, ]
  
  if (nrow(anomalous_ips) > 0) {
    anomalous_ips <- anomalous_ips[order(-anomalous_ips$requests), ]
    anomalous_ips$share_pct <- round((anomalous_ips$requests / total_requests) * 100, 2)
    anomalous_ips$total_mb  <- round(anomalous_ips$total_bytes / (1024^2), 2)
    anomalous_ips$flag_reason <- "High Request Volume (Potential Automated Crawler/Aggressive Script)"
    
    if (!is.null(lookup_env)) {
      anomalous_ips$hostname <- resolve_hostnames(anomalous_ips$ip, lookup_env)
      anomalous_ips <- anomalous_ips[, c("ip", "hostname", "requests", "share_pct", "total_mb", "flag_reason")]
    } else {
      anomalous_ips <- anomalous_ips[, c("ip", "requests", "share_pct", "total_mb", "flag_reason")]
    }
  } else {
    anomalous_ips <- data.frame(Message = "No significant anomalous volume outliers detected.")
  }
  
  return(list(
    kpis           = kpi_summary,
    top_urls       = top_10_urls,
    top_ips        = top_10_ips,
    status_summary = status_summary,
    methods        = method_df,
    top_404        = top_10_404,
    hourly         = hourly_df,
    anomalies      = anomalous_ips
  ))
}

export_analysis_results <- function(analysis_res, output_dir) {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  write.csv(analysis_res$kpis,           file.path(output_dir, "kpi_summary.csv"), row.names = FALSE)
  write.csv(analysis_res$top_urls,       file.path(output_dir, "top_10_urls.csv"), row.names = FALSE)
  write.csv(analysis_res$top_ips,        file.path(output_dir, "top_10_ips.csv"), row.names = FALSE)
  write.csv(analysis_res$status_summary, file.path(output_dir, "status_distribution.csv"), row.names = FALSE)
  write.csv(analysis_res$methods,        file.path(output_dir, "http_methods.csv"), row.names = FALSE)
  write.csv(analysis_res$top_404,        file.path(output_dir, "top_404_errors.csv"), row.names = FALSE)
  write.csv(analysis_res$hourly,         file.path(output_dir, "hourly_traffic.csv"), row.names = FALSE)
  write.csv(analysis_res$anomalies,      file.path(output_dir, "anomaly_indicators.csv"), row.names = FALSE)
  
  cat(sprintf("[Export] Analysis tables saved to: %s\n", output_dir))
}

print_console_summary <- function(res) {
  cat("\n==============================================================================\n")
  cat("                WEBSITE LOG ANALYSIS PROJECT SUMMARY REPORT                   \n")
  cat("==============================================================================\n\n")
  
  cat("--- 1. PROJECT METRICS & KPIS ---\n")
  print(res$kpis, row.names = FALSE)
  cat("\n")
  
  cat("--- 2. TOP 10 MOST REQUESTED WEBSITES / URLS ---\n")
  print(res$top_urls, row.names = FALSE)
  cat("\n")
  
  cat("--- 3. TOP 10 ACTIVE CLIENT IP ADDRESSES ---\n")
  print(res$top_ips, row.names = FALSE)
  cat("\n")
  
  cat("--- 4. HTTP STATUS CODE DISTRIBUTION ---\n")
  print(res$status_summary, row.names = FALSE)
  cat("\n")
  
  cat("--- 5. HTTP REQUEST METHODS ---\n")
  print(res$methods, row.names = FALSE)
  cat("\n")
  
  if (nrow(res$top_404) > 0) {
    cat("--- 6. TOP 404 (NOT FOUND) ERROR RESOURCES ---\n")
    print(res$top_404, row.names = FALSE)
    cat("\n")
  }
  
  cat("--- 7. ANOMALOUS TRAFFIC INDICATORS (Requiring Investigation) ---\n")
  print(head(res$anomalies, 5), row.names = FALSE)
  cat("\n==============================================================================\n")
}
