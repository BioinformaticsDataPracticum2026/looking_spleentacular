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


# CONFIG for the pipeline
# Original mouse IDR conservative peaks (uncompressed narrowPeak). 
MOUSE_CONSERVATIVE_NARROWPEAK="/ocean/projects/bio230007p/wli27/MouseAtac/AdrenalGland/peak/idr_reproducibility/idr.conservative_peak.narrowPeak"

# Human IDR conservative peaks 
HUMAN_CONSERVATIVE_NARROWPEAK="/ocean/projects/bio230007p/wli27/HumanAtac/peak/idr_reproducibility/idr.conservative_peak.narrowPeak"

# Directory where HALPER writes lifted peaks and bedtools steps output
HALPER_OUT="/ocean/projects/bio230007p/wli27/output/Mouse/mapping/conservative"

# hal file location
HAL_FILE="/ocean/projects/bio230007p/ikaplow/Alignments/10plusway-master.hal"

# Wrapper from halLiftover-postprocessing.
HALPER_MAP_SH="/ocean/projects/bio230007p/wli27/repos/halLiftover-postprocessing/halper_map_peak_orthologs.sh"

# Folder containing mouse_specific / shared / human_specific narrowPeak files after bedtools.
# the same as HALPER_OUT
CONSERVATIVE_PEAK_DIR="${HALPER_OUT}"

# load hal environment
setup_hal_env() {
  module load anaconda3/2024.10-1
  conda activate /ocean/projects/bio230007p/wli27/hal
  export PATH=/ocean/projects/bio230007p/wli27/repos/hal/bin:${PATH}
  export PYTHONPATH=/ocean/projects/bio230007p/wli27/repos/halLiftover-postprocessing:${PYTHONPATH}
}

# -----------------------------------------------------------------------------
# Step 1 — Unzip conservative IDR narrowPeaks(optional)
# -----------------------------------------------------------------------------
step_unzip() {
  bash "${SCRIPT_DIR}/unzip_narrowPeak.sh"
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
  bash "${SCRIPT_DIR}/bedtool_evaluation.sh"
}

# Step 4 — Rebuild mouse_specific peaks as a proper MOUSE-coordinate narrowPeak file.
step_mouse_specific_to_mouse_coords() {
  local IN_PEAK="${CONSERVATIVE_PEAK_DIR}/mouse_specific_peaks_conservative.narrowPeak"
  local OUT_PEAK="${CONSERVATIVE_PEAK_DIR}/mouse_specific_peaks_conservative.mouse_coords.narrowPeak"

  # Col4 is always: chr:start-end:summit (HALPER). Join to mouse IDR on chr,start,end,summit = cols 1,2,3,10.
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

main "$@"
