# dir.create("~/Dropbox/data/ct_orders")
setwd("~/Dropbox/data/ct_orders")

# Some functions to download comment letters ----
readPDF <- function(url) {

    # Download PDF
    library(curl)
    t <- gsub("http://www.sec.gov/Archives/edgar/data/(.*)/filename1.pdf", "\\1.pdf", url)
    t_dir <- gsub("^(\\d+)/\\d+\\.pdf", "\\1", t)
    dir.create(t_dir, showWarnings = FALSE)

    curl::curl_download(url, t)

    # Create a .txt file from PDF (requires installation of a free program)
    system(paste("pdftotext", t), intern=TRUE)

    # Read text and remove pagebreaks from text
    text <- paste(readLines(gsub("\\.pdf", ".txt", t), warn = FALSE), collapse="\n")
    gsub("\f", "\n", text)
}

getCommentLetter <- function(file_name) {
    url <- file.path("http://www.sec.gov/Archives",
                     gsub("(\\d{10})-(\\d{2})-(\\d{6})\\.txt", "\\1\\2\\3", file_name),
                     "filename1.pdf")
    readPDF(url)
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
ct_orders$text <- unlist(lapply(ct_orders$file_name, getCommentLetter))

regex <- "^.*excluded.*?(10-Q|10-K|Form.*?)\\sfiled\\s+(?:on\\s)?(.*?\\d{4}).*"
ct_orders$details <- gsub(regex, "\\1;\\2", gsub("\n", " ", ct_orders$text), perl=TRUE)
ct_orders$form <- unlist(lapply(strsplit(ct_orders$details, ";"), function(x) x[1]))
ct_orders$form_date <- unlist(lapply(strsplit(ct_orders$details, ";"), function(x) x[2]))
ct_orders$form_date <- as.Date(ct_orders$form_date, "%B %d, %Y")
table(is.na(ct_orders$form_date))

ct_orders$order <- gsub("^.*ORDER\\s+(\\w+).*$", "\\1", ct_orders$text)
ct_orders$granted <- grepl("ORDER\\s+DENYING", ct_orders$text)
ct_orders$denied <- grepl("ORDER\\s+GRANTING", ct_orders$text)

# Put data into my database ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())

dbWriteTable(pg, c("filings", "ct_orders"), ct_orders,
             overwrite=TRUE, row.names=FALSE)

rs <- dbDisconnect(pg)
