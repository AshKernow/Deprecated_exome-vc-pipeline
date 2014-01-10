#!/bin/bash
#$ -cwd 

while getopts i:d:s:l: opt; do
  case "$opt" in
      i) BamLst="$OPTARG";;
      d) BamDir="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

CHR=$SGE_TASK_ID
if [[ $CHR == "23" ]]
    then
    CHR="X"
fi
if [[ $CHR == "24"  ]]
    then
    CHR="Y"
fi
ChrNm=CHR_$CHR
if [ $CHR -le 9 ]; then
	ChrNm=CHR_0$CHR
fi
TmpLog=$LogFil.LocReal.$ChrNm.log

uname -a >> $TmpLog
echo "Start Variant Calling on Chromosome $CHR with GATK HaplotypeCaller - $0:`date`" >> $TmpLog
echo "" >> $TmpLog
echo "Job name: "$JOB_NAME >> $TmpLog
echo "Job ID: "$JOB_ID >> $TmpLog

JobNm=${JOB_NAME#*.}
TmpDir=$JobNm.$ChrNm.VC 
mkdir -p $TmpDir

##Set local parameters
#get exome capture range for chromosome
Range=$TmpDir/Range$ChrNm.bed
grep -E "^$CHR\b" $TARGET > $Range
#add path to file list
BamLstDir=$TmpDir/$JobNm.$ChrNm.bam.list
awk -v x=$BamDir '{print x"/"$1}' $BamLst >> $BamLstDir
#Output File
VcfDir=$JobNm"VCFbyCHR"
VcfFil=$VcfDir$JobNm.$ChrNm.raw_variants.vcf
mkdir -p $VcfDir
echo "Output Directory: "$VcfDir >> $TmpLog
echo "Output File: "$VcfFil >> $TmpLog
#Annotation fields to output into vcf files
infofields="-A AlleleBalance -A BaseQualityRankSumTest -A Coverage -A HaplotypeScore -A HomopolymerRun -A MappingQualityRankSumTest -A MappingQualityZero -A QualByDepth -A RMSMappingQuality -A SpanningDeletions "

##Run Joint Variant Calling
echo "Variant Calling with GATK HaplotypeCaller..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR  -T HaplotypeCaller -R $REF -L $Range -nct $NumCores -I $BamLstDir --genotyping_mode DISCOVERY -stand_emit_conf 10 -stand_call_conf 30 -o $VcfDir/$VcfFil $DBSNP135 --comp:HapMapV3 $HpMpV3 $infofields -rf BadCigar"
echo $cmd >> $TmpLog
$cmd
echo "" >> $TmpLog
echo "Variant Calling done." >> $TmpLog
echo "" >> $TmpLog

#Need to wait for all 24 HaplotypeCaller jobs to finish and then remerge all the vcfs
#calculate an amount of time to wait based on the chromosome and the current time past the hour
#ensures that even if all the jobs finish at the same time they will each execute the next bit of code at 10 second intervals rather than all at once
Sekunds=`date +%-S`
Minnits=`date +%-M`
Minnits=$((Minnits%4))
Minnits=$((Minnits*60))
Sekunds=$((Sekunds+Minnits))
CHR=$SGE_TASK_ID
GoTime=$((CHR-1))
GoTime=$((GoTime*10))
WaitTime=$((GoTime-Sekunds))
if [[ $WaitTime -lt 0 ]]; then
WaitTime=$((240+WaitTime))
fi
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
	$cmd
	echo "" >> $TmpLog
else
	echo "HaplotypeCallers still running: "$VCsrunning" "`date` >> $TmpLog
	echo "Exiting..."
fi

echo "End Variant Calling with GATK HaplotypeCaller on Chromosome $Chr $0:`date`" >> $TmpLog
echo ""
qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
echo "" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
rm -r $TmpLog $TmpDir
