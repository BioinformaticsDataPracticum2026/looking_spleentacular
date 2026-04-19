# Usage check
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <narrowpeak_dir> </bin path> [wd]"
    echo "Example: $0 ./narrowPeak /ocean/projects/bio230007p/mccreary/bin ./"
    exit 1
fi

# Set HOMER path explicitly
export PATH="$2:$PATH"

# Set your working directory
cd "${3:-$PWD}"

NARROWPEAK_DIR="$1"
OUT_DIR="./homer_results"

# Validate inputs
if [ ! -d "$NARROWPEAK_DIR" ]; then
    echo "Error: directory '$NARROWPEAK_DIR' not found."
    exit 1
fi

command -v annotatePeaks.pl >/dev/null 2>&1 || { echo "Error: annotatePeaks.pl not found. Is HOMER installed?"; exit 1; }
command -v findMotifsGenome.pl >/dev/null 2>&1 || { echo "Error: findMotifsGenome.pl not found. Is HOMER installed?"; exit 1; }

mkdir -p "$OUT_DIR"

# --- Loop over all .narrowPeak files ---
for NARROWPEAK_FILE in "$NARROWPEAK_DIR"/*.narrowPeak; do
    # Set the correct genome
    if [[ "${NARROWPEAK_FILE,,}" == *mouse* ]]; then
        GENOME="mm10"
    else
        GENOME="hg38"
    fi

    # Get the base name without extension (e.g. "shared_peaks_conservative")
    BASENAME=$(basename "$NARROWPEAK_FILE" .narrowPeak)

    SAMPLE_DIR="${OUT_DIR}/${BASENAME}"
    MOTIF_DIR="${SAMPLE_DIR}/motifs"
    ANNO_FILE="${SAMPLE_DIR}/annotated_peaks.txt"

    echo ""
    echo "=== Processing: $BASENAME ==="
    mkdir -p "$SAMPLE_DIR" "$MOTIF_DIR"

    # --- Convert narrowPeak to HOMER-compatible BED ---
    echo "[0/2] Converting .narrowPeak to HOMER BED..."
    BED_FILE="${SAMPLE_DIR}/peaks_homer.bed"

    awk 'BEGIN{OFS="\t"} {
        chr=$1; start=$2; end=$3; name=$4; score=$5; strand=$6; summit=$10
        if (summit != -1 && summit != ".") {
            center = start + summit
            print chr, center-1, center, name, score, (strand=="." ? "+" : strand)
        } else {
            print chr, start, end, name, score, (strand=="." ? "+" : strand)
        }
    }' "$NARROWPEAK_FILE" > "$BED_FILE"

    echo "      Converted -> ${BED_FILE}"

    # --- 1. findMotifsGenome.pl ---
    echo "[1/2] Running findMotifsGenome.pl..."
    findMotifsGenome.pl \
        "$BED_FILE" \
        "$GENOME" \
        "$MOTIF_DIR" \
        -size 200 \
        -mask \
        2> "${SAMPLE_DIR}/findMotifs.log"

    if [ $? -eq 0 ]; then
        echo "      Motif finding complete -> ${MOTIF_DIR}"
    else
        echo "      Error in findMotifsGenome.pl. Check ${SAMPLE_DIR}/findMotifs.log"
        continue
    fi

    # --- 2. annotatePeaks.pl with motif output integration ---
    echo "[2/2] Running annotatePeaks.pl..."
    annotatePeaks.pl \
        "$BED_FILE" \
        "$GENOME" \
        -m "${MOTIF_DIR}/nonRedundant.motifs" \
        -mbed "${SAMPLE_DIR}/motif_instances.bed" \
        -size 200 \
        > "$ANNO_FILE" 2> "${SAMPLE_DIR}/annotatePeaks.log"

    if [ $? -eq 0 ]; then
        echo "      Annotation complete -> ${ANNO_FILE}"
    else
        echo "      Error in annotatePeaks.pl. Check ${SAMPLE_DIR}/annotatePeaks.log"
        continue  # Skip to next file instead of exiting
    fi

    echo "=== Done with $BASENAME! Results in: ${SAMPLE_DIR} ==="
    echo "  Annotated peaks : ${ANNO_FILE}"
    echo "  Motif results   : ${MOTIF_DIR}/homerResults.html"

done

echo ""
echo "=== All samples complete! Results in: ${OUT_DIR} ==="
