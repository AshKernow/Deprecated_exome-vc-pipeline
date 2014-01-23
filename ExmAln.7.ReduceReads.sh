#!/bin/bash
#$ -cwd

ChaIn="no"

while getopts i:d:s:l:c: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      d) RclDir="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
	  c) ChaIn="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
TmpDir=$BamFil.RR 
mkdir -p $TmpDir
JobNm=${JOB_NAME#*.}
TmpLog=$LogFil.RR.log
AllBamsDir=$(readlink -f ../$JobNm"_all_recalibrated_bams")
RrBamsDir=$(readlink -f ../$JobNm"_all_RR_bams")
BamFilMrg=$AllBamsDir/$BamFil.recal
BamFilRr=$RrBamsDir/$BamFil.recal.RR
#RclFils=$BamFil.recalibratedfile.list
#for i in $(find $RclDir/*bam); do
#    echo " -I "$i >> $RclFils
#done
#MrgInputArg=$(cat $RclFils)
RclLst=$BamFil.recalibratedfile.list
find $RclDir/*bam > $RclLst

#Start Log
uname -a >> $TmpLog
echo "Start Reduce Reads with GATK - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo " Meta JobNm:" $JobNm  >> $TmpLog
echo " Collation Directories: $AllBamsDir & $RrBamsDir"  >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Merge chromosome data
echo "- Merge individual chromosome bam files using GATK PrintReads `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T PrintReads -R $REF -I $RclLst -o $BamFilMrg.bam"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Merge individual chromosome bam files using GATK PrintReads failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi

#Generate reduced reads data file
echo "- Create Reduced Reads bam file using GATK ReduceReads `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T ReduceReads -R $REF -I $BamFilMrg.bam -o $BamFilRr.bam"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Create Reduced Reads bam file using GATK ReduceReads failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $TmpLog

#Call Next Job if chain
if [[ $ChaIn = "chain" ]]; then
	echo "- Call Depth of coverage `date`:" >> $TmpLog
	cmd="qsub -pe smp $NumCores -l $DepofCovAlloc -N DepCov.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.8a.DepthofCoverage.sh -i $BamFilRr -s $Settings -l $LogFil"
	echo "    "$cmd  >> $TmpLog
	$cmd
	echo "----------------------------------------------------------------" >> $TmpLog
fi

#End Log
echo "End Reduce Reads with GATK $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil

#remove Temporary Files
rm -r $TmpDir $TmpLog $RclDir
