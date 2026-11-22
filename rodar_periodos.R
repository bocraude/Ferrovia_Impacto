# =============================================================================
# Roda analise_impacto_ferrovias.R em dois períodos e compara as estimativas
#
#   ate_2019 : 2002–2019, fase de obra, sem pandemia (análise principal)
#   ate_2023 : 2002–2023, inclui pandemia e início de operação da FNS-ES;
#              com controle agro × ano nos modelos fixest (boom de commodities)
#
# Saídas: resultados_ate_2019/, resultados_ate_2023/ e resultados_comparacao/
# =============================================================================

library(dplyr); library(readr); library(purrr); library(tidyr); library(ggplot2); library(stringr)

PERIODOS <- list(
  ate_2019 = list(ANO_MAX = 2019, CONTROLE_AGRO = FALSE),
  ate_2023 = list(ANO_MAX = 2023, CONTROLE_AGRO = TRUE)
)

# Opcional, para rodar os períodos em paralelo (um processo cada) e comparar depois:
#   SO_PERIODO=ate_2019 Rscript rodar_periodos.R   -> roda só esse período e encerra
#   SO_COMPARAR=1 Rscript rodar_periodos.R         -> só monta a comparação
SO_PERIODO <- Sys.getenv("SO_PERIODO"); SO_COMPARAR <- Sys.getenv("SO_COMPARAR") == "1"
for (nome in names(PERIODOS)) {
  if (SO_COMPARAR || (nzchar(SO_PERIODO) && nome != SO_PERIODO)) next
  message("\n==================== ", nome, " ====================")
  amb <- new.env()
  list2env(c(PERIODOS[[nome]], list(OUT = paste0("resultados_", nome))), envir = amb)
  sys.source("analise_impacto_ferrovias.R", envir = amb, keep.source = FALSE)
}

if (nzchar(SO_PERIODO)) quit(save = "no")

# ---- Comparação ----------------------------------------------------------------
CMP <- "resultados_comparacao"; dir.create(CMP, showWarnings = FALSE)
le <- function(arquivo) map_dfr(names(PERIODOS), function(nome) {
  f <- file.path(paste0("resultados_", nome), arquivo)
  if (file.exists(f)) read_csv(f, show_col_types = FALSE) |> mutate(periodo = nome) else NULL
})

# 1. Callaway & Sant'Anna: efeito médio por painel e desfecho
cs <- map_dfr(c("ln_pib", "ln_pibpc", "emp_constr_mil"), ~ le(paste0("07_cs_tabela_", .x, ".csv"))) |>
  filter(!str_detect(painel, "Teste de igualdade"))
cs_largo <- cs |>
  select(desfecho, painel, periodo, efeito, ic_inf, ic_sup, p_valor, p_pretendencia) |>
  pivot_wider(names_from = periodo, values_from = c(efeito, ic_inf, ic_sup, p_valor, p_pretendencia)) |>
  mutate(diferenca = efeito_ate_2023 - efeito_ate_2019)
write_csv(cs_largo, file.path(CMP, "cs_comparacao_periodos.csv"))

g <- cs |> filter(desfecho %in% c("ln_pib", "ln_pibpc")) |>
  mutate(desfecho = recode(desfecho, ln_pib = "ln(PIB real)", ln_pibpc = "ln(PIB real per capita)"),
         periodo = recode(periodo, ate_2019 = "2002–2019", ate_2023 = "2002–2023")) |>
  ggplot(aes(efeito, painel, colour = periodo, shape = periodo)) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_pointrange(aes(xmin = ic_inf, xmax = ic_sup), position = position_dodge(width = .5)) +
  scale_colour_manual(values = c("2002–2019" = "#2a78d6", "2002–2023" = "#eb6834")) +
  facet_wrap(~ desfecho) +
  labs(x = "Efeito médio pós-obra (Callaway & Sant'Anna), IC 95%", y = NULL, colour = NULL, shape = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top", panel.grid.minor = element_blank())
ggsave(file.path(CMP, "cs_comparacao_periodos.png"), g, width = 9, height = 4.5)

# 2. Synthetic DiD, controle sintético e DiD simples
write_csv(le("06_sdid_sc_did.csv") |>
            select(periodo, ferrovia, desfecho, estimador, efeito, se, ic_inf, ic_sup) |>
            pivot_wider(names_from = periodo, values_from = c(efeito, se, ic_inf, ic_sup)),
          file.path(CMP, "sdid_comparacao_periodos.csv"))

# 3. Sun & Abraham, robustez das datas, efeitos por janela e MDE
write_csv(le("09_sunab_att.csv"),               file.path(CMP, "sunab_comparacao_periodos.csv"))
write_csv(le("08_cs_robustez.csv") |>
            pivot_wider(names_from = periodo, values_from = c(efeito, se)),
          file.path(CMP, "robustez_datas_comparacao_periodos.csv"))
write_csv(le("09c_efeitos_por_janela.csv"),     file.path(CMP, "janelas_ambos_periodos.csv"))
write_csv(le("12_mde_placebo.csv"),             file.path(CMP, "mde_comparacao_periodos.csv"))
write_csv(le("14_psm_vs_todos.csv") |>
            select(periodo, ferrovia, controles, estimador, desfecho, efeito, se, n_trat, n_ctrl) |>
            pivot_wider(names_from = periodo, values_from = c(efeito, se)),
          file.path(CMP, "psm_vs_todos_comparacao_periodos.csv"))

# 4. Controle sintético: p-valor por placebos em cada período
scm <- map_dfr(names(PERIODOS), function(nome) {
  fs <- list.files(paste0("resultados_", nome), pattern = "^05_scm_inferencia_.*\\.csv$", full.names = TRUE)
  map_dfr(fs, ~ read_csv(.x, show_col_types = FALSE) |>
            filter(str_detect(unit_name, "^TRAT_")) |>
            mutate(periodo = nome, arquivo = basename(.x)))
})
write_csv(scm, file.path(CMP, "scm_comparacao_periodos.csv"))

message("\nComparação em ", normalizePath(CMP),
        "\nLeitura: se os efeitos de obra (janelas até 2019) forem parecidos nos dois períodos, ",
        "a extensão não muda a conclusão principal; diferenças concentradas nas janelas ",
        "2021–2023 refletem operação e/ou pandemia e devem ser lidas com cautela.")
