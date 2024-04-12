def get_genomad_path() -> Path:
    for fp in sys.path:
        if fp.split("/")[-1] == "sbx_genomad":
            return Path(fp)
    raise Error(
        "Filepath for sbx_genomad not found, are you sure it's installed under extensions/sbx_genomad?"
    )


SBX_GENOMAD_VERSION = open(get_genomad_path() / "VERSION").read().strip()

VIRUS_FP = Cfg["all"]["output_fp"] / "virus"

try:
    BENCHMARK_FP
except NameError:
    BENCHMARK_FP = output_subdir(Cfg, "benchmarks")
try:
    LOG_FP
except NameError:
    LOG_FP = output_subdir(Cfg, "logs")


localrules:
    all_genomad,


rule all_genomad:
    input:
        expand(
            VIRUS_FP
            / "genomad"
            / "{sample}"
            / "final.contigs_summary"
            / "final.contigs_virus_summary.tsv",
            sample=Samples.keys(),
        ),


rule genomad_download_db:
    """Download Genomad database"""
    output:
        version=Path(Cfg["sbx_genomad"]["genomad_db"]) / "genomad_db" / "version.txt",
    log:
        LOG_FP / "genomad_download_db.log",
    benchmark:
        BENCHMARK_FP / "genomad_download_db.tsv"
    conda:
        "envs/sbx_genomad_env.yml"
    container:
        f"docker://sunbeamlabs/sbx_genomad:{SBX_GENOMAD_VERSION}"
    shell:
        """
        GENOMAD_DB_DIR=$(dirname {output.version})
        genomad download-database $(dirname "$GENOMAD_DB_DIR") 2>&1 | tee {log}
        """


rule genomad_end_to_end:
    """Run Genomad end-to-end pipeline"""
    input:
        contigs=ASSEMBLY_FP / "megahit" / "{sample}_asm" / "final.contigs.fa",
        db_version=Path(Cfg["sbx_genomad"]["genomad_db"]) / "genomad_db" / "version.txt",
    output:
        assembly_summary=VIRUS_FP
        / "genomad"
        / "{sample}"
        / "final.contigs_summary"
        / "final.contigs_virus_summary.tsv",
        assembly_fna=VIRUS_FP
        / "genomad"
        / "{sample}"
        / "final.contigs_summary"
        / "final.contigs_virus.fna",
        prophage_summary=VIRUS_FP
        / "genomad"
        / "{sample}"
        / "final.contigs_find_proviruses"
        / "final.contigs_provirus.tsv",
        prophage_fna=VIRUS_FP
        / "genomad"
        / "{sample}"
        / "final.contigs_find_proviruses"
        / "final.contigs_provirus.fna",
    log:
        LOG_FP / "genomad_end_to_end_{sample}.log",
    benchmark:
        BENCHMARK_FP / "genomad_end_to_end_{sample}.tsv"
    conda:
        "envs/sbx_genomad_env.yml"
    container:
        f"docker://sunbeamlabs/sbx_genomad:{SBX_GENOMAD_VERSION}"
    shell:
        """
        ASSEMBLY_SUMMARY_DIR=$(dirname {output.assembly_summary})
        DB_DIR=$(dirname {input.db_version})
        
        if [ ! -s {input.contigs} ]; then
            touch {output.assembly_summary}
            touch {output.assembly_fna}
            touch {output.prophage_summary}
            touch {output.prophage_fna}
        else
            genomad end-to-end --cleanup --splits 8 {input.contigs} $(dirname "$ASSEMBLY_SUMMARY_DIR") $DB_DIR 2>&1 | tee {log}
        fi
        """


rule genomad_map_to_prophage:
    """Map reads to prophage regions"""
    input:
        reads=expand(QC_FP / "decontam" / "{{sample}}_{rp}.fastq.gz", rp=Pairs),
        prophage_fna=VIRUS_FP
        / "genomad"
        / "{sample}"
        / "final.contigs_find_proviruses"
        / "final.contigs_provirus.fna",
    output:
        VIRUS_FP / "genomad" / "{sample}_prophage.mpileup",
    log:
        LOG_FP / "genomad_filter_for_prophage_{sample}.log",
    benchmark:
        BENCHMARK_FP / "genomad_filter_for_prophage_{sample}.tsv"
    shell:
        """
        bwa map 
        """
