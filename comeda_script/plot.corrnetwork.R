## =======================================================================================
## function name : plot_interactive_networks
## description : create network(s) from corr.res using ggraph (including cross-dataset)
## layout_type : "fr", "kk", "nicely", "graphopt", "grid", "circle"
## ptype : which edge p-value to threshold on, "raw" (raw.p.value) or "adjusted" (BH p.value); default "raw"
## pcut : cutoff applied to the selected edge p-value (default: 0.05)
## corrcut : minimum absolute correlation for displayed edges (default: 0.3)
## Updated: 2025.12.15 (Support Paired Analysis with DS1_/DS2_ prefix, show original names)
## =======================================================================================

plot_interactive_networks <- function(corr_res, taxalevel, compcol, compevent, pcut = 0.05, corrcut = 0.3, layout_type = "fr", show_labels = TRUE, labelsize = 3, hubdegree = 12, focal_taxon = NULL, toptaxa = NULL, unified_layout = TRUE, show_legend = TRUE, analysis_type = "within_domain", ptype = "raw") {

        require(ggraph); require(igraph); require(patchwork); require(scales); require(ggrepel)
        require(ggiraph)

        if (!analysis_type %in% c("within_domain", "cross_domain")) stop("Invalid analysis_type")

        ## Edge p-value type: "raw" -> raw.p.value, "adjusted" -> BH-adjusted p.value (2026-08-11)
        ptype <- match.arg(ptype, c("raw", "adjusted"))
        pfield <- if (ptype == "adjusted") "p.value" else "raw.p.value"
        ## Backward compatible: older result objects may lack raw.p.value -> fall back to p.value
        get_pmat <- function(node) {
                m <- node[[pfield]]
                if (is.null(m)) m <- node[["p.value"]]
                m
        }

        comeda.colors <- c("steelblue", "tomato", "forestgreen", "darkorange", "darkslateblue", "firebrick", "mediumseagreen", "goldenrod", "slateblue", "darkgray", "dodgerblue", "lightgreen", "sienna", "blueviolet", "darkcyan", "salmon", "moccasin", "chocolate", "orchid", "cornflowerblue", "indianred", "darkolivegreen", "plum", "royalblue", "red", "seagreen", "peru", "slategray", "navy", "hotpink", "limegreen", "mediumvioletred", "orange", "#e5505a", "#6caddf", "#ffc600", "#9fc54d", "#a560e8", "#D0B3A3", "#fe5000", "#a93c3b", "#0057b8", "#00b140", "#4e2a84", "#B78B6E", "#ff9933", "#e0393e", "#1fbad6", "#00af87", "#694d88", "#767676", "#f58268", "#f4979c", "#007fae", "#578230", "#BDACE5", "#000075", "#1fbad6")

        all_taxa <- unique(unlist(lapply(compevent, function(evt) {
                if(is.null(corr_res[[taxalevel]][[compcol]][[evt]])) return(NULL)
                rownames(corr_res[[taxalevel]][[compcol]][[evt]]$correlationTable)
        })))
        if(length(all_taxa) == 0) return(NULL)
        
        color_indices <- ((seq_along(all_taxa) - 1) %% length(comeda.colors)) + 1
        taxa_color_map <- setNames(comeda.colors[color_indices], all_taxa)

        unified_layout_coords <- NULL; unified_degree_range <- NULL; unified_corr_range <- NULL

        # Calc unified scales
        if (length(compevent) > 1) {
                all_degrees <- c(); all_corrs <- c()
                for (evt in compevent) {
                        if(is.null(corr_res[[taxalevel]][[compcol]][[evt]])) next
                        cor_mat <- corr_res[[taxalevel]][[compcol]][[evt]]$correlationTable
                        pval_mat <- get_pmat(corr_res[[taxalevel]][[compcol]][[evt]])
                        sig_mask <- (pval_mat < pcut) & (abs(cor_mat) >= corrcut); sig_mask[is.na(sig_mask)] <- FALSE
                        adj_mat <- cor_mat * sig_mask; diag(adj_mat) <- 0; adj_mat[is.na(adj_mat)] <- 0
                        g_temp <- igraph::graph_from_adjacency_matrix(abs(adj_mat), mode="undirected", weighted=TRUE, diag=FALSE)
                        if (igraph::vcount(g_temp) > 0) {
                                iso <- which(igraph::degree(g_temp) == 0); if(length(iso)>0) g_temp <- igraph::delete_vertices(g_temp, iso)
                                if (igraph::vcount(g_temp) > 0) {
                                        all_degrees <- c(all_degrees, igraph::degree(g_temp))
                                        valid_corr <- abs(cor_mat[sig_mask]); all_corrs <- c(all_corrs, valid_corr[!is.na(valid_corr) & valid_corr != 0])
                                }
                        }
                }
                if (length(all_degrees) > 0) unified_degree_range <- range(all_degrees)
                if (length(all_corrs) > 0) unified_corr_range <- range(all_corrs)
        }

        # Calc unified layout
        if (unified_layout && length(compevent) > 1) {
                combined_cor <- matrix(0, nrow=length(all_taxa), ncol=length(all_taxa), dimnames=list(all_taxa, all_taxa))
                combined_pval <- matrix(1, nrow=length(all_taxa), ncol=length(all_taxa), dimnames=list(all_taxa, all_taxa))
                for (evt in compevent) {
                        if(is.null(corr_res[[taxalevel]][[compcol]][[evt]])) next
                        c_mat <- corr_res[[taxalevel]][[compcol]][[evt]]$correlationTable
                        p_mat <- get_pmat(corr_res[[taxalevel]][[compcol]][[evt]])
                        valid_taxs <- intersect(rownames(c_mat), all_taxa)
                        if(length(valid_taxs) > 0) {
                             for (i in valid_taxs) { for (j in valid_taxs) {
                                     if (!is.na(c_mat[i,j])) {
                                             if (is.na(combined_cor[i,j]) || abs(c_mat[i,j]) > abs(combined_cor[i,j])) {
                                                     combined_cor[i,j] <- c_mat[i,j]; combined_pval[i,j] <- p_mat[i,j]
                                             }
                                     }
                             }}
                        }
                }
                sig_mask <- (combined_pval < pcut) & (abs(combined_cor) >= corrcut); sig_mask[is.na(sig_mask)] <- FALSE
                c_adj <- combined_cor * sig_mask; diag(c_adj) <- 0; c_adj[is.na(c_adj)] <- 0
                g_combined <- igraph::graph_from_adjacency_matrix(abs(c_adj), mode="undirected", weighted=TRUE, diag=FALSE)
                if (igraph::vcount(g_combined) > 0) {
                        iso <- which(igraph::degree(g_combined) == 0); if(length(iso)>0) g_combined <- igraph::delete_vertices(g_combined, iso)
                }
                if (igraph::vcount(g_combined) > 0) {
                        set.seed(123)
                        l_mat <- ggraph::create_layout(g_combined, layout = layout_type)
                        unified_layout_coords <- data.frame(name=l_mat$name, x=l_mat$x, y=l_mat$y, stringsAsFactors=F)
                }
        }

        plot_list <- list()

        for (evt in compevent) {
                if(is.null(corr_res[[taxalevel]][[compcol]][[evt]])) next
                cor_mat <- corr_res[[taxalevel]][[compcol]][[evt]]$correlationTable
                pval_mat <- get_pmat(corr_res[[taxalevel]][[compcol]][[evt]])

                # Retrieve Node Info
                node_info <- corr_res[[taxalevel]][[compcol]][[evt]]$node_info
                metadata <- corr_res[[taxalevel]][[compcol]][[evt]]$metadata

                # [NEW v2.3] Detect analysis mode and get taxa lists
                is_paired <- FALSE
                ds1_taxa <- NULL; ds2_taxa <- NULL
                ds1_name_map <- NULL; ds2_name_map <- NULL
                
                if (analysis_type == "cross_domain" && !is.null(metadata)) {
                  # Check for new format (v2.3+)
                  if (!is.null(metadata$is_paired_analysis)) {
                    is_paired <- metadata$is_paired_analysis
                  }
                  
                  # Get taxa lists (use new names if available, fallback to old)
                  ds1_taxa <- if (!is.null(metadata$ds1_taxa)) metadata$ds1_taxa else metadata$bacteria_taxa
                  ds2_taxa <- if (!is.null(metadata$ds2_taxa)) metadata$ds2_taxa else metadata$fungi_taxa
                  
                  # Get name mappings (for Paired Analysis)
                  ds1_name_map <- metadata$ds1_name_map
                  ds2_name_map <- metadata$ds2_name_map
                }

                sig_mask <- (pval_mat < pcut) & (abs(cor_mat) >= corrcut); sig_mask[is.na(sig_mask)] <- FALSE
                adj_mat <- cor_mat * sig_mask; diag(adj_mat) <- 0; adj_mat[is.na(adj_mat)] <- 0
                g <- igraph::graph_from_adjacency_matrix(abs(adj_mat), mode="undirected", weighted=TRUE, diag=FALSE)

                if (igraph::ecount(g) == 0) {
                        plot_list[[evt]] <- ggplot() + annotate("text", x=0.5, y=0.5, label="No significant correlations", size=6) + theme_void() + ggtitle(paste(taxalevel, compcol, evt, sep=" - "))
                        next
                }

                if (analysis_type == "cross_domain") {
                        e_df <- igraph::as_data_frame(g, what="edges")
                        
                        # [UPDATED v2.3] Support multiple detection methods
                        if (!is.null(ds1_taxa) && !is.null(ds2_taxa)) {
                          # Use metadata taxa lists
                          f_ds1 <- e_df$from %in% ds1_taxa
                          t_ds1 <- e_df$to %in% ds1_taxa
                        } else {
                          # Fallback: detect by prefix (DS1_, DS2_) or legacy (bac_)
                          f_ds1 <- grepl("^DS1_", e_df$from) | grepl("^bac_", e_df$from)
                          t_ds1 <- grepl("^DS1_", e_df$to) | grepl("^bac_", e_df$to)
                        }
                        
                        cross <- (f_ds1 & !t_ds1) | (!f_ds1 & t_ds1)
                        if (sum(cross) == 0) {
                                plot_list[[evt]] <- ggplot() + annotate("text", x=0.5, y=0.5, label="No cross-dataset correlations", size=6) + theme_void() + ggtitle(paste(taxalevel, compcol, evt, sep=" - "))
                                next
                        }
                        g <- igraph::subgraph.edges(g, which(cross), delete.vertices=FALSE)
                }

                if (!is.null(toptaxa) && toptaxa > 0) {
                        node_names <- igraph::V(g)$name
                        str <- sapply(1:length(node_names), function(i) { ie <- igraph::incident(g, i); if(length(ie)==0) return(0); sum(igraph::E(g)$weight[ie]) })
                        if (toptaxa < length(node_names)) g <- igraph::induced_subgraph(g, order(str, decreasing=TRUE)[1:min(toptaxa, length(node_names))])
                        if (igraph::ecount(g) == 0) { plot_list[[evt]] <- ggplot() + annotate("text", x=0.5, y=0.5, label="No correlations after Top N", size=6) + theme_void() + ggtitle(paste(taxalevel, compcol, evt, sep=" - ")); next }
                }

                iso <- which(igraph::degree(g) == 0); if(length(iso) > 0) g <- igraph::delete_vertices(g, iso)
                if (igraph::vcount(g) == 0) { plot_list[[evt]] <- ggplot() + annotate("text", x=0.5, y=0.5, label="No connected taxa", size=6) + theme_void() + ggtitle(paste(taxalevel, compcol, evt, sep=" - ")); next }

                # [UPDATED v2.5] Enhanced Tooltip with all selected groups
                # Get all groups from metadata (for tooltip display)
                all_groups <- if (!is.null(metadata$all_groups)) metadata$all_groups else compevent
                
                # Helper function: format percentage with threshold
                format_pct <- function(val) {
                  if (is.na(val)) return("N/A")
                  pct <- val * 100
                  if (pct < 0.0001) return("< 0.0001%")
                  return(sprintf("%.4f%%", pct))
                }

                igraph::V(g)$tooltip <- sapply(igraph::V(g)$name, function(nm) {
                  original_nm <- nm
                  source_label <- "Unknown"

                  if (!is.null(node_info) && nm %in% rownames(node_info)) {
                    info <- node_info[nm, ]
                    
                    if ("original_name" %in% colnames(node_info) && !is.na(info$original_name)) {
                      original_nm <- info$original_name
                    }
                    source_label <- info$domain

                    # Build stats section for selected events only
                    abund_lines <- c()
                    prev_lines <- c()
                    
                    for (grp in compevent) {
                      grp_safe <- gsub("[^A-Za-z0-9]", "_", grp)
                      prop_col <- paste0("prop_", grp_safe)
                      prev_col <- paste0("prev_", grp_safe)
                      
                      # Check if columns exist (backward compatibility)
                      if (prop_col %in% colnames(node_info)) {
                        abund_lines <- c(abund_lines, paste0("&nbsp;&nbsp;", grp, ": ", format_pct(info[[prop_col]])))
                      }
                      if (prev_col %in% colnames(node_info)) {
                        prev_lines <- c(prev_lines, paste0("&nbsp;&nbsp;", grp, ": ", format_pct(info[[prev_col]])))
                      }
                    }
                    
                    # Fallback for old data format (prop_case/prop_ref)
                    if (length(abund_lines) == 0 && "prop_case" %in% colnames(node_info)) {
                      ref_label <- if (!is.null(metadata$ref_group)) metadata$ref_group else "Control"
                      abund_lines <- c(
                        paste0("&nbsp;&nbsp;", ref_label, ": ", format_pct(info$prop_ref)),
                        paste0("&nbsp;&nbsp;", evt, ": ", format_pct(info$prop_case))
                      )
                      prev_lines <- c(
                        paste0("&nbsp;&nbsp;", ref_label, ": ", format_pct(info$prev_ref)),
                        paste0("&nbsp;&nbsp;", evt, ": ", format_pct(info$prev_case))
                      )
                    }

                    paste0(
                      "<b>Taxon:</b> ", original_nm, "<br>",
                      "<b>Source:</b> ", source_label, "<br>",
                      "<hr style='margin: 5px 0; border-color: #ccc;'>",
                      "<b style='color: #666;'>Median Rel. Abund.</b><br>",
                      paste(abund_lines, collapse = "<br>"), "<br>",
                      "<br>",
                      "<b style='color: #666;'>Prevalence</b><br>",
                      paste(prev_lines, collapse = "<br>")
                    )
                  } else {
                    if (grepl("^DS1_", nm)) {
                      original_nm <- sub("^DS1_", "", nm)
                      source_label <- "Dataset1"
                    } else if (grepl("^DS2_", nm)) {
                      original_nm <- sub("^DS2_", "", nm)
                      source_label <- "Dataset2"
                    }
                    paste0("<b>Taxon:</b> ", original_nm, "<br><b>Source:</b> ", source_label)
                  }
                })

                if (!is.null(focal_taxon)) {
                        if (!focal_taxon %in% igraph::V(g)$name) {
                                warning(paste("Focal taxon", focal_taxon, "not found")); focal_related <- rep(FALSE, igraph::vcount(g)); igraph::E(g)$is_focal <- rep(FALSE, igraph::ecount(g))
                        } else {
                                fv <- which(igraph::V(g)$name == focal_taxon); nbs <- igraph::neighbors(g, fv)
                                focal_related <- 1:igraph::vcount(g) %in% c(fv, nbs)
                                el <- igraph::ends(g, igraph::E(g), names=FALSE)
                                igraph::E(g)$is_focal <- (el[,1]==fv) | (el[,2]==fv)
                        }
                } else { focal_related <- rep(TRUE, igraph::vcount(g)); igraph::E(g)$is_focal <- rep(TRUE, igraph::ecount(g)) }

                nn <- igraph::V(g)$name; nd <- igraph::degree(g); n_n <- length(nn)
                bc <- taxa_color_map[nn]
                
                # [UPDATED v2.3] Determine node shapes based on source
                if (analysis_type == "cross_domain") {
                        if (!is.null(ds1_taxa)) {
                          is_ds1 <- nn %in% ds1_taxa
                        } else {
                          # Fallback to prefix detection
                          is_ds1 <- grepl("^DS1_", nn) | grepl("^bac_", nn)
                        }
                        ns <- ifelse(is_ds1, "Dataset1", "Dataset2")
                } else { ns <- rep(21, n_n) }

                if (!is.null(focal_taxon)) {
                        nc <- ifelse(focal_related, bc, "whitesmoke"); na <- ifelse(focal_related, 1, 0.3); nl <- ifelse(focal_related, nn, "")
                } else { nc <- bc; na <- rep(1, n_n); nl <- nn }
                
                # [UPDATED v2.3] For labels, show original names if Paired Analysis
                if (is_paired && show_labels) {
                  nl <- sapply(nl, function(x) {
                    if (x == "") return("")
                    # Remove DS1_/DS2_ prefix for cleaner labels
                    sub("^DS[12]_", "", x)
                  })
                }

                igraph::V(g)$nc <- nc; igraph::V(g)$nd <- nd; igraph::V(g)$na <- na; igraph::V(g)$nl <- nl; igraph::V(g)$ns <- ns

                edf <- igraph::as_data_frame(g, what="edges")
                scor <- sapply(1:nrow(edf), function(i) cor_mat[edf$from[i], edf$to[i]])
                
                if (!is.null(focal_taxon)) {
                        ec <- ifelse(igraph::E(g)$is_focal, ifelse(scor > 0, "firebrick", "steelblue3"), "whitesmoke"); ea <- 0.3
                } else { ec <- ifelse(scor > 0, "firebrick", "steelblue3"); ea <- 0.3 }
                
                igraph::E(g)$ec <- ec; igraph::E(g)$ew <- abs(scor); igraph::E(g)$ea <- ea

                set.seed(1223)
                if (!is.null(unified_layout_coords)) {
                        matched <- unified_layout_coords[unified_layout_coords$name %in% nn, ]
                        if(nrow(matched)>0) gl <- ggraph::create_layout(g, layout="manual", x=matched$x[match(nn, matched$name)], y=matched$y[match(nn, matched$name)]) else gl <- ggraph::create_layout(g, layout=layout_type)
                } else { gl <- ggraph::create_layout(g, layout=layout_type) }

                p <- ggraph(gl) +
                        ggraph::geom_edge_link(aes(colour=ec, width=ew, alpha=ea), show.legend=if(show_legend) c(colour=T, width=T, alpha=F) else F) +
                        geom_point_interactive(aes(x = x, y = y, size=nd, fill=nc, alpha=na, shape=ns, tooltip=tooltip, data_id=name), colour="whitesmoke", stroke=1, show.legend=if(show_legend) c(size=T, fill=F, alpha=F, shape=T) else F) +
                        scale_edge_width_continuous(name="|Correlation|", range=c(0.5, 3), limits=if(!is.null(unified_corr_range)) unified_corr_range else NULL) +
                        scale_edge_colour_manual(name="Correlation", values=c("firebrick"="firebrick", "steelblue3"="steelblue3"), labels=c("firebrick"="Positive", "steelblue3"="Negative")) +
                        scale_edge_alpha_identity() +
                        scale_size_continuous(name="Degree", range=c(2, as.numeric(hubdegree)), limits=if(!is.null(unified_degree_range)) unified_degree_range else NULL) +
                        scale_fill_identity() + scale_alpha_identity()

                if (analysis_type == "cross_domain") {
                        p <- p + scale_shape_manual(name="Data Source", values=c("Dataset1"=21, "Dataset2"=22), guide=guide_legend(override.aes=list(fill="black", colour="black")))
                } else { p <- p + scale_shape_identity() }

                p <- p + guides(size = guide_legend(override.aes=list(fill="black", colour="black"))) +
                        theme_void() + theme(plot.title=element_text(hjust=0.5, size=14, face="bold"), plot.margin=margin(10,10,10,10), legend.position=if(show_legend) "right" else "none") +
                        ggtitle(paste(taxalevel, compcol, evt, sep=" - "))

                if (show_labels) p <- p + ggrepel::geom_text_repel(aes(x=x, y=y, label=nl), size=labelsize, segment.color="grey50", segment.size=0.2, max.overlaps=Inf)
                plot_list[[evt]] <- p
        }

        if (length(plot_list) == 1) combined_plot <- plot_list[[1]] else {
                combined_plot <- patchwork::wrap_plots(plot_list, ncol=length(plot_list))
                if (show_legend) combined_plot <- combined_plot + patchwork::plot_layout(guides="collect") & theme(legend.position="right", legend.box="vertical")
        }
        return(combined_plot)
}
