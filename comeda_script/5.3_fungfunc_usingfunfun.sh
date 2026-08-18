#! /bin/bash

## run FUNFUN for ITS functional prediction
## integrate with feature table from 5.1_featuretablegeneration.sh
## generate on 2025.10.14

inpath=$1
prefixname=$2
refpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"
rscript_path="${refpath}/5.5_its_function_calc.r"

## create output directory
mkdir -p ${inpath}/temp

## check input files
rep_seqs="${inpath}/${prefixname}.rep_seqs.filtered.fna"
feature_table="${inpath}/${prefixname}.feature_table.filtered.tsv"

if [ ! -f ${rep_seqs} ]; then
	echo "ERROR: Representative sequences not found: ${rep_seqs}"
	exit 1
fi

if [ ! -f ${feature_table} ]; then
	echo "ERROR: Feature table not found: ${feature_table}"
	exit 1
fi

if [ ! -f ${rscript_path} ]; then
	echo "ERROR: R script not found: ${rscript_path}"
	exit 1
fi

echo "=========================================="
echo "Running FUNFUN for ITS functional prediction"
echo "Input path: ${inpath}"
echo "Prefix name: ${prefixname}"
echo "R script: ${rscript_path}"
echo "=========================================="

## ^process ITS sequences for FUNFUN
echo ""
echo "Step 1: Processing ITS sequences..."

# convert IUPAC ambiguous codes to standard bases
# R→A, Y→C, M→A, K→G, S→C, W→A, H→A, B→C, V→A, D→A, N→A
awk '{
	if ($0 ~ /^>/) {
		print $0
	} else {
		seq = toupper($0)
		gsub(/R/, "A", seq)
		gsub(/Y/, "C", seq)
		gsub(/M/, "A", seq)
		gsub(/K/, "G", seq)
		gsub(/S/, "C", seq)
		gsub(/W/, "A", seq)
		gsub(/H/, "A", seq)
		gsub(/B/, "C", seq)
		gsub(/V/, "A", seq)
		gsub(/D/, "A", seq)
		gsub(/N/, "A", seq)
		print seq
	}
}' ${rep_seqs} > ${inpath}/temp/${prefixname}.processed.fasta

echo "  Processed sequences: ${inpath}/temp/${prefixname}.processed.fasta"
echo "Step 1 completed."
## process ITS sequences for FUNFUN$

## ^run FUNFUN
echo ""
echo "Step 2: Running FUNFUN..."

funfun -its ${inpath}/temp/${prefixname}.processed.fasta \
       -type concatenate \
       -out ${inpath}/funfun_res

if [ $? -ne 0 ]; then
	echo "ERROR: FUNFUN execution failed!"
	exit 1
fi

echo "  FUNFUN results: ${inpath}/funfun_res/Results.tsv"
echo "Step 2 completed."
## run FUNFUN$

## ^extract pathway information from FUNFUN results
echo ""
echo "Step 3: Extracting pathway information..."

# extract lines with pathway information (containing " [PATH:")
awk -F"\t" '{if($1 ~ " \\[PATH:" || NR == 1) print}' \
	${inpath}/funfun_res/Results.tsv > \
	${inpath}/temp/${prefixname}.results.path.tmp

# parse pathway IDs and create pathway × ASV matrix
cut -f 1 ${inpath}/temp/${prefixname}.results.path.tmp | \
	sed '1d' | \
	cut -d" " -f 2- | \
	sed -e 's/ \[PATH:/\t/g' -e 's/\]$//g' | \
	awk -F"\t" '{print $2}' | \
	sed '1ipathway.id' | \
	paste - ${inpath}/temp/${prefixname}.results.path.tmp | \
	cut -f 2 --complement | \
	datamash transpose | \
        sed -e '/\t$/d'	> ${inpath}/temp/${prefixname}.results.path.transpose.tmp

# sort by pathway ID
(head -n 1 ${inpath}/temp/${prefixname}.results.path.transpose.tmp && \
 tail -n +2 ${inpath}/temp/${prefixname}.results.path.transpose.tmp | sort -k1,1b) | \
 datamash transpose > ${inpath}/temp/${prefixname}.path_asv_matrix.txt

echo "  Pathway × ASV matrix created: ${inpath}/temp/${prefixname}.path_asv_matrix.txt"
echo "Step 3 completed."
## extract pathway information from FUNFUN results$

## ^sort feature table to match FUNFUN output
echo ""
echo "Step 4: Preparing feature table..."

# sort feature table by ASV ID (column 1)
(head -n 1 ${feature_table} && \
 sed '1d' ${feature_table} | sort -k1,1b) | sed 's/^#//g' > \
 ${inpath}/temp/${prefixname}.feature_table.sorted.tmp

echo "  Sorted feature table: ${inpath}/temp/${prefixname}.feature_table.sorted.tmp"
echo "Step 4 completed."
## sort feature table to match FUNFUN output$

## ^calculate pathway abundance using matrix multiplication
echo ""
echo "Step 5: Calculating pathway abundance..."

${rscript_path} \
	${inpath}/temp/${prefixname}.path_asv_matrix.txt \
	${inpath}/temp/${prefixname}.feature_table.sorted.tmp \
	${inpath}/temp/${prefixname}.pathway.tmp

if [ $? -ne 0 ]; then
	echo "ERROR: R script execution failed!"
	exit 1
fi

echo "  Pathway abundance calculated: ${inpath}/temp/${prefixname}.pathway.tmp"
echo "Step 5 completed."
## calculate pathway abundance using matrix multiplication$

## ^join with pathway annotations
echo ""
echo "Step 6: Adding pathway annotations..."

# check if pathway index file exists
pathway_idx="${refpath}/pathway.idx.forITS.txt"
if [ ! -f ${pathway_idx} ]; then
	echo "WARNING: Pathway index file not found: ${pathway_idx}"
	echo "Skipping pathway annotation step."
	cp ${inpath}/temp/${prefixname}.pathway.tmp \
	   ${inpath}/${prefixname}.pathway_kegg.txt
else
	# sort pathway table and join with annotations
	(head -n 1 ${inpath}/temp/${prefixname}.pathway.tmp && \
	 sed '1d' ${inpath}/temp/${prefixname}.pathway.tmp | sort -k1,1b) | \
	 join -1 1 -2 1 ${pathway_idx} - --header | \
	 sed 's/ /\t/g' | \
	 cut -f 2- > ${inpath}/temp/${prefixname}.pathway.joined.tmp
	
	# final sort
	(head -n 1 ${inpath}/temp/${prefixname}.pathway.joined.tmp && \
	 sed '1d' ${inpath}/temp/${prefixname}.pathway.joined.tmp | sort -k1,1b) > \
	 ${inpath}/${prefixname}.pathway_kegg.txt
	
	echo "  Pathway annotations added"
fi

echo "  Final pathway abundance table: ${inpath}/${prefixname}.pathway_kegg.txt"
echo "Step 6 completed."
## join with pathway annotations$

## ^clean up intermediate files
echo ""
echo "Cleaning up intermediate files..."
rm -rf ${inpath}/temp
echo "Cleanup completed."
## clean up intermediate files$

## ^summary
echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Output files:"
echo "  1. ${inpath}/${prefixname}.KO_abundance.txt"
echo "  2. ${inpath}/${prefixname}.pathway_kegg.txt"
echo "=========================================="
## summary$

echo ""
echo "Done!"
