## GLOBAL DEFINITIONS
sink(file="/tmp/rout.txt")
suppressMessages(library(gdalUtils))
suppressMessages(library(rgdal))

SCIDBARRAYNAME="TRMM3B42_DAILY" # Target SciDB array name for the data


nt = 53
ns = 1440*400
n.eof = 4 # extract only first EOFs




## 1. INGEST DATA TO 3D SCIDB ARRAY ##
# find scenes on disk
source("scidb_connect.R")
message("1. Ingesting TRMM data to a three-dimensional SciDB array... ")
image.files = data.frame(path=list.files("data", "*.hdf$",full.names = T),stringsAsFactors = F)
image.files$name = basename(image.files$path)
image.files$t = strptime(substr(image.files$name,12,19), format="%Y%m%d")
image.files = image.files[order(image.files$t),] # order by time

# ingest first scene
gdal_translate(src_dataset = image.files$path[1],
		dst_dataset = paste("SCIDB:array=", SCIDBARRAYNAME, sep=""),
		a_srs = "EPSG:4326",
		of = "SciDB", co = list(paste("t=",format(image.files$t[1],"%Y-%m-%d"),sep=""), "dt=P7D", "type=STS"))

# ingest other scenes								
for (i in 2:nrow(image.files)) 
{
  gdal_translate(src_dataset = image.files$path[i],
			  dst_dataset = paste("SCIDB:array=", SCIDBARRAYNAME, sep=""),
			  a_srs = "EPSG:4326",
			  of = "SciDB", co = list("type=ST", paste("t=",format(image.files$t[i],"%Y-%m-%d"),sep=""), "dt=P7D"))
  cat(paste(Sys.time(), ": ", i, " of ", nrow(image.files), " finished\n", sep=""))
}


Sys.sleep(20)



## 2. RUN EOF ANALYSIS IN SCIDB ##
source("scidb_connect.R")
message("2. Computing EOFs in SciDB...")
trmm.ref = scidb("TRMM3B42_DAILY")

# Create an array that maps time index to columns in the data matrix after removing incomplete images
t.complete =  unpack(subset(aggregate(subset(trmm.ref, "band1 >= 0"),by="t",FUN="count(*)"),"count = 576000"))$t
t.complete = redimension(t.complete,schema="<i:int64>[t=0:52,53,0]")
scidbeval(t.complete,name="TRMM3B42_EXPERIMENT_EOFSCALABILITY_COMPLETE_IMAGES_T")
t.complete = scidb("TRMM3B42_EXPERIMENT_EOFSCALABILITY_COMPLETE_IMAGES_T")
nt.nonempty = aggregate(t.complete,FUN="count(*)")[]$count

# Build the data matrix and detrend the data
trmm.subset.X.ref = redimension(cast(transform( merge(trmm.ref,t.complete, equi_join=FALSE),s="int64(x*400+y)"), paste("<band1:double,i:int64,s:int64> [y=0:399,2048,0,x=0:1439,2048,0,t=0:",nt-1, ",1,0]", sep="")),schema=paste("<band1:double>[i=0:", nt-1,", 32, 0, s=0:575999,32,0]",sep="")) 
trmm.subset.X.ref = scidb::subarray(trmm.subset.X.ref,limits=c(0,0,nt.nonempty-1,ns-1))
trmm.subset.X.ref = transform(merge(trmm.subset.X.ref , aggregate(trmm.subset.X.ref, by="s", "avg(band1)"), equi_join=FALSE), prec_norm = "(band1 - band1_avg)")$prec_norm

# Run SVD to compute EOFs
trmm.subset.X.svd.R = scidb::subarray(gesvd(trmm.subset.X.ref, type="right"),limits=c(0,0,n.eof-1,ns-1))
trmm.subset.X.svd.EOF.map = redimension(transform(trmm.subset.X.svd.R ,y="int64(s % 400)", x="int64(floor(s / 400))"),schema=paste("<v:double NOT NULL>[y=0:399,400,0, x=0:1439,1440, 0, i=0:", n.eof - 1, ",1,0]", sep="")) 

# Run all previous operations and store result as a new array
scidbeval(trmm.subset.X.svd.EOF.map,name="TRMM3B42_EXPERIMENT_EOFSCALABILITY_EOF_S")

# set spatial reference of results
iquery("eo_setsrs(TRMM3B42_EXPERIMENT_EOFSCALABILITY_EOF_S, TRMM3B42_DAILY)");




## 3. DOWNLOAD RESULT EOFS AS GEOTIFF FILES AND PRODUCE A GDAL VRT DATASET FOR ALL EOFS ##
source("scidb_connect.R")
message("3. Downloading results...")
suppressWarnings(eof.ref <- scidbst("TRMM3B42_EXPERIMENT_EOFSCALABILITY_EOF_S"))
for (i in 1:n.eof) {
  suppressWarnings(scidbsteval(slice(eof.ref, d = "i", n = i-1), name="TEMP"))
  fname = paste("trmm_eof_",i,".tif", sep="")
  gdal_translate(src_dataset = "SCIDB:array=TEMP", dst_dataset = fname)
}
gdalbuildvrt(list.files(pattern="*.tif$"), "EOF.vrt", separate=TRUE, overwrite=T)




## 4. GENERATE FIGURE AS IN THE PAPER ##
message("4. Generating PNG figure...")
require(rgdal)
eof = readGDAL("EOF.vrt")
names(eof) = paste0("EOF.", 1:n.eof ,sep="")
cols.n = 100
cols = rainbow(n = cols.n, start=0, end=0.6,s = 0.7)
at = seq(-0.01,0.01,length.out = cols.n)
png("EOF.png",width = 1500,height = 1200, res="150")
print(spplot(eof[ paste0("EOF.", 1:n.eof ,sep="")], at=at, col.regions=cols, scales=list(draw=T) ))
dev.off()



## 5. CLEAN UP ALL THE DATA IN SCIDB ##
source("scidb_connect.R")
scidbrm(c("TRMM3B42_EXPERIMENT_EOFSCALABILITY_EOF_S",
		  "TRMM3B42_DAILY",
          "TRMM3B42_EXPERIMENT_EOFSCALABILITY_COMPLETE_IMAGES_T",
		  "TEMP"), force=TRUE)

message("DONE.")
sink(NULL)

