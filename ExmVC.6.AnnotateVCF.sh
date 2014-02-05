#!/bin/bash
#$ -cwd 

while getopts i:d:v:s:l: opt; do
  case "$opt" in
      i) AnnFilLst="$OPTARG";;
	  d) AnnFilDir="$OPTARG";;
	  v) VcfFil="$OPTARG";;
	  s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

##Set local parameters
JobNm=${JOB_NAME#*.}
JobNum=$SGE_TASK_ID
NumJobs=$(cat $AnnFilLst | wc -l)
TmpDir=$JobNm.CnvAnn 
mkdir -p $TmpDir
AnnFilLst=$TmpDir/$TmpDir"_Files.list"
TmpLog=$LogFil.AnnVCF.$JobNum.log
AnnInp=$AnnFilDir/$(tail -n +$JobNum $AnnFilLst | head -n 1)
OutFil=${AnnInp/.avinput/}


#Start log file
uname -a >> $TmpLog
echo "Annotate Individual Sample VCFs using ANNOVAR - $0:`date`" >> $TmpLog
echo "Job name: "$JOB_NAME >> $TmpLog
echo "Job ID: "$JOB_ID >> $TmpLog
echo "Task ID: "$JobNum >> $TmpLog
echo "Input File: "$AnnInp >> $TmpLog

##Build Annotation table
echo "- Build Annotation table using ANNOVAR `date` ..." >> $TmpLog
grep -vE "^#" $AnnInp > $AnnInp.tmp
cmd="$ANNDIR/table_annovar.pl $AnnInp.tmp $ANNDIR/humandb/ --buildver hg19 --remove -protocol refGene,1000g2012apr_all,snp137,ljb2_all -operation g,f,f,f -nastring \"\" --outfile $OutFil"
echo $cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Build Annotation table using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
    exit 1
fi
rm $AnnInp.tmp
echo "" >> $TmpLog
echo "Built Annotation table using ANNOVAR `date`" >> $TmpLog
echo "" >> $TmpLog

##Convert ANNOVAR format back to VCF incorporating the ANNOVAR annotations
echo "- Convert ANNOVAR back to VCF `date` ..." >> $TmpLog


if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Build Annotation table using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
    exit 1
fi
echo "" >> $TmpLog
echo "Built Annotation table using ANNOVAR `date`" >> $TmpLog
echo "" >> $TmpLog










#Call next job
#Need to wait for all Annotation jobs to finish and then remerge all the vcfs
#calculate an amount of time to wait based on the Task Number and the current time past the hour
#ensures that even if all the jobs finish at the same time they will each execute the next bit of code at 10 second intervals rather than all at once
Sekunds=`date +%-S`
Minnits=`date +%-M`
Minnits=$((Minnits*60))
Sekunds=$((Sekunds+Minnits))
Sekunds=$((Sekunds/10))
NoTime=$((Sekunds%NumJobs))
WaitTime=$((JobNum-NoTime))
if [[ $WaitTime -lt 0 ]]; then
WaitTime=$((NumJobs+WaitTime))
fi
WaitTime=$((WaitTime*10))
echo "" >> $TmpLog
echo "Test for completion Time:" `date +%M:%S` >> $TmpLog
echo "Sleeping for "$WaitTime" seconds..." >> $TmpLog
sleep $WaitTime

VCsrunning=$(qstat | grep $JOB_ID | wc -l)
qstat | grep $JOB_ID >> $TmpLog
if [ $VCsrunning -eq 1 ]; then
	echo "All completed:`date`" >> $TmpLog
	echo "----------------------------------------------------------------" >> $TmpLog
	echo "" >> $TmpLog
	echo "Call Merge with vcftools ...:" >> $TmpLog
	echo ""
	cmd="qsub -l $RmgVCFAlloc -N RmgVCF.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.3.MergeVCF.sh -d $VcfDir -s $Settings -l $LogFil"
	echo $cmd  >> $TmpLog
	# $cmd
	echo "" >> $TmpLog
else
	echo "HaplotypeCallers still running: "$VCsrunning" "`date` >> $TmpLog
	echo "Exiting..." >> $TmpLog
fi

echo "" >> $TmpLog
echo "End Annotate Individual Sample VCFs using ANNOVAR $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
