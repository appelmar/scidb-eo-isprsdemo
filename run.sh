#!/bin/bash
# 1. start SciDB and other required services
echo -e "Starting system services (including SciDB, shim, and Rserve)..."
/opt/container_startup.sh >/dev/null

if [ -f /opt/run/run.R ]
  then
    # 2. run the actual analysis
    echo -e "Starting R script container..."
    cd /opt/run &&  Rscript run.R
	echo -e "Finished R script."
fi
echo -e "The container will stop NOW."

