#! /bin/bash

fapath=$1 ## path / ref fasta file (.fa, .fasta, .fna)
taxapath=$2 ## path / taxa table (.txt, .tsv); 2 columns (taxa.id \t taxa name)
dbpath=$3 ## path / dbname
metabctype=$4 ## 16S / ITS
dbname=$( echo "${dbpath}" | rev | cut -d"/" -f 1 | rev )
scriptpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script"
toolpath="/nfs/CoMeDA/shinyapps_v2/v2.2.250826/tools/kraken2/scripts_new/build_gg_taxonomy.pl"

if [ -d ${dbpath} ]; then
	rm -r ${dbpath}
fi
mkdir -p ${dbpath}/data ${dbpath}/taxonomy ${dbpath}/library

# ^check taxa name
python ${scriptpath}/3.4_transfergg2unclassified.py --in_taxonomy ${taxapath} --out_txt ${dbpath}/data/${dbname}.tax.tmp
sort -k2,2b ${dbpath}/data/${dbname}.tax.tmp > ${dbpath}/data/${dbname}.tax.sorted.txt
rm ${dbpath}/data/${dbname}.tax.tmp
# check taxa name$

# ^generate required files
${toolpath} ${dbpath}/data/${dbname}.tax.sorted.txt
mv names.dmp nodes.dmp ${dbpath}/taxonomy
mv seqid2taxid.map ${dbpath}/
cp ${fapath} ${dbpath}/library/${dbname}.fna
# generate required files$

# ^generate kraken2 & braken db
kraken2-build --build --db ${dbpath}
if [ ${metabctype} == "16S" ]; then
	for lib in 300 1600
	do
		bracken-build --db ${dbpath} -l ${lib}
	done
elif [ ${metabctype} == "ITS" ]; then
	for lib in 300 400 600 800
	do
		bracken-build --db ${dbpath} -l ${lib}
	done
fi
# generate kraken2 & braken db$
