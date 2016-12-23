# scidb-eo:gmd 
A Docker image and two study cases to demonstrate how to run open and scalable Earth observation analytics with [SciDB](http://www.paradigm4.com/), [GDAL](http://gdal.org/), and [R](https://www.r-project.org/)

---

This Docker image demonstrates how to run Earth observation (EO) analytics with [SciDB](http://www.paradigm4.com/) (15.7), its extensions [scidb4geo](https://github.com/appelmar/scidb4geo) and  [scidb4gdal](https://github.com/appelmar/scidb4gdal), and [GDAL](http://gdal.org/) (2.1.0). It includes:

* scripts, code, and a `Dockerfile` to create a Docker image with all required software

* R scripts and small datasets to run two study cases on (i) land use change monitoring with Landsat NDVI time series and (ii) computation of empirical orthogonal functions (EOFs) on TRMM precipitation data

To run the study cases, you have to build the Docker image first and run a container with attached data and script afterwards. The sections below provide copyable commands to get started.  


## Prerequisites
- [Docker Engine](https://www.docker.com/products/docker-engine) (>1.10.0) 
- Around 15 GBs free disk space 



## Getting started

_**Note**: Depending on your Docker configuration, the following commands must be executed with sudo rights._

### 1. Build the Docker image (1-2 hours)

The provided Docker image is based on a minimally sized Ubuntu OS. Among others, it includes the compilation and installation of [SciDB](http://www.paradigm4.com/), [GDAL](http://gdal.org/), SciDB extensions ([scidb4geo](https://github.com/appelmar/scidb4geo),  [scidb4gdal](https://github.com/appelmar/scidb4gdal)) and the installation of all dependencies. The image will take around 15 GBs of disk space. It can be created by executing:

```
docker build --tag="scidb-eo:gmd" https://github.com/appelmar/scidb-eo-gmd.git
``` 

_Note that by default, this includes a rather careful SciDB configuration with relatively little demand for main memory. You may modify `conf/scidb_docker.ini` if you have a powerful machine._


### 2. Start a container to run the study cases (30-60 minutes per study case)

To start the analyses of the study cases, you need to run a Docker container and mount the data and R code to the container's files system at `/opt/run/`. The file `/opt/run/run.R` is automatically called if you start the container with the provided `run.sh` script. The commands below can be used to run either of the two provided study cases.


_Note that the following commands limit the number of CPU cores and main memory available to the container. Feel free to use different settings for `--cpuset-cpu` and `-m`. Setting `--ipc="host"` is required to use [ScaLAPACK](http://www.netlib.org/scalapack) within containers._

**Monitoring changes in Landsat NDVI time series:**

```
docker run --name="scidbeo-gmd" --ipc="host" --rm --cpuset-cpus="0,1" -m "4G" -h "scidbeo-gmd" -v $PWD/studycases/LANDSAT-BFAST:/opt/run/  scidb-eo:gmd "/opt/run.sh"
```


**Computation of EOFs from TRMM precipitation observations:**

```
docker run --name="scidbeo-gmd" --ipc="host" --rm --cpuset-cpus="0,1" -m "4G" -h "scidbeo-gmd" -v $PWD/studycases/TRMM-EOF:/opt/run/  scidb-eo:gmd "/opt/run.sh"
```


### 3. Check the results

Once the analysis has been finished, you should see generated result figures as new files `studycases/LANDSAT-BFAST/changes.png` and `studycases/TRMM-EOF/EOF.png`  respectively.


### 4. Clean up
To clean up your system, you can remove containers and the image with

1. `docker rm scidbeo-gmd` (only needed if container didn't run with `--rm`), and 
2. `docker rmi scidb-eo:gmd`.



	
	
	
## Study case details

Below, you can find brief descriptions of the study cases and datasets. 

**Monitoring changes in Landsat NDVI time series:**

This study case works on a small region covering 10x10 km in the southwest of Ethiopia. For this region, post-processed NDVI imagery captured by Landsat 7 between 2003-07-21 and 2014-12-27 has been downloaded from [espa.cr.usgs.gov](http://espa.cr.usgs.gov/). The resulting imagery (see `studycases/LANDSAT-BFAST/data`) has been cropped by GDAL.   

The analysis with R (see `studycases/LANDSAT-BFAST/run.R`) includes the following steps:

1. Load the data as a three-dimensional array to SciDB
2. Omit invalid NDVI values (< -1 or > 1) and reshape the array such that chunks contain complete time series
3. Run change monitoring from the [bfast R package](http://bfast.r-forge.r-project.org)[1] where the monitoring period starts with 2010.
4. Download the results and generate a simple change figure.


**Computation of EOFs from TRMM precipitation observations:**

The analysis in this example looks at 53 scenes of the daily accumulated rainfall product from the [Tropical Rainfall Measuring Mission (TRMM)](https://mirador.gsfc.nasa.gov/collections/TRMM_3B42_daily__007.shtml) in 2005 and computes a few first empricial orthogonal functions (EOFs) using a singular value decomposition in SciDB. The R script (see `studycases/TRMM-EOF/run.R`) performs the following steps:

1. Load the data as a three-dimensional array to SciDB
2. Convert the array to a two-dimensional data matrix with spatial pixels as variables and time as observations
3. To compute EOFs, detrend the time series of individual pixels and run singular value decomposition on the data matrix
4. Download the results and generate a simple map with the first EOFs.

	
	
	
## Files

| File        | Description           |
| :------------- | :-------------------------------------------------------| 
| install/ | Directory for installation scripts |
| install/install_scidb.sh | Installs SciDB 15.7 from sources |
| install/install_shim.sh | Installs Shim |
| install/install_scidb4geo.sh | Installs the scidb4geo plugin |
| install/install_gdal.sh | Installs GDAL with SciDB driver |
| install/install_R.sh | Installs the latest R version  |
| install/install_r_exec.sh | Installs the r_exec SciDB plugin to run R functions in AFL queries including Rserve |
| install/scidb-15.7.0.9267.tgz| SciDB 15.7 source code |
| conf/ | Directory for configuration files |
| conf/scidb_docker.ini | SciDB configuration file |
| conf/supervisord.conf | Configuration file to manage automatic starts in Docker containers |
| conf/iquery.conf | Default configuration file for iquery |
| conf/shim.conf | Default configuration file for shim |
| studycases/ | Directory with scripts and data of the study cases |
| Dockerfile | Docker image definition file |
| container_startup.sh | Script that starts SciDB, Rserve, and other system services within a container  |
| run.sh | Script that calls container_startup.sh and starts Rscript /opt/run/run.R if available within the container, can be used as container CMD instruction |


## References
[1] Verbesselt, J., Zeileis, A., & Herold, M. (2013). Near real-time disturbance detection using satellite image time series, Remote Sensing of Environment. DOI: 10.1016/j.rse.2012.02.022. 


## License
This Docker image contains source code of SciDB in install/scidb-15.7.0.9267.tgz. SciDB is copyright (C) 2008-2016 SciDB, Inc. and licensed under the AFFERO GNU General Public License as published by the Free Software Foundation. You should have received a copy of the AFFERO GNU General Public License. If not, see <http://www.gnu.org/licenses/agpl-3.0.html>

License of this Docker image can be found in the `LICENSE`file.



## Notes
Building the image includes both compiling softwar from sources and installing packages from binaries. Some installations require downloading files (e.g. GDAL source code), which is not provided within this image. If these links are not available or URLs are changed in the futre, the build procedure might fail. Please feel free so report any issues to the author. 


----

## Author

Marius Appel  <marius.appel@uni-muenster.de>
