#! /bin/bash

## run PICRUSt2 for 16S functional prediction, process results, and convert KO to KEGG pathway
## generate on 2025.10.14

inpath=$1
projectname=$2
threads=4
scriptpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"
rscript_path="${scriptpath}/5.4_picrustko2kegg_pathway.r"
keggrefpath="${scriptpath}/pathway.idx.for16S.txt"

## check input files
rep_seqs="${inpath}/${projectname}.rep_seqs.filtered.fna"
input_table="${inpath}/${projectname}.feature_table.filtered.tsv"

echo "=========================================="
echo "Running PICRUSt2 for 16S functional prediction"
echo "Input path: ${inpath}"
echo "Project name: ${projectname}"
echo "R script: ${rscript_path}"
echo "Threads: ${threads}"
echo "=========================================="

## ^run PICRUSt2 pipeline
echo ""
echo "Starting PICRUSt2 pipeline..."
echo "This may take several hours depending on data size..."
echo ""

picrust2_pipeline.py -s ${rep_seqs} -i ${input_table} -o ${inpath}/picrust2.res -p ${threads} --no_pathways --max_nsti 0.5

## run PICRUSt2 pipeline$

## ^check PICRUSt2 execution status
if [ $? -ne 0 ]; then
	echo ""
	echo "ERROR: PICRUSt2 failed!"
	echo "Please check error messages above."
	exit 1
fi

echo ""
echo "=========================================="
echo "PICRUSt2 completed successfully!"
echo "=========================================="
## check PICRUSt2 execution status$

## ^process KO predictions
echo ""
echo "Processing KO predictions..."

if [ -f ${inpath}/picrust2.res/KO_metagenome_out/pred_metagenome_unstrat.tsv.gz ]; then
	gunzip -c ${inpath}/picrust2.res/KO_metagenome_out/pred_metagenome_unstrat.tsv.gz | \
		sed 's/ko://g' > ${inpath}/${projectname}.KO_abundance.txt
	echo "  KO abundance table created: ${inpath}/${projectname}.KO_abundance.txt"
else
	echo "  WARNING: KO predictions not found"
fi

## ^convert KO to KEGG pathway
echo ""
echo "=========================================="
echo "Converting KO to KEGG pathway"
echo "=========================================="
echo ""

if [ -f ${inpath}/${projectname}.KO_abundance.txt ]; then
	echo "Running KO to KEGG pathway conversion..."
	
	${rscript_path} ${inpath}/${projectname}.KO_abundance.txt ${inpath}/${projectname}.ko2kegg.tmp
	
	if [ $? -ne 0 ]; then
		echo ""
		echo "ERROR: R script execution failed!"
		exit 1
	fi
	
	echo "  Intermediate file created: ${inpath}/${projectname}.ko2kegg.tmp"
	
	echo ""
	echo "Formatting pathway abundance table..."
	
	# sort by pathway ID
	(head -n 1 ${inpath}/${projectname}.ko2kegg.tmp && sed '1d' ${inpath}/${projectname}.ko2kegg.tmp | sort -k1,1b) | join -1 1 -2 1 ${keggrefpath} - --header | sed 's/ /\t/g' | cut -f 2- > ${inpath}/${projectname}.pathway_kegg.txt
	
	echo "  Pathway abundance table created: ${inpath}/${projectname}.pathway_kegg.txt"
	
	echo ""
	echo "Cleaning up intermediate files..."
	rm ${inpath}/${projectname}.ko2kegg.tmp
	echo "  Removed: ${inpath}/${projectname}.ko2kegg.tmp"
else
	echo "WARNING: KO abundance table not found. Skipping KO to KEGG conversion."
fi

## convert KO to KEGG pathway$

echo "Done!"
