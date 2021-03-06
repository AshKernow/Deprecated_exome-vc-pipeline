#!/bin/bash
#$ -cwd

ChaIn="no"

while getopts i:s:d:l:c: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      s) Settings="$OPTARG";;
      d) RalDir="$OPTARG";;
      l) LogFil="$OPTARG";;
	  c) ChaIn="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
JobNm=${JOB_NAME#*.}
TmpDir=$BamFil.GenBQSR 
mkdir -p $TmpDir
RclTable=$BamFil.recal.table
#RalFils=$BamFil.realignedfile.list
#for i in $(find $RalDir/*bam); do
#    echo " -I "$i >> $RalFils
#done
#RclInputArg=$(cat $RalFils)
#echo $RclInputArg >> $LogFil
RalLst=$BamFil.realignedfile.list
find $RalDir/*bam > $RalLst


#Start Log
uname -a >> $LogFil
echo "Start Generate Base Quality Score Recalibration Table with GATK - $0:`date`" >> $LogFil
echo " Job name: "$JOB_NAME >> $LogFil
echo " Job ID: "$JOB_ID >> $LogFil
echo "----------------------------------------------------------------" >> $LogFil

#Run Jobs
#Generate recalibration data file
echo "- Create recalibration data file using GATK BaseRecalibrator `date`..." >> $LogFil
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T BaseRecalibrator -R $REF -L $TARGET -I $RalLst -knownSites $DBSNP -knownSites $INDEL -knownSites $INDEL1KG -o $RclTable -nct $NumCores"
echo "    "$cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Create recalibration data file using GATK BaseRecalibrator failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage" >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $LogFil
echo ""

#Call Next Job if chain
if [[ $ChaIn = "chain" ]]; then
	echo "- Call Analyse Base Score Covariation with GATK `date`:" >> $LogFil
	cmd="qsub -pe smp $NumCores -l $AnaCovAlloc -N AnaCov.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.6a.AnalyseCovariation.sh -i $BamFil -t $RclTable -r $RalLst -d $RalDir -s $Settings -l $LogFil"
	echo "    "$cmd  >> $LogFil
	$cmd
	echo "- Call Apply Base Score Recalibration with GATK `date`:" >> $LogFil
	cmd="qsub -t 1-24 -pe smp $NumCores -l $AppBQSRAlloc -N ApBQSR.$JobNm  -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.6.ApplyRecalibration.sh -i $BamFil -t $RclTable -d $RalDir -s $Settings -l $LogFil -c chain"
	echo "    "$cmd  >> $LogFil
	$cmd
	echo "----------------------------------------------------------------" >> $LogFil
fi

#End Log
echo "End Base Quality Score Recalibration $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil

#remove temporary files
rm -r $TmpDir $TmpTar #$RalFils $BamFil.bam $BamFil.bai
