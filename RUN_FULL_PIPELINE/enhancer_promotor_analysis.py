#!/usr/bin/env python3
"""
List HOMER nonRedundant motifs by assignment condition from filtered_annotations/*.txt.

  (a) Human enhancers: enhancer rows in shared_peaks + human_specific (hg38).
      Mouse enhancers: enhancer rows in shared_peaks + mouse_specific 
  (b) Human promoters: promoter rows in shared + human_specific.
      Mouse promoters: promoter rows in shared_peaks + mouse_specific.
  (c) Shared enhancers: enhancer rows in shared_peaks.txt only.
  (d) Species-specific enhancers: enhancer rows in human_specific vs mouse_specific.

A motif is listed if it has >=1 non-empty hit in that peak set. 
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def default_filtered_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "HOMER" / "filtered_annotations"


def default_out_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "motif_annotation_split"

# extract motifs with annotation
def motifs_with_annotation_hits(tsv_path: Path, annotation: str) -> set[str]:
    want = annotation.strip().lower()
    out: set[str] = set()
    with tsv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        motif_cols = list(reader.fieldnames[2:])
        for row in reader:
            if (row.get("Annotation") or "").strip().lower() != want:
                continue
            for col in motif_cols:
                if (row.get(col) or "").strip():
                    out.add(col)
    return out

# write sorted motif list
def write_sorted_motif_list(path: Path, motifs: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for m in sorted(motifs):
            f.write(m + "\n")

# main function
def main() -> Path:
    p = argparse.ArgumentParser(
        usage="%(prog)s [--filtered-dir DIR] [--out-dir DIR]",
    )
    p.add_argument(
        "--input-dir", # /ocean/projects/bio230007p/wli27/repo/looking_spleentacular/HOMER/filtered_annotations
        type=Path,
        default=default_filtered_dir(),
        metavar="DIR",
    )
    p.add_argument(
        "--output-dir", # /ocean/projects/bio230007p/wli27/repo/looking_spleentacular/HOMER_evaluation/motif_annotation_split
        type=Path,
        default=default_out_dir(),
        metavar="DIR",
    )
    args = p.parse_args()

    fd, out_dir = args.filtered_dir, args.out_dir
    shared = fd / "shared_peaks.txt"
    human_sp = fd / "human_specific.txt"
    mouse_sp = fd / "mouse_specific.txt"
    for path in (shared, human_sp, mouse_sp):
        if not path.is_file():
            raise SystemExit(f"Missing: {path}")

    sub = out_dir / "assignment_conditions"
    e, pr = "enhancer", "promoter"

    write_sorted_motif_list(
        sub / "human_enhancers_motifs.txt",
        motifs_with_annotation_hits(shared, e) | motifs_with_annotation_hits(human_sp, e),
    )
    write_sorted_motif_list(
        sub / "mouse_enhancers_motifs.txt",
        motifs_with_annotation_hits(shared, e) | motifs_with_annotation_hits(mouse_sp, e),
    )
    write_sorted_motif_list(
        sub / "human_promoters_motifs.txt",
        motifs_with_annotation_hits(shared, pr) | motifs_with_annotation_hits(human_sp, pr),
    )
    write_sorted_motif_list(
        sub / "mouse_promoters_motifs.txt",
        motifs_with_annotation_hits(shared, pr) | motifs_with_annotation_hits(mouse_sp, pr),
    )
    write_sorted_motif_list(
        sub / "shared_enhancers_across_species_motifs.txt",
        motifs_with_annotation_hits(shared, e),
    )
    write_sorted_motif_list(
        sub / "human_specific_enhancers_motifs.txt",
        motifs_with_annotation_hits(human_sp, e),
    )
    write_sorted_motif_list(
        sub / "mouse_specific_enhancers_motifs.txt",
        motifs_with_annotation_hits(mouse_sp, e),
    )

    print(sub)
    return sub


if __name__ == "__main__":
    main()
