sink(file="/tmp/rout.txt")
suppressMessages(library(gdalUtils))
suppressMessages(library(rgdal))
suppressMessages(library(raster))
source("scidb_connect.R")



#### INGEST #####
message("1. Ingesting Landsat NDVI data to a three-dimensional SciDB array... ")
SCIDBARRAYNAME = "L7_SW_ETHIOPIA"
BBOX = "799500 799000 809500 789000"
SRS = "EPSG:32636"

# find scenes on disk
image.files = data.frame(path=list.files("data", "*ndvi_subset.tif$",full.names = T),stringsAsFactors = F)
image.files$name = basename(image.files$path)
image.files$wrs2path = as.integer(substr(image.files$name,4,6))
image.files$wrs2row = as.integer(substr(image.files$name,7,9))
image.files$t = strptime(substr(image.files$name,10,16), format="%Y%j")


# order by time
image.files = image.files[order(image.files$t),]


# CREATE ARRAY AND ADD FIRST IMAGE
i = 1

cat(paste(Sys.time(), ": ", image.files$name[i], " (", i, "/", nrow(image.files), ") ...", sep=""))
res = gdal_translate(src_dataset = image.files$path[i], 
					 dst_dataset = paste("SCIDB:array=", SCIDBARRAYNAME, sep=""),
					 of = "SciDB", co = list(paste("t=",format(image.files$t[i],"%Y-%m-%d"),sep=""), "dt=P1D",paste("bbox=",BBOX,sep=""),paste("srs=", SRS, sep=""),"type=STS"))
cat(" DONE. (" , round(100* (i) / nrow(image.files),digits=2) , "%)")
cat("\n")
i = i + 1


while (i <= nrow(image.files))
{
	cat(paste(Sys.time(), ": ", image.files$name[i], " (", i, "/", nrow(image.files), ") ...", sep=""))
	res = gdal_translate(src_dataset = image.files$path[i],verbose = F,
						 dst_dataset = paste("SCIDB:array=", SCIDBARRAYNAME, sep=""),
						 of = "SciDB", co = list("type=ST",paste("t=",format(image.files$t[i],"%Y-%m-%d"),sep=""),"dt=P1D"))

	cat(" DONE. (" , round(100* (i) / nrow(image.files),digits=2) , "%)\n")
	i = i + 1
}
cat("\nDONE.\n")




#### ANALYZE #####
source("scidb_connect.R")
l7.ref = scidb("L7_SW_ETHIOPIA")
l7.ref = subset(l7.ref,"band1 > -9999 and band1 <= 10000") # leave out missing data and clouds (20000)
l7.ref = transform(l7.ref,ndvi = "double(band1) / 10000")$ndvi
l7.ref = transform(l7.ref, dimx="double(x)", dimy="double(y)", dimt="double(t)")
l7.ref = repart(l7.ref,chunk=c(64,64,4161))

message("2. Reshaping array...")
scidbeval(l7.ref, name="L7_SW_ETHIOPIA_TCHUNK")

query.R = paste("store(unpack(r_exec(", "L7_SW_ETHIOPIA_TCHUNK", ",'output_attrs=5','expr=
                require(xts)
                require(bfast)
                require(plyr)
                ndvi.df = data.frame(ndvi=ndvi,dimy=dimy,dimx=dimx,dimt=dimt)
                f <- function(x) {
                return(
                tryCatch({
                ndvi.ts = bfastts(x$ndvi,as.Date(\"2003-07-21\") + x$dimt,\"irregular\")
                bfast.result = bfastmonitor(ndvi.ts, start = c(2010, 1), order=1,history=\"ROC\")
      return(c(nt=length(t), breakpoint = bfast.result$breakpoint,  magnitude = bfast.result$magnitude ))
    }, error=function(e) {
      return (c(nt=0,breakpoint=0,magnitude=0))
    })
  )
}
runtime = system.time(ndvi.change <- ddply(ndvi.df, c(\"dimy\",\"dimx\"), f))[3]
cat(paste(\"Needed \", runtime, \"seconds - \", \"Failed: \", sum(ndvi.change$nt == 0), \" - Succeeded: \", sum(ndvi.change$nt > 0), \"\n\" , sep=\"\"), file=\"/tmp/rexec.log\", append=TRUE)
list(dimy = as.double(ndvi.change$dimy), dimx = as.double(ndvi.change$dimx), nt = as.double(ndvi.change$nt), brk = as.double(ndvi.change$breakpoint), magn = as.double(ndvi.change$magnitude) )'),i), 
", "L7_SW_ETHIOPIA_ROUT" ,")", sep="")

message("3. Running change detection in time series...")
iquery(query.R)

schema = "<nt:int16,breakpoint:double,magnitude:double>[y=0:334,2048,0,x=-167:334,2048,0]"
scidbeval(redimension(transform(scidb("L7_SW_ETHIOPIA_ROUT"), y="int64(expr_value_0)", x="int64(expr_value_1)", nt = "int16(expr_value_2)", breakpoint = "expr_value_3", magnitude="expr_value_4"),schema = schema), name="L7_SW_ETHIOPIA_CHANGEMAP")
iquery("eo_setsrs(L7_SW_ETHIOPIA_CHANGEMAP,L7_SW_ETHIOPIA)")

message("4. Downloading results...")
x = stack(readGDAL("SCIDB:array=L7_SW_ETHIOPIA_CHANGEMAP"))

col = rainbow(5)
brk = 2010:2015

x[[2]][is.na(x[[2]])] <- NA
x[[2]][x[[2]] < 2010 | x[[2]] > 2015] <- NA

x[[3]][is.na(x[[2]])] <- NA
x[[3]][x[[2]] < 2010 | x[[2]] > 2015] <- NA


png("changes.png",width = 1500,height = 800, res="90")
par(oma=c(1,1,1,1))
par(mfrow=c(1,2))
plot(x[[2]],col=col,breaks=brk, main="Change date")
plot(x[[3]], main="Change magnitude")
dev.off()


#### CLEAN UP #####
message("5. Cleaning up...")
source("scidb_connect.R")
scidbrm(c("L7_SW_ETHIOPIA_TCHUNK",
		  "L7_SW_ETHIOPIA",
          "L7_SW_ETHIOPIA_CHANGEMAP",
		  "L7_SW_ETHIOPIA_ROUT"), force=TRUE)


message("DONE.\n")
sink(NULL)





