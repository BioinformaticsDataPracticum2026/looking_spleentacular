#!/usr/bin/env bash
set -euo pipefail

# 01_extract_consensus.sh
# Purpose: locate and extract species-level consensus peaks (prefer IDR conservative,
#          fallback to overlap conservative), normalize to BED, sort, de-duplicate,
#          and optionally expand intervals before downstream cross-species mapping.
# Usage: 01_extract_consensus.sh --human-idr PATH --human-overlap PATH \
#           --mouse-idr PATH --mouse-overlap PATH --outdir PATH [--expand-bp INT]

usage(){
  echo "Usage: $0 --human-idr PATH --human-overlap PATH --mouse-idr PATH --mouse-overlap PATH --outdir PATH [--expand-bp INT]"
  exit 1
}

if [ $# -lt 10 ]; then
  usage
fi

EXPAND_BP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --human-idr) HUMAN_IDR="$2"; shift 2;;
    --human-overlap) HUMAN_OVERLAP="$2"; shift 2;;
    --mouse-idr) MOUSE_IDR="$2"; shift 2;;
    --mouse-overlap) MOUSE_OVERLAP="$2"; shift 2;;
    --outdir) OUTDIR="$2"; shift 2;;
    --expand-bp) EXPAND_BP="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

mkdir -p "$OUTDIR"

# Helper: convert input (bigBed/.bb or gz narrowPeak) to BED sorted 3-column.
# Only the first 3 columns are retained because the downstream liftover logic
# does not require narrowPeak-specific fields.
to_bed_sorted(){
  local src="$1" dst="$2"
  case "$src" in
    *.bb)
      if ! command -v bigBedToBed &>/dev/null; then
        echo "bigBedToBed not found in PATH" >&2; exit 2
      fi
      bigBedToBed "$src" stdout | awk 'BEGIN{OFS="\t"}{print $1,$2,$3}' | sort -k1,1 -k2,2n -u > "$dst" ;;
    *.gz)
      gunzip -c "$src" | awk 'BEGIN{OFS="\t"}{print $1,$2,$3}' | sort -k1,1 -k2,2n -u > "$dst" ;;
    *)
      # assume plain bed or narrowPeak
      awk 'BEGIN{OFS="\t"}{print $1,$2,$3}' "$src" | sort -k1,1 -k2,2n -u > "$dst" ;;
  esac
}

expand_bed(){
  local src="$1" dst="$2" bp="$3"
  if [ "$bp" -le 0 ]; then
    cp "$src" "$dst"
    return 0
  fi

  awk -v OFS="\t" -v bp="$bp" '{
    start=$2-bp;
    if (start < 0) start=0;
    end=$3+bp;
    print $1,start,end
  }' "$src" | sort -k1,1 -k2,2n -u > "$dst"
}

select_and_write(){
  local idr="$1" overlap="$2" out="$3"
  if [ -n "${idr-}" ] && [ -e "$idr" ]; then
    echo "Using IDR file: $idr"
    to_bed_sorted "$idr" "$out"
  elif [ -n "${overlap-}" ] && [ -e "$overlap" ]; then
    echo "IDR not found; using overlap file: $overlap"
    to_bed_sorted "$overlap" "$out"
  else
    echo "Neither IDR nor overlap peak file found for selection: $idr / $overlap" >&2
    exit 3
  fi
}

HUMAN_OUT_RAW="$OUTDIR/human_consensus.raw.bed"
MOUSE_OUT_RAW="$OUTDIR/mouse_consensus.raw.bed"
HUMAN_OUT="$OUTDIR/human_consensus.bed"
MOUSE_OUT="$OUTDIR/mouse_consensus.bed"

select_and_write "$HUMAN_IDR" "$HUMAN_OVERLAP" "$HUMAN_OUT_RAW"
select_and_write "$MOUSE_IDR" "$MOUSE_OVERLAP" "$MOUSE_OUT_RAW"

expand_bed "$HUMAN_OUT_RAW" "$HUMAN_OUT" "$EXPAND_BP"
expand_bed "$MOUSE_OUT_RAW" "$MOUSE_OUT" "$EXPAND_BP"

echo "Wrote: $HUMAN_OUT" 
echo "Wrote: $MOUSE_OUT"

exit 0
