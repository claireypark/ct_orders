# dir.create("~/Dropbox/data/ct_orders")
setwd("~/Dropbox/data/ct_orders")

# Some functions to download comment letters ----
readPDF <- function(url, download=TRUE) {

    # Download PDF
    library(curl)
    t <- gsub("http://www.sec.gov/Archives/edgar/data/(.*)/filename1.pdf", "\\1.pdf", url)
    if (download) {
        t_dir <- gsub("^(\\d+)/\\d+\\.pdf", "\\1", t)
        dir.create(t_dir, showWarnings = FALSE)

        curl::curl_download(url, t)

        # Create a .txt file from PDF (requires installation of a free program)
        system(paste("pdftotext", t), intern=TRUE)
    }

    # Read text and remove pagebreaks from text
    text <- paste(readLines(gsub("\\.pdf", ".txt", t), warn = FALSE), collapse="\n")
    gsub("\f", "\n", text)
}

getCommentLetter <- function(file_name, download=TRUE) {
    url <- file.path("http://www.sec.gov/Archives",
                     gsub("(\\d{10})-(\\d{2})-(\\d{6})\\.txt", "\\1\\2\\3", file_name),
                     "filename1.pdf")
    readPDF(url, download)
}

# Get a list of court orders filed by SEC ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())
ct_orders <- dbGetQuery(pg, "
    SELECT *
    FROM filings.filings
    WHERE form_type = 'CT ORDER'")
dbDisconnect(pg)

# Now, get the text of comment letters and save as an R file ----
ct_orders$order_text <- unlist(lapply(ct_orders$file_name, getCommentLetter, download=FALSE))

# Put text data into my database ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())

# dbGetQuery(pg, "CREATE ROLE ct_orders_access")
# dbGetQuery(pg, "GRANT ct_orders_access TO dtayl")
# dbGetQuery(pg, "GRANT ct_orders_access TO igow")
# dbGetQuery(pg, "CREATE SCHEMA ct_orders AUTHORIZATION ct_orders_access")

dbWriteTable(pg, c("ct_orders", "raw_text"), ct_orders,
             overwrite=TRUE, row.names=FALSE)

dbGetQuery(pg, "ALTER TABLE ct_orders.raw_text OWNER TO ct_orders_access")

rs <- dbDisconnect(pg)
