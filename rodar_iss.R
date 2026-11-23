# =============================================================================
# Mesma análise de analise_impacto_ferrovias.R com o ISS como variável dependente
#
# Não duplica o script: lê analise_impacto_ferrovias.R e, da seção 2 em diante, troca
#   ln_pib   -> ln_iss    (ln do ISS real, R$ de 2020, deflator do PIB)
#   ln_pibpc -> ln_isspc  (ln do ISS real per capita, população interpolada)
#   pib_real -> iss_real  (controle sintético agregado)
# A preparação (amostra, datas, covariáveis pré-obra medidas com o PIB, escore de
# propensão e pareamento) fica idêntica à análise do PIB: muda só o desfecho.
# Municípios-ano sem declaração de ISS (ou com ISS zero) ficam como NA.
#
# Entrada extra: dados_brutos/iss_ipeadata_2002_2023.csv (baixar_iss_ipeadata.R)
# Saídas: resultados_iss_ate_2019/, resultados_iss_ate_2023/ (mesmos nomes de arquivo,
#         com ln_iss / ln_isspc) e 00_cobertura_iss.csv em cada pasta.
# Uso: Rscript rodar_iss.R   |   SO_PERIODO=ate_2019 Rscript rodar_iss.R
# =============================================================================
library(dplyr); library(readr); library(purrr); library(tidyr); library(ggplot2); library(stringr)
stopifnot(file.exists("dados_brutos/iss_ipeadata_2002_2023.csv"))
PERIODOS <- list(ate_2019 = list(ANO_MAX = 2019, CONTROLE_AGRO = FALSE),
                 ate_2023 = list(ANO_MAX = 2023, CONTROLE_AGRO = TRUE))
SO_PERIODO <- Sys.getenv("SO_PERIODO")

fonte <- readLines("analise_impacto_ferrovias.R", encoding = "UTF-8")
i2 <- grep("^# ---- 2\\. Descritivas", fonte)[1]
troca <- function(x) x |>
  str_replace_all("\\bln_pibpc\\b", "ln_isspc") |> str_replace_all("\\bln_pib\\b", "ln_iss") |>
  str_replace_all("\\bpib_real\\b", "iss_real") |>
  str_replace_all("ln\\(PIB real per capita\\)", "ln(ISS real per capita)") |>
  str_replace_all("ln\\(PIB real\\)", "ln(ISS real)") |> str_replace_all("PIB real", "ISS real")
idesf <- grep("^DESFECHOS <- c\\(ln_pib", fonte)[1]          # definição dos desfechos (antes da seção 2)
fonte[idesf:(idesf + 1)] <- troca(fonte[idesf:(idesf + 1)])
fonte[i2:length(fonte)]  <- troca(fonte[i2:length(fonte)])
# cobertura do ISS por ferrovia, logo antes da seção 2
cobertura <- c(
  'write_csv(painel |> group_by(ferrovia, pool, cod_ibge) |> summarise(anos_com_iss = sum(!is.na(ln_iss)), .groups = "drop") |>',
  '            group_by(ferrovia, pool) |> summarise(municipios = n(), serie_completa = sum(anos_com_iss == n_distinct(painel$ano)),',
  '                      sem_nenhum_ano = sum(anos_com_iss == 0), media_anos = mean(anos_com_iss), .groups = "drop"),',
  '          file.path(OUT, "00_cobertura_iss.csv"))')
fonte <- c(fonte[1:(i2 - 1)], cobertura, fonte[i2:length(fonte)])
arq <- tempfile("analise_iss_", fileext = ".R"); writeLines(fonte, arq, useBytes = TRUE)

for (nome in names(PERIODOS)) {
  if (nzchar(SO_PERIODO) && nome != SO_PERIODO) next
  message("\n==================== ISS | ", nome, " ====================")
  amb <- new.env()
  list2env(c(PERIODOS[[nome]], list(OUT = paste0("resultados_iss_", nome))), envir = amb)
  sys.source(arq, envir = amb, keep.source = FALSE)
}
