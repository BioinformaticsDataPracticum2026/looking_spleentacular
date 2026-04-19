set -euo pipefail

DEFAULT_BASE="/ocean/projects/bio230007p/wli27"
BASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--base DIR]  (default DIR: ${DEFAULT_BASE})"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--base DIR]" >&2
      exit 1
      ;;
  esac
done

BASE="${BASE:-$DEFAULT_BASE}"
BASE="${BASE%/}"

HALPER_OUT="${BASE}/output/Mouse/mapping/conservative"
HUMAN_CONSERVATIVE_NARROWPEAK="${BASE}/HumanAtac/peak/idr_reproducibility/idr.conservative_peak.narrowPeak"

cd "${HALPER_OUT}"

# psc module load bedtools
module load bedtools
# Unzip the target file with HALPER filter
gunzip -c idr.conservative_peak.MouseToHuman.HALPER.narrowPeak.gz > mouse_to_human_conservative.narrowPeak

# can sort for quick use, optional
sort -k1,1 -k2,2n mouse_to_human_conservative.narrowPeak > mouse_to_human_conservative.sorted.narrowPeak

sort -k1,1 -k2,2n "${HUMAN_CONSERVATIVE_NARROWPEAK}" > human_conservative.sorted.narrowPeak

# shared mapped
bedtools intersect -a mouse_to_human_conservative.sorted.narrowPeak -b human_conservative.sorted.narrowPeak -u > shared_peaks_conservative.narrowPeak

# Mouse specific (actually mouse_nonreciprocal_peaks)
bedtools intersect -a mouse_to_human_conservative.sorted.narrowPeak -b human_conservative.sorted.narrowPeak -v > mouse_specific_peaks_conservative.narrowPeak

# Human specific
bedtools intersect -a human_conservative.sorted.narrowPeak -b mouse_to_human_conservative.sorted.narrowPeak -v > human_specific_peaks_conservative.narrowPeak
