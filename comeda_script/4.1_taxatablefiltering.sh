#! /bin/bash

## taxa-table pre-filtering (amount of taxa in each sample >= 5 -- sample richness, total read count in each sample >= 500 -- sample rc, sample size of each taxon from each group within the primary comparison >= 20% -- taxa prevalence)
## generate on 2025.09.22

projectpath=$1
outname=$2
outpath="${projectpath}/analysis/${outname}"
prefixname=$3
rawtaxatable="${projectpath}/analysis/preTaxaTable/rawTaxaTable/${prefixname}.rawTaxaTable.txt" ## sample in columns
metadata="${projectpath}/analysis/preTaxaTable/metadatafiles/${prefixname}.metadata.txt"
groupname=$4
groupcolno=$( head -n 1 ${metadata} | datamash transpose | awk -v groupname="${groupname}" '{if($1 == groupname) print NR}' )
samplerichcut=$5 # default : 5
samplerccut=$6 # default : 500
taxaprevcut=$7 # default : 20% -> 0.2
inputtype=$8 # from sequencing or taxatable

#if [ -d ${outpath} ]; then
#	rm -r ${outpath}
#fi
#mkdir -p ${outpath}

# ^get files from preTaxaTable folder
awk -F";" '{if(NR == 1 || NF == 7) print}' ${rawtaxatable} > ${outpath}/${prefixname}.rawTaxaTable.species.txt
cp ${metadata} ${outpath}/${prefixname}.metadata.txt
sptaxatable="${outpath}/${prefixname}.rawTaxaTable.species.txt"
# get files from preTaxaTable folder$

# ^sample richness & readcount filtering
totalncols=$( awk -F"\t" '{if(NR == 1) print NF}' ${sptaxatable} )
if [ ${inputtype} == "sequencing" ]; then
	firstcol=3
elif [ ${inputtype} == "taxatable" ]; then
	firstcol=2
fi
for samplencol in $( seq ${firstcol} ${totalncols} )
do
	rcinsample=$( sed '1d' ${sptaxatable} | datamash sum ${samplencol})
	ntaxainsamp=$( awk -F"\t" -v samplencol=${samplencol} '{if($samplencol > 0) count++}END{print count}' ${sptaxatable} )
	if [[ ${ntaxainsamp} -lt ${samplerichcut} || ${rcinsample} -lt ${samplerccut} ]]; then
		echo "${samplencol}" >> ${outpath}/sampleremoval.tmp
	fi
done

if [ -f ${outpath}/sampleremoval.tmp ]; then
	samplecutncol=$(awk '{printf("%s,", $1)}' ${outpath}/sampleremoval.tmp | sed 's/,$/\n/g' )
	if [ ${inputtype} == "sequencing" ]; then
		cut -f 2,${samplecutncol} --complement ${sptaxatable} > ${outpath}/${prefixname}.samplerichness.tmp
	elif [ ${inputtype} == "taxatable" ]; then
		cut -f ${samplecutncol} --complement ${sptaxatable} > ${outpath}/${prefixname}.samplerichness.tmp
	fi
else
	if [ ${inputtype} == "sequencing" ]; then
		cut -f 2 --complement ${sptaxatable} > ${outpath}/${prefixname}.samplerichness.tmp
	elif [ ${inputtype} == "taxatable" ]; then
		cp ${sptaxatable} ${outpath}/${prefixname}.samplerichness.tmp
	fi
fi
# sample richness & readcount filtering$

# ^taxa prevalence filtering
head -n 1 ${outpath}/${prefixname}.samplerichness.tmp | datamash transpose > ${outpath}/${prefixname}.sampleposition.tmp
for groupevent in $( cut -f ${groupcolno} ${metadata} | sed '1d' | sort | uniq )
do
	groupsamples=$( awk -F"\t" -v groupcolno=${groupcolno} -v groupevent=${groupevent} '{if($groupcolno == groupevent) printf("%s\\|", $1)}' ${metadata} | sed 's/\\|$/\n/g' )
	samplepos=$( grep -nw "${groupsamples}" ${outpath}/${prefixname}.sampleposition.tmp | cut -d":" -f 1 | awk '{printf("%s,", $1)}' | sed 's/,$/\n/g' )
	cut -f 1,${samplepos} ${outpath}/${prefixname}.samplerichness.tmp | sed '1d' > ${outpath}/${groupevent}.taxatable.tmp
	groupsampcut=$( awk -F"\t" -v taxaprevcut=${taxaprevcut} '{if(NR == 1) printf("%d", (NF - 1) * taxaprevcut + 1)}' ${outpath}/${groupevent}.taxatable.tmp )
	awk -F"\t" -v groupsampcut=${groupsampcut} '{count = 0; for (i = 2; i <= NF; i++) if($i > 0) count++; if (count >= groupsampcut) print $1}' ${outpath}/${groupevent}.taxatable.tmp >> ${outpath}/${prefixname}.taxalist.tmp
done
sort ${outpath}/${prefixname}.taxalist.tmp | uniq > ${outpath}/${prefixname}.taxalist.unique.tmp
awk 'NR==FNR{ids[$1]=1; next} FNR==1 || $1 in ids' ${outpath}/${prefixname}.taxalist.unique.tmp ${outpath}/${prefixname}.samplerichness.tmp > ${outpath}/${prefixname}.filteredTaxaTable.species.txt
# taxa prevalence filtering$

rm ${outpath}/*.tmp
