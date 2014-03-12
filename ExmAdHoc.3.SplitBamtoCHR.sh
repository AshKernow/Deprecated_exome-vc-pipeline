#!/bin/bash
#$ -t 1-24 -l mem=8G,time=2:: -N SplitBam -cwd

#Provide a settings file containing the following variables:
# REF - Reference sequence fasta file
# PICARD - path to picard
# JAVA7BIN - path to java


while getopts i:s:l: opt; do
  case "$opt" in
      i) BamFil="$OPTARG";; #sam or bam file to be reordered
      s) Settings="$OPTARG";; # settings file
      l) LogFil="$OPTARG";; #log file to output to - optional
  esac
done

#Load settings file
. $Settings

#Set local variables
BamFil=${BamFil/.bam/}
Chr=$SGE_TASK_ID
Chr=${Chr/23/X}
Chr=${Chr/24/Y}
if [[ "$BUILD" = "hg19" ]]; then
	Chr=chr$Chr
fi
TmpDir=temp.$BamFil.$Chr.tempdir
mkdir -p $TmpDir
TmpLog=$BamFil.$Chr.Split.log
OutDir=$BamFil"_by_Chromosome"
mkdir -p $OutDir
OutFil=$OutDir/$BamFil.$Chr.bam

#Start Log
uname -a >> $TmpLog
echo "Start Split into Chromosomes using GATK $Chr - $0:`date`" >> $TmpLog
echo " Job name: "$JOB_NAME >> $TmpLog
echo " Job ID: "$JOB_ID >> $TmpLog
echo " Chromosome: "$Chr >> $TmpLog

echo "- Split using GATK PrintReads `date`..." >> $TmpLog
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T PrintReads -R $REF -I $BamFil.bam -L $Chr -o $OutFil -nct $NumCores"
echo "    "$cmd >> $TmpLog
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $TmpLog
    echo "Split using GATK PrintReads $Chr failed `date`" >> $TmpLog
	qstat -j $JOB_ID | grep -E "usage *$SGE_TASK_ID:" >> $TmpLog
	cat $TmpLog >> $LogFil
    exit 1
fi
echo "----------------------------------------------------------------" >> $TmpLog



echo "End Split into Chromosomes using GATK $Chr $0:`date`" >> $TmpLog
qstat -j $JOB_ID | grep -E "usage" >> $TmpLog
echo "===========================================================================================" >> $TmpLog
echo "" >> $TmpLog
cat $TmpLog >> $LogFil
#rm -r $TmpDir $TmpLog
