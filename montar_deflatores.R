# =============================================================================
# Monta deflator_pib.csv e ipca.csv a partir do SIDRA/IBGE (etapa 4 do CLAUDE.md)
#
#  deflator_pib.csv (ano, deflator; 2020 = 100)
#     Fonte: SIDRA tabela 6784 (Sistema de Contas Nacionais, anual), variável 9811
#     "PIB - deflator - variação anual (%)". O índice é o encadeamento das variações,
#     reescalado para 2020 = 100. Se a tabela não tiver o último ano do painel, o
#     script para e avisa (não extrapola).
#  ipca.csv (ano, ipca_indice)
#     Fonte: SIDRA tabela 1737, variável 2266 "IPCA - Número-índice (base: dezembro
#     de 1993 = 100)", mês de DEZEMBRO de cada ano — a massa salarial da RAIS usada
#     em rais_longa_scm.R é a remuneração de dezembro.
# =============================================================================
library(httr2); library(dplyr); library(readr)
sidra_br <- function(caminho) {
  d <- NULL
  for (tentativa in 1:6) {                      # a API devolve erro intermitente (página HTML)
    d <- tryCatch(request(paste0("https://apisidra.ibge.gov.br/values", caminho)) |>
                    req_timeout(120) |> req_perform() |> resp_body_json(simplifyVector = TRUE),
                  error = function(e) NULL)
    if (!is.null(d)) break
    Sys.sleep(10 * tentativa)
  }
  if (is.null(d)) stop("Falha na consulta SIDRA: ", caminho)
  names(d) <- unlist(d[1, ]); tibble::as_tibble(d[-1, ], .name_repair = "unique")
}

defl <- sidra_br("/t/6784/n1/all/v/9811/p/all") |>
  transmute(ano = as.integer(Ano), var_pct = suppressWarnings(as.numeric(Valor))) |>
  filter(!is.na(var_pct)) |> arrange(ano)
stopifnot(all(diff(defl$ano) == 1), 2020 %in% defl$ano, min(defl$ano) <= 2002)
defl <- defl |> mutate(indice = cumprod(1 + var_pct / 100),
                       deflator = 100 * indice / indice[ano == 2020])
if (max(defl$ano) < 2023) stop("Tabela 6784 vai só até ", max(defl$ano), ": falta deflator para 2023.")
write_csv(defl |> filter(ano >= 2002) |> select(ano, deflator), "deflator_pib.csv")

ipca <- sidra_br(sprintf("/t/1737/n1/all/v/2266/p/%s", paste0(1995:2023, "12", collapse = ","))) |>
  transmute(ano = as.integer(substr(`Mês (Código)`, 1, 4)), ipca_indice = as.numeric(Valor)) |>
  arrange(ano)
stopifnot(nrow(ipca) == 29)
write_csv(ipca, "ipca.csv")
message("deflator_pib.csv: ", min(defl$ano[defl$ano >= 2002]), "–", max(defl$ano),
        " | ipca.csv: ", min(ipca$ano), "–", max(ipca$ano))
