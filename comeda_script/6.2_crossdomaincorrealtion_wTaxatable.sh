#! /bin/bash

workdir=$1
table_16s=$2; meta_16s=$3
table_its=$4; meta_its=$5
comp_info_file=$6
taxalevel=$7
prev_bac=$8
prev_fun=$9
prop_cut=${10}

scriptpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"
prep_script="${scriptpath}/6.3_prepare_data_for_crossdomain.r"
anal_script="${scriptpath}/6.1_crossdomaincorrelation_wReport.r"

mkdir -p "${workdir}/prep_16S"
mkdir -p "${workdir}/prep_ITS"

# Step 1: Prep 16S
Rscript ${prep_script} "${table_16s}" "${meta_16s}" "${comp_info_file}" "${taxalevel}" "${workdir}/prep_16S" "16S" "${prop_cut}" "batches" "${workdir}/batch_methods_16s.txt" "${scriptpath}"
if [ $? -ne 0 ]; then echo "Error preparing 16S data"; exit 1; fi

# Step 2: Prep ITS
Rscript ${prep_script} "${table_its}" "${meta_its}" "${comp_info_file}" "${taxalevel}" "${workdir}/prep_ITS" "ITS" "${prop_cut}" "batches" "${workdir}/batch_methods_its.txt" "${scriptpath}"
if [ $? -ne 0 ]; then echo "Error preparing ITS data"; exit 1; fi

cat "${workdir}/batch_methods_16s.txt" "${workdir}/batch_methods_its.txt" > "${workdir}/batch_methods.txt" 2>/dev/null

# Step 3: Analysis
Rscript ${anal_script} "${scriptpath}" "${workdir}/prep_16S/CoMeDA.Rdata" "${workdir}/prep_ITS/CoMeDA.Rdata" "${taxalevel}" "${prev_bac}" "${prev_fun}" "${comp_info_file}" "${workdir}"

echo "Done."
