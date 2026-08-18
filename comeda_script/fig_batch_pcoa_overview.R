#!/usr/bin/env Rscript
## =====================================================================
## Gout 圖：Batch correction overview 四 PCoA（複製 shinyapp result overview 風格）
## 版面 2x2：列=配色{batches / primary comparison}，欄={Before / After correction}
##   p1 Before(By Batches) firebrick｜p2 After(By Batches) forestgreen
##   p3 Before(By Group)   firebrick｜p4 After(By Group)   forestgreen
## 資料＝平台原生 gout CoMeDA.Rdata（aldex.clr=before、batch.correct.res$correctedTable=after）
## 忠實重現：Aitchison(=Euclidean on CLR) → cmdscale PCoA、centroid 連線、t-ellipse、
##   條件式 PERMANOVA（focal | adjust，by terms）+ PERMDISP，comedacolors 調色盤。
## 輸出：fig_batch_pcoa_overview.{pdf,png}
## 用法： Rscript fig_batch_pcoa_overview.R
## =====================================================================
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(rlang); library(patchwork); library(vegan); library(permute)
})

base   <- "/nfs/TMUWorkNAS/nathan/personal/PHD/Thesis/CoMeDA/BMCbioinfo_20260318/review_part1/re-analysis"
outdir <- file.path(base, "result/study1_out")
RDATA  <- file.path(outdir, "gout_CoMeDA_Rdata/CoMeDA.Rdata")
TAXA   <- "genus"; BATCH_COL <- "batches"; COMP_COL <- "comparison.Group"; SEED <- 1223L; NPERM <- 999L

## comedacolors（複製自 shiny global.R）
comedacolors <- c("steelblue","tomato","forestgreen","darkorange","darkslateblue","firebrick","mediumseagreen",
  "goldenrod","slateblue","darkgray","dodgerblue","lightgreen","sienna","blueviolet","darkcyan","salmon",
  "moccasin","chocolate","orchid","cornflowerblue","indianred","darkolivegreen","plum","royalblue","red",
  "seagreen","peru","slategray","navy","hotpink","limegreen","mediumvioletred","orange","#e5505a","#6caddf",
  "#ffc600","#9fc54d","#a560e8","#D0B3A3","#fe5000","#a93c3b","#0057b8","#00b140","#4e2a84","#B78B6E","#ff9933",
  "#e0393e","#1fbad6","#00af87","#694d88","#767676","#f58268","#f4979c","#007fae","#578230","#BDACE5","#000075")

## ---- 載入平台原生 Rdata ----
e <- new.env(); load(RDATA, envir = e)
before_mat <- as.matrix(e$aldex.clr[[TAXA]])
after_mat  <- as.matrix(e$batch.correct.res[[TAXA]][["correctedTable"]])
meta_all   <- as.data.frame(e$filtered.meta[[TAXA]])
stopifnot(all(c(BATCH_COL, COMP_COL) %in% colnames(meta_all)))

## ---- prepare_beta_space（複製 shiny）----
prepare_beta_space <- function(X, metadata, batch_col, group_col) {
  cs <- intersect(rownames(X), rownames(metadata)); if (length(cs) < 3) return(NULL)
  X <- as.matrix(X[cs, , drop = FALSE]); md <- as.data.frame(metadata[cs, , drop = FALSE])
  ok <- complete.cases(md[, c(batch_col, group_col), drop = FALSE]); X <- X[ok, , drop = FALSE]; md <- md[ok, , drop = FALSE]
  if (nrow(X) < 3 || ncol(X) < 2 || any(!is.finite(X))) return(NULL)
  md$batch <- droplevels(factor(md[[batch_col]])); md$group <- droplevels(factor(md[[group_col]]))
  if (nlevels(md$batch) < 2 || nlevels(md$group) < 2) return(NULL)
  D <- stats::dist(X, method = "euclidean")            # Aitchison = Euclidean on CLR
  pcoa <- stats::cmdscale(D, k = 2, eig = TRUE)
  list(metadata = md, distance = D, pcoa = pcoa, batch_col = batch_col, group_col = group_col,
       n_samples = nrow(X), n_taxa = ncol(X))
}

## ---- calculate_beta_tests（條件式 PERMANOVA + PERMDISP，複製 shiny）----
calculate_beta_tests <- function(bs, focal = c("batch","group")) {
  focal <- match.arg(focal); if (is.null(bs)) return(NULL)
  D <- bs$distance; md <- bs$metadata
  if (focal == "batch") { adj <- md$group; ff <- md$batch; fcol <- bs$batch_col; acol <- bs$group_col; form <- D ~ group + batch; tgt <- "batch" }
  else                  { adj <- md$batch; ff <- md$group; fcol <- bs$group_col; acol <- bs$batch_col; form <- D ~ batch + group; tgt <- "group" }
  ctrl <- permute::how(nperm = NPERM); permute::setBlocks(ctrl) <- adj
  set.seed(SEED); fit <- vegan::adonis2(form, data = md, permutations = ctrl, by = "terms")
  permd <- tryCatch({ set.seed(SEED); disp <- vegan::betadisper(D, ff); dt <- as.data.frame(vegan::permutest(disp, permutations = NPERM)$tab)
    list(F = unname(dt[1, grep("^F", colnames(dt))[1]]), p = unname(dt[1, grep("Pr", colnames(dt))[1]])) },
    error = function(err) list(F = NA_real_, p = NA_real_))
  list(R2 = unname(fit[tgt, "R2"]), pvalue = unname(fit[tgt, "Pr(>F)"]),
       permdisp_F = permd$F, permdisp_p = permd$p, focal_col = fcol, adjust_col = acol)
}

## ---- get_pcoa_ggplot（靜態版，複製 shiny 樣式）----
get_pcoa_ggplot <- function(bs, color_col, title_color, pr, color_reverse = FALSE) {
  if (is.null(bs)) return(NULL)
  md <- bs$metadata; pc <- bs$pcoa; md[[color_col]] <- factor(md[[color_col]])
  df <- data.frame(PCoA1 = pc$points[,1], PCoA2 = pc$points[,2], row.names = rownames(md), check.names = FALSE)
  df$Row.names <- rownames(df); ev <- pc$eig; ve <- round(ev[1:2] / sum(abs(ev)) * 100, 1)
  dwm <- cbind(df, md)
  cen <- dwm %>% dplyr::group_by(!!sym(color_col)) %>% dplyr::summarise(cx = mean(PCoA1), cy = mean(PCoA2), .groups = "drop")
  pd <- dplyr::left_join(dwm, cen, by = color_col)
  fp <- function(p) if (is.na(p)) "NA" else if (p <= 0.001) "<= 0.001" else format(round(p,3), nsmall = 3)
  disp_w <- if (!is.na(pr$permdisp_p) && pr$permdisp_p < 0.05) " [dispersion differs]" else ""
  ttl <- paste0("PERMANOVA R²(", pr$focal_col, " | ", pr$adjust_col, ") = ", round(pr$R2,3),
                ", p ", fp(pr$pvalue), "\nPERMDISP F = ", round(pr$permdisp_F,2), ", p ", fp(pr$permdisp_p), disp_w)
  ng <- length(unique(pd[[color_col]]))
  cols <- if (color_reverse) rev(comedacolors)[1:ng] else comedacolors[1:ng]
  ggplot(pd, aes(x = PCoA1, y = PCoA2, color = .data[[color_col]])) +
    geom_segment(aes(xend = cx, yend = cy), linetype = "solid", linewidth = 0.5, alpha = 0.3) +
    stat_ellipse(data = pd %>% group_by(!!sym(color_col)) %>% filter(n() > 3), type = "t",
                 linetype = "dashed", linewidth = 0.5, alpha = 0.8) +
    geom_point(size = 3) +
    theme_minimal(base_size = 12) +
    labs(title = ttl, x = paste0("PCoA1 (", ve[1], "%)"), y = paste0("PCoA2 (", ve[2], "%)"), color = color_col) +
    scale_color_manual(values = cols) +
    theme(legend.position = "bottom",
          plot.title = element_text(size = 11, face = "italic", hjust = 1, color = title_color),
          plot.title.position = "plot",
          panel.border = element_rect(colour = "grey", fill = NA, linewidth = 0.5))
}

## ---- 建 beta space + tests ----
before <- prepare_beta_space(before_mat, meta_all, BATCH_COL, COMP_COL)
after  <- prepare_beta_space(after_mat,  meta_all, BATCH_COL, COMP_COL)
stopifnot(!is.null(before), !is.null(after))
t_bb <- calculate_beta_tests(before, "batch"); t_ba <- calculate_beta_tests(after, "batch")
t_gb <- calculate_beta_tests(before, "group"); t_ga <- calculate_beta_tests(after, "group")

p1 <- get_pcoa_ggplot(before, BATCH_COL, "firebrick",   t_bb, color_reverse = TRUE)
p2 <- get_pcoa_ggplot(after,  BATCH_COL, "forestgreen", t_ba, color_reverse = TRUE)
p3 <- get_pcoa_ggplot(before, COMP_COL,  "firebrick",   t_gb, color_reverse = FALSE)
p4 <- get_pcoa_ggplot(after,  COMP_COL,  "forestgreen", t_ga, color_reverse = FALSE)

## ---- 段標 / 欄標 / 分隔線（複製 shiny）----
sec <- function(lbl) ggplot() + annotate("text", 0.5, 0.5, label = lbl, fontface = "bold", size = 6, colour = "gray20") +
  xlim(0,1) + ylim(0,1) + theme_void() + theme(plot.margin = margin(0,0,0,0))
colhdr <- function() ggplot() +
  annotate("text", 0.25, 0.5, label = "Before batch correction", fontface = "bold", size = 4.5, colour = "firebrick") +
  annotate("text", 0.50, 0.5, label = "→", fontface = "bold", size = 5, colour = "black") +
  annotate("text", 0.75, 0.5, label = "After batch correction", fontface = "bold", size = 4.5, colour = "forestgreen") +
  xlim(0,1) + ylim(0,1) + theme_void() + theme(plot.margin = margin(0,0,0,0))
sep <- ggplot() + geom_hline(yintercept = 0, linetype = "dashed", colour = "gray60", linewidth = 0.8) +
  theme_void() + theme(plot.margin = margin(5,0,5,0))
cm <- margin(5, 5.5, 5.5, 5.5)
p1 <- p1 + theme(plot.margin = cm); p2 <- p2 + theme(plot.margin = cm)
p3 <- p3 + theme(plot.margin = cm); p4 <- p4 + theme(plot.margin = cm)

design <- "AA\n##\nBB\nCD\nEE\nFF\n##\nGG\nHI"
combined <- sec("Label by batches") + colhdr() + p1 + p2 + sep + sec("Label by primary comparison") + colhdr() + p3 + p4 +
  patchwork::plot_layout(design = design, heights = c(0.8, 0.1, 0.45, 10, 0.25, 0.8, 0.1, 0.45, 10))

ggsave(file.path(outdir, "fig_batch_pcoa_overview.pdf"), combined, width = 16, height = 11, device = cairo_pdf)
ggsave(file.path(outdir, "fig_batch_pcoa_overview.png"), combined, width = 16, height = 11, dpi = 300)

cat("PERMANOVA R²（focal | adjust）：\n")
cat(sprintf("  batch  before %.3f (p=%.3f) → after %.3f (p=%.3f)\n", t_bb$R2, t_bb$pvalue, t_ba$R2, t_ba$pvalue))
cat(sprintf("  group  before %.3f (p=%.3f) → after %.3f (p=%.3f)\n", t_gb$R2, t_gb$pvalue, t_ga$R2, t_ga$pvalue))
cat("輸出：fig_batch_pcoa_overview.pdf / .png\n")
