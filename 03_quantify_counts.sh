#!/usr/bin/env bash
set -euo pipefail

# 03_quantify_counts.sh
# Purpose: count reads in a peak BED file across many BAMs and produce a tab-separated
#          count matrix suitable for DESeq2/edgeR.
# Requirements: bedtools (multicov) and samtools available in PATH.
# Inputs:
#   --peaks PATH         : consensus peak BED (3-column, sorted)
#   --samples PATH       : tab-delimited file: sample_id\t/path/to/sample.bam  (one per line)
#   --out PATH           : output counts TSV (headered)
# Usage example:
#   03_quantify_counts.sh --peaks consensus.bed --samples samples.tsv --out counts_matrix.tsv

usage(){
  echo "Usage: $0 --peaks PATH --samples PATH --out PATH"; exit 1
}

if [ $# -lt 6 ]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --peaks) PEAKS="$2"; shift 2;;
    --samples) SAMPLES="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

if ! command -v bedtools &>/dev/null; then
  echo "bedtools not in PATH" >&2; exit 2
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Build ordered bam list and header
BAM_LIST=()
HEADER=("chr" "start" "end")
while IFS=$'\t' read -r sid bam || [ -n "$sid" ]; do
  [ -z "$sid" ] && continue
  BAM_LIST+=("$bam")
  HEADER+=("$sid")
done < "$SAMPLES"

# Run bedtools multicov: writes counts for each interval and each bam
bedtools multicov -bams ${BAM_LIST[@]} -bed "$PEAKS" > "$TMPDIR/multicov.out"

# Prepare final TSV with header
printf "%s\t" "chr" "start" "end" > "$OUT.tmp"
for i in "${HEADER[@]:3}"; do printf "%s\t" "$i" >> "$OUT.tmp"; done
printf "\n" >> "$OUT.tmp"

# multicov output: first 3 columns are interval, remaining columns are counts
cat "$TMPDIR/multicov.out" >> "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

echo "Wrote count matrix: $OUT"

exit 0
