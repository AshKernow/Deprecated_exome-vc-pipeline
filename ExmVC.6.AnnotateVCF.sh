#!/bin/bash
#$ -cwd 

while getopts i:d:s:l: opt; do
  case "$opt" in
      i) AnnFilLst="$OPTARG";;
	  d) AnnFilDir="$OPTARG";;
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
AnnVcfLst=$AnnFilDir/Annotated_VCFs.list


#Start log file
uname -a >> $TmpLog
echo "Start Annotate Individual Sample VCFs using ANNOVAR $JOB_NAME $JOB_ID - $0:`date`" >> $TmpLog
echo "Job name: "$JOB_NAME >> $TmpLog
echo "Job ID: "$JOB_ID>> $TmpLog
echo "Task ID: $JobNum/$NumJobs"  >> $TmpLog
echo "Input File: "$AnnInp >> $TmpLog

##Build Annotation table
echo "- Build Annotation table using ANNOVAR `date` ..." >> $TmpLog
grep -vE "^#" $AnnInp > $AnnInp.tmp
cmd="$ANNDIR/table_annovar.pl $AnnInp.tmp $ANNDIR/humandb/ --buildver hg19 --remove -protocol refGene,1000g2012apr_all,snp137,ljb2_all -operation g,f,f,f -nastring \"\"  -otherinfo --outfile $OutFil"
echo $cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Build Annotation table using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
    exit 1
fi
AnntCmd=$cmd
AnnFil=$OutFil.hg19_multianno.txt
rm $AnnInp.tmp
echo "" >> $TmpLog
echo "Built Annotation table using ANNOVAR `date`" >> $TmpLog
echo "" >> $TmpLog

##Convert ANNOVAR format back to VCF incorporating the ANNOVAR annotations
echo "- Convert ANNOVAR back to VCF using R `date` ..." >> $TmpLog
 #call R script with following arguments: 
	# (1) ANNOVAR input data file used above
	# (2) ANNOVAR annotation table generated above 
	# (3) ANNOVAR annotation VCF meta-information INFO lines (resources)  
	# (4) ANNOVAR command used in ExmVC.5.ConvertforANNOVAR 
	# (5) ANNOVAR command used above to generate the annotation
ConvCmd=$(grep convert2annovar $LogFil | tail -n1) # get (4) from log file
cmd="Rscript $EXOMSCR/ExmVC.6R.BuildVCF.R $AnnInp $AnnFil $VCFAnnovarHeader $ConvCmd $AnntCmd"
echo $cmd >> $TmpLog
# Rscript $EXOMSCR/ExmVC.6R.BuildVCF.R "$AnnInp" "$AnnFil" "$VCFAnnovarHeader" "$ConvCmd" "$AnntCmd"
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Convert ANNOVAR back to VCF using R $JOB_NAME $JOB_ID failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
    exit 1
fi
echo "" >> $TmpLog
echo "Converted ANNOVAR back to VCF using R `date`" >> $TmpLog
echo "" >> $TmpLog
VcfFil=${AnnInp/avinput/annotated.vcf}

##Index the new VCF file
echo "- Index VCF using vcftools `date` ..." >> $TmpLog
cmd="vcftools --vcf $VcfFil"
echo $cmd >> $TmpLog
# $cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Index VCF using vcftools $JOB_NAME $JOB_ID failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage " >> $TmpLog
    exit 1
fi
mv $VcfFil.vcfidx $VcfFil.idx
echo "" >> $TmpLog
echo "Indexed VCF using vcftools `date`" >> $TmpLog
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
	find $AnnFilDir/ -type f | grep -E "vcf$" > $AnnVcfLst
	cmd="qsub -l $RmgVCFAlloc -N MgAnV.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.7.MergeAnnotatedVCF.sh -i $AnnVcfLst -s $Settings -l $LogFil"
	echo $cmd  >> $TmpLog
	# $cmd
	echo "" >> $TmpLog
else
	echo "Annotate individual VCFs still running: "$VCsrunning" "`date` >> $TmpLog
	echo "Exiting..." >> $TmpLog
fi

echo "" >> $TmpLog
echo "End Annotate Individual Sample VCFs using ANNOVAR $JOB_NAME $JOB_ID $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage *$JobNum:" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
rm $TmpLog

