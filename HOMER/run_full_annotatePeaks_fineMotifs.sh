#!/bin/bash

#SBATCH --job-name=homer
#SBATCH --output=homer_%j.log
#SBATCH --error=homer_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4        
#SBATCH --mem=8000M                
#SBATCH --time=8:00:00          
#SBATCH --account=bio230007p

# Usage check
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <narrowpeak_dir> </bin path> [wd]"
    echo "Example: $0 ./narrowPeak /ocean/projects/bio230007p/mccreary/bin ./"
    exit 1
fi

bash run_homer_on_dir.sh $1 $2
bash extract_promoters_enhancers.sh