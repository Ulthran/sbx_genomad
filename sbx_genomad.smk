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
        expand(VIRUS_FP / "genomad" / "{sample}", sample=Samples),


rule genomad_download_db:
    """Download Genomad database"""
    output:
        dir(Cfg["sbx_genomad"]["genomad_db"]),
    log:
        LOG_FP / "example_rule.log",
    benchmark:
        BENCHMARK_FP / "example_rule.tsv"
    conda:
        "envs/sbx_genomad_env.yml"
    container:
        f"docker://antoniopcamargo/genomad"
    shell:
        "genomad download-database {output} 2>&1 | tee {log}"


rule genomad_end_to_end:
    """Run Genomad end-to-end pipeline"""
    input:
        contigs=ASSEMBLY_FP / "megahit" / "{sample}_asm" / "final.contigs.fa",
        db=Cfg["sbx_genomad"]["genomad_db"],
    output:
        VIRUS_FP / "genomad" / "{sample}",
    log:
        LOG_FP / "genomad_end_to_end_{sample}.log",
    benchmark:
        BENCHMARK_FP / "genomad_end_to_end_{sample}.tsv"
    conda:
        "envs/sbx_genomad_env.yml"
    container:
        f"docker://antoniopcamargo/genomad"
    shell:
        """
        genomad end-to-end --cleanup --splits 8 {input.contigs} {output} {input.db} 2>&1 | tee {log}
        """

rule genomad_filter_for_prophage:
