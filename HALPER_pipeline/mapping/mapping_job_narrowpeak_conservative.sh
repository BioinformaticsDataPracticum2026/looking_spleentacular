#!/bin/bash
#SBATCH -A bio230007p        #  project/account
#SBATCH -p RM-shared          # RM-shared partition
#SBATCH --time=06:00:00       # max runtime
#SBATCH -n 2               # 2 CPUs 
#SBATCH --mem=2000         # 2000 MB total (~2 GB)
#SBATCH -o halper_%j.out      # stdout log
#SBATCH -e halper_%j.err      # stderr log
#SBATCH -J halper_mouse2human_adrenal_conservative # job name

# prepare the conda environment in psc
module load anaconda3/2024.10-1
conda activate /ocean/projects/bio230007p/wli27/hal
export PATH=/ocean/projects/bio230007p/wli27/repos/hal/bin:${PATH}
export PYTHONPATH=/ocean/projects/bio230007p/wli27/repos/halLiftover-postprocessing:${PYTHONPATH}

# run the .sh to mapping mouse into human genome with conservative peak
# -b is the input narrowPeak file
# -o is the output directory
# -s is the source genome of mouse
# -t is the target genome of human
# -c is the hal file
bash /ocean/projects/bio230007p/wli27/repos/halLiftover-postprocessing/halper_map_peak_orthologs.sh \
  -b /ocean/projects/bio230007p/wli27/MouseAtac/AdrenalGland/peak/idr_reproducibility/idr.conservative_peak.narrowPeak \ 
  -o /ocean/projects/bio230007p/wli27/output/Mouse/mapping/conservative/ \ 
  -s Mouse \ 
  -t Human \ 
  -c /ocean/projects/bio230007p/ikaplow/Alignments/10plusway-master.hal 
