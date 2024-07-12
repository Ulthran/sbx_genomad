FROM condaforge/mambaforge:latest

# Setup
WORKDIR /home/mapping_env

COPY envs/mapping_env.yml ./

# Install environment
RUN conda env create --file mapping_env.yml --name mapping

ENV PATH="/opt/conda/envs/mapping/bin/:${PATH}"

# "Activate" the environment
SHELL ["conda", "run", "-n", "mapping", "/bin/bash", "-c"]

# Run
CMD "bash"