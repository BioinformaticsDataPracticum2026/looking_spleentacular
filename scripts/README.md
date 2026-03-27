Workflow scripts for cross-species ATAC peak mapping

This workflow starts from peak files that already exist in this repository.
It does not rebuild the full ENCODE-style ATAC preprocessing because this workspace
currently contains peak and QC outputs, but no BAM files or chain files.

Files:
- `00_run_cross_species_pipeline.sh` : main entry point that runs the full workflow.
- `01_extract_consensus.sh` : pick species consensus peaks (prefer IDR conservative).
- `02_reciprocal_liftover.sh` : perform liftover and reciprocal mapping (A->B->A).
- `03_quantify_counts.sh` : count reads in peaks across BAMs and produce count matrices.
- `04_build_peak_sets.sh` : generate conserved and species-specific peak sets.

Requirements:
- `bedtools`
- `liftOver` from UCSC tools
- `bigBedToBed` if you want to use `.bb` inputs instead of `.gz`
- `awk`, `sort`, `gunzip`
- Optional: BAM files and manifests for the quantification stage

Repository inputs already available:
- Human IDR consensus candidate:
  - `AdrenalGland_human/peak/idr_reproducibility/idr.conservative_peak.narrowPeak.gz`
- Human overlap fallback:
  - `AdrenalGland_human/peak/overlap_reproducibility/overlap.conservative_peak.narrowPeak.gz`
- Mouse IDR consensus candidate:
  - `AdrenalGland_mouse/peak/idr_reproducibility/idr.conservative_peak.narrowPeak.gz`
- Mouse overlap fallback:
  - `AdrenalGland_mouse/peak/overlap_reproducibility/overlap.conservative_peak.narrowPeak.gz`

Configuration:
1. Copy `workflow/config/cross_species.config.example.sh`.
2. Edit the chain file paths.
3. Optionally edit `workflow/config/human_bams.tsv` and `workflow/config/mouse_bams.tsv`.

Main run command:

```bash
cp workflow/config/cross_species.config.example.sh workflow/config/cross_species.config.sh
bash workflow/scripts/00_run_cross_species_pipeline.sh workflow/config/cross_species.config.sh
```

Outputs:
- `workflow/results/consensus/`
- `workflow/results/liftover/`
- `workflow/results/peak_sets/`
- `workflow/results/counts/` (only if BAM manifests are provided)
- `workflow/results/summary.txt`

Interpretation notes:
- `human_conserved_by_sequence.bed` and `mouse_conserved_by_sequence.bed` are native-coordinate
  peak sets retained by reciprocal liftover.
- `human_species_specific.bed` and `mouse_species_specific.bed` are consensus peaks not retained
  by reciprocal mapping.
- `human_mapped_overlapping_mouse_consensus.bed` and the reciprocal mouse file are stricter shared
  accessibility sets in target-species coordinates.

Recommended next analysis after this shell workflow:
- Run differential accessibility on count matrices if BAMs are available.
- Add nearest-gene annotation and ortholog mapping.
- Run motif enrichment separately on conserved and species-specific peak sets.
