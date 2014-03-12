options(stringsAsFactors=F)
options(scipen=1000)

bufsize <- 50

exon <- read.table("SureSelect_Human_All_Exon_V4_UTRs_Covered.bed", skip=2)
exon.keep <- exon
exon <- exon.keep[,1:3]
#remove unwanted
exon <- exon[grep("_", exon[,1], invert=T),]
#remove "chr"
exon[,1] <- gsub("chr", "", exon[,1])
CHR <- as.numeric(gsub("X", 23, gsub("Y", 24, exon[,1])))
#sort 
exon <- exon[order(CHR, exon[,2]),]
CHR <- as.numeric(gsub("X", 23, gsub("Y", 24, exon[,1])))
#add buffer
exon[,2] <- exon[,2]-bufsize
exon[,3] <- exon[,3]+bufsize
#check for overlaps between buffered regions
ovlp.diff <- c(1, exon[-1,2]-exon[-nrow(exon),3])
newchr <- which(c(0, diff(CHR))!=0)
ovlp.diff[newchr] <- 1
ovlp <- which(ovlp.diff<=0)

#concatenate overlapping regions
new.exon <- exon
new.exon[ovlp-1,3] <- NA # replace end of first region in overlap with NA
new.exon[ovlp,2] <- NA #replace start of second region in overlap with NA
new.exon <- new.exon[!(is.na(new.exon[,2])&is.na(new.exon[,3])),] # any with NA NA are overlapped both before and after so can be removed leaving only the first and last regions in any overlap
mvend <- which(is.na(new.exon[,3])) # NA's in the "end" column correspond to the first region of the overap
new.exon[mvend,3] <- new.exon[mvend+1,3] # add the end of the overlap region to the line of the start of the overlap region
new.exon <- new.exon[-(mvend+1),] # remove the line for the end of the overlap redion

#sanity check
chec <- matrix(nr=24, nc=2)
for(i in 1:24){
  chr <- i
  if(i==23) chr <- "X"
  if(i==24) chr <- "Y"  
  chec[i,1] <- sum(exon[exon[,1]==chr,3]-exon[exon[,1]==chr,2])+sum(ovlp.diff[exon[,1]==chr&ovlp.diff<=0])
  chec[i,2] <- sum(new.exon[new.exon[,1]==chr,3]-new.exon[new.exon[,1]==chr,2])
}

write.table(new.exon, "SureSelect_Human_All_Exon_V4_UTRs_Covered.orderandbuffered_b37.bed", quote=F, col.names=F, row.names=F, sep="\t")
new.exon[,1] <- paste("chr", new.exon[,1], sep="")
write.table(new.exon, "SureSelect_Human_All_Exon_V4_UTRs_Covered.orderandbuffered_hg19.bed", quote=F, col.names=F, row.names=F, sep="\t")






