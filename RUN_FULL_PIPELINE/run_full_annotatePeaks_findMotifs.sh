#!/bin/bash

#SBATCH --job-name=homer
#SBATCH --output=homer_%j.log
#SBATCH --error=homer_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4        
#SBATCH --mem=8000M                
#SBATCH --time=8:00:00          
#SBATCH --account=bio230007p

set -euo pipefail

SCRIPT_DIR="$SLURM_SUBMIT_DIR"
WD="${3:-}"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <narrowpeak_dir> <bin_path> [wd]"
    echo "Example: $0 ./narrowPeak /ocean/projects/bio230007p/mccreary/bin ./"
    exit 1
fi

echo "Starting run_homer_on_dir.sh..."
bash "$SCRIPT_DIR/run_homer_on_dir.sh" "$1" "$2" ${WD:+"$WD"}
echo "Starting extract_promoters_enhancers.sh..."
bash "$SCRIPT_DIR/extract_promoters_enhancers.sh" ${WD:+"$WD"}
echo "Done."