#!/bin/bash

## generate a sample-taxa abundance table using KrakenTools
## generate on 2025.09.05
## Modified: 2025.12.13 - Support mixed Bracken/Kraken2 sources based on marker files
## Modified: 2025.12.13 - Filter out unclassified and root entries
## Modified: 2025.12.18 - Added genus-only taxa recovery from Kraken2 reports

toolpath=$1
inpath=$2
outpath=$3
taxatablename=$4
scriptpath=$5  # [NEW] Script path for 3.5_merge_genus_only.py

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting taxa table generation..."
echo "Input path: ${inpath}"
echo "Output path: ${outpath}"

## ^[NEW] Check if scriptpath is provided, if not try to derive from toolpath
if [ -z "${scriptpath}" ]; then
	# Try to derive scriptpath from toolpath (assume same parent directory)
	scriptpath=$(dirname $(dirname "${toolpath}"))/script
	echo "[INFO] scriptpath not provided, using derived path: ${scriptpath}"
fi

# Check if merge script exists
merge_script="${scriptpath}/3.5_merge_genus_only.py"
if [ ! -f "${merge_script}" ]; then
	echo "[WARNING] Merge script not found: ${merge_script}"
	echo "[WARNING] Genus-only taxa will NOT be recovered"
	MERGE_ENABLED="no"
else
	MERGE_ENABLED="yes"
	echo "[INFO] Genus-only taxa recovery: ENABLED"
fi
## Check merge script$

## ^[NEW] Function to filter kreport - remove unclassified and root
# Input: kreport file
# Output: filtered kreport file (removes U and R with taxid 1)
filter_kreport() {
	local input_file=$1
	local output_file=$2
	
	# Filter conditions:
	# - Remove lines where rank_code (column 4) is "U" (unclassified)
	# - Remove lines where rank_code is "R" and taxid (column 5) is 1 (root)
	# Keep everything else including R1 (domain level like Bacteria)
	awk -F'\t' '!($4 == "U") && !($4 == "R" && $5 == 1)' "${input_file}" > "${output_file}"
}
## Filter function$

## ^convert to mpa format - with source selection and genus-only recovery
echo ""
echo "Converting kreport to MPA format..."
echo "=========================================="

mpa_file_list=""
sample_count=0
bracken_count=0
kraken2_count=0
skipped_count=0
genus_only_recovered=0  # [NEW] Counter for genus-only taxa recovery

# Get all samples by checking for kraken2 reports
for kraken_report in ${inpath}/*.taxa.kraken2.txt
do
	# Extract sample name
	samplename=$(basename "${kraken_report}" .taxa.kraken2.txt)
	
	# Check if sample should be skipped (no valid Kraken2 results)
	skip_marker="${inpath}/${samplename}.skip_sample"
	if [ -f "${skip_marker}" ]; then
		echo "[${samplename}] SKIPPED - No valid classification results"
		skipped_count=$((skipped_count + 1))
		continue
	fi
	
	sample_count=$((sample_count + 1))
	
	# Determine source based on marker file
	use_kraken2_marker="${inpath}/${samplename}.use_kraken2"
	
	if [ -f "${use_kraken2_marker}" ]; then
		# Use Kraken2 report (Bracken failed)
		source_file="${inpath}/${samplename}.taxa.kraken2.txt"
		source_type="Kraken2"
		kraken2_count=$((kraken2_count + 1))
		do_merge="no"  # No merge needed for Kraken2-only samples
	else
		# Use Bracken output (default)
		source_file="${inpath}/${samplename}.taxa.kraken2_bracken_species.txt"
		source_type="Bracken"
		bracken_count=$((bracken_count + 1))
		do_merge="yes"  # Merge genus-only taxa for Bracken samples
		
		# Fallback to Kraken2 if Bracken file doesn't exist
		if [ ! -f "${source_file}" ]; then
			source_file="${inpath}/${samplename}.taxa.kraken2.txt"
			source_type="Kraken2(fallback)"
			kraken2_count=$((kraken2_count + 1))
			bracken_count=$((bracken_count - 1))
			do_merge="no"
		fi
	fi
	
	echo "[${samplename}] Source: ${source_type}"
	
	# Check source file exists
	if [ ! -f "${source_file}" ]; then
		echo "ERROR: Source file not found: ${source_file}" >&2
		exit 1
	fi
	
	# ^[NEW] Merge genus-only taxa if using Bracken and merge is enabled
	if [ "${do_merge}" == "yes" ] && [ "${MERGE_ENABLED}" == "yes" ]; then
		kraken2_file="${inpath}/${samplename}.taxa.kraken2.txt"
		merged_file="${inpath}/${samplename}.taxa.merged.txt"
		
		if [ -f "${kraken2_file}" ]; then
			# Run merge script
			merge_output=$(python3 "${merge_script}" \
				--bracken "${source_file}" \
				--kraken2 "${kraken2_file}" \
				--output "${merged_file}" \
				--verbose 2>&1)
			
			merge_exit=$?
			
			if [ ${merge_exit} -eq 0 ] && [ -f "${merged_file}" ] && [ -s "${merged_file}" ]; then
				# Extract genus-only count from merge output
				genus_added=$(echo "${merge_output}" | grep "Genus-only added:" | sed 's/.*Genus-only added: \([0-9]*\).*/\1/')
				if [ -n "${genus_added}" ] && [ "${genus_added}" -gt 0 ]; then
					echo "       -> Merged ${genus_added} genus-only taxa"
					genus_only_recovered=$((genus_only_recovered + genus_added))
				fi
				
				# Use merged file as source
				source_file="${merged_file}"
			else
				echo "[${samplename}] WARNING: Merge failed, using original Bracken file"
				# Continue with original Bracken file
			fi
		fi
	fi
	## Merge genus-only taxa$
	
	# Filter kreport (remove unclassified and root)
	filtered_file="${inpath}/${samplename}.filtered.kreport.txt"
	filter_kreport "${source_file}" "${filtered_file}"
	
	# Check filtered file has content
	if [ ! -s "${filtered_file}" ]; then
		echo "WARNING: Filtered kreport is empty for ${samplename}, skipping..."
		rm -f "${filtered_file}"
		continue
	fi
	
	# Convert to MPA format
	mpa_output="${inpath}/${samplename}.taxa.mpa.txt"
	${toolpath}/kreport2mpa_withTaxaid.py -r "${filtered_file}" -o "${mpa_output}" --include-taxid
	
	if [ ! -f "${mpa_output}" ]; then
		echo "ERROR: MPA conversion failed for ${samplename}" >&2
		exit 1
	fi
	
	# Add to file list
	mpa_file_list="${mpa_file_list} ${mpa_output}"
	
	# Clean up temporary files
	rm -f "${filtered_file}"
	rm -f "${inpath}/${samplename}.taxa.merged.txt"  # [NEW] Clean up merged file
done

echo ""
echo "=========================================="
echo "Conversion summary:"
echo "  Total samples processed: ${sample_count}"
echo "  Bracken sources: ${bracken_count}"
echo "  Kraken2 sources: ${kraken2_count}"
echo "  Skipped samples: ${skipped_count}"
echo "  Genus-only taxa recovered: ${genus_only_recovered}"  # [NEW]
echo "=========================================="
## convert to mpa format$

## ^combine all samples
echo ""
echo "Combining all samples into taxa table..."

# Trim leading space from file list
mpa_file_list=$(echo "${mpa_file_list}" | sed 's/^ *//')

if [ -z "${mpa_file_list}" ]; then
	echo "ERROR: No MPA files generated" >&2
	exit 1
fi

# Combine MPA files
${toolpath}/combine_mpa_withTaxaid.py -i ${mpa_file_list} -o ${inpath}/${taxatablename}.rawTaxaTable.tmp

# Generate header with sample names
# Extract sample names from MPA files in the same order
header_samples=""
for mpa_file in ${mpa_file_list}
do
	samplename=$(basename "${mpa_file}" .taxa.mpa.txt)
	header_samples="${header_samples}${samplename}\n"
done

# Create final taxa table with proper header
echo -e "taxonomy\ntaxa.id\n${header_samples}" | head -n -1 | datamash transpose | \
	cat - ${inpath}/${taxatablename}.rawTaxaTable.tmp | \
	sed '2d' | \
	sed -e 's/__/_/g' -e "s/|/;/g" -e 's/ /_/g' > ${outpath}/${taxatablename}.rawTaxaTable.txt

# Clean up temporary files
rm -f ${inpath}/${taxatablename}.rawTaxaTable.tmp
rm -f ${inpath}/*.taxa.mpa.txt
rm -f ${inpath}/*.taxa.kraken2_bracken_species.mpa.txt 2>/dev/null || true

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Taxa table generation completed"
echo "Output: ${outpath}/${taxatablename}.rawTaxaTable.txt"

# ^[NEW] Log genus-only recovery status
if [ "${MERGE_ENABLED}" == "yes" ]; then
	echo "[INFO] Genus-only taxa recovery was enabled"
	echo "[INFO] Total genus-only taxa recovered: ${genus_only_recovered}"
else
	echo "[WARNING] Genus-only taxa recovery was DISABLED (merge script not found)"
fi
## combine all samples$
