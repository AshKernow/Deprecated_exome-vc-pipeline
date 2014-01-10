#!/bin/bash
#$ -cwd
# This script will ask for the paths to the various files required to run just the local realignment and recalibration (R&R) steps on a set of aligned and indexed bam files. It is primarily for use on bam files that have already undergone R&R at the lane level that you now wish to rerun R&R at the sample level.
# A file containing global setting for software locations, reference file locations, and cluster memory and time allocations for each step must be provided. The default is the BISR_Exome_pipeline_settings.sh file.
# The script will then call the first the job in the pipeline
# The main input is a file containing a table of two columns, the first column is the list of bam files (must have associated bai files) and the second column is the sample to which each bam file belongs. The table should include the full path to the files (thus they do not need to be in the same directory.
echo ""
echo "Enter the required information for Realignment/Recalibration (R&R) pipeline."
echo "Default values are shown in square brackets."
echo "Press [Enter] to select default value where provided or to skip optional parameters."
echo ""
echo "==========================================================================================="
echo ""
echo "Note the following requirements:"
echo ""
echo "   The main input is a file containing a tab-delimited table of two columns, the first column is the list of bam files (must have associated bai files) and the second column is the sample to which each bam file belongs. The table should include the full path to the files (thus they do not need to be in the same directory."
echo "        e.g.:"
echo "                dir1/bam_file_1_L005.bam         Sample_1"
echo "                dir1/bam_file_1_L006.bam         Sample_1"
echo "                dir1/bam_file_2_L005.bam         Sample_2"
echo "                dir1/bam_file_2_L006.bam         Sample_2"
echo "                dir2/bam_file_3_L007.bam         Sample_3"
echo "                dir2/bam_file_3_L008.bam         Sample_3"
echo "    Bam file MUST NOT be Reduced Reads files."
echo "==========================================================================================="
echo ""
echo ""

#File containing list of Bam files
BamTab=""
read -e -p "File containing list of bam files to be realigned together: " BamTab
if [ ! "$BamTab" ] #check for input
then
echo "----------------------------------------------------------------"
echo "Can not align nothing."
exit 1
fi
if [ ! -f $BamTab ]; then #check to see if file exists
	echo "----------------------------------------------------------------"
	echo $BamTab" Does not exist."
	exit 1
fi
echo "   Checking for fastq files..."
#check existence of bam files in the list
FilList=$(cut -f1 $BamTab)#Read 1 files
MisFil=Missing_Fastq_files$(date '+%d%b%Yt%H%M') #Output files for list of missing files
for i in $FilList; do #check each file
	if [ ! -f $i ]; then #if file doesn't exist send name to output file
		echo $i >> $MisFil
	fi
done
if [ -f $MisFil ]; then #if output file is not empty
	sort $MisFil | uniq > $MisFil
	echo "   The following files do not exist in the directory."
	cat $MisFil
	echo "Exiting..."
	exit 1
else #if all fastq files were found
	echo "   Found all fastq files"
fi
echo "----------------------------------------------------------------"
#Global settings
read -e -p "Global settings files [BISR_Exome_pipeline_settings]: " Settings
echo "----------------------------------------------------------------"
if [ ! "$Settings" ]; then #if no input use default global settings file
	echo "   Using BISR_Exome_pipeline_settings"
	Settings="/ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/resources/BISR_Exome_pipeline_settings.sh"
	echo "----------------------------------------------------------------"
fi
if [ ! -f $Settings ]; then #check the global settings file exists
	echo $Settings" Does not exist."
	exit 1
fi
Settings=$(readlink -f $Settings)
#A name for the R&R job, this will be used to generate the job names on the cluster, output directories and log file names
read -e -p "Name for the R&R job (*optional*): " JobNm
mydate="_"$(date '+%y%m%d.%H%M')
if [ ! "$JobNm" ]; then # if no input use the date to generate a unique Job Name
	JobNm=ExmVCd$(date '+%d%b%Yt%H%M')
	JobNm=${JobNm// /}
	JobNm=${JobNm//:/}
	mydate=""
	echo "Job Name: "$JobNm
fi
#Output Directory
read -e -p "Output directory (will create if does not exist): " OutDir 
if [ -e $OutDir ] &&  [ ! -d $OutDir ]; then #if a file has been given instead of a directory
	echo "----------------------------------------------------------------"
	echo $OutDir" is not a directory."
	exit
fi
if [ ! -d $OutDir ]; then #if the directory does not exist
	echo "----------------------------------------------------------------"
	echo "The directory "$OutDir" does not exist. It will be created if you proceed."
fi

#Load Settings
. $Settings 
#Samples to undergo joint R/R
BamSams=$(cut -f2 $BamTab | sort | uniq)

echo "R&R Pipeline will be initiated with the following samples:"
for i in $BamSams; do
	echo "Sample: "$i
	awk 


read -e -p "Proceed? y/n: " gogogo
if [ "$gogogo" != y ]; then 
	exit 1
fi

#Generate log file output directories
LogFil="AlnExm."$JobNm$mydate".log"
AllBamsDir=$JobNm"_all_recalibrated_bams" #directory for recalibrated BAM files (gzipped)
RrBamsDir=$JobNm"_all_RR_bams" #directory for reduced read versions of recalibrated bam files
echo "----------------------------------------------------------------"
echo "   Individual sample processing logs will be recorded in $LogFil.[readgroup ID].log"
echo "----------------------------------------------------------------"
echo "   Final Aligned BAMs for all samples will be collected in $AllBamsDir - note these will be at the lane level"
echo "   Final Aligned reduced read BAMs for all samples will be collected in $RrBamsDir"
echo "----------------------------------------------------------------"

cmd="qsub -t 1:$NFILS -pe smp $nthreads -l $mapExmAlloc -N mapExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.2.Align_BWA.sh -i $FqFil -f $FqDir -s $Settings -l $LogFil"

echo ""

mkdir -p $OutDir
echo "Current directory: "$PWD > $OutDir/$LogFil
echo "Output Directory: "$OutDir >> $OutDir/$LogFil
echo "Fastq File List:"$FqFil >> $OutDir/$LogFil
echo "Fastq Directory: "$FqDir >> $OutDir/$LogFil

cd $OutDir
mkdir -p stdostde/
mkdir -p $AllBamsDir
mkdir -p $RrBamsDir
echo $cmd >> $LogFil
$cmd
echo "qsub time: `date`" >> $LogFil
echo "" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil






echo "- Call GATK realign, 1 job for each Chr `date`:" >> $LogFil
cmd="qsub -pe smp $NumCores -t 1-24 -l $realnAlloc -N realn.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmAln.4.LocalRealignment.sh -i $BamFil -b $BamLst -s $Settings -l $LogFil"
echo "    "$cmd >> $LogFil
$cmd
echo "----------------------------------------------------------------" >> $LogFil