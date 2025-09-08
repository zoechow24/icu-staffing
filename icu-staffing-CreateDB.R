# load packages
suppressPackageStartupMessages(
  library(RSQLite)
)

# create database
fpath = ""
dbfile = "hospital-beds.sqlitedb"

dbcon <- dbConnect(RSQLite::SQLite(), paste0(fpath, dbfile))

# make sure the tables do not already exist
# Bed_Categories
dropBedCat <- paste("DROP TABLE IF EXISTS Bed_Categories")
dbExecute(dbcon, dropBedCat) 

# Facility
dropFacility <- paste("DROP TABLE IF EXISTS Facility")
dbExecute(dbcon, dropFacility)

# Bed_Facts
dropBedFacts <- paste("DROP TABLE IF EXISTS Bed_Facts")
dbExecute(dbcon, dropBedFacts) 


# create tables
# Bed_Categories
createBedCat <- paste0(
  "CREATE TABLE Bed_Categories(
    catID INTEGER,
    category TEXT UNIQUE,
    descr TEXT,
    PRIMARY KEY (catID)
  )"
)
dbExecute(dbcon, createBedCat)


# Facility
createFacility <- paste0(
  'CREATE TABLE Facility(
    IMSID TEXT,
    name  TEXT,
    "TTL-Licensed" INTEGER,
    "TTL-Census" INTEGER,
    "TTL-Staffed" INTEGER,
    PRIMARY KEY (IMSID)
  )'
)
dbExecute(dbcon, createFacility)


# Bed_Facts
createBedFacts <- paste0(
  "CREATE TABLE Bed_Facts(
    IMSID TEXT,
    catID INTEGER,
    licensed INTEGER,
    census INTEGER,
    staffed INTEGER,
    PRIMARY KEY (IMSID, catID),
    FOREIGN KEY (IMSID) REFERENCES Facility (IMSID),
    FOREIGN KEY (catID) REFERENCES Bed_Categories (catID)
  )"
)
dbExecute(dbcon, createBedFacts)

# Disconnect
dbDisconnect






