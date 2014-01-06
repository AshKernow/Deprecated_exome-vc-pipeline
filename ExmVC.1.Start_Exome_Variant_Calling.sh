#!/bin/bash
#$ -cwd

echo ""
echo "Enter the required information for Exome variant calling analysis pipeline."
echo "Default values are shown in square brackets."
echo "Press [Enter] to select default value where provided or to skip optional parameters."
echo ""
echo "==========================================================================================="
echo ""
echo "Note the following requirements:"
echo ""
echo "   The main input is a file containing a list of recalibrated BAM files for for joint variant calling."
echo "   The file should contain the just names of the BAM files, not the paths."
echo "   The name of this file will be used as the job name and output name if no alternative is given."
echo "   All BAM files should be in the same directory."
echo "   Can files can optionally be Reduced Reads (see GATK)."
echo ""echo "==========================================================================================="
echo ""
echo ""
#File containing list of fastq files
BamLst=""
read -e -p "List of BAM files for for joint variant calling: " BamLst
if [ ! "$BamLst" ]
then
echo "----------------------------------------------------------------"
echo "Can not call variants on nothing."
exit 1
fi
if [ ! -f $BamLst ]; then
	echo "----------------------------------------------------------------"
	echo $BamLst" Does not exist."
	exit 1
fi
echo "----------------------------------------------------------------"
BamLst=$(readlink -f $BamLst)
echo ""
#Directory containing fastq files
read -e -p "Directory containing BAM files [current_directory]: " BamDir
echo "----------------------------------------------------------------"
if [ ! "$BamDir" ]; then
	BamDirnm="current"
	BamDir=$PWD
else
	BamDirnm=$BamDir
	BamDir=$(readlink -f $BamDir)
fi
if [ ! -d $BamDir ]; then
	echo $BamDir" Does not exist."
	exit 1
fi
BamDir=${BamDir%/}
echo "   Checking $BamDirnm for BAM files..."
#check directory contains all the FastQ files in the list
FilList=$(cat $BamLst)
MisFil=Missing_BAM_files$(date '+%d%b%Yt%H%M')
for i in $FilList; do
	checkFil=$BamDir/$i
	if [ ! -f $checkFil ]; then
		echo $i >> $MisFil
	fi
done
if [ -f $MisFil ]; then
	sort $MisFil | uniq > $MisFil
	echo "   Checking $BamDirnm for BAM files..."
	echo ""
	echo "          ...The following files do not exist in the $BamDirnm directory:"
	cat $MisFil
	echo ""
	echo "Exiting..."
	exit 1
else
	echo ""
	echo "       ...Found all BAM files"
	echo ""
fi
echo "----------------------------------------------------------------"
#Global settings
read -e -p "Global settings files [BISR_Exome_pipeline_settings]: " Settings
echo "----------------------------------------------------------------"
if [ ! "$Settings" ]; then
	echo "   Using BISR_Exome_pipeline_settings"
	Settings="/ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/resources/BISR_Exome_pipeline_settings.sh"
	echo "----------------------------------------------------------------"
fi
if [ ! -f $Settings ]; then
	echo $Settings" Does not exist."
	exit 1
fi
Settings=$(readlink -f $Settings)
#job name
read -e -p "Name for the variant calling job (*optional*): " JobNm
mydate="_"$(date '+%y%m%d.%H%M')
if [ ! "$JobNm" ]; then
	JobNm=`basename $BamLst`
	JobNm=${JobNm%.*}
	echo "Job Name: "$JobNm
fi
read -e -p "Output directory (will create if does not exist): " OutDir
if [ -e $OutDir ] &&  [ ! -d $OutDir ]; then
	echo "----------------------------------------------------------------"
	echo $OutDir" is not a directory."
	exit
fi
if [ ! -d $OutDir ]; then
	echo "----------------------------------------------------------------"
	echo "The directory "$OutDir" does not exist. It will be created if you proceed."
fi
OutDir=${OutDir%/}
#Load Settings
. $Settings 
#Generate log file and output directories
LogFil="VCExm."$JobNm$mydate".log"
echo "----------------------------------------------------------------"
echo "   Individual sample processing logs will be recorded in $LogFil.CHR_[CHR].log"
echo "----------------------------------------------------------------"
#cmd="qsub -t 1:24 -pe smp $NumCores -l $vcHapCExmAlloc -N vcHapCExm.$JobNm $EXOMSCR/ExmVC.2.HaplotypeCaller.sh -i $BamLst -d $BamDir -s $Settings -l $LogFil -n $NumCores"
cmd="qsub -t 1:4 -pe smp $NumCores -l $vcHapCExmAlloc -N vcHapCExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2.HaplotypeCaller.sh -i $BamLst -d $BamDir -s $Settings -l $LogFil"
echo ""
echo "Pipeline will be initiated with the following command:"
echo $cmd
read -e -p "Proceed? y/n: " gogogo
if [ "$gogogo" != y ]; then 
	exit 1
fi
mkdir -p $OutDir
echo "Current directory: "$PWD > $OutDir/$LogFil
echo "Output Directory: "$Outdir >> $OutDir/$LogFil
echo "Bam File List:"$BamLst >> $OutDir/$LogFil
echo "Bam File Directory: "$BamDir >> $OutDir/$LogFil
case $(/bin/hostname) in
*.titan) echo "Running on titan with 8 threads" >> $OutDir/$LogFil;;
*.hpc) echo "Running on hpc with 12 threads" >> $OutDir/$LogFil;;
esac
cd $OutDir
mkdir -p stdostde/
echo $cmd >> $LogFil
$cmd
echo "qsub time: `date`" >> $LogFil
echo "" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
