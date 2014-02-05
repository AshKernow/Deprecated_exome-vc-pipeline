#!/bin/bash
#$ -cwd 

while getopts i:s:l: opt; do
  case "$opt" in
      i) VcfFil="$OPTARG";;
	  s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

uname -a >> $LogFil
echo "Start Convert for ANNOVAR - $0:`date`" >> $LogFil
echo "" >> $LogFil
echo "Job name: "$JOB_NAME >> $LogFil
echo "Job ID: "$JOB_ID >> $LogFil

##Set local parameters
JobNm=${JOB_NAME#*.}
TmpDir=$JobNm.CnvAnn 
mkdir -p $TmpDir
AnnFilLst=$TmpDir/$TmpDir"_Files.list"

##Build the SNP recalibration model
echo "- Convert VCF to ANNOVAR input file using ANNOVAR `date` ..." >> $LogFil

cmd="$ANNDIR/convert2annovar.pl $VcfFil -format vcf4 -includeinfo -allsample -comment -outfile $TmpDir/$VcfFil"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Convert VCF to ANNOVAR input file using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
echo "$(ls $TmpDir | grep $VcfFil | grep avinput)" > $AnnFilLst
NumFils=$(cat $AnnFilLst | wc -l)
echo "Converted VCF to $NumFils ANNOVAR input files `date`" >> $LogFil
echo "" >> $LogFil

#Call next job
echo "- Call Annotate VCF with ANNOVAR `date`:" >> $LogFil
JobNm=${JOB_NAME#*.}
#cmd="qsub -t 1-$NumFils -l $AnnVCFAlloc -N AnnVCF.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.6.AnnotateVCF.sh -i $AnnFilLst -d $TmpDir -v $VcfFil -s $Settings -l $LogFil"
cmd="qsub -t 1-1 -l $AnnVCFAlloc -N AnnVCF.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.6.AnnotateVCF.sh -i $AnnFilLst -d $TmpDir -v $VcfFil -s $Settings -l $LogFil"

echo "    "$cmd  >> $LogFil
$cmd
echo "----------------------------------------------------------------" >> $LogFil

echo "" >> $LogFil
echo "End Convert for ANNOVAR $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage " >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
