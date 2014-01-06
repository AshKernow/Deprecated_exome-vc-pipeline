#!/bin/bash
#$ -cwd

while getopts i:t:f:s:l:N: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      t) RclTable="$OPTARG";;
      f) RalFils="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
	  N) NCores="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
TmpDir=$BamFil.AnaCov.$NCores 
mkdir -p $TmpDir
PostRclTable=$BamFil.post_recal.$NCores.table
RclPlot=$BamFil.recalibration_plots.$NCores.pdf
RclCsv=$BamFil.recalibration_plots.$NCores.csv
TmpLog=$LogFil.AnaCov.$NCores.log
RclInputArg=$(cat $RalFils)

echo $BamFil
echo $RclTable
echo $RalFils
echo $Settings
echo $LogFil
echo $TmpDir
echo $PostRclTable
echo $RclPlot
echo $RclCsv
echo $TmpLog
echo $RclInputArg

#Start Log
uname -a >> $TmpLog
echo "Start Analyse Base Scores for Covariation with GATK - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Second pass recalibration to analyse covariation after recal
echo "- Second pass to analyse covariation after recal using GATK BaseRecalibrator `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T BaseRecalibrator -R $REF -L $TARGET $RclInputArg -knownSites $DBSNP -knownSites $INDEL -BQSR $RclTable -o $PostRclTable -nct $NCores"
echo "    "$cmd >> $TmpLog
$cmd
#Generate before and after plots
echo "- Generate Before and After plots using GATK AnalyzeCovariates `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T AnalyzeCovariates -R $REF -L $TARGET -before $RclTable -after $PostRclTable -plots $RclPlot -csv $RclCsv"
echo "    "$cmd >> $TmpLog
$cmd
echo "----------------------------------------------------------------" >> $TmpLog
echo "----------------------------------------------------------------"

#End Log
echo "" >> $TmpLog
echo "End Analyse Base Scores for Covariation $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil

#Remove temporary files
#rm -r $TmpDir $TmpLog
