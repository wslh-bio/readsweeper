process HUMAN_SCRUBBER_REPORT {
    tag "$meta.id"
    label 'process_single'


    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
    tuple val(meta), path(raw_reads)
    tuple val(meta), path(clean_reads)
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path("*_final_report.csv"), emit: report
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    human_scrubber_report.py \\
        $args \\
        --sample_id ${meta.id} \\
        --raw_reads $raw_reads \\
        --clean_reads $clean_reads \\
        --kraken_report $kraken_report \\
        --output ${prefix}_final_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
    END_VERSIONS
    """
}