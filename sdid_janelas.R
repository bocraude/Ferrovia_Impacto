# =============================================================================
# Synthetic DiD: efeito ano a ano e por janela (fase da obra)
#
# Complementa a seção 4 de analise_impacto_ferrovias.R sem alterá-la. O modelo é o
# mesmo (mesmos dados, mesma data por ferrovia, pesos estimados uma única vez); a
# diferença é que, em vez de reportar só a média de todo o pós-obra, guarda o efeito
# de cada ano (synthdid_effect_curve) e tira a média dentro das mesmas JANELAS usadas
# no TWFE (seção 6c). A média das janelas ponderada pelo nº de anos reproduz o efeito
# total de 06_sdid_sc_did.csv.
#
# Erro-padrão: placebo, como na seção 4 — sorteiam-se controles como falsos tratados
# (mesmo nº de tratados), reestima-se o modelo e guarda-se a curva inteira; o EP de
# cada ano/janela é o desvio-padrão entre as réplicas (B_PLACEBO = 200).
#
# Saídas, em cada resultados_<período>/:
#   06b_sdid_efeito_anual.csv        efeito por ano, EP e IC 95%
#   06b_sdid_efeitos_por_janela.csv  efeito por janela, EP e IC 95% (+ linha "Total pós-obra")
#   06b_sdid_efeito_anual.png, 06b_sdid_efeitos_por_janela.png  (ln PIB real)
# Uso: Rscript sdid_janelas.R            (os dois períodos)
#      SO_PERIODO=ate_2019 Rscript sdid_janelas.R
# =============================================================================
suppressMessages({library(dplyr); library(tidyr); library(purrr); library(readr); library(stringr)
  library(ggplot2); library(fixest); library(did); library(tidysynth); library(synthdid)
  library(HonestDiD); library(MatchIt)})

PERIODOS <- list(ate_2019 = list(ANO_MAX = 2019, CONTROLE_AGRO = FALSE),
                 ate_2023 = list(ANO_MAX = 2023, CONTROLE_AGRO = TRUE))
SO_PERIODO <- Sys.getenv("SO_PERIODO")
B_PLACEBO <- as.integer(Sys.getenv("B_PLACEBO", "200"))   # réplicas do placebo
DESF <- c(ln_pib = "ln(PIB real)", ln_pibpc = "ln(PIB real per capita)")

# Preparação (painel, amostras, pareamento) = seções 0 a 2f do script principal, sem repetir código
fonte <- readLines("analise_impacto_ferrovias.R", encoding = "UTF-8")
prep  <- fonte[grep("^set.seed\\(", fonte)[1]:(grep("^# ---- 3\\. Controle sint", fonte)[1] - 1)]

curva <- function(Y, N0, T0, pesos = NULL) {
  est <- if (is.null(pesos)) synthdid_estimate(Y, N0, T0) else
    synthdid_estimate(Y, N0, T0, weights = pesos, update.omega = TRUE, update.lambda = TRUE)
  list(est = est, tau = as.numeric(synthdid_effect_curve(est)))
}

roda_periodo <- function(nome) {
  amb <- new.env()
  list2env(c(PERIODOS[[nome]], list(OUT = tempfile("prep_"))), envir = amb)   # descritivas vão p/ pasta temporária
  suppressWarnings(suppressMessages(eval(parse(text = prep), envir = amb)))
  OUT <- paste0("resultados_", nome); dir.create(OUT, showWarnings = FALSE)
  set.seed(2026)

  res <- map_dfr(amb$FERROV, function(k) map_dfr(c(FALSE, TRUE), function(ps) map_dfr(names(DESF), function(y) {
    d <- amb$amostra(k, psm = ps); g0 <- amb$DATA_TRAT[[k]]
    df <- d |> transmute(unidade = cod_ibge, ano, y = .data[[y]], W = as.integer(tratado & ano >= g0)) |>
      group_by(unidade) |> filter(sum(!is.na(y)) == n_distinct(amb$painel$ano)) |> ungroup() |> as.data.frame()
    pm <- panel.matrices(df, unit = 1, time = 2, outcome = 3, treatment = 4)
    N0 <- pm$N0; N1 <- nrow(pm$Y) - N0; T0 <- pm$T0
    anos <- as.integer(colnames(pm$Y))[(T0 + 1):ncol(pm$Y)]
    obs <- curva(pm$Y, N0, T0)
    w <- attr(obs$est, "weights")
    # placebo: N1 controles sorteados viram "tratados"; os demais são os controles
    pl <- if (N0 > N1) t(replicate(B_PLACEBO, {
      ind <- sample(N0); n0 <- N0 - N1
      om <- w$omega[ind[1:n0]]; om <- om / sum(om)
      curva(pm$Y[ind, ], n0, T0, pesos = list(omega = om, lambda = w$lambda))$tau
    })) else matrix(NA_real_, B_PLACEBO, length(anos))
    jj <- amb$JANELAS[[k]]
    jan <- as.character(cut(anos, breaks = c(unname(jj), Inf), right = FALSE, labels = names(jj)))
    grupos <- c(split(seq_along(anos), factor(jan, names(jj))), list("Total pós-obra" = seq_along(anos)))
    message(nome, " | ", k, " | ", y, " | ", if (ps) "pareados" else "todos", ": efeito total ",
            round(mean(obs$tau), 4), " (EP ", round(sd(rowMeans(pl)), 4), ")")
    bind_rows(
      tibble(tipo = "ano", janela = as.character(anos), anos = as.character(anos), n_anos = 1L,
             efeito = obs$tau, se = apply(pl, 2, sd)),
      imap_dfr(grupos, ~ tibble(tipo = "janela", janela = .y,
                                anos = paste0(min(anos[.x]), "-", max(anos[.x])), n_anos = length(.x),
                                efeito = mean(obs$tau[.x]), se = sd(rowMeans(pl[, .x, drop = FALSE]))))) |>
      mutate(ferrovia = k, desfecho = y,
             controles = if (ps) "Pareados (escore de propensão)" else "Todos os elegíveis",
             n_trat = N1, n_ctrl = N0, ano_inicio = g0, .before = 1)
  }))) |>
    mutate(ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se, p_valor = 2 * pnorm(-abs(efeito / se)))

  # conferência com a seção 4 (todos os controles): o total tem de reproduzir 06_sdid_sc_did.csv
  ref <- file.path(OUT, "06_sdid_sc_did.csv")
  if (file.exists(ref)) {
    chk <- res |> filter(janela == "Total pós-obra", controles == "Todos os elegíveis") |>
      inner_join(read_csv(ref, show_col_types = FALSE) |> filter(estimador == "SDID") |>
                   select(ferrovia, desfecho, efeito_ref = efeito, se_ref = se), by = c("ferrovia", "desfecho"))
    stopifnot(nrow(chk) == 6, all(abs(chk$efeito - chk$efeito_ref) < 1e-8))
    message(nome, ": efeito total confere com 06_sdid_sc_did.csv; razão EP (este / seção 4): ",
            paste(round(chk$se / chk$se_ref, 2), collapse = " "))
  }
  write_csv(res |> filter(tipo == "ano") |> transmute(ferrovia, desfecho, controles, n_trat, n_ctrl, ano_inicio,
                                                      ano = as.integer(janela), efeito, se, ic_inf, ic_sup, p_valor),
            file.path(OUT, "06b_sdid_efeito_anual.csv"))
  write_csv(res |> filter(tipo == "janela") |> select(-tipo), file.path(OUT, "06b_sdid_efeitos_por_janela.csv"))

  tema <- theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "top")
  cores <- c("Todos os elegíveis" = "grey45", "Pareados (escore de propensão)" = "#2a78d6")
  g1 <- res |> filter(tipo == "ano", desfecho == "ln_pib") |> mutate(ano = as.integer(janela)) |>
    ggplot(aes(ano, efeito, colour = controles, fill = controles)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_ribbon(aes(ymin = ic_inf, ymax = ic_sup), alpha = .15, colour = NA) +
    geom_line(linewidth = .7) + geom_point(size = 1.6) +
    scale_colour_manual(values = cores) + scale_fill_manual(values = cores) +
    facet_wrap(~ ferrovia, scales = "free_x") +
    labs(x = NULL, y = "Efeito sobre ln(PIB real) — Synthetic DiD, IC 95%", colour = NULL, fill = NULL) + tema
  ggsave(file.path(OUT, "06b_sdid_efeito_anual.png"), g1, width = 10, height = 4)
  g2 <- res |> filter(tipo == "janela", desfecho == "ln_pib") |>
    mutate(janela = factor(janela, unique(janela))) |>
    ggplot(aes(janela, efeito, colour = controles, shape = controles)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_pointrange(aes(ymin = ic_inf, ymax = ic_sup), position = position_dodge(width = .5)) +
    scale_colour_manual(values = cores) +
    facet_wrap(~ ferrovia, scales = "free_x") +
    labs(x = NULL, y = "Efeito sobre ln(PIB real) — Synthetic DiD, IC 95%", colour = NULL, shape = NULL) + tema +
    theme(axis.text.x = element_text(angle = 20, hjust = 1))
  ggsave(file.path(OUT, "06b_sdid_efeitos_por_janela.png"), g2, width = 10, height = 4.5)
  invisible(res)
}

for (nome in names(PERIODOS)) if (!nzchar(SO_PERIODO) || nome == SO_PERIODO) roda_periodo(nome)
message("Concluído: 06b_sdid_* em resultados_<período>/")
