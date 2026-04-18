#!/bin/bash

# Check input arguments
if [ "$#" -lt 1 ]; then
    echo "[ERROR] Missing arguments!"
    echo "Usage: bash $0 <input_directory> [output_directory]"
    echo "Example: bash $0 ./peaks_folder ./my_results"
    exit 1
fi

INPUT_DIR=$1
OUT_DIR=${2:-"rGREAT_results"} # Default output to rGREAT_results directory

echo "Scanning directory [$INPUT_DIR] for peak files..."

# Fetch files precisely based on your actual filenames
MOUSE_SPEC=$(find "$INPUT_DIR" -maxdepth 1 -type f -name "*mouse_specific_peaks_conservative*.narrowPeak" | head -n 1)
HUMAN_SPEC=$(find "$INPUT_DIR" -maxdepth 1 -type f -name "*human_specific_peaks_conservative*.narrowPeak" | head -n 1)
CONS_MH=$(find "$INPUT_DIR" -maxdepth 1 -type f -name "*mouse_to_human_conservative*.narrowPeak" | head -n 1)
# Updated the keyword here to match human_conservative.sorted.narrowPeak
CONS_HM=$(find "$INPUT_DIR" -maxdepth 1 -type f -name "*human_conservative*.narrowPeak" | head -n 1)

# Verify all 4 files were found
if [[ -z "$MOUSE_SPEC" || -z "$HUMAN_SPEC" || -z "$CONS_MH" || -z "$CONS_HM" ]]; then
    echo "[ERROR] Could not find all 4 required .narrowPeak files in $INPUT_DIR."
    echo "Please check if all files are present in the directory."
    exit 1
fi

echo "------------"
echo "Successfully found matching files:"
echo "Mouse Specific: $MOUSE_SPEC"
echo "Human Specific: $HUMAN_SPEC"
echo "Conserved (M -> H): $CONS_MH"
echo "Conserved (H -> M): $CONS_HM"
echo "------------"
echo "Executing Rscript for analysis..."

# Pass arguments to R script
Rscript rgreat_pipeline.R "$MOUSE_SPEC" "$HUMAN_SPEC" "$CONS_MH" "$CONS_HM" "$OUT_DIR"

# Check execution result
if [ $? -eq 0 ]; then
    echo "✅ Analysis complete! Check the [$OUT_DIR] directory for results and plots."
else
    echo "❌ An error occurred. Analysis aborted."
fi

# bash run_pipeline.sh my_peaks