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

