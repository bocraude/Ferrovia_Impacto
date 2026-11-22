# =============================================================================
# MÓDULO RAIS LONGA — emprego formal 1995–2023 em Áreas Mínimas Comparáveis
#
#  1. Baixa a RAIS vínculos (FTP PDET/MTE) de 1995 a 2023 para BA, GO, MG, SP
#     e agrega por município e Subsetor IBGE (classificação estável na série toda)
#  2. Agrega municípios em Áreas Mínimas Comparáveis 1991–2010 (geobr), para
#     neutralizar as emancipações dos anos 1990
#  3. Controle sintético LONGO do emprego formal privado e do emprego na
#     construção civil (pré-obra 1995–2009 = 15 anos)
#  4. Controle sintético do PIB (2002–) usando a trajetória do emprego
#     1995–2009 como preditor adicional
#  5. Callaway & Sant'Anna com emprego em AMC (mais anos de pré-tendência)
#
# Datas: única por ferrovia (DATA_TRAT), como no programa principal.
# Entradas: municipios_grupos.csv, painel_municipal.csv,
#           ipca.csv (ano, ipca_indice; qualquer base) para deflacionar salários
# Saídas:   resultados_rais_longa/
# =============================================================================

pacotes <- c("dplyr", "tidyr", "purrr", "readr", "stringr", "ggplot2",
             "data.table", "curl", "geobr", "sf", "tidysynth", "did")
falta <- setdiff(pacotes, rownames(installed.packages()))
if (length(falta)) install.packages(falta)
invisible(lapply(pacotes, library, character.only = TRUE))
if (!requireNamespace("archive", quietly = TRUE)) try(install.packages("archive"))
first <- dplyr::first; last <- dplyr::last; between <- dplyr::between   # evita conflito com data.table

# ---- descompactação .7z: usa o pacote archive; se não houver, usa o 7-Zip ----
tem_archive <- requireNamespace("archive", quietly = TRUE)
SETEZIP <- Sys.which("7z")
if (!nzchar(SETEZIP) && file.exists("C:/Program Files/7-Zip/7z.exe")) SETEZIP <- "C:/Program Files/7-Zip/7z.exe"
if (!tem_archive && !nzchar(SETEZIP))
  stop("Para abrir os arquivos .7z da RAIS instale o pacote 'archive' ",
       "(install.packages('archive')) ou o 7-Zip (https://www.7-zip.org).")
extrai_7z <- function(arquivo, destino) {
  dir.create(destino, recursive = TRUE, showWarnings = FALSE)
  if (tem_archive) archive::archive_extract(arquivo, destino)
  else system2(SETEZIP, c("x", shQuote(arquivo), paste0("-o", shQuote(destino)), "-y"), stdout = FALSE)
}

OUT  <- "resultados_rais_longa"; dir.create(OUT, showWarnings = FALSE)
DIR  <- "dados_brutos/rais_longa"; dir.create(DIR, recursive = TRUE, showWarnings = FALSE)
UFS  <- c(BA = 29, GO = 52, MG = 31, SP = 35)
ANOS <- 1995:2023
PRE_FIM <- 2009
FERROV  <- c("FIOL I", "FIOL II", "FNS-ES")
POOL    <- c("FIOL I" = "BA", "FIOL II" = "BA", "FNS-ES" = "FNS")
DATA_TRAT <- c("FIOL I" = 2011, "FIOL II" = 2013, "FNS-ES" = 2011)   # igual ao programa principal
tema  <- theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "top")
salva <- function(g, nome, w = 7, h = 4.5) ggsave(file.path(OUT, nome), g, width = w, height = h)

# Subsetor IBGE (25 categorias) — CONFERIR com o dicionário de variáveis da RAIS
# no FTP (arquivo de layout do ano) antes de usar. Códigos esperados:
SUB_CONSTRUCAO <- 15   # Construção civil
SUB_ADM_PUB    <- 24   # Administração pública direta e autárquica
SUB_AGRO       <- 25   # Agricultura, silvicultura, criação de animais, extrativismo vegetal

# ---- 1. RAIS por município × subsetor ----------------------------------------
FTP <- "ftp://ftp.mtps.gov.br/pdet/microdados/RAIS/"
lista_ftp <- function(url) {
  h <- new_handle(dirlistonly = TRUE)
  strsplit(rawToChar(curl_fetch_memory(url, handle = h)$content), "\r?\n")[[1]]
}
padrao <- "^(BA|GO|MG|SP)\\d{4}\\.(7z|zip)$|RAIS_VINC_PUB_(NORDESTE|CENTRO_OESTE|MG_ES_RJ|SP)\\.(7z|zip)$"
acha_col <- function(nms, padroes) {
  base <- iconv(nms, from = "latin1", to = "ASCII//TRANSLIT")
  for (p in padroes) { i <- grep(p, base, ignore.case = TRUE); if (length(i)) return(nms[i[1]]) }
  NA_character_
}

rais_subsetor_ano <- function(ano) {
  saida <- file.path(DIR, paste0("rais_subsetor_", ano, ".csv"))
  if (file.exists(saida)) return(fread(saida, colClasses = c(mun6 = "character")))
  arqs <- lista_ftp(paste0(FTP, ano, "/")); sel <- arqs[grepl(padrao, arqs)]
  message(ano, ": ", paste(sel, collapse = ", "))
  if (!length(sel)) { warning("Nenhum arquivo selecionado em ", ano, ": ", paste(arqs, collapse = ", ")); return(NULL) }
  res <- rbindlist(lapply(sel, function(a) {
    dest <- file.path(DIR, ano, a); dir.create(dirname(dest), TRUE, FALSE)
    if (!file.exists(dest)) curl_download(paste0(FTP, ano, "/", a), dest, quiet = TRUE)
    exdir <- sub("\\.(7z|zip)$", "", dest)
    if (!dir.exists(exdir)) extrai_7z(dest, exdir)
    rbindlist(lapply(list.files(exdir, pattern = "\\.(txt|TXT)$", full.names = TRUE, recursive = TRUE), function(f) {
      cab <- names(fread(f, sep = ";", nrows = 0, encoding = "Latin-1"))
      mapa <- c(mun     = acha_col(cab, c("^Munic.pio$", "^Mun Trab", "Munic")),
                sub     = acha_col(cab, c("IBGE Subsetor", "Subsetor IBGE", "Subs.*Ibge")),
                ativo   = acha_col(cab, c("V.nculo Ativo 31/12", "Ativo")),
                rem_dez = acha_col(cab, c("Vl Remun Dezembro Nom", "Remun Dezembro")))
      if (anyNA(mapa)) stop("Colunas não encontradas em ", f, ": ", paste(cab, collapse = " | "))
      d <- fread(f, sep = ";", select = unname(mapa), encoding = "Latin-1",
                 colClasses = "character", showProgress = FALSE)
      setnames(d, unname(mapa), names(mapa))
      d <- d[substr(mun, 1, 2) %in% as.character(UFS)]
      d[, `:=`(ativo = as.integer(ativo) == 1, sub = as.integer(sub),
               rem_dez = as.numeric(gsub(",", ".", rem_dez)))]
      d[ativo == TRUE, .(emp = .N, massa_dez = sum(rem_dez, na.rm = TRUE)),
        by = .(mun6 = substr(mun, 1, 6), sub)]
    }))
  }))
  res <- res[, .(emp = sum(emp), massa_dez = sum(massa_dez)), by = .(mun6, sub)][, ano := ano]
  fwrite(res, saida); res
}
rais_sub <- rbindlist(lapply(ANOS, rais_subsetor_ano))

# Checagem: participação de cada subsetor no emprego dos 4 estados (conferir rótulos)
chk <- rais_sub[ano %in% c(1995, 2005, 2015), .(emp = sum(emp)), by = .(ano, sub)][
  , share := emp / sum(emp), by = ano][order(ano, sub)]
fwrite(chk, file.path(OUT, "00_checagem_subsetores.csv"))

# ---- 2. Áreas Mínimas Comparáveis 1991–2010 ----------------------------------
amc <- read_comparable_areas(start_year = 1991, end_year = 2010, simplified = TRUE, showProgress = FALSE)
col_lista <- grep("^list_code_muni", names(amc), value = TRUE)[1]
col_amc   <- grep("amc", names(amc), value = TRUE, ignore.case = TRUE)[1]
if (is.na(col_lista) || is.na(col_amc))
  stop("Conferir nomes das colunas da AMC no geobr: ", paste(names(amc), collapse = ", "))
amc_map <- amc |> st_drop_geometry() |>
  transmute(code_amc = .data[[col_amc]], lista = .data[[col_lista]]) |>
  separate_longer_delim(lista, delim = ",") |>
  transmute(code_amc, cod_ibge = str_trim(lista), mun6 = substr(cod_ibge, 1, 6)) |>
  filter(substr(cod_ibge, 1, 2) %in% as.character(UFS))

# Classificação das AMCs a partir dos municípios
grupos <- read_csv("municipios_grupos.csv", col_types = cols(cod_ibge = "c"))

amc_grupo <- amc_map |>
  left_join(grupos |> select(cod_ibge, ferrovia, pool, anel, outro_projeto_ferroviario), by = "cod_ibge") |>
  group_by(code_amc) |>
  summarise(n_mun = n(),
            ferrovia = { f <- unique(na.omit(ferrovia[ferrovia %in% FERROV]))
                         if (length(f) == 0) "controle" else if (length(f) == 1) f else "mista" },
            pool = first(na.omit(pool)),
            anel_min = suppressWarnings(min(anel, na.rm = TRUE)),
            outro_proj = any(outro_projeto_ferroviario %in% c(1, "1", TRUE, "sim", "Sim")),
            .groups = "drop") |>
  mutate(g = as.integer(unname(ifelse(ferrovia %in% FERROV, DATA_TRAT[ferrovia], 0))),
         tratada = ferrovia %in% FERROV,
         elegivel_ctrl = ferrovia == "controle" & anel_min >= 3 & !outro_proj)
# AMC "mista" (cortada por duas ferrovias) fica fora; AMC tratada = contém ≥1 município tratado.
write_csv(amc_grupo, file.path(OUT, "01_amc_classificacao.csv"))

# Painel AMC × ano
ipca <- read_csv("ipca.csv")    # ano, ipca_indice
painel_amc <- rais_sub |> as_tibble() |>
  inner_join(amc_map |> distinct(mun6, code_amc), by = "mun6") |>
  group_by(code_amc, ano) |>
  summarise(emp_total   = sum(emp),
            emp_privado = sum(emp[sub != SUB_ADM_PUB]),
            emp_constr  = sum(emp[sub == SUB_CONSTRUCAO]),
            emp_agro    = sum(emp[sub == SUB_AGRO]),
            massa_priv  = sum(massa_dez[sub != SUB_ADM_PUB]), .groups = "drop") |>
  left_join(ipca, by = "ano") |>
  mutate(massa_priv_real = massa_priv / ipca_indice * 100,
         ln_emp_priv   = log(emp_privado + 1),
         ln_emp_constr = log(emp_constr + 1),
         ln_massa_priv = log(massa_priv_real + 1)) |>
  inner_join(amc_grupo |> filter(tratada | elegivel_ctrl), by = "code_amc")

# PIB por AMC (2002–) a partir do painel municipal
pib_amc <- read_csv("painel_municipal.csv", col_types = cols(cod_ibge = "c")) |>
  select(cod_ibge, ano, pib) |>
  inner_join(amc_map |> select(cod_ibge, code_amc), by = "cod_ibge") |>
  group_by(code_amc, ano) |> summarise(pib = sum(pib), .groups = "drop")
deflator <- read_csv("deflator_pib.csv")
painel_amc <- painel_amc |>
  left_join(pib_amc, by = c("code_amc", "ano")) |>
  left_join(deflator, by = "ano") |>
  mutate(ln_pib = log(pib * 100 / deflator))

amostra <- function(k) painel_amc |>
  filter(ferrovia == k | (ferrovia == "controle" & pool == POOL[[k]]))

# Descritiva: trajetórias longas, tratadas x controles (índice 2009 = 0)
traj <- map_dfr(FERROV, ~ amostra(.x) |> mutate(painel_f = .x)) |>
  group_by(code_amc) |> mutate(y = ln_emp_priv - first(ln_emp_priv[ano == PRE_FIM])) |> ungroup() |>
  mutate(grupo = ifelse(tratada, "AMCs tratadas", "AMCs de controle")) |>
  group_by(painel_f, grupo, ano) |>
  summarise(m = mean(y, na.rm = TRUE), se = sd(y, na.rm = TRUE) / sqrt(n()), .groups = "drop")
salva(ggplot(traj, aes(ano, m, colour = grupo, fill = grupo)) +
        geom_ribbon(aes(ymin = m - 1.96 * se, ymax = m + 1.96 * se), alpha = .15, colour = NA) +
        geom_line() +
        geom_vline(data = tibble(painel_f = FERROV, x = DATA_TRAT[FERROV] - .5), aes(xintercept = x),
                   linetype = "dashed") +
        facet_wrap(~ painel_f) +
        labs(x = NULL, y = "ln(emprego formal privado), 2009 = 0", colour = NULL, fill = NULL) + tema,
      "02_trajetorias_emprego_1995_2023.png", w = 9, h = 3.8)

# ---- 3. Controle sintético longo (emprego) -----------------------------------
# Tratada = soma das AMCs tratadas da ferrovia; séries centradas na média pré.
monta_scm <- function(k, var_nivel, inicio = 1995) {
  d <- amostra(k) |> filter(ano >= inicio); ult_pre <- DATA_TRAT[[k]] - 1
  trat <- d |> filter(tratada) |> group_by(ano) |>
    summarise(nivel = sum(.data[[var_nivel]]), emp_agro = sum(emp_agro),
              emp_total = sum(emp_total), emp_privado = sum(emp_privado), .groups = "drop") |>
    mutate(unidade = "TRATADA")
  ctrl <- d |> filter(!tratada) |>
    transmute(ano, nivel = .data[[var_nivel]], emp_agro, emp_total, emp_privado,
              unidade = as.character(code_amc))
  bind_rows(trat, ctrl) |>
    group_by(unidade) |>
    mutate(y = 100 * (log(nivel + 1) - mean(log(nivel + 1)[ano >= inicio & ano <= ult_pre])),
           sh_agro = emp_agro / emp_total, sh_priv = emp_privado / emp_total) |>
    ungroup() |> filter(is.finite(y)) |> arrange(unidade, ano)
}

scm_longo <- function(k, var_nivel, rotulo) {
  dd <- monta_scm(k, var_nivel); gk <- DATA_TRAT[[k]]
  s <- dd |>
    synthetic_control(outcome = y, unit = unidade, time = ano, i_unit = "TRATADA",
                      i_time = gk, generate_placebos = TRUE) |>
    generate_predictor(time_window = 1995:(gk - 1),
                       sh_agro = mean(sh_agro, na.rm = TRUE), sh_priv = mean(sh_priv, na.rm = TRUE)) |>
    generate_predictor(time_window = 1997, y1997 = y) |>
    generate_predictor(time_window = 2001, y2001 = y) |>
    generate_predictor(time_window = 2005, y2005 = y) |>
    generate_predictor(time_window = 2009, y2009 = y) |>
    generate_weights(optimization_window = 1995:(gk - 1),
                     margin_ipop = .02, sigf_ipop = 7, bound_ipop = 6) |>
    generate_control()
  tag <- paste0(str_replace_all(k, "[^A-Za-z]", ""), "_", var_nivel)
  salva(plot_trends(s) + labs(title = paste(k, "—", rotulo)), paste0("03_scm_", tag, ".png"))
  salva(plot_placebos(s) + labs(title = paste(k, "—", rotulo)), paste0("03_scm_placebos_", tag, ".png"))
  write_csv(grab_significance(s) |> filter(unit_name == "TRATADA") |>
              mutate(ferrovia = k, desfecho = rotulo), file.path(OUT, paste0("03_scm_inf_", tag, ".csv")))
  write_csv(grab_unit_weights(s), file.path(OUT, paste0("03_scm_pesos_", tag, ".csv")))
  s
}
scm_emp <- map(set_names(FERROV), function(k) list(
  privado = scm_longo(k, "emp_privado", "Emprego formal privado"),
  constr  = scm_longo(k, "emp_constr",  "Emprego na construção civil")))

# ---- 4. Controle sintético do PIB com trajetória de emprego como preditor ----
# O PIB só existe a partir de 2002; a trajetória do emprego 1995–2009 entra como
# característica fixa de cada unidade (crescimento e nível relativo).
scm_pib_com_rais <- function(k) {
  gk <- DATA_TRAT[[k]]
  base <- monta_scm(k, "emp_privado") |>
    group_by(unidade) |>
    summarise(cresc_emp_9502 = (first(y[ano == 2002]) - first(y[ano == 1995])) / 7,
              cresc_emp_0209 = (first(y[ano == 2009]) - first(y[ano == 2002])) / 7,
              vol_emp_9509   = sd(diff(y[ano <= PRE_FIM])), .groups = "drop")
  d <- amostra(k) |> filter(ano >= 2002)
  trat <- d |> filter(tratada) |> group_by(ano) |>
    summarise(pib = sum(exp(ln_pib), na.rm = TRUE), .groups = "drop") |> mutate(unidade = "TRATADA")
  ctrl <- d |> filter(!tratada) |> transmute(ano, pib = exp(ln_pib), unidade = as.character(code_amc))
  dd <- bind_rows(trat, ctrl) |> group_by(unidade) |>
    mutate(y = 100 * (log(pib) - mean(log(pib)[ano < gk]))) |> ungroup() |>
    filter(is.finite(y)) |> inner_join(base, by = "unidade")
  s <- dd |>
    synthetic_control(outcome = y, unit = unidade, time = ano, i_unit = "TRATADA",
                      i_time = gk, generate_placebos = TRUE) |>
    generate_predictor(time_window = 2002:(gk - 1),
                       cresc_emp_9502 = mean(cresc_emp_9502), cresc_emp_0209 = mean(cresc_emp_0209),
                       vol_emp_9509 = mean(vol_emp_9509)) |>
    generate_predictor(time_window = 2003, y2003 = y) |>
    generate_predictor(time_window = 2006, y2006 = y) |>
    generate_predictor(time_window = 2009, y2009 = y) |>
    generate_weights(optimization_window = 2002:(gk - 1),
                     margin_ipop = .02, sigf_ipop = 7, bound_ipop = 6) |>
    generate_control()
  tag <- str_replace_all(k, "[^A-Za-z]", "")
  salva(plot_trends(s) + labs(title = paste(k, "— PIB (pesos com trajetória de emprego 1995–2009)")),
        paste0("04_scm_pib_rais_", tag, ".png"))
  write_csv(grab_significance(s) |> filter(unit_name == "TRATADA") |> mutate(ferrovia = k),
            file.path(OUT, paste0("04_scm_pib_rais_inf_", tag, ".csv")))
  write_csv(grab_balance_table(s), file.path(OUT, paste0("04_scm_pib_rais_balanco_", tag, ".csv")))
  s
}
scm_pib <- map(set_names(FERROV), scm_pib_com_rais)

# Comparar com o SCM do PIB sem a RAIS (programa principal): se o ajuste pré e
# o efeito forem parecidos, o resultado não depende da curta janela 2002–2009.

# ---- 5. Callaway & Sant'Anna com emprego em AMC (14 anos de pré-tendência) ----
cs_amc <- map_dfr(FERROV, function(k) {
  d <- amostra(k) |> mutate(id = as.numeric(factor(code_amc)), gg = ifelse(tratada, g, 0L))
  map_dfr(c("ln_emp_priv", "ln_emp_constr", "ln_massa_priv"), function(y) {
    m <- tryCatch(att_gt(yname = y, tname = "ano", idname = "id", gname = "gg", data = d,
                         control_group = "nevertreated", base_period = "universal",
                         allow_unbalanced_panel = TRUE, print_details = FALSE),
                  error = function(e) { message(k, " ", y, ": ", conditionMessage(e)); NULL })
    if (is.null(m)) return(NULL)
    din <- aggte(m, type = "dynamic", min_e = -14, max_e = 10, na.rm = TRUE)
    sim <- aggte(m, type = "simple", na.rm = TRUE)
    salva(ggdid(din) + labs(title = paste(k, "—", y)),
          paste0("05_cs_amc_", str_replace_all(k, "[^A-Za-z]", ""), "_", y, ".png"))
    tibble(ferrovia = k, desfecho = y, efeito = sim$overall.att, se = sim$overall.se,
           ic_inf = efeito - 1.96 * se, ic_sup = efeito + 1.96 * se)
  })
})
write_csv(cs_amc, file.path(OUT, "05_cs_amc_resumo.csv"))

message("Concluído. Resultados em ", normalizePath(OUT))
