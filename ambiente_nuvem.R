# Ajustes só deste ambiente (proxy HTTPS): não mudam nenhum cálculo.
#  - curl::has_internet() falha atrás do proxy -> forçado para TRUE
#  - Overpass: usa o espelho maps.mail.ru (overpass-api.de e kumi não respondem daqui)
#  - geobr::read_municipality: lê a malha 2020 (não simplificada) já baixada do IPEA em
#    dados_brutos/malha_2020/ (mesmos arquivos que o geobr baixaria; o servidor estava instável)
assignInNamespace("has_internet", function() TRUE, ns = "curl")
loadNamespace("geobr")
assignInNamespace("read_municipality", function(code_muni = "all", year = 2020, simplified = TRUE, ...) {
  stopifnot(identical(code_muni, "all"), year == 2020, !simplified)
  fs <- list.files("dados_brutos/malha_2020", pattern = "\\.gpkg$", full.names = TRUE)
  stopifnot(length(fs) == 27)
  do.call(rbind, lapply(fs, sf::st_read, quiet = TRUE))
}, ns = "geobr")
if (requireNamespace("osmdata", quietly = TRUE))
  osmdata::set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter")
