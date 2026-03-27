#!/usr/bin/env bash
set -euo pipefail

# 02_reciprocal_liftover.sh
# Purpose: perform liftover from species A -> B and check reciprocal mapping (A->B->A).
#          Produces mapped, reciprocal, and statistics files.
# Requirements: UCSC `liftOver` binary in PATH and chain files.
# Usage: 02_reciprocal_liftover.sh --in-bed PATH --chain-AtoB PATH --chain-BtoA PATH --orig-bed PATH --outdir PATH --prefix PREFIX

usage(){
  echo "Usage: $0 --in-bed PATH --chain-AtoB PATH --chain-BtoA PATH --orig-bed PATH --outdir PATH --prefix PREFIX"
  exit 1
}

if [ $# -lt 12 ]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in-bed) IN_BED="$2"; shift 2;;
    --chain-AtoB) CHAIN_AtoB="$2"; shift 2;;
    --chain-BtoA) CHAIN_BtoA="$2"; shift 2;;
    --orig-bed) ORIG_BED="$2"; shift 2;;
    --outdir) OUTDIR="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

mkdir -p "$OUTDIR"

if ! command -v liftOver &>/dev/null; then
  echo "liftOver not found in PATH" >&2; exit 2
fi

# Step 1: map A -> B
ATOB="$OUTDIR/${PREFIX}_AtoB.bed"
UNMAPPED_A="$OUTDIR/${PREFIX}_AtoB.unmapped.bed"
liftOver "$IN_BED" "$CHAIN_AtoB" "$ATOB" "$UNMAPPED_A"

# Step 2: map the mapped results back B -> A
BACKTOTEST="$OUTDIR/${PREFIX}_AtoB_back_to_A.bed"
UNMAPPED_BACK="$OUTDIR/${PREFIX}_AtoB_back.unmapped.bed"
liftOver "$ATOB" "$CHAIN_BtoA" "$BACKTOTEST" "$UNMAPPED_BACK"

# Step 3: reciprocal = original peaks that are present in back-mapped set
RECIPROCAL="$OUTDIR/${PREFIX}_reciprocal.bed"
if ! command -v bedtools &>/dev/null; then
  echo "bedtools not found in PATH" >&2; exit 2
fi
bedtools intersect -u -a "$ORIG_BED" -b "$BACKTOTEST" > "$RECIPROCAL"

# Stats
TOTAL=$(wc -l < "$ORIG_BED" )
MAPPED=$(wc -l < "$ATOB" )
RECIP=$(wc -l < "$RECIPROCAL" )
echo "total_orig=$TOTAL" > "$OUTDIR/${PREFIX}.stats.txt"
echo "mapped_AtoB=$MAPPED" >> "$OUTDIR/${PREFIX}.stats.txt"
echo "reciprocal=$RECIP" >> "$OUTDIR/${PREFIX}.stats.txt"

echo "Wrote: $ATOB" 
echo "Wrote: $BACKTOTEST" 
echo "Wrote: $RECIPROCAL" 
echo "Wrote stats: $OUTDIR/${PREFIX}.stats.txt"

exit 0
