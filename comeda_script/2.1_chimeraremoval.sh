#! /bin/bash

## chimera removal 
## generate on 2025.09.04

prefixname=$1
inpath=$2
outpath=$3
readtype=$4 # short / long reads
longtime=$5 # for long reads if using --uchime_ref : yes / no; set no for short reads; default -> no
metabarcodingtype=$6 # set 16S / ITS databases
minlen=$7
maxlen=$8

## ^remove chimera reads
if [ "${readtype}" == "short_reads"  ]; then
	ovlength=$( echo ${minlen} | awk '{printf("%d", $1*0.1)}' )
	vsearch --fastq_mergepairs ${inpath}/${prefixname}.clean.R1.fastq --reverse ${inpath}/${prefixname}.clean.R2.fastq --fastaout ${outpath}/${prefixname}.merged.fasta --fastq_allowmergestagger --fastq_maxdiffpct 30 --fastq_minovlen ${ovlength} --fastq_minmergelen ${minlen} --fastq_maxmergelen ${maxlen}
	vsearch --fastx_uniques ${outpath}/${prefixname}.merged.fasta --minuniquesize 1 --sizeout --relabel "${prefixname}_" --fastaout ${outpath}/${prefixname}.derep.fasta
	vsearch --uchime3_denovo ${outpath}/${prefixname}.derep.fasta --nonchimeras ${outpath}/${prefixname}.nochimera.fasta --minh 0.28 --mindiffs 3 --abskew 16
	rm ${outpath}/${prefixname}.merged.fasta
elif [ "${readtype}" == "long_reads" ]; then
	## ^set reference seq fa
	if [ ${metabarcodingtype} == "16S" ]; then
		reffapath="/nfs/CoMeDA/databases/greengenes2_v2024.09_bb.modified/library/gg2.202409.backbone.fna"
	elif [ ${metabarcodingtype} == "ITS" ]; then
		reffapath="/nfs/CoMeDA/databases/unite10_v2025.02_dynamic.modified/library/unite10.202502.dynamic.fna"
	fi
	## set reference seq fa$

	vsearch --fastx_uniques ${inpath}/${prefixname}.clean.R1.fastq --minuniquesize 1 --sizeout --relabel "${prefixname}_" --fastaout ${outpath}/${prefixname}.derep.fasta
	vsearch --uchime_denovo ${outpath}/${prefixname}.derep.fasta --nonchimeras ${outpath}/${prefixname}.nochimera_denovo.fasta --minh 0.22 --mindiffs 6 --abskew 8
	if [ ${longtime} == "yes" ]; then
		vsearch --uchime_ref ${outpath}/${prefixname}.nochimera_denovo.fasta --db ${reffapath} --nonchimeras ${outpath}/${prefixname}.nochimera.fasta
	else
		mv ${outpath}/${prefixname}.nochimera_denovo.fasta ${outpath}/${prefixname}.nochimera.fasta
	fi
fi
awk "/^>/{if(seq) print seq; print; seq=\"\"} !/^>/{seq=seq\$0} END{if(seq) print seq}" ${outpath}/${prefixname}.nochimera.fasta > ${outpath}/${prefixname}.nochimera.formated.fasta
rm ${outpath}/${prefixname}.derep.fasta ${outpath}/${prefixname}.nochimera.fasta
## remove chimera reads$

