# Unit and integration tests for MapReduce in R

SCRIPT_DIR <- file.path(getwd(), "website-log-mapreduce", "scripts")
if (!dir.exists(SCRIPT_DIR)) {
  SCRIPT_DIR <- file.path(getwd(), "scripts")
}

source(file.path(SCRIPT_DIR, "parser.R"))
source(file.path(SCRIPT_DIR, "mapper.R"))
source(file.path(SCRIPT_DIR, "shuffle.R"))
source(file.path(SCRIPT_DIR, "reducer.R"))

test_results <- list(passed = 0, failed = 0)

assert_test <- function(test_name, condition, details = "") {
  if (isTRUE(condition)) {
    cat(sprintf("  [PASS] %s\n", test_name))
    test_results$passed <<- test_results$passed + 1
  } else {
    cat(sprintf("  [FAIL] %s - %s\n", test_name, details))
    test_results$failed <<- test_results$failed + 1
  }
}

cat("Running MapReduce tests...\n\n")

SAMPLE_PATH <- file.path(getwd(), "website-log-mapreduce", "data", "sample.log")
if (!file.exists(SAMPLE_PATH)) {
  SAMPLE_PATH <- file.path(getwd(), "data", "sample.log")
}

sample_lines <- readLines(SAMPLE_PATH, warn = FALSE)

# 1. Parser & Edge Cases
parsed <- parse_log_chunk(sample_lines, log_format = "CLF")
assert_test("Total lines read matches sample length (20 lines)", parsed$total_count == 20)
assert_test("Malformed lines accurately caught (2 invalid lines)", parsed$malformed_count == 2)
assert_test("Valid lines accurately parsed (18 valid lines)", parsed$valid_count == 18)

banner_row <- parsed$records[grepl("banner.jpg", parsed$records$url), ]
assert_test("Missing byte '-' correctly converted to numeric 0", nrow(banner_row) > 0 && banner_row$bytes == 0)

# 2. Map Stage
mapped_urls <- map_urls(parsed$records)
assert_test("Mapper emits 18 key-value pairs for 18 valid records", nrow(mapped_urls) == 18)
assert_test("Mapper URL structure contains key, count, bytes", all(c("key", "count", "bytes") %in% names(mapped_urls)))

mapped_404 <- map_404_errors(parsed$records)
assert_test("404 Error mapper catches exactly two 404 requests", nrow(mapped_404) == 2)

# 3. Shuffle Stage
shuffled_urls <- shuffle_multi_value(mapped_urls)
assert_test("Shuffle groups into distinct unique URL keys", length(shuffled_urls) > 0 && is.list(shuffled_urls))
assert_test("Shuffle sorts keys in alphabetical order", identical(names(shuffled_urls), sort(names(shuffled_urls))))
assert_test("Index page '/index.html' grouped with exactly 7 visits", sum(shuffled_urls[["/index.html"]]$counts) == 7)

# 4. Reduce Stage
reduced_urls <- reduce_counts_and_bytes(shuffled_urls, "url")
index_reduced <- reduced_urls[reduced_urls$url == "/index.html", ]
assert_test("Reducer aggregates '/index.html' visits to 7", index_reduced$requests == 7)

# 5. Multi-Chunk Merge
chunk1 <- parsed$records[1:9, ]
chunk2 <- parsed$records[10:18, ]
red1 <- reduce_counts_and_bytes(shuffle_multi_value(map_urls(chunk1)), "url")
red2 <- reduce_counts_and_bytes(shuffle_multi_value(map_urls(chunk2)), "url")
merged_chunks <- merge_counts_bytes_df(red1, red2, "url")

merged_sorted <- merged_chunks[order(merged_chunks$url), ]
single_sorted <- reduced_urls[order(reduced_urls$url), ]

assert_test("Multi-chunk merged results match single-pass reduced results", 
            identical(merged_sorted$requests, single_sorted$requests) &&
            identical(merged_sorted$total_bytes, single_sorted$total_bytes))

cat(sprintf("\nResults: %d Passed, %d Failed\n", test_results$passed, test_results$failed))
if (test_results$failed > 0) stop("Tests failed!")
