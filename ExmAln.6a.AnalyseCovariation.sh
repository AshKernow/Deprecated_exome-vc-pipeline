#!/bin/bash
#$ -cwd

while getopts i:t:r:s:l: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";;
      t) RclTable="$OPTARG";;
      r) RalLst="$OPTARG";;
      s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

#Set local variables
TmpDir=$BamFil.AnaCov 
mkdir -p $TmpDir
PostRclTable=$BamFil.post_recal.table
RclPlot=$BamFil.recalibration_plots.pdf
RclCsv=$BamFil.recalibration_plots.csv
TmpLog=$LogFil.AnaCov.log
#RclInputArg=$(cat $RalFils)

#Start Log
uname -a >> $TmpLog
echo "Start Analyse Base Scores for Covariation with GATK - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo "----------------------------------------------------------------" >> $TmpLog

#Second pass recalibration to analyse covariation after recal
echo "- Second pass to analyse covariation after recal using GATK BaseRecalibrator `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx4G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T BaseRecalibrator -R $REF -L $TARGET -I $RalLst -knownSites $DBSNP -knownSites $INDEL -BQSR $RclTable -o $PostRclTable -nct $NumCores"
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
rm -r $TmpDir $TmpLog
