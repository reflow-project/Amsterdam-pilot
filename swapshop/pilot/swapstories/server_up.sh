#!/bin/bash

#start the web server on host port 3000 bound to the app in this directory
docker run --rm --mount type=bind,source="$(pwd)",target=/app -p 3000:3000 -it swapstories bin/rails server -b 0.0.0.0
