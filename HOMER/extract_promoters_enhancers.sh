#!/bin/bash

#SBATCH --job-name=annotation
#SBATCH --output=annotation_%j.log
#SBATCH --error=annotation_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2000M
#SBATCH --time=0:30:00
#SBATCH --account=bio230007p

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <homer_results_dir> [output_dir]"
    echo "Example: $0 ./homer_results ./peak_types"
    exit 1
fi

cd /ocean/projects/bio230007p/mccreary

HOMER_RESULTS_DIR="$1"
OUT_DIR="${2:-./peak_types}"

mkdir -p "$OUT_DIR"

if [ ! -d "$HOMER_RESULTS_DIR" ]; then
    echo "Error: directory '$HOMER_RESULTS_DIR' not found."
    exit 1
fi

for dir in "$HOMER_RESULTS_DIR"/*/; do
    subdir=$(basename "$dir")
    input="${dir}annotated_peaks.txt"
    output="${OUT_DIR}/${subdir}.txt"

    awk -F'\t' 'BEGIN {OFS="\t"}
    NR==1 {
        id=1
        for (i=2; i<=NF; i++) {
            if ($i=="Annotation") annot=i
            if ($i=="Distance to TSS") dist=i
        }
        print "PeakID", "Annotation"
        next
    }
    {
        new_annot = ""
        if (((tolower($annot) ~ /intergenic/ || tolower($annot) ~ /intron/) && $dist >= 2000) || (tolower($annot) ~ /enhancer/)) {
            new_annot = "enhancer"
        } else if (tolower($annot) ~ /promoter/) {
            new_annot  = "promoter"
        }

        if (new_annot != ""){
            print $id, new_annot
        }
        
    }' "$input" > "$output"

done

Rscript plot_promoters_enhancers.R