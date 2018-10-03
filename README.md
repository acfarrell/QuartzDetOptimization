# QuartzDetOptimization
Performs optimization on geometry parameters for the MOLLER quartz detectors
To run you need: the up-to-date GDML geometry generator, and an up-todate remoll that has been built

Be sure to update your GDML generator directory and remoll directory within optimizeQuartz.sh for the variables 
$GEOGENDIRECTORY and $REMOLLDIRECTORY, respectively

The cadp.csv file should also be specified for the variable $CSV. This file will be edited directly, so best to 
make a copy of the original cadp.csv specifically for running optimization scans.

Run with
./optimizeQuartz.sh (ring) (sector) (parameter ID num) (min value) (max value) (step)

For example, to scan the reflector angle of ring 5 open from 10 to 30 degrees in steps of two:
./optimizeQuartz.sh 5 open 9 10 30 2
