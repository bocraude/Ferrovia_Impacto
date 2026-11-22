#!/usr/bin/env bash
# Instala R e as bibliotecas de sistema usadas pelos scripts (Ubuntu 24.04).
# Pode ser usado como "setup script" do ambiente do Claude Code na web.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  r-base r-base-dev \
  libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
  libgdal-dev libgeos-dev libproj-dev libudunits2-dev libsqlite3-dev \
  libarchive-dev p7zip-full cmake
Rscript -e 'options(repos = "https://cloud.r-project.org"); \
  pk <- c("dplyr","tidyr","purrr","readr","stringr","ggplot2","httr2","jsonlite","data.table", \
          "archive","curl","fixest","did","tidysynth","MatchIt","bacondecomp","sf","geobr","spdep", \
          "remotes","MASS","osmdata"); \
  install.packages(setdiff(pk, rownames(installed.packages())), Ncpus = 4); \
  remotes::install_github("synth-inference/synthdid", upgrade = "never"); \
  remotes::install_github("asheshrambachan/HonestDiD", upgrade = "never")'
exit 0
