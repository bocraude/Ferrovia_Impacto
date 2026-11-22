# Uso: Rscript rodar_na_nuvem.R <script.R>
# Aplica os ajustes de rede de ambiente_nuvem.R (proxy HTTPS do Claude Code na web)
# e executa o script indicado, sem alterar nenhum cálculo.
a <- commandArgs(TRUE); source("ambiente_nuvem.R"); source(a[1], encoding = "UTF-8")
