#!/bin/bash
docker container stop bonfire_web 
docker container stop reflow_release_search_1 reflow_release_db_1
docker container rm reflow_release_search_1 reflow_release_db_1
. .env #load REFLOW_OS_PATH from .env
cd $REFLOW_OS_PATH 
rm -rf bonfire/data
make setup
make run
