#!/bin/bash

#SBATCH --job-name=full_ATAC_peak_analysis
#SBATCH --output=ATAC_%j.log
#SBATCH --error=ATAC_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4        
#SBATCH --mem=8000M                
#SBATCH --time=18:00:00          
#SBATCH --account=bio230007p

set -euo pipefail

SCRIPT_DIR="$SLURM_SUBMIT_DIR"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <.hal filepath> <halper_map_peak_orthologs.sh path> <bin_path>"
    exit 1
fi

HAL_FILE=$1
HALPER_MAP_SH=$2
BIN_PATH=$3

echo "Starting mapping with integrate_halper.sh..." # will produce "./output/Mouse/mapping/conservative", condensed into a narrowPeak file afterwards
bash "$SCRIPT_DIR/integrate_halper.sh" "$SCRIPT_DIR" "$HAL_FILE" "$HALPER_MAP"

# reformat narrowPeak output for downstream use
echo "Extracting relevant files for homer analysis..."
mkdir -p ./narrowPeak_for_homer

cp "./output/Mouse/mapping/conservative/shared_peaks_conservative.narrowPeak" \
   "./narrowPeak_for_homer/shared_peaks.narrowPeak"

cp "./output/Mouse/mapping/conservative/human_specific_peaks_conservative.narrowPeak" \
   "./narrowPeak_for_homer/human_specific.narrowPeak"

cp "./output/Mouse/mapping/conservative/mouse_specific_peaks_conservative.mouse_coords.narrowPeak" \
   "./narrowPeak_for_homer/mouse_specific.narrowPeak"

echo "Done. Files in ./narrowPeak_for_homer:"
ls ./narrowPeak_for_homer/

echo "Starting motif enrichment and peak annotation with run_homer_on_dir.sh..."
bash "$SCRIPT_DIR/run_full_annotatePeaks_findMotifs.sh" "./narrowPeak_for_homer" "$BIN_PATH" # should prouduce ./homer_results dir and ./filered_annotations dir

echo "Starting GO BP enrichment with rGREAT run_GO_pipeline.sh..."
bash "$SCRIPT_DIR/run_GO_pipeline.sh" "./filtered_annotations" # should produce ./rGREAT_results dir
echo "Done."