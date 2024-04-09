FROM condaforge/mambaforge:latest

# Setup
WORKDIR /home/sbx_genomad_env

COPY envs/sbx_genomad_env.yml ./

# Install environment
RUN conda env create --file sbx_genomad_env.yml --name sbx_genomad

ENV PATH="/opt/conda/envs/sbx_genomad/bin/:${PATH}"

# "Activate" the environment
SHELL ["conda", "run", "-n", "sbx_genomad", "/bin/bash", "-c"]

# Run
CMD "bash"