## ============================================================================
## ^software environment record (reviewer revision R2-4b, 2026-09-27)
## ----------------------------------------------------------------------------
## Builds the "SECTION 0: SOFTWARE ENVIRONMENT" block that is written at the top
## of every parameters_info.txt (single-dataset jobs and cross-dataset jobs).
##
## * Every line starts with "#", so the existing parsers are unaffected:
##   - current_params() in server_analysis_resultoverview.R drops "^#" lines
##   - parse_parameters_info() in server_analysis_crosskingdom.R ignores lines
##     that appear before the first "[Analysis Mode]" header
## * Tool versions are queried once per R session and cached, because they are
##   fixed within a Docker image.
## * The release identifiers come from environment variables set in the
##   Dockerfile:
##       ENV COMEDA_VERSION=v2.local.YYYYMMDD
##       ENV COMEDA_COMMIT=<git commit hash>
## * Fixed analysis settings mirror the hard-coded values in comeda_script/
##   (4.2_metagenomicanalysis.r, analysis.function.R, plot.betadiversity.R,
##   5.2_bacfunc_usingpicrust2.sh, 6.1_crossdomaincorrelation_wReport.r).
##   Update this list whenever those values change.
## ============================================================================

.comeda_env_cache <- new.env(parent = emptyenv())

## query one command-line tool and return the first version-like string
.query_tool_version <- function(cmd, args) {
  if (!nzchar(Sys.which(cmd))) return("not detected")
  out <- tryCatch(
    suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = TRUE, timeout = 30)),
    error = function(e) character(0)
  )
  if (length(out) == 0) return("not detected")
  hits <- regmatches(out, regexpr("[0-9]+\\.[0-9]+(\\.[0-9]+)?", out))
  if (length(hits) == 0) return("not detected")
  hits[1]
}

## installed version of an R package, or "not installed"
.query_pkg_version <- function(pkg) {
  tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) "not installed")
}

## returns a character vector of "#"-prefixed lines (cached after first call)
build_software_environment_lines <- function() {
  if (!is.null(.comeda_env_cache$lines)) return(.comeda_env_cache$lines)

  env_or <- function(var, default = "not set") {
    val <- Sys.getenv(var, unset = "")
    if (nzchar(val)) val else default
  }

  tools <- c(
    Cutadapt  = .query_tool_version("cutadapt", "--version"),
    VSEARCH   = .query_tool_version("vsearch", "--version"),
    Kraken2   = .query_tool_version("kraken2", "--version"),
    Bracken   = .query_tool_version("bracken", "-v"),
    PICRUSt2  = .query_tool_version("picrust2_pipeline.py", "--version"),
    FUNFUN    = "1.0 (bundled)"
  )

  databases <- c(
    `16S reference` = "Greengenes2 2024.09 backbone (greengenes2_v2024.09_bb.modified)",
    `ITS reference` = "UNITE 10.0, 2025-02 dynamic release (unite10_v2025.02_dynamic.modified)"
  )

  r_pkgs <- c("ALDEx2", "PLSDAbatch", "mixOmics", "vegan", "effsize",
              "igraph", "ggraph", "ggpicrust2", "shiny", "ggiraph")
  pkg_versions <- vapply(r_pkgs, .query_pkg_version, character(1))

  fixed_settings <- c(
    `Kraken2 confidence`     = "selected value in Section 1 (16S 0.1, ITS 0.05 by default), reclassified at 0 if any sample lacks Bracken results (recorded in Section 2)",
    `ALDEx2 CLR`             = "mc.samples = 128, denom = iqlr (median if iqlr fails, recorded in Section 2)",
    `Random seed`            = "1223 (ALDEx2, PLSDA-batch tuning, fastCCLasso)",
    `PLSDA-batch tuning`     = "Mfold CV, folds = 4, nrepeat = 30",
    `Differential abundance` = "Wilcoxon rank-sum test on median CLR, Benjamini-Hochberg adjustment, Cliff's delta",
    `PERMANOVA / PERMDISP`   = "vegan adonis2 and permutest, 999 permutations",
    `fastCCLasso`            = "k_cv = 3, lam_min_ratio = 1e-4, k_max = 20, n_boot = 100",
    `Network edge default`   = "BH-adjusted p < 0.05 and |r| >= 0.3 (cross-dataset BH over cross-dataset pairs only)",
    `PICRUSt2`               = "--max_nsti 0.5, --no_pathways (KO to KEGG pathway via ggpicrust2)"
  )

  fmt <- function(x) paste0("# ", names(x), ": ", x)

  lines <- c(
    "# [SECTION 0: SOFTWARE ENVIRONMENT]",
    "# Software release, tool and database versions, and fixed analysis settings",
    paste0("# CoMeDA release: ", env_or("COMEDA_VERSION")),
    paste0("# Source commit: ", env_or("COMEDA_COMMIT")),
    "# Docker image: tmunathanlee/bccomeda",
    "#",
    "# Tools",
    fmt(tools),
    "#",
    "# Reference databases",
    fmt(databases),
    "#",
    paste0("# R: ", R.version$major, ".", R.version$minor),
    fmt(pkg_versions),
    "#",
    "# Fixed analysis settings",
    fmt(fixed_settings),
    "# ============================================================",
    ""
  )

  .comeda_env_cache$lines <- lines
  lines
}
## software environment record$
