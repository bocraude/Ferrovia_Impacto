# Resumo dos resultados — impacto da FIOL I, FIOL II e FNS-ES

Gerado por `montar_resumo.R`. Todas as tabelas são lidas dos CSVs de `resultados_ate_2019/`,
`resultados_ate_2023/` e `resultados_comparacao/`; os números citados no texto foram copiados
desses mesmos arquivos. Efeitos em pontos de log (0,05 ≈ 5%).

## O que os resultados dizem

1. **Não há efeito robusto da obra sobre o PIB ou o PIB per capita em nenhuma das três ferrovias.**
   No período principal (2002–2019), a média conjunta do Callaway & Sant'Anna é 0,026 (p = 0,264)
   para o PIB e 0,015 (p = 0,495) para o PIB per capita.
2. **FNS-ES:** o Callaway & Sant'Anna dá 0,060 no PIB (p = 0,013) em 2002–2019, mas o teste de
   pré-tendência rejeita tendências paralelas (p = 0,032), o Synthetic DiD (0,007) e o TWFE (−0,013)
   ficam em zero, a inferência por randomização dá p = 0,767 e, com controles pareados, o efeito
   perde significância (0,049; p = 0,216). O HonestDiD só exclui zero com Mbar = 0.
3. **FIOL II:** em 2002–2023 aparecem efeitos grandes (CS 0,138, p = 0,033; Synthetic DiD 0,205;
   TWFE 0,179; randomização p = 0,012), concentrados na janela 2018–2023 (0,274). **Não devem ser
   lidos como efeito da ferrovia:** 6 dos 11 municípios tratados são produtores de soja do oeste
   baiano e nenhum dos 271 controles elegíveis da Bahia tinha soja em 2002–2009. Na amostra pareada
   (5 tratados sem soja, 15 controles) o CS é −0,079 (p = 0,395) e o Synthetic DiD 0,036 (p = 0,637).
   Em 2002–2019 o CS da FIOL II é 0,039 (p = 0,522).
4. **FIOL I:** CS −0,033 (p = 0,506) e Synthetic DiD 0,010 no PIB em 2002–2019. O TWFE do PIB per
   capita é positivo (0,114; p < 0,001), mas o CS do mesmo desfecho é −0,022 (p = 0,671) com
   pré-tendência rejeitada (p = 0,003): o resultado do TWFE não se sustenta nos outros estimadores.
5. **Poder estatístico baixo:** o efeito mínimo detectável por placebo fica entre 14,5% e 18,6% do
   PIB em 2002–2019. Efeitos menores que isso não seriam detectados com esta amostra.
6. **Pré-tendências:** o teste do CS rejeita tendências paralelas (p < 0,05) na média conjunta, na
   FIOL I e na FNS-ES para o PIB. Isso enfraquece a leitura causal de qualquer estimativa de DiD aqui.

## Avisos — o que não rodou ou foi alterado

- **RAIS não baixada.** O servidor do MTE (ftp.mtps.gov.br) só atende por FTP, protocolo bloqueado na
  rede do ambiente em nuvem. Consequências: o desfecho **emprego na construção não foi estimado** em
  nenhuma tabela; a etapa 6 (`rais_longa_scm.R`, série longa e controle sintético longo) **não foi
  executada**; a checagem dos arquivos do FTP e de `00_checagem_subsetores.csv` não pôde ser feita.
  Para rodar: executar `baixar_bases_fiol_fns.R` e `rais_longa_scm.R` em máquina com acesso FTP.
- **Controle sintético com todos os doadores (seção 3 da análise) não executado**, por decisão do
  usuário: um ajuste com 271 doadores leva cerca de 207 s e os placebos exigem um ajuste por doador.
  Ficou o controle sintético com doadores pareados (seção 11) e o SC do `synthdid`.
- **Soja fora das covariáveis do CS na Bahia** (FIOL I e FIOL II), por decisão do usuário: não há
  variação entre os controles. Na FNS-ES a covariável foi mantida.
- **Wild cluster bootstrap (seção 7a) não executado:** o pacote `fwildclusterboot` não está mais no
  CRAN. A inferência por randomização (7b) rodou.
- **Lista de tratados:** a planilha do Fernando (aba "Municípios interceptados") prevaleceu sobre o
  traçado do OpenStreetMap. Homônimos confirmados pelo usuário: São Simão/GO e Turmalina/SP.
  Caetité consta na FIOL I e na FIOL II e ficou na FIOL I (FIOL II com 11 tratados). Correntina
  consta na FIOL II e na FIOL III e ficou como tratada da FIOL II. FIOL III e TLSA entraram em
  `outros_projetos.csv`. Diferenças em relação ao OSM em `comparacao_lista_fernando.csv`: só na lista
  do Fernando — Ilhéus, Populina, Turmalina/SP e Cachoeira Alta; só no OSM — Anápolis e Campo Limpo
  de Goiás.
- **Atenção à planilha original:** na aba "PIB dos Municípios", a coluna "Ferrovias" marca homônimos
  de outros estados como interceptados (Riacho de Santana/RN e Jaborandi/SP como FIOL II; Trindade/PE,
  Nova Veneza/SC, São Simão/SP e Turmalina/MG como FNS-ES). Simulações que filtrem por essa coluna
  incluem municípios errados.
- **PIB:** série do SIDRA 5938 (2002–2023). Conferida contra a planilha do Fernando em 2010–2023:
  30.254 pares município-ano, diferença máxima de 0,005% (arredondamento).
- **Deflator:** deflator do PIB (SIDRA 6784, variável 9811, encadeado, 2020 = 100), em
  `deflator_pib.csv`. `ipca.csv` (SIDRA 1737, índice de dezembro) só seria usado pela etapa 6.
- **ISS:** Siconfi/DCA 2013–2023 baixado para os 2.161 municípios (20.835 observações); está no
  painel, mas não entra em nenhuma estimativa. FINBRA 2002–2012 não baixado (manual).
- **População:** 3 controles sem população nos três censos (Barrocas/BA, Ipiranga de Goiás/GO e Lagoa
  Santa/GO) saem dos modelos com covariáveis.
- **Versões:** R 4.3.3; `HonestDiD` 0.2.6 e `CVXR` 1.0-14 (as versões atuais exigem R ≥ 4.4);
  `geobr` 1.9.1 com a malha municipal 2020 do IPEA.
- **Ajustes de execução nos scripts** (sem mudar método): consulta ao SIDRA em blocos de anos quando
  passa de 100 mil valores; nomes de municípios comparados sem diferenciar maiúsculas; coluna de
  geometria da malha; erro-padrão do Synthetic DiD gravado como número; tabela do TWFE por amostra;
  linha duplicada do TWFE em `14_psm_vs_todos.csv` corrigida.

## 1. Amostra

Municípios de BA, GO, MG e SP por classe (`municipios_grupos.csv`):

| pool | classe | municípios |
|---|---|---|
| BA | Controle elegível (anel ≥ 3) | 271 |
| BA | Fora: vizinho do traçado (anel 1) | 59 |
| BA | Fora: vizinho do traçado (anel 2) | 58 |
| BA | Tratado — FIOL I | 18 |
| BA | Tratado — FIOL II | 11 |
| FNS | Controle elegível (anel ≥ 3) | 1571 |
| FNS | Fora: outro projeto ferroviário | 13 |
| FNS | Fora: vizinho do traçado (anel 1) | 55 |
| FNS | Fora: vizinho do traçado (anel 2) | 77 |
| FNS | Tratado — FNS-ES | 28 |

Amostra que entra nos modelos (com dados no painel), por ferrovia e data de tratamento:

| pool | ferrovia | data de tratamento (0 = controle) | municípios |
|---|---|---|---|
| BA | FIOL I | 2011 | 18 |
| BA | FIOL II | 2013 | 11 |
| BA | controle | 0 | 271 |
| FNS | FNS-ES | 2011 | 28 |
| FNS | controle | 0 | 1571 |

Pareamento por escore de propensão (3 vizinhos, caliper 0,25 DP; igual nos dois períodos):

| ferrovia | tratados | tratados com par | controles pareados | tratados sem par |
|---|---|---|---|---|
| FIOL I | 18 | 17 | 51 | Mirante |
| FIOL II | 11 | 5 | 15 | Barreiras, Correntina, Jaborandi, São Desidério, São Félix Do Coribe, Serra Do Ramalho |
| FNS-ES | 28 | 28 | 80 | — |

Covariáveis do Callaway & Sant'Anna por ferrovia (`07_cs_covariaveis.csv`):

| ferrovia | covariaveis_usadas | retiradas_sem_variacao |
|---|---|---|
| FIOL I | ln_pop_2002 + sh_agro + sh_ind + sh_apu + ln_pibpc_2002 | soja_ha_pc |
| FIOL II | ln_pop_2002 + sh_agro + sh_ind + sh_apu + ln_pibpc_2002 | soja_ha_pc |
| FNS-ES | ln_pop_2002 + sh_agro + sh_ind + sh_apu + ln_pibpc_2002 + soja_ha_pc | — |

## 2. Tabelas principais — Callaway & Sant'Anna

Efeito médio pós-obra (ATT), IC 95% e p por bootstrap de municípios (199 réplicas); `p pré-tendência` = teste de Wald
dos coeficientes anteriores à obra (p baixo = tendências prévias diferentes); `MDE 80%` = efeito mínimo detectável (2,8 × EP).

### 2002–2019

| desfecho | painel | efeito | efeito (%) | IC 95% | p | p pré-tendência | MDE 80% |
|---|---|---|---|---|---|---|---|
| ln(PIB real) | Média conjunta | 0,026 | 2,7 | [-0,020; 0,072] | 0,264 | 0,002 | 0,066 |
| ln(PIB real) | Média sem FIOL II | 0,023 | 2,4 | [-0,024; 0,071] | 0,339 | 0,011 | 0,068 |
| ln(PIB real) | FIOL I | -0,033 | -3,3 | [-0,132; 0,065] | 0,506 | 0,011 | 0,141 |
| ln(PIB real) | FIOL II | 0,039 | 3,9 | [-0,080; 0,157] | 0,522 | 0,084 | 0,169 |
| ln(PIB real) | FNS-ES | 0,060 | 6,1 | [0,013; 0,107] | 0,013 | 0,032 | 0,067 |
| ln(PIB real per capita) | Média conjunta | 0,015 | 1,5 | [-0,028; 0,059] | 0,495 | 0,008 | 0,062 |
| ln(PIB real per capita) | Média sem FIOL II | 0,014 | 1,4 | [-0,034; 0,063] | 0,561 | 0,046 | 0,069 |
| ln(PIB real per capita) | FIOL I | -0,022 | -2,1 | [-0,121; 0,078] | 0,671 | 0,003 | 0,142 |
| ln(PIB real per capita) | FIOL II | 0,019 | 1,9 | [-0,093; 0,130] | 0,739 | 0,051 | 0,159 |
| ln(PIB real per capita) | FNS-ES | 0,037 | 3,8 | [-0,008; 0,083] | 0,106 | 0,057 | 0,065 |

| desfecho | teste | estatística | p |
|---|---|---|---|
| ln(PIB real) | igualdade dos efeitos entre as três ferrovias (χ², 2 gl) | 2,748 | 0,253 |
| ln(PIB real per capita) | igualdade dos efeitos entre as três ferrovias (χ², 2 gl) | 1,204 | 0,548 |

### 2002–2023

| desfecho | painel | efeito | efeito (%) | IC 95% | p | p pré-tendência | MDE 80% |
|---|---|---|---|---|---|---|---|
| ln(PIB real) | Média conjunta | 0,039 | 4,0 | [-0,008; 0,087] | 0,107 | 0,002 | 0,068 |
| ln(PIB real) | Média sem FIOL II | 0,016 | 1,6 | [-0,032; 0,064] | 0,522 | 0,011 | 0,069 |
| ln(PIB real) | FIOL I | -0,042 | -4,1 | [-0,129; 0,045] | 0,343 | 0,011 | 0,124 |
| ln(PIB real) | FIOL II | 0,138 | 14,8 | [0,011; 0,264] | 0,033 | 0,084 | 0,181 |
| ln(PIB real) | FNS-ES | 0,053 | 5,4 | [-0,004; 0,109] | 0,067 | 0,032 | 0,081 |
| ln(PIB real per capita) | Média conjunta | 0,023 | 2,4 | [-0,019; 0,066] | 0,275 | 0,008 | 0,060 |
| ln(PIB real per capita) | Média sem FIOL II | 0,003 | 0,3 | [-0,042; 0,049] | 0,889 | 0,046 | 0,065 |
| ln(PIB real per capita) | FIOL I | -0,025 | -2,5 | [-0,108; 0,058] | 0,549 | 0,003 | 0,119 |
| ln(PIB real per capita) | FIOL II | 0,108 | 11,4 | [-0,010; 0,226] | 0,072 | 0,051 | 0,168 |
| ln(PIB real per capita) | FNS-ES | 0,022 | 2,2 | [-0,028; 0,072] | 0,397 | 0,057 | 0,072 |

| desfecho | teste | estatística | p |
|---|---|---|---|
| ln(PIB real) | igualdade dos efeitos entre as três ferrovias (χ², 2 gl) | 6,051 | 0,049 |
| ln(PIB real per capita) | igualdade dos efeitos entre as três ferrovias (χ², 2 gl) | 3,185 | 0,203 |

## 3. Outros estimadores (ln do PIB real e do PIB real per capita)

### 2002–2019

Synthetic DiD, controle sintético (synthdid) e DiD — EP por placebo:

| ferrovia | desfecho | estimador | efeito | EP | IC 95% |
|---|---|---|---|---|---|
| FIOL I | ln(PIB real) | SDID | 0,010 | 0,034 | [-0,057; 0,078] |
| FIOL I | ln(PIB real) | SC | 0,131 | 0,050 | [0,033; 0,230] |
| FIOL I | ln(PIB real) | DiD | 0,048 | 0,051 | [-0,051; 0,147] |
| FIOL I | ln(PIB real per capita) | SDID | 0,037 | 0,037 | [-0,035; 0,109] |
| FIOL I | ln(PIB real per capita) | SC | 0,115 | 0,048 | [0,022; 0,208] |
| FIOL I | ln(PIB real per capita) | DiD | 0,114 | 0,053 | [0,010; 0,218] |
| FIOL II | ln(PIB real) | SDID | 0,110 | 0,051 | [0,010; 0,210] |
| FIOL II | ln(PIB real) | SC | 0,243 | 0,069 | [0,108; 0,379] |
| FIOL II | ln(PIB real) | DiD | 0,077 | 0,067 | [-0,055; 0,208] |
| FIOL II | ln(PIB real per capita) | SDID | 0,080 | 0,051 | [-0,019; 0,180] |
| FIOL II | ln(PIB real per capita) | SC | 0,196 | 0,058 | [0,083; 0,310] |
| FIOL II | ln(PIB real per capita) | DiD | 0,039 | 0,063 | [-0,083; 0,162] |
| FNS-ES | ln(PIB real) | SDID | 0,007 | 0,039 | [-0,069; 0,082] |
| FNS-ES | ln(PIB real) | SC | 0,011 | 0,056 | [-0,099; 0,121] |
| FNS-ES | ln(PIB real) | DiD | -0,013 | 0,049 | [-0,110; 0,083] |
| FNS-ES | ln(PIB real per capita) | SDID | -0,026 | 0,037 | [-0,099; 0,047] |
| FNS-ES | ln(PIB real per capita) | SC | 0,015 | 0,043 | [-0,070; 0,099] |
| FNS-ES | ln(PIB real per capita) | DiD | -0,068 | 0,047 | [-0,161; 0,025] |

TWFE estático (efeitos fixos de município e ano×pool; EP agrupado por município) e Sun & Abraham (ATT, ln PIB):

| amostra | desfecho | estimador | efeito | EP | p |
|---|---|---|---|---|---|
| Todas | ln(PIB real) | TWFE | 0,022 | 0,027 | 0,422 |
| Todas | ln(PIB real per capita) | TWFE | 0,008 | 0,027 | 0,777 |
| FIOL I | ln(PIB real) | TWFE | 0,048 | 0,035 | 0,171 |
| FIOL I | ln(PIB real per capita) | TWFE | 0,114 | 0,028 | <0,001 |
| FIOL II | ln(PIB real) | TWFE | 0,077 | 0,037 | 0,037 |
| FIOL II | ln(PIB real per capita) | TWFE | 0,040 | 0,049 | 0,419 |
| FNS-ES | ln(PIB real) | TWFE | -0,013 | 0,045 | 0,768 |
| FNS-ES | ln(PIB real per capita) | TWFE | -0,068 | 0,041 | 0,098 |
| Todas | ln(PIB real) | Sun & Abraham | 0,007 | 0,024 | 0,763 |
| FIOL I | ln(PIB real) | Sun & Abraham | -0,022 | 0,055 | 0,694 |
| FIOL II | ln(PIB real) | Sun & Abraham | 0,039 | 0,040 | 0,331 |
| FNS-ES | ln(PIB real) | Sun & Abraham | 0,014 | 0,029 | 0,617 |

Inferência por randomização do TWFE (999 permutações) e efeito mínimo detectável por placebo:

| ferrovia | efeito TWFE | p randomização | DP placebo | MDE 80% (%) |
|---|---|---|---|---|
| FIOL I | 0,048 | 0,345 | 0,054 | 16,3 |
| FIOL II | 0,077 | 0,236 | 0,061 | 18,6 |
| FNS-ES | -0,013 | 0,767 | 0,048 | 14,5 |

Efeitos por janela (fase da obra), TWFE:

| ferrovia | desfecho | janela | efeito | EP | IC 95% |
|---|---|---|---|---|---|
| FIOL I | ln(PIB real) | 2011-2015 obra | 0,091 | 0,049 | [-0,006; 0,187] |
| FIOL I | ln(PIB real) | 2016-2019 ritmo baixo | -0,005 | 0,051 | [-0,106; 0,095] |
| FIOL I | ln(PIB real per capita) | 2011-2015 obra | 0,151 | 0,047 | [0,059; 0,244] |
| FIOL I | ln(PIB real per capita) | 2016-2019 ritmo baixo | 0,068 | 0,044 | [-0,018; 0,154] |
| FIOL II | ln(PIB real) | 2013-2017 início lento | 0,043 | 0,039 | [-0,033; 0,118] |
| FIOL II | ln(PIB real) | 2018-2019 retomada | 0,161 | 0,042 | [0,079; 0,243] |
| FIOL II | ln(PIB real per capita) | 2013-2017 início lento | 0,012 | 0,050 | [-0,087; 0,110] |
| FIOL II | ln(PIB real per capita) | 2018-2019 retomada | 0,110 | 0,054 | [0,005; 0,216] |
| FNS-ES | ln(PIB real) | 2011-2019 obra Valec | -0,013 | 0,045 | [-0,102; 0,075] |
| FNS-ES | ln(PIB real per capita) | 2011-2019 obra Valec | -0,068 | 0,041 | [-0,148; 0,013] |

Robustez do CS às datas de tratamento (ln PIB):

| ferrovia | especificação | efeito | EP |
|---|---|---|---|
| FIOL I | Principal (2011 / FIOL II 2013) | -0,033 | 0,066 |
| FIOL I | Data comum 2010 | 0,065 | 0,033 |
| FIOL I | Data comum 2011 | -0,033 | 0,066 |
| FIOL I | FIOL II em 2014 | -0,033 | 0,062 |
| FIOL I | Data comum 2010 + antecipação 1 | 0,086 | 0,040 |
| FIOL I | Principal + antecipação 1 | 0,062 | 0,033 |
| FIOL II | Principal (2011 / FIOL II 2013) | 0,039 | 0,062 |
| FIOL II | Data comum 2010 | 0,117 | 0,026 |
| FIOL II | Data comum 2011 | 0,254 | 0,070 |
| FIOL II | FIOL II em 2014 | 0,098 | 0,042 |
| FIOL II | Data comum 2010 + antecipação 1 | 0,092 | 0,039 |
| FIOL II | Principal + antecipação 1 | 0,128 | 0,033 |
| FNS-ES | Principal (2011 / FIOL II 2013) | 0,060 | 0,027 |
| FNS-ES | Data comum 2010 | 0,048 | 0,033 |
| FNS-ES | Data comum 2011 | 0,060 | 0,026 |
| FNS-ES | FIOL II em 2014 | 0,060 | 0,027 |
| FNS-ES | Data comum 2010 + antecipação 1 | 0,054 | 0,042 |
| FNS-ES | Principal + antecipação 1 | 0,054 | 0,037 |

HonestDiD (magnitudes relativas; IC robusto do efeito médio pós-obra em ln PIB; Mbar = 0 equivale a tendências paralelas exatas):

| ferrovia | Mbar | IC robusto |
|---|---|---|
| FIOL I | 0 | [-0,137; 0,069] |
| FIOL I | 0.5 | [-0,594; 0,384] |
| FIOL I | 1 | [-1,061; 0,860] |
| FIOL I | 1.5 | [-1,061; 1,061] |
| FIOL I | 2 | [-1,061; 1,061] |
| FIOL II | 0 | [-0,061; 0,138] |
| FIOL II | 0.5 | [-0,469; 0,473] |
| FIOL II | 1 | [-0,916; 0,908] |
| FIOL II | 1.5 | [-1,025; 1,025] |
| FIOL II | 2 | [-1,025; 1,025] |
| FNS-ES | 0 | [0,008; 0,111] |
| FNS-ES | 0.5 | [-0,232; 0,379] |
| FNS-ES | 1 | [-0,527; 0,531] |
| FNS-ES | 1.5 | [-0,531; 0,531] |
| FNS-ES | 2 | [-0,531; 0,531] |

Controle sintético com doadores pareados (unidade tratada agregada; p = posição da razão RMSPE pós/pré entre os placebos):

| ferrovia | unidades (tratada + doadores) | razão RMSPE pós/pré | posição | p (placebos) |
|---|---|---|---|---|
| FIOL I | 52 | 4,8 | 14 | 0,269 |
| FIOL II | 16 | 49,4 | 1 | 0,062 |
| FNS-ES | 81 | 189,5 | 1 | 0,012 |

Decomposição de Goodman-Bacon do TWFE (amostra com as três ferrovias):

| comparação | peso | efeito médio |
|---|---|---|
| Earlier vs Later Treated | 0,001 | 0,021 |
| Later vs Earlier Treated | 0,001 | 0,106 |
| Treated vs Untreated | 0,998 | 0,028 |

### 2002–2023

Synthetic DiD, controle sintético (synthdid) e DiD — EP por placebo:

| ferrovia | desfecho | estimador | efeito | EP | IC 95% |
|---|---|---|---|---|---|
| FIOL I | ln(PIB real) | SDID | 0,002 | 0,040 | [-0,075; 0,080] |
| FIOL I | ln(PIB real) | SC | 0,137 | 0,052 | [0,036; 0,237] |
| FIOL I | ln(PIB real) | DiD | 0,041 | 0,054 | [-0,064; 0,147] |
| FIOL I | ln(PIB real per capita) | SDID | 0,038 | 0,042 | [-0,045; 0,121] |
| FIOL I | ln(PIB real per capita) | SC | 0,069 | 0,054 | [-0,038; 0,175] |
| FIOL I | ln(PIB real per capita) | DiD | 0,113 | 0,056 | [0,003; 0,223] |
| FIOL II | ln(PIB real) | SDID | 0,205 | 0,060 | [0,088; 0,323] |
| FIOL II | ln(PIB real) | SC | 0,372 | 0,078 | [0,218; 0,525] |
| FIOL II | ln(PIB real) | DiD | 0,161 | 0,072 | [0,020; 0,301] |
| FIOL II | ln(PIB real per capita) | SDID | 0,163 | 0,057 | [0,050; 0,275] |
| FIOL II | ln(PIB real per capita) | SC | 0,293 | 0,064 | [0,167; 0,419] |
| FIOL II | ln(PIB real per capita) | DiD | 0,113 | 0,069 | [-0,022; 0,247] |
| FNS-ES | ln(PIB real) | SDID | -0,008 | 0,045 | [-0,096; 0,080] |
| FNS-ES | ln(PIB real) | SC | -0,004 | 0,066 | [-0,132; 0,125] |
| FNS-ES | ln(PIB real) | DiD | -0,022 | 0,055 | [-0,130; 0,087] |
| FNS-ES | ln(PIB real per capita) | SDID | -0,054 | 0,040 | [-0,133; 0,025] |
| FNS-ES | ln(PIB real per capita) | SC | 0,002 | 0,051 | [-0,099; 0,103] |
| FNS-ES | ln(PIB real per capita) | DiD | -0,089 | 0,050 | [-0,186; 0,009] |

TWFE estático (efeitos fixos de município e ano×pool; EP agrupado por município) e Sun & Abraham (ATT, ln PIB):

| amostra | desfecho | estimador | efeito | EP | p |
|---|---|---|---|---|---|
| Todas | ln(PIB real) | TWFE | 0,034 | 0,030 | 0,261 |
| Todas | ln(PIB real per capita) | TWFE | 0,007 | 0,029 | 0,798 |
| FIOL I | ln(PIB real) | TWFE | 0,038 | 0,043 | 0,372 |
| FIOL I | ln(PIB real per capita) | TWFE | 0,113 | 0,036 | 0,002 |
| FIOL II | ln(PIB real) | TWFE | 0,179 | 0,036 | <0,001 |
| FIOL II | ln(PIB real per capita) | TWFE | 0,113 | 0,045 | 0,014 |
| FNS-ES | ln(PIB real) | TWFE | -0,019 | 0,049 | 0,691 |
| FNS-ES | ln(PIB real per capita) | TWFE | -0,091 | 0,043 | 0,033 |
| Todas | ln(PIB real) | Sun & Abraham | 0,011 | 0,024 | 0,654 |
| FIOL I | ln(PIB real) | Sun & Abraham | -0,029 | 0,047 | 0,529 |
| FIOL II | ln(PIB real) | Sun & Abraham | 0,101 | 0,036 | 0,005 |
| FNS-ES | ln(PIB real) | Sun & Abraham | 0,003 | 0,034 | 0,941 |

Inferência por randomização do TWFE (999 permutações) e efeito mínimo detectável por placebo:

| ferrovia | efeito TWFE | p randomização | DP placebo | MDE 80% (%) |
|---|---|---|---|---|
| FIOL I | 0,038 | 0,477 | 0,053 | 15,9 |
| FIOL II | 0,179 | 0,012 | 0,070 | 21,5 |
| FNS-ES | -0,019 | 0,693 | 0,053 | 15,9 |

Efeitos por janela (fase da obra), TWFE:

| ferrovia | desfecho | janela | efeito | EP | IC 95% |
|---|---|---|---|---|---|
| FIOL I | ln(PIB real) | 2011-2015 obra | 0,088 | 0,051 | [-0,013; 0,189] |
| FIOL I | ln(PIB real) | 2016-2020 ritmo baixo | -0,003 | 0,043 | [-0,087; 0,080] |
| FIOL I | ln(PIB real) | 2021-2023 concessão | 0,025 | 0,069 | [-0,109; 0,160] |
| FIOL I | ln(PIB real per capita) | 2011-2015 obra | 0,151 | 0,048 | [0,056; 0,245] |
| FIOL I | ln(PIB real per capita) | 2016-2020 ritmo baixo | 0,074 | 0,036 | [0,003; 0,144] |
| FIOL I | ln(PIB real per capita) | 2021-2023 concessão | 0,114 | 0,061 | [-0,005; 0,233] |
| FIOL II | ln(PIB real) | 2013-2017 início lento | 0,064 | 0,033 | [-0,001; 0,129] |
| FIOL II | ln(PIB real) | 2018-2023 retomada | 0,274 | 0,058 | [0,161; 0,388] |
| FIOL II | ln(PIB real per capita) | 2013-2017 início lento | 0,018 | 0,047 | [-0,075; 0,110] |
| FIOL II | ln(PIB real per capita) | 2018-2023 retomada | 0,192 | 0,059 | [0,076; 0,308] |
| FNS-ES | ln(PIB real) | 2011-2018 obra Valec | -0,002 | 0,044 | [-0,089; 0,085] |
| FNS-ES | ln(PIB real) | 2019-2020 conclusão | -0,061 | 0,060 | [-0,178; 0,056] |
| FNS-ES | ln(PIB real) | 2021-2023 operação | -0,038 | 0,066 | [-0,168; 0,091] |
| FNS-ES | ln(PIB real per capita) | 2011-2018 obra Valec | -0,057 | 0,040 | [-0,136; 0,022] |
| FNS-ES | ln(PIB real per capita) | 2019-2020 conclusão | -0,148 | 0,053 | [-0,253; -0,044] |
| FNS-ES | ln(PIB real per capita) | 2021-2023 operação | -0,142 | 0,054 | [-0,247; -0,037] |

Robustez do CS às datas de tratamento (ln PIB):

| ferrovia | especificação | efeito | EP |
|---|---|---|---|
| FIOL I | Principal (2011 / FIOL II 2013) | -0,042 | 0,050 |
| FIOL I | Data comum 2010 | 0,056 | 0,041 |
| FIOL I | Data comum 2011 | -0,042 | 0,048 |
| FIOL I | FIOL II em 2014 | -0,042 | 0,050 |
| FIOL I | Data comum 2010 + antecipação 1 | 0,077 | 0,052 |
| FIOL I | Principal + antecipação 1 | 0,053 | 0,043 |
| FIOL II | Principal (2011 / FIOL II 2013) | 0,138 | 0,057 |
| FIOL II | Data comum 2010 | 0,208 | 0,046 |
| FIOL II | Data comum 2011 | 0,344 | 0,097 |
| FIOL II | FIOL II em 2014 | 0,201 | 0,051 |
| FIOL II | Data comum 2010 + antecipação 1 | 0,183 | 0,058 |
| FIOL II | Principal + antecipação 1 | 0,227 | 0,058 |
| FNS-ES | Principal (2011 / FIOL II 2013) | 0,053 | 0,030 |
| FNS-ES | Data comum 2010 | 0,043 | 0,036 |
| FNS-ES | Data comum 2011 | 0,053 | 0,031 |
| FNS-ES | FIOL II em 2014 | 0,053 | 0,030 |
| FNS-ES | Data comum 2010 + antecipação 1 | 0,049 | 0,044 |
| FNS-ES | Principal + antecipação 1 | 0,047 | 0,039 |

HonestDiD (magnitudes relativas; IC robusto do efeito médio pós-obra em ln PIB; Mbar = 0 equivale a tendências paralelas exatas):

| ferrovia | Mbar | IC robusto |
|---|---|---|
| FIOL I | 0 | [-0,128; 0,045] |
| FIOL I | 0.5 | [-0,774; 0,587] |
| FIOL I | 1 | [-0,909; 0,909] |
| FIOL I | 1.5 | [-0,909; 0,909] |
| FIOL I | 2 | [-0,909; 0,909] |
| FIOL II | 0 | [0,039; 0,237] |
| FIOL II | 0.5 | [-0,565; 0,836] |
| FIOL II | 1 | [-1,043; 1,043] |
| FIOL II | 1.5 | [-1,043; 1,043] |
| FIOL II | 2 | [-1,043; 1,043] |
| FNS-ES | 0 | [-0,007; 0,112] |
| FNS-ES | 0.5 | [-0,363; 0,493] |
| FNS-ES | 1 | [-0,613; 0,613] |
| FNS-ES | 1.5 | [-0,613; 0,613] |
| FNS-ES | 2 | [-0,613; 0,613] |

Controle sintético com doadores pareados (unidade tratada agregada; p = posição da razão RMSPE pós/pré entre os placebos):

| ferrovia | unidades (tratada + doadores) | razão RMSPE pós/pré | posição | p (placebos) |
|---|---|---|---|---|
| FIOL I | 52 | 3,7 | 19 | 0,365 |
| FIOL II | 16 | 59,8 | 1 | 0,062 |
| FNS-ES | 81 | 394,7 | 1 | 0,012 |

Decomposição de Goodman-Bacon do TWFE (amostra com as três ferrovias):

| comparação | peso | efeito médio |
|---|---|---|
| Earlier vs Later Treated | 0,001 | 0,021 |
| Later vs Earlier Treated | 0,001 | 0,186 |
| Treated vs Untreated | 0,998 | 0,034 |

## 4. Controles pareados × todos os controles elegíveis

### 2002–2019

| ferrovia | desfecho | estimador | todos: efeito (EP); p; n trat/ctrl | pareados: efeito (EP); p; n trat/ctrl |
|---|---|---|---|---|
| FIOL I | ln(PIB real) | Callaway & Sant'Anna | -0,033 (0,063); p = 0,597; n = 18/271 | -0,049 (0,069); p = 0,474; n = 17/51 |
| FIOL I | ln(PIB real per capita) | Callaway & Sant'Anna | -0,022 (0,064); p = 0,736; n = 18/271 | -0,030 (0,077); p = 0,697; n = 17/51 |
| FIOL I | ln(PIB real) | TWFE | 0,048 (0,035); p = 0,169; n = 18/271 | 0,033 (0,042); p = 0,440; n = 17/51 |
| FIOL I | ln(PIB real per capita) | TWFE | 0,114 (0,028); p = <0,001; n = 18/271 | 0,100 (0,037); p = 0,006; n = 17/51 |
| FIOL I | ln(PIB real) | Synthetic DiD | 0,010 (0,035); p = 0,767; n = 18/271 | -0,026 (0,036); p = 0,481; n = 17/51 |
| FIOL I | ln(PIB real per capita) | Synthetic DiD | 0,037 (0,038); p = 0,331; n = 18/271 | -0,007 (0,036); p = 0,856; n = 17/51 |
| FIOL II | ln(PIB real) | Callaway & Sant'Anna | 0,039 (0,059); p = 0,515; n = 11/271 | -0,049 (0,070); p = 0,483; n = 5/15 |
| FIOL II | ln(PIB real per capita) | Callaway & Sant'Anna | 0,019 (0,064); p = 0,769; n = 11/271 | -0,055 (0,079); p = 0,492; n = 5/15 |
| FIOL II | ln(PIB real) | TWFE | 0,077 (0,037); p = 0,036; n = 11/271 | 0,109 (0,061); p = 0,073; n = 5/15 |
| FIOL II | ln(PIB real per capita) | TWFE | 0,040 (0,049); p = 0,418; n = 11/271 | 0,106 (0,051); p = 0,036; n = 5/15 |
| FIOL II | ln(PIB real) | Synthetic DiD | 0,110 (0,051); p = 0,030; n = 11/271 | 0,026 (0,058); p = 0,654; n = 5/15 |
| FIOL II | ln(PIB real per capita) | Synthetic DiD | 0,080 (0,046); p = 0,084; n = 11/271 | 0,037 (0,065); p = 0,567; n = 5/15 |
| FNS-ES | ln(PIB real) | Callaway & Sant'Anna | 0,060 (0,028); p = 0,035; n = 28/1571 | 0,049 (0,039); p = 0,216; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | Callaway & Sant'Anna | 0,037 (0,024); p = 0,112; n = 28/1571 | 0,020 (0,036); p = 0,589; n = 28/80 |
| FNS-ES | ln(PIB real) | TWFE | -0,013 (0,045); p = 0,768; n = 28/1571 | 0,003 (0,057); p = 0,960; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | TWFE | -0,068 (0,041); p = 0,098; n = 28/1571 | -0,036 (0,053); p = 0,492; n = 28/80 |
| FNS-ES | ln(PIB real) | Synthetic DiD | 0,007 (0,038); p = 0,864; n = 28/1571 | 0,051 (0,040); p = 0,201; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | Synthetic DiD | -0,026 (0,035); p = 0,461; n = 28/1571 | 0,020 (0,042); p = 0,629; n = 28/80 |

### 2002–2023

| ferrovia | desfecho | estimador | todos: efeito (EP); p; n trat/ctrl | pareados: efeito (EP); p; n trat/ctrl |
|---|---|---|---|---|
| FIOL I | ln(PIB real) | Callaway & Sant'Anna | -0,042 (0,049); p = 0,389; n = 18/271 | -0,065 (0,058); p = 0,270; n = 17/51 |
| FIOL I | ln(PIB real per capita) | Callaway & Sant'Anna | -0,025 (0,048); p = 0,600; n = 18/271 | -0,037 (0,059); p = 0,529; n = 17/51 |
| FIOL I | ln(PIB real) | TWFE | 0,038 (0,043); p = 0,371; n = 18/271 | 0,020 (0,053); p = 0,706; n = 17/51 |
| FIOL I | ln(PIB real per capita) | TWFE | 0,113 (0,036); p = 0,002; n = 18/271 | 0,096 (0,045); p = 0,032; n = 17/51 |
| FIOL I | ln(PIB real) | Synthetic DiD | 0,002 (0,043); p = 0,958; n = 18/271 | -0,049 (0,047); p = 0,301; n = 17/51 |
| FIOL I | ln(PIB real per capita) | Synthetic DiD | 0,038 (0,040); p = 0,345; n = 18/271 | -0,023 (0,050); p = 0,643; n = 17/51 |
| FIOL II | ln(PIB real) | Callaway & Sant'Anna | 0,138 (0,051); p = 0,007; n = 11/271 | -0,079 (0,093); p = 0,395; n = 5/15 |
| FIOL II | ln(PIB real per capita) | Callaway & Sant'Anna | 0,108 (0,053); p = 0,043; n = 11/271 | -0,087 (0,103); p = 0,399; n = 5/15 |
| FIOL II | ln(PIB real) | TWFE | 0,179 (0,036); p = <0,001; n = 11/271 | 0,121 (0,061); p = 0,046; n = 5/15 |
| FIOL II | ln(PIB real per capita) | TWFE | 0,113 (0,045); p = 0,013; n = 11/271 | 0,120 (0,059); p = 0,044; n = 5/15 |
| FIOL II | ln(PIB real) | Synthetic DiD | 0,205 (0,060); p = <0,001; n = 11/271 | 0,036 (0,077); p = 0,637; n = 5/15 |
| FIOL II | ln(PIB real per capita) | Synthetic DiD | 0,163 (0,056); p = 0,004; n = 11/271 | 0,047 (0,088); p = 0,590; n = 5/15 |
| FNS-ES | ln(PIB real) | Callaway & Sant'Anna | 0,053 (0,031); p = 0,088; n = 28/1571 | 0,036 (0,045); p = 0,426; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | Callaway & Sant'Anna | 0,022 (0,027); p = 0,423; n = 28/1571 | -0,005 (0,040); p = 0,901; n = 28/80 |
| FNS-ES | ln(PIB real) | TWFE | -0,019 (0,049); p = 0,691; n = 28/1571 | -0,011 (0,065); p = 0,865; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | TWFE | -0,091 (0,043); p = 0,033; n = 28/1571 | -0,058 (0,057); p = 0,316; n = 28/80 |
| FNS-ES | ln(PIB real) | Synthetic DiD | -0,008 (0,039); p = 0,838; n = 28/1571 | 0,043 (0,053); p = 0,416; n = 28/80 |
| FNS-ES | ln(PIB real per capita) | Synthetic DiD | -0,054 (0,040); p = 0,177; n = 28/1571 | -0,001 (0,049); p = 0,992; n = 28/80 |

## 5. Comparação entre períodos (Callaway & Sant'Anna)

| desfecho | painel | efeito 2002–2019 | p | efeito 2002–2023 | p  | diferença |
|---|---|---|---|---|---|---|
| ln(PIB real) | Média conjunta | 0,026 | 0,264 | 0,039 | 0,107 | 0,013 |
| ln(PIB real) | Média sem FIOL II | 0,023 | 0,339 | 0,016 | 0,522 | -0,008 |
| ln(PIB real) | FIOL I | -0,033 | 0,506 | -0,042 | 0,343 | -0,009 |
| ln(PIB real) | FIOL II | 0,039 | 0,522 | 0,138 | 0,033 | 0,099 |
| ln(PIB real) | FNS-ES | 0,060 | 0,013 | 0,053 | 0,067 | -0,007 |
| ln(PIB real per capita) | Média conjunta | 0,015 | 0,495 | 0,023 | 0,275 | 0,008 |
| ln(PIB real per capita) | Média sem FIOL II | 0,014 | 0,561 | 0,003 | 0,889 | -0,011 |
| ln(PIB real per capita) | FIOL I | -0,022 | 0,671 | -0,025 | 0,549 | -0,004 |
| ln(PIB real per capita) | FIOL II | 0,019 | 0,739 | 0,108 | 0,072 | 0,089 |
| ln(PIB real per capita) | FNS-ES | 0,037 | 0,106 | 0,022 | 0,397 | -0,016 |

