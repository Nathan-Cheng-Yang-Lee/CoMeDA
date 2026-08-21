# CoMeDA

**CoMeDA** (batch-corrected Compositional Metabarcoding Data Analysis) is a no-code, web-based platform for the compositional analysis of 16S rRNA and ITS metabarcoding data. It integrates ALDEx2-based zero handling and centered log-ratio (CLR) transformation, automated PLSDA-batch correction with a partial-redundancy-analysis-guided decision rule, Aitchison-based diversity, log-ratio differential abundance with Cliff's delta, fastCCLasso network inference, PICRUSt2 and FUNFUN functional prediction, and split-CLR cross-dataset correlation, all delivered through an R Shiny interface.

## Availability

- **Web server:** https://comeda.tmu.edu.tw (freely available, no login required, accessible for anonymous review)
- **Docker image:** https://hub.docker.com/r/tmunathanlee/bccomeda (version `v2.local.20260817`)
- **License:** MIT (see [LICENSE](LICENSE))
- **Archived release:** Zenodo DOI [`10.5281/zenodo.21991003`](https://doi.org/10.5281/zenodo.21991004)

## Repository structure

```
CoMeDA/
├── README.md
├── LICENSE
├── comeda_shinyR/              # R Shiny application (UI and server modules)
├── comeda_script/              # Analysis pipeline (numbered stages 0-6) and plotting functions
├── renv.lock                   # R dependency lockfile
└── sessionInfo.txt             # R session information
```

## Local deployment (Docker)

The Docker image bundles the complete application together with all reference databases (Greengenes2, UNITE, and the classification indices), so no additional downloads are required.

```bash
docker pull tmunathanlee/bccomeda:v2.local.20260817
docker run -p 3838:3838 tmunathanlee/bccomeda:v2.local.20260817
```

Then open `http://localhost:3838` in a web browser.

## Analysis pipeline

The `comeda_script/` directory contains the pipeline as numbered stages, together with the plotting functions used by the web application.

| Stage | Scripts | Purpose |
|---|---|---|
| 0 | `0.1_*`, `0.2_*` | Pre-classified taxa-table and result generation |
| 1 | `1.0_demultiplex.sh`, `1.1_qualitycontrol.sh` | Demultiplexing and quality control (Cutadapt) |
| 2 | `2.1_chimeraremoval.sh`, `2.2_*` | Chimera removal (VSEARCH) |
| 3 | `3.1_*` to `3.5_*` | Taxonomic classification (Kraken2/Bracken) and taxa-table generation |
| 4 | `4.1_taxatablefiltering.sh`, `4.2_metagenomicanalysis.r` | Filtering, CLR transformation, batch correction, and downstream analyses |
| 5 | `5.1_*` to `5.5_*` | Functional prediction (PICRUSt2, FUNFUN) and KEGG pathway conversion |
| 6 | `6.1_*` to `6.3_*` | Cross-dataset and cross-kingdom correlation (split-CLR) |

Core functions are defined in `analysis.function.R`, `crossdomain.function.R`, and `fastCCLasso_CLR.R`. Figure panels are rendered by the `plot.*.R` plotting functions, and the batch-correction overview is reproduced by `fig_batch_pcoa_overview.R`.

## Demo data

The example dataset (FASTQ files and the corresponding metadata) can be run directly in the Tutorial section of the web server at https://comeda.tmu.edu.tw. Metadata must contain a `comparison` (or `comparison.1`) column specifying the primary grouping variable, along with batch identifiers and primer sequences where applicable.

## Third-party components

CoMeDA builds on the following tools, which retain their original licenses and should be cited alongside CoMeDA.

- **fastCCLasso** — Zhang S, Fang H, Hu T. Bioinformatics 2024;40(5):btae314. DOI: 10.1093/bioinformatics/btae314. Source: https://github.com/ShenZhang-Statistics/fastCCLasso.
- **PLSDA-batch** (Wang and Le Cao, 2023), **ALDEx2**, **mixOmics**, **vegan**, **effsize**, **compositions**, **PICRUSt2**, **FUNFUN**, **ggpicrust2**, **Kraken2**, **Bracken**, **Cutadapt**, **VSEARCH**, **igraph**, **ggraph**. Full versions are pinned in `renv.lock`.

## Contact

For questions or feedback, please contact bioinfo@tmu.edu.tw or open an issue in this repository.
