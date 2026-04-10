process HUMAN_SCRUBBER_REPORT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(meta), path(raw_reads), path(clean_reads), path(kraken_report)

    output:
    tuple val(meta), path("*_human_scrubber_report.csv"), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: meta.id.split("_")[0]
    """
    human_scrubber_report.py \\
        --sample_id ${prefix} \\
        --raw_reads $raw_reads \\
        --clean_reads $clean_reads \\
        --kraken_report $kraken_report \\
        --output ${prefix}_human_scrubber_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
    END_VERSIONS
    """
}
