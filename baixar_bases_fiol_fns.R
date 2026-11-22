# =============================================================================
# Baixa e organiza as bases municipais para a dissertação (FIOL / FNS-ES)
# UFs: BA (29), GO (52), MG (31), SP (35) — tratados e candidatos a controle
#
#  1. PIB dos Municípios (IBGE/SIDRA, tabela 5938)        2002–2023
#  2. População: Censos 2000/2010/2022 (SIDRA 202, 9514) + interpolação
#     geométrica (série sem saltos) e estimativas oficiais (SIDRA 6579) p/ comparar
#  3. Soja — área plantada e quantidade produzida (PAM, SIDRA 1612)
#  4. ISS — Siconfi/DCA Anexo I-C (API do Tesouro)          2013–2023
#     (2002–2012: FINBRA, download manual — ver bloco 4b)
#  5. RAIS vínculos (PDET/MTE, FTP): emprego e massa salarial total, seção F
#     (construção), divisão 42 e classe 4211-1 (rodovias e ferrovias)
#  6. Junta tudo em painel_municipal.csv
#
# Rodar em máquina com internet. A RAIS é pesada (vários GB por ano).
# Códigos de tabelas/variáveis conferidos na API do SIDRA e do Siconfi em nov/2026.
# =============================================================================

pacotes <- c("httr2", "jsonlite", "dplyr", "tidyr", "purrr", "readr",
             "stringr", "data.table", "curl")
novos <- setdiff(pacotes, rownames(installed.packages()))
if (length(novos)) install.packages(novos)
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

UFS   <- c(BA = 29, GO = 52, MG = 31, SP = 35)
ANOS  <- 2002:2023
DIR   <- "dados_brutos"; dir.create(DIR, showWarnings = FALSE)

# ---- utilitário SIDRA: consulta por UF (evita limite de linhas da API) -------
sidra_get <- function(url) {
  for (tentativa in 1:3) {
    r <- tryCatch(request(url) |> req_timeout(300) |> req_error(is_error = \(x) FALSE) |> req_perform(),
                  error = function(e) NULL)
    if (!is.null(r) && resp_status(r) == 200) return(resp_body_json(r, simplifyVector = TRUE))
    if (!is.null(r) && resp_status(r) == 400) return(NULL)   # limite de 100 mil valores: não adianta repetir
    Sys.sleep(5 * tentativa)
  }
  NULL
}
sidra <- function(tabela, variaveis, periodos = "all", classif = "", uf) {
  monta <- function(p) sprintf("https://apisidra.ibge.gov.br/values/t/%s/n6/in%%20n3%%20%s/v/%s/p/%s%s",
                               tabela, uf, variaveis, p, classif)
  limpa <- function(d) { names(d) <- unlist(d[1, ]); tibble::as_tibble(d[-1, ], .name_repair = "unique") }
  d <- sidra_get(monta(periodos))
  if (!is.null(d)) return(limpa(d))
  # A API limita cada consulta a 100 mil valores (MG × série inteira × 7 variáveis
  # estoura). Nesse caso a mesma consulta é refeita em blocos de anos, em sequência.
  v1 <- strsplit(variaveis, ",")[[1]][1]
  per <- sidra_get(sprintf("https://apisidra.ibge.gov.br/values/t/%s/n1/all/v/%s/p/%s%s",
                           tabela, v1, periodos, classif))
  if (is.null(per)) stop("Falha na consulta: ", monta(periodos))
  col_ano <- names(per)[which(unlist(per[1, ]) == "Ano (Código)")[1]]
  anos <- sort(unique(as.character(per[-1, col_ano])))
  blocos <- split(anos, ceiling(seq_along(anos) / 3))
  message("SIDRA ", tabela, " UF ", uf, ": consulta em ", length(blocos), " blocos de anos")
  purrr::map_dfr(blocos, function(b) {
    d <- sidra_get(monta(paste(b, collapse = ",")))
    if (is.null(d)) stop("Falha na consulta: ", monta(paste(b, collapse = ",")))
    limpa(d)
  })
}
num <- function(x) suppressWarnings(as.numeric(ifelse(x %in% c("-", "...", "X", ".."), NA, x)))

# =============================================================================
# 1. PIB dos Municípios — SIDRA 5938 (mil R$ correntes)
#    37 PIB | 498 VAB total | 513 VAB agro | 517 VAB indústria
#    6575 VAB serviços (exc. APU) | 525 VAB APU | 543 impostos líquidos
#    Obs.: em 2022–2023 o IBGE divulgou sem a abertura do VAB por setor.
#    Baixar sempre a série inteira de uma vez (mesma divulgação).
# =============================================================================
pib <- map_dfr(UFS, ~ sidra(5938, "37,498,513,517,6575,525,543", "all", uf = .x)) |>
  transmute(cod_ibge = `Município (Código)`, ano = as.integer(`Ano`),
            var = `Variável (Código)`, valor = num(Valor)) |>
  mutate(var = recode(var, `37` = "pib", `498` = "vab", `513` = "vab_agro",
                      `517` = "vab_ind", `6575` = "vab_serv", `525` = "vab_apu",
                      `543` = "impostos")) |>
  pivot_wider(names_from = var, values_from = valor)
write_csv(pib, file.path(DIR, "pib_municipios_5938.csv"))

# =============================================================================
# 2. População
#  2a. Censos: 2000 e 2010 (SIDRA 202, v93, situação=0 total, sexo=0 total)
#              2022 (SIDRA 9514, v93, sexo 6794, idade 100362, forma 113635)
#  2b. Série anual sem saltos: interpolação geométrica entre censos
#      (2023 extrapolado com a taxa 2010–2022). É a série recomendada p/ o
#      PIB per capita.
#  2c. Estimativas oficiais (SIDRA 6579, v9324) — só para documentar os saltos
#      (ex.: Salvador estimada em ~3,0 mi em 2009 e recenseada em ~2,68 mi em 2010).
# =============================================================================
censo_0010 <- map_dfr(UFS, ~ sidra(202, "93", "2000,2010", "/c1/0/c2/0", uf = .x)) |>
  transmute(cod_ibge = `Município (Código)`, ano = as.integer(Ano), pop = num(Valor))
censo_22 <- map_dfr(UFS, ~ sidra(9514, "93", "2022", "/c2/6794/c287/100362/c286/113635", uf = .x)) |>
  transmute(cod_ibge = `Município (Código)`, ano = as.integer(Ano), pop = num(Valor))
censos <- bind_rows(censo_0010, censo_22)

interp_geom <- function(d) {                       # d: cod_ibge, ano, pop (censos)
  d <- arrange(d, ano)
  map_dfr(ANOS, function(a) {
    if (a %in% d$ano) return(tibble(ano = a, pop_interp = d$pop[d$ano == a]))
    i <- findInterval(a, d$ano); i <- min(max(i, 1), nrow(d) - 1)   # extrapola nas pontas
    r <- (d$pop[i + 1] / d$pop[i])^(1 / (d$ano[i + 1] - d$ano[i]))
    tibble(ano = a, pop_interp = d$pop[i] * r^(a - d$ano[i]))
  })
}
pop_interp <- censos |> group_by(cod_ibge) |>
  filter(n() == 3) |>                               # municípios presentes nos 3 censos
  group_modify(~ interp_geom(.x)) |> ungroup()

pop_estim <- map_dfr(UFS, ~ sidra(6579, "9324", "all", uf = .x)) |>
  transmute(cod_ibge = `Município (Código)`, ano = as.integer(Ano), pop_estimada = num(Valor))

populacao <- pop_interp |> left_join(pop_estim, by = c("cod_ibge", "ano"))
write_csv(populacao, file.path(DIR, "populacao_interp_e_estimada.csv"))

# Alternativa de robustez: estimativas do Ministério da Saúde (2000–2021)
#   install.packages("brpop", repos = "https://rfsaldanha.r-universe.dev")
#   brpop::mun_pop_totals(source = "datasus")   # código de 6 dígitos

# =============================================================================
# 3. Soja — PAM, SIDRA 1612 (lavouras temporárias), produto 2713 = Soja (em grão)
#    109 = área plantada (ha) | 214 = quantidade produzida (t)
# =============================================================================
soja <- map_dfr(UFS, ~ sidra(1612, "109,214", "all", "/c81/2713", uf = .x)) |>
  transmute(cod_ibge = `Município (Código)`, ano = as.integer(Ano),
            var = `Variável (Código)`, valor = num(Valor)) |>
  mutate(var = recode(var, `109` = "soja_area_ha", `214` = "soja_ton")) |>
  pivot_wider(names_from = var, values_from = valor) |>
  mutate(across(c(soja_area_ha, soja_ton), ~ coalesce(.x, 0)))   # "-" = sem produção
write_csv(soja, file.path(DIR, "soja_pam_1612.csv"))

# =============================================================================
# 4. ISS — Siconfi, DCA Anexo I-C (receitas orçamentárias), 2013 em diante
#    Conta "Imposto sobre Serviços de Qualquer Natureza" (o código da conta mudou
#    em 2018, por isso o filtro é pelo nome). Coluna: receitas brutas realizadas.
#    São ~2.160 municípios × 11 anos: dá para restringir a `municipios_alvo`.
# =============================================================================
municipios_alvo <- unique(pib$cod_ibge)      # ou: tratados + candidatos a controle

iss_um <- function(cod, ano) {
  url <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca"
  r <- tryCatch(request(url) |>
                  req_url_query(an_exercicio = ano, no_anexo = "DCA-Anexo I-C", id_ente = cod) |>
                  req_timeout(60) |> req_retry(max_tries = 3) |> req_perform(),
                error = function(e) NULL)
  if (is.null(r)) return(NULL)
  it <- resp_body_json(r, simplifyVector = TRUE)$items
  if (!length(it) || !nrow(it)) return(NULL)
  it |> filter(str_detect(conta, regex("Servi.os de Qualquer Natureza", ignore_case = TRUE)),
               str_detect(coluna, regex("Brutas Realizadas|Receitas Realizadas", ignore_case = TRUE))) |>
    arrange(nchar(cod_conta)) |> slice(1) |>
    transmute(cod_ibge = as.character(cod_ibge), ano = as.integer(exercicio), iss = as.numeric(valor))
}
# O ISS não entra em nenhuma estimativa de analise_impacto_ferrovias.R e são ~24 mil
# consultas (horas). Se o arquivo já existir, é reaproveitado; com PULAR_ISS=1 no
# ambiente, a coluna fica NA e pode ser preenchida depois (baixar_iss.R).
arq_iss <- file.path(DIR, "iss_siconfi_2013_2023.csv")
if (file.exists(arq_iss)) {
  iss_siconfi <- read_csv(arq_iss, col_types = cols(cod_ibge = "c", ano = "i", iss = "d"))
  message("ISS: reaproveitando ", arq_iss, " (", nrow(iss_siconfi), " linhas)")
} else if (Sys.getenv("PULAR_ISS") == "1") {
  iss_siconfi <- tibble::tibble(cod_ibge = character(), ano = integer(), iss = numeric())
  message("ISS: PULAR_ISS=1, coluna iss ficará NA no painel")
} else {
  iss_siconfi <- expand_grid(cod = municipios_alvo, ano = 2013:2023) |>
    pmap_dfr(function(cod, ano) { Sys.sleep(0.2); iss_um(cod, ano) })
  write_csv(iss_siconfi, arq_iss)
}

# 4b. ISS 2002–2012 (FINBRA): baixar manualmente no Siconfi
#     (Consultas > Consultar Finbra > Declarações anteriores ao Siconfi, 1989–2012),
#     salvar em dados_brutos/finbra/ e ajustar a leitura abaixo — o layout muda
#     entre anos; procurar a coluna de ISS/ISSQN em "Receitas Orçamentárias".
# iss_finbra <- list.files(file.path(DIR, "finbra"), full.names = TRUE) |> ...

# =============================================================================
# 5. RAIS vínculos — FTP do PDET/MTE
#    Até ~2017 os arquivos são por UF (ex.: BA2010.7z); depois, por região
#    (RAIS_VINC_PUB_NORDESTE, _CENTRO_OESTE, _MG_ES_RJ, _SP). O script lista o
#    diretório de cada ano e mostra o que selecionou — conferir na 1ª execução.
#    Município na RAIS = do estabelecimento, código de 6 dígitos.
#    CNAE 2.0 só existe na RAIS a partir de 2006; antes, usar CNAE 95 (seção F
#    ≈ divisão 45) — quebra a ser tratada na análise.
# =============================================================================
FTP <- "ftp://ftp.mtps.gov.br/pdet/microdados/RAIS/"
lista_ftp <- function(url) {
  h <- new_handle(dirlistonly = TRUE)
  strsplit(rawToChar(curl_fetch_memory(url, handle = h)$content), "\r?\n")[[1]]
}
padrao_arquivos <- "^(BA|GO|MG|SP)\\d{4}\\.7z$|RAIS_VINC_PUB_(NORDESTE|CENTRO_OESTE|MG_ES_RJ|SP)\\.7z$"

acha_col <- function(nms, padroes) {
  base <- iconv(nms, to = "ASCII//TRANSLIT")
  for (p in padroes) { i <- grep(p, base, ignore.case = TRUE); if (length(i)) return(nms[i[1]]) }
  NA_character_
}

rais_ano <- function(ano) {
  arqs <- lista_ftp(paste0(FTP, ano, "/"))
  sel  <- arqs[grepl(padrao_arquivos, arqs)]
  message(ano, ": ", paste(sel, collapse = ", "))
  map_dfr(sel, function(a) {
    dest <- file.path(DIR, "rais", ano, a); dir.create(dirname(dest), TRUE, FALSE)
    if (!file.exists(dest)) curl_download(paste0(FTP, ano, "/", a), dest, quiet = TRUE)
    exdir <- file.path(dirname(dest), sub("\\.7z$", "", a))
    if (!dir.exists(exdir)) extrai_7z(dest, exdir)
    txt <- list.files(exdir, pattern = "\\.(txt|TXT)$", full.names = TRUE)
    map_dfr(txt, function(f) {
      cab <- names(fread(f, sep = ";", nrows = 0, encoding = "Latin-1"))
      c_mun  <- acha_col(cab, c("^Munic.pio$", "^Mun Trab", "Munic"))
      c_cn2  <- acha_col(cab, c("CNAE 2\\.0 Classe"))
      c_cn95 <- acha_col(cab, c("CNAE 95 Classe"))
      c_at   <- acha_col(cab, c("V.nculo Ativo 31/12", "Ativo"))
      c_rdez <- acha_col(cab, c("Vl Remun Dezembro Nom", "Remun Dezembro"))
      c_rmed <- acha_col(cab, c("Vl Remun M.dia Nom", "Remun M.dia"))
      mapa <- c(mun = c_mun, cnae2 = c_cn2, cnae95 = c_cn95,
                ativo = c_at, rem_dez = c_rdez, rem_med = c_rmed)
      mapa <- mapa[!is.na(mapa)]
      if (!all(c("mun", "ativo", "rem_dez", "rem_med") %in% names(mapa)))
        stop("Colunas não encontradas em ", f, ": ", paste(cab, collapse = " | "))
      d <- fread(f, sep = ";", select = unname(mapa), encoding = "Latin-1",
                 colClasses = "character", showProgress = FALSE)
      setnames(d, unname(mapa), names(mapa))
      d[, `:=`(ativo = as.integer(ativo) == 1,
               rem_dez = as.numeric(gsub(",", ".", rem_dez)),
               rem_med = as.numeric(gsub(",", ".", rem_med)))]
      d[, uf := substr(mun, 1, 2)]
      d <- d[uf %in% as.character(UFS)]
      if ("cnae2" %in% names(d)) {
        d[, cn := sprintf("%05d", as.integer(cnae2))]
        d[, `:=`(secF = substr(cn, 1, 2) %in% c("41", "42", "43"),
                 div42 = substr(cn, 1, 2) == "42", cl42111 = cn == "42111")]
      } else {
        d[, cn := sprintf("%05d", as.integer(cnae95))]
        d[, `:=`(secF = substr(cn, 1, 2) == "45", div42 = NA, cl42111 = NA)]
      }
      d[, .(emp_total = sum(ativo), massa_dez_total = sum(rem_dez[ativo], na.rm = TRUE),
            massa_media_total = sum(rem_med, na.rm = TRUE),
            emp_secF = sum(ativo & secF), massa_dez_secF = sum(rem_dez[ativo & secF], na.rm = TRUE),
            emp_div42 = sum(ativo & div42), massa_dez_div42 = sum(rem_dez[ativo & div42], na.rm = TRUE),
            emp_42111 = sum(ativo & cl42111)),
        by = .(mun6 = substr(mun, 1, 6))][, ano := ano]
    })
  }) |> group_by(mun6, ano) |> summarise(across(everything(), sum), .groups = "drop")
}
# Se o FTP do MTE não responder (protocolo FTP bloqueado na rede), o painel é
# montado sem a RAIS: as colunas de emprego e massa salarial ficam NA.
arq_rais <- file.path(DIR, "rais_municipio_ano.csv")
rais <- if (file.exists(arq_rais)) {
  message("RAIS: reaproveitando ", arq_rais)
  read_csv(arq_rais, col_types = cols(mun6 = "c", ano = "i", .default = "d"))
} else tryCatch({
  # checagem antes do FTP: sem DNS o libcurl aborta o R em vez de devolver erro
  if (is.null(curl::nslookup("ftp.mtps.gov.br", error = FALSE)))
    stop("ftp.mtps.gov.br não resolve nesta rede (FTP bloqueado)")
  r <- map_dfr(ANOS, rais_ano); write_csv(r, arq_rais); r
}, error = function(e) {
  warning("RAIS NÃO BAIXADA (FTP do MTE inacessível): ", conditionMessage(e),
          "\nO painel segue sem emprego/massa salarial.", call. = FALSE)
  writeLines(conditionMessage(e), file.path(DIR, "rais_FALHOU.txt"))
  tibble::tibble(mun6 = character(), ano = integer(), emp_total = numeric(),
                 massa_dez_total = numeric(), massa_media_total = numeric(),
                 emp_secF = numeric(), massa_dez_secF = numeric(), emp_div42 = numeric(),
                 massa_dez_div42 = numeric(), emp_42111 = numeric())
})

# =============================================================================
# 6. Painel final
# =============================================================================
painel <- pib |>
  left_join(populacao, by = c("cod_ibge", "ano")) |>
  left_join(soja,      by = c("cod_ibge", "ano")) |>
  left_join(iss_siconfi, by = c("cod_ibge", "ano")) |>
  mutate(mun6 = substr(cod_ibge, 1, 6)) |>
  left_join(rais, by = c("mun6", "ano")) |>
  mutate(pib_pc_interp = 1000 * pib / pop_interp,          # PIB em mil R$
         emp_secF_mil  = 1000 * emp_secF / pop_interp,
         emp_div42_mil = 1000 * emp_div42 / pop_interp)
write_csv(painel, "painel_municipal.csv")
message("Painel: ", nrow(painel), " linhas, ", n_distinct(painel$cod_ibge), " municípios.")
