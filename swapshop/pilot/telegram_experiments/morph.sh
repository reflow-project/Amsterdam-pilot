#!/bin/bash 
convert qrcode.jpg +repage -threshold 50% -morphology open square:1 threshold.jpg 
