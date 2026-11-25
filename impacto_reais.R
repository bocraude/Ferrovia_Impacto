# =============================================================================
# Impacto em reais (R$ de 2020), por trecho e por fase da obra, 2002–2019
#
#   PIB: Synthetic DiD (todos os controles elegíveis)      — modelo principal do PIB
#   ISS: Callaway & Sant'Anna (duplamente robusto)         — modelo principal do ISS
#
# Como o efeito é estimado em logaritmo, a conversão para reais é:
#   contrafactual = observado / exp(efeito)      impacto = observado − contrafactual
# feita ano a ano, com o efeito daquele ano, e somada por fase e no total.
#   PIB: aplicado ao PIB real somado dos municípios do trecho em cada ano.
#   ISS: aplicado ao ISS real de cada município-ano declarado e somado.
# Hipótese da conversão: o efeito proporcional do ano vale para todos os municípios do
# trecho, de modo que os municípios maiores dominam o valor em reais.
#
# Intervalo de 95%: percentis de 2,5 e 97,5 do impacto em reais recalculado em cada
# simulação do efeito —
#   PIB: 200 placebos do Synthetic DiD (controles sorteados como falsos tratados), somados
#        à estimativa; ISS: 5.000 sorteios da distribuição conjunta dos efeitos por ano do
#        Callaway & Sant'Anna (covariância pela função de influência).
# As simulações preservam a correlação entre os anos, o que a soma de intervalos anuais não faz.
#
# Saídas em resultados_impacto_reais/:
#   impacto_reais_por_fase.csv, impacto_reais_anual.csv, impacto_reais_por_fase.png
# =============================================================================
suppressMessages({library(dplyr); library(tidyr); library(purrr); library(readr); library(stringr)
  library(ggplot2); library(fixest); library(did); library(tidysynth); library(synthdid)
  library(HonestDiD); library(MatchIt)})
OUTR <- "resultados_impacto_reais"; dir.create(OUTR, showWarnings = FALSE)
B_PLACEBO <- 200; N_SORTEIOS <- 5000

fonte <- readLines("analise_impacto_ferrovias.R", encoding = "UTF-8")
bloco <- function(de, ate) fonte[grep(de, fonte)[1]:(grep(ate, fonte)[1] - 1)]
amb <- new.env(); list2env(list(ANO_MAX = 2019, CONTROLE_AGRO = FALSE, OUT = tempfile("prep_")), envir = amb)
suppressWarnings(suppressMessages({
  eval(parse(text = bloco("^set.seed\\(", "^# ---- 3\\. Controle sint")), envir = amb)     # amostra, variáveis, pareamento
  eval(parse(text = bloco("^# ---- 5\\. Callaway", "^cs_tudo <- function")), envir = amb)   # fórmula por ferrovia e cs_ferrovia()
}))
FERROV <- amb$FERROV; set.seed(2026)
fase_de <- function(k, anos) { jj <- amb$JANELAS[[k]]
  as.character(cut(anos, breaks = c(unname(jj), Inf), right = FALSE, labels = names(jj))) }
resumo <- function(k, variavel, modelo, anos, obs, imp, sim, n_trat, nota) {
  # obs, imp: vetores por ano; sim: matriz simulações × anos, já em reais (mesma unidade de obs)
  grupos <- c(split(seq_along(anos), factor(fase_de(k, anos), names(amb$JANELAS[[k]]))), list("Total pós-obra" = seq_along(anos)))
  fases <- imap_dfr(grupos, function(ix, nm) { s <- rowSums(sim[, ix, drop = FALSE])
    tibble(fase = nm, anos = paste0(min(anos[ix]), "-", max(anos[ix])), n_anos = length(ix),
           observado_mi = sum(obs[ix]), impacto_mi = sum(imp[ix]),
           ic_inf_mi = unname(quantile(s, .025)), ic_sup_mi = unname(quantile(s, .975))) }) |>
    mutate(contrafactual_mi = observado_mi - impacto_mi, impacto_pct_contrafactual = 100 * impacto_mi / contrafactual_mi,
           impacto_medio_anual_mi = impacto_mi / n_anos)
  anual <- tibble(ano = anos, observado_mi = obs, impacto_mi = imp,
                  ic_inf_mi = apply(sim, 2, quantile, .025), ic_sup_mi = apply(sim, 2, quantile, .975))
  cab <- tibble(ferrovia = k, variavel = variavel, modelo = modelo, municipios = n_trat, nota = nota)
  list(fases = bind_cols(cab, fases), anual = bind_cols(cab |> select(-nota), anual))
}

# ---- PIB: Synthetic DiD -----------------------------------------------------------------
pib <- map(FERROV, function(k) {
  d <- amb$amostra(k); g0 <- amb$DATA_TRAT[[k]]
  df <- d |> transmute(unidade = cod_ibge, ano, y = ln_pib, W = as.integer(tratado & ano >= g0)) |>
    group_by(unidade) |> filter(sum(!is.na(y)) == n_distinct(amb$painel$ano)) |> ungroup() |> as.data.frame()
  pm <- panel.matrices(df, unit = 1, time = 2, outcome = 3, treatment = 4)
  N0 <- pm$N0; N1 <- nrow(pm$Y) - N0; T0 <- pm$T0
  anos <- as.integer(colnames(pm$Y))[(T0 + 1):ncol(pm$Y)]
  est <- synthdid_estimate(pm$Y, N0, T0); tau <- as.numeric(synthdid_effect_curve(est)); w <- attr(est, "weights")
  pl <- t(replicate(B_PLACEBO, { ind <- sample(N0); n0 <- N0 - N1; om <- w$omega[ind[1:n0]]
    as.numeric(synthdid_effect_curve(synthdid_estimate(pm$Y[ind, ], n0, T0, weights = list(omega = om / sum(om), lambda = w$lambda),
                                                       update.omega = TRUE, update.lambda = TRUE))) }))
  pl <- sweep(pl, 2, colMeans(pl))                                   # ruído dos placebos, centrado em zero
  tratados <- rownames(pm$Y)[(N0 + 1):nrow(pm$Y)]
  obs <- d |> filter(cod_ibge %in% tratados, ano %in% anos) |> group_by(ano) |> summarise(v = sum(pib_real) / 1e3) |> arrange(ano) |> pull(v)  # R$ milhões
  sim <- sweep(1 - exp(-sweep(pl, 2, tau, `+`)), 2, obs, `*`)
  message("PIB | ", k, ": efeito médio ", round(mean(tau), 4), "; impacto total R$ ", round(sum(obs * (1 - exp(-tau)))), " mi")
  resumo(k, "PIB real", "Synthetic DiD", anos, obs, obs * (1 - exp(-tau)), sim, N1,
         "PIB real somado dos municípios do trecho; IC por 200 placebos")
})

# ---- ISS: Callaway & Sant'Anna ------------------------------------------------------------
iss <- map(FERROV, function(k) {
  r <- suppressWarnings(suppressMessages(amb$cs_ferrovia(amb$painel, k, "ln_iss"))); din <- r$din; g0 <- amb$DATA_TRAT[[k]]
  pos <- which(din$egt >= 0); e <- din$egt[pos]; anos <- g0 + e; tau <- din$att.egt[pos]
  inf <- din$inf.function$dynamic.inf.func.e[, pos, drop = FALSE]
  V <- crossprod(inf) / nrow(inf)^2
  sorteios <- MASS::mvrnorm(N_SORTEIOS, tau, V)
  d <- amb$amostra(k) |> filter(tratado, ano %in% anos, !is.na(iss_real))
  obs <- d |> group_by(ano) |> summarise(v = sum(iss_real) / 1e6) |> right_join(tibble(ano = anos), by = "ano") |> arrange(ano) |> pull(v)   # R$ milhões
  obs[is.na(obs)] <- 0
  sim <- sweep(1 - exp(-sorteios), 2, obs, `*`)
  decl <- d |> count(ano) |> pull(n)
  message("ISS | ", k, ": efeito médio ", round(mean(tau), 4), " (tabela: ", round(r$sim$overall.att, 4), "); impacto total R$ ",
          round(sum(obs * (1 - exp(-tau))), 1), " mi; municípios com ISS declarado por ano: ", min(decl), " a ", max(decl))
  resumo(k, "ISS real", "Callaway & Sant'Anna", anos, obs, obs * (1 - exp(-tau)), sim, n_distinct(d$cod_ibge),
         paste0("ISS real dos municípios-ano com declaração (", min(decl), " a ", max(decl), " municípios por ano); IC por ", N_SORTEIOS, " sorteios"))
})

fases <- bind_rows(map(c(pib, iss), "fases")); anual <- bind_rows(map(c(pib, iss), "anual"))
write_csv(fases, file.path(OUTR, "impacto_reais_por_fase.csv"))
write_csv(anual, file.path(OUTR, "impacto_reais_anual.csv"))

g <- fases |> mutate(fase = factor(fase, unique(fase)), ferrovia = factor(ferrovia, FERROV)) |>
  ggplot(aes(fase, impacto_mi)) + geom_hline(yintercept = 0, colour = "grey60") +
  geom_pointrange(aes(ymin = ic_inf_mi, ymax = ic_sup_mi), colour = "#2a78d6") +
  facet_grid(variavel ~ ferrovia, scales = "free") +
  labs(x = NULL, y = "Impacto acumulado na fase (R$ milhões de 2020), IC 95%") +
  theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path(OUTR, "impacto_reais_por_fase.png"), g, width = 11, height = 6)
message("Concluído: ", OUTR)
