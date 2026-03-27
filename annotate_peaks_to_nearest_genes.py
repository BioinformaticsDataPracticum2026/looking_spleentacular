#!/usr/bin/env python3

import argparse
import bisect
import csv
import gzip
import re
from collections import defaultdict


ATTR_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*) "([^"]+)"')


def parse_args():
    parser = argparse.ArgumentParser(
        description="Annotate BED peaks to the nearest gene TSS from a GTF file."
    )
    parser.add_argument("--peaks", required=True, help="Input BED file with at least 3 columns")
    parser.add_argument("--gtf", required=True, help="Input GTF or GTF.gz file")
    parser.add_argument("--out-tsv", required=True, help="Output annotated TSV")
    parser.add_argument("--out-genes", required=True, help="Output unique gene list TXT")
    return parser.parse_args()


def open_text(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "r")


def parse_attributes(field):
    attrs = {}
    for key, value in ATTR_RE.findall(field):
        attrs[key] = value
    return attrs


def load_tss_by_chrom(gtf_path):
    tss_by_chrom = defaultdict(list)
    with open_text(gtf_path) as handle:
        for line in handle:
            if not line or line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 9 or fields[2] != "gene":
                continue

            chrom, _, _, start, end, _, strand, _, attrs = fields
            attr_map = parse_attributes(attrs)
            gene_name = attr_map.get("gene_name", attr_map.get("gene_id", "NA"))
            gene_id = attr_map.get("gene_id", "NA")
            gene_type = attr_map.get("gene_type", attr_map.get("gene_biotype", "NA"))

            start_i = int(start)
            end_i = int(end)
            tss = start_i - 1 if strand == "+" else end_i - 1
            tss_by_chrom[chrom].append((tss, gene_name, gene_id, gene_type, strand))

    for chrom in tss_by_chrom:
        tss_by_chrom[chrom].sort(key=lambda item: item[0])
    return tss_by_chrom


def nearest_gene(chrom, midpoint, tss_by_chrom):
    if chrom not in tss_by_chrom:
        return ("NA", "NA", "NA", "NA", "NA")

    items = tss_by_chrom[chrom]
    positions = [item[0] for item in items]
    idx = bisect.bisect_left(positions, midpoint)

    candidates = []
    if idx < len(items):
        candidates.append(items[idx])
    if idx > 0:
        candidates.append(items[idx - 1])

    best = min(candidates, key=lambda item: abs(item[0] - midpoint))
    distance = midpoint - best[0]
    return best[1], best[2], best[3], best[4], distance


def annotate_peaks(peaks_path, tss_by_chrom, out_tsv, out_genes):
    gene_set = set()
    with open(peaks_path, "r") as peaks_handle, open(out_tsv, "w", newline="") as out_handle:
        writer = csv.writer(out_handle, delimiter="\t")
        writer.writerow([
            "chrom",
            "start",
            "end",
            "peak_midpoint",
            "nearest_gene_name",
            "nearest_gene_id",
            "nearest_gene_type",
            "nearest_gene_strand",
            "distance_to_tss",
        ])

        for line in peaks_handle:
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            chrom = fields[0]
            start = int(fields[1])
            end = int(fields[2])
            midpoint = (start + end) // 2
            gene_name, gene_id, gene_type, strand, distance = nearest_gene(chrom, midpoint, tss_by_chrom)

            if gene_name != "NA":
                gene_set.add(gene_name)

            writer.writerow([
                chrom,
                start,
                end,
                midpoint,
                gene_name,
                gene_id,
                gene_type,
                strand,
                distance,
            ])

    with open(out_genes, "w") as genes_handle:
        for gene in sorted(gene_set):
            genes_handle.write(f"{gene}\n")


def main():
    args = parse_args()
    tss_by_chrom = load_tss_by_chrom(args.gtf)
    annotate_peaks(args.peaks, tss_by_chrom, args.out_tsv, args.out_genes)


if __name__ == "__main__":
    main()