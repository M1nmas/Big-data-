# Website Log Analysis Using MapReduce in R Without Hadoop

A college-level Big Data Analytics project implementing the **MapReduce programming paradigm** natively in **R** without requiring Hadoop, HDFS, or Spark clusters.

---

## 1. Project Overview

Analyzing massive web server logs (ranging from 160 MB to 3.26+ GB) poses significant memory challenges on standard personal computers. This project demonstrates how the core functional stages of MapReduce—**Map**, **Shuffle & Sort**, and **Reduce**—can be simulated natively in R using chunked stream processing to analyze web traffic, popular pages, status codes, and traffic anomalies without running out of RAM.

### Key Highlights
- **Zero Cluster Overhead**: 100% Base R MapReduce simulation; runs on any standard Windows machine.
- **Chunk-Based Streaming Engine**: Configurable chunks (e.g., 50,000 lines) keep RAM consumption constant ($O(1)$ memory).
- **Secondary Reducer Combiner**: Intermediate chunk outputs are merged deterministically using a multi-chunk combiner.
- **Data Enrichment**: Integrated IP-to-hostname dictionary resolution using `client_hostname.csv`.
- **Interactive Dashboard**: Decoupled Shiny dashboard for interactive KPI exploration and filtering.
- **Publication-Ready Outputs**: Automatically exports CSV summaries and high-resolution ggplot2 charts.

---

## 2. Directory Structure

```text
website-log-mapreduce/
├── data/
│   └── sample_access.log     # Curated 20-line test log (normal, 404, malformed, missing bytes)
├── scripts/
│   ├── parser.R              # Log format detection & regex chunk parsing
│   ├── mapper.R              # Canonical Map functions emitting (key, value) pairs
│   ├── shuffle.R             # Grouping & alphabetical sorting by intermediate keys
│   ├── reducer.R             # Reducer functions & multi-chunk combiner merger
│   ├── analysis.R           # Statistical rankings, KPI calculation, anomaly flags & CSV export
│   ├── visualizer.R         # High-resolution ggplot2 visualization generation
│   └── main.R               # Master execution pipeline
├── output/                   # Auto-generated CSV reports
│   ├── kpi_summary.csv
│   ├── top_10_urls.csv
│   ├── top_10_ips.csv
│   ├── status_distribution.csv
│   ├── http_methods.csv
│   ├── top_404_errors.csv
│   ├── hourly_traffic.csv
│   └── anomaly_indicators.csv
├── plots/                    # Auto-generated chart images (.png)
│   ├── plot_top_urls.png
│   ├── plot_top_ips.png
│   ├── plot_status_codes.png
│   ├── plot_traffic_trends.png
│   └── plot_http_methods.png
├── dashboard/
│   └── app.R                # Interactive Shiny web application
├── tests/
│   └── test_mapreduce.R      # Automated unit and integration test suite
├── README.md                 # Project guide and execution manual
└── report.md                 # Complete academic project report & viva questions
```

---

## 3. How to Run the Project

### Prerequisites
- R (version 4.0 or later).
- Recommended packages: `ggplot2`, `shiny`, `data.table` (fallback to base R is supported if packages are missing).

### Step 1: Run the Automated Unit Tests
Verify all parsing, edge cases, mapping, and chunk merging:
```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" "tests/test_mapreduce.R"
```
*Expected Result:* `12 PASSED, 0 FAILED`.

### Step 2: Run the Main MapReduce Analysis Pipeline
Executes chunk streaming, MapReduce aggregation, CSV export, and chart generation:
```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" "scripts/main.R"
```
*(By default, this analyzes `access.log` in 50,000-line chunks and outputs directly to `output/` and `plots/`).*

### Step 3: Launch the Interactive Shiny Dashboard
```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" -e "shiny::runApp('dashboard', launch.browser = TRUE)"
```
Or open [dashboard/app.R](dashboard/app.R) in RStudio and click **Run App**.

---

## 4. MapReduce Execution Workflow

```
[Raw Access Log File (3.26 GB)]
             │
             ▼ (Streaming Chunk Reader: e.g., 50,000 lines)
┌────────────────────────────────────────────────────────┐
│ Chunk N:                                               │
│                                                        │
│ 1. PARSE STAGE:                                        │
│    Validate regex -> Drop malformed -> Impute missing  │
│                                                        │
│ 2. MAP STAGE:                                          │
│    Emit (URL, 1), (IP, 1), (Status, 1), (Hour, 1)      │
│                                                        │
│ 3. SHUFFLE & SORT STAGE:                               │
│    Group intermediate pairs by Key -> Sort Keys        │
│                                                        │
│ 4. REDUCE STAGE:                                       │
│    Sum counts & bytes per key                          │
│                                                        │
│ 5. SECONDARY REDUCER MERGE (Combiner):                 │
│    Accumulator = Accumulator ⊕ Chunk_Reduced           │
└────────────────────────────────────────────────────────┘
             │ (Repeat until End Of File)
             ▼
[Global Aggregated Reduced Metrics]
             │
             ├──> Export 8 Analytical CSVs (output/)
             ├──> Generate 5 High-Res Charts (plots/)
             └──> Feed Interactive Shiny Dashboard (dashboard/)
```

---

## 5. Contact & Academic Submission
- **Project Title:** Website Log Analysis Using MapReduce in R Without Hadoop
- **Subject:** Big Data Analytics / Data Mining Practical Project
- **Documentation:** See [report.md](report.md) for the complete thesis report and viva questions.
