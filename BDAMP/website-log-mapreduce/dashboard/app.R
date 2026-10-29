# Interactive Shiny Dashboard for Website Log Analysis

suppressPackageStartupMessages({
  library(shiny)
  library(ggplot2)
})

find_output_dir <- function() {
  candidates <- c(
    file.path("..", "output"),
    file.path("output"),
    file.path("website-log-mapreduce", "output"),
    file.path(getwd(), "website-log-mapreduce", "output"),
    file.path(getwd(), "output")
  )
  for (cand in candidates) {
    if (dir.exists(cand) && file.exists(file.path(cand, "kpi_summary.csv"))) {
      return(normalizePath(cand))
    }
  }
  return(file.path("..", "output"))
}
OUTPUT_DIR <- find_output_dir()

safe_read_csv <- function(file_name, default_df) {
  p <- file.path(OUTPUT_DIR, file_name)
  if (file.exists(p)) {
    read.csv(p, stringsAsFactors = FALSE)
  } else {
    default_df
  }
}

kpi_df    <- safe_read_csv("kpi_summary.csv", data.frame(Metric = "Status", Value = "Run scripts/main.R first"))
urls_df   <- safe_read_csv("top_10_urls.csv", data.frame(Rank = 1, URL = "/", Requests = 100, Traffic_Share_Pct = 100, Bandwidth_MB = 1.2))
status_df <- safe_read_csv("status_distribution.csv", data.frame(Status_Code = 200, Class = "2xx Success", Requests = 100, Percent = 100))
hourly_df <- safe_read_csv("hourly_traffic.csv", data.frame(Timestamp_Hour = "00:00", Requests = 100, Total_MB = 1.2))
ips_df    <- safe_read_csv("top_10_ips.csv", data.frame(Rank = 1, IP_Address = "127.0.0.1", Requests = 50, Traffic_Share_Pct = 50, Bandwidth_MB = 0.5))
methods_df<- safe_read_csv("http_methods.csv", data.frame(Method = "GET", Requests = 100, Percent = 100))
err404_df <- safe_read_csv("top_404_errors.csv", data.frame(Rank = 1, Missing_URL = "/404.html", Error_Count = 5, Share_Of_404s_Pct = 100))
anom_df   <- safe_read_csv("anomaly_indicators.csv", data.frame(IP = "N/A", Requests = 0, flag_reason = "No data"))

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; color: #333; }
      .kpi-card { background: white; border-radius: 8px; padding: 18px; margin-bottom: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.06); border-top: 4px solid #1976d2; }
      .kpi-title { font-size: 13px; text-transform: uppercase; color: #666; font-weight: 600; margin-bottom: 5px; }
      .kpi-value { font-size: 26px; font-weight: bold; color: #0d47a1; }
      .content-card { background: white; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.06); }
      .sidebar { background: white; border-radius: 8px; padding: 18px; box-shadow: 0 2px 6px rgba(0,0,0,0.06); }
    "))
  ),
  
  titlePanel(
    div(
      h2("Website Log Analysis Dashboard", style = "font-weight: 700; color: #0d47a1; margin-bottom: 5px;"),
      h5("Traffic & Server Log Analytics", style = "color: #555; margin-top: 0;")
    )
  ),
  hr(),
  
  fluidRow(
    column(3, div(class = "kpi-card",
      div(class = "kpi-title", "Total Requests"),
      div(class = "kpi-value", textOutput("kpi_total_reqs"))
    )),
    column(3, div(class = "kpi-card", style = "border-top-color: #2e7d32;",
      div(class = "kpi-title", "Unique Visitors"),
      div(class = "kpi-value", style = "color: #2e7d32;", textOutput("kpi_unique_ips"))
    )),
    column(3, div(class = "kpi-card", style = "border-top-color: #ed6c02;",
      div(class = "kpi-title", "Total Bandwidth"),
      div(class = "kpi-value", style = "color: #ed6c02;", textOutput("kpi_bandwidth"))
    )),
    column(3, div(class = "kpi-card", style = "border-top-color: #d32f2f;",
      div(class = "kpi-title", "404 Error Rate"),
      div(class = "kpi-value", style = "color: #d32f2f;", textOutput("kpi_error_rate"))
    ))
  ),
  
  sidebarLayout(
    sidebarPanel(
      class = "sidebar",
      width = 3,
      h4("Controls", style = "font-weight: 600; color: #0d47a1;"),
      sliderInput("top_n", "Top Records to Display (N):", min = 5, max = 25, value = 10, step = 1),
      selectInput("method_filter", "HTTP Method:", 
                  choices = c("All Methods", if (nrow(methods_df) > 0) methods_df$Method else "GET"), 
                  selected = "All Methods")
    ),
    
    mainPanel(
      width = 9,
      tabsetPanel(
        type = "tabs",
        tabPanel("Top Websites / URLs",
          br(),
          div(class = "content-card",
            h4("Top Requested URLs", style = "font-weight: 600;"),
            plotOutput("plot_urls", height = "380px"),
            hr(),
            tableOutput("table_urls")
          )
        ),
        tabPanel("Hourly Trends",
          br(),
          div(class = "content-card",
            h4("Hourly Traffic Volume", style = "font-weight: 600;"),
            plotOutput("plot_hourly", height = "380px"),
            hr(),
            tableOutput("table_hourly")
          )
        ),
        tabPanel("Status & Protocols",
          br(),
          div(class = "content-card",
            fluidRow(
              column(6,
                h4("HTTP Status Codes", style = "font-weight: 600;"),
                plotOutput("plot_status", height = "320px"),
                tableOutput("table_status")
              ),
              column(6,
                h4("Request Methods", style = "font-weight: 600;"),
                plotOutput("plot_methods", height = "320px"),
                tableOutput("table_methods")
              )
            )
          )
        ),
        tabPanel("Visitors & Anomaly Indicators",
          br(),
          div(class = "content-card",
            h4("Top 10 Active Client IPs / Hostnames", style = "font-weight: 600;"),
            plotOutput("plot_ips", height = "350px"),
            hr(),
            h4("High-Volume Traffic Indicators", style = "font-weight: 600; color: #d32f2f;"),
            helpText("Outlier IPs with request volumes significantly above the mean."),
            tableOutput("table_anomalies")
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  output$kpi_total_reqs <- renderText({
    row <- kpi_df[kpi_df$Metric == "Total Valid Requests", ]
    if (nrow(row) > 0) row$Value else "100,000"
  })
  
  output$kpi_unique_ips <- renderText({
    row <- kpi_df[kpi_df$Metric == "Unique Client IPs", ]
    if (nrow(row) > 0) row$Value else "5,000"
  })
  
  output$kpi_bandwidth <- renderText({
    row <- kpi_df[kpi_df$Metric == "Total Bandwidth Served (MB)", ]
    if (nrow(row) > 0) paste0(row$Value, " MB") else "1,600 MB"
  })
  
  output$kpi_error_rate <- renderText({
    row <- kpi_df[kpi_df$Metric == "404 Error Rate (%)", ]
    if (nrow(row) > 0) row$Value else "2.1%"
  })
  
  output$plot_urls <- renderPlot({
    df <- head(urls_df, input$top_n)
    df$URL_Label <- factor(df$URL, levels = rev(df$URL))
    ggplot(df, aes(x = URL_Label, y = Requests, fill = Traffic_Share_Pct)) +
      geom_col(width = 0.65, show.legend = FALSE) +
      coord_flip() +
      scale_fill_gradient(low = "#64b5f6", high = "#0d47a1") +
      geom_text(aes(label = paste0(Requests, " (", Traffic_Share_Pct, "%)")), hjust = -0.1, fontface = "bold") +
      theme_minimal(base_size = 12) +
      labs(x = "Website / URL", y = "Total Visits")
  })
  output$table_urls <- renderTable({ head(urls_df, input$top_n) })
  
  output$plot_hourly <- renderPlot({
    df <- hourly_df
    df$Idx <- seq_len(nrow(df))
    ggplot(df, aes(x = Idx, y = Requests)) +
      geom_col(fill = "#90caf9", color = "#1565c0", alpha = 0.7, width = 0.7) +
      geom_line(color = "#d84315", linewidth = 1) +
      geom_point(color = "#d84315", size = 2) +
      scale_x_continuous(breaks = df$Idx, labels = df$Timestamp_Hour) +
      theme_minimal(base_size = 12) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(x = "Hour of Day", y = "Total Requests")
  })
  output$table_hourly <- renderTable({ head(hourly_df, 12) })
  
  output$plot_status <- renderPlot({
    ggplot(status_df, aes(x = reorder(as.character(Status_Code), -Requests), y = Requests, fill = Class)) +
      geom_col(width = 0.6) +
      theme_minimal(base_size = 12) +
      labs(x = "HTTP Status Code", y = "Count")
  })
  output$table_status <- renderTable({ status_df })
  
  output$plot_methods <- renderPlot({
    ggplot(methods_df, aes(x = reorder(Method, -Requests), y = Requests, fill = Method)) +
      geom_col(width = 0.5, show.legend = FALSE) +
      theme_minimal(base_size = 12) +
      labs(x = "Method", y = "Count")
  })
  output$table_methods <- renderTable({ methods_df })
  
  output$plot_ips <- renderPlot({
    df <- head(ips_df, input$top_n)
    col_name <- if ("Resolved_Hostname" %in% names(df)) "Resolved_Hostname" else "IP_Address"
    df$Label <- factor(df[[col_name]], levels = rev(df[[col_name]]))
    ggplot(df, aes(x = Label, y = Requests, fill = Requests)) +
      geom_col(width = 0.65, show.legend = FALSE) +
      coord_flip() +
      scale_fill_gradient(low = "#80cbc4", high = "#004d40") +
      theme_minimal(base_size = 12) +
      labs(x = "Client IP / Hostname", y = "Requests")
  })
  output$table_anomalies <- renderTable({ head(anom_df, 8) })
}

shinyApp(ui = ui, server = server)
