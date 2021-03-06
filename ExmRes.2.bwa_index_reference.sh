#!/bin/bash
#$ -cwd -l mem=6G,time=3:: -N bwaIndRef -o bwaInd.o -e bwaInd.e
uname -a
echo "Start $0:`date`"

. /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings.sh
echo $BWA
echo $REF

cmd="$BWA index -a bwtsw $REF"
echo $cmd
# $cmd

. /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings_hg19.sh
echo $BWA
echo $REF

cmd="$BWA index -a bwtsw $REF"
echo $cmd
$cmd

echo "End $0:`date`"
