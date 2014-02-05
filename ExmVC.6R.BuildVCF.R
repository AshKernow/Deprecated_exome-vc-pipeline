ARGvcdat <- "LorrVC.variants.recal_snps.recalibrated_variants.vcf.Clk51764.avinput"
ARGannot <- "LorrVC.variants.recal_snps.recalibrated_variants.vcf.Clk51764.hg19_multianno.tab"
ARGmiann <- "../../scripts/BISR_pipeline_scripts/VCF_header_INFO_for_ANNOVAR.txt" 
vcfFil <- "LorrVC.variants.recal_snps.recalibrated_variants.vcf"
AnnConvCmd <- paste("##analysis_type=Annovar=\"convert2annovar.pl", vcfFil, " -format vcf4 -includeinfo -allsample -comment -outfile", vcfFil, "\"")
AnnConvCmd <- paste("##analysis_type=Annovar=\"table_annovar.pl", ARGvcdat, "/humandb/ --buildver hg19 --remove -protocol refGene,1000g2012apr_all,snp137,ljb2_all -operation g,f,f,f -nastring \"\" --outfile", gsub(".avinput", "", ARGvcdat), "\"")


options(stringsAsFactors=F)
#build Meta-information section
midat <- scan(ARGvcdat, what="character", sep="\n", nlines=1000) # variant data - Meta-Information plus some variants
midat <- grep("^##", midat, value=T) # get only Meta-Information
milen <- length(midat)
miann <- scan(ARGmiann, what="character", sep="\n") # ANNOVAR related Meta-information

stinfo <- head(grep("\\#\\#INFO", midat),1) #start of ##INFO sections
eninfo <- tail(grep("\\#\\#INFO", midat),1) #end of ##INFO sections

vcmiout <- c(midat[1:(stinfo-1)], # initial bits of original Meta-information
             AnnSpltCmd, # ANNOVAR Convert VCF to ANNOVAR command
             AnnAnnCmd,  # ANNOVAR Build Annotation Table command
             midat[stinfo:eninfo], # Original INFO section of Meta-Information
             miann, # New ANNOVAR additions to INFO section of Meta-Information
             midat[(eninfo+1):milen]) # Remainder of original Meta-information

#build Variant section
  #get basic VCF data
vchead <- scan(ARGvcdat, what="character", sep="\n", skip=milen, nlines=1) # variant data - Header Line
vchead <- strsplit(vchead, "\\t")[[1]]
vcvars <- read.table(ARGvcdat) # variant data - variants
vcvars <- vcvars[,-(1:5)] # get only VCF data - first 5 columns the ANNOVAR data format
colnames(vcvars) <- vchead

  #get annotation data to add to INFO column
annot <- read.delim(ARGannot) # annotation from ANNOVAR

