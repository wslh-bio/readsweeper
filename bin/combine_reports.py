#!/usr/bin/env python3
import argparse
import logging
import os
import sys

import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(levelname)s : %(message)s")

FIELDS = [
    "sample_id",
    "raw_read_1", "raw_read_2",
    "clean_read_1", "clean_read_2",
    "unclassified_reads", "unclassified_reads_pct",
    "human_reads", "human_reads_pct",
]


def validate_files(report_files):
    """Check for duplicate filenames and that all files exist."""
    filenames = [os.path.basename(f) for f in report_files]
    duplicates = [f for f in filenames if filenames.count(f) > 1]
    if duplicates:
        raise ValueError(f"Duplicate report filenames detected: {set(duplicates)}")

    for f in report_files:
        if not os.path.exists(f):
            raise FileNotFoundError(f"Report file not found: {f}")


def combine_reports(report_files, output_file):
    """Read, combine, and reorder CSV report files into a single output."""
    logging.info(f"Received {len(report_files)} report(s) to combine")

    validate_files(report_files)

    combined = pd.concat(
        [pd.read_csv(f) for f in report_files],
        ignore_index=True
    )
    logging.info(f"Combined dataframe has {len(combined)} row(s)")
    
    combined = combined.reindex(columns=FIELDS)

    combined.to_csv(output_file, index=False)
    logging.info(f"Combined report written to {output_file}")


class ReportParser(argparse.ArgumentParser):
    def error(self, msg):
        self.print_help()
        sys.stderr.write(f"\nERROR: {msg}\n")
        sys.exit(1)


if __name__ == "__main__":
    parser = ReportParser(description="Combine multiple CSV report files into one.")

    parser.add_argument(
        "--reports",
        nargs="+",
        required=True,
        help="CSV report files to combine"
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output CSV file"
    )

    args = parser.parse_args()

    logging.info(f"Combining {len(args.reports)} report(s) into {args.output}")
    combine_reports(args.reports, args.output)