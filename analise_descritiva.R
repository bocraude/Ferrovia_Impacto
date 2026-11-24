# =============================================================================
# Análise exploratória e descritiva — PIB, PIB per capita e ISS por trecho
#
# Usa a mesma amostra dos modelos (preparação de analise_impacto_ferrovias.R, período
# 2002–2023): tratados de cada trecho e controles elegíveis do pool (anel >= 3).
# Valores reais em R$ de 2020 (deflator do PIB). Não estima nada: só descreve.
#
# Saídas em resultados_descritiva/:
#   d1_series_por_grupo.csv     série anual por grupo (trecho tratado ou controles do pool)
#   d2_descritiva_grupos.csv    tabela descritiva em 2002, 2010 e 2019
#   d3_municipios_tratados.csv  os municípios de cada trecho, com km de linha, PIB e ISS
#   d4_km_por_trecho.csv        km de linha por trecho (traçado do OpenStreetMap)
#   d5_linha_do_tempo.csv       fases da obra por ferrovia (janelas do script de análise)
#   d6_resultados.csv           principais estimativas (2002–2019), PIB e ISS
#   d7_cs_resumo.csv            Callaway & Sant'Anna: efeito, p, pré-tendência, MDE
#   d8_sdid_anual.csv           Synthetic DiD ano a ano
#   d9_janelas.csv              efeitos por fase (Synthetic DiD e TWFE)
#   mapa.json                   contornos para o mapa do painel
#   g*.png                      gráficos
# =============================================================================
suppressMessages({library(dplyr); library(tidyr); library(purrr); library(readr); library(stringr)
  library(ggplot2); library(fixest); library(did); library(tidysynth); library(synthdid)
  library(HonestDiD); library(MatchIt); library(sf)})
sf_use_s2(FALSE)
OUTD <- "resultados_descritiva"; dir.create(OUTD, showWarnings = FALSE)
BASE <- 2010                                   # ano-base dos índices (último antes das obras de 2011)

# ---- amostra e variáveis: mesma preparação dos modelos -----------------------------
fonte <- readLines("analise_impacto_ferrovias.R", encoding = "UTF-8")
prep  <- fonte[grep("^set.seed\\(", fonte)[1]:(grep("^# ---- 3\\. Controle sint", fonte)[1] - 1)]
amb <- new.env(); list2env(list(ANO_MAX = 2023, CONTROLE_AGRO = TRUE, OUT = tempfile("prep_")), envir = amb)
suppressWarnings(suppressMessages(eval(parse(text = prep), envir = amb)))
FERROV <- amb$FERROV
p <- amb$painel |>
  mutate(grupo = case_when(tratado ~ ferrovia, pool == "BA" ~ "Controles BA", TRUE ~ "Controles GO-MG-SP"),
         pibpc = 1000 * pib_real / pop_interp,          # R$ de 2020 por habitante
         isspc = iss_real / pop_interp)
ORDEM <- c("FIOL I", "FIOL II", "Controles BA", "FNS-ES", "Controles GO-MG-SP")

# ---- d1: séries por grupo -------------------------------------------------------------
series <- p |> group_by(grupo, pool, ano) |>
  summarise(municipios = n_distinct(cod_ibge),
            pib_real_bi = sum(pib_real, na.rm = TRUE) / 1e6,
            pibpc_mediana = median(pibpc, na.rm = TRUE),
            isspc_mediana = median(isspc, na.rm = TRUE),
            iss_mediano_mil = median(iss_real, na.rm = TRUE) / 1e3,
            municipios_com_iss = sum(!is.na(iss_real)), .groups = "drop") |>
  group_by(grupo) |>
  mutate(pib_idx = 100 * pib_real_bi / pib_real_bi[ano == BASE],
         pibpc_idx = 100 * pibpc_mediana / pibpc_mediana[ano == BASE],
         isspc_idx = 100 * isspc_mediana / isspc_mediana[ano == BASE]) |> ungroup() |>
  mutate(grupo = factor(grupo, ORDEM)) |> arrange(grupo, ano)
write_csv(series, file.path(OUTD, "d1_series_por_grupo.csv"))

# ---- d2: descritiva em anos de referência ------------------------------------------------
descr <- p |> filter(ano %in% c(2002, 2010, 2019)) |> group_by(grupo, ano) |>
  summarise(municipios = n_distinct(cod_ibge),
            pop_mil = sum(pop_interp, na.rm = TRUE) / 1e3,
            pib_real_bi = sum(pib_real, na.rm = TRUE) / 1e6,
            pibpc_media = mean(pibpc, na.rm = TRUE), pibpc_mediana = median(pibpc, na.rm = TRUE),
            pibpc_min = min(pibpc, na.rm = TRUE), pibpc_max = max(pibpc, na.rm = TRUE),
            part_agro = 100 * sum(vab_agro, na.rm = TRUE) / sum(vab, na.rm = TRUE),
            part_ind  = 100 * sum(vab_ind,  na.rm = TRUE) / sum(vab, na.rm = TRUE),
            part_serv = 100 * sum(vab_serv, na.rm = TRUE) / sum(vab, na.rm = TRUE),
            part_apu  = 100 * sum(vab_apu,  na.rm = TRUE) / sum(vab, na.rm = TRUE),
            isspc_mediana = median(isspc, na.rm = TRUE),
            municipios_com_iss = sum(!is.na(iss_real)), .groups = "drop") |>
  mutate(grupo = factor(grupo, ORDEM), chave = paste(grupo, ano)) |> arrange(grupo, ano)
write_csv(descr, file.path(OUTD, "d2_descritiva_grupos.csv"))

# ---- d3 e d4: municípios de cada trecho e km de linha ----------------------------------------
km <- read_csv("km_por_municipio.csv", col_types = cols(cod_ibge = "c")) |>
  group_by(cod_ibge) |> summarise(km_linha = sum(km_no_municipio), .groups = "drop")
pares <- imap_dfr(amb$PSM_TRAT, ~ tibble(cod_ibge = .x, com_par = "sim"))
larg <- function(v, anos) p |> filter(tratado, ano %in% anos) |> select(cod_ibge, ano, all_of(v)) |>
  pivot_wider(names_from = ano, values_from = all_of(v), names_prefix = paste0(v, "_"))
mun <- p |> filter(tratado) |> distinct(cod_ibge, nome, uf, trecho = ferrovia, inicio_obra = g, soja_ha_pc) |>
  left_join(km, by = "cod_ibge") |> left_join(pares, by = "cod_ibge") |>
  left_join(p |> filter(tratado, ano == 2019) |> transmute(cod_ibge, pop_2019 = round(pop_interp)), by = "cod_ibge") |>
  left_join(larg("pib_real", c(2010, 2019)), by = "cod_ibge") |>
  left_join(larg("pibpc", c(2010, 2019)), by = "cod_ibge") |>
  left_join(larg("isspc", c(2010, 2019)), by = "cod_ibge") |>
  left_join(p |> filter(tratado) |> group_by(cod_ibge) |> summarise(anos_com_iss = sum(!is.na(iss_real))), by = "cod_ibge") |>
  transmute(cod_ibge, municipio = str_to_title(nome) |> str_replace_all(" (De|Do|Da|Dos|Das) ", function(x) tolower(x)) |>
              str_replace_all("D'o", "d'O"),
            uf, trecho, inicio_obra, km_linha = round(km_linha, 1),
            pop_2019, pib_2010_mi = pib_real_2010 / 1e3, pib_2019_mi = pib_real_2019 / 1e3,
            var_pib_pct = 100 * (pib_real_2019 / pib_real_2010 - 1),
            pibpc_2010 = pibpc_2010, pibpc_2019 = pibpc_2019,
            isspc_2010 = isspc_2010, isspc_2019 = isspc_2019,
            var_isspc_pct = 100 * (isspc_2019 / isspc_2010 - 1),
            anos_com_iss, soja_pre_obra = ifelse(soja_ha_pc > 0, "sim", "não"),
            com_par_psm = coalesce(com_par, "não")) |>
  mutate(trecho = factor(trecho, FERROV)) |> arrange(trecho, desc(km_linha))
write_csv(mun, file.path(OUTD, "d3_municipios_tratados.csv"))
km_trecho <- mun |> group_by(trecho) |>
  summarise(municipios = n(), com_linha_no_osm = sum(!is.na(km_linha)), km_total = sum(km_linha, na.rm = TRUE),
            km_medio = mean(km_linha, na.rm = TRUE), km_min = min(km_linha, na.rm = TRUE),
            km_max = max(km_linha, na.rm = TRUE), .groups = "drop")
write_csv(km_trecho, file.path(OUTD, "d4_km_por_trecho.csv"))

# ---- d5: linha do tempo (fases = janelas do script de análise; datas de tratamento) ----------
linha <- imap_dfr(amb$JANELAS, function(jj, k) {
  ini <- unname(jj); fim <- c(ini[-1] - 1, 2023)
  bind_rows(tibble(ferrovia = k, fase = "Antes da obra", inicio = 2002, fim = ini[1] - 1, tipo = "pré"),
            tibble(ferrovia = k, fase = str_trim(str_remove(names(jj), "^\\d{4}-\\d{4}")), inicio = ini, fim = fim, tipo = "obra"))
}) |> mutate(inicio_tratamento = amb$DATA_TRAT[ferrovia], chave = paste(ferrovia, inicio))
write_csv(linha, file.path(OUTD, "d5_linha_do_tempo.csv"))

# ---- d6 a d9: principais resultados (2002–2019) ---------------------------------------------------
NOME <- c(ln_pib = "PIB real", ln_pibpc = "PIB real per capita", ln_iss = "ISS real", ln_isspc = "ISS real per capita")
pastas <- c("resultados_ate_2019", "resultados_iss_ate_2019")
res <- map_dfr(pastas, ~ read_csv(file.path(.x, "14_psm_vs_todos.csv"), show_col_types = FALSE)) |>
  transmute(desfecho = NOME[desfecho], ferrovia, estimador,
            controles = ifelse(str_detect(controles, "Pareados"), "Pareados", "Todos os elegíveis"),
            efeito, erro_padrao = se, ic_inf, ic_sup, p_valor, efeito_pct = 100 * (exp(efeito) - 1),
            chave = paste(desfecho, ferrovia, estimador, controles, sep = " | "))
write_csv(res, file.path(OUTD, "d6_resultados.csv"))
cs <- map_dfr(c("resultados_ate_2019/07_cs_tabela_ln_pib.csv", "resultados_ate_2019/07_cs_tabela_ln_pibpc.csv",
                "resultados_iss_ate_2019/07_cs_tabela_ln_iss.csv", "resultados_iss_ate_2019/07_cs_tabela_ln_isspc.csv"),
              read_csv, show_col_types = FALSE) |> filter(!str_detect(painel, "Teste de igualdade")) |>
  transmute(desfecho = NOME[desfecho], painel, efeito, efeito_pct, ic_inf, ic_sup, p_valor, p_pretendencia, mde_80,
            chave = paste(desfecho, painel, sep = " | "))
write_csv(cs, file.path(OUTD, "d7_cs_resumo.csv"))
sdid <- map_dfr(pastas, ~ read_csv(file.path(.x, "06b_sdid_efeito_anual.csv"), show_col_types = FALSE)) |>
  transmute(desfecho = NOME[desfecho], ferrovia,
            controles = ifelse(str_detect(controles, "Pareados"), "Pareados", "Todos os elegíveis"),
            ano, ano_inicio, n_trat, n_ctrl, efeito, ic_inf, ic_sup)
write_csv(sdid, file.path(OUTD, "d8_sdid_anual.csv"))
jan <- bind_rows(
  map_dfr(pastas, ~ read_csv(file.path(.x, "06b_sdid_efeitos_por_janela.csv"), show_col_types = FALSE)) |>
    filter(str_detect(controles, "Todos"), janela != "Total pós-obra") |>
    transmute(desfecho = NOME[desfecho], ferrovia, estimador = "Synthetic DiD", janela, efeito, ic_inf, ic_sup, p_valor),
  map_dfr(pastas, ~ read_csv(file.path(.x, "09c_efeitos_por_janela.csv"), show_col_types = FALSE)) |>
    transmute(desfecho = NOME[desfecho], ferrovia, estimador = "TWFE", janela, efeito, ic_inf, ic_sup,
              p_valor = 2 * pnorm(-abs(efeito / se)))) |>
  mutate(chave = paste(desfecho, ferrovia, estimador, janela, sep = " | "))
write_csv(jan, file.path(OUTD, "d9_janelas.csv"))

# ---- mapa: UFs, municípios de cada trecho e linhas (contornos simplificados, em SVG) -------------
malha <- do.call(rbind, lapply(list.files("dados_brutos/malha_2020", "^(29|31|35|52).*\\.gpkg$", full.names = TRUE),
                               st_read, quiet = TRUE)) |> st_make_valid() |> st_transform(5880)
ufs <- malha |> group_by(nome = abbrev_state) |> summarise(.groups = "drop") |> st_simplify(dTolerance = 4000)
trat <- malha |> mutate(cod_ibge = as.character(code_muni)) |> inner_join(mun |> select(cod_ibge, municipio, trecho), by = "cod_ibge") |>
  st_simplify(dTolerance = 1200) |> select(nome = municipio, trecho)
lin <- st_read("tracado_ferrovias.gpkg", quiet = TRUE) |> st_transform(5880) |> group_by(nome = ferrovia) |>
  summarise(.groups = "drop") |> st_simplify(dTolerance = 800)
bb <- st_bbox(ufs); L <- 1000; esc <- L / max(bb$xmax - bb$xmin, bb$ymax - bb$ymin)
caminho <- function(g) {
  cs <- st_coordinates(st_cast(st_sfc(g), "MULTILINESTRING"))
  id <- do.call(paste, as.data.frame(cs[, setdiff(colnames(cs), c("X", "Y")), drop = FALSE]))
  paste(vapply(split(seq_len(nrow(cs)), factor(id, unique(id))), function(i)
    paste0("M", paste(sprintf("%.1f,%.1f", (cs[i, "X"] - bb$xmin) * esc, (bb$ymax - cs[i, "Y"]) * esc), collapse = "L")),
    character(1)), collapse = "")
}
fechado <- function(x, tipo, trecho = NA) tibble(tipo = tipo, nome = x$nome, trecho = as.character(trecho),
                                                 d = paste0(map_chr(st_geometry(x), caminho), "Z"))
mapa <- bind_rows(fechado(ufs, "uf"), fechado(trat, "municipio", trat$trecho),
                  tibble(tipo = "linha", nome = lin$nome, trecho = lin$nome, d = map_chr(st_geometry(lin), caminho)))
cent <- st_coordinates(st_centroid(st_geometry(ufs)))
mapa <- bind_rows(mapa, tibble(tipo = "rotulo", nome = ufs$nome, trecho = NA_character_,
                               d = sprintf("%.1f,%.1f", (cent[, 1] - bb$xmin) * esc, (bb$ymax - cent[, 2]) * esc)))
attr(mapa, "dim") <- NULL
jsonlite::write_json(mapa |> mutate(largura = round((bb$xmax - bb$xmin) * esc), altura = round((bb$ymax - bb$ymin) * esc)),
                     file.path(OUTD, "mapa.json"), na = "null")

# ---- gráficos ------------------------------------------------------------------------------------
tema <- theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "top")
CORES <- c("FIOL I" = "#2a78d6", "FIOL II" = "#6250d6", "FNS-ES" = "#eb6834", "Controles BA" = "grey55", "Controles GO-MG-SP" = "grey55")
paineis <- bind_rows(series |> filter(grupo %in% c("FIOL I", "Controles BA")) |> mutate(painel = "FIOL I"),
                     series |> filter(grupo %in% c("FIOL II", "Controles BA")) |> mutate(painel = "FIOL II"),
                     series |> filter(grupo %in% c("FNS-ES", "Controles GO-MG-SP")) |> mutate(painel = "FNS-ES")) |>
  mutate(serie = ifelse(str_detect(grupo, "Controles"), "Controles elegíveis do pool", "Municípios do trecho"))
graf <- function(v, rot, arq) {
  g <- ggplot(paineis, aes(ano, .data[[v]], colour = serie)) +
    geom_vline(data = tibble(painel = FERROV, x = amb$DATA_TRAT[FERROV] - .5), aes(xintercept = x), linetype = "dashed", colour = "grey40") +
    geom_line(linewidth = .8) + facet_wrap(~ painel) +
    scale_colour_manual(values = c("Municípios do trecho" = "#2a78d6", "Controles elegíveis do pool" = "grey55")) +
    labs(x = NULL, y = rot, colour = NULL, caption = "Linha tracejada: início da obra. R$ de 2020 (deflator do PIB).") + tema
  ggsave(file.path(OUTD, arq), g, width = 10, height = 4)
}
graf("pib_idx", paste0("PIB real total (", BASE, " = 100)"), "g1_pib_real_indice.png")
graf("pibpc_mediana", "PIB real per capita mediano (R$ de 2020)", "g2_pib_per_capita_mediano.png")
graf("isspc_mediana", "ISS real per capita mediano (R$ de 2020)", "g3_iss_per_capita_mediano.png")
ggsave(file.path(OUTD, "g4_km_por_municipio.png"),
       mun |> filter(!is.na(km_linha)) |> ggplot(aes(km_linha, reorder(paste0(municipio, "/", uf), km_linha), fill = trecho)) +
         geom_col() + facet_wrap(~ trecho, scales = "free_y") + scale_fill_manual(values = CORES, guide = "none") +
         labs(x = "km de linha no município (traçado do OpenStreetMap)", y = NULL) + tema + theme(axis.text.y = element_text(size = 7)),
       width = 12, height = 6)
ggsave(file.path(OUTD, "g5_linha_do_tempo.png"),
       linha |> mutate(ferrovia = factor(ferrovia, rev(FERROV))) |>
         ggplot(aes(y = ferrovia)) +
         geom_segment(aes(x = inicio - .5, xend = fim + .5, yend = ferrovia, colour = tipo), linewidth = 9) +
         geom_text(aes(x = (inicio + fim) / 2, label = paste0(fase, "\n", inicio, "–", fim)), size = 2.8, lineheight = .9) +
         geom_vline(xintercept = seq(2002.5, 2022.5, 1), colour = "white", linewidth = .2) +
         scale_colour_manual(values = c("pré" = "grey85", "obra" = "#9ec3ee"), guide = "none") +
         scale_x_continuous(breaks = seq(2002, 2023, 3)) + labs(x = NULL, y = NULL) + tema,
       width = 11, height = 3)
message("Descritiva concluída em ", OUTD, ": ", paste(list.files(OUTD), collapse = ", "))
