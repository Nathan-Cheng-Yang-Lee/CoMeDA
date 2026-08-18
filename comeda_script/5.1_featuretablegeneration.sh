#! /bin/bash

## 5.1_featuretablegeneration.sh (v3.4 - Fully Auto-Config)
## 1. Auto-detect paths: Project, Metadata, CompCol, Input Table, Output Dir
## 2. Filter taxa by Group Prevalence & Median Relative Abundance
## 3. Map filtered taxa to Reference DB (Species Level)
##    - Robust Prefix Parsing (s_, s__, S_, S__) -> Output Clean Species Name
## Date: 2025.12.03

# ==============================================================================
# 1. Parameter Setup
# ==============================================================================
# Arguments reduced to 5
projectpath=$1          # path to project root
prevcutoff=${2}    # Prevalence cutoff; default = 0.3
propcutoff=${3} # Median Relative Abundance cutoff; default = 0.0001
datatype=${4}      # 16S or ITS
analysisname=${5}       # analysis folder name (Essential for path derivation)

script_dir="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"

# ------------------------------------------------------------------------------
# Auto-Derive Variables
# ------------------------------------------------------------------------------

# 1. Project Name
projectname=$(basename "${projectpath%/}")

# 2. Output Path (Fixed Structure)
# Note: User specified "functional_prediction"
outpath="${projectpath}/analysis/${analysisname}/functional_prediction"

# 3. Metadata Path
metapath="${projectpath}/analysis/${analysisname}/${projectname}.metadata.txt"

# 4. Input Taxa Table Path (Priority: Raw > Filtered)
input_table="${projectpath}/analysis/${analysisname}/${projectname}.rawTaxaTable.species.txt"
if [ ! -f "${input_table}" ]; then
    input_table="${projectpath}/analysis/${analysisname}/${projectname}.filteredTaxaTable.species.txt"
fi

# 5. Comparison Column (Primary)
compinfo="${projectpath}/analysis/compinfotable.txt"
if [ -f "${compinfo}" ]; then
    compcol=$(head -n 1 "${compinfo}" | awk -F"\t" '{print $1}' | tr -d '\r')
else
    echo "ERROR: Comparison info file not found: ${compinfo}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Output File Definitions
# ------------------------------------------------------------------------------
intermediate_table="${outpath}/${projectname}.feature_table.stats_filtered.tsv"
final_table="${outpath}/${projectname}.feature_table.filtered.tsv"
final_fasta="${outpath}/${projectname}.rep_seqs.filtered.fna"

# ==============================================================================
# 2. Database Selection
# ==============================================================================
if [ "${datatype}" == "16S" ]; then
    ref_db="${script_dir}/greengenes2_2024.09.Species.tab.txt"
elif [ "${datatype}" == "ITS" ]; then
    ref_db="${script_dir}/unite_10_0.Species.tab.txt"
else
    echo "ERROR: Unknown datatype ${datatype}"
    exit 1
fi

# ==============================================================================
# 3. Validation
# ==============================================================================
if [ ! -f "${input_table}" ]; then
    echo "ERROR: Input Taxa Table not found: ${input_table}"
    exit 1
fi
if [ ! -f "${ref_db}" ]; then
    echo "ERROR: Reference Database not found: ${ref_db}"
    exit 1
fi
if [ ! -f "${metapath}" ]; then
    echo "ERROR: Metadata not found: ${metapath}"
    exit 1
fi
if [ -z "${compcol}" ]; then
    echo "ERROR: Comparison column not detected."
    exit 1
fi

# Prepare Output Directory
if [ -d "${outpath}" ]; then rm -rf "${outpath}"; fi
mkdir -p "${outpath}"

echo "=========================================="
echo "Phase 5.1: Feature Table Gen (v3.4)"
echo "=========================================="
echo "Project:  ${projectname}"
echo "Input:    ${input_table}"
echo "Output:   ${outpath}"
echo "Metadata: ${metapath}"
echo "Group:    ${compcol} (Primary)"
echo "Filters:  Prev >= ${prevcutoff}, Median >= ${propcutoff}"
echo "DB:       ${ref_db}"
echo "=========================================="

# ==============================================================================
# 4. Step 1: Statistical Filtering (R Module)
# ==============================================================================
echo "[Step 1] Filtering Taxa by Group Statistics..."

r_script="${outpath}/filter_taxa_logic.R"

cat <<EOF > "${r_script}"
suppressPackageStartupMessages(library(tidyverse))

# Load Parameters
input_file <- "${input_table}"
meta_file <- "${metapath}"
out_file <- "${intermediate_table}"
group_col <- "${compcol}"
prev_cut <- as.numeric("${prevcutoff}")
prop_cut <- as.numeric("${propcutoff}")

# 1. Read Data
data <- read.table(input_file, header=TRUE, sep="\t", comment.char="", check.names=FALSE)
rownames(data) <- data[,1]
data <- data[,-1]

# 2. Read Metadata
meta <- read.table(meta_file, header=TRUE, sep="\t", comment.char="", check.names=FALSE, row.names=1)

# 3. Align Samples
common_samples <- intersect(colnames(data), rownames(meta))
if(length(common_samples) == 0) stop("No common samples between table and metadata!")
data <- data[, common_samples]
meta <- meta[common_samples, , drop=FALSE]

# 4. Filter Logic
rel_data <- sweep(data, 2, colSums(data), "/")
rel_data[is.na(rel_data)] <- 0

if (!group_col %in% colnames(meta)) stop(paste("Column", group_col, "missing in metadata"))

groups <- unique(as.character(meta[[group_col]]))
keep_taxa <- c()

cat(sprintf("  Processing %d groups from '%s'...\n", length(groups), group_col))

for(g in groups) {
    g_samples <- rownames(meta)[meta[[group_col]] == g]
    g_samples <- g_samples[!is.na(g_samples)]
    if(length(g_samples) == 0) next
    
    sub_data <- rel_data[, g_samples, drop=FALSE]
    taxa_prev <- rowMeans(sub_data > 0)
    taxa_median <- apply(sub_data, 1, median)
    
    g_keep <- rownames(sub_data)[(taxa_prev >= prev_cut) & (taxa_median >= prop_cut)]
    cat(sprintf("    Group '%s': %d samples, retaining %d taxa\n", g, length(g_samples), length(g_keep)))
    keep_taxa <- union(keep_taxa, g_keep)
}

cat(sprintf("  Total unique taxa retained: %d\n", length(keep_taxa)))

if(length(keep_taxa) == 0) stop("All taxa were filtered out!")

final_data <- data[keep_taxa, , drop=FALSE]
final_data <- tibble::rownames_to_column(final_data, "Taxonomy")
write.table(final_data, out_file, sep="\t", quote=FALSE, row.names=FALSE)
EOF

Rscript "${r_script}"
if [ $? -ne 0 ]; then echo "ERROR: R filtering step failed."; exit 1; fi
rm "${r_script}"

# ==============================================================================
# 5. Step 2: Database Mapping (AWK Module)
# ==============================================================================
echo "[Step 2] Mapping features to sequences..."

awk -F"\t" -v db_file="${ref_db}" \
    -v out_fna="${final_fasta}" \
    -v out_tsv="${final_table}" '
BEGIN {
    # Phase A: Load Database (Col 1=ID, Col 3=Seq)
    print "  Loading Reference DB..." > "/dev/stderr"
    while ((getline < db_file) > 0) {
        if ($3 != "") db_seq[$1] = $3
    }
    close(db_file)
    print "  Database loaded." > "/dev/stderr"
    OFS = "\t"
    mapped_count = 0
}
# Phase B: Process
{
    if (NR == 1) {
        $1 = "#FEATURE_ID"
        print $0 > out_tsv
        next
    }
    full_taxonomy = $1
    clean_species = ""
    
    n = split(full_taxonomy, levels, ";")
    for (i in levels) {
        gsub(/^ +| +$/, "", levels[i])
        if (levels[i] ~ /^[sS]__?/) {
            clean_species = levels[i]
            sub(/^[sS]__?/, "", clean_species)
            break
        }
    }
    
    if (clean_species != "" && (clean_species in db_seq)) {
        sequence = db_seq[clean_species]
        print ">" clean_species > out_fna
        print sequence > out_fna
        $1 = clean_species
        print $0 > out_tsv
        mapped_count++
    }
}
END {
    print "  Mapping complete." > "/dev/stderr"
    print "  Final Features: " mapped_count > "/dev/stderr"
    if (mapped_count == 0) {
        print "ERROR: No features matched after mapping." > "/dev/stderr"
        exit 1
    }
}
' "${intermediate_table}"

# ==============================================================================
# 6. Cleanup
# ==============================================================================
if [ $? -eq 0 ]; then
    echo "Success! Output generated."
    rm "${intermediate_table}"
    exit 0
else
    echo "ERROR: Mapping step failed."
    exit 1
fi
