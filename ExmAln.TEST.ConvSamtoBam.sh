#!/bin/bash
#$ -cwd

ChaIn="no"

while getopts i:s:l:c: opt; do
  case "$opt" in
      i) SamFil="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
	  c) ChaIn="$OPTARG";;
  esac
done

#Load settings file
. $Settings

#Set local variables
TmpDir=$SamFil.Conversiontempdir
mkdir -p $TmpDir

#Start Log
uname -a >> $LogFil
echo "Start Convert SAM to BAM - $0:`date`" >> $LogFil
echo " Job name: "$JOB_NAME >> $LogFil
echo " Job ID: "$JOB_ID >> $LogFil
echo "----------------------------------------------------------------" >> $LogFil

#Run Jobs
#convert to bam and sort
echo "- Convert SAM to BAM and reorder using PICARD `date`..."  >> $LogFil
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/SortSam.jar INPUT=$SamFil.sam OUTPUT=$SamFil.bam SORT_ORDER=coordinate"
echo "    "$cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Convert SAM to BAM and reorder using PICARD failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
    exit 1
fi
BamFil=$SamFil
#Index BAM file
echo "- Index BAM file using PICARD `date`..." >> $LogFil
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $PICARD/BuildBamIndex.jar INPUT=$BamFil.bam"
echo "    "$cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Index BAM file using PICARD failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $LogFil

#Call Next Job if chain
if [[ $ChaIn = "chain" ]]; then
	echo "- Call Align with Stampy `date`:" >> $LogFil
	JobNm=${JOB_NAME#*.}
	cmd="qsub -pe smp 4 -l mem=4G,time=8:: -N Stmpy.TestQik -o stdostde/ -e stdostde/ /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/ExmAln.TEST.AlignSTAMPY.sh -i $BamFil -s $Settings -l $LogFil -c chain"
	echo "    "$cmd >> $LogFil
	$cmd
	echo "----------------------------------------------------------------" >> $LogFil
fi

#End Log
echo "End Convert SAM to BAM $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil

#Remove temp files
#rm -r $TmpDir $SamFil.sam $SamFil.bam 
