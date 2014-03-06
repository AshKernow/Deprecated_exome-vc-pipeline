#!/bin/bash
#$ -cwd 

while getopts i:s:l: opt; do
  case "$opt" in
      i) VcfFil="$OPTARG";;
	  s) Settings="$OPTARG";;
      l) LogFil="$OPTARG";;
  esac
done

#load settings file
. $Settings

uname -a >> $LogFil
echo "Start Convert for ANNOVAR - $0:`date`" >> $LogFil
echo "" >> $LogFil
echo "Job name: "$JOB_NAME >> $LogFil
echo "Job ID: "$JOB_ID >> $LogFil

##Set local parameters
JobNm=${JOB_NAME#*.}
OutFil=${VcfFil/.vcf/}
TmpDir=$OutFil.$JobNm.CnvAnn
TmpVar=$OutFil.$JobNm.UniqueVariants
mkdir -p $TmpDir

##Convert VCF to ANNOVAR input file using ANNOVAR - split by sample to get all variants
echo "- Convert VCF to ANNOVAR input file using ANNOVAR `date` ..." >> $LogFil

cmd="$ANNDIR/convert2annovar.pl $VcfFil -format vcf4 -allsample -outfile $TmpDir/$VcfFil"
echo $cmd >> $LogFil
 $cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Convert VCF to ANNOVAR input file using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
NumFils=$(ls $TmpDir | grep avinput | wc -l)
echo "Converted VCF to $NumFils ANNOVAR input files `date`" >> $LogFil
echo "" >> $LogFil

#Combine annovar outputs into single variants table containing one row for each variant
cut -f 1-5 $TmpDir/*.avinput | sort -V | uniq > $TmpVar

##Build Annotation table
echo "- Build Annotation table using ANNOVAR `date` ..." >> $LogFil
cmd="$ANNDIR/table_annovar.pl $TmpVar $ANNDIR/humandb/ --buildver hg19 --remove -protocol refGene,gerp++elem,esp6500si_all,esp6500si_aa,esp6500si_ea,1000g2012apr_all,1000g2012apr_eur,1000g2012apr_amr,1000g2012apr_asn,1000g2012apr_afr,snp137,avsift,ljb2_all -operation g,r,f,f,f,f,f,f,f,f,f,f,f -nastring \"\"  -otherinfo --outfile $OutFil"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Build Annotation table using ANNOVAR $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi

echo "" >> $LogFil
echo "End Annotate with ANNOVAR $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage " >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
