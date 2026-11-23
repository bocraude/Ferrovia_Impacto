# =============================================================================
# ISS — Siconfi, DCA Anexo I-C, 2013–2023 (mesma consulta e mesmo filtro do bloco 4
# de baixar_bases_fiol_fns.R), em paralelo e retomável.
# São ~24 mil consultas (município × ano); em sequência levam horas. Este script
# faz N_PAR consultas simultâneas, grava parciais em dados_brutos/iss_partes/ e,
# ao final, escreve dados_brutos/iss_siconfi_2013_2023.csv — que
# baixar_bases_fiol_fns.R reaproveita ao montar painel_municipal.csv.
# =============================================================================
pacotes <- c("httr2", "dplyr", "readr", "purrr", "stringr", "tidyr", "curl")
novos <- setdiff(pacotes, rownames(installed.packages()))
if (length(novos)) install.packages(novos)
invisible(lapply(pacotes, library, character.only = TRUE))
DIR <- "dados_brutos"; PARTES <- file.path(DIR, "iss_partes"); dir.create(PARTES, TRUE, FALSE)
N_PAR <- 6
# lista de municípios: PIB bruto do passo 1 ou, se não houver, o painel já montado
arq_mun <- if (file.exists(file.path(DIR, "pib_municipios_5938.csv")))
  file.path(DIR, "pib_municipios_5938.csv") else "painel_municipal.csv"
if (!file.exists(arq_mun)) stop("Rode antes baixar_bases_fiol_fns.R (ou coloque painel_municipal.csv nesta pasta).")
mun <- read_csv(arq_mun, col_types = cols(cod_ibge = "c"), show_col_types = FALSE) |>
  distinct(cod_ibge) |> pull(cod_ibge)
grade <- expand_grid(cod = mun, ano = 2013:2023)

extrai <- function(r) {
  it <- tryCatch(resp_body_json(r, simplifyVector = TRUE)$items, error = function(e) NULL)
  if (is.null(it) || !length(it) || !nrow(it)) return(NULL)
  it |> filter(str_detect(conta, regex("Servi.os de Qualquer Natureza", ignore_case = TRUE)),
               str_detect(coluna, regex("Brutas Realizadas|Receitas Realizadas", ignore_case = TRUE))) |>
    arrange(nchar(cod_conta)) |> slice(1) |>
    transmute(cod_ibge = as.character(cod_ibge), ano = as.integer(exercicio), iss = as.numeric(valor))
}
for (cod in mun) {
  arq <- file.path(PARTES, paste0(cod, ".csv")); if (file.exists(arq)) next
  reqs <- map(2013:2023, ~ request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca") |>
                req_url_query(an_exercicio = .x, no_anexo = "DCA-Anexo I-C", id_ente = cod) |>
                req_timeout(90) |> req_retry(max_tries = 4))
  # httr2 >= 1.1 usa max_active; versões anteriores usam pool
  resps <- if ("max_active" %in% names(formals(req_perform_parallel)))
    req_perform_parallel(reqs, on_error = "continue", progress = FALSE, max_active = N_PAR) else
    req_perform_parallel(reqs, on_error = "continue", progress = FALSE,
                         pool = curl::new_pool(host_con = N_PAR, total_con = N_PAR))
  falhas <- sum(!map_lgl(resps, ~ inherits(.x, "httr2_response")))
  if (falhas) { message(cod, ": ", falhas, " consulta(s) falharam; fica para a próxima execução"); next }
  d <- map_dfr(resps, extrai)
  if (!nrow(d)) d <- tibble(cod_ibge = character(), ano = integer(), iss = numeric())
  write_csv(d, arq)
}
feitos <- list.files(PARTES, full.names = TRUE)
message(length(feitos), " de ", length(mun), " municípios consultados")
if (length(feitos) == length(mun)) {
  iss <- map_dfr(feitos, read_csv, col_types = cols(cod_ibge = "c", ano = "i", iss = "d"))
  write_csv(iss, file.path(DIR, "iss_siconfi_2013_2023.csv"))
  message("iss_siconfi_2013_2023.csv: ", nrow(iss), " linhas, ", n_distinct(iss$cod_ibge), " municípios")
} else message("Incompleto: rode de novo para retomar.")
