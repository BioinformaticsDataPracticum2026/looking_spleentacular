#!/usr/bin/env python3

import argparse
import math
from pathlib import Path

import matplotlib.pyplot as plt
from gprofiler import GProfiler


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run GO:BP enrichment with g:Profiler from a gene list."
    )
    parser.add_argument("--genes", required=True, help="Text file with one gene symbol per line")
    parser.add_argument("--organism", required=True, choices=["hsapiens", "mmusculus"])
    parser.add_argument("--label", required=True, help="Label for outputs and plots")
    parser.add_argument("--outdir", required=True, help="Output directory")
    parser.add_argument("--topn", type=int, default=15, help="Number of top terms to plot")
    return parser.parse_args()


def read_genes(path):
    genes = []
    with open(path, "r") as handle:
        for line in handle:
            gene = line.strip()
            if gene:
                genes.append(gene)
    return sorted(set(genes))


def main():
    args = parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    genes = read_genes(args.genes)
    if not genes:
        raise SystemExit("No genes found in input gene list")

    gp = GProfiler(return_dataframe=True)
    results = gp.profile(
        organism=args.organism,
        query=genes,
        sources=["GO:BP"],
        user_threshold=0.05,
        no_evidences=False,
    )

    if results is None or results.empty:
        empty_path = outdir / f"{args.label}.go_bp.tsv"
        empty_path.write_text("No significant GO:BP terms found\n")
        return

    results = results.sort_values(by=["p_value", "term_size"], ascending=[True, False])
    results["neg_log10_p"] = results["p_value"].apply(lambda value: -math.log10(value) if value > 0 else 300.0)
    results.to_csv(outdir / f"{args.label}.go_bp.tsv", sep="\t", index=False)

    plot_df = results.head(args.topn).copy()
    plot_df = plot_df.sort_values(by="neg_log10_p", ascending=True)

    plt.figure(figsize=(10, max(5, len(plot_df) * 0.35)))
    plt.barh(plot_df["name"], plot_df["neg_log10_p"], color="#3B82F6")
    plt.xlabel("-log10 adjusted p-value")
    plt.ylabel("GO Biological Process")
    plt.title(f"GO:BP enrichment for {args.label}")
    plt.tight_layout()
    plt.savefig(outdir / f"{args.label}.go_bp.top_terms.png", dpi=200)
    plt.close()


if __name__ == "__main__":
    main()