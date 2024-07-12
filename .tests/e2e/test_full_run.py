import gzip
import os
import pytest
import shutil
import subprocess as sp
import sys
from pathlib import Path


@pytest.fixture
def setup(tmpdir):
    reads_fp = tmpdir / "reads/"
    os.makedirs(reads_fp, exist_ok=True)
    assemblies_fp = Path(".tests/data/set5_gut_virome_dataset/assemblies/").resolve()
    # genomad_db_fp = tmpdir / "genomad_db/"
    genomad_db_fp = Path("/home/ctbus/Penn/dbs/genomad_db_2024_04_09")

    for dir in [x[0] for x in os.walk(assemblies_fp)][1:]:
        with gzip.open(
            reads_fp / f"{Path(dir).name}_1.fastq.gz", "wt"
        ) as r1, gzip.open(reads_fp / f"{Path(dir).name}_2.fastq.gz", "wt") as r2:
            r1.write("NONEMPTY")
            r2.write("NONEMPTY")

    project_dir = tmpdir / "project/"

    sp.check_output(["sunbeam", "init", "--data_fp", reads_fp, project_dir])

    config_fp = project_dir / "sunbeam_config.yml"
    output_fp = project_dir / "sunbeam_output"
    megahit_assemblies_fp = output_fp / "assembly" / "megahit"

    os.makedirs(megahit_assemblies_fp, exist_ok=True)

    for dir in [x[0] for x in os.walk(assemblies_fp)][1:]:
        os.makedirs(megahit_assemblies_fp / f"{Path(dir).name}_asm", exist_ok=True)
        shutil.copyfile(
            Path(dir) / "assembly.fa",
            megahit_assemblies_fp / f"{Path(dir).name}_asm" / "final.contigs.fa",
        )

    config_str = f"sbx_genomad: {{genomad_db: {genomad_db_fp}}}"

    sp.check_output(
        [
            "sunbeam",
            "config",
            "modify",
            "-i",
            "-s",
            f"{config_str}",
            f"{config_fp}",
        ]
    )

    yield tmpdir, project_dir


@pytest.fixture
def run_sunbeam(setup):
    temp_dir, project_dir = setup
    output_fp = project_dir / "sunbeam_output"
    log_fp = output_fp / "logs"
    stats_fp = project_dir / "stats"

    # Run the test job
    try:
        sp.check_output(
            [
                "sunbeam",
                "run",
                "--profile",
                project_dir,
                "all_genomad",
                "--directory",
                temp_dir,
            ]
        )
    except sp.CalledProcessError as e:
        shutil.copytree(log_fp, "logs/")
        shutil.copytree(stats_fp, "stats/")
        sys.exit(e)

    shutil.copytree(log_fp, "logs/")
    shutil.copytree(stats_fp, "stats/")

    output_fp = project_dir / "sunbeam_output"
    benchmarks_fp = project_dir / "stats/"

    yield output_fp, benchmarks_fp


def test_full_run(run_sunbeam):
    output_fp, benchmarks_fp = run_sunbeam

    print([x[0] for x in os.walk(output_fp / "virus" / "genomad")])
    for root, dirs, filenames in os.walk(output_fp / "virus" / "genomad"):
        for dir in dirs:
            summary = (
                Path(dir) / "final.contigs_summary" / "final.contigs_virus_summary.tsv"
            )
            assert summary.exists(), f"{summary} does not exist"
        break
