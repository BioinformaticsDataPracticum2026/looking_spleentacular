# Bioinformatics Data Practicum Project
Data used here: Human and Mouse Adrenal Gland

## Description (needs more)
The purpose of this pipeline is to provide complete analysis of IDR-conservative ATAC-Seq peak data for mouse and human samples. It takes heirarchial alignment files (.hal) and conducts peak mapping, annotation of promoters and enhancers, motif enrichment, and GO analysis.

## Installation(different persons)
### dependency(all the persons):
This tool was designed for a Linux SLURM cluster. To ensure smooth execution of complete_analysis_pipeline.sh, install the following to your cluster environment before running:
- R (including ggplot2, tidyverse)
- HOMER (including the genomes hg38 and mm10)

### HALPER
The detailed steps for installaion can be seen in [install_hal](https://github.com/BioinformaticsDataPracticum2026/looking_spleentacular/blob/main/HALPER_pipeline/mapping/install_halper)
(need to updated)
We use PSC for the installation.

### rGREAT
The detailed steps for installaion can be seen in [rGREAT](https://github.com/jokergoo/rgreat).
It is hard to install R in psc, so for isolated analysis we just use the local script in the local computer.

### HOMER
The individual scripts for running and analyzing HOMER output can be found in [HOMER](https://github.com/BioinformaticsDataPracticum2026/looking_spleentacular/blob/main/HOMER/README)

## Usage(one person)
### data structure
### input
### highest level script
### output

### citation



