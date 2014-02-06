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

echo $PATH

uname -a >> $LogFil
echo "Start Variant Quality Score Recalibration - $0:`date`" >> $LogFil
echo "" >> $LogFil
echo "Job name: "$JOB_NAME >> $LogFil
echo "Job ID: "$JOB_ID >> $LogFil

##Set local parameters
JobNm=${JOB_NAME#*.}
TmpDir=$JobNm.VQSR 
mkdir -p $TmpDir

##Build the SNP recalibration model
echo "- Build the SNP recalibration model with GATK VariantRecalibrator `date` ..." >> $LogFil
InfoFields="-an DP -an QD -an FS -an MQRankSum -an ReadPosRankSum -an HaplotypeScore"

cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T VariantRecalibrator -R $REF -input $VcfFil.vcf     -resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HpMpV3 -resource:omni,known=false,training=true,truth=true,prior=12.0 $TGVCF -resource:1000G,known=false,training=true,truth=false,prior=10.0 $OneKG -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP $InfoFields -mode SNP -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 -recalFile $VcfFil.recalibrate_SNP.recal -tranchesFile $VcfFil.recalibrate_SNP.tranches -rscriptFile recalibrate_SNP_plots.R -nt $NumCores"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Build the SNP recalibration model with GATK VariantRecalibrator $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
echo "SNP recalibration model built `date`" >> $LogFil
echo "" >> $LogFil
##Apply SNP recalibration
echo "- Apply SNP recalibration with GATK ApplyRecalibration `date` ..." >> $LogFil
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T ApplyRecalibration -R $REF -input $VcfFil.vcf -mode SNP --ts_filter_level 99.0 -recalFile $VcfFil.recalibrate_SNP.recal -tranchesFile $VcfFil.recalibrate_SNP.tranches -o $VcfFil.recal_snps.vcf -nt $NumCores"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Apply SNP recalibration with GATK ApplyRecalibration  $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
echo "SNP recalibration applied `date`" >> $LogFil
echo "" >> $LogFil
VcfFil=$VcfFil.recal_snps

##Build the InDel recalibration model
echo "- Build the InDel recalibration model with GATK VariantRecalibrator `date` ..." >> $LogFil
InfoFields="-an DP -an FS -an MQRankSum -an ReadPosRankSum"
#InfoFields="-an DP -an FS -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff" #from Badri
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T VariantRecalibrator -R $REF -input $VcfFil.vcf -resource:mills,known=true,training=true,truth=true,prior=12.0 $INDEL -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP $InfoFields -mode INDEL -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 --maxGaussians 4 -recalFile $VcfFil.recalibrate_INDEL.recal -tranchesFile $VcfFil.recalibrate_INDEL.tranches -rscriptFile recalibrate_INDEL_plots.R -nt $NumCores"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Build the InDel recalibration model with GATK VariantRecalibrator $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
echo "InDel recalibration model built `date`" >> $LogFil
echo "" >> $LogFil

##Apply InDel recalibration
echo ""
echo "- Apply InDel recalibration with GATK ApplyRecalibration `date` ..." >> $LogFil
cmd="$JAVA7BIN -Xmx7G -Djava.io.tmpdir=$TmpDir -jar $GATKJAR -T ApplyRecalibration -R $REF -input $VcfFil.vcf -mode INDEL --ts_filter_level 99.0 -recalFile $VcfFil.recalibrate_INDEL.recal -tranchesFile $VcfFil.recalibrate_INDEL.tranches -o $VcfFil.recalibrated_variants.vcf -nt $NumCores"
echo $cmd >> $LogFil
$cmd
if [[ $? == 1 ]]; then
	echo "----------------------------------------------------------------" >> $LogFil
    echo "Apply InDel recalibration with GATK ApplyRecalibration $JOB_NAME $JOB_ID failed `date`" >> $LogFil
	qstat -j $JOB_ID | grep -E "usage " >> $LogFil
    exit 1
fi
echo "" >> $LogFil
echo "InDel recalibration applied `date`" >> $LogFil
echo "" >> $LogFil
VcfFil=$VcfFil.recalibrated_variants

#Call next job
echo "- Call Convert for ANNOVAR `date`:" >> $LogFil
cmd="qsub -l $VCF2ANNAlloc -N VCF2ANN.$JobNm  -o stdostde/ -e stdostde/ $EXOMSCR/ExmVC.5.ConvertforANNOVAR.sh -i $VcfFil -s $Settings -l $LogFil"
echo "    "$cmd  >> $LogFil
# $cmd
echo "----------------------------------------------------------------" >> $LogFil

echo "" >> $LogFil
echo "End Variant Quality Score Recalibration $0:`date`" >> $LogFil
qstat -j $JOB_ID | grep -E "usage " >> $LogFil
echo "===========================================================================================" >> $LogFil
echo "" >> $LogFil
