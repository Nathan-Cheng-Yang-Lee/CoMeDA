#!/bin/bash

## generate raw taxonomy table using kraken2 + bracken pipeline
## generate on 2025.09.05
## Modified: 2025.12.13 - Added confidence parameter and result validation
## Modified: 2025.12.13 - Bracken failure creates marker file instead of exit
## Modified: 2025.12.19 - Added paired-end FASTQ input mode (skip chimera removal)

metabarcodingtype=$1
readtype=$2
inpath=$3
outpath=$4
prefixname=$5
refdbpath=$6
confidence=$7  # Accept confidence parameter from caller
inputmode=$8   # NEW: "fasta" or "fastq_paired"

## ^[NEW] Default inputmode to "fasta" if not provided (backward compatibility)
if [ -z "${inputmode}" ]; then
	inputmode="fasta"
fi
## Default inputmode$

## ^map to reference database
if [ ${readtype} == "short_reads" ]; then
	minhitgroup=2
	brackenRlen=250
elif [ ${readtype} == "long_reads" ]; then
	minhitgroup=3
	if [ ${metabarcodingtype} == "16S" ]; then
		brackenRlen=1200
	elif [ ${metabarcodingtype} == "ITS" ]; then
		brackenRlen=350
	fi
fi

# Use passed confidence parameter (fallback to default if not provided)
if [ -z "${confidence}" ]; then
	if [ ${metabarcodingtype} == "16S" ]; then
		confidence=0
	else
		confidence=0.05
	fi
fi

## ^[MODIFIED] Input file check based on inputmode
if [ "${inputmode}" == "fastq_paired" ]; then
	# Paired-end FASTQ mode (skip chimera removal)
	input_r1="${inpath}/${prefixname}.clean.R1.fastq"
	input_r2="${inpath}/${prefixname}.clean.R2.fastq"
	
	if [ ! -f "${input_r1}" ]; then
		echo "ERROR: Input R1 fastq not found: ${input_r1}" >&2
		exit 1
	fi
	
	if [ ! -s "${input_r1}" ]; then
		echo "ERROR: Input R1 fastq is empty: ${input_r1}" >&2
		exit 1
	fi
	
	if [ ! -f "${input_r2}" ]; then
		echo "ERROR: Input R2 fastq not found: ${input_r2}" >&2
		exit 1
	fi
	
	if [ ! -s "${input_r2}" ]; then
		echo "ERROR: Input R2 fastq is empty: ${input_r2}" >&2
		exit 1
	fi
	
	echo "[${prefixname}] Input mode: FASTQ_PAIRED (skip chimera removal)"
	echo "[${prefixname}] R1: ${input_r1}"
	echo "[${prefixname}] R2: ${input_r2}"
else
	# Original FASTA mode (with chimera removal)
	input_fasta="${inpath}/${prefixname}.final_clean.fasta"
	
	if [ ! -f "${input_fasta}" ]; then
		echo "ERROR: Input fasta not found: ${input_fasta}" >&2
		exit 1
	fi
	
	if [ ! -s "${input_fasta}" ]; then
		echo "ERROR: Input fasta is empty: ${input_fasta}" >&2
		exit 1
	fi
	
	echo "[${prefixname}] Input mode: FASTA (with chimera removal)"
	echo "[${prefixname}] Input: ${input_fasta}"
fi
## Input file check$

echo "[${prefixname}] Running Kraken2 with confidence=${confidence}..."

## ^[MODIFIED] Run Kraken2 based on inputmode
if [ "${inputmode}" == "fastq_paired" ]; then
	# NEW: Paired-end FASTQ mode
	kraken2 -db ${refdbpath} \
		--paired \
		--threads 1 \
		--confidence ${confidence} \
		--minimum-hit-groups ${minhitgroup} \
		--report ${outpath}/${prefixname}.taxa.kraken2.txt \
		--output ${outpath}/${prefixname}.result.kraken2.txt \
		${input_r1} ${input_r2}
else
	# Original FASTA mode
	kraken2 -db ${refdbpath} \
		--threads 1 \
		--confidence ${confidence} \
		--minimum-hit-groups ${minhitgroup} \
		--report ${outpath}/${prefixname}.taxa.kraken2.txt \
		--output ${outpath}/${prefixname}.result.kraken2.txt \
		${input_fasta}
fi

kraken2_exit=$?
if [ ${kraken2_exit} -ne 0 ]; then
	echo "KRAKEN2_FAILED: Kraken2 command failed for ${prefixname} (exit code: ${kraken2_exit})" >&2
	exit 2
fi
## Run Kraken2$

# Check if Kraken2 report was generated
kraken_report="${outpath}/${prefixname}.taxa.kraken2.txt"
if [ ! -f "${kraken_report}" ]; then
	echo "KRAKEN2_FAILED: Kraken2 report not generated for ${prefixname}" >&2
	exit 2
fi

if [ ! -s "${kraken_report}" ]; then
	echo "KRAKEN2_FAILED: Kraken2 report is empty for ${prefixname}" >&2
	exit 2
fi

# Check if Kraken2 report has valid taxa (not just unclassified/root)
# Valid lines: exclude U (unclassified), R with taxid 1 (root), R1 with taxid 3 (Bacteria/Fungi domain - keep for processing but check others exist)
# Count lines that are actual taxonomic classifications (P, C, O, F, G, S levels)
valid_taxa_count=$(awk -F'\t' '$4 ~ /^[PCOFGS]/ {count++} END {print count+0}' "${kraken_report}")

if [ ${valid_taxa_count} -eq 0 ]; then
	echo "KRAKEN2_FAILED: Kraken2 report has no valid taxa for ${prefixname} (only unclassified/root)" >&2
	exit 2
fi

echo "[${prefixname}] Kraken2 report generated successfully (${valid_taxa_count} valid taxa lines)"

# Run Bracken
echo "[${prefixname}] Running Bracken..."
bracken -d ${refdbpath} -i ${kraken_report} \
	-o ${outpath}/${prefixname}.result.bracken.txt \
	-r ${brackenRlen} -l S -t 1

bracken_exit=$?

# Define marker file path
use_kraken2_marker="${outpath}/${prefixname}.use_kraken2"

# Remove old marker if exists
rm -f "${use_kraken2_marker}"

# Check Bracken results - if failed, mark to use Kraken2 instead
bracken_output="${outpath}/${prefixname}.taxa.kraken2_bracken_species.txt"

if [ ${bracken_exit} -ne 0 ]; then
	echo "[${prefixname}] WARNING: Bracken command failed (exit code: ${bracken_exit}), will use Kraken2 report"
	touch "${use_kraken2_marker}"
elif [ ! -f "${bracken_output}" ]; then
	echo "[${prefixname}] WARNING: Bracken species output not generated, will use Kraken2 report"
	touch "${use_kraken2_marker}"
elif [ ! -s "${bracken_output}" ]; then
	echo "[${prefixname}] WARNING: Bracken species output is empty, will use Kraken2 report"
	touch "${use_kraken2_marker}"
else
	# Check if Bracken output has valid content (actual taxonomic classifications)
	bracken_valid_lines=$(awk -F'\t' '$4 ~ /^[PCOFGS]/ {count++} END {print count+0}' "${bracken_output}")
	
	if [ ${bracken_valid_lines} -lt 1 ]; then
		echo "[${prefixname}] WARNING: Bracken species output has no valid taxa, will use Kraken2 report"
		touch "${use_kraken2_marker}"
	else
		echo "[${prefixname}] Bracken completed successfully (${bracken_valid_lines} valid taxa lines)"
	fi
fi

# Report final status
if [ -f "${use_kraken2_marker}" ]; then
	echo "[${prefixname}] Taxa classification completed - SOURCE: Kraken2 (confidence=${confidence}, mode=${inputmode})"
else
	echo "[${prefixname}] Taxa classification completed - SOURCE: Bracken (confidence=${confidence}, mode=${inputmode})"
fi

exit 0
## map to reference database$
