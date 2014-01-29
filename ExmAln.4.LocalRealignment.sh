#!/bin/bash
#$ -cwd

ChaIn="no"

while getopts i:b:s:l:c: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
	  b) BamLst="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
	  c) ChaIn="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local Variables
Chr=$SGE_TASK_ID
Chr=${Chr/23/X}
Chr=${Chr/24/Y}
TmpLog=$LogFil.LocReal.$Chr.log
JobNm=${JOB_NAME#*.}
TmpDir=$BamFil.$Chr.Realignjavdir #java temp directory
mkdir -p $TmpDir
RalDir=realign.$BamFil #directory to collect individual chromosome realignments
mkdir -p $RalDir
StatFil=$JOB_ID.LocReal.stat #Status file to check if all chromosome are complete
TgtFil=$RalDir/$BamFil.$Chr.target_intervals.list

#Start Log
uname -a >> $TmpLog
echo "Start Local Realignment around InDels on Chromosome $Chr - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo " Chromosome: "$Chr >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Run jobs
#Generate target file
echo "- Create target interval file using GATK RealignerTargetCreator `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T RealignerTargetCreator -R $REF -I $BamLst -L $Chr -known $INDEL -o $TgtFil -nt $NumCores"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Create target interval file using GATK RealignerTargetCreator failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi
#Realign InDels
realignedFile=$RalDir/realigned.$BamFil.Chr_$Chr.bam
echo "- Realign InDels file using GATK IndelRealigner `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T IndelRealigner -R $REF -I $BamLst -targetIntervals $TgtFil -known $INDEL -o $realignedFile"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Realign InDels file using GATK IndelRealigner failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $TmpLog

#Call next job if chain
if [[ $ChaIn = "chain" ]]; then
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
	echo "- Check if all realigns are complete..." >> $TmpLog
	echo " Min:Sec past hour " `date +%M:%S` >> $TmpLog
	echo " Sleeping for "$WaitTime" seconds..." >> $TmpLog
	sleep $WaitTime
	#send marker to status file
	echo $CHR >> $StatFil
	#count markers in status file and if equals 24 call merge job
	ralfin=$(cat $StatFil | wc -l)
	if [ $ralfin -eq 24 ]; then
		echo " All realigns complete at `date`" >> $TmpLog
		echo "- Call Base Quality Score Recalibration with GATK `date`:" >> $TmpLog
		cmd="qsub -pe smp $NumCores -l $GenBQSRAlloc -N GnBQSR.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.5.GenerateBQSRTable.sh -i $BamFil -s $Settings -d $RalDir -l $LogFil -c chain"
		echo "    "$cmd  >> $TmpLog
		$cmd
	else
		echo " Realigns Finished at `date`: $ralfin" >> $TmpLog
		echo " Exiting..."
		grep -vE "^/ifs" $TmpLog > $TmpLog.2
		cat $TmpLog.2 > $TmpLog
		rm $TmpLog.2
	fi
	echo "----------------------------------------------------------------" >> $LogFil
fi

#End Log
echo "End Local Realignment of Chromosome $Chr $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil

#remove temporary files
rm -r $TmpLog $TmpDir $TgtFil
if [ $ralfin -eq 24 ]; then
    rm $StatFil $BamFilLst ${BamFilLst//bam/bai}
fi
