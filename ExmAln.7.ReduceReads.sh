#!/bin/bash
#$ -cwd

while getopts i:d:s:l: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      d) RclDir="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
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
RclFils=$BamFil.recalibratedfile.list
for i in $(find $RclDir/*bam); do
    echo " -I "$i >> $RclFils
done
MrgInputArg=$(cat $RclFils)

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
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T PrintReads -R $REF $MrgInputArg -o $BamFilMrg.bam"
echo "    "$cmd >> $TmpLog
$cmd


#Generate recalibration data file
echo "- Create Reduced Reads bam file using GATK ReduceReads `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T ReduceReads -R $REF -I $BamFilMrg.bam -o $BamFilRr.bam"
echo "    "$cmd >> $TmpLog
$cmd
#echo "----------------------------------------------------------------" >> $TmpLog

#Call Next JOb
echo "- Call Depth of coverage `date`:" >> $TmpLog
cmd="qsub -pe smp $NumCores -l $DepofCovAlloc -N DepofCov.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.8a.DepthofCoverage.sh -i $BamFilRr -s $Settings -l $LogFil"
echo "    "$cmd  >> $TmpLog
# $cmd
echo "----------------------------------------------------------------" >> $TmpLog

#End Log
echo "End Reduce Reads with GATK $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil

#remove Temporary Files
rm -r $TmpDir $TmpLog $RclDir
