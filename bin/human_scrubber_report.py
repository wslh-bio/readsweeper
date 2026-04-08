#!/usr/bin/env python3

import sys
import os
import gzip
import csv
import logging
import argparse

logging.basicConfig(level=logging.INFO, format="%(levelname)s : %(message)s")

def count_reads(path):
    """Count reads in FASTQ."""
    opener = gzip.open if path.endswith(".gz") else open

    try:
        with opener(path, "rt") as f:
            lines = sum(1 for _ in f)
    except Exception as e:
        logging.error(f"Cannot read FASTQ {path}: {e}")
        sys.exit(1)

    if lines % 4:
        logging.warning(f"FASTQ not divisible by 4 (possible malformed): {path}")

    return lines // 4


def parse_kraken_report(path):
    """Extract unclassified + human read stats from Kraken2 report."""
    stats = {
        "unclassified_reads": 0,
        "unclassified_reads_pct": 0.0,
        "human_reads": 0,
        "human_reads_pct": 0.0,
    }

    try:
        with open(path) as f:
            for line in f:
                parts = line.split("\t")
                if len(parts) < 6:
                    continue

                try:
                    pct = float(parts[0])
                    reads = int(parts[1])
                except ValueError:
                    continue

                rank, taxid = parts[3], parts[4]

                if rank == "U":
                    stats["unclassified_reads"] = reads
                    stats["unclassified_reads_pct"] = pct

                if taxid == "9606":
                    stats["human_reads"] = reads
                    stats["human_reads_pct"] = pct

    except Exception as e:
        logging.error(f"Cannot parse Kraken report {path}: {e}")
        sys.exit(1)

    return stats



def write_csv(path, row):
    """Write a single-row CSV."""
    fields = [
        "sample_id",
        "raw_read_1", "raw_read_2",
        "clean_read_1", "clean_read_2",
        "unclassified_reads", "unclassified_reads_pct",
        "human_reads", "human_reads_pct",
    ]

    try:
        with open(path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerow(row)
    except Exception as e:
        logging.error(f"Cannot write CSV {path}: {e}")
        sys.exit(1)

    logging.info(f"Report written: {path}")


def process(raw, clean, kraken, output, sample_id):
    logging.info("Counting FASTQ reads")
    raw_counts = [count_reads(f) for f in raw]
    clean_counts = [count_reads(f) for f in clean]

    logging.info("Parsing Kraken2 report")
    stats = parse_kraken_report(kraken)

    sample_id = sample_id or os.path.basename(output).replace("_final_report.csv", "")

    row = {
        "sample_id": sample_id,
        "raw_read_1": raw_counts[0] if raw_counts else 0,
        "raw_read_2": raw_counts[1] if len(raw_counts) > 1 else 0,
        "clean_read_1": clean_counts[0] if clean_counts else 0,
        "clean_read_2": clean_counts[1] if len(clean_counts) > 1 else 0,
        "unclassified_reads": stats["unclassified_reads"],
        "unclassified_reads_pct": round(stats["unclassified_reads_pct"], 2),
        "human_reads": stats["human_reads"],
        "human_reads_pct": round(stats["human_reads_pct"], 2),
    }

    write_csv(output, row)


class ReadReportParser(argparse.ArgumentParser):
    def error(self, msg):
        self.print_help()
        sys.stderr.write(f"\nERROR: {msg}\n")
        sys.exit(1)


if __name__ == "__main__":
    parser = ReadReportParser(
        description="Generate a CSV report with read counts and Kraken2 classification stats."
    )

    parser.add_argument(
        "--sample_id",
        help="Sample ID for the report"
    )
    parser.add_argument(
        "--raw_reads",
        nargs="+",
        required=True,
        help="List of raw read files"
    )
    parser.add_argument(
        "--clean_reads",
        nargs="+",
        required=True,
        help="List of clean read files"
    )
    parser.add_argument(
        "--kraken_report",
        required=True,
        help="Kraken2 report file"
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output CSV file"
    )

    args = parser.parse_args()

    logging.info("Processing input files")
    process(args.raw_reads, args.clean_reads, args.kraken_report, args.output, args.sample_id)
