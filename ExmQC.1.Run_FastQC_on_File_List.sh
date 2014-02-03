#!/bin/bash
#$ -l mem=4G,time=1:: -N FastQC -cwd

while getopts f:o:s: opt; do
  case "$opt" in
      f) FastQFileList="$OPTARG";;
	  o) OutDir="$OPTARG";;
	  s) Settings="$OPTARG";;
  esac
done

if [[ ! $FastQFileList ]];then
	echo "Please supply a file containing a list of fastq files to QC"
	exit 1
fi

if [[ ! $Settings ]]; then
	Settings="/ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings.sh"
fi

if [[ ! $OutDir ]]; then
	OutDir="./"
fi

. $Settings

FQFil=$(tail -n+$SGE_TASK_ID $FastQFileList | head -n 1)
echo $FQFil
mkdir -p $OutDir
$FASTQC -o $OutDir -j $JAVA7BIN --noextract $FQFil
