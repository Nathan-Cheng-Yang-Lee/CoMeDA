#! /bin/bash

## Short and Long read preprocessing including primer trimming, base quality and minum length filtering
## generated on 2025.09.16

readtype=$1 ## short_reads or long_reads
rawfilepath=$2 ## input folder path
outpath=$3 ## output folder path
samplename=$4 ## sample name
metafile=$5
Fprimercolno=$6 ## forward primer column number | none
Rprimercolno=$7 ## reverse primer column number | none
seqfilecolno=$8
qscore=$9
minlen="${10}"
maxlen="${11}"
demux="${12}"

cleanpath="${outpath}/clean"

if [ "${readtype}" == "short_reads" ]; then # for Illumina PE data; define seq name
	if [ "${demux}" == "yes" ]; then
		R1seq="${samplename}.R1.fastq"
		R2seq="${samplename}.R2.fastq"
	else
		R1seq=$( awk -F"\t" -v samplename=${samplename} -v seqfilecolno=${seqfilecolno} '{if($1 == samplename) print $seqfilecolno}' ${metafile} | cut -d"," -f 1 | sed 's/ //g' )
		R2seq=$( awk -F"\t" -v samplename=${samplename} -v seqfilecolno=${seqfilecolno} '{if($1 == samplename) print $seqfilecolno}' ${metafile} | cut -d"," -f 2 | sed 's/ //g' )
	fi
	seqmaxee=$( awk 'ORS=NR%4?"\t":"\n"' ${rawfilepath}/${R1seq} | awk -F"\t" '{print length($2)}' | datamash median 1 | awk -v qscore=${qscore} '{print $1*10^-(qscore/10)}' )
elif [ ${readtype} == "long_reads" ]; then # for PacBio / Nanopore SR data
	R1seq=$( awk -F"\t" -v samplename=${samplename} -v seqfilecolno=${seqfilecolno} '{if($1 == samplename) print $seqfilecolno}' ${metafile} )
fi

if [ "${Fprimercolno}" != "none" ] || [ "${Rprimercolno}" != "none" ]; then # with primers
	Fprimerseq=$( awk -F"\t" -v samplename=${samplename} -v Fprimercolno=${Fprimercolno} '{if($1 == samplename) print $Fprimercolno}' ${metafile} )
	Rprimerseq=$( awk -F"\t" -v samplename=${samplename} -v Rprimercolno=${Rprimercolno} '{if($1 == samplename) print $Rprimercolno}' ${metafile} )

	if [ "${readtype}" == "short_reads" ]; then # Illumina PE data
		cutadapt -j 1 -g ${Fprimerseq} -g ${Rprimerseq} -G ${Fprimerseq} -G ${Rprimerseq} --action=trim -q ${qscore} -Q ${qscore} --max-ee ${seqmaxee} --max-n 0 -m ${minlen}:${minlen} -o ${cleanpath}/${samplename}.clean.R1.fastq -p ${cleanpath}/${samplename}.clean.R2.fastq ${rawfilepath}/${R1seq} ${rawfilepath}/${R2seq} &>> ${outpath}/clean.log
	elif [ "${readtype}" == "long_reads" ]; then # PacBio / Nanopore SR data
		revFprimerseq=$(echo "${Fprimerseq}" | tr "ATCGRYSWKMBDHVN" "TAGCYRSWMKVHDBN" | rev)
		revRprimerseq=$(echo "${Rprimerseq}" | tr "ATCGRYSWKMBDHVN" "TAGCYRSWMKVHDBN" | rev)
		cutadapt -j 1 -g "${Fprimerseq}...${revRprimerseq}" -g "${Rprimerseq}...${revFprimerseq}" --action=trim --discard-untrimmed -q ${qscore} --max-n 0 -n 2 -m ${minlen} -M ${maxlen} -o ${cleanpath}/${samplename}.clean.R1.fastq ${rawfilepath}/${R1seq} &>> ${outpath}/clean.log
	fi
else # without primers
	if [ "${readtype}" == "short_reads" ]; then # Illumina PE data
		cutadapt -j 1 -q ${qscore} -Q ${qscore} --max-ee ${seqmaxee} --max-n 0 -m ${minlen}:${minlen} -o ${cleanpath}/${samplename}.clean.R1.fastq -p ${cleanpath}/${samplename}.clean.R2.fastq ${rawfilepath}/${R1seq} ${rawfilepath}/${R2seq} &>> ${outpath}/clean.log
	elif [ "${readtype}" == "long_reads" ]; then # PacBio / Nanopore SR data
		cutadapt -j 1 -q ${qscore} --max-n 0 -n 2 -m ${minlen} -M ${maxlen} -o ${cleanpath}/${samplename}.clean.R1.fastq ${rawfilepath}/${R1seq} &>> ${outpath}/clean.log
	fi
fi
