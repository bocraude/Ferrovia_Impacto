# =============================================================================
# Gera municipios_grupos.csv: classifica cada município de BA, GO, MG e SP em
# tratado (por ferrovia) ou controle e calcula o "anel" — distância ao traçado
# em camadas de vizinhança (0 = interceptado, 1 = vizinho, 2 = vizinho do
# vizinho, ...). Controles elegíveis: anel >= 3 e sem outro projeto ferroviário.
#
# Duas formas de informar os tratados (use uma):
#  A) tracado_ferrovias.shp (ou .gpkg) com uma coluna "ferrovia" contendo
#     "FIOL I", "FIOL II", "FNS-ES" (e, se quiser, "FIOL III", "FICO" etc.).
#     O script identifica os municípios cruzados e mede os km de linha em cada um.
#  B) municipios_tratados.csv com colunas cod_ibge, ferrovia
#  A lista oficial municipios_fernando.csv (cod_ibge, nome, ferrovia), quando
#  preenchida, prevalece sobre A e B; o traçado continua dando os km por município.
#     (a lista que o Fernando já usa: 18 FIOL I, 12 FIOL II, 28 FNS-ES)
# Opcional: outros_projetos.csv (cod_ibge, projeto) — municípios cortados por
#     FIOL III, FICO, Transnordestina etc., que não podem ser controle.
#
# Saídas: municipios_grupos.csv, km_por_municipio.csv (se A), mapa_aneis.png
# =============================================================================

pacotes <- c("dplyr", "readr", "sf", "geobr", "spdep", "ggplot2", "purrr")
falta <- setdiff(pacotes, rownames(installed.packages()))
if (length(falta)) install.packages(falta)
invisible(lapply(pacotes, library, character.only = TRUE))
sf_use_s2(FALSE)

UFS_ANALISE <- c(29, 52, 31, 35)                  # BA, GO, MG, SP
FERROV      <- c("FIOL I", "FIOL II", "FNS-ES")
ANO_MALHA   <- 2020                               # malha municipal do IBGE via geobr
CRS_METROS  <- 5880                               # SIRGAS 2000 / Brazil Polyconic

# ---- 1. Malha municipal (Brasil inteiro, para não perder vizinhos de outra UF)
mun <- read_municipality(code_muni = "all", year = ANO_MALHA, simplified = FALSE,
                         showProgress = FALSE) |>
  st_make_valid() |>
  mutate(cod_ibge = as.character(code_muni), uf_cod = as.integer(substr(cod_ibge, 1, 2))) |>
  select(cod_ibge, nome = name_muni, uf = abbrev_state, uf_cod)
st_geometry(mun) <- "geometry"   # a malha do geobr vem com a coluna "geom"; os cálculos abaixo usam "geometry"

# ---- 2. Tratados ----------------------------------------------------------------
arq_tracado <- list.files(".", pattern = "^tracado_ferrovias\\.(shp|gpkg)$")[1]
km_mun <- NULL
if (!is.na(arq_tracado)) {
  message("Usando o traçado em ", arq_tracado)
  linhas <- st_read(arq_tracado, quiet = TRUE) |> st_make_valid() |>
    st_transform(st_crs(mun)) |> select(ferrovia)
  cruz <- st_intersection(st_transform(mun, CRS_METROS), st_transform(linhas, CRS_METROS))
  km_mun <- cruz |>
    mutate(km = as.numeric(st_length(geometry)) / 1000) |>
    st_drop_geometry() |>
    group_by(cod_ibge, nome, uf, ferrovia) |>
    summarise(km_no_municipio = sum(km), .groups = "drop") |>
    filter(km_no_municipio > 0.1)                  # descarta toques de fronteira
  write_csv(km_mun, "km_por_municipio.csv")
  tratados <- km_mun |> select(cod_ibge, ferrovia)
}
# A lista oficial do Fernando, se preenchida, prevalece sobre o traçado
if (file.exists("municipios_fernando.csv") &&
    nrow(read_csv("municipios_fernando.csv", show_col_types = FALSE)) > 0) {
  message("Usando a lista oficial municipios_fernando.csv para os tratados")
  tratados_fer <- read_csv("municipios_fernando.csv", col_types = cols(cod_ibge = "c")) |>
    select(cod_ibge, ferrovia)
  if (exists("tratados")) {   # trechos do traçado fora do estudo continuam como "outro projeto"
    tratados <- bind_rows(tratados_fer, tratados |> filter(!ferrovia %in% FERROV))
  } else tratados <- tratados_fer
} else if (is.na(arq_tracado) && file.exists("municipios_tratados.csv")) {
  message("Usando municipios_tratados.csv")
  tratados <- read_csv("municipios_tratados.csv", col_types = cols(cod_ibge = "c")) |>
    select(cod_ibge, ferrovia)
} else if (!exists("tratados")) stop("Forneça municipios_fernando.csv, tracado_ferrovias.gpkg ou municipios_tratados.csv")

outros <- if (file.exists("outros_projetos.csv"))
  read_csv("outros_projetos.csv", col_types = cols(cod_ibge = "c")) else
  tibble(cod_ibge = character(), projeto = character())
# Ferrovias do traçado que não são do estudo também viram "outro projeto"
outros <- bind_rows(outros, tratados |> filter(!ferrovia %in% FERROV) |>
                      transmute(cod_ibge, projeto = ferrovia)) |> distinct()
tratados <- tratados |> filter(ferrovia %in% FERROV) |> distinct()

dup <- tratados |> count(cod_ibge) |> filter(n > 1)
if (nrow(dup)) message("Municípios em mais de uma ferrovia (ex.: Caetité): ",
                       paste(dup$cod_ibge, collapse = ", "),
                       " — mantidos na primeira; revise manualmente.")
tratados <- tratados |> group_by(cod_ibge) |> slice(1) |> ungroup()

# ---- 3. Contiguidade (rainha: compartilhar ao menos um ponto de fronteira) -----
nb <- poly2nb(mun, queen = TRUE, snap = 1e-4)

anel_a_partir <- function(origem_idx, max_anel = 10) {
  dist <- rep(NA_integer_, length(nb)); dist[origem_idx] <- 0L
  fronteira <- origem_idx
  for (k in seq_len(max_anel)) {
    viz <- setdiff(unique(unlist(nb[fronteira])), 0L)
    novos <- viz[is.na(dist[viz])]
    if (!length(novos)) break
    dist[novos] <- k; fronteira <- novos
  }
  dist[is.na(dist)] <- max_anel + 1L        # "longe": >= max_anel + 1
  dist
}
idx <- function(cods) which(mun$cod_ibge %in% cods)

aneis <- tibble(
  cod_ibge   = mun$cod_ibge,
  anel_fiol1 = anel_a_partir(idx(tratados$cod_ibge[tratados$ferrovia == "FIOL I"])),
  anel_fiol2 = anel_a_partir(idx(tratados$cod_ibge[tratados$ferrovia == "FIOL II"])),
  anel_fns   = anel_a_partir(idx(tratados$cod_ibge[tratados$ferrovia == "FNS-ES"])),
  anel_outro = if (nrow(outros)) anel_a_partir(idx(outros$cod_ibge)) else 99L
) |>
  mutate(anel = pmin(anel_fiol1, anel_fiol2, anel_fns))

# ---- 4. Classificação final ------------------------------------------------------
grupos <- mun |> st_drop_geometry() |>
  filter(uf_cod %in% UFS_ANALISE) |>
  left_join(tratados, by = "cod_ibge") |>
  left_join(aneis, by = "cod_ibge") |>
  mutate(ferrovia = coalesce(ferrovia, "controle"),
         pool = case_when(ferrovia %in% c("FIOL I", "FIOL II") ~ "BA",
                          ferrovia == "FNS-ES" ~ "FNS",
                          uf_cod == 29 ~ "BA",
                          TRUE ~ "FNS"),
         outro_projeto_ferroviario = as.integer(cod_ibge %in% outros$cod_ibge),
         observacao = case_when(
           ferrovia == "controle" & anel < 3 ~ "vizinho do traçado: fora do controle principal (usar em transbordamento)",
           ferrovia == "controle" & outro_projeto_ferroviario == 1 ~ "outro projeto ferroviário: fora do controle principal",
           ferrovia == "controle" & anel_outro <= 1 ~ "vizinho de outro projeto: avaliar",
           TRUE ~ "")) |>
  select(cod_ibge, nome, uf, ferrovia, pool, anel, anel_fiol1, anel_fiol2, anel_fns,
         outro_projeto_ferroviario, anel_outro, observacao) |>
  arrange(uf, ferrovia, anel, nome)

write_csv(grupos, "municipios_grupos.csv")

# ---- 5. Resumo e mapa para conferência ---------------------------------------------
print(grupos |> mutate(classe = case_when(ferrovia != "controle" ~ ferrovia,
                                          outro_projeto_ferroviario == 1 ~ "outro projeto",
                                          anel >= 3 ~ "controle elegível",
                                          TRUE ~ paste0("vizinho (anel ", anel, ")"))) |>
        count(pool, classe))

mapa <- mun |> filter(uf_cod %in% UFS_ANALISE) |>
  left_join(grupos |> select(cod_ibge, ferrovia, anel, outro_projeto_ferroviario), by = "cod_ibge") |>
  mutate(classe = case_when(ferrovia != "controle" ~ ferrovia,
                            outro_projeto_ferroviario == 1 ~ "Outro projeto",
                            anel == 1 ~ "Anel 1", anel == 2 ~ "Anel 2",
                            TRUE ~ "Controle elegível (anel ≥ 3)"),
         classe = factor(classe, c(FERROV, "Anel 1", "Anel 2", "Outro projeto", "Controle elegível (anel ≥ 3)")))
g <- ggplot(mapa) + geom_sf(aes(fill = classe), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = c("FIOL I" = "#2a78d6", "FIOL II" = "#6250d6", "FNS-ES" = "#eb6834",
                               "Anel 1" = "#b4b2a9", "Anel 2" = "#d3d1c7",
                               "Outro projeto" = "#e34948", "Controle elegível (anel ≥ 3)" = "#f1efe8")) +
  labs(fill = NULL) + theme_void() + theme(legend.position = "right")
ggsave("mapa_aneis.png", g, width = 9, height = 8, dpi = 200)
message("Gerados: municipios_grupos.csv, mapa_aneis.png",
        if (!is.null(km_mun)) ", km_por_municipio.csv" else "")
