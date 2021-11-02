#!/bin/bash
docker container stop bonfire_web 
docker container stop reflow_release_search_1 reflow_release_db_1
docker container rm reflow_release_search_1 reflow_release_db_1
cd ~/Projects/reflow_os/reflow-os/  
rm -rf bonfire/data
make setup
make run
