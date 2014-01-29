#!/bin/bash
#$ -cwd -l mem=6G,time=6:: -N StampyRefs
uname -a
echo "Start $0:`date`"

. /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings.sh
echo $STAMPY
echo $REF

#build reference genome file index for Stampy
cmd="$STAMPY -G stampy_b37 $REF"
echo "Build genome file for Stampy"
echo $cmd
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Build reference genome file index for Stampy failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
    exit 1
else
	echo "Build reference genome file index for Stampy - success!"
fi
#build hash tablefor Stampy
echo "Build hash tablefor Stampy"
cmd="$STAMPY -g b37 -H stampy_b37"
echo $cmd
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Build hash table for Stampy failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
    exit 1
else
	echo "Build hash table for Stampy - success!"
fi
echo "End $0:`date`"
