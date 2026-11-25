# =============================================================================
# Monta RESUMO_RESULTADOS.md a partir dos CSVs de saída (nenhum número é digitado
# à mão: tudo é lido de resultados_ate_2019/, resultados_ate_2023/,
# resultados_comparacao/ e dos arquivos de grupos). O texto fixo está em
# resumo_texto.md (avisos e leitura); as tabelas são geradas aqui.
# =============================================================================
suppressMessages({library(dplyr); library(readr); library(purrr); library(tidyr); library(stringr)})
PER <- c(ate_2019 = "2002–2019", ate_2023 = "2002–2023")
le <- function(p, f) read_csv(file.path(paste0("resultados_", p), f), show_col_types = FALSE)
n3 <- function(x) ifelse(is.na(x), "", formatC(x, digits = 3, format = "f", decimal.mark = ","))
n1 <- function(x) ifelse(is.na(x), "", formatC(x, digits = 1, format = "f", decimal.mark = ","))
pv <- function(x) ifelse(is.na(x), "", ifelse(x < 0.001, "<0,001", formatC(x, digits = 3, format = "f", decimal.mark = ",")))
md <- function(d) {
  d <- mutate(d, across(everything(), as.character))
  c(paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
    pmap_chr(d, function(...) paste0("| ", paste(c(...), collapse = " | "), " |")), "")
}
out <- character()
add <- function(...) out <<- c(out, ...)
rot <- c(ln_pib = "ln(PIB real)", ln_pibpc = "ln(PIB real per capita)")

# ---- Amostra -------------------------------------------------------------------
g <- read_csv("municipios_grupos.csv", col_types = cols(cod_ibge = "c"))
add("## 1. Amostra", "",
    "Municípios de BA, GO, MG e SP por classe (`municipios_grupos.csv`):", "",
    md(g |> mutate(classe = case_when(ferrovia != "controle" ~ paste("Tratado —", ferrovia),
                                      outro_projeto_ferroviario == 1 ~ "Fora: outro projeto ferroviário",
                                      anel >= 3 ~ "Controle elegível (anel ≥ 3)",
                                      TRUE ~ paste0("Fora: vizinho do traçado (anel ", anel, ")"))) |>
         count(pool, classe, name = "municípios")))
am <- le("ate_2019", "00_amostra_e_datas_tratamento.csv")
add("Amostra que entra nos modelos (com dados no painel), por ferrovia e data de tratamento:", "",
    md(am |> count(pool, ferrovia, g, name = "municípios") |> rename(`data de tratamento (0 = controle)` = g)))
psm <- le("ate_2019", "02f_psm_amostra_pareada.csv") |> count(ferrovia, papel) |>
  pivot_wider(names_from = papel, values_from = n)
sp <- le("ate_2019", "02f_psm_tratados_sem_par.csv")
add("Pareamento por escore de propensão (3 vizinhos, caliper 0,25 DP; igual nos dois períodos):", "",
    md(am |> filter(ferrovia != "controle") |> count(ferrovia, name = "tratados") |>
         left_join(psm, by = "ferrovia") |>
         left_join(sp |> group_by(ferrovia) |> summarise(`tratados sem par` = paste(nome, collapse = ", ")), by = "ferrovia") |>
         transmute(ferrovia, tratados, `tratados com par` = tratado, `controles pareados` = controle,
                   `tratados sem par` = coalesce(`tratados sem par`, "—"))))
cv <- le("ate_2019", "07_cs_covariaveis.csv")
add("Covariáveis do Callaway & Sant'Anna por ferrovia (`07_cs_covariaveis.csv`):", "",
    md(cv |> mutate(retiradas_sem_variacao = coalesce(retiradas_sem_variacao, "—"))))

# ---- Tabela principal: CS --------------------------------------------------------
add("## 2. Tabelas principais — Callaway & Sant'Anna", "",
    "Efeito médio pós-obra (ATT), IC 95% e p por bootstrap de municípios (199 réplicas); `p pré-tendência` = teste de Wald",
    "dos coeficientes anteriores à obra (p baixo = tendências prévias diferentes); `MDE 80%` = efeito mínimo detectável (2,8 × EP).", "")
for (p in names(PER)) {
  add(paste0("### ", PER[[p]]), "")
  cs <- map_dfr(names(rot), ~ le(p, paste0("07_cs_tabela_", .x, ".csv")))
  add(md(cs |> filter(!str_detect(painel, "Teste de igualdade")) |>
           transmute(desfecho = rot[desfecho], painel, efeito = n3(efeito), `efeito (%)` = n1(efeito_pct),
                     `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"), p = pv(p_valor),
                     `p pré-tendência` = pv(p_pretendencia), `MDE 80%` = n3(mde_80))))
  add(md(cs |> filter(str_detect(painel, "Teste de igualdade")) |>
           transmute(desfecho = rot[desfecho], teste = "igualdade dos efeitos entre as três ferrovias (χ², 2 gl)",
                     estatística = n3(efeito), p = pv(p_valor))))
}

# ---- Outros estimadores ------------------------------------------------------------
add("## 3. Outros estimadores (ln do PIB real e do PIB real per capita)", "")
for (p in names(PER)) {
  add(paste0("### ", PER[[p]]), "", "Synthetic DiD, controle sintético (synthdid) e DiD — EP por placebo:", "")
  add(md(le(p, "06_sdid_sc_did.csv") |>
           transmute(ferrovia, desfecho = rot[desfecho], estimador, efeito = n3(efeito), EP = n3(se),
                     `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"))))
  add("TWFE estático (efeitos fixos de município e ano×pool; EP agrupado por município) e Sun & Abraham (ATT, ln PIB):", "")
  tw <- le(p, "09_twfe_estatico.csv"); sa <- le(p, "09_sunab_att.csv")
  add(md(tw |> transmute(amostra, desfecho = rot[desfecho], estimador = "TWFE", efeito = n3(efeito), EP = n3(se), p = pv(p_valor)) |>
           bind_rows(sa |> transmute(amostra, desfecho = rot[["ln_pib"]], estimador = "Sun & Abraham",
                                     p = pv(2 * pnorm(-abs(efeito / se))), efeito = n3(efeito), EP = n3(se)) |>
                       relocate(p, .after = EP))))
  add("Inferência por randomização do TWFE (999 permutações) e efeito mínimo detectável por placebo:", "")
  add(md(le(p, "10_inferencia_randomizacao.csv") |>
           left_join(le(p, "12_mde_placebo.csv"), by = "ferrovia") |>
           transmute(ferrovia, `efeito TWFE` = n3(efeito), `p randomização` = pv(p_randomizacao),
                     `DP placebo` = n3(dp_placebo), `MDE 80% (%)` = n1(mde_80_pct))))
  add("Efeitos por janela (fase da obra), TWFE:", "")
  add(md(le(p, "09c_efeitos_por_janela.csv") |>
           transmute(ferrovia, desfecho = rot[desfecho], janela, efeito = n3(efeito), EP = n3(se),
                     `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"))))
  add("Robustez do CS às datas de tratamento (ln PIB):", "")
  add(md(le(p, "08_cs_robustez.csv") |> transmute(ferrovia, especificação = especificacao, efeito = n3(efeito), EP = n3(se))))
  add("HonestDiD (magnitudes relativas; IC robusto do efeito médio pós-obra em ln PIB; Mbar = 0 equivale a tendências paralelas exatas):", "")
  add(md(map_dfr(c("FIOL I" = "FIOLI", "FIOL II" = "FIOLII", "FNS-ES" = "FNSES"),
                 ~ le(p, paste0("11_honestdid_", .x, ".csv")), .id = "ferrovia") |>
           transmute(ferrovia, Mbar, `IC robusto` = paste0("[", n3(lb), "; ", n3(ub), "]"))))
  add("Controle sintético com doadores pareados (unidade tratada agregada; p = posição da razão RMSPE pós/pré entre os placebos):", "")
  add(md(map_dfr(c("FIOL I" = "FIOLI", "FIOL II" = "FIOLII", "FNS-ES" = "FNSES"), function(t) {
    d <- le(p, paste0("14_scm_psm_inferencia_", t, ".csv"))
    d |> filter(type == "Treated") |> transmute(`unidades (tratada + doadores)` = nrow(d), `razão RMSPE pós/pré` = n1(mspe_ratio),
                                                posição = rank, `p (placebos)` = pv(fishers_exact_pvalue))
  }, .id = "ferrovia")))
  bc <- le(p, "09b_bacon_resumo.csv")
  add("Decomposição de Goodman-Bacon do TWFE (amostra com as três ferrovias):", "",
      md(bc |> filter(amostra == "Todas") |> transmute(comparação = type, peso = n3(peso), `efeito médio` = n3(efeito_medio))))
}

# ---- Synthetic DiD por janela (sdid_janelas.R) ---------------------------------------
if (all(file.exists(file.path(paste0("resultados_", names(PER)), "06b_sdid_efeitos_por_janela.csv")))) {
  add("## 3b. Synthetic DiD por janela (fase da obra)", "",
      "Mesmo modelo da seção 3, com o efeito anual agregado nas janelas do TWFE (`sdid_janelas.R`); EP por placebo",
      "(200 réplicas). A linha \"Total pós-obra\" reproduz o efeito do Synthetic DiD da seção 3.", "")
  for (p in names(PER)) {
    add(paste0("### ", PER[[p]]), "")
    add(md(le(p, "06b_sdid_efeitos_por_janela.csv") |>
             mutate(controles = ifelse(str_detect(controles, "Pareados"), "pareados", "todos")) |>
             transmute(ferrovia, desfecho = rot[desfecho], janela, controles,
                       txt = paste0(n3(efeito), " (", n3(se), "); p = ", pv(p_valor))) |>
             pivot_wider(names_from = controles, values_from = txt) |>
             rename(`todos os controles: efeito (EP); p` = todos, `pareados: efeito (EP); p` = pareados)))
  }
}

# ---- Pareados x todos ---------------------------------------------------------------
add("## 4. Controles pareados × todos os controles elegíveis", "")
for (p in names(PER)) {
  add(paste0("### ", PER[[p]]), "")
  add(md(le(p, "14_psm_vs_todos.csv") |>
           mutate(controles = ifelse(str_detect(controles, "Pareados"), "pareados", "todos")) |>
           transmute(ferrovia, desfecho = rot[desfecho], estimador, controles,
                     txt = paste0(n3(efeito), " (", n3(se), "); p = ", pv(p_valor), "; n = ", n_trat, "/", n_ctrl)) |>
           pivot_wider(names_from = controles, values_from = txt) |>
           rename(`todos: efeito (EP); p; n trat/ctrl` = todos, `pareados: efeito (EP); p; n trat/ctrl` = pareados)))
}

# ---- Comparação entre períodos --------------------------------------------------------
cmp <- read_csv("resultados_comparacao/cs_comparacao_periodos.csv", show_col_types = FALSE)
add("## 5. Comparação entre períodos (Callaway & Sant'Anna)", "",
    md(cmp |> transmute(desfecho = rot[desfecho], painel, `efeito 2002–2019` = n3(efeito_ate_2019), `p` = pv(p_valor_ate_2019),
                        `efeito 2002–2023` = n3(efeito_ate_2023), `p ` = pv(p_valor_ate_2023), diferença = n3(diferenca))))

# ---- ISS como variável dependente (rodar_iss.R), só 2002–2019 --------------------------
PI <- "resultados_iss_ate_2019"
if (file.exists(file.path(PI, "07_cs_tabela_ln_iss.csv"))) {
  li <- function(f) read_csv(file.path(PI, f), show_col_types = FALSE)
  roti <- c(ln_iss = "ln(ISS real)", ln_isspc = "ln(ISS real per capita)")
  add("## 6. ISS como variável dependente (2002–2019)", "",
      "Mesma amostra, datas, covariáveis, pareamento e estimadores da análise do PIB; muda só o desfecho (`rodar_iss.R`).",
      "ISS municipal do Ipeadata/STN (série RISSM), deflacionado pelo deflator do PIB. Efeitos em pontos de log.", "",
      "Cobertura do ISS na amostra (`00_cobertura_iss.csv`; série completa = 18 anos com ISS declarado e positivo):", "",
      md(li("00_cobertura_iss.csv") |> transmute(ferrovia, pool, municípios = municipios, `série completa` = serie_completa,
                                                 `média de anos com ISS` = n1(media_anos))),
      "Callaway & Sant'Anna (painel incompleto aceito; bootstrap de 199 réplicas):", "")
  csi <- map_dfr(names(roti), ~ li(paste0("07_cs_tabela_", .x, ".csv")))
  add(md(csi |> filter(!str_detect(painel, "Teste de igualdade")) |>
           transmute(desfecho = roti[desfecho], painel, efeito = n3(efeito), `efeito (%)` = n1(efeito_pct),
                     `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"), p = pv(p_valor),
                     `p pré-tendência` = pv(p_pretendencia), `MDE 80%` = n3(mde_80))))
  add("Synthetic DiD, SC e DiD (só municípios com série completa de ISS; EP por placebo):", "",
      md(li("06_sdid_sc_did.csv") |> transmute(ferrovia, desfecho = roti[desfecho], estimador, efeito = n3(efeito), EP = n3(se),
                                               `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"))))
  add("TWFE estático e Sun & Abraham (ATT, ln ISS):", "",
      md(li("09_twfe_estatico.csv") |> transmute(amostra, desfecho = roti[desfecho], estimador = "TWFE", efeito = n3(efeito),
                                                 EP = n3(se), p = pv(p_valor), `n obs.` = n_obs) |>
           bind_rows(li("09_sunab_att.csv") |> transmute(amostra, desfecho = roti[["ln_iss"]], estimador = "Sun & Abraham",
                                                         p = pv(2 * pnorm(-abs(efeito / se))), efeito = n3(efeito), EP = n3(se)) |>
                       relocate(p, .after = EP))))
  add("Efeitos por janela (TWFE):", "",
      md(li("09c_efeitos_por_janela.csv") |> transmute(ferrovia, desfecho = roti[desfecho], janela, efeito = n3(efeito), EP = n3(se),
                                                       `IC 95%` = paste0("[", n3(ic_inf), "; ", n3(ic_sup), "]"))))
  if (file.exists(file.path(PI, "06b_sdid_efeitos_por_janela.csv")))
    add("Synthetic DiD por janela (`DESFECHO=iss Rscript sdid_janelas.R`):", "",
        md(li("06b_sdid_efeitos_por_janela.csv") |>
             mutate(controles = ifelse(str_detect(controles, "Pareados"), "pareados", "todos")) |>
             transmute(ferrovia, desfecho = roti[desfecho], janela, controles,
                       txt = paste0(n3(efeito), " (", n3(se), "); p = ", pv(p_valor), "; n = ", n_trat, "/", n_ctrl)) |>
             pivot_wider(names_from = controles, values_from = txt) |>
             rename(`todos: efeito (EP); p; n trat/ctrl` = todos, `pareados: efeito (EP); p; n trat/ctrl` = pareados)))
  add("Inferência por randomização (TWFE) e efeito mínimo detectável por placebo:", "",
      md(li("10_inferencia_randomizacao.csv") |> left_join(li("12_mde_placebo.csv"), by = "ferrovia") |>
           transmute(ferrovia, `efeito TWFE` = n3(efeito), `p randomização` = pv(p_randomizacao),
                     `DP placebo` = n3(dp_placebo), `MDE 80% (%)` = n1(mde_80_pct))))
  add("HonestDiD (IC robusto do efeito médio pós-obra em ln ISS):", "",
      md(map_dfr(c("FIOL I" = "FIOLI", "FIOL II" = "FIOLII", "FNS-ES" = "FNSES"),
                 ~ li(paste0("11_honestdid_", .x, ".csv")), .id = "ferrovia") |>
           transmute(ferrovia, Mbar, `IC robusto` = paste0("[", n3(lb), "; ", n3(ub), "]"))))
  add("Controles pareados × todos os elegíveis (n = municípios da amostra; o Synthetic DiD usa só os de série completa):", "",
      md(li("14_psm_vs_todos.csv") |>
           mutate(controles = ifelse(str_detect(controles, "Pareados"), "pareados", "todos")) |>
           transmute(ferrovia, desfecho = roti[desfecho], estimador, controles,
                     txt = paste0(n3(efeito), " (", n3(se), "); p = ", pv(p_valor), "; n = ", n_trat, "/", n_ctrl)) |>
           pivot_wider(names_from = controles, values_from = txt) |>
           rename(`todos: efeito (EP); p; n trat/ctrl` = todos, `pareados: efeito (EP); p; n trat/ctrl` = pareados)))
}

# ---- Impacto em reais (impacto_reais.R) ---------------------------------------------------
if (file.exists("resultados_impacto_reais/impacto_reais_por_fase.csv")) {
  ir <- read_csv("resultados_impacto_reais/impacto_reais_por_fase.csv", show_col_types = FALSE)
  m1 <- function(x) formatC(x, digits = 1, format = "f", decimal.mark = ",", big.mark = ".")
  add("## 7. Impacto em reais, por trecho e por fase (2002–2019)", "",
      "R$ milhões de 2020, acumulados na fase. PIB pelo Synthetic DiD e ISS pelo Callaway & Sant'Anna (`impacto_reais.R`).",
      "Contrafactual = observado / exp(efeito do ano); impacto = observado − contrafactual. IC 95% pelos percentis do impacto",
      "recalculado em cada simulação do efeito (200 placebos no PIB; 5.000 sorteios dos efeitos anuais no ISS).",
      "No ISS entram só os municípios-ano com declaração, então o montante é um piso.", "",
      md(ir |> transmute(variável = variavel, ferrovia, fase, anos, `observado` = m1(observado_mi), `impacto` = m1(impacto_mi),
                         `IC 95%` = paste0("[", m1(ic_inf_mi), "; ", m1(ic_sup_mi), "]"),
                         `% do contrafactual` = n1(impacto_pct_contrafactual), `média anual` = m1(impacto_medio_anual_mi))))
}

texto <- readLines("resumo_texto.md", encoding = "UTF-8")
i <- which(texto == "<!-- TABELAS -->")
writeLines(c(texto[seq_len(i - 1)], out, texto[-seq_len(i)]), "RESUMO_RESULTADOS.md", useBytes = TRUE)
message("RESUMO_RESULTADOS.md escrito (", length(out), " linhas de tabelas)")
