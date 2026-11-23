# =============================================================================
# ANÁLISE DE IMPACTO — FIOL I, FIOL II e FNS-ES sobre os municípios interceptados
#
# Sequência:
#   0. Configuração e leitura
#   1. Preparação do painel (deflação, logs, per capita, data de tratamento por ferrovia)
#   2. Descritivas: tabelas por grupo, testes de médias, gráficos
#   3. Controle sintético agregado por ferrovia (tidysynth)
#   4. Synthetic DiD por ferrovia (synthdid)
#   5. Callaway & Sant'Anna por ferrovia + média conjunta (did)
#   6. TWFE e Sun & Abraham (fixest) — comparação com o modelo atual
#  6b. Decomposição de Goodman-Bacon do TWFE
#  6c. Efeitos por janela (fases da obra) por ferrovia
#   7. Inferência robusta: wild cluster bootstrap e inferência por randomização
#   8. Sensibilidade a pré-tendências (HonestDiD)
#   9. Poder: efeito mínimo detectável por placebo
#  10. (Opcional) intensidade do tratamento
#  11. Escore de propensão: pareamento 3:1 (seção 2f) e reestimação na amostra pareada
#
# Entradas (pasta do projeto):
#   painel_municipal.csv   — gerado por baixar_bases_fiol_fns.R
#   municipios_grupos.csv  — classificação tratado/controle (modelo enviado)
#   deflator_pib.csv       — ano, deflator (base 2020 = 100)
#   km_por_municipio.csv   — opcional, gerado por calcular_aneis.R (intensidade)
#
# DATAS DE TRATAMENTO: sem cronograma por município, a data é única por ferrovia
# (ver o documento "Linha do tempo das obras"): FIOL I e FNS-ES em 2011 (primeiro
# ano com obra física), FIOL II em 2013 (licença dos lotes 5/5A). Cenários
# alternativos (data comum 2010 ou 2011, FIOL II em 2014) entram na robustez.
# Saídas: pasta resultados/ (ou a definida em OUT)
#
# PERÍODO: por padrão roda 2002–2019 (fase de obra, sem pandemia). Para rodar os
# dois períodos e comparar, use rodar_periodos.R, que define ANO_MAX, OUT,
# JANELAS e CONTROLE_AGRO antes de executar este script.
# =============================================================================

# ---- 0. Configuração ---------------------------------------------------------
pacotes <- c("dplyr", "tidyr", "purrr", "readr", "stringr", "ggplot2",
             "fixest", "did", "tidysynth", "synthdid", "HonestDiD", "MatchIt")
opcionais <- c("fwildclusterboot", "bacondecomp")
falta <- setdiff(pacotes, rownames(installed.packages()))
if (length(falta)) stop("Instale antes: ", paste(falta, collapse = ", "),
                        "\n(HonestDiD e synthdid: remotes::install_github('asheshrambachan/HonestDiD');",
                        " remotes::install_github('synth-inference/synthdid'))")
invisible(lapply(pacotes, library, character.only = TRUE))
tem_wild <- requireNamespace("fwildclusterboot", quietly = TRUE)

set.seed(2026)
# Parâmetros que rodar_periodos.R pode definir antes (senão, valores padrão)
if (!exists("OUT", inherits = FALSE))           OUT <- "resultados"
if (!exists("ANO_MAX", inherits = FALSE))       ANO_MAX <- 2019
if (!exists("CONTROLE_AGRO", inherits = FALSE)) CONTROLE_AGRO <- FALSE
dir.create(OUT, showWarnings = FALSE)
FERROV   <- c("FIOL I", "FIOL II", "FNS-ES")
POOL     <- c("FIOL I" = "BA", "FIOL II" = "BA", "FNS-ES" = "FNS")
ANO_MIN  <- 2002
PRE_FIM  <- 2009          # último ano antes de qualquer obra (covariáveis e normalização)
E_MIN    <- -9; E_MAX <- 12
B_BOOT   <- 199           # réplicas do bootstrap da média conjunta (aumentar na versão final)
N_RI     <- 999           # permutações da inferência por randomização

# Datas de tratamento por ferrovia (principal) e cenários de robustez
DATA_TRAT <- c("FIOL I" = 2011, "FIOL II" = 2013, "FNS-ES" = 2011)
CENARIOS  <- list("Data comum 2010"  = c("FIOL I" = 2010, "FIOL II" = 2010, "FNS-ES" = 2010),
                  "Data comum 2011"  = c("FIOL I" = 2011, "FIOL II" = 2011, "FNS-ES" = 2011),
                  "FIOL II em 2014"  = c("FIOL I" = 2011, "FIOL II" = 2014, "FNS-ES" = 2011))
# Janelas (fases) por ferrovia: nome = rótulo, valor = primeiro ano da janela
if (!exists("JANELAS", inherits = FALSE)) JANELAS <- if (ANO_MAX <= 2019) list(
  "FIOL I"  = c("2011-2015 obra" = 2011, "2016-2019 ritmo baixo" = 2016),
  "FIOL II" = c("2013-2017 início lento" = 2013, "2018-2019 retomada" = 2018),
  "FNS-ES"  = c("2011-2019 obra Valec" = 2011)) else list(
  "FIOL I"  = c("2011-2015 obra" = 2011, "2016-2020 ritmo baixo" = 2016, "2021-2023 concessão" = 2021),
  "FIOL II" = c("2013-2017 início lento" = 2013, "2018-2023 retomada" = 2018),
  "FNS-ES"  = c("2011-2018 obra Valec" = 2011, "2019-2020 conclusão" = 2019, "2021-2023 operação" = 2021))

# Efeitos fixos dos modelos fixest. Com CONTROLE_AGRO = TRUE (usado no período
# até 2023), cada ano ganha uma inclinação própria na participação do agro no VAB
# antes de 2010: absorve o boom de commodities de 2020–2022, que atinge mais os
# municípios agrícolas. No CS, sh_agro já está nas covariáveis (XFORM).
setFixest_fml(..fe = if (CONTROLE_AGRO) ~ id + ano^pool + ano[sh_agro] else ~ id + ano^pool)
message("Período 2002–", ANO_MAX, " | controle agro × ano: ", CONTROLE_AGRO, " | saída: ", OUT)

tema <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "top")
salva <- function(g, nome, w = 7, h = 4.5) ggsave(file.path(OUT, nome), g, width = w, height = h)

painel_raw <- read_csv("painel_municipal.csv", col_types = cols(cod_ibge = "c"))
grupos     <- read_csv("municipios_grupos.csv", col_types = cols(cod_ibge = "c"))
km_mun     <- if (file.exists("km_por_municipio.csv"))
  read_csv("km_por_municipio.csv", col_types = cols(cod_ibge = "c")) |>
  group_by(cod_ibge) |> summarise(km = sum(km_no_municipio), .groups = "drop") else
  tibble(cod_ibge = character(), km = numeric())
deflator   <- read_csv("deflator_pib.csv")       # ano, deflator (2020 = 100)

# ---- 1. Preparação -----------------------------------------------------------
# 1a. Data de tratamento: única por ferrovia (DATA_TRAT); 0 = nunca tratado.
data_de <- function(ferrovia, datas) unname(ifelse(ferrovia %in% names(datas), datas[ferrovia], 0))

# 1b. Painel analítico
painel <- painel_raw |>
  inner_join(grupos |> select(cod_ibge, nome, uf, ferrovia, pool, anel, outro_projeto_ferroviario),
             by = "cod_ibge") |>
  filter(ferrovia %in% FERROV |
           (ferrovia == "controle" & anel >= 3 & outro_projeto_ferroviario %in% c(0, NA))) |>
  left_join(km_mun, by = "cod_ibge") |>
  left_join(deflator, by = "ano") |>
  mutate(id        = as.numeric(cod_ibge),
         tratado   = ferrovia %in% FERROV,
         g         = as.integer(data_de(ferrovia, DATA_TRAT)),
         g_c2010   = as.integer(data_de(ferrovia, CENARIOS[["Data comum 2010"]])),
         g_c2011   = as.integer(data_de(ferrovia, CENARIOS[["Data comum 2011"]])),
         g_f2_2014 = as.integer(data_de(ferrovia, CENARIOS[["FIOL II em 2014"]])),
         pib_real  = pib * 100 / deflator,
         ln_pib    = log(pib_real),
         ln_pibpc  = log(1000 * pib_real / pop_interp),
         ln_pibpc_estoficial = log(1000 * pib_real / pop_estimada),
         emp_constr_mil = emp_secF_mil,
         emp_42_mil     = emp_div42_mil,
         ln_massa  = log(massa_dez_total * 100 / deflator + 1),
         iss_pc    = iss * 100 / deflator / pop_interp,
         rel       = ifelse(tratado, ano - g, NA_integer_))


# 1c. Covariáveis medidas ANTES das obras (médias 2002–2009) — não usar pós-2010
cov_pre <- painel |>
  filter(ano <= PRE_FIM) |>
  arrange(cod_ibge, ano) |>
  group_by(cod_ibge) |>
  summarise(ln_pop_2002   = log(first(pop_interp[ano == 2002])),
            sh_agro       = mean(vab_agro / vab, na.rm = TRUE),
            sh_ind        = mean(vab_ind  / vab, na.rm = TRUE),
            sh_apu        = mean(vab_apu  / vab, na.rm = TRUE),
            ln_pibpc_2002 = first(ln_pibpc[ano == 2002]),
            cresc_pre     = (last(ln_pib) - first(ln_pib)) / (n() - 1),
            soja_ha_pc    = mean(soja_area_ha / pop_interp, na.rm = TRUE),
            .groups = "drop")
painel <- painel |> left_join(cov_pre, by = "cod_ibge") |>
  filter(ano >= ANO_MIN, ano <= ANO_MAX)

XFORM <- ~ ln_pop_2002 + sh_agro + sh_ind + sh_apu + ln_pibpc_2002 + soja_ha_pc
DESFECHOS <- c(ln_pib = "ln(PIB real)", ln_pibpc = "ln(PIB real per capita)",
               emp_constr_mil = "Emprego na construção por mil hab.")
# Sem a RAIS no painel (FTP do MTE inacessível), o desfecho de emprego sai da lista:
# os modelos de PIB e PIB per capita rodam iguais; nada de emprego é estimado.
TEM_RAIS <- any(is.finite(painel$emp_constr_mil))
if (!TEM_RAIS) {
  warning("painel_municipal.csv sem RAIS: desfecho emp_constr_mil NÃO estimado.", call. = FALSE)
  DESFECHOS <- DESFECHOS[names(DESFECHOS) != "emp_constr_mil"]
}
# emp_42_mil só existe a partir de 2006 (CNAE 2.0); iss_pc a partir de 2013 (ou 2002 com FINBRA)

# psm = TRUE restringe aos tratados com par e aos controles pareados (seção 2f)
amostra <- function(k, dados = painel, psm = FALSE) {
  d <- dados |> filter(ferrovia == k | (ferrovia == "controle" & pool == POOL[[k]]))
  if (psm) d <- d |> filter(cod_ibge %in% c(PSM_TRAT[[k]], PSM_CTRL[[k]]))
  d
}

write_csv(painel |> distinct(cod_ibge, nome, uf, ferrovia, pool, g, g_c2010, g_c2011, g_f2_2014),
          file.path(OUT, "00_amostra_e_datas_tratamento.csv"))

# ---- 2. Descritivas e testes de médias ---------------------------------------
# 2a. Equilíbrio no período pré-obra: médias, diferença, teste t de Welch,
#     Wilcoxon e diferença normalizada (|dn| > 0,25 indica desequilíbrio).
vars_bal <- c("ln_pop_2002", "ln_pibpc_2002", "cresc_pre", "sh_agro", "sh_ind", "sh_apu", "soja_ha_pc")
balanco <- map_dfr(FERROV, function(k) {
  d <- amostra(k) |> select(cod_ibge, tratado, all_of(vars_bal)) |> distinct()
  map_dfr(vars_bal, function(v) {
    x1 <- d[[v]][d$tratado]; x0 <- d[[v]][!d$tratado]
    tibble(ferrovia = k, variavel = v,
           n_trat = sum(!is.na(x1)), n_ctrl = sum(!is.na(x0)),
           media_trat = mean(x1, na.rm = TRUE), media_ctrl = mean(x0, na.rm = TRUE),
           dif = media_trat - media_ctrl,
           dif_norm = dif / sqrt((var(x1, na.rm = TRUE) + var(x0, na.rm = TRUE)) / 2),
           p_t_welch = tryCatch(t.test(x1, x0)$p.value, error = function(e) NA),
           p_wilcoxon = tryCatch(wilcox.test(x1, x0, exact = FALSE)$p.value, error = function(e) NA))
  })
})
write_csv(balanco, file.path(OUT, "01_balanco_pre_obra.csv"))

g_bal <- ggplot(balanco, aes(dif_norm, variavel, colour = ferrovia, shape = ferrovia)) +
  annotate("rect", xmin = -0.25, xmax = 0.25, ymin = -Inf, ymax = Inf, fill = "grey92") +
  geom_vline(xintercept = 0, colour = "grey50") + geom_point(size = 2.5) +
  labs(x = "Diferença normalizada (tratados − controles)", y = NULL, colour = NULL, shape = NULL) + tema
salva(g_bal, "01_balanco_diferenca_normalizada.png")

# 2b. Trajetórias médias (log normalizado em 2009 = 0) por ferrovia, com IC 95%
traj <- map_dfr(FERROV, function(k) amostra(k) |> mutate(painel_f = k)) |>
  group_by(cod_ibge) |> mutate(y = ln_pib - first(ln_pib[ano == PRE_FIM])) |> ungroup() |>
  mutate(grupo = ifelse(tratado, "Tratados", "Controles")) |>
  group_by(painel_f, grupo, ano) |>
  summarise(m = mean(y, na.rm = TRUE), se = sd(y, na.rm = TRUE) / sqrt(sum(!is.na(y))), .groups = "drop")
g_traj <- ggplot(traj, aes(ano, m, colour = grupo, fill = grupo)) +
  geom_ribbon(aes(ymin = m - 1.96 * se, ymax = m + 1.96 * se), alpha = .15, colour = NA) +
  geom_line(linewidth = .8) +
  geom_vline(data = tibble(painel_f = FERROV, x = DATA_TRAT[FERROV] - .5), aes(xintercept = x),
             linetype = "dashed") +
  facet_wrap(~ painel_f, ncol = 3) +
  labs(x = NULL, y = "ln(PIB real), 2009 = 0", colour = NULL, fill = NULL) + tema
salva(g_traj, "02_trajetorias_pib.png", w = 9, h = 3.8)

# 2c. Emprego na construção em torno do início da obra (checagem das datas):
#     deve subir no ano 0 se as datas estiverem corretas.
if (TEM_RAIS) {
g_emp <- painel |> filter(tratado, between(rel, E_MIN, E_MAX)) |>
  group_by(ferrovia, rel) |>
  summarise(m = mean(emp_constr_mil, na.rm = TRUE),
            se = sd(emp_constr_mil, na.rm = TRUE) / sqrt(n()), .groups = "drop") |>
  ggplot(aes(rel, m)) +
  geom_ribbon(aes(ymin = m - 1.96 * se, ymax = m + 1.96 * se), alpha = .15) +
  geom_line() + geom_point() + geom_vline(xintercept = -.5, linetype = "dashed") +
  facet_wrap(~ ferrovia) +
  labs(x = "Anos desde o início da obra", y = "Emprego na construção / mil hab.") + tema
salva(g_emp, "03_emprego_construcao_tempo_evento.png", w = 9, h = 3.5)
}

# 2d. Diferença em diferenças de médias simples (2x2) com testes:
#     por município, Δ = média pós (ano >= data da ferrovia) − média pré;
#     compara Δ de tratados e controles (Welch e Wilcoxon).
dd_medias <- map_dfr(FERROV, function(k) map_dfr(names(DESFECHOS), function(v) {
  gk <- DATA_TRAT[[k]]
  d <- amostra(k) |> group_by(cod_ibge, tratado) |>
    summarise(pre = mean(.data[[v]][ano <  gk], na.rm = TRUE),
              pos = mean(.data[[v]][ano >= gk], na.rm = TRUE), .groups = "drop") |>
    mutate(delta = pos - pre) |> filter(is.finite(delta))
  x1 <- d$delta[d$tratado]; x0 <- d$delta[!d$tratado]
  tibble(ferrovia = k, desfecho = v,
         pre_trat = mean(d$pre[d$tratado]), pos_trat = mean(d$pos[d$tratado]),
         pre_ctrl = mean(d$pre[!d$tratado]), pos_ctrl = mean(d$pos[!d$tratado]),
         did_medias = mean(x1) - mean(x0),
         p_t_welch = tryCatch(t.test(x1, x0)$p.value, error = function(e) NA),
         p_wilcoxon = tryCatch(wilcox.test(x1, x0, exact = FALSE)$p.value, error = function(e) NA))
}))
write_csv(dd_medias, file.path(OUT, "02_did_medias_2x2.csv"))

# 2e. Crescimento anual médio pré e pós por grupo (boxplot)
g_box <- map_dfr(FERROV, function(k) amostra(k) |> mutate(painel_f = k, gk = DATA_TRAT[[k]])) |>
  group_by(painel_f, cod_ibge, tratado) |> arrange(ano) |>
  summarise(pre = (first(ln_pib[ano == gk[1] - 1]) - first(ln_pib[ano == ANO_MIN])) / (gk[1] - 1 - ANO_MIN),
            pos = (first(ln_pib[ano == ANO_MAX]) - first(ln_pib[ano == gk[1] - 1])) / (ANO_MAX - gk[1] + 1),
            .groups = "drop") |>
  pivot_longer(c(pre, pos), names_to = "periodo", values_to = "cresc") |>
  mutate(periodo = factor(periodo, c("pre", "pos"), c("Antes da obra", "Depois do início")),
         grupo = ifelse(tratado, "Tratados", "Controles")) |>
  ggplot(aes(periodo, 100 * cresc, fill = grupo)) + geom_boxplot(outlier.size = .8) +
  facet_wrap(~ painel_f) + labs(x = NULL, y = "Crescimento anual médio do PIB real (%)", fill = NULL) + tema
salva(g_box, "04_boxplot_crescimento.png", w = 9, h = 3.8)

# ---- 2f. Escore de propensão: pareamento por ferrovia -------------------------
# Substitui a escolha manual de controles (RMSE / valores-p) por uma regra fixa,
# definida antes de olhar os resultados. Logit da probabilidade de estar no
# corredor, com características de 2002–2009; 3 vizinhos mais próximos por
# tratado, sem reposição, com caliper de 0,25 DP do logit do escore.
# Covariáveis: estrutura produtiva e crescimento, não o NÍVEL do PIB (parear
# pelo nível pode gerar regressão à média — Daw & Hatfield, 2018).
PS_FORM  <- tratado ~ ln_pop_2002 + sh_agro + sh_ind + sh_apu + cresc_pre + soja_ha_pc
PS_RATIO <- 3; PS_CALIPER <- 0.25
PSM_TRAT <- list(); PSM_CTRL <- list()
psm_balanco <- list(); psm_escores <- list()

for (k in FERROV) {
  cross <- amostra(k) |> select(cod_ibge, nome, tratado, all_of(all.vars(PS_FORM)[-1])) |>
    distinct() |> filter(if_all(all.vars(PS_FORM)[-1], ~ is.finite(.x))) |>
    mutate(tratado = as.integer(tratado))
  m <- matchit(PS_FORM, data = as.data.frame(cross), method = "nearest", distance = "glm",
               ratio = PS_RATIO, replace = FALSE, caliper = PS_CALIPER, std.caliper = TRUE)
  md <- match.data(m)
  PSM_TRAT[[k]] <- md$cod_ibge[md$tratado == 1]
  PSM_CTRL[[k]] <- md$cod_ibge[md$tratado == 0]
  sm <- summary(m, un = TRUE)
  bal <- function(tab, quando) tibble(variavel = rownames(tab), quando = quando,
                                      dif_padronizada = tab[, "Std. Mean Diff."])
  psm_balanco[[k]] <- bind_rows(bal(sm$sum.all, "Antes"), bal(sm$sum.matched, "Depois")) |>
    mutate(ferrovia = k)
  psm_escores[[k]] <- tibble(ferrovia = k, tratado = cross$tratado == 1, escore = m$distance,
                             pareado = cross$cod_ibge %in% md$cod_ibge)
  message(k, ": ", length(PSM_TRAT[[k]]), " de ", sum(cross$tratado == 1), " tratados com par; ",
          length(PSM_CTRL[[k]]), " controles pareados de ", sum(cross$tratado == 0), " elegíveis")
}
write_csv(bind_rows(psm_balanco), file.path(OUT, "02f_psm_balanco.csv"))
write_csv(imap_dfr(PSM_CTRL, ~ tibble(ferrovia = .y, cod_ibge = .x, papel = "controle")) |>
            bind_rows(imap_dfr(PSM_TRAT, ~ tibble(ferrovia = .y, cod_ibge = .x, papel = "tratado"))) |>
            left_join(painel |> distinct(cod_ibge, nome, uf), by = "cod_ibge"),
          file.path(OUT, "02f_psm_amostra_pareada.csv"))
# tratados sem par (fora do suporte comum) — reportar na dissertação
write_csv(map_dfr(FERROV, function(k) amostra(k) |> filter(tratado, !cod_ibge %in% PSM_TRAT[[k]]) |>
                    distinct(ferrovia, cod_ibge, nome)),
          file.path(OUT, "02f_psm_tratados_sem_par.csv"))

salva(bind_rows(psm_balanco) |> filter(variavel != "distance") |>
        ggplot(aes(dif_padronizada, variavel, colour = quando, shape = quando)) +
        annotate("rect", xmin = -0.1, xmax = 0.1, ymin = -Inf, ymax = Inf, fill = "grey92") +
        geom_vline(xintercept = 0, colour = "grey50") + geom_point(size = 2.5) +
        scale_colour_manual(values = c(Antes = "grey55", Depois = "#2a78d6")) +
        facet_wrap(~ ferrovia) +
        labs(x = "Diferença padronizada de médias (tratados − controles)", y = NULL,
             colour = NULL, shape = NULL) + tema,
      "02f_psm_equilibrio.png", w = 10, h = 4)
salva(bind_rows(psm_escores) |>
        mutate(grupo = ifelse(tratado, "Tratados", "Controles elegíveis")) |>
        ggplot(aes(escore, fill = grupo)) + geom_density(alpha = .4, colour = NA) +
        facet_wrap(~ ferrovia, scales = "free_y") +
        labs(x = "Escore de propensão", y = "Densidade", fill = NULL) + tema,
      "02f_psm_suporte_comum.png", w = 10, h = 3.8)
# Ler: |dif. padronizada| < 0,1 depois do pareamento = bom equilíbrio; as
# densidades devem se sobrepor (suporte comum).

# ---- 3. Controle sintético agregado por ferrovia -----------------------------
# Unidade tratada = soma do PIB real dos municípios da ferrovia. Para resolver a
# diferença de escala, todas as séries são centradas na média pré-obra:
# y = 100 × (ln PIB − média 2002–2009 de ln PIB).
scm_ferrovia <- function(k, psm = FALSE) {
  d <- amostra(k, psm = psm); gk <- DATA_TRAT[[k]]
  trat <- d |> filter(tratado) |> group_by(ano) |>
    summarise(pib_real = sum(pib_real), sh_agro = weighted.mean(vab_agro / vab, vab, na.rm = TRUE),
              sh_ind = weighted.mean(vab_ind / vab, vab, na.rm = TRUE), .groups = "drop") |>
    mutate(unidade = paste0("TRAT_", k))
  ctrl <- d |> filter(!tratado) |>
    transmute(ano, pib_real, sh_agro = vab_agro / vab, sh_ind = vab_ind / vab, unidade = cod_ibge)
  bind_rows(trat, ctrl) |>
    group_by(unidade) |>
    mutate(y = 100 * (log(pib_real) - mean(log(pib_real)[ano < gk]))) |> ungroup() |>
    filter(!is.na(y)) |>
    synthetic_control(outcome = y, unit = unidade, time = ano,
                      i_unit = paste0("TRAT_", k), i_time = gk,
                      generate_placebos = TRUE) |>
    generate_predictor(time_window = ANO_MIN:(gk - 1),
                       sh_agro = mean(sh_agro, na.rm = TRUE), sh_ind = mean(sh_ind, na.rm = TRUE)) |>
    generate_predictor(time_window = 2003, y2003 = y) |>
    generate_predictor(time_window = 2006, y2006 = y) |>
    generate_predictor(time_window = 2009, y2009 = y) |>
    generate_weights(optimization_window = ANO_MIN:(gk - 1),
                     margin_ipop = .02, sigf_ipop = 7, bound_ipop = 6) |>
    generate_control()
}
# O ajuste com placebos refaz o controle sintético uma vez por doador: com todos os
# controles elegíveis (271 na BA, ~1.570 na FNS) leva dias. SCM_COMPLETO=0 no ambiente
# pula esta seção; o controle sintético com doadores pareados (seção 11) e o SC do
# synthdid (seção 4) continuam rodando. Padrão: roda (comportamento original).
SCM_COMPLETO <- Sys.getenv("SCM_COMPLETO", "1") == "1"
if (!SCM_COMPLETO) message("SCM_COMPLETO=0: seção 3 (controle sintético com todos os doadores) NÃO executada.")
scm <- if (SCM_COMPLETO) set_names(map(FERROV, scm_ferrovia), FERROV) else list()
iwalk(scm, function(s, k) {
  tag <- str_replace_all(k, "[^A-Za-z]", "")
  salva(plot_trends(s) + labs(title = k), paste0("05_scm_trajetoria_", tag, ".png"))
  salva(plot_placebos(s) + labs(title = k), paste0("05_scm_placebos_", tag, ".png"))
  write_csv(grab_significance(s), file.path(OUT, paste0("05_scm_inferencia_", tag, ".csv")))
  write_csv(grab_unit_weights(s), file.path(OUT, paste0("05_scm_pesos_", tag, ".csv")))
  write_csv(grab_balance_table(s), file.path(OUT, paste0("05_scm_balanco_", tag, ".csv")))
})
# Ler: p-valor = posição da razão RMSPE pós/pré da unidade tratada entre os placebos.

# ---- 4. Synthetic DiD por ferrovia --------------------------------------------
# Exige painel balanceado e início comum: usa a data da ferrovia (DATA_TRAT).
sdid_ferrovia <- function(k, y = "ln_pib", psm = FALSE) {
  d <- amostra(k, psm = psm)
  g0 <- DATA_TRAT[[k]]
  df <- d |> transmute(unidade = cod_ibge, ano, y = .data[[y]],
                       W = as.integer(tratado & ano >= g0)) |>
    group_by(unidade) |> filter(sum(!is.na(y)) == n_distinct(painel$ano)) |> ungroup() |>
    as.data.frame()
  pm <- panel.matrices(df, unit = 1, time = 2, outcome = 3, treatment = 4)
  est <- list(SDID = synthdid_estimate(pm$Y, pm$N0, pm$T0),
              SC   = sc_estimate(pm$Y, pm$N0, pm$T0),
              DiD  = did_estimate(pm$Y, pm$N0, pm$T0))
  tab <- imap_dfr(est, ~ tibble(ferrovia = k, desfecho = y, estimador = .y, ano_inicio = g0,
                                efeito = as.numeric(.x),
                                se = as.numeric(sqrt(vcov(.x, method = "placebo")))))
  list(tab = tab, sdid = est$SDID)
}
sdid_res <- map(FERROV, function(k) map(c("ln_pib", "ln_pibpc"), ~ sdid_ferrovia(k, .x)))
sdid_tab <- map_dfr(sdid_res, ~ map_dfr(.x, "tab")) |>
  mutate(ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se)
write_csv(sdid_tab, file.path(OUT, "06_sdid_sc_did.csv"))
iwalk(set_names(sdid_res, FERROV), function(r, k)
  salva(synthdid_plot(r[[1]]$sdid) + labs(title = paste(k, "— ln(PIB real)")),
        paste0("06_sdid_", str_replace_all(k, "[^A-Za-z]", ""), ".png")))

# ---- 5. Callaway & Sant'Anna --------------------------------------------------
# Covariável sem variação entre os controles da ferrovia não pode entrar no ajuste
# (matriz singular -> todos os ATT(g,t) viram NA). É o caso da soja na Bahia: nenhum
# controle elegível tinha soja em 2002–2009. A fórmula é montada por ferrovia e as
# covariáveis retiradas ficam registradas em 07_cs_covariaveis.csv.
XFORM_K <- map(set_names(FERROV), function(k) {
  ctrl <- amostra(k) |> filter(!tratado) |> distinct(cod_ibge, across(all_of(all.vars(XFORM))))
  fora <- all.vars(XFORM)[map_lgl(all.vars(XFORM), ~ isTRUE(sd(ctrl[[.x]], na.rm = TRUE) < 1e-12))]
  if (length(fora)) message("CS ", k, ": covariável sem variação nos controles retirada: ", paste(fora, collapse = ", "))
  reformulate(setdiff(all.vars(XFORM), fora))
})
write_csv(imap_dfr(XFORM_K, ~ tibble(ferrovia = .y, covariaveis_usadas = paste(all.vars(.x), collapse = " + "),
                                     retiradas_sem_variacao = paste(setdiff(all.vars(XFORM), all.vars(.x)), collapse = " + "))),
          file.path(OUT, "07_cs_covariaveis.csv"))
cs_ferrovia <- function(dados, k, y, controle = "nevertreated", gcol = "g", bstrap = FALSE,
                        antecip = 0, psm = FALSE) {
  d <- amostra(k, dados, psm = psm) |> mutate(gg = .data[[gcol]]) |> filter(!is.na(.data[[y]]))
  m <- att_gt(yname = y, tname = "ano", idname = "id", gname = "gg", xformla = XFORM_K[[k]],
              data = d, control_group = controle, base_period = "universal",
              anticipation = antecip, est_method = "dr", allow_unbalanced_panel = TRUE,
              bstrap = bstrap, cband = FALSE, print_details = FALSE)
  list(gt = m,
       din = aggte(m, type = "dynamic", min_e = E_MIN, max_e = E_MAX, na.rm = TRUE, bstrap = bstrap),
       sim = aggte(m, type = "simple", na.rm = TRUE, bstrap = bstrap))
}

cs_tudo <- function(dados, y) {
  res <- set_names(map(FERROV, ~ cs_ferrovia(dados, .x, y)), FERROV)
  n_t <- dados |> filter(tratado) |> distinct(id, ferrovia) |> count(ferrovia)
  w <- setNames(n_t$n, n_t$ferrovia)[FERROV]; w <- w / sum(w)
  sem2 <- c("FIOL I", "FNS-ES"); w2 <- w[sem2] / sum(w[sem2])
  e <- E_MIN:E_MAX
  b <- map(res, ~ .x$din$att.egt[match(e, .x$din$egt)])
  a <- map_dbl(res, ~ .x$sim$overall.att)
  list(res = res, e = e,
       b = c(list("Média conjunta" = Reduce(`+`, map2(b, w, `*`)),
                  "Média sem FIOL II" = Reduce(`+`, map2(b[sem2], w2, `*`))), b),
       att = c("Média conjunta" = sum(a * w), "Média sem FIOL II" = sum(a[sem2] * w2), a))
}

# bootstrap por município, estratificado por ferrovia/pool (capta controles compartilhados)
boot_cs <- function(y, B = B_BOOT) {
  mun <- painel |> distinct(cod_ibge, ferrovia, pool)
  compact(map(seq_len(B), function(b) {
    s <- mun |> group_by(ferrovia, pool) |> slice_sample(prop = 1, replace = TRUE) |>
      ungroup() |> mutate(id_novo = row_number())
    d <- s |> select(cod_ibge, id_novo) |>
      inner_join(painel, by = "cod_ibge", relationship = "many-to-many") |>
      mutate(id = id_novo)
    tryCatch({ r <- cs_tudo(d, y); list(b = r$b, att = r$att) }, error = function(e) NULL)
  }))
}

cs_resultados <- map(set_names(names(DESFECHOS)), function(y) {
  est <- cs_tudo(painel, y)
  bt  <- boot_cs(y)
  paineis <- names(est$b)
  fig <- map_dfr(paineis, function(p) {
    bm <- sapply(bt, function(x) x$b[[p]]); se <- apply(bm, 1, sd, na.rm = TRUE)
    tibble(painel = p, e = est$e, b = est$b[[p]], lo = b - 1.96 * se, hi = b + 1.96 * se,
           att = est$att[[p]])
  }) |> filter(!is.na(b)) |> mutate(painel = factor(painel, paineis))
  # tabela: efeito médio, IC, p, pré-tendência (Wald), MDE
  A <- sapply(bt, function(x) x$att)
  tab <- map_dfr(paineis, function(p) {
    se <- sd(A[p, ]); pre <- est$e < -1
    Bp <- t(sapply(bt, function(x) x$b[[p]][pre])); okc <- colSums(is.na(Bp)) == 0
    bp <- est$b[[p]][pre][okc]; V <- cov(Bp[, okc, drop = FALSE])
    W  <- as.numeric(t(bp) %*% MASS::ginv(V) %*% bp)
    tibble(desfecho = y, painel = p, efeito = est$att[[p]],
           efeito_pct = 100 * (exp(est$att[[p]]) - 1),
           ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se,
           p_valor = 2 * pnorm(-abs(efeito / se)),
           p_pretendencia = pchisq(W, df = length(bp), lower.tail = FALSE),
           mde_80 = 2.8 * se)
  })
  C <- rbind(c(1, -1, 0), c(1, 0, -1)); v <- est$att[FERROV]
  Wq <- as.numeric(t(C %*% v) %*% MASS::ginv(C %*% cov(t(A[FERROV, ])) %*% t(C)) %*% (C %*% v))
  tab <- bind_rows(tab, tibble(desfecho = y, painel = "Teste de igualdade (chi2, 2 gl)",
                               efeito = Wq, p_valor = pchisq(Wq, 2, lower.tail = FALSE)))
  g <- ggplot(fig, aes(e, b, colour = e >= 0, shape = e >= 0)) +
    annotate("rect", xmin = -Inf, xmax = -.5, ymin = -Inf, ymax = Inf, fill = "grey95") +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_vline(xintercept = -.5, linetype = "dashed", colour = "grey50") +
    geom_segment(data = distinct(fig, painel, att),
                 aes(x = -.5, xend = E_MAX, y = att, yend = att),
                 inherit.aes = FALSE, linetype = "dashed", colour = "#2a78d6") +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0) + geom_point(size = 2) +
    scale_colour_manual(values = c("grey45", "#2a78d6"), labels = c("Antes da obra", "Depois do início")) +
    scale_shape_manual(values = c(16, 15), labels = c("Antes da obra", "Depois do início")) +
    facet_wrap(~ painel, ncol = 3, scales = "fixed") +
    labs(x = "Anos desde o início da obra", y = paste("Efeito sobre", DESFECHOS[[y]]),
         colour = NULL, shape = NULL) + tema
  salva(g, paste0("07_cs_event_study_", y, ".png"), w = 10, h = 6)
  write_csv(tab, file.path(OUT, paste0("07_cs_tabela_", y, ".csv")))
  list(est = est, tab = tab)
})

# 5b. Robustez do CS: datas alternativas e antecipação de 1 ano
rob_cs <- map_dfr(FERROV, function(k) {
  esp <- list("Principal (2011 / FIOL II 2013)" = list(g = "g",         a = 0),
              "Data comum 2010"                 = list(g = "g_c2010",   a = 0),
              "Data comum 2011"                 = list(g = "g_c2011",   a = 0),
              "FIOL II em 2014"                 = list(g = "g_f2_2014", a = 0),
              "Data comum 2010 + antecipação 1" = list(g = "g_c2010",   a = 1),
              "Principal + antecipação 1"       = list(g = "g",         a = 1))
  imap_dfr(esp, function(s, nome) {
    r <- tryCatch(cs_ferrovia(painel, k, "ln_pib", "nevertreated", s$g, bstrap = TRUE, antecip = s$a),
                  error = function(e) NULL)
    if (is.null(r)) return(NULL)
    tibble(ferrovia = k, especificacao = nome,
           efeito = r$sim$overall.att, se = r$sim$overall.se)
  })
})
write_csv(rob_cs, file.path(OUT, "08_cs_robustez.csv"))

# ---- 6. TWFE e Sun & Abraham (fixest) -----------------------------------------
# Efeitos fixos de município e de ano×pool (cada ferrovia vs. sua região).
painel_fx <- painel |>
  mutate(pos = as.integer(tratado & ano >= g),
         coorte_sa = ifelse(tratado, g, 10000),                    # nunca tratado = 10000
         rel_bin = pmin(pmax(ifelse(tratado, ano - g, -1000), E_MIN), E_MAX),
         rel_bin = ifelse(tratado, rel_bin, -1000))

twfe <- map(set_names(c("Todas", FERROV)), function(k) {
  d <- if (k == "Todas") painel_fx else amostra(k, painel_fx)
  list(
    estatico = feols(as.formula(paste0("c(", paste(names(DESFECHOS), collapse = ", "), ") ~ pos | ..fe")),
                     data = d, cluster = ~ id),
    sunab    = feols(ln_pib ~ sunab(coorte_sa, ano) | ..fe, data = d, cluster = ~ id),
    es_twfe  = feols(ln_pib ~ i(rel_bin, ref = c(-1, -1000)) | ..fe, data = d, cluster = ~ id))
})
# Uma tabela por amostra no mesmo arquivo: nesta versão do fixest, etable() falha ao
# juntar numa só tabela modelos estimados em amostras diferentes.
iwalk(map(twfe, "estatico"), function(m, k)
  etable(m, title = paste("TWFE estático — amostra:", k),
         file = file.path(OUT, "09_twfe_estatico.tex"), replace = (k == "Todas")))
write_csv(imap_dfr(map(twfe, "estatico"), function(m, k) map_dfr(seq_along(m), function(i) {
  ct <- coeftable(m[[i]])
  tibble(amostra = k, desfecho = names(DESFECHOS)[i], efeito = ct["pos", 1], se = ct["pos", 2],
         p_valor = ct["pos", 4], n_obs = nobs(m[[i]]))
})), file.path(OUT, "09_twfe_estatico.csv"))
write_csv(map_dfr(names(twfe), function(k) {
  s <- summary(twfe[[k]]$sunab, agg = "ATT")
  tibble(amostra = k, efeito = coef(s)[["ATT"]], se = se(s)[["ATT"]])
}), file.path(OUT, "09_sunab_att.csv"))
png(file.path(OUT, "09_twfe_vs_sunab.png"), width = 1800, height = 1100, res = 200)
iplot(list(twfe$Todas$es_twfe, twfe$Todas$sunab), sep = .2,
      main = "Estudo de eventos: TWFE (preto) x Sun & Abraham (vermelho)",
      xlab = "Anos desde o início da obra")
dev.off()

# ---- 6b. Decomposição de Goodman-Bacon ----------------------------------------
# Quanto do coeficiente TWFE vem de comparações "limpas" (tratado x nunca
# tratado) e quanto de comparações problemáticas (tratado x já tratado).
# Exige painel balanceado; a decomposição usa só efeitos fixos de unidade e ano.
if (requireNamespace("bacondecomp", quietly = TRUE)) {
  bacon_res <- map_dfr(c("Todas", FERROV), function(k) {
    d <- (if (k == "Todas") painel_fx else amostra(k, painel_fx)) |>
      filter(!is.na(ln_pib)) |> group_by(id) |>
      filter(n() == n_distinct(painel_fx$ano)) |> ungroup() |>
      select(id, ano, ln_pib, pos) |> as.data.frame()
    b <- tryCatch(bacondecomp::bacon(ln_pib ~ pos, data = d, id_var = "id",
                                     time_var = "ano", quietly = TRUE),
                  error = function(e) { message("bacon (", k, "): ", conditionMessage(e)); NULL })
    if (is.null(b)) return(NULL)
    b |> mutate(amostra = k)
  })
  bacon_resumo <- bacon_res |> group_by(amostra, type) |>
    summarise(peso = sum(weight), efeito_medio = weighted.mean(estimate, weight), .groups = "drop")
  write_csv(bacon_resumo, file.path(OUT, "09b_bacon_resumo.csv"))
  write_csv(bacon_res,    file.path(OUT, "09b_bacon_2x2.csv"))
  salva(ggplot(bacon_res, aes(weight, estimate, colour = type, shape = type)) +
          geom_hline(yintercept = 0, colour = "grey60") + geom_point(size = 2) +
          facet_wrap(~ amostra) +
          labs(x = "Peso no coeficiente TWFE", y = "Estimativa 2x2", colour = NULL, shape = NULL) + tema,
        "09b_bacon_decomposicao.png", w = 8, h = 5)
  # Ler: se o peso de "Later vs Earlier Treated" for pequeno, TWFE e CS devem
  # concordar; se for grande e com sinal diferente, o TWFE não é confiável aqui.
} else message("Instale bacondecomp para a decomposição de Goodman-Bacon (seção 6b).")

# ---- 6c. Efeitos por janela (fases da obra) -----------------------------------
# Um coeficiente por fase em vez de um efeito único: tratados × janela, com
# efeitos fixos de município e ano. Referência = anos antes da obra.
janelas_res <- map_dfr(FERROV, function(k) {
  jj <- JANELAS[[k]]
  d <- amostra(k, painel_fx) |>
    mutate(janela = as.character(cut(ano, breaks = c(-Inf, unname(jj), Inf), right = FALSE,
                                     labels = c("pre", names(jj)))),
           tr = as.integer(tratado))
  map_dfr(names(DESFECHOS), function(y) {
    m <- tryCatch(feols(as.formula(paste(y, "~ i(janela, tr, ref = 'pre') | ..fe")),
                        data = d, cluster = ~ id), error = function(e) NULL)
    if (is.null(m)) return(NULL)
    ct <- coeftable(m)
    tibble(ferrovia = k, desfecho = y, termo = rownames(ct),
           janela = str_remove(rownames(ct), "^janela::|:tr$") |> str_remove(":tr"),
           efeito = ct[, 1], se = ct[, 2],
           ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se)
  })
})
write_csv(janelas_res, file.path(OUT, "09c_efeitos_por_janela.csv"))
salva(janelas_res |> filter(desfecho == "ln_pib") |>
        ggplot(aes(janela, efeito)) + geom_hline(yintercept = 0, colour = "grey60") +
        geom_pointrange(aes(ymin = ic_inf, ymax = ic_sup), colour = "#2a78d6") +
        facet_wrap(~ ferrovia, scales = "free_x") +
        labs(x = NULL, y = "Efeito sobre ln(PIB real)") + tema +
        theme(axis.text.x = element_text(angle = 20, hjust = 1)),
      "09c_efeitos_por_janela.png", w = 10, h = 4)

# ---- 7. Inferência robusta ---------------------------------------------------
# 7a. Wild cluster bootstrap (pesos de Webb) para o modelo estático
if (tem_wild) {
  wild <- map_dfr(names(twfe), function(k) {
    m <- feols(ln_pib ~ pos | ..fe,
               data = if (k == "Todas") painel_fx else amostra(k, painel_fx), cluster = ~ id)
    bt <- tryCatch(fwildclusterboot::boottest(m, param = "pos", clustid = "id", B = 9999, type = "webb"),
                   error = function(e) { message("boottest (", k, "): ", conditionMessage(e)); NULL })
    tibble(amostra = k, efeito = coef(m)[["pos"]], p_cluster = pvalue(m)[["pos"]],
           p_wild = if (is.null(bt)) NA else bt$p_val,
           ic_wild_inf = if (is.null(bt)) NA else bt$conf_int[1],
           ic_wild_sup = if (is.null(bt)) NA else bt$conf_int[2])
  })
  write_csv(wild, file.path(OUT, "10_wild_bootstrap.csv"))
} else message("fwildclusterboot não instalado: pulando 7a.")

# 7b. Inferência por randomização: sorteia quais municípios do pool recebem as
#     datas de início observadas e reestima; p = fração de |efeito| ≥ observado.
ri <- map_dfr(FERROV, function(k) {
  d <- amostra(k, painel_fx)
  obs <- coef(feols(ln_pib ~ pos | ..fe, data = d))[["pos"]]
  ids <- unique(d$id); gs <- d |> filter(tratado) |> distinct(id, g) |> pull(g)
  sim <- replicate(N_RI, {
    fake <- tibble(id = sample(ids, length(gs)), gf = gs)
    dd <- d |> select(-pos) |> left_join(fake, by = "id") |>
      mutate(pos = as.integer(!is.na(gf) & ano >= gf))
    coef(feols(ln_pib ~ pos | ..fe, data = dd))[["pos"]]
  })
  tibble(ferrovia = k, efeito = obs, p_randomizacao = mean(abs(sim) >= abs(obs)))
})
write_csv(ri, file.path(OUT, "10_inferencia_randomizacao.csv"))

# ---- 8. HonestDiD: quanto de violação de tendências anula a conclusão? -------
# Usa o estudo de eventos do CS (base_period = "universal"); remove o ano −1.
honest <- function(din, Mbar = c(0, .5, 1, 1.5, 2)) {
  e <- din$egt; keep <- e != -1
  inf <- din$inf.function$dynamic.inf.func.e[, keep, drop = FALSE]
  V <- crossprod(inf) / nrow(inf)^2
  b <- din$att.egt[keep]; npre <- sum(e[keep] < 0); npost <- sum(e[keep] >= 0)
  rob <- createSensitivityResults_relativeMagnitudes(betahat = b, sigma = V,
           numPrePeriods = npre, numPostPeriods = npost, Mbarvec = Mbar,
           l_vec = rep(1 / npost, npost))                       # média pós-obra
  ori <- constructOriginalCS(betahat = b, sigma = V, numPrePeriods = npre,
           numPostPeriods = npost, l_vec = rep(1 / npost, npost))
  list(rob = rob, ori = ori)
}
iwalk(cs_resultados$ln_pib$est$res, function(r, k) {
  h <- tryCatch(honest(r$din), error = function(e) NULL); if (is.null(h)) return()
  write_csv(h$rob, file.path(OUT, paste0("11_honestdid_", str_replace_all(k, "[^A-Za-z]", ""), ".csv")))
  salva(createSensitivityPlot_relativeMagnitudes(h$rob, h$ori) + labs(title = k),
        paste0("11_honestdid_", str_replace_all(k, "[^A-Za-z]", ""), ".png"), w = 6, h = 4)
})
# Ler: Mbar = 1 admite violação pós-obra tão grande quanto a maior pré-obra observada.

# ---- 9. Poder: efeito mínimo detectável por placebo ---------------------------
# Só controles: sorteia N_T "tratados" falsos com as datas reais; a dispersão
# das estimativas é o erro-padrão sob ausência de efeito. MDE ≈ 2,8 × DP.
mde <- map_dfr(FERROV, function(k) {
  d <- amostra(k, painel_fx) |> filter(!tratado)
  gs <- amostra(k, painel_fx) |> filter(tratado) |> distinct(id, g) |> pull(g)
  ids <- unique(d$id)
  sim <- replicate(500, {
    fake <- tibble(id = sample(ids, length(gs)), gf = gs)
    dd <- d |> left_join(fake, by = "id") |> mutate(pos = as.integer(!is.na(gf) & ano >= gf))
    coef(feols(ln_pib ~ pos | id + ano, data = dd))[["pos"]]
  })
  tibble(ferrovia = k, n_trat = length(gs), n_ctrl_pool = length(ids) - length(gs),
         dp_placebo = sd(sim), mde_80_pct = 100 * (exp(2.8 * sd(sim)) - 1))
})
write_csv(mde, file.path(OUT, "12_mde_placebo.csv"))

# ---- 10. (Opcional) intensidade ---------------------------------------------
# Requer km_por_municipio.csv (gerado por calcular_aneis.R a partir do traçado).
if (any(painel_fx$km > 0, na.rm = TRUE)) {
  dose <- feols(ln_pib ~ pos:log1p(km) + pos | ..fe,
                data = painel_fx |> mutate(km = coalesce(km, 0)), cluster = ~ id)
  etable(dose, file = file.path(OUT, "13_intensidade_km.tex"), replace = TRUE)
}

# ---- 11. Amostra pareada por escore de propensão x todos os controles ----------
# Mesmos estimadores nas duas amostras de controle; se os efeitos forem
# parecidos, o resultado não depende da escolha do grupo de controle.
psm_comp <- map_dfr(FERROV, function(k) map_dfr(c(FALSE, TRUE), function(ps) {
  rot <- if (ps) "Pareados (escore de propensão)" else "Todos os elegíveis"
  n_t <- n_distinct(amostra(k, psm = ps)$cod_ibge[amostra(k, psm = ps)$tratado])
  n_c <- n_distinct(amostra(k, psm = ps)$cod_ibge[!amostra(k, psm = ps)$tratado])
  cs <- map_dfr(c("ln_pib", "ln_pibpc", "emp_constr_mil"), function(y) {
    r <- tryCatch(cs_ferrovia(painel, k, y, bstrap = TRUE, psm = ps), error = function(e) NULL)
    if (is.null(r)) return(NULL)
    tibble(estimador = "Callaway & Sant'Anna", desfecho = y,
           efeito = r$sim$overall.att, se = r$sim$overall.se)
  })
  tw <- tryCatch({
    m <- feols(c(ln_pib, ln_pibpc) ~ pos | ..fe, data = amostra(k, painel_fx, psm = ps), cluster = ~ id)
    map_dfr(c("ln_pib", "ln_pibpc"), function(y) {
      mm <- m[lhs = y]
      tibble(estimador = "TWFE", desfecho = y, efeito = coef(mm)[["pos"]], se = se(mm)[["pos"]])
    })
  }, error = function(e) NULL)
  sd <- map_dfr(c("ln_pib", "ln_pibpc"), function(y) {
    r <- tryCatch(sdid_ferrovia(k, y, psm = ps)$tab, error = function(e) NULL)
    if (is.null(r)) return(NULL)
    r |> filter(estimador == "SDID") |> transmute(estimador = "Synthetic DiD", desfecho, efeito, se)
  })
  bind_rows(cs, tw, sd) |> mutate(ferrovia = k, controles = rot, n_trat = n_t, n_ctrl = n_c)
})) |>
  mutate(ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se,
         p_valor = 2 * pnorm(-abs(efeito / se)))
write_csv(psm_comp, file.path(OUT, "14_psm_vs_todos.csv"))

salva(psm_comp |> filter(desfecho == "ln_pib") |>
        ggplot(aes(efeito, estimador, colour = controles, shape = controles)) +
        geom_vline(xintercept = 0, colour = "grey60") +
        geom_pointrange(aes(xmin = ic_inf, xmax = ic_sup), position = position_dodge(width = .5)) +
        scale_colour_manual(values = c("Todos os elegíveis" = "grey45",
                                       "Pareados (escore de propensão)" = "#2a78d6")) +
        facet_wrap(~ ferrovia) +
        labs(x = "Efeito sobre ln(PIB real), IC 95%", y = NULL, colour = NULL, shape = NULL) + tema,
      "14_psm_vs_todos.png", w = 10, h = 4)

# Controle sintético com doadores restritos aos pareados
iwalk(set_names(FERROV), function(k, ...) {
  s <- tryCatch(scm_ferrovia(k, psm = TRUE), error = function(e) NULL); if (is.null(s)) return()
  tag <- str_replace_all(k, "[^A-Za-z]", "")
  salva(plot_trends(s) + labs(title = paste(k, "— doadores pareados")),
        paste0("14_scm_psm_trajetoria_", tag, ".png"))
  write_csv(grab_significance(s), file.path(OUT, paste0("14_scm_psm_inferencia_", tag, ".csv")))
})

message("Concluído. Resultados em ", normalizePath(OUT))
