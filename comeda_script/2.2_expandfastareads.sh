#!/bin/bash

inpath=$1
samplename=$2

awk '
BEGIN { 
    seq_count = 0
    total_expanded = 0
}
/^>/ {
    # 處理序列標頭
    header = $0
    
    # 提取 size
    size = 1
    if (match(header, /size=([0-9]+)/)) {
        size_str = substr(header, RSTART, RLENGTH)
        gsub(/size=/, "", size_str)
        size = int(size_str)
    }
    
    # 清理序列 ID（移除 size 標籤和 > 符號）
    gsub(/;size=[0-9]*/, "", header)
    gsub(/^>/, "", header)
    seq_id = header
    
    # 讀取下一行（序列）
    getline sequence
    
    # 展開序列
    for (i = 1; i <= size; i++) {
        print ">" seq_id "_" i
        print sequence
        total_expanded++
    }
}
' ${inpath}/${samplename}.nochimera.formated.fasta > ${inpath}/${samplename}.final_clean.fasta

#rm ${inpath}/${samplename}.nochimera.formated.fasta
