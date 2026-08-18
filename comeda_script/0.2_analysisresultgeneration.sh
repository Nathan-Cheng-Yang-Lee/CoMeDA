#! /bin/bash
set -e  # Exit immediately if a command exits with non-zero status
set -o pipefail  # Pipe failures cause script to exit

## master pipeline for metabarcoding data analysis (parallel execution)
## integrates taxa analysis (4.1 -> 4.2) and functional prediction (5.1 -> 5.2/5.3)
## generate on 2025.10.15
## Modified: v2.5 - Unified Log Path + Metadata Auto-recovery + Robust Skip Logic
## Modified: 2025.11.28 - Added Phase 5-6 error detection flags
## Modified: 2025-12-07 - Full pipeline runtime + FASTQ cleanup

projectname=$1
projectpath="/nfs/CoMeDA/projects_v2/${projectname}"
outname="analysis_result" 
datatype=$2 # 16S / ITS
groupname=$3 # primary comparison column name
compinfopath=$4 
batchcolname=$5 # column name / none
taxalevels="${6}" # [FIX] Added quotes
samplerichcut=$7 # default: 5
samplerccut=$8 # default: 500
taxaprevcut=$9 # default 0.2
funcprevcut=${10} # default: 0.3
funcsizecut=${11} # default: 2
strictedpropcut=${12} # default: 0.0001
strictedprevcut=${13} # default: 16S:0.3 / ITS:0.2
inputtype=${14}
readtype=${15} # short_reads / long_reads
analysisname=${16}
threads=4
scriptpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"

# Check if readtype is NA (taxatable mode)
if [ "${readtype}" == "none" ]; then
    echo "[INFO] Taxatable mode detected, readtype not applicable"
fi

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

check_branch_failure() {
    local phase_num=$1
    local error_flag="${projectpath}/.phase${phase_num}_error"
    
    if [ -f "${error_flag}" ]; then
        return 1  # Failure detected
    fi
    return 0  # No failure
}
## Error handling functions$

## ^set default strict prevalence cutoff
if [ -z "${strictedprevcut}" ]; then
	if [ "${datatype}" == "16S" ]; then
		strictedprevcut=0.3
	elif [ "${datatype}" == "ITS" ]; then
		strictedprevcut=0.2
	fi
fi
# set default strict prevalence cutoff$

## ^validate input parameters
if [ -z "${projectpath}" ] || [ -z "${outname}" ] || [ -z "${projectname}" ] || [ -z "${datatype}" ] || [ -z "${groupname}" ] || [ -z "${compinfopath}" ]; then
	echo "ERROR: Missing required parameters"
	exit 1
fi

if [ "${datatype}" != "16S" ] && [ "${datatype}" != "ITS" ]; then
	echo "ERROR: datatype must be either 16S or ITS"
	exit 1
fi
# validate input parameters$

## ^check input files and directories (With Auto-Recovery)
rawtaxatable="${projectpath}/analysis/preTaxaTable/rawTaxaTable/${projectname}.rawTaxaTable.txt"
metadata="${projectpath}/analysis/preTaxaTable/metadatafiles/${projectname}.metadata.txt"
nochimerdir="${projectpath}/analysis/preTaxaTable/preprocessing/nochime"

if [ ! -d "${projectpath}" ]; then
	echo "ERROR: Project path does not exist: ${projectpath}"
	exit 1
fi

# [Auto-Recovery] Metadata Check
if [ ! -f "${metadata}" ]; then
    echo "WARNING: Metadata not found at expected path: ${metadata}"
    echo "Attempting to recover from rawdata..."
    
    raw_meta=$(ls ${projectpath}/rawdata/metadata/*.txt 2>/dev/null | head -n 1)
    
    if [ -f "${raw_meta}" ]; then
        mkdir -p $(dirname "${metadata}")
        cp "${raw_meta}" "${metadata}"
#        sed -i 's/\r$//' "${metadata}"
        fromdos ${metadata}
        echo "SUCCESS: Metadata recovered from: ${raw_meta}"
    else
        echo "ERROR: Metadata file not found in rawdata either. Cannot proceed."
        exit 1
    fi
fi

# [Auto-Recovery] Taxa Table Check (For Taxatable mode mainly)
if [ ! -f "${rawtaxatable}" ]; then
    echo "WARNING: Raw taxa table not found at expected path: ${rawtaxatable}"
    
    if [ "${inputtype}" == "taxatable" ]; then
         echo "Attempting to recover from rawdata..."
         raw_taxa=$(ls ${projectpath}/rawdata/taxafile/*.txt 2>/dev/null | head -n 1)
         if [ -f "${raw_taxa}" ]; then
             mkdir -p $(dirname "${rawtaxatable}")
             cp "${raw_taxa}" "${rawtaxatable}"
	     fromdos ${rawtaxatable}
             echo "SUCCESS: Taxa table recovered from: ${raw_taxa}"
         fi
    fi
fi

# Final check
if [ ! -f "${rawtaxatable}" ]; then
	echo "ERROR: Raw taxa table not found: ${rawtaxatable}"
	exit 1
fi

if [ ! -f "${compinfopath}" ]; then
	echo "ERROR: Comparison info file not found: ${compinfopath}"
	exit 1
fi

# Check for function prediction prerequisites
skipfunction="no"
if [ ! -d "${nochimerdir}" ]; then
	echo "WARNING: Nochimera directory not found: ${nochimerdir}"
	echo "Functional prediction will be skipped."
	skipfunction="yes"
else
	nochimercount=$( find ${nochimerdir} -name "*.nochimera.formated.fasta" | wc -l )
	if [ ${nochimercount} -eq 0 ]; then
		echo "WARNING: No nochimera.formated.fasta files found in ${nochimerdir}"
		echo "Functional prediction will be skipped."
		skipfunction="yes"
	fi
fi
# check input files and directories$

## ^setup output directories (Unified Log Path)
# Check if analysisname was passed
if [ -z "${analysisname}" ]; then
    echo "ERROR: analysisname parameter is required (should be passed from Step 3)"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using analysisname from Step 3: ${analysisname}"

outpath="${projectpath}/analysis/${analysisname}"
funcoutpath="${outpath}/functional_prediction"

logpath="${projectpath}/logs"

mkdir -p ${logpath}
mkdir -p ${outpath}
if [ "${skipfunction}" == "no" ]; then
	mkdir -p ${funcoutpath}
fi
# setup output directories$

## ^display configuration
echo "Phase 5 : Taxa Analysis"
echo "=========================================="
echo "Master Pipeline for Metabarcoding Analysis"
echo "=========================================="
echo "Output directories:"
echo "  Taxa analysis     : ${outpath}"
echo "  Logs (Unified)    : ${logpath}"
echo "=========================================="
# display configuration$

starttime=$( date +%s )

# step 4.1: taxa table filtering
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 4.1: Running taxa table filtering..."
if ! bash ${scriptpath}/4.1_taxatablefiltering.sh \
  ${projectpath} ${analysisname} ${projectname} ${groupname} \
  ${samplerichcut} ${samplerccut} ${taxaprevcut} ${inputtype} \
  > ${logpath}/4.1_taxafilter.log 2>&1; then
if [ "${inputtype}" == "taxatable" ]; then pid="1"; else pid="5"; fi
  create_error_flag "${pid}" "Taxa Analysis" "Taxa table filtering (4.1) failed"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 4.1 completed"

## ^branch 1: taxa analysis (parallel execution in background)
{
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Branch 1: Taxa Analysis"
        branch1start=$( date +%s )

	# step 4.2: metagenomic analysis
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 4.2: Running metagenomic analysis..."
	filteredtable="${projectname}.filteredTaxaTable.species.txt"
	cp ${compinfopath} ${outpath}/compinfotable.txt
	
	if ! Rscript ${scriptpath}/4.2_metagenomicanalysis.r \
		${filteredtable} \
		"${taxalevels}" \
		"${projectname}.metadata.txt" \
		${batchcolname} \
		"${outpath}/compinfotable.txt" \
		${strictedpropcut} \
		${strictedprevcut} \
		${outpath} \
		> ${logpath}/4.2_metagenomics.log 2>&1; then
	        if [ "${inputtype}" == "taxatable" ]; then pid="1"; else pid="5"; fi
		create_error_flag "${pid}" "Taxa Analysis" "Metagenomic analysis (4.2) failed"
	fi
	
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 4.2 completed"
	
	branch1end=$( date +%s )
	branch1time=$((branch1end - branch1start))
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 1 completed in ${branch1time}s"
	
	# Create Phase 5 success flag
	if [ "${inputtype}" == "taxatable" ]; then
	  current_phase="1"
        else
	  current_phase="5"
	fi
	create_success_flag "${current_phase}"
	
} > ${logpath}/branch1_taxa.log 2>&1 &

branch1pid=$!
# branch 1: taxa analysis$

## ^branch 2: functional prediction (parallel execution in background)
if [ "${skipfunction}" == "no" ]; then
	{
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Branch 2: Functional Prediction"
		branch2start=$( date +%s )
		
		# step 5.1: feature table generation
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 5.1: Generating feature table..."
		bash ${scriptpath}/5.1_featuretablegeneration.sh \
			${projectpath} ${funcprevcut} ${funcsizecut} ${datatype} ${analysisname} \
			> ${logpath}/5.1_featuretable.log 2>&1

		if [ $? -ne 0 ]; then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Step 5.1 failed!"
			exit 1
		fi

		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 5.1 completed"
		
		# step 5.2/5.3
		if [ "${datatype}" == "16S" ]; then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 5.2: Running PICRUSt2..."
			if ! bash ${scriptpath}/5.2_bacfunc_usingpicrust2.sh \
				${funcoutpath} ${projectname} > ${logpath}/5.2_picrust2.log 2>&1; then
				create_error_flag "6" "Functional Prediction" "PICRUSt2 (5.2) failed"
			fi
		elif [ "${datatype}" == "ITS" ]; then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 5.3: Running FUNFUN..."
			if ! bash ${scriptpath}/5.3_fungfunc_usingfunfun.sh \
				${funcoutpath} ${projectname} > ${logpath}/5.3_funfun.log 2>&1; then
				create_error_flag "6" "Functional Prediction" "FUNFUN (5.3) failed"
			fi
		fi
		
		branch2end=$( date +%s )
		branch2time=$((branch2end - branch2start))
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 2 completed in ${branch2time}s"
		
		# Create Phase 6 success flag
		create_success_flag "6"
		
	} > ${logpath}/branch2_function.log 2>&1 &
	
	branch2pid=$!
fi
# branch 2: functional prediction$

## ^wait for both branches to complete
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for parallel processes to complete..."

branch1success=FALSE
branch2success=FALSE

wait ${branch1pid}
branch1_exit=$?

if [ ${branch1_exit} -eq 0 ] && check_branch_failure "5"; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 1 (Taxa Analysis) completed successfully"
	branch1success=TRUE
	echo "Phase 5 Completed"
else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 1 (Taxa Analysis) failed"
	if [ -f "${logpath}/branch1_taxa.log" ]; then
		echo "--- Last 5 lines of branch1_taxa.log ---"
		tail -n 5 ${logpath}/branch1_taxa.log
	fi
	# Read error message if exists
	error_flag_5="${projectpath}/.phase5_error"
	if [ -f "${error_flag_5}" ]; then
		echo "Error: $(cat ${error_flag_5})"
	fi
fi

if [ "${skipfunction}" == "no" ]; then
	wait ${branch2pid}
	branch2_exit=$?
	
	if [ ${branch2_exit} -eq 0 ] && check_branch_failure "6"; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 2 (Functional Prediction) completed successfully"
		branch2success=TRUE
		echo "Phase 6 Completed"
	else
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 2 (Functional Prediction) failed"
		if [ -f "${logpath}/branch2_function.log" ]; then
			echo "--- Last 5 lines of branch2_function.log ---"
			tail -n 5 ${logpath}/branch2_function.log
		fi
		# Read error message if exists
		error_flag_6="${projectpath}/.phase6_error"
		if [ -f "${error_flag_6}" ]; then
			echo "Error: $(cat ${error_flag_6})"
		fi
	fi
else
	branch2success=TRUE
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Branch 2 (Functional Prediction) skipped"
	echo "Phase 6 Completed"
fi
# wait for both branches to complete$

## ^consolidate parameter adjustments from all sources
consolidate_parameter_adjustments() {
    local params_file="${outpath}/parameters_info.txt"
    local shell_adjustments="${projectpath}/analysis/shell_adjustments.tmp"

    # Check if there are any adjustments to consolidate
    local has_adjustments=FALSE

    # Start SECTION 2
    {
        echo ""
        echo "# [SECTION 2: ADJUSTED PARAMETERS]"
        echo "# Parameters automatically adjusted during execution"
        echo "# Format: parameter | adjusted_value | original_value | reason | timestamp"
        echo "#"
    } >> "${params_file}"

    # Process Shell Script adjustments if file exists
    if [ -f "${shell_adjustments}" ]; then
        local adj_count=1

        while IFS= read -r line; do
            if [[ "$line" == "# SHELL_ADJUSTMENT" ]]; then
                # Start new adjustment block
                echo "# ADJUSTMENT_${adj_count}" >> "${params_file}"
                echo "parameter	adjusted_value	original_value	reason	timestamp" >> "${params_file}"

                # Read next 5 lines (parameter, adjusted_value, original_value, reason, timestamp)
                read -r param_line
                read -r adjusted_line
                read -r original_line
                read -r reason_line
                read -r timestamp_line

                # Extract values
                parameter=$(echo "$param_line" | cut -d: -f2)
                adjusted_value=$(echo "$adjusted_line" | cut -d: -f2)
                original_value=$(echo "$original_line" | cut -d: -f2)
                reason=$(echo "$reason_line" | cut -d: -f2-)
                timestamp=$(echo "$timestamp_line" | cut -d: -f2-)

                # Write to parameters_info.txt
                echo -e "${parameter}\t${adjusted_value}\t${original_value}\t${reason}\t${timestamp}" >> "${params_file}"
                echo "#" >> "${params_file}"

                adj_count=$((adj_count + 1))
                has_adjustments=TRUE
            fi
        done < "${shell_adjustments}"

        # Clean up temporary file
        rm -f "${shell_adjustments}"
    fi

    # Note: R script adjustments are already appended by save_parameter_adjustments()
    # We just need to check if SECTION 2 exists
    if grep -q "\[SECTION 2: ADJUSTED PARAMETERS\]" "${params_file}"; then
        has_adjustments=TRUE
    fi

    # Add SECTION 3 summary (will be overwritten by R if R adjustments exist)
    if [ "${has_adjustments}" == "FALSE" ]; then
        {
            echo ""
            echo "# [SECTION 3: ANALYSIS SUMMARY]"
            echo "total_adjustments	0"
            echo "has_adjustments	FALSE"
        } >> "${params_file}"
    fi
}

# Call consolidation before generating summary
consolidate_parameter_adjustments
## consolidate parameter adjustments$

## ^generate summary report - [MODIFIED] Calculate full pipeline runtime
endtime=$( date +%s )

# [NEW] Try to read pipeline start time from 0.1 script
pipeline_start_file="${projectpath}/.pipeline_start_time"
if [ -f "${pipeline_start_file}" ]; then
    pipeline_starttime=$( cat "${pipeline_start_file}" )
    full_totaltime=$((endtime - pipeline_starttime))
    full_totalmin=$((full_totaltime / 60))
    full_totalsec=$((full_totaltime % 60))
    echo "[INFO] Full pipeline runtime calculated from Phase 1 start"
else
    # Fallback: use local starttime (Phase 5 only)
    full_totaltime=$((endtime - starttime))
    full_totalmin=$((full_totaltime / 60))
    full_totalsec=$((full_totaltime % 60))
    echo "[INFO] Using Phase 5-6 runtime only (no Phase 1-4 start time found)"
fi

# Also calculate Phase 5-6 runtime separately
phase56_totaltime=$((endtime - starttime))
phase56_totalmin=$((phase56_totaltime / 60))
phase56_totalsec=$((phase56_totaltime % 60))

summaryfile="${outpath}/pipeline_summary.txt"

{
	echo "=========================================="
	echo "Pipeline Execution Summary"
	echo "=========================================="
	echo ""
	echo "Analysis name     : ${analysisname}"
	echo "Execution date    : $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""
	# [MODIFIED] Show full pipeline runtime
	echo "Total runtime     : ${full_totaltime}s (${full_totalmin}m ${full_totalsec}s)"
	if [ -f "${pipeline_start_file}" ]; then
	    echo "  - Full pipeline (Phase 1-6)"
	else
	    echo "  - Analysis only (Phase 5-6)"
	fi
	echo "Phase 5-6 runtime : ${phase56_totaltime}s (${phase56_totalmin}m ${phase56_totalsec}s)"
	echo ""
	echo "Configuration:"
	echo "  Project         : ${projectname}"
	echo "  Data type       : ${datatype}"
	echo "  Group           : ${groupname}"
	echo ""
	echo "Branch status:"
	if [ "${branch1success}" == TRUE ]; then
		echo "  Taxa analysis   : SUCCESS"
	else
		echo "  Taxa analysis   : FAILED"
	fi

	if [ "${skipfunction}" == "no" ]; then
		if [ "${branch2success}" == TRUE ]; then
			echo "  Function pred   : SUCCESS"
		else
			echo "  Function pred   : FAILED"
		fi
	else
		echo "  Function pred   : SKIPPED"
	fi
	echo ""
	echo "Output files:"
	if [ "${branch1success}" == TRUE ]; then
		echo "  Taxa analysis:"
		echo "    - ${outpath}/CoMeDA.Rdata"
		echo "    - ${outpath}/${projectname}.filteredTaxaTable.species.txt"
		echo "    - ${outpath}/${projectname}.metadata.txt"
	fi

	if [ "${branch2success}" == TRUE ] && [ "${skipfunction}" == "no" ]; then
		echo "  Functional prediction:"
		if [ "${datatype}" == "16S" ]; then
			echo "    - ${funcoutpath}/picrust2_results/${projectname}.KO_abundance.txt"
			echo "    - ${funcoutpath}/picrust2_results/${projectname}.pathway_kegg.txt"
		else
			echo "    - ${funcoutpath}/funfun_results/${projectname}.KO_abundance.txt"
			echo "    - ${funcoutpath}/funfun_results/${projectname}.pathway_kegg.txt"
		fi
	fi
	echo ""
	echo "Log files (Unified path: ${logpath}):"
	echo "  - ${logpath}/4.1_taxafilter.log"
	echo "  - ${logpath}/4.2_metagenomics.log"
	if [ "${skipfunction}" == "no" ]; then
		echo "  - ${logpath}/5.1_featuretable.log"
		if [ "${datatype}" == "16S" ]; then
			echo "  - ${logpath}/5.2_picrust2.log"
		else
			echo "  - ${logpath}/5.3_funfun.log"
		fi
	fi
	echo "  - ${logpath}/branch1_taxa.log"
	if [ "${skipfunction}" == "no" ]; then
		echo "  - ${logpath}/branch2_function.log"
	fi
	echo ""
	echo "=========================================="
} > ${summaryfile}

cat ${summaryfile}
# generate summary report$

## ^[NEW] Cleanup FASTQ files to save storage space
# Only delete if analysis completed successfully
if [ "${branch1success}" == TRUE ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up FASTQ files to save storage space..."
    
    rawdata_taxafile="${projectpath}/rawdata/taxafile"
    
    if [ -d "${rawdata_taxafile}" ]; then
        # Delete FASTQ files (*.fastq, *.fq, *.gz)
        fastq_count=$(find "${rawdata_taxafile}" -type f \( -name "*.fastq" -o -name "*.fq" -o -name "*.fastq.gz" -o -name "*.fq.gz" \) 2>/dev/null | wc -l)
        
        if [ ${fastq_count} -gt 0 ]; then
            find "${rawdata_taxafile}" -type f \( -name "*.fastq" -o -name "*.fq" -o -name "*.fastq.gz" -o -name "*.fq.gz" \) -delete
            echo "[INFO] Deleted ${fastq_count} FASTQ file(s) from ${rawdata_taxafile}"
        else
            echo "[INFO] No FASTQ files found in ${rawdata_taxafile}"
        fi
    else
        echo "[INFO] rawdata/taxafile directory not found, skipping cleanup"
    fi
    
    # Clean up pipeline start time file
    if [ -f "${pipeline_start_file}" ]; then
        rm -f "${pipeline_start_file}"
        echo "[INFO] Cleaned up pipeline start time marker"
    fi
else
    echo "[WARNING] Taxa analysis failed, skipping FASTQ cleanup to allow re-analysis"
fi
## Cleanup FASTQ files$

## ^final status
if [ "${branch1success}" == TRUE ] && [ "${branch2success}" == TRUE ]; then
	echo ""
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pipeline completed successfully!"
	exit 0
else
	echo ""
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pipeline completed with errors!"
	if [ "${branch1success}" == FALSE ]; then
		echo "  - Taxa analysis failed"
	fi
	if [ "${skipfunction}" == "no" ] && [ "${branch2success}" == FALSE ]; then
		echo "  - Functional prediction failed"
	fi
	exit 1
fi
# final status$
