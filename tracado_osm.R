# =============================================================================
# Traçado da FIOL e da FNS-ES a partir do OpenStreetMap + lista de municípios
# interceptados (proposta, a conferir com a lista do Fernando)
#
# O geobr não tem ferrovias (só limites administrativos), então:
#   - linhas: OpenStreetMap via Overpass (pacote osmdata), trechos com nome
#     "Oeste-Leste"/FIOL/EF-334 e "Norte-Sul"/EF-151, em operação ou em obra
#   - municípios: malha do IBGE via geobr
# Se existir um traçado oficial (tracado_oficial.shp/.gpkg com coluna "ferrovia"),
# ele é usado no lugar do OSM.
#
# Saídas:
#   tracado_ferrovias.gpkg            linhas com a coluna ferrovia (lida por calcular_aneis.R)
#   municipios_tratados_proposta.csv  municípios cruzados, km de linha e alertas
#   municipios_tratados.csv           só é escrito se ainda não existir (não sobrescreve a lista do Fernando)
#   mapa_tracado.png                  conferência visual
#   comparacao_lista_fernando.csv     se municipios_fernando.csv existir (cod_ibge, ferrovia)
# =============================================================================

pacotes <- c("dplyr", "readr", "sf", "geobr", "osmdata", "ggplot2", "purrr", "stringr")
falta <- setdiff(pacotes, rownames(installed.packages()))
if (length(falta)) install.packages(falta)
invisible(lapply(pacotes, library, character.only = TRUE))
sf_use_s2(FALSE)
CRS_M <- 5880                                   # SIRGAS 2000 / Brazil Polyconic (metros)
ESPERADO <- c("FIOL I" = 18, "FIOL II" = 12, "FNS-ES" = 28)   # contagens da dissertação

mun <- read_municipality(code_muni = "all", year = 2020, simplified = FALSE, showProgress = FALSE) |>
  st_make_valid() |>
  transmute(cod_ibge = as.character(code_muni), nome = name_muni, uf = abbrev_state)
st_geometry(mun) <- "geometry"   # a malha do geobr vem com a coluna "geom"; os cálculos abaixo usam "geometry"
# o geobr grafa "Ouro Verde De Goiás", "União De Minas": comparar nomes sem diferenciar maiúsculas
igual <- function(a, b) tolower(a) %in% tolower(b)
centro <- function(nm, uf_) {
  m <- mun |> filter(igual(nome, nm), uf == uf_)
  if (!nrow(m)) stop("Município de referência não encontrado: ", nm, "/", uf_)
  st_coordinates(st_centroid(st_geometry(m)))[1, ]
}
CAETITE   <- centro("Caetité", "BA")             # divisa FIOL I (leste) / FIOL II (oeste)
OURO_VERDE <- centro("Ouro Verde de Goiás", "GO") # início da Extensão Sul

# ---- 1. Linhas -----------------------------------------------------------------
oficial <- list.files(".", pattern = "^tracado_oficial\\.(shp|gpkg)$")[1]
if (!is.na(oficial)) {
  message("Usando traçado oficial: ", oficial)
  linhas <- st_read(oficial, quiet = TRUE) |> st_transform(4326) |> select(ferrovia)
} else {
  message("Baixando linhas do OpenStreetMap (Overpass)...")
  busca <- function(bbox, padrao) {
    q <- opq(bbox = bbox, timeout = 300) |>
      add_osm_feature(key = "railway", value = c("rail", "construction", "disused", "proposed")) |>
      add_osm_feature(key = "name", value = padrao, value_exact = FALSE, match_case = FALSE)
    # consulta com erro (ex.: 504 do servidor) não pode virar "sem trechos": repete até responder
    r <- NULL; ok <- FALSE
    for (tentativa in 1:8) {
      r <- tryCatch({ x <- osmdata_sf(q)$osm_lines; ok <- TRUE; x },
                    error = function(e) { message("Overpass (", padrao, ", tentativa ", tentativa, "): ",
                                                  conditionMessage(e)); NULL })
      if (ok) break
      Sys.sleep(30)
    }
    if (!ok) stop("Overpass não respondeu à consulta '", padrao, "' após 8 tentativas.")
    message("OSM '", padrao, "': ", if (is.null(r)) 0 else nrow(r), " trechos")
    if (is.null(r) || !nrow(r)) return(NULL)
    r <- r |> select(osm_id, any_of(c("name", "railway", "ref")))
    names(st_geometry(r)) <- NULL      # geometrias nomeadas quebram bind_rows/distinct
    r
  }
  bbox_ba  <- c(-46.7, -18.4, -38.9, -10.0)      # oeste a leste da Bahia
  bbox_fns <- c(-51.5, -20.6, -48.5, -15.8)      # Ouro Verde (GO) a Estrela d'Oeste (SP)
  junta <- function(...) {
    l <- compact(list(...)); if (!length(l)) return(NULL)
    bind_rows(l) |> distinct(osm_id, .keep_all = TRUE)
  }
  fiol <- junta(busca(bbox_ba, "Oeste-Leste"), busca(bbox_ba, "Oeste Leste"), busca(bbox_ba, "FIOL"))
  fns  <- junta(busca(bbox_fns, "Norte-Sul"), busca(bbox_fns, "Norte Sul"), busca(bbox_fns, "EF-151"))
  if (is.null(fiol) || !nrow(fiol)) warning("Nenhum trecho da FIOL encontrado no OSM.")
  if (is.null(fns)  || !nrow(fns))  warning("Nenhum trecho da FNS encontrado no OSM.")
  if (is.null(fiol) && is.null(fns)) stop("OSM não retornou trechos: use um traçado oficial (tracado_oficial.gpkg).")
  linhas <- bind_rows(compact(list(if (!is.null(fiol)) mutate(fiol, grupo = "FIOL"),
                                   if (!is.null(fns))  mutate(fns,  grupo = "FNS"))))
  write_csv(st_drop_geometry(linhas), "osm_trechos_encontrados.csv")
}

# ---- 2. Municípios cruzados e km ------------------------------------------------
cruza <- st_intersection(st_transform(mun, CRS_M), st_transform(linhas, CRS_M)) |>
  mutate(km = as.numeric(st_length(geometry)) / 1000)

cent <- st_centroid(st_geometry(mun)) |> st_coordinates()
mun_xy <- tibble(cod_ibge = mun$cod_ibge, lon = cent[, 1], lat = cent[, 2])

prop <- cruza |> st_drop_geometry() |>
  group_by(across(c(cod_ibge, nome, uf, any_of(c("grupo", "ferrovia"))))) |>
  summarise(km_no_municipio = sum(km), .groups = "drop") |>
  filter(km_no_municipio > 0.1) |>
  left_join(mun_xy, by = "cod_ibge")

if (!"ferrovia" %in% names(prop)) {
  prop <- prop |>
    mutate(ferrovia = case_when(
      grupo == "FIOL" & uf == "BA" & lon >= CAETITE[["X"]] - 0.05 ~ "FIOL I",
      grupo == "FIOL" & uf == "BA"                                  ~ "FIOL II",
      grupo == "FNS" & uf %in% c("GO", "MG", "SP") & lat <= OURO_VERDE[["Y"]] + 0.05 ~ "FNS-ES",
      TRUE ~ "fora do estudo"))
}
prop <- prop |>
  mutate(alerta = case_when(
    igual(nome, "Caetité")                    ~ "junção FIOL I/FIOL II: decidir em qual entra",
    igual(nome, c("Anápolis", "Ouro Verde de Goiás")) ~ "ponta da Extensão Sul / ramal de Anápolis: conferir",
    km_no_municipio < 2                       ~ "menos de 2 km de linha: conferir se conta como interceptado",
    TRUE ~ "")) |>
  arrange(ferrovia, uf, lon)
write_csv(prop, "municipios_tratados_proposta.csv")

contagem <- prop |> filter(ferrovia %in% names(ESPERADO)) |> count(ferrovia) |>
  mutate(esperado = ESPERADO[ferrovia], diferenca = n - esperado)
print(contagem)
for (mg in c("Iturama", "Santa Vitória", "União de Minas"))   # citados na dissertação
  if (!any(igual(prop$nome, mg) & prop$ferrovia == "FNS-ES"))
    warning(mg, " (MG) não apareceu como FNS-ES: verifique o traçado do OSM.")

# ---- 3. Arquivos para os outros scripts -------------------------------------------
tracado <- cruza |> left_join(prop |> select(cod_ibge, ferrovia_mun = ferrovia), by = "cod_ibge") |>
  mutate(ferrovia = coalesce(if ("ferrovia" %in% names(cruza)) ferrovia else NA_character_, ferrovia_mun)) |>
  filter(!is.na(ferrovia)) |> select(ferrovia) |> st_transform(4326)
st_write(tracado, "tracado_ferrovias.gpkg", delete_dsn = TRUE, quiet = TRUE)

if (!file.exists("municipios_tratados.csv") ||
    nrow(read_csv("municipios_tratados.csv", show_col_types = FALSE)) == 0) {
  write_csv(prop |> filter(ferrovia %in% names(ESPERADO)) |> select(cod_ibge, nome, ferrovia),
            "municipios_tratados.csv")
  message("municipios_tratados.csv escrito a partir do OSM — CONFIRMAR com a lista do Fernando.")
} else message("municipios_tratados.csv já existe e não foi alterado.")

if (file.exists("municipios_fernando.csv")) {
  fer <- read_csv("municipios_fernando.csv", col_types = cols(cod_ibge = "c")) |> select(cod_ibge, ferrovia)
  comp <- full_join(fer |> rename(ferrovia_fernando = ferrovia),
                    prop |> filter(ferrovia %in% names(ESPERADO)) |>
                      select(cod_ibge, nome, uf, ferrovia_osm = ferrovia, km_no_municipio),
                    by = "cod_ibge") |>
    mutate(situacao = case_when(is.na(ferrovia_osm) ~ "só na lista do Fernando",
                                is.na(ferrovia_fernando) ~ "só no OSM",
                                ferrovia_osm != ferrovia_fernando ~ "ferrovia diferente",
                                TRUE ~ "igual"))
  write_csv(comp, "comparacao_lista_fernando.csv"); print(count(comp, situacao))
}

# ---- 4. Mapa de conferência -----------------------------------------------------
ufs <- mun |> filter(uf %in% c("BA", "GO", "MG", "SP"))
marc <- ufs |> inner_join(prop |> filter(ferrovia %in% names(ESPERADO)) |> select(cod_ibge, ferrovia),
                          by = "cod_ibge")
g <- ggplot() +
  geom_sf(data = ufs, fill = "grey97", colour = "grey85", linewidth = .05) +
  geom_sf(data = marc, aes(fill = ferrovia), colour = "white", linewidth = .05) +
  geom_sf(data = st_transform(linhas, st_crs(mun)), colour = "grey20", linewidth = .4) +
  scale_fill_manual(values = c("FIOL I" = "#2a78d6", "FIOL II" = "#6250d6", "FNS-ES" = "#eb6834")) +
  labs(fill = NULL, caption = "Linhas: OpenStreetMap; municípios: IBGE (geobr)") +
  theme_void() + theme(legend.position = "right")
ggsave("mapa_tracado.png", g, width = 9, height = 8, dpi = 200)
message("Concluído: tracado_ferrovias.gpkg, municipios_tratados_proposta.csv, mapa_tracado.png")
