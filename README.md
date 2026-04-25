# Bioinformatics Data Practicum Project
The purpose of this pipeline is to provide complete analysis of IDR-conservative ATAC-Seq peak data for mouse and human samples. It takes a heirarchial alignment file (.hal) and conducts peak mapping, annotation of promoters and enhancers, motif enrichment, and GO analysis.

This analysis used human and mouse ATAC-Seq data from healthy adrenal gland tissue in female subjects. Human data was from the ENCODE database (ENCSR241OBO and ENCSR864ADD) and mouse data was from Liu et al., Scientific Data, 2019. Reference genomes used throughout analysis were hg38 and mm10 respectively. 

## Tutorial
👉 [Open Tutorial](https://BioinformaticsDataPracticum2026.github.io/AdrenalGland_ATAC-Seq_Analysis/tutorial.html)
## Installation Instructions:
This tool was designed for a Linux SLURM cluster. To ensure smooth execution of COMPLETE_ANALYSIS_PIPELINE.sh, complete the following:

### 1. Download the RUN_FULL_PIPELINE directory
This folder contains the COMPLETE_ANALYSIS_PIPELINE.sh script as well as all dependent scripts. Copy this folder into your Linux cluster environment and treat it as your base directory when installing the rest of the dependencies.

### 2. Set up dependencies with conda
Set up the environment
```
module load anaconda3
conda create -n atac_seq_analysis python 3.7
conda activate atac_seq_analysis
```

Install the following simulteneously or individually as necessary, if not using a fresh environment
```
conda install -c matplotlib numpy wget R
# verify installation using conda list <package name>
```

Open an R environment for the following steps:
```
install.packages("tidyverse")
if(!require("BiocManager", quiety=TRUE))
	install.packages("BiocManager")
BiocManager::install("rGREAT")
```

### 3. Install HOMER and genomes
```
wget http://homer.ucsd.edu/homer/configureHomer.pl
perl configureHomer.pl -install homer && perl configureHomer.pl -install hg38 && perl configureHomer.pl -install mm10
```

### 4. Install HALPER
See detailed instructions at the [original repository](https://github.com/pfenninglab/halLiftover-postprocessing/blob/master/hal_install_instructions.md)

### 5. Setup data directories
Add the directories with narrowPeak data to the current setup:

```
# from base
mkdir idr_reproducibility
cd idr_reproducibility
mkdir HumanAtac # add .narrowPeak.gz here
mkdir MouseAtac # add .narrowPeak.gz here
```

```
BASE/
├── hal/                                    # conda env (--conda-env), e.g. conda activate …/hal
│   └── …
│
├── repos/                                  # HAL tools + HALPER checkout
│   ├── hal/bin/                            # HAL binaries (--hal-bin); on PATH (halLiftover, …)
│   └── halLiftover-postprocessing/         # HALPER (--halper-pp for PYTHONPATH)
│       ├── halper_map_peak_orthologs.sh    # default --halper-map (full path to this file)
│       └── …
│
├── idr_reproducibility/
│   ├──MouseAtac
│   	└── idr.conservative_peak.narrowPeak.gz
│	└── HumanAtac
│    	└── idr.conservative_peak.narrowPeak.gz
```

## USAGE

### Input
To run the full pipeline, users can submit a slurm job of COMPLETE_ANALYSIS_PIPELINE.sh using the following command:

```
sbatch COMPLETE_ANALYSIS_PIPELINE.sh <.hal filepath> <halper_map_peak_orthologs.sh path>
```

Example:
```
sbatch COMPLETE_ANALYSIS_PIPELINE.sh /ocean/projects/bio230007p/ikaplow/Alignments/10plusway-master.hal /ocean/projects/bio230007p/mccreary/red_group/RUN_FULL_PIPELINE/repos/halLiftover-postprocessing/halper_map_peak_orthologs.sh
```

### Output
COMPLETE_ANALYSIS_PIPELINE.sh will conduct peak mapping, annotation, motif enrichment, and GO analysis. The output will be organized as follows:

```
RUN_FULL_PIPELINE/
├── COMPLETE_ANALYSIS_PIPELINE.sh
├── scripts called by COMPLETE_ANALYSIS_PIPELINE.sh...
│
├── output/Mouse/mapping/conservative				# output from mapping                    
│       ├── shared_peaks_conservative.narrowPeak
│       └── …
│
├── narrowPeak/										# select narrowPeak files, renamed for downstream analysis
│   ├── shared_peaks.narrowPeak
│   └── ...
│
├── homer_results/									# output from HOMER annotatePeaks.pl and findMotifsGenome.pl
│   ├── human_specific/
│   	├── annotated_peaks.txt
│   	├── annotatedPeaks.log
│   	├── findMotifs.log
│   	├── motif_instances.bed
│   	├── peaks_homer.bed
│   	└── motifs/
│   		├── nonRedundant.motifs
│   		└── ...
│   ├── mouse_specific/
│   	└── ...
│   └── shared_peaks/
│   	└── ...
│
├── filtered_annotations/										# downstream analysis from HOMER
│   ├── human_specific_motif_table.tsv
│   ├── human_specific.png
│   ├── human_specific.txt
│   └── ...
│
├── motif_annotation_split/										# additional motif analysis from HOMER
│   ├── human_enhancers_motifs.txt
│   ├── human_promoters_motifs.txt
│   └── ...
│
└── rGREAT_results/												# output from GO enrichment analysis
    ├── dot plots...
    ├── pngs...
    └── tsvs...
```

## Citations and Acknowledgements
This project was conducted for 03-713 Bioinformatics Data Practicum at Carnegie Mellon University, Spring 2026. Authors include Wen Li, Makayla McCreary, Guanyang Wang, and Ushta Samal.

Dependencies retreived from:
- HALPER: Pfenning Lab
- HOMER: Heinz et al. (2010)
- rGREAT: Gu et al. (2016)

