# Load Packages
suppressPackageStartupMessages({
  library(RSQLite)
  library(XML)
  library(RCurl)
  library(dplyr)
})

# Load SQLite
dbcon <- dbConnect(RSQLite::SQLite(), "hospital-beds.sqlitedb")

# Check if the tables are laoded 
# dbListTables(dbcon) 

# Load XML
xmlURL <- "http://s3.us-east-2.amazonaws.com/artificium.us/datasets/HospitalBeds.xml"
xmlContent <- getURL(xmlURL, .encoding = "UTF-8")
xmlDOM <- xmlParse(xmlContent, asText = TRUE)


## Bed Categories
bed_cat <- xpathApply(xmlDOM, "//bed", function(node){
  category = xmlGetAttr(node, "type")
  descr = xmlGetAttr(node, "desc")
  
  # skip empty and NA
  if(is.null(category) || 
     is.null(descr) || 
     category %in% c("", "NA") || 
     descr%in% c("", "NA")) return (NULL)
  
  list(
    category = xmlGetAttr(node, "type"),
    descr = xmlGetAttr(node, "desc")
  )
})
bed_cat_df <- do.call(rbind, lapply(bed_cat, as.data.frame))
bed_cat_df <- unique(bed_cat_df)

# make sure columns are the correct type
bed_cat_df$catID <- seq(1:nrow(bed_cat_df))
bed_cat_df$category <- as.character(bed_cat_df$category)
bed_cat_df$descr <- as.character(bed_cat_df$descr)

# write into SQL
dbWriteTable(dbcon, "Bed_Categories", bed_cat_df, overwrite = T, rownames = F)
#dbGetQuery(dbcon, "SELECT * FROM Bed_Categories")



## Facility
facility <- xpathApply(xmlDOM, "//hospital", function(node) {
  IMSID <- xmlGetAttr(node, "ims-org-id")
  name <- xmlValue(node[["name"]])
  
  # iterate through bed for each hospital
  beds <- xpathApply(node, ".//bed", function(node){
    licensed <- xmlValue(node[["ttl-licensed"]])
    census <- xmlValue(node[["ttl-census"]])
    staffed <- xmlValue(node[["ttl-staffed"]])
    
    licensed <- ifelse(licensed %in% c("", "NA", " "), NA, as.integer(licensed))
    census <- ifelse(census %in% c("", "NA", " "), NA, as.integer(census))
    staffed <- ifelse(staffed %in% c("", "NA", " "), NA, as.integer(staffed))
    
    list(
      licensed = licensed,
      census = census,
      staffed = staffed
    )
  })
  
  # create data frame if the hospital has a bed
  beds_df <- do.call(rbind, lapply(beds, as.data.frame))
  
  list(
    IMSID = IMSID,
    name = name,
    TTL_licensed = beds_df$licensed,
    TTL_census = beds_df$census,
    TTL_staffed = beds_df$staffed
  )
})

facility_df <- do.call(rbind, lapply(facility, as.data.frame))

# filter NAs and determine total licensed, census, and staffed per facility
facility_df <- facility_df %>% 
  filter(!is.na(TTL_licensed) & !is.na(TTL_census) & !is.na(TTL_staffed) ) %>%
  group_by(IMSID, name) %>%
  summarize(
    TTL_licensed = sum(TTL_licensed, na.rm = TRUE),
    TTL_census = sum(TTL_census, na.rm = TRUE),
    TTL_staffed = sum(TTL_staffed, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ungroup

# make sure columns are the correct type
facility_df$IMSID <- as.character(facility_df$IMSID)
facility_df$name <- as.character(facility_df$name)
facility_df$TTL_licensed <- as.integer(facility_df$TTL_licensed)
facility_df$TTL_census <- as.integer(facility_df$TTL_census)
facility_df$TTL_staffed <- as.integer(facility_df$TTL_staffed)

# write into SQL
dbWriteTable(dbcon, "Facility", facility_df, overwrite = T, rownames = F)
#dbGetQuery(dbcon, "SELECT * FROM Facility")



## Bed_Facts
bed_facts <- xpathApply(xmlDOM, "//hospital", function(node){
  IMSID = xmlGetAttr(node, "ims-org-id")
  
  # iterate and get catID, licensed, census, and staffed for each
  beds <- xpathApply(node, ".//bed", function(node){
    
    # make sure catID is the same as bed_categories
    bed_category <- xmlGetAttr(node, "type")
    bed_desc <- xmlGetAttr(node, "desc")
    matching_row <- bed_cat_df[bed_cat_df$category == bed_category & bed_cat_df$descr == bed_desc, ]
    catID <- ifelse(nrow(matching_row) > 0, matching_row$catID[1], NA)
    
    licensed <- xmlValue(node[["ttl-licensed"]])
    census <- xmlValue(node[["ttl-census"]])
    staffed <- xmlValue(node[["ttl-staffed"]])
    
    # handle NAs
    licensed <- ifelse(licensed %in% c("", "NA", " "), NA, as.integer(licensed))
    census <- ifelse(census %in% c("", "NA", " "), NA, as.integer(census))
    staffed <- ifelse(staffed %in% c("", "NA", " "), NA, as.integer(staffed))
    
    list(
      catID = catID,
      licensed = licensed,
      census = census,
      staffed = staffed
    )
  })
  beds_df <- do.call(rbind, lapply(beds, as.data.frame))
  
  list(
    IMSID = IMSID,
    catID = beds_df$catID,
    licensed = beds_df$licensed,
    census = beds_df$census,
    staffed = beds_df$staffed
  )
})
bed_facts_df <- do.call(rbind, lapply(bed_facts, as.data.frame))

# filter NAs
bed_facts_df <- bed_facts_df %>%
  filter(
    !is.na(IMSID) &!is.na(catID) & !is.na(licensed) & !is.na(census) & !is.na(staffed) 
  )

# make sure columns are the correct type
bed_facts_df$licensed <- as.integer(bed_facts_df$licensed)
bed_facts_df$census <- as.integer(bed_facts_df$census)
bed_facts_df$staffed <- as.integer(bed_facts_df$staffed)
bed_facts_df$catID <- as.integer(bed_facts_df$catID)
bed_facts_df$IMSID <- as.character(bed_facts_df$IMSID)

# write into SQL
dbWriteTable(dbcon, "Bed_Facts", bed_facts_df, overwrite = T, rownames = F)
#dbGetQuery(dbcon, "SELECT * FROM Bed_Facts")


# Disconnect
dbDisconnect(dbcon)
