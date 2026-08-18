#! /bin/bash

## de-multiplex
## generate on 2025.9.16

seqR1=$1
seqR2=$2
inpath=$3
outpath=$4
barcodecolno=$5
metadatapath=$6
prefixname=$( echo "${seqR1}" | sed 's/R1/\t/g' | cut -f 1 )

awk -F"\t" -v barcodecolno=${barcodecolno} '{if(NR != 1) printf(">%s\n%s\n", $1, $barcodecolno)}' ${metadatapath} > ${outpath}/${prefixname}_forward_barcode.fasta ## generate forward barcode sequence file
for barcodeseqs in $( cut -f ${barcodecolno} ${metadatapath} | sed '1d' )
do
	echo "${barcodeseqs}" | tr "ATCGRYSWKMBDHVN" "TAGCYRSWMKVHDBN" >> ${outpath}/${prefixname}_reverse_barcode.tmp
done
cut -f 1 ${metadatapath} | sed '1d' | paste - ${outpath}/${prefixname}_reverse_barcode.tmp | awk -F"\t" '{printf(">%s\n%s\n", $1, $2)}' > ${outpath}/${prefixname}_reverse_barcode.fasta ## generate reverse barcode sequence file
cutadapt -j 2 -g ^file:${outpath}/${prefixname}_forward_barcode.fasta -g ^file:${outpath}/${prefixname}_reverse_barcode.fasta -o ${outpath}/{name}.R1.fastq -p  ${outpath}/{name}.R2.fastq ${inpath}/${seqR1} ${inpath}/${seqR2}
