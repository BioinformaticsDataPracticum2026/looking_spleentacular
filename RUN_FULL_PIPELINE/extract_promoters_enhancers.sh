if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [wd]"
    echo "This script takes only an optional wd argument"
    exit 1
fi

cd "${1:-$PWD}"

HOMER_RESULTS_DIR="./homer_results"
OUT_DIR="./filtered_annotations"

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
        n_motifs=0
        for (i=2; i<=NF; i++) {
            if ($i=="Annotation") annot=i
            if ($i=="Distance to TSS") dist=i
            if ($i ~ /Distance From Peak/) motif_cols[n_motifs++]=i
        }
        header = "PeakID\tAnnotation"
        for (m=0; m<n_motifs; m++) {
            header = header "\t" $motif_cols[m]
        }
        print header
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
            row = $id "\t" new_annot
            for (m=0; m<n_motifs; m++) {
                row = row "\t" $motif_cols[m]
            }
            print row
        }
        
    }' "$input" > "$output"

done

Rscript plot_promoters_enhancers.R
Rscript motif_table.R