#!/bin/bash

. /ifs/home/c2b2/af_lab/ads2202/scratch/Exome_Seq/scripts/BISR_pipeline_scripts/BISR_Exome_pipeline_settings
echo $ANNDIR

echo ""
echo "Download: refseq hg19 gene reference"
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar refGene humandb/"
echo $cmd
$cmd


echo ""
echo "Download: 1000 genomes reference"
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar 1000g2012apr humandb/"
echo $cmd
$cmd

echo ""
echo "Download: dbSNP reference"
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar snp137 humandb/"
echo $cmd
$cmd

echo ""
echo "Download: LJB version 2 databases: whole-exome SIFT scores, PolyPhen2 HDIV scores, PolyPhen2 HVAR scores, LRT scores, MutationTaster scores, MutationAssessor score, FATHMM scores, GERP++ scores, PhyloP scores and SiPhy scores"
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar ljb2_all humandb/"
echo $cmd
$cmd

echo ""
echo "Download: alternative allele frequency in all subjects in the NHLBI-ESP project with 6500 exomes, including the indel calls and the chrY calls "
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar esp6500si_all humandb/"
echo $cmd
$cmd
echo ""
echo "Download: alternative allele frequency in African Americans in the NHLBI-ESP project with 6500 exomes, including the indel calls and the chrY calls  "
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar esp6500si_aa humandb/"
echo $cmd
$cmd

echo ""
echo "Download: alternative allele frequency in all subjects in the NHLBI-ESP project with 6500 exomes, including the indel calls and the chrY calls "
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar esp6500si_ea humandb/"
echo $cmd
$cmd

echo ""
echo "Download: whole-exome SIFT scores for non-synonymous variants  "
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar avsift humandb/"
echo $cmd
$cmd

echo ""
echo "Download: conserved genomic regions by GERP++ "
cmd="perl annotate_variation.pl -downdb -buildver hg19 -webfrom annovar gerp++elem humandb/"
echo $cmd
$cmd

