# =============================================================================
# ISS municipal 2002–2023 — série longa para usar o ISS como variável dependente
#
# Fonte: Ipeadata, série RISSM ("Receita corrente - receita bruta - impostos, taxas e
# contribuições de melhoria - ISS - municipal"), origem Min. Fazenda/STN (FINBRA/Siconfi),
# anual, em R$ correntes, por município. É a mesma informação do bloco 4 de
# baixar_bases_fiol_fns.R (Siconfi, só 2013+), mas numa série única desde antes das obras.
#
# Saídas: dados_brutos/iss_ipeadata_2002_2023.csv (cod_ibge, ano, iss)
#         dados_brutos/iss_ipeadata_vs_siconfi.csv (conferência 2013–2023, se houver o Siconfi)
# =============================================================================
pacotes <- c("httr2", "dplyr", "readr")
novos <- setdiff(pacotes, rownames(installed.packages()))
if (length(novos)) install.packages(novos)
invisible(lapply(pacotes, library, character.only = TRUE))
DIR <- "dados_brutos"; dir.create(DIR, showWarnings = FALSE)
UFS <- c("29", "52", "31", "35"); ANOS <- 2002:2023

r <- request("https://www.ipeadata.gov.br/api/odata4/ValoresSerie(SERCODIGO='RISSM')") |>
  req_timeout(600) |> req_retry(max_tries = 4) |> req_perform()
v <- resp_body_json(r, simplifyVector = TRUE)$value
iss <- tibble::as_tibble(v) |>
  filter(NIVNOME == "Municípios", substr(TERCODIGO, 1, 2) %in% UFS) |>
  transmute(cod_ibge = TERCODIGO, ano = as.integer(substr(VALDATA, 1, 4)), iss = as.numeric(VALVALOR)) |>
  filter(ano %in% ANOS, !is.na(iss)) |> arrange(cod_ibge, ano)
stopifnot(!anyDuplicated(iss[c("cod_ibge", "ano")]))
write_csv(iss, file.path(DIR, "iss_ipeadata_2002_2023.csv"))
message("ISS Ipeadata: ", nrow(iss), " obs., ", n_distinct(iss$cod_ibge), " municípios, ",
        min(iss$ano), "–", max(iss$ano), "; zeros: ", sum(iss$iss == 0))

sic <- file.path(DIR, "iss_siconfi_2013_2023.csv")
if (file.exists(sic)) {
  cmp <- inner_join(iss, read_csv(sic, col_types = cols(cod_ibge = "c", ano = "i", iss = "d")),
                    by = c("cod_ibge", "ano"), suffix = c("_ipeadata", "_siconfi")) |>
    mutate(dif_pct = 100 * (iss_ipeadata / iss_siconfi - 1))
  write_csv(cmp, file.path(DIR, "iss_ipeadata_vs_siconfi.csv"))
  print(cmp |> filter(iss_siconfi > 0) |> group_by(ano) |>
          summarise(n = n(), iguais_1pct = mean(abs(dif_pct) < 1), mediana_dif_pct = median(dif_pct),
                    p90_abs_dif_pct = quantile(abs(dif_pct), .9)))
}
