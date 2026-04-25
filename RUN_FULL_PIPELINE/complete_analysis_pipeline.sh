#!/bin/bash

#SBATCH --job-name=full_ATAC_peak_analysis
#SBATCH --output=ATAC_%j.log
#SBATCH --error=ATAC_%j.err
#SBATCH --partition=RM-shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4        
#SBATCH --mem=8000M                
#SBATCH --time=18:00:00          
#SBATCH --account=bio230007p

module load anaconda3
source /opt/packages/anaconda3-2024.10-1/etc/profile.d/conda.sh
conda activate atac_seq_analysis

set -euo pipefail

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(pwd -P)}"
echo "$SCRIPT_DIR"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <.hal filepath> <halper_map_peak_orthologs.sh path>"
    exit 1
fi

HAL_FILE=$1
HALPER_MAP=$2
BIN_PATH="$SCRIPT_DIR/bin"

echo "Starting mapping with integrate_halper.sh..." # will produce ".output/Mouse/mapping/conservative/"
bash "$SCRIPT_DIR/integrate_halper.sh" --base "$SCRIPT_DIR" --hal-file "$HAL_FILE" --halper-map "$HALPER_MAP"
echo "Mapping complete! Results in BASE/output/Mouse/mapping/conservative"

# reformat narrowPeak output for downstream use
echo "Extracting relevant files for homer analysis..."
mkdir -p "${SCRIPT_DIR}/narrowPeak_for_homer"

cp "${SCRIPT_DIR}/output/Mouse/mapping/conservative/shared_peaks_conservative.narrowPeak" \
   "${SCRIPT_DIR}/narrowPeak_for_homer/shared_peaks.narrowPeak"

cp "${SCRIPT_DIR}/output/Mouse/mapping/conservative/human_specific_peaks_conservative.narrowPeak" \
   "${SCRIPT_DIR}/narrowPeak_for_homer/human_specific.narrowPeak"

cp "${SCRIPT_DIR}/output/Mouse/mapping/conservative/mouse_specific_peaks_conservative.mouse_coords.narrowPeak" \
   "${SCRIPT_DIR}/narrowPeak_for_homer/mouse_specific.narrowPeak"

echo "Done. Files in BASE/narrowPeak_for_homer:"
ls "${SCRIPT_DIR}/narrowPeak_for_homer"

echo "Starting motif enrichment and peak annotation with run_homer_on_dir.sh..."
bash "$SCRIPT_DIR/run_full_annotatePeaks_findMotifs.sh" "./narrowPeak_for_homer" "$BIN_PATH" # should prouduce ./homer_results dir and ./filered_annotations dir
echo "Done! Results in BASE/homer_results and BASE/filtered_annotations"

echo "Starting enhancer_promotor_analysis.py..."
python "$SCRIPT_DIR/enhancer_promotor_analysis.py" --input-dir "./filtered_annotations" # should produce motif_annotation_split dir
echo "Done! Results in BASE/motif_annotation_split"

echo "Starting GO BP enrichment with rGREAT run_GO_pipeline.sh..."
bash "$SCRIPT_DIR/run_GO_pipeline.sh" "./output/Mouse/mapping/conservative" # should produce ./rGREAT_results dir
echo "Done! Results in BASE/rGREAT_results"

echo "Full pipeline complete"