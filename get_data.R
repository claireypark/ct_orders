# Some functions to download comment letters ----
readPDF <- function(url) {

    # Download PDF
    library(curl)
    t <- tempfile()
    curl::curl_download(url, t)

    # Create a .txt file from PDF (requires installation of a free program)
    system(paste("pdftotext", t), intern=TRUE)

    # Read text and remove pagebreaks from text
    text <- paste(readLines(paste0(t, ".txt"), warn = FALSE), collapse="\n")
    gsub("\f", "\n", text)
}

getCommentLetter <- function(file_name) {
    url <- file.path("http://www.sec.gov/Archives",
                     gsub("(\\d{10})-(\\d{2})-(\\d{6})\\.txt", "\\1\\2\\3", file_name),
                     "filename1.pdf")
    readPDF(url)
}

# Get a list of 100 comment letters submitted by the SEC ----
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
save(ct_orders, file="~/Desktop/ct_orders.Rdata")
