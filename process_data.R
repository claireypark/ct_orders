# Get data from database ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())

ct_orders <- dbGetQuery(pg, "SELECT file_name, order_text FROM ct_orders.raw_text")

rs <- dbDisconnect(pg)

regex <- "^.*excluded.*?(10-Q|10-K|Form.*?)\\sfiled\\s+(?:on\\s)?(.*?\\d{4}).*"
ct_orders$details <- gsub(regex, "\\1;\\2", gsub("\n", " ", ct_orders$order_text), perl=TRUE)
ct_orders$form <- unlist(lapply(strsplit(ct_orders$details, ";"), function(x) x[1]))
ct_orders$form_date <- unlist(lapply(strsplit(ct_orders$details, ";"), function(x) x[2]))
ct_orders$details <- NULL
ct_orders$form_date <- as.Date(ct_orders$form_date, "%B %d, %Y")
table(is.na(ct_orders$form_date))

# ct_orders$order_type <- gsub("^.*ORDER\\s+(\\w+).*$", "\\1", ct_orders$order_text)
ct_orders$denied <- grepl("ORDER\\s+DENYING", ct_orders$order_text)
ct_orders$granted <- grepl("ORDER\\s+GRANTING", ct_orders$order_text)

# Get exhibits mentioned
matches <- gregexpr("[Ee]xhibit\\s+[0-9][A-Z0-9a-z\\(\\)\\.-]+", ct_orders$order_text)
matched_text <- regmatches(ct_orders$order_text , matches)
ct_orders$exhibits <- unlist(lapply(matched_text, function(x) paste(x, collapse=";")))
ct_orders$order_text <- NULL

# Put data into my database ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())

dbWriteTable(pg, c("ct_orders", "processed_data"), ct_orders,
             overwrite=TRUE, row.names=FALSE)

dbGetQuery(pg, "ALTER TABLE ct_orders.processed_data
                    ALTER COLUMN exhibits TYPE text[]
                        USING regexp_split_to_array(exhibits, ';')")

dbGetQuery(pg, "ALTER TABLE ct_orders.processed_data OWNER TO ct_orders_access")

rs <- dbDisconnect(pg)
