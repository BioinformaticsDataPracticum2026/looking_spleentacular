#!/usr/bin/env bash
set -euo pipefail

# 00_run_cross_species_pipeline.sh
# Purpose: orchestrate the complete cross-species ATAC peak comparison workflow
#          starting from existing peak calls and optional BAM manifests.
# Expected config variables:
#   ROOT_DIR
#   OUTDIR
#   HUMAN_IDR_PEAK
#   HUMAN_OVERLAP_PEAK
#   MOUSE_IDR_PEAK
#   MOUSE_OVERLAP_PEAK
#   HG_TO_MM_CHAIN
#   MM_TO_HG_CHAIN
# Optional:
#   EXPAND_BP
#   HUMAN_BAM_MANIFEST
#   MOUSE_BAM_MANIFEST
#
# Usage:
#   bash workflow/scripts/00_run_cross_species_pipeline.sh workflow/config/cross_species.config.sh

usage(){
  echo "Usage: $0 path/to/config.sh"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

CONFIG="$1"
if [ ! -f "$CONFIG" ]; then
  echo "Config file not found: $CONFIG" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$CONFIG"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}
OUTDIR=${OUTDIR:-$ROOT_DIR/workflow/results}
EXPAND_BP=${EXPAND_BP:-0}

mkdir -p "$OUTDIR" "$OUTDIR/logs" "$OUTDIR/consensus" "$OUTDIR/liftover" "$OUTDIR/peak_sets" "$OUTDIR/counts"

require_file(){
  local path="$1"
  local label="$2"
  if [ ! -f "$path" ]; then
    echo "Missing required file for $label: $path" >&2
    exit 3
  fi
}

require_cmd(){
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    echo "Required command not found in PATH: $cmd" >&2
    exit 4
  fi
}

manifest_has_real_bams(){
  local manifest="$1"

  [ -f "$manifest" ] || return 1

  while IFS=$'\t' read -r sample_id bam_path || [ -n "${sample_id:-}" ]; do
    [ -z "${sample_id:-}" ] && continue
    case "${bam_path:-}" in
      ""|/path/to/*)
        continue
        ;;
    esac

    if [ -f "$bam_path" ]; then
      return 0
    fi
  done < "$manifest"

  return 1
}

require_cmd awk
require_cmd sort
require_cmd bedtools
require_cmd liftOver

require_file "$HUMAN_IDR_PEAK" "HUMAN_IDR_PEAK"
require_file "$HUMAN_OVERLAP_PEAK" "HUMAN_OVERLAP_PEAK"
require_file "$MOUSE_IDR_PEAK" "MOUSE_IDR_PEAK"
require_file "$MOUSE_OVERLAP_PEAK" "MOUSE_OVERLAP_PEAK"
require_file "$HG_TO_MM_CHAIN" "HG_TO_MM_CHAIN"
require_file "$MM_TO_HG_CHAIN" "MM_TO_HG_CHAIN"

echo "[1/5] Extracting consensus peaks"
bash "$SCRIPT_DIR/01_extract_consensus.sh" \
  --human-idr "$HUMAN_IDR_PEAK" \
  --human-overlap "$HUMAN_OVERLAP_PEAK" \
  --mouse-idr "$MOUSE_IDR_PEAK" \
  --mouse-overlap "$MOUSE_OVERLAP_PEAK" \
  --outdir "$OUTDIR/consensus" \
  --expand-bp "$EXPAND_BP" \
  | tee "$OUTDIR/logs/01_extract_consensus.log"

echo "[2/5] Reciprocal liftover human -> mouse -> human"
bash "$SCRIPT_DIR/02_reciprocal_liftover.sh" \
  --in-bed "$OUTDIR/consensus/human_consensus.bed" \
  --chain-AtoB "$HG_TO_MM_CHAIN" \
  --chain-BtoA "$MM_TO_HG_CHAIN" \
  --orig-bed "$OUTDIR/consensus/human_consensus.bed" \
  --outdir "$OUTDIR/liftover" \
  --prefix human_to_mouse \
  | tee "$OUTDIR/logs/02_human_to_mouse.log"

echo "[3/5] Reciprocal liftover mouse -> human -> mouse"
bash "$SCRIPT_DIR/02_reciprocal_liftover.sh" \
  --in-bed "$OUTDIR/consensus/mouse_consensus.bed" \
  --chain-AtoB "$MM_TO_HG_CHAIN" \
  --chain-BtoA "$HG_TO_MM_CHAIN" \
  --orig-bed "$OUTDIR/consensus/mouse_consensus.bed" \
  --outdir "$OUTDIR/liftover" \
  --prefix mouse_to_human \
  | tee "$OUTDIR/logs/03_mouse_to_human.log"

echo "[4/5] Building conserved and species-specific peak sets"
bash "$SCRIPT_DIR/04_build_peak_sets.sh" \
  --human-consensus "$OUTDIR/consensus/human_consensus.bed" \
  --mouse-consensus "$OUTDIR/consensus/mouse_consensus.bed" \
  --human-reciprocal "$OUTDIR/liftover/human_to_mouse_reciprocal.bed" \
  --mouse-reciprocal "$OUTDIR/liftover/mouse_to_human_reciprocal.bed" \
  --human-mapped-to-mouse "$OUTDIR/liftover/human_to_mouse_AtoB.bed" \
  --mouse-mapped-to-human "$OUTDIR/liftover/mouse_to_human_AtoB.bed" \
  --outdir "$OUTDIR/peak_sets" \
  | tee "$OUTDIR/logs/04_build_peak_sets.log"

if [ -n "${HUMAN_BAM_MANIFEST:-}" ] && [ -f "$HUMAN_BAM_MANIFEST" ]; then
  if manifest_has_real_bams "$HUMAN_BAM_MANIFEST"; then
    echo "[5/5] Quantifying human BAMs on human conserved peaks"
    bash "$SCRIPT_DIR/03_quantify_counts.sh" \
      --peaks "$OUTDIR/peak_sets/human_conserved_by_sequence.bed" \
      --samples "$HUMAN_BAM_MANIFEST" \
      --out "$OUTDIR/counts/human_conserved_counts.tsv" \
      2>&1 | tee "$OUTDIR/logs/05_quantify_human.log"
  else
    echo "[5/5] Skipping human quantification because HUMAN_BAM_MANIFEST only contains placeholder or missing BAM paths" \
      | tee "$OUTDIR/logs/05_quantify_human.log"
  fi
else
  echo "[5/5] Skipping human quantification because HUMAN_BAM_MANIFEST is not set or does not exist" \
    | tee "$OUTDIR/logs/05_quantify_human.log"
fi

if [ -n "${MOUSE_BAM_MANIFEST:-}" ] && [ -f "$MOUSE_BAM_MANIFEST" ]; then
  if manifest_has_real_bams "$MOUSE_BAM_MANIFEST"; then
    echo "[5/5] Quantifying mouse BAMs on mouse conserved peaks"
    bash "$SCRIPT_DIR/03_quantify_counts.sh" \
      --peaks "$OUTDIR/peak_sets/mouse_conserved_by_sequence.bed" \
      --samples "$MOUSE_BAM_MANIFEST" \
      --out "$OUTDIR/counts/mouse_conserved_counts.tsv" \
      2>&1 | tee "$OUTDIR/logs/05_quantify_mouse.log"
  else
    echo "[5/5] Skipping mouse quantification because MOUSE_BAM_MANIFEST only contains placeholder or missing BAM paths" \
      | tee "$OUTDIR/logs/05_quantify_mouse.log"
  fi
else
  echo "[5/5] Skipping mouse quantification because MOUSE_BAM_MANIFEST is not set or does not exist" \
    | tee "$OUTDIR/logs/05_quantify_mouse.log"
fi

cat > "$OUTDIR/summary.txt" <<EOF
Cross-species ATAC pipeline completed.

Key outputs:
- Consensus peaks: $OUTDIR/consensus
- Reciprocal liftover results: $OUTDIR/liftover
- Conserved and species-specific peak sets: $OUTDIR/peak_sets
- Optional count matrices: $OUTDIR/counts

Most useful summary file:
- $OUTDIR/peak_sets/peak_set_summary.tsv
EOF

echo "Pipeline finished. See: $OUTDIR/summary.txt"
