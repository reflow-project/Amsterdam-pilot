#!/bin/bash

#start the telegram bot bound to the app in this directory
docker run --rm --mount type=bind,source="$(pwd)",target=/app -it swapstories bin/rake swapbot:run 
