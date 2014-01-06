#!/bin/bash
#$ -cwd 

while getopts d:s:l: opt; do
  case "$opt" in
      d) VcfDir="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";
  esac
done

#load settings file
. $Settings

uname -a >> $LogFil
echo "Start Merge individual chromosome VCFs with vcftools - $0:`date`" >> $LogFil
echo "" >> $LogFil
echo "Job name: "$JOB_NAME >> $LogFil
echo "Job ID: "$JOB_ID >> $LogFil

##Set local parameters
JobNm=${JOB_NAME#*.}
VcfFil=$JobNm.variants
echo "Merged VCF file: "$VcfFil >> $LogFil

#Merge files with vcftools
echo "Starting merge..."  >> $LogFil
$VCFTOOLS/vcf-concat -p $VcfDir/*vcf > $VcfFil.vcf

echo "" >> $LogFil
echo "----------------------------------------------------------------" >> $LogFil
echo "" >> $LogFil
echo "Call Recalibrate Variant Quality:" >> $LogFil
JobNm=${JOB_NAME#*.}
cmd="qsub -pe smp $NumCores -l $VQSRAlloc -N VQSR.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.4.RecalibrateVariantQuality.sh -i $VcfFil -s $Settings -l $LogFil"
echo "qsub time: `date`" >> $LogFil
echo $cmd  >> $LogFil
$cmd
echo "" >> $LogFil
echo "End Merge individual chromosome VCFs with vcftools $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage " >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
