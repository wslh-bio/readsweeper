/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { UNTAR as UNTAR_KRAKEN2_DB     } from '../modules/nf-core/untar/main'
include { KRAKEN2_KRAKEN2               } from '../modules/nf-core/kraken2/kraken2/main'
include { HUMAN_SCRUBBER_REPORT         } from '../modules/local/human_scrubber_report/main'
include { COMBINE_REPORTS               } from '../modules/local/combine_reports/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow READSWEEPER {

    take:
    ch_samplesheet // Channel: samplesheet read in from --input
    
    main:

    ch_versions = Channel.empty()
    
    //
    // MODULE: Untar Kraken2 DB
    //
    UNTAR_KRAKEN2_DB (
        [ [:], params.kraken2_db ]
    )
    ch_kraken2_db = UNTAR_KRAKEN2_DB.out.untar.map { it[1] }
    ch_versions = ch_versions.mix(UNTAR_KRAKEN2_DB.out.versions.first())

    //
    // MODULE: Run Kraken2 for human read scrubbing
    //
    KRAKEN2_KRAKEN2 (
        ch_samplesheet,
        ch_kraken2_db,
        true,
        true
    )
    ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first())

    //
    // MODULE: Generate human scrubber report
    //
    HUMAN_SCRUBBER_REPORT (
        ch_samplesheet,
        KRAKEN2_KRAKEN2.out.unclassified_reads_fastq,
        KRAKEN2_KRAKEN2.out.report
    )
    ch_versions = ch_versions.mix(HUMAN_SCRUBBER_REPORT.out.versions.first())
    
    //
    // MODULE: Combine reports into single report for easier human readability
    //
    COMBINE_REPORTS (
        HUMAN_SCRUBBER_REPORT.out.report.map { it[1] }.collect()
    )    

    emit:
    reports = COMBINE_REPORTS.out.combined_report
    versions = ch_versions

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
