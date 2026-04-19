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

# NEED TO FINALIZE INPUTS (is .hal only one peak set?)
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <.hal filepath> <halper_map_peak_orthologs.sh path> <bin_path>"
    exit 1
fi

HAL_FILE=$1
HALPER_MAP_SH=$2
BIN_PATH=$3

# NEED TO COPY ALL RELEVANT SCRIPTS INTO DIRECTORY
echo "Starting mapping with integrate_halper.sh..." # should produce narrowPeak dir
bash "$SCRIPT_DIR/integrate_halper.sh" "$SCRIPT_DIR" "$HAL_FILE" "$HALPER_MAP"
echo "Starting motif enrichment and peak annotation with run_homer_on_dir.sh..."
bash "$SCRIPT_DIR/run_full_annotatePeaks_findMotifs.sh" "./narrowPeak" "$BIN_PATH" # should prouduce ./homer_results dir and ./filered_annotations dir
echo "Starting GO BP enrichment with rGREAT run_GO_pipeline.sh..."
bash "$SCRIPT_DIR/run_GO_pipeline.sh" "./filtered_annotations" # should produce ./rGREAT_results dir
echo "Done."