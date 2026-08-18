#! /usr/bin/Rscript 

## metabarcoding data analysis in R
## generate on 2025.09.22
## Modified: 2025.12.06 (Added Node Info for Tooltips & Batch Method Logging)
## Modified: 2025.12.20 - Added Batch Correction v3 support

library(tidyverse)

args <- commandArgs(TRUE)

# =============================================================================
# Parameter parsing (matching 0_2_analysisresultgeneration.sh calling order)
# =============================================================================
# 0_2 calls:
#   Rscript 4.2_metagenomicanalysis.r \
#       ${filteredtable} \              # $1 = tablename
#       "${taxalevels}" \               # $2 = taxalevels
#       "${projectname}.metadata.txt" \ # $3 = metaname
#       ${batchcolname} \               # $4 = batchcolname
#       "${outpath}/compinfotable.txt" \# $5 = compinfopath
#       ${strictedpropcut} \            # $6 = strictedpropcut
#       ${strictedprevcut} \            # $7 = strictedprevcut
#       ${outpath}                      # $8 = outpath

## [2026-08-13] scriptpath 可由環境變數 COMEDA_SCRIPT_PATH 覆寫（預設＝部署版，非破壞）；
## 用於改以 review_part1/comeda_script 這份（含 pooled network 等修改）執行。
scriptpath <- Sys.getenv("COMEDA_SCRIPT_PATH", "/nfs/CoMeDA/shinyapps_v2/v2.2.250826/script")
tablename <- args[1]
taxalevels <- args[2]
taxalevels <- strsplit(taxalevels, ",")[[1]] %>% trimws()
aldexdenom <- "iqlr" 
metaname <- args[3]
batchcolname <- args[4] 
compinfopath <- args[5]
compinfotable <- read.table(compinfopath, header = T, sep = "\t")
primarycomp <- colnames(compinfotable)[1]
primarycompref <- compinfotable[[primarycomp]]
strictedpropcut <- args[6] 
strictedprevcut <- args[7] 
outpath <- args[8]
tablepath <- paste0(outpath, "/", tablename)
metapath <- paste0(outpath, "/", metaname)

source(paste0(scriptpath, "/analysis.function.R"))
source(paste0(scriptpath, "/fastCCLasso_CLR.R"))

cat("\n=== 4.2 Metagenomics Analysis ===\n")
cat("Table path:", tablepath, "\n")
cat("Metadata path:", metapath, "\n")
cat("Taxa levels:", paste(taxalevels, collapse = ", "), "\n")
cat("Batch column:", batchcolname, "\n")
cat("Output path:", outpath, "\n\n")

# Step 1: Aggregate taxatable and upload metadata
raw.taxatable <- read.table(tablepath, header = T, sep = "\t", comment.char = "", check.names = F)
colnames(raw.taxatable) <- gsub("-", ".", colnames(raw.taxatable))
agg.taxatable <- aggregate_taxa(raw.taxatable, taxalevels) %>% lapply(., function(x) round(x))
raw.metadata <- read.table(metapath, header = T, sep = "\t", comment.char = "", row.names = 1)
row.names(raw.metadata) <- row.names(raw.metadata) %>% gsub("-", ".", .)

# Step 2: CLR
set.seed(1223)
aldex.res <- lapply(agg.taxatable, function(table) {
  mat <- as.matrix(table); cond <- rep(1, ncol(mat))
  tryCatch({ ALDEx2::aldex.clr(mat, cond, mc.samples=128, denom=aldexdenom, verbose=F) },
           error=function(e) { record_parameter_adjustment("aldexdenom", "median", aldexdenom, "Failed"); ALDEx2::aldex.clr(mat, cond, mc.samples=128, denom="median", verbose=F) })
})
aldex.clr <- lapply(aldex.res, function(res) { t(sapply(ALDEx2::getMonteCarloInstances(res), function(x) apply(x, 1, median))) })
## [2026-08-12] 取 128 個 Dirichlet instance 的逐 taxa marginal median 後，逐樣本重新正規化至總和為 1
## （marginal median 不保證 closure；正規化後才是合法的相對豐度，供 median/prevalence 計算一致）。
aldex.prop <- lapply(aldex.res, function(res) {
  m <- t(sapply(ALDEx2::getDirichletInstances(res), function(x) apply(x, 1, median)))
  m / rowSums(m)
})
#set.seed(1223)
#aldex.res <- aldex.transfer.batch(agg.taxatable = agg.taxatable, metadata=raw.metadata, aldexdenom = "iqlr", mc.samples = 128, merge_mode = "union")
#aldex.clr <- aldex.res$clr
#aldex.prop <- aldex.res$prop

# Step 3: Batch Correction
#raw.metadata <- read.table(metapath, header = T, sep = "\t", comment.char = "", row.names = 1)
#row.names(raw.metadata) <- row.names(raw.metadata) %>% gsub("-", ".", .)
filtered.meta <- lapply(aldex.clr, function(clr) {left_join(x = clr %>% data.frame %>% rownames_to_column("Row.names"), y = raw.metadata %>% rownames_to_column("Row.names"), by = "Row.names") %>% column_to_rownames("Row.names") %>% dplyr::select(all_of(colnames(raw.metadata)))})

if ( batchcolname == "none" ) {
	bc.method.est <- lapply(taxalevels, function(lvl) {"nobatches"}) %>% setNames(taxalevels)
} else {
	bc.method.est <- lapply(taxalevels, function(lvl) {classify_batchtype(aldex.clr[[lvl]], filtered.meta[[lvl]], batchcolname, primarycomp)}) %>% setNames(taxalevels)
}

# [MODIFIED for v3] Handle both v3 (list) and v1 (string) return formats
batch.correct.res <- lapply(taxalevels, function(lvl) {
    bc_result <- bc.method.est[[lvl]]
    
    # Handle v3 format (list with $final_type) vs v1 format (string)
    if (is.list(bc_result) && !is.null(bc_result$final_type)) {
        # v3 format
        bctype_raw <- bc_result$final_type
    } else {
        # v1 format (string directly)
        bctype_raw <- bc_result
    }
    
    if (bctype_raw == "nobatches") {
        list(correctedTable = aldex.clr[[lvl]])
    } else {
        # Map to bctype for plsda_correction
        # v1 types: plsda.batch, splsda.batch, weighted_plsda.batch
        # v3 types: uw_plsda, uw_splsda, w_plsda, w_splsda
        
        if (bctype_raw %in% c("uw_plsda", "uw_splsda", "w_plsda", "w_splsda")) {
            # v3 format - pass directly
            bctype <- bctype_raw
        } else {
            # v1 format - convert to old bctype
            bctype <- if (bctype_raw == "plsda.batch") "balance" else if (bctype_raw == "splsda.batch") "sparse" else "unbalance"
        }
        
        res <- plsda_correction(clr=aldex.clr[[lvl]], metadata=filtered.meta[[lvl]], batchcol=batchcolname, compcol=primarycomp, compref=primarycompref, bctype=bctype)
        return(res)
    }
}) %>% setNames(taxalevels)

# Step 4: DAM
dam.res <- lapply(taxalevels, function(lvl) {
  lapply(colnames(compinfotable), function(compcol) {
    compref <- compinfotable[[compcol]]
    group.lvl <- levels(factor(filtered.meta[[lvl]][[compcol]]))
    compevent <- group.lvl[ group.lvl != compref ]
    lapply(compevent, function(evt) {
      calculate_dam(clr = batch.correct.res[[lvl]][["correctedTable"]], meta = filtered.meta[[lvl]], compcol = compcol, compcase = evt, compref = compref)
    }) %>% setNames(compevent)
  }) %>% setNames(colnames(compinfotable))
}) %>% setNames(taxalevels)

# Step 5: Correlation
agg.proptable <- aggregate_taxa(raw.taxatable, taxalevels) %>% 
	lapply(., function(table) {
		t_table <- t(table)
		common_samples <- rownames(filtered.meta[[1]]) 
		t_table_filtered <- t_table[common_samples, , drop = FALSE]
		compositions::acomp(t_table_filtered)
	})

abd_prev.res <- lapply(taxalevels, function(lvl) {
  lapply(colnames(compinfotable), function(compcol) {
    compref <- compinfotable[[compcol]]
    ## [2026-08-12] median 相對豐度與 prevalence 改由 ALDEx2 proportion（aldex.prop，Dirichlet 中位）計算，
    ## 與 CoDA-native 流程一致；原為 raw counts 的 acomp（agg.proptable）。此 abd_prev.res 同時餵
    ## edge hover 顯示與網路 prevalence 過濾（下方 taxafiltered.list），故 taxa 集合亦隨之改變（方案 A）。
    calculate_taxa_stats(prop = aldex.prop[[lvl]], meta = filtered.meta[[lvl]], compcol = compcol, compref = compref, prop_cutoff = as.numeric(strictedpropcut))
  }) %>% setNames(colnames(compinfotable))
}) %>% setNames(taxalevels)

corr.res <- lapply(taxalevels, function(lvl) {
  lapply(colnames(compinfotable), function(compcol) {
    compref <- compinfotable[[compcol]]
    group.lvl <- levels(factor(filtered.meta[[lvl]][[compcol]]))
    
    # Calculate for ALL groups (including Reference)
    compevent <- group.lvl 
    
    lapply(compevent, function(evt) {
      # 1. Filter Taxa
      prevname <- paste0("prev.", evt)
      taxafiltered.list <- abd_prev.res[[lvl]][[compcol]] %>% dplyr::filter( !!sym(prevname) >= as.numeric(strictedprevcut) ) %>% row.names(.)
     
      # 2. [UPDATED] Prepare Node Info (for Tooltips) - All Groups
      stats_df <- abd_prev.res[[lvl]][[compcol]][taxafiltered.list, , drop=FALSE]
      
      # Get all groups for this comparison column
      all_groups <- group.lvl
      
      # Base info
      node_info <- data.frame(
          taxon = rownames(stats_df),
          original_name = rownames(stats_df),
          domain = "Taxon",
          stringsAsFactors = FALSE
      )
      
      # Add prop/prev for each group
      for (grp in all_groups) {
        prop_col <- paste0("median.prop.", grp)
        prev_col <- paste0("prev.", grp)
        
        # Sanitize group name for column naming (replace spaces/special chars)
        grp_safe <- gsub("[^A-Za-z0-9]", "_", grp)
        
        node_info[[paste0("prop_", grp_safe)]] <- if (prop_col %in% colnames(stats_df)) stats_df[[prop_col]] else NA
        node_info[[paste0("prev_", grp_safe)]] <- if (prev_col %in% colnames(stats_df)) stats_df[[prev_col]] else NA
      }
      
      rownames(node_info) <- node_info$taxon 
      
      # 3. Calculate Correlation
      batch_correctedTable <- batch.correct.res[[lvl]][["correctedTable"]]
      # [per-group 2026-08-12] Subset SAMPLES to this group's (evt) samples, to
      # match the cross-domain path (6.1). Previously the within-domain network
      # was estimated on ALL pooled samples and only taxa were per-group; now the
      # correlation for group `evt` is estimated on that group's samples only.
      # [scope toggle 2026-08-13] 環境變數 COMEDA_NETWORK_SCOPE：
      #   "pergroup"(預設)＝逐組樣本；"pooled"＝全樣本（回到改動前行為，taxa 仍逐組過濾）。
      NET_SCOPE <- Sys.getenv("COMEDA_NETWORK_SCOPE", "pergroup")
      evt_samps <- rownames(filtered.meta[[lvl]])[ filtered.meta[[lvl]][[compcol]] == evt ]
      evt_samps <- intersect(evt_samps, rownames(batch_correctedTable))
      net_samps <- if (identical(NET_SCOPE, "pooled")) rownames(batch_correctedTable) else evt_samps
      clr_table <- batch_correctedTable[net_samps, colnames(batch_correctedTable) %in% taxafiltered.list, drop = FALSE] %>% as.matrix
#      clr_table <- batch.correct.res[[lvl]][["correctedTable"]][, taxafiltered.list, drop = FALSE] %>% as.matrix
      set.seed(1223)

      res_list <- tryCatch({
        # [per-group 2026-08-12] Guard: skip groups with too few samples for a
        # stable network (matches cross-domain's length(evt_samps) < 5 skip).
        # The stop() is caught below and yields an empty (all-zero) network.
        if (length(net_samps) < 5) stop("fewer than 5 samples in group; skip network")
        fastcc_result <- fastCCLasso_CLR(
          clr_data = clr_table,
          k_cv = 3,
          lam_min_ratio = 1E-4,
          k_max = 20,
          n_boot = 100
        )
        corr_matrix <- fastcc_result$correlation_matrix
        raw_p_matrix <- fastcc_result$p_values
        corr_matrix[is.na(corr_matrix)] <- 0
        raw_p_matrix[is.na(raw_p_matrix)] <- 1
        p_matrix <- adjust_fastCCLasso_pvalues(
          raw_p_matrix,
          scope = "all_pairs",
          method = "BH"
        )
        rownames(corr_matrix) <- colnames(corr_matrix) <- taxafiltered.list
        rownames(raw_p_matrix) <- colnames(raw_p_matrix) <- taxafiltered.list
        rownames(p_matrix) <- colnames(p_matrix) <- taxafiltered.list
        
        list(
            correlationTable = round(corr_matrix, 6), 
            p.value = round(p_matrix, 6),
            raw.p.value = round(raw_p_matrix, 6),
            node_info = node_info,
	    metadata = list(
              all_groups = all_groups,
              ref_group = compref,
              fastCCLasso_k_cv = 3,
              fastCCLasso_n_boot = 100,
              edge_p_adjust_method = "BH",
              edge_p_adjust_scope = "all unique taxon pairs",
              default_edge_adjusted_p_cutoff = 0.05,
              default_edge_abs_correlation_cutoff = 0.3
            )
        )
      }, error = function(e) {
        n_taxa <- length(taxafiltered.list)
        corr_matrix <- matrix(0, nrow = n_taxa, ncol = n_taxa)
        p_matrix <- matrix(1, nrow = n_taxa, ncol = n_taxa)
        raw_p_matrix <- matrix(1, nrow = n_taxa, ncol = n_taxa)
        rownames(corr_matrix) <- colnames(corr_matrix) <- taxafiltered.list
        rownames(p_matrix) <- colnames(p_matrix) <- taxafiltered.list
        rownames(raw_p_matrix) <- colnames(raw_p_matrix) <- taxafiltered.list
        
        list(
            correlationTable = round(corr_matrix, 6), 
            p.value = round(p_matrix, 6),
            raw.p.value = round(raw_p_matrix, 6),
            node_info = node_info,
	    metadata = list(
              all_groups = all_groups,
              ref_group = compref,
              fastCCLasso_k_cv = 3,
              fastCCLasso_n_boot = 100,
              edge_p_adjust_method = "BH",
              edge_p_adjust_scope = "all unique taxon pairs",
              default_edge_adjusted_p_cutoff = 0.05,
              default_edge_abs_correlation_cutoff = 0.3
            )
        )
      })
      return(res_list)
      
    }) %>% setNames(compevent)
  }) %>% setNames(colnames(compinfotable))
}) %>% setNames(taxalevels)

# Step 7: Save
if (batchcolname != "none") {
    # [MODIFIED for v3] Extract method names properly
    methods_list <- sapply(bc.method.est, function(x) {
        if (is.list(x) && !is.null(x$final_type)) {
            x$final_type
        } else {
            x
        }
    })
    methods_str <- paste(names(methods_list), methods_list, sep = "=", collapse = ", ")
    params_file <- paste0(outpath, "/parameters_info.txt")
    if(file.exists(params_file)) {
        cat(paste0("batch_correction_methods\t", methods_str, "\n"), file = params_file, append = TRUE)
    }
}

save_parameter_adjustments(outpath)
## [2026-08-12] proportion 來源標記：abd_prev.res 的 median/prevalence 由 renormalized ALDEx2 proportion 計算。
## 供 cross-domain（6.1 Mode A）載入時檢查是否為新版流程產生的 CoMeDA.Rdata。
comeda_prop_source <- "aldex.prop_renorm_v20260812"
save(raw.taxatable, agg.taxatable, aldex.clr, aldex.prop, raw.metadata, filtered.meta, batch.correct.res, dam.res, corr.res, abd_prev.res, comeda_prop_source, file = paste0(outpath, "/CoMeDA.Rdata"))

cat("\n=== Analysis Completed ===\n")
cat("Output directory:", outpath, "\n")
