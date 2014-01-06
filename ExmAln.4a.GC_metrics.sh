#!/bin/bash
#$ -cwd

while getopts i:s:l: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local Variables
TmpLog=$LogFil.GCtemp
TmpDir=$BamFil.GCtempdir
mkdir -p $TmpDir

#Start Log
uname -a >> $TmpLog
echo "Start Get GC metrics with Picard - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Get GC metrics with Picard
echo "- Get GC Metrics with Picard `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/CollectGcBiasMetrics.jar INPUT=$BamFil.bam  OUTPUT=$BamFil.GCbias_detail CHART=$BamFil.GCbias.pdf REFERENCE_SEQUENCE=$REF VALIDATION_STRINGENCY=SILENT WINDOW_SIZE=200"
echo "    "$cmd >> $TmpLog
$cmd
#Get Insert size metrics with Picard
echo "- Get Insert Size Metrics with Picard `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/CollectInsertSizeMetrics.jar INPUT=$BamFil.bam  OUTPUT=$BamFil.InsertSize_detail HISTOGRAM_FILE=$BamFil.InsertSize.pdf VALIDATION_STRINGENCY=SILENT"
echo "    "$cmd >> $TmpLog
$cmd
echo "----------------------------------------------------------------" >> $TmpLog

#End Log
echo "End Get GC metrics with Picard $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil

#remove temp files
rm -r $TmpLog $TmpDir
