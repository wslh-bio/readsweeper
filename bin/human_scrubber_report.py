#!/usr/bin/env python3

import argparse
import pandas as pd
import logging
import sys
import os

logging.basicConfig(level = logging.INFO, format = '%(levelname)s : %(message)s')

def parse_kraken2_report(report_file):
    logging.info("Parsing the Kraken2 report file to create tsv file with sample name, percentage of human reads, number of human reads, percentage of unclassified reads, and number of unclassified reads")

    logging.info("Getting basename of the report file to use as sample name")
    #TODO:Need to make this more robust to only capture sample name that has ##VR######## or ##VQ######## pathern in the filename
    sample_name = os.path.basename(report_file).split('_')[0]

    logging.debug("Parsing the Kraken2 report file")
    kraken2_report_df = pd.read_csv(report_file, sep='\t', header=None, names=['Percentage', 'Reads_Clade', 'Reads_Taxon', 'Rank_Code', 'NCBI_TaxID', 'Taxon_Name'], dtype={'Percentage': float, 'Reads_Clade': int, 'Reads_Taxon': int, 'Rank_Code': str, 'NCBI_TaxID': str, 'Taxon_Name': str})
        
    # Strip leading and trailing whitespace from the Taxon_Name column
    kraken2_report_df["Taxon_Name"] = kraken2_report_df["Taxon_Name"].str.strip()   

    logging.info("Create column names for the output dataframe")
    df = pd.DataFrame(columns=['Sample', 'Percentage_Human_Reads', 'Number_Human_Reads', 'Percentage_Unclassified_Reads', 'Number_Unclassified_Reads'], 
                      dtype={'Sample': str, 'Percentage_Human_Reads': float, 'Number_Human_Reads': int, 'Percentage_Unclassified_Reads': float, 'Number_Unclassified_Reads': int})
    df['Sample'] = sample_name
    df['Percentage_Human_Reads'] = kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '9606', "Percentage"].iloc[0] if not kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '9606'].empty else 0
    df['Number_Human_Reads'] = kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '9606', "Reads_Taxon"].iloc[0] if not kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '9606'].empty else 0
    df['Percentage_Unclassified_Reads'] = kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '0', "Percentage"].iloc[0] if not kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '0'].empty else 0
    df['Number_Unclassified_Reads'] = kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '0', "Reads_Taxon"].iloc[0] if not kraken2_report_df.loc[kraken2_report_df["NCBI_TaxID"] == '0'].empty else 0

    logging.debug("Returning the dataframes")
    return kraken2_report_df, sample_name

#TODO: Need to write function to grab count data from the read count nextflow channel and put into dataframe with sample name and read count columns. Then merge this dataframe with the kraken2 report dataframe to get the percentage of human reads and unclassified reads for each sample. Then write the merged dataframe to a tsv file with the sample name as the filename and the columns: Sample, Percentage_Human_Reads, Number_Human_Reads, Percentage_Unclassified_Reads, Number_Unclassified_Reads
def parse_read_counts(read_counts_file):


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse the Kraken2 report file to create tsv file with sample name, percentage of human reads, number of human reads, percentage of unclassified reads, and number of unclassified reads")
    parser.add_argument("-r", "--report_file", required=True, help="Path to the Kraken2 report file")
    parser.add_argument("-c", "--read_counts_file", required=True, help="Path to the read counts file")
    args = parser.parse_args()

    kraken2_report_file = args.report_file
    read_counts_file = args.read_counts_file

    kraken2_report_df, sample_name = parse_kraken2_report(kraken2_report_file)
    read_counts_df = parse_read_counts(read_counts_file)
    merged_df = create_dataframe(read_counts_df, kraken2_report_df)

