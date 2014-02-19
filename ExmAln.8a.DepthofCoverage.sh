#!/bin/bash
#$ -cwd

while getopts i:d:s:l: opt; do
  case "$opt" in
      i) BamFilRr="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set Local Variables
TmpDir=$BamFilRr.DoC 
mkdir -p $TmpDir
TmpLog=$LogFil.DoC.log
JobNm=${JOB_NAME#*.}
OutFil=$(basename $BamFilRr)
OutFil=${OutFil%%.*}.DoC

#Start Log
uname -a >> $TmpLog
echo "Start Depth of Coverage with GATK - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Generate recalibration data file
echo "- Calculate depth of coverage statistics using GATK DepthOfCoverage `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx5G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T DepthOfCoverage -R $REF -I $BamFilRr.bam -L $TARGET -o $OutFil -ct 1  -ct 5 -ct 10 -ct 15 -ct 20 -nt $NumCores -omitIntervals"
echo "    "$cmd >> $TmpLog
$cmd
echo "----------------------------------------------------------------" >> $TmpLog

#End Log
echo "End Depth of Coverage with GATK $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
#Remove Temporary files
rm -r $TmpDir $TmpLog $OutFil
