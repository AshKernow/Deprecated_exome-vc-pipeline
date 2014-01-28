#!/bin/bash
#$ -cwd -l mem=6G,time=6:: -N StampyRefs
uname -a
echo "Start $0:`date`"

. /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings.sh
echo $STAMPY
echo $REF

#build genome file
cmd="$STAMPY -G b37 $REF"
echo $cmd
$cmd

#build hash table
cmd="$STAMPY -g b37 -H b37"
echo $cmd
$cmd
echo "End $0:`date`"
