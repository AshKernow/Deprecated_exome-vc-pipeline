#!/bin/bash
#$ -l mem=8G,time=2:: -N GetMetricsSB -cwd

#Provide a settings file containing the following variables:
# REF - Reference sequence fasta file
# PICARD - path to picard
# JAVA7BIN - path to java


while getopts i:s:l: opt; do
  case "$opt" in
      i) SamFil="$OPTARG";; #sam or bam file to be reordered
      s) Settings="$OPTARG";; # settings file
      l) LogFil="$OPTARG";; #log file to output to - optional
  esac
done

#Load settings file
. $Settings

#Set local variables
TmpDir=temp.$SamFil.QCtempdir
mkdir -p $TmpDir
TmpLog=$TmpDir/$SamFil.QualMetrics.log
if [[ ! $LogFil ]]; then
	LogFil=$SamFil.QualMetrics.log
fi
OutFil=${SamFil%.*}.qualitymetrics

#Start Log
uname -a >> $TmpLog
echo "Start Get Quality Metrics from SAM/BAM using PICARD - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog

#Quality Score Distribution
echo "- Get Quality Score Distribution from BAM file using PICARD `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/QualityScoreDistribution.jar CHART_OUTPUT=$OutFil.QualityScoreDistr.pdf INPUT=$SamFil OUTPUT=$OutFil REFERENCE_SEQUENCE=$REF"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Get Quality Score Distribution from  SAM/BAM using PICARD failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
    exit 1
fi




echo "End Get Quality Metrics from SAM/BAM using PICARD $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
#rm -r $TmpDir $TmpLog
