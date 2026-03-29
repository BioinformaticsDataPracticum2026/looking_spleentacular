#!/bin/bash
#SBATCH -A bio230007p        # your project/account
#SBATCH -p RM-shared          # or general / RM-shared partition
#SBATCH --time=06:00:00       # max runtime
#SBATCH -n 1               # 2 CPUs (halLiftover is mostly single-threaded; -n 1 is often enough)
#SBATCH --mem=2000         # 2000 MB total (~2 GB); raise if the step OOMs
#SBATCH -o unzip_narrowpeak_%j.out      # stdout log
#SBATCH -e unzip_narrowpeak_%j.err      # stderr log
#SBATCH -J unzip_narrowpeak # job name

module load anaconda3/2024.10-1
conda activate /ocean/projects/bio230007p/wli27/hal
export PATH=/ocean/projects/bio230007p/wli27/repos/hal/bin:${PATH}
export PYTHONPATH=/ocean/projects/bio230007p/wli27/repos/halLiftover-postprocessing:${PYTHONPATH}

cd /ocean/projects/bio230007p/wli27/MouseAtac/AdrenalGland/peak/idr_reproducibility
zcat idr.optimal_peak.narrowPeak.gz > idr.optimal_peak.narrowPeak

cd /ocean/projects/bio230007p/wli27/HumanAtac/peak/idr_reproducibility
zcat idr.optimal_peak.narrowPeak.gz > idr.optimal_peak.narrowPeak

