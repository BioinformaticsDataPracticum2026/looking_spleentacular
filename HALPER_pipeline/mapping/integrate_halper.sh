#!/bin/bash
# =============================================================================
# integrate_halper_homer.sh
# =============================================================================
# WORKFLOW
#   1) unzip_narrowPeak.sh     — unzip conservative IDR peaks (optional).
#   2) halper_map_peak_orthologs — map mouse conservative peaks to human (HAL + HALPER).
#   3) bedtool_evaluation.sh   — intersect lifted mouse vs human IDR -> shared /
#      mouse_specific / human_specific peak sets in human coordinates.
#   4) awk join (this file)    — build mouse_specific_peaks_conservative.mouse_coords.narrowPeak
#                                in mouse coordinates.
#
# Usage:
#   bash integrate_halper_homer.sh --base DIR --hal-file PATH.hal --halper-map PATH/halper_map_peak_orthologs.sh
# Optional: --conda-env, --hal-bin, --halper-pp (see parse_args / defaults below).
#
# =============================================================================
#SBATCH -A bio230007p
#SBATCH -p RM-shared
#SBATCH --time=12:00:00
#SBATCH -n 1
#SBATCH --mem=2000
#SBATCH -o integrate_halper_homer_%j.out
#SBATCH -e integrate_halper_homer_%j.err
#SBATCH -J integrate_halper_homer

set -euo pipefail

# Directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (override with flags)
DEFAULT_HAL_FILE="/ocean/projects/bio230007p/ikaplow/Alignments/10plusway-master.hal"

BASE=""
HAL_FILE=""
HALPER_MAP_SH=""
CONDA_ENV=""
HAL_BIN=""
HALPER_PP=""

usage() {
  cat <<'EOF'
Usage: integrate_halper_homer.sh --base DIR [options]

Required:
  --base DIR              Project root
  --hal-file PATH         Cactus/HAL .hal file
  --halper-map PATH       halper_map_peak_orthologs.sh from halLiftover-postprocessing

Optional (defaults derived from --base):
  --conda-env PATH        conda env for HAL tools (default: BASE/hal)
  --hal-bin DIR           HAL binaries directory (default: BASE/repos/hal/bin)
  --halper-pp DIR         halLiftover-postprocessing for PYTHONPATH (default: BASE/repos/halLiftover-postprocessing)

EOF
}

# parse arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) BASE="$2"; shift 2 ;;
      --hal-file) HAL_FILE="$2"; shift 2 ;;
      --halper-map) HALPER_MAP_SH="$2"; shift 2 ;;
      --conda-env) CONDA_ENV="$2"; shift 2 ;;
      --hal-bin) HAL_BIN="$2"; shift 2 ;;
      --halper-pp) HALPER_PP="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "${BASE}" ]]; then
    echo "Error: --base DIR is required." >&2
    usage
    exit 1
  fi
  BASE="${BASE%/}"

  HAL_FILE="${HAL_FILE:-$DEFAULT_HAL_FILE}"
  HALPER_MAP_SH="${HALPER_MAP_SH:-${BASE}/repos/halLiftover-postprocessing/halper_map_peak_orthologs.sh}"
  CONDA_ENV="${CONDA_ENV:-${BASE}/hal}"
  HAL_BIN="${HAL_BIN:-${BASE}/repos/hal/bin}"
  HALPER_PP="${HALPER_PP:-${BASE}/repos/halLiftover-postprocessing}"

  MOUSE_CONSERVATIVE_NARROWPEAK="${BASE}/MouseAtac/AdrenalGland/peak/idr_reproducibility/idr.conservative_peak.narrowPeak"
  HUMAN_CONSERVATIVE_NARROWPEAK="${BASE}/HumanAtac/peak/idr_reproducibility/idr.conservative_peak.narrowPeak"
  HALPER_OUT="${SCRIPT_DIR}/results/conservative/narrowPeak"
  CONSERVATIVE_PEAK_DIR="${HALPER_OUT}"
}

parse_args "$@"

# load hal environment
setup_hal_env() {
  module load anaconda3/2024.10-1
  conda activate "${CONDA_ENV}"
  export PATH="${HAL_BIN}:${PATH}"
  export PYTHONPATH="${HALPER_PP}:${PYTHONPATH:-}"
}

# -----------------------------------------------------------------------------
# Step 1 — Unzip conservative IDR narrowPeaks(optional)
# -----------------------------------------------------------------------------
step_unzip() {
  bash "${SCRIPT_DIR}/unzip_narrowPeak.sh" --base "${BASE}"
}

# Step 2 — Map mouse conservative peaks to human coordinates via HALPER.
step_halper() {
  setup_hal_env
  mkdir -p "${HALPER_OUT}"
  bash "${HALPER_MAP_SH}" \
    -b "${MOUSE_CONSERVATIVE_NARROWPEAK}" \
    -o "${HALPER_OUT}/" \
    -s Mouse \
    -t Human \
    -c "${HAL_FILE}"
}

# Step 3 — Classify peaks: shared vs mouse-specific vs human-specific using bedtools intersect.
step_bedtools() {
  bash "${SCRIPT_DIR}/bedtool_evaluation.sh" --base "${BASE}"
}

# Step 4 — Rebuild mouse_specific peaks as a proper MOUSE-coordinate narrowPeak file.
step_mouse_specific_to_mouse_coords() {
  local IN_PEAK="${CONSERVATIVE_PEAK_DIR}/mouse_specific_peaks_conservative.narrowPeak"
  local OUT_PEAK="${CONSERVATIVE_PEAK_DIR}/mouse_specific_peaks_conservative.mouse_coords.narrowPeak"

  awk '
    FNR == NR {
      tail[$1 SUBSEP $2 SUBSEP $3 SUBSEP $10] = $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10
      next
    }
    {
      split($4, p, ":")
      split(p[2], q, "-")
      k = p[1] SUBSEP q[1] SUBSEP q[2] SUBSEP p[3]
      print p[1], q[1], q[2], tail[k]
    }
  ' "${MOUSE_CONSERVATIVE_NARROWPEAK}" "${IN_PEAK}" > "${OUT_PEAK}"

  echo "Wrote ${OUT_PEAK}"
}

main() {
  step_unzip
  step_halper
  step_bedtools
  step_mouse_specific_to_mouse_coords
}

main
