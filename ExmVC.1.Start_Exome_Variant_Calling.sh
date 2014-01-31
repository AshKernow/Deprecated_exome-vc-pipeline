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
echo "   The file should contain the FULL PATHS to the BAM files."
echo "   The name of this file will be used as the job name and output name if no alternative is given."
echo "   Files can optionally be Reduced Reads (see GATK)."
echo ""
echo "==========================================================================================="
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
#check that the filename ends in .list if not change it
BLext=${BamLst##*.}
if [[ $BLext != "list" ]]; then
	echo "Appending \".list\" to the BAM list filename for compatability with GATK."
	echo "----------------------------------------------------------------"
	cp $BamLst $BamLst.list
	BamLst=$BamLst.list
fi
echo ""
echo "   Checking $BamDirnm for BAM files..."
#check directory contains all the FastQ files in the list
FilList=$(cat $BamLst)
MisFil=Missing_BAM_files$(date '+%d%b%Yt%H%M')
for i in $FilList; do
	checkFil=$i
	if [ ! -f $checkFil ]; then
		echo $i >> $MisFil
	fi
done
if [ -f $MisFil ]; then
	sort $MisFil | uniq > $MisFil
	echo "          ...The following files do not exist:"
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
	Settings="/ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings.sh"
	echo "----------------------------------------------------------------"
fi
if [ ! -f $Settings ]; then
	echo $Settings" Does not exist."
	exit 1
fi
Settings=$(readlink -f $Settings)
#HaplotypeCaller or UnifiedGenotyper
read -e -p "Default variant calling tool is the HaplotypeCaller, do you want to use the UnifiedGenotyped instead? y/n " VCFtest
if [[ $VCFtest == "y" ]]; then
	VCFTool=UG
	echo "----------------------------------------------------------------"
	echo "   Variant calling will be carried out using the UnifiedGenotyper"
	echo "----------------------------------------------------------------"
	else
	VCFTool=HC
	echo "----------------------------------------------------------------"
	echo "   Variant calling will be carried out using the HaplotypeCaller"
	echo "----------------------------------------------------------------"
fi

#Number of jobs to split VC into

read -e -p "How many jobs should the variant calling be split into [30]: " NumJobs
if [[ ! "$NumJobs" ]]; then NumJobs=30; fi
echo "----------------------------------------------------------------"
echo "   Variant calling will be split across $NumJobs jobs"
echo "----------------------------------------------------------------"
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
#check that there are not too many jobs for the target length
TarLen=$(wc $TARGET)
if [[ $NumJobs -gt $TarLen ]]; then
	NumJobs=$TarLen
fi
#Generate log file and output directories
LogFil="VCExm."$JobNm$mydate".log"
echo "----------------------------------------------------------------"
echo "   Individual sample processing logs will be recorded in $LogFil.CHR_[CHR].log"
echo "----------------------------------------------------------------"

#Starting the pipeline
if [[ $VCFTool == "HC" ]]; then
	cmd="qsub -t 1:$NumJobs -pe smp 6 -l $vcHapCExmAlloc -N vcHapC.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2hc.HaplotypeCaller.sh -i $BamLst -s $Settings -l $LogFil -n 6 -j $NumJobs"
	#cmd="qsub -t 1:4 -pe smp 6 -l $vcHapCExmAlloc -N vcHapCExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2hc.HaplotypeCaller.sh -i $BamLst -s $Settings -l $LogFil -j $NumJobs"
	#cmd="qsub -t 1:4 -l mem=1G,time=1:: -N vcHapCExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2hc.HaplotypeCaller.sh -i $BamLst -s $Settings -l $LogFil -j $NumJobs"
	else
	cmd="qsub -t 1:$NumJobs -pe smp 6 -l $vcUniGExmAlloc -N vcUniG.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2ug.UnifiedGenotyper.sh -i $BamLst -s $Settings -l $LogFil -n 6 -j $NumJobs"
	#cmd="qsub -t 1:4 -pe smp 6 -l $vcUniGExmAlloc -N vcUniGExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2ug.UnifiedGenotyper.sh -i $BamLst -s $Settings -l $LogFil -n 6 -j $NumJobs"
	#cmd="qsub -t 1:4 -l mem=1G,time=1:: -N vcUniGExm.$JobNm -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.2ug.UnifiedGenotyper.sh -i $BamLst -s $Settings -l $LogFil -j $NumJobs"
	echo ""
fi
echo "Pipeline will be initiated with the following command:"
echo $cmd
read -e -p "Proceed? y/n: " gogogo
if [ "$gogogo" != y ]; then 
	exit 1
fi
mkdir -p $OutDir
echo "Current directory: "$PWD > $OutDir/$LogFil
echo "Output Directory: "$OutDir >> $OutDir/$LogFil
echo "Bam File List:"$BamLst >> $OutDir/$LogFil

cd $OutDir
mkdir -p stdostde/
echo $cmd >> $LogFil
$cmd
echo "qsub time: `date`" >> $LogFil
echo "" >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
