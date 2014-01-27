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
echo "Start Merge & Sort individual chromosome VCFs with vcftools - $0:`date`" >> $LogFil
echo "Job name: "$JOB_NAME >> $LogFil
echo "Job ID: "$JOB_ID >> $LogFil

##Set local parameters
JobNm=${JOB_NAME#*.}
VcfFil=$JobNm.variants
echo "Merged VCF file: "$VcfFil >> $LogFil

#Merge files with vcftools
echo "- Starting merge with vcftools`date` ..."  >> $LogFil
$VCFTOOLS/vcf-concat -p $VcfDir/*vcf > $VcfFil.vcf
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Merge with vcftools $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $LogFil
    exit 1
fi

#Sort VCF file with vcftools
echo "- Starting sort with vcftools `date` ..."  >> $LogFil
cat $VcfFil.vcf | $VCFTOOLS/vcf-sort -c > $VcfFil.sorted.vcf
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Sort with vcftools $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $LogFil
    exit 1
fi
mv $VcfFil.sorted.vcf $VcfFil.vcf

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
