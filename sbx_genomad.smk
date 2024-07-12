def get_genomad_path() -> Path:
    for fp in sys.path:
        if fp.split("/")[-1] == "sbx_genomad":
            return Path(fp)
    raise Error(
        "Filepath for sbx_genomad not found, are you sure it's installed under extensions/sbx_genomad?"
    )


SBX_GENOMAD_VERSION = open(get_genomad_path() / "VERSION").read().strip()

VIRUS_FP = Cfg["all"]["output_fp"] / "virus"
GENOMAD_FP = VIRUS_FP / "genomad"

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
            GENOMAD_FP
            / "{sample}"
            / "final.contigs_summary"
            / "final.contigs_virus_summary.tsv",
            sample=Samples.keys(),
        ),
        expand(GENOMAD_FP / "{sample}" / "prophage.mpileup", sample=Samples.keys()),


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
        assembly_summary=GENOMAD_FP
        / "{sample}"
        / "final.contigs_summary"
        / "final.contigs_virus_summary.tsv",
        assembly_fna=GENOMAD_FP
        / "{sample}"
        / "final.contigs_summary"
        / "final.contigs_virus.fna",
        prophage_summary=GENOMAD_FP
        / "{sample}"
        / "final.contigs_find_proviruses"
        / "final.contigs_provirus.tsv",
        prophage_fna=GENOMAD_FP
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


rule genomad_build_index:
    input:
        Cfg["sbx_genomad"]["ref_fp"],
    output:
        [
            str(Cfg["sbx_genomad"]["ref_fp"]) + ext
            for ext in [
                ".1.bt2",
                ".2.bt2",
                ".3.bt2",
                ".4.bt2",
                ".rev.1.bt2",
                ".rev.2.bt2",
            ]
        ],
    log:
        LOG_FP / "genomad_build_index.log",
    benchmark:
        BENCHMARK_FP / "genomad_build_index.tsv"
    conda:
        "envs/mapping_env.yml"
    container:
        f"docker://sunbeamlabs/sbx_genomad_mapping:{SBX_GENOMAD_VERSION}"
    shell:
        """
        bowtie2-build {input} {input} 2>&1 | tee {log}
        """


rule genomad_map_to_prophage:
    """Map reads to prophage regions"""
    input:
        prophage_fna=GENOMAD_FP
        / "{sample}"
        / "final.contigs_find_proviruses"
        / "final.contigs_provirus.fna",
        index=Cfg["sbx_genomad"]["ref_fp"],
        indexes=[
            str(Cfg["sbx_genomad"]["ref_fp"]) + ext
            for ext in [
                ".1.bt2",
                ".2.bt2",
                ".3.bt2",
                ".4.bt2",
                ".rev.1.bt2",
                ".rev.2.bt2",
            ]
        ],
    output:
        sam=temp(GENOMAD_FP / "{sample}" / "prophage.sam"),
        bam=temp(GENOMAD_FP / "{sample}" / "prophage.bam"),
        mpileup=GENOMAD_FP / "{sample}" / "prophage.mpileup",
    log:
        LOG_FP / "genomad_filter_for_prophage_{sample}.log",
    benchmark:
        BENCHMARK_FP / "genomad_filter_for_prophage_{sample}.tsv"
    conda:
        "envs/mapping_env.yml"
    container:
        f"docker://sunbeamlabs/sbx_genomad_mapping:{SBX_GENOMAD_VERSION}"
    shell:
        """
        if [ ! -s {input.prophage_fna} ]; then
            touch {output}
        else
            bowtie2 -p 8 -x {input.index} -f {input.prophage_fna} -S {output.sam}
            samtools view -S -b {output.sam} | samtools sort -o {output.bam}
            samtools index {output.bam}
            samtools mpileup -A -a -Q 0 -o {output.mpileup} -f {input.index} {output.bam}
        fi
        """
