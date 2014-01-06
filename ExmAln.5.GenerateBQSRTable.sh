#!/bin/bash
#$ -cwd

while getopts i:s:d:l: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      s) Settings="$OPTARG";;
      d) RalDir="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
JobNm=${JOB_NAME#*.}
TmpDir=$BamFil.GenBQSR 
mkdir -p $TmpDir
RclTable=$BamFil.recal.table
RalFils=$BamFil.realignedfile.list
for i in $(find $RalDir/*bam); do
    echo " -I "$i >> $RalFils
done
RclInputArg=$(cat $RalFils)
#echo $RclInputArg >> $LogFil

#Start Log
uname -a >> $LogFil
echo "Start Generate Base Quality Score Recalibration Table with GATK - $0:`date`" >> $LogFil
echo " Job name: "$JOB_NAME >> $LogFil
echo " Job ID: "$JOB_ID >> $LogFil
echo "----------------------------------------------------------------" >> $LogFil

#Run Jobs
#Generate recalibration data file
echo "- Create recalibration data file using GATK BaseRecalibrator `date`..." >> $LogFil
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T BaseRecalibrator -R $REF -L $TARGET $RclInputArg -knownSites $DBSNPf -knownSites $INDEL -o $RclTable -nct $NumCores"
echo "    "$cmd >> $LogFil
$cmd
echo "----------------------------------------------------------------" >> $LogFil
echo ""

#Call Next Job
echo "- Call Analyse Base Score Covariation with GATK `date`:" >> $LogFil
cmd="qsub -pe smp $NumCores -l $AnaCovAlloc -N AnaCov.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.6a.AnalyseCovariation.sh -i $BamFil -t $RclTable -f $RalFils -s $Settings -l $LogFil"
echo "    "$cmd  >> $LogFil
$cmd

echo "- Call Apply Base Score Recalibration with GATK `date`:" >> $LogFil
cmd="qsub -t 1-24 -pe smp $NumCores -l $AppBQSRAlloc -N AppBQSR.$JobNm  -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.6.ApplyRecalibration.sh -i $BamFil -t $RclTable -d $RalDir -s $Settings -l $LogFil"
echo "    "$cmd  >> $LogFil
$cmd

echo "----------------------------------------------------------------" >> $LogFil

#End Log
echo "End Base Quality Score Recalibration $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil

#remove temporary files
rm -r $TmpDir $TmpTar #$RalFils $BamFil.bam $BamFil.bai
