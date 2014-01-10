#!/bin/bash
#$ -cwd
# This script will ask for the paths to the various files required for the Exome alignment, local realignment and recalibration steps.
# A file containing global setting for software locations, reference file locations, and cluster memory and time allocations for each step must be provided. The default is the BISR_Exome_pipeline_settings.sh file.
# The script will then call the first the job in the pipeline
# The main input is a comma separated file containing a list of fastq files (gzipped or flat) to be aligned and a readgroup header. Columns should be as follows:
#      For single end - <fastq files> <readgroup headers>
#      For paired end - <Read 1 fastq files> <readgroup headers> <Read 2 fastq files>
echo ""
echo "Enter the required information for Exome sequence alignment pipeline."
echo "Default values are shown in square brackets."
echo "Press [Enter] to select default value where provided or to skip optional parameters."
echo ""
echo "==========================================================================================="
echo ""
echo "Note the following requirements:"
echo ""
echo "   The main input is a comma separated file containing a list of fastq files (gzipped or flat) to be aligned and a readgroup header. Columns should be as follows:"
echo "      For single end - <fastq file> <readgroup header>"
echo "      For paired end - <Read 1 fastq files> <readgroup header> <Read 2 fastq files>"
echo ""
echo "   File names can be anything as long as:"
echo "                1) they end in \".fastq(.gz)\" "
echo "                2) for paired-end reads also contain the read number as \"_R1\" or \"_R2\""
echo "       e.g. Sample5172_R2.fastq.gz"
echo ""
echo "   For details of read header format please see relevant specification on SAM file format for full list of options:"
echo "       http://samtools.sourceforge.net/SAMv1.pdf"
echo "   Also see minimum required information for GATK analysis:"
echo "       http://gatkforums.broadinstitute.org/discussion/1317/collected-faqs-about-bam-files"
echo "   Readgroup header should be in the general format:"
echo "       @RG\t<tag>:<tag info>\t<tag>:<tag info>..."
echo "        e.g @RG\tID:Sample12324.C2KDGACXX.5\tSM:Sample12324\tLB:Library1B34C\tPL:Illumina\tCN:BISRColumbia"
echo "   First 2 fields MUST be ID then SM (sample)"
echo "==========================================================================================="
echo ""
echo ""
#File containing list of fastq files
FqFil=""
read -e -p "Table of fastq data to be aligned: " FqFil
if [ ! "$FqFil" ] #check for input
then
echo "----------------------------------------------------------------"
echo "Can not align nothing."
exit 1
fi
if [ ! -f $FqFil ]; then #check to see if file exists
	echo "----------------------------------------------------------------"
	echo $FqFil" Does not exist."
	exit 1
fi
echo "----------------------------------------------------------------"
FqFil=$(readlink -f $FqFil)
#check paired end or single reads using number of columns in the input table
NCOL=$(head -n1 $FqFil | wc -w | cut -d" " -f1)
case "$NCOL" in
	2) echo "   Samples are single reads, not paired-end."
		nthreads=2;;
	3) echo "   Samples are paired-end reads."
		nthreads=4;;
	*) echo "   Error in fastq file table."
	   exit 1;;
esac
echo "----------------------------------------------------------------"
echo ""
#Directory containing fastq files
read -e -p "Directory containing fastq files to be aligned [current_directory]: " FqDir
echo "----------------------------------------------------------------"
if [ ! "$FqDir" ]; then # no input --> set default
	FqDir=$PWD
else
	FqDir=$(readlink -f $FqDir)
fi
if [ ! -d $FqDir ]; then # check the directory exists
	echo $FqDir" Does not exist."
	exit 1
fi
echo "   Checking for fastq files..."
#check directory contains all the FastQ files in the list
cut -f1 $FqFil > TEMP_CHECK_LIST #Read 1 files
cut -f4 $FqFil >> TEMP_CHECK_LIST #Read 2 files (if present)
FilList=$(cat TEMP_CHECK_LIST)
MisFil=Missing_Fastq_files$(date '+%d%b%Yt%H%M') #Output files for list of missing files
for i in $FilList; do #check each file
	checkFil=$FqDir/$i
	if [ ! -f $checkFil ]; then #if file doesn't exist send name to output file
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
	rm TEMP_CHECK_LIST
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
#A name for the alignment job, this will be used to generate the job names on the cluster, output directories and log file names
read -e -p "Name for the aligment job (*optional*): " JobNm
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
#Number of files to be aligned
echo $FqFil
NFILS=$(cat $FqFil | wc -l)
#Generate log file and output directories
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
echo "Pipeline will be initiated with the following command:"
echo $cmd
read -e -p "Proceed? y/n: " gogogo
if [ "$gogogo" != y ]; then 
	exit 1
fi
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
