#R script called by ExmVC.6.AnnotateVCF.sh
#Inputs are the ANNOVAR input files, the ANNOVAR annotation file, a table listing the ANNOVAR annotations to be added along with there associated INFO tags and the relevant mete-information to be added to the vcf, and also the two ANNOVAR commands used to annotate the file
#The script uses these inputs to reconstruct the original VCF with the addition of the various annotations in the INFO column and the relevant additional meta-information
args <- commandArgs(TRUE) #arguments are passed by BASH script

ARGvcdat <- args[1] #ANNOVAR input file
ARGannot <- args[2] #ANNOVAR annotation file
ARGmiann <- args[3] #table listing the ANNOVAR annotations
AnnConvCmd <- args[4] #ConvertfoANNOVAR command line
AnnAnntCmd <- args[5] #Annotate variants with ANNOVAR command line

options(stringsAsFactors=F)
#build Meta-information section
midat <- scan(ARGvcdat, what="character", sep="\n", nlines=1000) # variant data - Meta-Information plus some variants
midat <- grep("^##", midat, value=T) # get only Meta-Information
milen <- length(midat) #no of lines of meta-information
miann <- read.delim(ARGmiann, comment.char="", header=F, skip=3) # ANNOVAR related Meta-information
rownames(miann) <- gsub("\\+", ".", gsub("^([0-9])", "X\\1", miann[,1])) #fix GERP++ and 1000g to match the column names in the annotation as fixed by R

stinfo <- head(grep("\\#\\#INFO", midat),1) #start of ##INFO sections
eninfo <- tail(grep("\\#\\#INFO", midat),1) #end of ##INFO sections

AnnConvMI <- paste("##analysis_type=Annovar=\"", AnnConvCmd, "\"") # ANNOVAR Convert VCF to ANNOVAR command meta-information line
AnnAnntMI <- paste("##analysis_type=Annovar=\"", AnnAnntCmd, "\"") # ANNOVAR Build Annotation Table command meta-information line

vcmeta <- c(midat[1:(stinfo-1)], # initial bits of original Meta-information
             AnnConvMI, # ANNOVAR Convert VCF to ANNOVAR command
             AnnAnntMI,  # ANNOVAR Build Annotation Table command
             midat[stinfo:eninfo], # Original INFO section of Meta-Information
             miann[,3], # New ANNOVAR additions to INFO section of Meta-Information
             midat[(eninfo+1):milen]) # Remainder of original Meta-information

#build Variant section
  #get basic VCF data
vchead <- scan(ARGvcdat, what="character", sep="\n", skip=milen, nlines=1) # variant data - Header Line
vchead <- strsplit(vchead, "\\t")[[1]]
vcvars <- read.table(ARGvcdat) # variant data - variants
vcvars.ind <- paste(vcvars[,1], vcvars[,2]) # Chromosome/postion index to match to annotation file
vcvars <- vcvars[,-(1:5)] # get only VCF data - first 5 columns the ANNOVAR data format
colnames(vcvars) <- vchead

  #get annotation data to add to INFO column
annots <- read.delim(ARGannot) # annotation from ANNOVAR
annots.ind <- paste(annots[,1], annots[,2]) # Chromosome/postion index to match to variants table
if(!(all(vcvars.ind==annots.ind))) quit("no", status=1) # check that the two table match
mat <- match(rownames(miann), colnames(annots)) # match annotations to the miann table

annot2 <- vector()
for(i in 1:length(mat)){ #for each column of annotation
  annot2 <- cbind(annot2, paste(miann[i,2], "=", annots[,mat[i]], sep="")) #paste in the relevant ID flag
  annot2[grep("=$", annot2[,i]),i] <- "" # replace blank annotations
}
annot3 <- apply(annot2, 1, function(x){paste(x, collapse=";")}) #collapse each line of annotation and...
annot3 <- gsub(";;*", ";", annot3) #remove multiple ;'s from where there were blank annotations
vcvars[,"INFO"] <- paste(vcvars[,"INFO"], annot3, sep=";") # paste the annotations to the INFO column of the VCF
vcvars[,"INFO"] <- gsub(";$", "", vcvars[,"INFO"]) #remove trailing ;'s

#Output VCF
outnam <- gsub("avinput", "annotated.vcf", ARGvcdat)
write.table(vcmeta, outnam, quote=F, col.names=F, row.names=F, sep="\t") #write metainformation
write.table(vcvars, outnam, quote=F, col.names=T, row.names=F, sep="\t", append=T) #append variants
