/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                        } from '../modules/nf-core/fastqc/main'
include { UNTAR as UNTAR_KRAKEN2_DB     } from '../modules/nf-core/untar/main'
include { KRAKEN2_KRAKEN2               } from '../modules/nf-core/kraken2/kraken2/main'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap              } from 'plugin/nf-schema'
include { paramsSummaryMultiqc          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText        } from '../subworkflows/local/utils_nfcore_readsweeper_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow READSWEEPER {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()
    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())


    if (params.protocol == 'taxinomic-classification') {
        //
        // MODULE: Untar Kraken2 DB
        //
        UNTAR_KRAKEN2_DB (
            [ [:], params.kraken2_db ]
        )
        ch_kraken2_db = UNTAR_KRAKEN2_DB.out.untar.map { it[1] }
        ch_versions   = ch_versions.mix(UNTAR_KRAKEN2_DB.out.versions)


        //
        // MODULE: Run Kraken2
        //
        ch_kraken2_multiqc = Channel.empty()
        KRAKEN2_KRAKEN2 (
            ch_samplesheet,
            ch_kraken2_db,
            false,
            true
        )
        ch_kraken2_multiqc = KRAKEN2_KRAKEN2.out.report
        ch_versions        = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first().ifEmpty(null))


        //
        // Module: Krona tools for visualization (optional, not implemented here)
        //


        //
        // Module: Pavian for visualization (optional, not implemented here)
        //


    } else if (params.protocol == 'human-read-scrubbing') {
        
        //
        // MODULE: Untar Kraken2 DB
        //
        UNTAR_KRAKEN2_DB (
            [ [:], params.kraken2_db ]
        )
        ch_kraken2_db = UNTAR_KRAKEN2_DB.out.untar.map { it[1] }
        ch_versions   = ch_versions.mix(UNTAR_KRAKEN2_DB.out.versions.first())

        ch_versions.view()
        //
        // MODULE: Run Kraken2
        //
        KRAKEN2_KRAKEN2 (
            ch_samplesheet,
            ch_kraken2_db,
            true,
            true
        )
        ch_multiqc_files =  ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.report.collect{it[1]}.ifEmpty([]))
        ch_versions        = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first())


        //
        // Module: Rename unclassified reads to final output scrubbed reads
        // (not implemented here, but would be a simple file move/rename)
        //
    }

    // Fastq Read counts; check if samples have matching read counts between R1 and R2 and if not mathcing exit with warning
    ch_raw_read_counts = ch_samplesheet.map { meta, file ->
        def sample_id = meta.id
        def raw_read1_count = file[0].countFastq()
        def raw_read2_count = file[1].countFastq()

        if (raw_read1_count != raw_read2_count) {
            log.warn("Warning: Read counts between read 1 and read 2 do not match for sample ${sample_id}: Read1(${raw_read1_count}) vs Read2(${raw_read2_count})")
        }
        return [sample_id, [raw_read1_count, raw_read2_count]]
    }
    
    ch_cleaned_read_counts = KRAKEN2_KRAKEN2.out.unclassified_reads_fastq.map { meta, file ->
        def sample_id = meta.id
        def clean_read1_count = file[0].countFastq()
        def clean_read2_count = file[1].countFastq()
        if (clean_read1_count != clean_read2_count) {
            log.warn("Warning: Read counts between read 1 and read 2 do not match for sample ${sample_id}: Read1(${clean_read1_count}) vs Read2(${clean_read2_count})")
        }
        return [sample_id, [clean_read1_count, clean_read2_count]]
    }

    // Check to make sure read counts for read1 and read2 match
    ch_read_counts_summary = ch_raw_read_counts.join(ch_cleaned_read_counts).map { sample_id, raw_counts, clean_counts ->
        def raw_read1_count = raw_counts[0]
        def raw_read2_count = raw_counts[1]
        def clean_read1_count = clean_counts[0]
        def clean_read2_count = clean_counts[1]       
        return [sample_id, raw_read1_count, raw_read2_count, clean_read1_count, clean_read2_count]
    }

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'readsweeper_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
