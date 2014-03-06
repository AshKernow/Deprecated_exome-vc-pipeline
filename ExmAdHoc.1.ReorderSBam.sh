#!/bin/bash
#$ -l mem=8G,time=2:: -N ReorderSB -cwd

#Provide a settings file containing the following variables:
# REF - reference file to reorder against 
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
TmpDir=temp.$SamFil.Conversiontempdir
mkdir -p $TmpDir
TmpLog=$TmpDir/$SamFil.reordering.log
if [[ ! $LogFil ]]; then
	LogFil=$SamFil.reordering.log
fi
OutFil=${SamFil%.*}.reordered.${SamFil##*.}

#Start Log
uname -a >> $TmpLog
echo "Start Reorder SAM/BAM using PICARD - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog

#Reorder Bam
echo "- Reorder BAM file using PICARD `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/ReorderSam.jar INPUT=$SamFil OUTPUT=$OutFil REFERENCE=$REF CREATE_INDEX=TRUE"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Reorder SAM/BAM using PICARD failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
    exit 1
fi
#Index BAM file
#echo "- Index BAM file using PICARD `date`..." >> $TmpLog
#cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/BuildBamIndex.jar INPUT=$OutFil.bam"
#echo "    "$cmd >> $LogFil
# $cmd
#if [[ $? == 1 ]]; then
#	echo "----------------------------------------------------------------" >> $LogFil
 #   echo "Index BAM file using PICARD failed `date`" >> $LogFil
#	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
 #   exit 1
#fi


echo "End Reorder SAM/BAM using PICARD $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
#rm -r $TmpDir $TmpLog
