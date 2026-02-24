process HUMAN_SCRUBBER_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0f/0f827dcea51be6b5c32255167caa2dfb65607caecdc8b067abd6b71c267e2e82/data' :
        'community.wave.seqera.io/library/kraken2_coreutils_pigz:920ecc6b96e2ba71' }"

    input:
    tuple val(meta), path(read_counts)
    tuple val(meta), path(report_file)

    output:
    tuple val(meta), path "${report_file}", emit: report

    when:
    params.human_scrubber_report

    script:
    """
    human_scrubber_report.py \\
        --read-counts ${read_counts} \\
        --kraken2-report ${report_file} \\
        --output ${report_file}
    """
}   

