# Plot generation functions for log metrics

generate_all_plots <- function(analysis_res, plot_dir) {
  if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)
  
  has_ggplot2 <- requireNamespace("ggplot2", quietly = TRUE)
  
  if (has_ggplot2) {
    library(ggplot2)
    cat("Generating charts using ggplot2 ...\n")
    
    # 1. Top 10 URLs
    top_urls_df <- analysis_res$top_urls
    if (nrow(top_urls_df) > 0) {
      top_urls_df$URL_Label <- factor(top_urls_df$URL, levels = rev(top_urls_df$URL))
      p1 <- ggplot(top_urls_df, aes(x = URL_Label, y = Requests, fill = Traffic_Share_Pct)) +
        geom_col(width = 0.7, show.legend = FALSE) +
        coord_flip() +
        scale_fill_gradient(low = "#64b5f6", high = "#0d47a1") +
        geom_text(aes(label = paste0(Requests, " (", Traffic_Share_Pct, "%)")), 
                  hjust = -0.1, size = 3.2, fontface = "bold") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
        labs(
          title = "Top 10 Most Requested Websites / URLs",
          subtitle = "Frequency and traffic share computed via MapReduce",
          x = "URL / Endpoint",
          y = "Total Requests"
        ) +
        theme_minimal(base_size = 11) +
        theme(
          plot.title = element_text(face = "bold", size = 13),
          axis.text.y = element_text(size = 9, face = "bold")
        )
      ggsave(file.path(plot_dir, "plot_top_urls.png"), p1, width = 9, height = 5.5, dpi = 150)
      cat("  [+] Saved: plot_top_urls.png\n")
    }
    
    # 2. Status codes
    status_df <- analysis_res$status_summary
    if (nrow(status_df) > 0) {
      status_colors <- c(
        "2xx Success"      = "#2e7d32",
        "3xx Redirection"  = "#0288d1",
        "4xx Client Error" = "#ed6c02",
        "5xx Server Error" = "#d32f2f",
        "Other"            = "#757575"
      )
      p2 <- ggplot(status_df, aes(x = reorder(Status_Code, -Requests), y = Requests, fill = Class)) +
        geom_col(width = 0.6) +
        scale_fill_manual(values = status_colors) +
        geom_text(aes(label = paste0(Percent, "%")), vjust = -0.4, size = 3.5, fontface = "bold") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
        labs(
          title = "HTTP Status Code Distribution",
          subtitle = "Breakdown of successful responses, redirections, and client/server errors",
          x = "HTTP Status Code",
          y = "Request Count",
          fill = "Status Class"
        ) +
        theme_minimal(base_size = 11) +
        theme(plot.title = element_text(face = "bold", size = 13))
      ggsave(file.path(plot_dir, "plot_status_codes.png"), p2, width = 8, height = 5, dpi = 150)
      cat("  [+] Saved: plot_status_codes.png\n")
    }
    
    # 3. Hourly traffic
    hourly_df <- analysis_res$hourly
    if (nrow(hourly_df) > 0) {
      hourly_df$Idx <- seq_len(nrow(hourly_df))
      p3 <- ggplot(hourly_df, aes(x = Idx, y = Requests)) +
        geom_col(fill = "#90caf9", color = "#1565c0", width = 0.7, alpha = 0.6) +
        geom_line(color = "#d84315", linewidth = 1) +
        geom_point(color = "#d84315", size = 2) +
        scale_x_continuous(breaks = hourly_df$Idx, labels = hourly_df$Timestamp_Hour) +
        labs(
          title = "Traffic Volume Trends Over Time",
          subtitle = "Requests per hour processed across MapReduce chunks",
          x = "Timestamp (Hour)",
          y = "Total Requests"
        ) +
        theme_minimal(base_size = 11) +
        theme(
          plot.title = element_text(face = "bold", size = 13),
          axis.text.x = element_text(angle = 45, hjust = 1, size = 8)
        )
      ggsave(file.path(plot_dir, "plot_traffic_trends.png"), p3, width = 10, height = 5, dpi = 150)
      cat("  [+] Saved: plot_traffic_trends.png\n")
    }
    
    # 4. Top IPs
    top_ips_df <- analysis_res$top_ips
    if (nrow(top_ips_df) > 0) {
      label_col <- if ("Resolved_Hostname" %in% names(top_ips_df)) "Resolved_Hostname" else "IP_Address"
      top_ips_df$IP_Label <- factor(top_ips_df[[label_col]], levels = rev(top_ips_df[[label_col]]))
      p4 <- ggplot(top_ips_df, aes(x = IP_Label, y = Requests, fill = Requests)) +
        geom_col(width = 0.7, show.legend = FALSE) +
        coord_flip() +
        scale_fill_gradient(low = "#80cbc4", high = "#004d40") +
        geom_text(aes(label = paste0(Requests, " (", Traffic_Share_Pct, "%)")), 
                  hjust = -0.1, size = 3.2, fontface = "bold") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
        labs(
          title = "Top 10 Most Active Client IPs / Hostnames",
          subtitle = "Highest volume visitors identified during IP Reduce phase",
          x = "Client IP / Hostname",
          y = "Requests Processed"
        ) +
        theme_minimal(base_size = 11) +
        theme(
          plot.title = element_text(face = "bold", size = 13),
          axis.text.y = element_text(size = 9, face = "bold")
        )
      ggsave(file.path(plot_dir, "plot_top_ips.png"), p4, width = 9, height = 5.5, dpi = 150)
      cat("  [+] Saved: plot_top_ips.png\n")
    }
    
    # 5. Methods
    methods_df <- analysis_res$methods
    if (nrow(methods_df) > 0) {
      p5 <- ggplot(methods_df, aes(x = reorder(Method, -Requests), y = Requests, fill = Method)) +
        geom_col(width = 0.5, show.legend = FALSE) +
        geom_text(aes(label = paste0(Percent, "%")), vjust = -0.4, size = 3.5, fontface = "bold") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
        labs(
          title = "HTTP Request Method Distribution",
          subtitle = "Proportion of GET, POST, HEAD and other request protocols",
          x = "HTTP Method",
          y = "Total Requests"
        ) +
        theme_minimal(base_size = 11) +
        theme(plot.title = element_text(face = "bold", size = 13))
      ggsave(file.path(plot_dir, "plot_http_methods.png"), p5, width = 7, height = 5, dpi = 150)
      cat("  [+] Saved: plot_http_methods.png\n")
    }
    
  } else {
    cat("ggplot2 not available. Using base R graphics ...\n")
    png(file.path(plot_dir, "plot_top_urls.png"), width = 800, height = 500)
    top_urls <- analysis_res$top_urls
    barplot(rev(top_urls$Requests), names.arg = rev(top_urls$URL), horiz = TRUE, 
            las = 1, col = "steelblue", main = "Top 10 Most Requested URLs")
    dev.off()
    
    png(file.path(plot_dir, "plot_status_codes.png"), width = 800, height = 500)
    status_df <- analysis_res$status_summary
    barplot(status_df$Requests, names.arg = status_df$Status_Code, 
            col = "darkorange", main = "HTTP Status Code Distribution")
    dev.off()
  }
}
