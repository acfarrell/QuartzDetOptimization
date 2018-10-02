#!/bin/bash

#Optimization script for the MOLLER quartz detector geometries.

#-Creates the geometry files for each variation of the desired parameter
#-Creates a new geometry folder inside defined remoll directory and moves
# all necessary folders (including schema and mollerMother.gdml) inside
#-Edits test macro to test each geometry variant
#-Runs remoll to simulate each geometry
#-Runs root script to plot yield for each variation and display result

#Run with ./optimizeQuartz <ring no> <sector> <parameter ID> <min value> <max value> <step value>
#example: ./optimizeQuartz 5 open 9 10 30 1 
#         (ring 5 open, varying reflector angle from 10 degrees to 30 in 1 degree steps)


#Path to remoll
REMOLLDIRECTORY=~/remoll_Sep18
#Path to the GDML generator
GEOGENDIRECTORY=~/geoGen
#Name of CSV file to read and edit geometry parameters
CSV=cadp_opt.csv
[ ! -f ${GEOGENDIRECTORY}/${CSV} ] && { echo "$CSV file not found"; exit 99; }
cp $GEOGENDIRECTORY/cadp.csv $GEOGENDIRECTORY/cadp_opt.csv
ring=$1
sector=$2

#parameter to be optimized
par=$3
case "$par" in
  2)
    parname="det_radius"
    ;;
  3)
    parname="quartz_len"
    ;;
  4)
    parname="overlap"
    ;;
  5)
    parname="quartz_thickness"
    ;;
  6)
    parname="quartz_tilt"
    ;;
  7)
    parname="roll"
    ;;
  8)
    parname="reflector_len"
    ;;
  9)
    parname="reflector_angle"
    ;;
  10)
    parname="light_guide_angle"
    ;;
  11)
    parname="light_guide_width"
    ;;
  12)
    parname="light_guide_length"
    ;;
  13)
    parname="pmt_ph_len"
    ;;
  14)
    parname="pmt_diameter"
    ;;
  15)
    parname="wall_thickness"
    ;;
  16)
    parname="pmt_holder_width"
    ;;
  17)
    parname="pmt_holder_depth"
    ;;
  18)
    parname="quartz_zpos"
    ;;
  19)
    parname="quartz_zpos_stag"
    ;;
esac

minval=$4
maxval=$5
step=$6

echo "Optimizing detector ${ring}${sector} ${parname} from ${minval} to ${maxval} in steps of ${step}"
currentval=$minval

#set up geometry directory in remoll
GEODIRECTORY=${REMOLLDIRECTORY}/geometry_Optimize_${parname}
[ ! -d "${GEODIRECTORY}" ] && { mkdir $GEODIRECTORY; }
cp -rp ${REMOLLDIRECTORY}/geometry_Mainz/schema $GEODIRECTORY
cp -rp ${REMOLLDIRECTORY}/geometry_Mainz/materials.xml $GEODIRECTORY
cp -rp ${REMOLLDIRECTORY}/geometry_Mainz/targetDaughter.gdml $GEODIRECTORY
cp mollerMother_template.gdml $GEODIRECTORY/mollerMother.gdml 
echo "Created geometry directory at $GEODIRECTORY"

#create macro from template
MACROPATH=${REMOLLDIRECTORY}/macros/optimize_${ring}${sector}_${parname}.mac
cp macro_template.mac $MACROPATH

#get array of quartz center positions
readarray -t quartzCenter < <(cut -d, -f2 "${GEOGENDIRECTORY}/$CSV" )
cp $GEOGENDIRECTORY/cadp.csv $GEOGENDIRECTORY/cadp_opt.csv
OUTPUTDIRECTORY=$GEOGENDIRECTORY/output_optimize_${ring}${sector}_$parname
[ ! -d "$OUTPUTDIRECTORY" ] && { mkdir $OUTPUTDIRECTORY; }
cp get_pe.C $OUTPUTDIRECTORY/
cp Makefile $OUTPUTDIRECTORY/
cp $REMOLLDIRECTORY/build/libremoll.so $OUTPUTDIRECTORY
cp $REMOLLDIRECTORY/build/remolltypes.hh $OUTPUTDIRECTORY
echo "Created output directory at $OUTPUTDIRECTORY"

if [ ! $ring -lt 5 ] 
then
  index=$(($ring-1))
  detid=$(($ring*10000 + 702))
else
  if [ $ring == 5 ]
  then
    case "$sector" in
      "open")
        index=4
        detid=50702
        ;;
      "closed")
        index=5
        detid=51702
        ;;
      "trans")
      index=6
      detid=52702
      ;;
   esac
 else
   index=7
   detid=60702
 fi
fi
  
#position beam to the center of the quartz in macro file
sed -i 's;QUARTZCENTER;'"${quartzCenter[$index]}"';g' $MACROPATH

sed -i 's;GEOMETRYDIRECTORY;'"${GEODIRECTORY}"';g' $MACROPATH

initialsuffix=$(($minval-$step))

touch $OUTPUTDIRECTORY/yield.csv
sed -i 's;ROOTFILE;'"$OUTPUTDIRECTORY"'/remollout_'"$initialsuffix"'.root;g' $OUTPUTDIRECTORY/get_pe.C
sed -i 's;DET_ID;'"$detid"';g' $OUTPUTDIRECTORY/get_pe.C
sed -i 's;OUTPUTFILE;'"$OUTPUTDIRECTORY"'/remollout_'"$initialsuffix"';g' $MACROPATH

MOLLERMOTHERPATH=$GEODIRECTORY/mollerMother.gdml

sed -i 's;detector_SUFFIX;detector_opt_'"$initialsuffix"';g' $MOLLERMOTHERPATH
cd $GEOGENDIRECTORY

while [ $currentval -le $maxval ]
do
  cd $GEOGENDIRECTORY
  oldval=$(($currentval-$step))
  #create a temporary cadp.csv to store this geometry variation
  TEMPFILE=cadp_opt_${par}_${currentval}.tmp
  echo "Testing parameter value = ${currentval}"

  #edit the cadp.csv to update parameter value 
  cat $CSV | awk -v par="$par" -v val="$currentval" -v prev="$oldval" 'BEGIN{FS=",";OFS=","}{$par=val; print $0}' > $TEMPFILE 
  mv $TEMPFILE $CSV
  
  #generate the GDML files
  perl cadGeneratorV1.pl -F $CSV >> log.txt
  perl gdmlGeneratorV1_materials.pl -M detectorMotherP.csv -D parameter.csv -P qe.txt -U UVS_45total.txt -R MylarRef.txt -T _opt_${currentval} -L "${ring}${sector}" 
  mv *_opt_${currentval}* $GEODIRECTORY

  #Update mollerMother.gdml and test macro to use this geometry
  cd $REMOLLDIRECTORY
  #FIXME macro still only uses a single electron beam hitting the center of the quartz
  #      parallel to central beamline axis. Needs to be updated to use realistic electron
  #      distribution using Blackening backtrace generator
  
  #Change macro to output the right file name
  LASTFILE=${OUTPUTDIRECTORY}/remollout_${oldval}.root
  NEWFILE=${OUTPUTDIRECTORY}/remollout_${currentval}.root
  
  
  sed -i 's;'"$LASTFILE"';'"$NEWFILE"';g' $MACROPATH
  
  #Update mollerMother to read correct detector geometry
  OLDGEOFILE=detector_opt_${oldval}.gdml
  NEWGEOFILE=detector_opt_${currentval}.gdml
  
  sed -i 's;'"$OLDGEOFILE"';'"$NEWGEOFILE"';g' $MOLLERMOTHERPATH
  
  ./build/remoll -t 8 $MACROPATH >> $OUTPUTDIRECTORY/log.txt

  cd $OUTPUTDIRECTORY
  
  #Run get_pe.C to get MPV yield on the cathode and write output to yield.csv
  
  sed -i 's;'"$LASTFILE"';'"$NEWFILE"';g' get_pe.C
  
  printf "$currentval," >> yield.csv
  make
  ./get_pe

  ((currentval+=step))
done
