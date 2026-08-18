#!/bin/bash
set -e  # Exit immediately if a command exits with non-zero status
set -o pipefail  # Pipe failures cause script to exit

## pre-taxatable generation
## generated on 2025.09.16
## Modified: 2025.11.28 - Added Phase 1-4 error detection flags
## Modified: 2025.12.07 - Added pipeline start time recording
## Modified: 2025.12.13 - Added Kraken2 confidence two-stage fallback mechanism
## Modified: 2025.12.13 - Changed failure definition: only check Kraken2 results
## Modified: 2025.12.19 - Added Skip Chimera Removal option with paired-end Kraken2 support

projectname=$1 # = uuid
projectpath="/nfs/CoMeDA/projects_v2/${projectname}"
demultipx=$2 # yes / no
barcocol=$3 # barcode col.name / none
Fprimercol=$4 # forward primer col.name / none
Rprimercol=$5 # reverse primer col.name / none
qscore=$6 # default: short_reads:20, pacbio: 30, nanopore: 15
minlen=$7 # default: short_reads: 150, pacbio / nanopore: 400
maxlen=$8 # default: short_reads: 600, pacbio / nanopore : 1800
seqfilecol=$9 # fastq file col.name /none
uchimeref="${10}" # yes / no for using --uchime_ref; default: no
metabarctype="${11}" # 16S / ITS
readtype="${12}" # short_reads or long_reads
skipchimera="${13}" # NEW: yes / no - skip chimera removal and use paired-end Kraken2
user_confidence="${14}" # NEW (reviewer revision): user-adjustable Kraken2 confidence; overrides Stage 1 default when provided
njobs=4

datapath="${projectpath}/rawdata/taxafile"
metapath="${projectpath}/rawdata/metadata"
pretaxapath="${projectpath}/analysis/preTaxaTable"
scriptpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"
toolpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/tools/KrakenTools"

## ^[NEW] Default skipchimera to "no" if not provided
if [ -z "${skipchimera}" ]; then
    skipchimera="no"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skip Chimera Removal: ${skipchimera}"
## Default skipchimera$

## ^[NEW] Define Kraken2 confidence parameters (two-stage fallback)
# Stage 1: Default confidence values
# Stage 2: Fallback confidence values (if Stage 1 fails)
if [ "${metabarctype}" == "16S" ]; then
	CONFIDENCE_STAGE1=0.1
	CONFIDENCE_STAGE2=0.05
elif [ "${metabarctype}" == "ITS" ]; then
	CONFIDENCE_STAGE1=0.05
	CONFIDENCE_STAGE2=0
fi

# [NEW - reviewer revision] If a user-specified confidence was provided, use it as the Stage 1 value.
# Backward-compatible: when the 14th argument is empty, the metabarctype-based default above is kept.
if [ -n "${user_confidence}" ]; then
	CONFIDENCE_STAGE1=${user_confidence}
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using user-specified Kraken2 confidence (Stage 1): ${CONFIDENCE_STAGE1}"
fi

# Track which confidence was actually used
FINAL_CONFIDENCE=${CONFIDENCE_STAGE1}
CONFIDENCE_ADJUSTED="FALSE"
## Define Kraken2 confidence parameters$

## ^[NEW] Record pipeline start time for total runtime calculation
pipeline_start_time=$( date +%s )
echo "${pipeline_start_time}" > "${projectpath}/.pipeline_start_time"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pipeline start time recorded: ${pipeline_start_time}"
## Record pipeline start time$

## ^Error handling functions
create_error_flag() {
    local phase_num=$1
    local phase_name=$2
    local error_msg=$3
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local error_flag="${projectpath}/.phase${phase_num}_error"
    
    echo "Phase ${phase_num} (${phase_name}) failed: ${error_msg}" > "${error_flag}"
    echo "[${timestamp}] ERROR: Phase ${phase_num} (${phase_name}) - ${error_msg}" >&2
    exit 1
}

create_success_flag() {
    local phase_num=$1
    local success_flag="${projectpath}/.phase${phase_num}_complete"
    touch "${success_flag}"
}

check_command_success() {
    local exit_code=$?
    local phase_num=$1
    local phase_name=$2
    local step_description=$3
    
    if [ ${exit_code} -ne 0 ]; then
        create_error_flag "${phase_num}" "${phase_name}" "${step_description} failed (exit code: ${exit_code})"
    fi
}

## ^[NEW] Record parameter adjustment (for Shell scripts)
record_shell_adjustment() {
    local parameter=$1
    local adjusted_value=$2
    local original_value=$3
    local reason=$4
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local adjustment_file="${projectpath}/analysis/shell_adjustments.tmp"
    
    # Ensure directory exists
    mkdir -p "${projectpath}/analysis"
    
    # Append adjustment record
    cat >> "${adjustment_file}" << EOF
# SHELL_ADJUSTMENT
parameter:${parameter}
adjusted_value:${adjusted_value}
original_value:${original_value}
reason:${reason}
timestamp:${timestamp}
EOF
    
    echo "[PARAMETER ADJUSTMENT] ${parameter}: ${original_value} -> ${adjusted_value} (${reason})"
}
## Record parameter adjustment$

## Error handling functions$

mkdir -p ${pretaxapath}/metadatafiles
mkdir -p ${pretaxapath}/preprocessing
mkdir -p ${pretaxapath}/rawTaxaTable

metafile=$( ls ${metapath}/* )
fromdos ${metafile}
Fprimercolno=$( head -n 1 ${metafile} | datamash transpose | grep -nw "${Fprimercol}" | cut -d":" -f 1 )
Rprimercolno=$( head -n 1 ${metafile} | datamash transpose | grep -nw "${Rprimercol}" | cut -d":" -f 1 )
seqfilecolno=$( head -n 1 ${metafile} | datamash transpose | grep -nw "${seqfilecol}" | cut -d":" -f 1 )
if [ "${metabarctype}" == "16S" ]; then
	refdbpath="/nfs/CoMeDA/databases/greengenes2_v2024.09_bb.modified"
elif [ "${metabarctype}" == "ITS" ]; then
	refdbpath="/nfs/CoMeDA/databases/unite10_v2025.02_dynamic.modified"
fi

# ^step 0 if need to de-multiplex
if [ "${demultipx}" == "yes" ]; then
	demuxpath="${pretaxapath}/preprocessing/demultiplex"
	if [ -d ${demuxpath} ]; then
		rm -r ${demuxpath}
	fi
	mkdir -p ${demuxpath}

	for demuxfile in $( cut -f ${seqfilecolno} ${metafile} | sed '1d' | sort | uniq )
	do
		demuxR1seq=$( echo "${demuxfile}" | cut -d"," -f 1 | sed 's/ //g' )
		demuxR2seq=$( echo "${demuxfile}" | cut -d"," -f 2 | sed 's/ //g' )
		metadataname=$( echo "${demuxR1seq}" | sed 's/R1/\t/g' | cut -f 1 )
		awk -F"\t" -v demuxfile=${demuxfile} -v seqfilecolno=${seqfilecolno} '{if ($seqfilecolno == demuxfile || NR == 1) print}' ${metafile} > ${demuxpath}/${metadataname}.metadata.tmp
		barcocolno=$( head -n 1 ${demuxpath}/${metadataname}.metadata.tmp | datamash transpose | grep -nw "${barcocol}" | cut -d":" -f 1 )
		echo "${scriptpath}/1.0_demultiplex.sh ${demuxR1seq} ${demuxR2seq} ${datapath} ${demuxpath} ${barcocolno} ${demuxpath}/${metadataname}.metadata.tmp" >> ${demuxpath}/demux.commandlist
	done
fi
# step 0 if need to de-multiplex$

if [ -d ${pretaxapath}/preprocessing/clean ]; then
	rm -r ${pretaxapath}/preprocessing/clean
fi
if [ -f ${pretaxapath}/preprocessing/clean.log ]; then
	rm ${pretaxapath}/preprocessing/clean.log
fi
mkdir -p ${pretaxapath}/preprocessing/clean

if [ -d ${pretaxapath}/preprocessing/nochime ]; then
	rm -r ${pretaxapath}/preprocessing/nochime
fi
mkdir -p ${pretaxapath}/preprocessing/nochime

if [ -d ${pretaxapath}/preprocessing/map2ref ]; then
	rm -r ${pretaxapath}/preprocessing/map2ref
fi
mkdir -p ${pretaxapath}/preprocessing/map2ref

for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
do
	# ^step 1 quality control
	if [ "${demultipx}" == "yes" ]; then
		rawfilepath="${pretaxapath}/preprocessing/demultiplex"
	elif [ "${demultipx}" == "no" ]; then
		rawfilepath=${datapath}
	fi

	echo "${scriptpath}/1.1_qualitycontrol.sh ${readtype} ${rawfilepath} ${pretaxapath}/preprocessing ${samplename} ${metafile} ${Fprimercolno} ${Rprimercolno} ${seqfilecolno} ${qscore} ${minlen} ${maxlen} ${demultipx}" >> ${pretaxapath}/preprocessing/clean/qc.commandlist
	# step 1 quality control$

	# NOTE: Chimera removal commandlist generation moved to after Phase 2
	# This allows per-sample read length detection for auto mode (2025.12.20)
done

## ^Phase 1: Demultiplexing (if needed)
if [ ${demultipx} == "yes" ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Phase 1: Demultiplexing"
	
	if ! parallel -j ${njobs} < ${pretaxapath}/preprocessing/demultiplex/demux.commandlist; then
		create_error_flag "1" "Demultiplexing" "Parallel demultiplexing execution failed"
	fi
	
	rm ${pretaxapath}/preprocessing/demultiplex/demux.commandlist ${pretaxapath}/preprocessing/demultiplex/unknown.*.fastq ${pretaxapath}/preprocessing/demultiplex/*barcode.fasta ${pretaxapath}/preprocessing/demultiplex/*tmp 2>/dev/null || true
	
	create_success_flag "1"
	echo "Phase 1 Completed"

	## ^[NEW] Post-Demultiplex Validation: Check for empty files and filter samples (2025.12.20)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Validating demultiplexed files..."

        demux_dir="${pretaxapath}/preprocessing/demultiplex"
        empty_samples_file="${demux_dir}/empty_samples.txt"
        valid_samples_file="${demux_dir}/valid_samples.txt"
        demux_validation_report="${demux_dir}/demux_validation_report.txt"

        # Clear previous files
        > "${empty_samples_file}"
        > "${valid_samples_file}"

        # Initialize report
        echo -e "Sample\tR1_Status\tR2_Status\tResult" > "${demux_validation_report}"

        empty_count=0
        valid_count=0

	for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
        do
                r1_file="${demux_dir}/${samplename}.R1.fastq"
                r2_file="${demux_dir}/${samplename}.R2.fastq"

                # Check R1 status
                if [ -f "${r1_file}" ] && [ -s "${r1_file}" ]; then
                        r1_status="OK"
                elif [ -f "${r1_file}" ]; then
                        r1_status="EMPTY"
                else
                        r1_status="MISSING"
                fi

                # Check R2 status
                if [ -f "${r2_file}" ] && [ -s "${r2_file}" ]; then
                        r2_status="OK"
                elif [ -f "${r2_file}" ]; then
                        r2_status="EMPTY"
                else
                        r2_status="MISSING"
                fi

                # Determine result
                if [ "${r1_status}" == "OK" ] && [ "${r2_status}" == "OK" ]; then
                        echo "${samplename}" >> "${valid_samples_file}"
                        echo -e "${samplename}\t${r1_status}\t${r2_status}\tVALID" >> "${demux_validation_report}"
                        valid_count=$((valid_count + 1))
                else
                        echo "${samplename}" >> "${empty_samples_file}"
                        echo -e "${samplename}\t${r1_status}\t${r2_status}\tREMOVED" >> "${demux_validation_report}"
                        empty_count=$((empty_count + 1))

                        # Remove empty/missing files
                        rm -f "${r1_file}" "${r2_file}"

                        echo "  [WARNING] Sample ${samplename}: R1=${r1_status}, R2=${r2_status} - REMOVED"
                fi
        done

	echo "  Validation complete: ${valid_count} valid, ${empty_count} removed"
        echo "  Report saved to: ${demux_validation_report}"

        # If empty samples found, update metadata and regenerate commandlists
        if [ ${empty_count} -gt 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Filtering metadata and regenerating command lists..."

                # Create filtered metadata
                original_metafile="${metafile}"
                filtered_metafile="${pretaxapath}/metadatafiles/filtered.metadata.txt"

                # Keep header + valid samples only
                head -1 "${original_metafile}" > "${filtered_metafile}"
                while IFS= read -r samplename; do
                        awk -F"\t" -v sample="${samplename}" '$1 == sample' "${original_metafile}" >> "${filtered_metafile}"
                done < "${valid_samples_file}"

                # Update metafile to use filtered version
                metafile="${filtered_metafile}"

                # Regenerate qc.commandlist with filtered samples
                > ${pretaxapath}/preprocessing/clean/qc.commandlist

                while IFS= read -r samplename; do
                        rawfilepath="${pretaxapath}/preprocessing/demultiplex"
                        echo "${scriptpath}/1.1_qualitycontrol.sh ${readtype} ${rawfilepath} ${pretaxapath}/preprocessing ${samplename} ${metafile} ${Fprimercolno} ${Rprimercolno} ${seqfilecolno} ${qscore} ${minlen} ${maxlen} ${demultipx}" >> ${pretaxapath}/preprocessing/clean/qc.commandlist
                done < "${valid_samples_file}"

                echo "  Filtered metadata: ${filtered_metafile}"
                echo "  QC command list regenerated for ${valid_count} samples"

                # Record the adjustment
                record_shell_adjustment \
                        "demux_samples_removed" \
                        "${empty_count}" \
                        "0" \
                        "Removed ${empty_count} samples with empty/missing demultiplex output"
        fi

	# Check if any valid samples remain
        if [ ${valid_count} -eq 0 ]; then
                create_error_flag "1" "Demultiplexing" "No valid samples after demultiplexing - all files were empty or missing. Check barcode sequences in metadata."
        fi
        ## Post-Demultiplex Validation$
fi
## Phase 1$

## ^Phase 2: Quality Control
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Phase 2: Quality Control"

if ! parallel -j ${njobs} < ${pretaxapath}/preprocessing/clean/qc.commandlist; then
	create_error_flag "2" "Quality Control" "Parallel quality control execution failed"
fi

rm ${pretaxapath}/preprocessing/clean/qc.commandlist
create_success_flag "2"
echo "Phase 2 Completed"
## Phase 2$

## ^[NEW] Per-Sample Read Length Detection and Chimera Decision (2025.12.20)
## This section handles three scenarios:
##   1. skipchimera == "auto" && readtype == "short_reads" → per-sample detection
##   2. skipchimera == "auto" && readtype == "long_reads" → all execute
##   3. skipchimera == "yes" or "no" → apply to all samples

# Initialize sample classification files
skip_samples_file="${pretaxapath}/preprocessing/nochime/skip_samples.txt"
execute_samples_file="${pretaxapath}/preprocessing/nochime/execute_samples.txt"
readlength_report="${pretaxapath}/preprocessing/nochime/sample_readlength_report.txt"

# Clear previous files
> "${skip_samples_file}"
> "${execute_samples_file}"

# Initialize report header
echo -e "Sample\tRead_Length\tMode" > "${readlength_report}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Determining chimera removal mode for each sample..."

if [ "${skipchimera}" == "auto" ] && [ "${readtype}" == "short_reads" ]; then
    # =========================================================================
    # Per-sample detection for short reads in auto mode
    # =========================================================================
    echo "  Mode: Per-sample auto-detection (short_reads)"
    
    skip_count=0
    execute_count=0
    
    for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
    do
        clean_r1="${pretaxapath}/preprocessing/clean/${samplename}.clean.R1.fastq"
        
        if [ -f "${clean_r1}" ] && [ -s "${clean_r1}" ]; then
            # Calculate median read length from first 1000 reads
            # IMPORTANT: Use head FIRST to limit input lines
            median_readlen=$( head -n 4000 "${clean_r1}" | awk 'NR%4==2 {print length($0)}' | datamash median 1 2>/dev/null )
            
            # Handle empty or invalid result
            if [ -z "${median_readlen}" ] || [ "${median_readlen}" == "nan" ]; then
                median_readlen=0
            fi
            
            # Convert to integer for comparison
            median_readlen_int=$( printf "%.0f" "${median_readlen}" )
            
            # Decision: if read length <= 200, skip chimera removal
            if [ ${median_readlen_int} -le 200 ]; then
                echo "${samplename}" >> "${skip_samples_file}"
                echo -e "${samplename}\t${median_readlen_int}\tskip (fastq_paired)" >> "${readlength_report}"
                skip_count=$((skip_count + 1))
            else
                echo "${samplename}" >> "${execute_samples_file}"
                echo -e "${samplename}\t${median_readlen_int}\texecute (fasta)" >> "${readlength_report}"
                execute_count=$((execute_count + 1))
            fi
        else
            # File not found - default to execute
            echo "  [WARNING] Clean R1 not found for ${samplename}, defaulting to execute"
            echo "${samplename}" >> "${execute_samples_file}"
            echo -e "${samplename}\tNA\texecute (fasta, default)" >> "${readlength_report}"
            execute_count=$((execute_count + 1))
        fi
    done
    
    echo "  Detection complete:"
    echo "    - Skip chimera (fastq_paired): ${skip_count} samples"
    echo "    - Execute chimera (fasta): ${execute_count} samples"
    
    # Record adjustment
    record_shell_adjustment \
        "skip_chimera_mode" \
        "per_sample" \
        "auto" \
        "Per-sample detection: ${skip_count} skip, ${execute_count} execute"

elif [ "${skipchimera}" == "auto" ] && [ "${readtype}" == "long_reads" ]; then
    # =========================================================================
    # Long reads: all samples execute chimera removal
    # =========================================================================
    echo "  Mode: Long reads detected - all samples will execute chimera removal"
    
    for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
    do
        echo "${samplename}" >> "${execute_samples_file}"
        echo -e "${samplename}\tlong_read\texecute (fasta)" >> "${readlength_report}"
    done
    
    record_shell_adjustment \
        "skip_chimera" \
        "no (all execute)" \
        "auto" \
        "Long reads detected, using long-read chimera removal protocol for all samples"

elif [ "${skipchimera}" == "yes" ]; then
    # =========================================================================
    # User selected: skip all
    # =========================================================================
    echo "  Mode: User selected skip - all samples will skip chimera removal"
    
    for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
    do
        echo "${samplename}" >> "${skip_samples_file}"
        echo -e "${samplename}\tuser_skip\tskip (fastq_paired)" >> "${readlength_report}"
    done

elif [ "${skipchimera}" == "no" ]; then
    # =========================================================================
    # User selected: execute all
    # =========================================================================
    echo "  Mode: User selected execute - all samples will execute chimera removal"
    
    for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
    do
        echo "${samplename}" >> "${execute_samples_file}"
        echo -e "${samplename}\tuser_execute\texecute (fasta)" >> "${readlength_report}"
    done
fi

# Count samples in each category
total_skip=$( wc -l < "${skip_samples_file}" )
total_execute=$( wc -l < "${execute_samples_file}" )

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sample classification complete:"
echo "  - Skip chimera removal: ${total_skip} samples"
echo "  - Execute chimera removal: ${total_execute} samples"
echo "  - Report saved to: ${readlength_report}"

## ^Generate commandlist for samples that need chimera removal
if [ ${total_execute} -gt 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating chimera removal command lists..."
    
    # Clear any existing commandlists
    > "${pretaxapath}/preprocessing/nochime/nochime.commandlist"
    > "${pretaxapath}/preprocessing/nochime/expand.commandlist"
    
    while IFS= read -r samplename
    do
        echo "${scriptpath}/2.1_chimeraremoval.sh ${samplename} ${pretaxapath}/preprocessing/clean ${pretaxapath}/preprocessing/nochime ${readtype} ${uchimeref} ${metabarctype} ${minlen} ${maxlen}" >> ${pretaxapath}/preprocessing/nochime/nochime.commandlist
        echo "${scriptpath}/2.2_expandfastareads.sh ${pretaxapath}/preprocessing/nochime ${samplename}" >> ${pretaxapath}/preprocessing/nochime/expand.commandlist
    done < "${execute_samples_file}"
    
    echo "  Command lists generated for ${total_execute} samples"
fi
## Per-Sample Detection$

## ^Phase 3: Chimera Reads Removal (MODIFIED - per-sample conditional execution)
if [ ${total_execute} -gt 0 ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Phase 3: Chimera Reads Removal (${total_execute} samples)"

	if ! parallel -j ${njobs} < ${pretaxapath}/preprocessing/nochime/nochime.commandlist; then
		create_error_flag "3" "Chimera Removal" "Chimera removal step failed"
	fi

	rm ${pretaxapath}/preprocessing/nochime/nochime.commandlist

	if ! parallel -j ${njobs} < ${pretaxapath}/preprocessing/nochime/expand.commandlist; then
		create_error_flag "3" "Chimera Removal" "FASTA expansion step failed"
	fi

	rm ${pretaxapath}/preprocessing/nochime/expand.commandlist
	create_success_flag "3"
	echo "Phase 3 Completed (${total_execute} samples processed)"
	
	if [ ${total_skip} -gt 0 ]; then
		echo "  Note: ${total_skip} samples skipped chimera removal (will use fastq_paired mode)"
	fi
else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Phase 3: Chimera Removal SKIPPED (all ${total_skip} samples using fastq_paired mode)"
	echo "  -> All samples will use paired-end FASTQ directly for Kraken2 classification"
	
	# Record the skip decision
	record_shell_adjustment \
		"chimera_removal" \
		"all_skipped" \
		"executed" \
		"All ${total_skip} samples skipped chimera removal - using paired-end Kraken2 mode"
	
	create_success_flag "3"
	echo "Phase 3 Skipped (flagged as complete)"
fi
## Phase 3$

## ^Phase 4: Taxa Classification (with two-stage confidence fallback)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Phase 4: Taxa Classification"

# ^[MODIFIED] Function to generate classification command list
# Now supports per-sample input mode based on skip_samples.txt (2025.12.20)
generate_classification_commands() {
	local confidence_value=$1
	local commandlist="${pretaxapath}/preprocessing/map2ref/map2ref.commandlist"
	local skip_file="${pretaxapath}/preprocessing/nochime/skip_samples.txt"
	
	# Clear existing command list
	> "${commandlist}"
	
	for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
	do
		# Check if this sample is in skip_samples.txt
		if grep -qx "${samplename}" "${skip_file}" 2>/dev/null; then
			# Sample skipped chimera removal → use paired-end FASTQ mode
			echo "${scriptpath}/3.1_taxaclassification.sh ${metabarctype} ${readtype} ${pretaxapath}/preprocessing/clean ${pretaxapath}/preprocessing/map2ref ${samplename} ${refdbpath} ${confidence_value} fastq_paired" >> "${commandlist}"
		else
			# Sample had chimera removal → use FASTA mode
			echo "${scriptpath}/3.1_taxaclassification.sh ${metabarctype} ${readtype} ${pretaxapath}/preprocessing/nochime ${pretaxapath}/preprocessing/map2ref ${samplename} ${refdbpath} ${confidence_value} fasta" >> "${commandlist}"
		fi
	done
}

# ^[MODIFIED] Function to check classification results
# Stage 1: ALL samples must have Bracken results
# Stage 2: Bracken preferred, Kraken2 acceptable, >10% no Kraken2 = fail
FAILURE_THRESHOLD_PERCENT=10

check_classification_results() {
	local stage=$1  # "stage1" or "stage2"
	local map2ref_dir="${pretaxapath}/preprocessing/map2ref"
	local failed_samples=""
	local failed_sample_list="${map2ref_dir}/.failed_samples.tmp"
	local total_count=0
	local bracken_count=0
	local kraken2_only_count=0
	local no_result_count=0
	
	# Clear previous failed sample list
	> "${failed_sample_list}"
	
	for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
	do
		total_count=$((total_count + 1))
		
		# Check Bracken result
		bracken_output="${map2ref_dir}/${samplename}.taxa.kraken2_bracken_species.txt"
		kraken_report="${map2ref_dir}/${samplename}.taxa.kraken2.txt"
		
		has_bracken="FALSE"
		has_kraken2="FALSE"
		
		# Check Bracken: exists, non-empty, has valid taxa
		if [ -f "${bracken_output}" ] && [ -s "${bracken_output}" ]; then
			bracken_valid=$(awk -F'\t' '$4 ~ /^[PCOFGS]/ {count++} END {print count+0}' "${bracken_output}")
			if [ ${bracken_valid} -gt 0 ]; then
				has_bracken="TRUE"
			fi
		fi
		
		# Check Kraken2: exists, non-empty, has valid taxa
		if [ -f "${kraken_report}" ] && [ -s "${kraken_report}" ]; then
			kraken2_valid=$(awk -F'\t' '$4 ~ /^[PCOFGS]/ {count++} END {print count+0}' "${kraken_report}")
			if [ ${kraken2_valid} -gt 0 ]; then
				has_kraken2="TRUE"
			fi
		fi
		
		# Categorize result
		if [ "${has_bracken}" == "TRUE" ]; then
			bracken_count=$((bracken_count + 1))
		elif [ "${has_kraken2}" == "TRUE" ]; then
			kraken2_only_count=$((kraken2_only_count + 1))
			# Mark to use Kraken2 report
			touch "${map2ref_dir}/${samplename}.use_kraken2"
		else
			no_result_count=$((no_result_count + 1))
			failed_samples="${failed_samples} ${samplename}"
			echo "${samplename}" >> "${failed_sample_list}"
		fi
	done
	
	# Evaluate results based on stage
	if [ "${stage}" == "stage1" ]; then
		# Stage 1: ALL samples must have Bracken results
		echo "Stage 1 check: ${bracken_count}/${total_count} samples have Bracken results"
		
		local non_bracken=$((kraken2_only_count + no_result_count))
		if [ ${non_bracken} -gt 0 ]; then
			echo "Samples without Bracken: ${non_bracken} (Kraken2-only: ${kraken2_only_count}, Failed: ${no_result_count})"
			if [ ${no_result_count} -gt 0 ]; then
				echo "Failed samples:${failed_samples}"
			fi
			echo "STAGE 1 FAILED: Not all samples have Bracken results - will retry with lower confidence"
			return 1
		fi
		
		echo "STAGE 1 SUCCESS: All samples have Bracken results"
		return 0
	else
		# Stage 2: Calculate failure rate for samples without any results
		local success_count=$((bracken_count + kraken2_only_count))
		
		if [ ${total_count} -gt 0 ]; then
			failure_percent=$(awk "BEGIN {printf \"%.1f\", (${no_result_count}/${total_count})*100}")
		else
			failure_percent="0.0"
		fi
		
		echo "Stage 2 check: ${success_count}/${total_count} samples successful (${no_result_count} failed, ${failure_percent}%)"
		echo "  - Using Bracken: ${bracken_count} samples"
		echo "  - Using Kraken2: ${kraken2_only_count} samples"
		
		if [ ${no_result_count} -gt 0 ]; then
			echo "Samples without any results:${failed_samples}"
			
			# Check if failure rate exceeds threshold
			threshold_exceeded=$(awk "BEGIN {print (${failure_percent} > ${FAILURE_THRESHOLD_PERCENT}) ? 1 : 0}")
			
			if [ "${threshold_exceeded}" -eq 1 ]; then
				echo "STAGE 2 FAILED: ${failure_percent}% samples failed, exceeds ${FAILURE_THRESHOLD_PERCENT}% threshold"
				return 1
			else
				echo "WARNING: ${no_result_count} samples failed but within ${FAILURE_THRESHOLD_PERCENT}% threshold - continuing with successful samples"
				# Create marker files to skip failed samples
				for failed_sample in $(cat "${failed_sample_list}"); do
					touch "${map2ref_dir}/${failed_sample}.skip_sample"
				done
				return 0
			fi
		fi
		
		echo "STAGE 2 SUCCESS: All samples have valid results"
		return 0
	fi
}

# ^[NEW] Function to clean classification results for retry
clean_classification_results() {
	local map2ref_dir="${pretaxapath}/preprocessing/map2ref"
	
	echo "Cleaning previous classification results for retry..."
	rm -f ${map2ref_dir}/*.taxa.kraken2.txt
	rm -f ${map2ref_dir}/*.result.kraken2.txt
	rm -f ${map2ref_dir}/*.result.bracken.txt
	rm -f ${map2ref_dir}/*.taxa.kraken2_bracken_species.txt
	rm -f ${map2ref_dir}/*.use_kraken2
	rm -f ${map2ref_dir}/*.skip_sample
	rm -f ${map2ref_dir}/.failed_samples.tmp
}

# ^[NEW] Function to log data source for each sample
log_data_sources() {
	local map2ref_dir="${pretaxapath}/preprocessing/map2ref"
	local log_file="${pretaxapath}/preprocessing/map2ref/classification_sources.log"
	local skip_file="${pretaxapath}/preprocessing/nochime/skip_samples.txt"
	local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	
	echo "========================================" > "${log_file}"
	echo "Taxa Classification Data Sources Log" >> "${log_file}"
	echo "Generated: ${timestamp}" >> "${log_file}"
	echo "Final Confidence: ${FINAL_CONFIDENCE}" >> "${log_file}"
	echo "Confidence Adjusted: ${CONFIDENCE_ADJUSTED}" >> "${log_file}"
	echo "Chimera Mode: per-sample (see Input_Mode column)" >> "${log_file}"
	echo "Failure Threshold: ${FAILURE_THRESHOLD_PERCENT}%" >> "${log_file}"
	echo "========================================" >> "${log_file}"
	echo "" >> "${log_file}"
	echo -e "Sample\tData_Source\tInput_Mode\tFile_Path" >> "${log_file}"
	
	local bracken_count=0
	local kraken2_count=0
	local skipped_count=0
	local fastq_paired_count=0
	local fasta_count=0
	
	for samplename in $( cut -f 1 ${metafile} | sed '1d' | sort | uniq )
	do
		# Determine input mode for this sample
		local input_mode="fasta"
		if grep -qx "${samplename}" "${skip_file}" 2>/dev/null; then
			input_mode="fastq_paired"
			fastq_paired_count=$((fastq_paired_count + 1))
		else
			fasta_count=$((fasta_count + 1))
		fi
		
		# Check if sample should be skipped
		if [ -f "${map2ref_dir}/${samplename}.skip_sample" ]; then
			echo -e "${samplename}\tSKIPPED\t${input_mode}\tNo valid classification results" >> "${log_file}"
			skipped_count=$((skipped_count + 1))
		elif [ -f "${map2ref_dir}/${samplename}.use_kraken2" ]; then
			echo -e "${samplename}\tKraken2\t${input_mode}\t${map2ref_dir}/${samplename}.taxa.kraken2.txt" >> "${log_file}"
			kraken2_count=$((kraken2_count + 1))
		else
			echo -e "${samplename}\tBracken\t${input_mode}\t${map2ref_dir}/${samplename}.taxa.kraken2_bracken_species.txt" >> "${log_file}"
			bracken_count=$((bracken_count + 1))
		fi
	done
	
	echo "" >> "${log_file}"
	echo "========================================" >> "${log_file}"
	echo "Summary:" >> "${log_file}"
	echo "  Classification sources:" >> "${log_file}"
	echo "    - Bracken: ${bracken_count}" >> "${log_file}"
	echo "    - Kraken2: ${kraken2_count}" >> "${log_file}"
	echo "    - Skipped: ${skipped_count}" >> "${log_file}"
	echo "  Input modes:" >> "${log_file}"
	echo "    - fasta (chimera removed): ${fasta_count}" >> "${log_file}"
	echo "    - fastq_paired (no chimera): ${fastq_paired_count}" >> "${log_file}"
	echo "========================================" >> "${log_file}"
	
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Data sources logged to: ${log_file}"
	
	if [ ${skipped_count} -gt 0 ]; then
		echo "WARNING: ${skipped_count} samples will be excluded from taxa table"
	fi
	
	if [ ${kraken2_count} -gt 0 ]; then
		echo "NOTE: ${kraken2_count} samples using Kraken2 results (Bracken unavailable)"
	fi
	
	if [ ${fastq_paired_count} -gt 0 ] && [ ${fasta_count} -gt 0 ]; then
		echo "NOTE: Mixed input modes - ${fasta_count} fasta, ${fastq_paired_count} fastq_paired"
	fi
}
## Helper functions$

# ^[NEW] Stage 1: Try with default confidence - ALL samples must have Bracken
echo "=========================================="
echo "[Stage 1] Running Taxa Classification with confidence=${CONFIDENCE_STAGE1}"
echo "         Input mode: per-sample (${total_execute} fasta, ${total_skip} fastq_paired)"
echo "         Requirement: ALL samples must have Bracken results"
echo "=========================================="

generate_classification_commands ${CONFIDENCE_STAGE1}

# Run classification (allow failure for retry)
set +e
parallel -j ${njobs} < ${pretaxapath}/preprocessing/map2ref/map2ref.commandlist
parallel_exit=$?
set -e

# Check results - Stage 1 requires ALL samples to have Bracken
if check_classification_results "stage1"; then
	echo "[Stage 1] SUCCESS: All samples have Bracken results with confidence=${CONFIDENCE_STAGE1}"
	FINAL_CONFIDENCE=${CONFIDENCE_STAGE1}
else
	echo "[Stage 1] FAILED: Some samples missing Bracken results"
	
	# ^[NEW] Stage 2: Retry with lower confidence - Bracken preferred, Kraken2 acceptable
	echo ""
	echo "=========================================="
	echo "[Stage 2] Retrying Taxa Classification with confidence=${CONFIDENCE_STAGE2}"
	echo "         Input mode: per-sample (${total_execute} fasta, ${total_skip} fastq_paired)"
	echo "         Requirement: Bracken preferred, Kraken2 acceptable"
	echo "         Failure threshold: >${FAILURE_THRESHOLD_PERCENT}% samples without Kraken2"
	echo "=========================================="
	
	# Clean previous results
	clean_classification_results
	
	# Generate new command list with lower confidence
	generate_classification_commands ${CONFIDENCE_STAGE2}
	
	# Run classification again
	set +e
	parallel -j ${njobs} < ${pretaxapath}/preprocessing/map2ref/map2ref.commandlist
	parallel_exit=$?
	set -e
	
	# Check results - Stage 2 allows Kraken2 fallback, with 10% failure threshold
	if check_classification_results "stage2"; then
		echo "[Stage 2] SUCCESS: Classification completed with confidence=${CONFIDENCE_STAGE2}"
		FINAL_CONFIDENCE=${CONFIDENCE_STAGE2}
		CONFIDENCE_ADJUSTED="TRUE"
		
		# Record the parameter adjustment
		record_shell_adjustment \
			"kraken2_confidence" \
			"${CONFIDENCE_STAGE2}" \
			"${CONFIDENCE_STAGE1}" \
			"Not all samples had Bracken results with default confidence - retrying with lower confidence"
	else
		echo "[Stage 2] FAILED: Taxa classification failed - too many samples without valid results"
		create_error_flag "4" "Taxa Classification" "Taxa classification failed: More than ${FAILURE_THRESHOLD_PERCENT}% of samples could not generate valid classification results even with lowest confidence setting (${CONFIDENCE_STAGE2}). Please check sequence quality and reference database compatibility."
	fi
fi
## Two-stage classification$

# Clean up command list
rm -f ${pretaxapath}/preprocessing/map2ref/map2ref.commandlist

# ^[NEW] Log data sources for each sample
log_data_sources

# ^[NEW] Record final confidence value for parameters_info.txt
echo "${FINAL_CONFIDENCE}" > "${projectpath}/.kraken2_confidence_used"
echo "CONFIDENCE_ADJUSTED=${CONFIDENCE_ADJUSTED}" >> "${projectpath}/.kraken2_confidence_used"
echo "CHIMERA_MODE=per_sample" >> "${projectpath}/.kraken2_confidence_used"
echo "SAMPLES_SKIP_CHIMERA=${total_skip}" >> "${projectpath}/.kraken2_confidence_used"
echo "SAMPLES_EXECUTE_CHIMERA=${total_execute}" >> "${projectpath}/.kraken2_confidence_used"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Final Kraken2 confidence used: ${FINAL_CONFIDENCE}"

# Generate taxa table (pass map2ref_dir for source detection)
if ! ${scriptpath}/3.2_taxatablegeneration.sh ${toolpath} ${pretaxapath}/preprocessing/map2ref ${pretaxapath}/rawTaxaTable ${projectname} ${scriptpath}; then
	create_error_flag "4" "Taxa Classification" "Taxa table generation failed"
fi

if ! cp ${metafile} ${pretaxapath}/metadatafiles/${projectname}.metadata.txt; then
	create_error_flag "4" "Taxa Classification" "Metadata copy failed"
fi

create_success_flag "4"
echo "Phase 4 Completed"
## Phase 4$
