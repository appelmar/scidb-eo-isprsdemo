suppressMessages(library(scidb))
suppressMessages(library(scidbst))
SCIDB_HOST = "localhost"
SCIDB_PORT = 8083
SCIDB_USER = "scidb"
SCIDB_PW   = "xxxx.xxxx.xxxx"

Sys.setenv(SCIDB4GDAL_HOST=paste("https://", SCIDB_HOST, sep=""), 
           SCIDB4GDAL_PORT=SCIDB_PORT, 
           SCIDB4GDAL_USER=SCIDB_USER,
           SCIDB4GDAL_PASSWD=SCIDB_PW)
		   
scidbconnect(host=SCIDB_HOST,port = SCIDB_PORT,username = SCIDB_USER, password = SCIDB_PW,auth_type = "digest",protocol = "https")