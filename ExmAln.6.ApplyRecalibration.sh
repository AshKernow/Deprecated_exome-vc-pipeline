#!/bin/bash
#$ -cwd

ChaIn="no"

while getopts i:t:d:s:l:c: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      t) RclTable="$OPTARG";;
      d) RalDir="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
	  c) ChaIn="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
JobNm=${JOB_NAME#*.}
Chr=$SGE_TASK_ID
Chr=${Chr/23/X}
Chr=${Chr/24/Y}
TmpDir=$BamFil.appBQSR.$Chr
if [[ "$BUILD" = "hg19" ]]; then
	Chr=chr$Chr
fi
TmpLog=$LogFil.recal.$Chr.log
mkdir -p $TmpDir
RclDir=recal.$BamFil #directory for individual chromosome recalibration files
mkdir -p $RclDir
TmpTar=TmpTarFil.$Chr.bed #temporary target file
RclFil=$RclDir/recalibrated.$BamFil.Chr_$Chr.bam
StatFil=$JOB_ID.LocReal.stat #Status file to check if all chromosome are complete
RalFil=$RalDir/$(ls $RalDir | grep "Chr_$Chr.bam")

#Start Log
uname -a >> $TmpLog
echo "Start Apply Base Quality Score Recalibration on Chromosome $Chr with GATK - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Run Jobs
#Make chromosome specific exome target file
echo "CHR "$Chr >> $TmpLog
echo "Target File: "$TARGET >> $TmpLog
grep -E "^$Chr[[:blank:]]" $TARGET > $TmpTar
#Apply recalibration 
echo "- Apply recalibration data file using GATK PrintReads `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T PrintReads -R $REF -I $RalFil -L $TmpTar -BQSR $RclTable -o $RclFil -nct $NumCores"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $TmpLog
	echo "Apply recalibration data file using GATK PrintReads failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $TmpLog
	echo "=================================================================" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $TmpLog

#Call Next Job if chain
if [[ $ChaIn = "chain" ]]; then
	#calculate an amount of time to wait based on the chromosome and the current time past the hour
	#ensures that even if all the jobs finish at the same time they will each execute the next bit of code at 10 second intervals rather than all at once
	Sekunds=`date +%-S`
	Minnits=`date +%-M`
	Minnits=$((Minnits%4))
	Minnits=$((Minnits*60))
	Sekunds=$((Sekunds+Minnits))
	Chr=$SGE_TASK_ID
	GoTime=$((Chr-1))
	GoTime=$((GoTime*10))
	WaitTime=$((GoTime-Sekunds))
	if [[ $WaitTime -lt 0 ]]; then
	WaitTime=$((240+WaitTime))
	fi
	echo "- Check if all recalibrations are complete..." >> $TmpLog
	echo " Min:Sec past hour " `date +%M:%S` >> $TmpLog
	echo " Sleeping for "$WaitTime" seconds..." >> $TmpLog
	sleep $WaitTime
	#send marker to status file
	echo $Chr >> $StatFil
	#count markers in status file and if equals 24 call merge job
	RclFin=$(cat $StatFil | wc -l)
	if [ $RclFin -eq 24 ]; then
		echo " All recalibrations completed..." >> $TmpLog
		echo "- Call Reduce Reads with GATK `date`:" >> $TmpLog
		cmd="qsub -l $RRAlloc -N RR.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.7.ReduceReads.sh -i $BamFil -d $RclDir -s $Settings -l $LogFil -c chain"
		echo "    "$cmd  >> $TmpLog
		$cmd
	else
		echo " Recalibrations Finished at `date`: $RclFin" >> $TmpLog
		echo " Exiting..."
		grep -vE "^/ifs" $TmpLog > $TmpLog.2
		cat $TmpLog.2 > $TmpLog
		rm $TmpLog.2
	fi
	echo "----------------------------------------------------------------" >> $TmpLog
fi

#End Log
echo "End Apply Base Quality Score Recalibration on Chromosome $Chr $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog

cat $TmpLog >> $LogFil

#remove temporary files
rm -r $TmpLog $TmpDir $TmpTar
if [ $RclFin -eq 24 ]; then
	rm $StatFil $BamFil.bam $BamFil.bai
	if [[ -f AnaCovComplete ]]; then
		rm -r $RalDir AnaCovComplete
	else
		touch AppRecalComplete
	fi
fi

