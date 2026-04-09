# Summary of ATAC-seq Motif and Regulatory Element Evolution Analyses

## 1. Enhancer vs Promoter Bias Analysis

**Objective:**
Analyze the distribution of enhancer-like and promoter peaks across different evolutionary peak sets (shared, human-specific, mouse-specific) using HOMER annotation results. The goal is to test the classic hypothesis that enhancer evolution exceeds promoter evolution.

**Steps:**
- Read the HOMER annotation file (`annotated_peaks.txt`) for each peak set.
- Extract the annotation for each peak and classify as "enhancer-like" (intergenic/intronic) or "promoter" (TSS).
- Count and compare the number of enhancer-like and promoter peaks in each set, and output a summary table.

---

## 2. TF by Regulatory Type Analysis

**Objective:**
Cross-tabulate transcription factor (TF) motif enrichment with regulatory element type (promoter vs enhancer-like) to identify TFs that preferentially associate with promoters or enhancers.

**Steps:**
- Read the HOMER motif result file (`knownResults.txt`) for each peak set.
- Parse the motif file and extract TF names.
- (If annotation data is available) Cross-tabulate TF occurrence by regulatory type; otherwise, output the top 20 TFs for each peak set.

---

## 3. TF Evolutionary Shift Analysis

**Objective:**
Compare TF motif enrichment across different evolutionary peak sets (shared, human-specific, mouse-specific) to identify conserved or species-specific TFs and highlight evolutionary rewiring of regulatory networks.

**Steps:**
- Read the HOMER motif result file (`knownResults.txt`) for each peak set.
- Extract the top 20 most significant TFs for each set.
- Compare the TF lists across sets and output a summary table indicating whether each TF is enriched in shared, human-specific, or mouse-specific peaks, highlighting conserved and species-specific TFs.
