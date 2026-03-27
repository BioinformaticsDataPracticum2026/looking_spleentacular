#!/usr/bin/env bash
set -euo pipefail

# 04_build_peak_sets.sh
# Purpose: build conserved and species-specific peak sets from reciprocal liftover
#          results and summarize direct overlap in target species coordinates.
# Inputs:
#   --human-consensus PATH
#   --mouse-consensus PATH
#   --human-reciprocal PATH         # subset of human peaks that reciprocally map
#   --mouse-reciprocal PATH         # subset of mouse peaks that reciprocally map
#   --human-mapped-to-mouse PATH    # human consensus mapped into mouse coordinates
#   --mouse-mapped-to-human PATH    # mouse consensus mapped into human coordinates
#   --outdir PATH

usage(){
  echo "Usage: $0 --human-consensus PATH --mouse-consensus PATH --human-reciprocal PATH --mouse-reciprocal PATH --human-mapped-to-mouse PATH --mouse-mapped-to-human PATH --outdir PATH"
  exit 1
}

if [ $# -lt 14 ]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --human-consensus) HUMAN_CONSENSUS="$2"; shift 2 ;;
    --mouse-consensus) MOUSE_CONSENSUS="$2"; shift 2 ;;
    --human-reciprocal) HUMAN_RECIP="$2"; shift 2 ;;
    --mouse-reciprocal) MOUSE_RECIP="$2"; shift 2 ;;
    --human-mapped-to-mouse) HUMAN_MAPPED_TO_MOUSE="$2"; shift 2 ;;
    --mouse-mapped-to-human) MOUSE_MAPPED_TO_HUMAN="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if ! command -v bedtools &>/dev/null; then
  echo "bedtools not found in PATH" >&2
  exit 2
fi

mkdir -p "$OUTDIR"

# Conserved peaks in their native coordinates.
cp "$HUMAN_RECIP" "$OUTDIR/human_conserved_by_sequence.bed"
cp "$MOUSE_RECIP" "$OUTDIR/mouse_conserved_by_sequence.bed"

# Species-specific peaks are the consensus peaks not retained by reciprocal mapping.
bedtools subtract -a "$HUMAN_CONSENSUS" -b "$HUMAN_RECIP" > "$OUTDIR/human_species_specific.bed"
bedtools subtract -a "$MOUSE_CONSENSUS" -b "$MOUSE_RECIP" > "$OUTDIR/mouse_species_specific.bed"

# Direct overlap in target coordinates: a mapped peak that also overlaps the target species
# consensus peak set is stronger evidence for shared open chromatin, not only sequence conservation.
bedtools intersect -u -a "$HUMAN_MAPPED_TO_MOUSE" -b "$MOUSE_CONSENSUS" > "$OUTDIR/human_mapped_overlapping_mouse_consensus.bed"
bedtools intersect -u -a "$MOUSE_MAPPED_TO_HUMAN" -b "$HUMAN_CONSENSUS" > "$OUTDIR/mouse_mapped_overlapping_human_consensus.bed"

{
  echo "metric\tvalue"
  echo "human_consensus\t$(wc -l < "$HUMAN_CONSENSUS")"
  echo "mouse_consensus\t$(wc -l < "$MOUSE_CONSENSUS")"
  echo "human_reciprocal\t$(wc -l < "$HUMAN_RECIP")"
  echo "mouse_reciprocal\t$(wc -l < "$MOUSE_RECIP")"
  echo "human_species_specific\t$(wc -l < "$OUTDIR/human_species_specific.bed")"
  echo "mouse_species_specific\t$(wc -l < "$OUTDIR/mouse_species_specific.bed")"
  echo "human_mapped_overlap_mouse_consensus\t$(wc -l < "$OUTDIR/human_mapped_overlapping_mouse_consensus.bed")"
  echo "mouse_mapped_overlap_human_consensus\t$(wc -l < "$OUTDIR/mouse_mapped_overlapping_human_consensus.bed")"
} > "$OUTDIR/peak_set_summary.tsv"

echo "Wrote peak sets and summary to: $OUTDIR"
