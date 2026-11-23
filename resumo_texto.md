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

7. **Synthetic DiD por fase da obra** (seção 3b, `sdid_janelas.R`): na FIOL I há um efeito positivo
   pequeno só na fase de obra 2011–2015 (0,058 no PIB, p = 0,079; 0,073 no PIB per capita, p = 0,029),
   que some em 2016–2019 (−0,049) e não aparece com controles pareados (0,033; p = 0,210). Na FIOL II
   o efeito com todos os controles está concentrado na retomada (0,206 em 2018–2019; 0,311 em
   2018–2023) e é nulo com pareados (0,030 e 0,045). Na FNS-ES não há efeito no PIB em nenhuma fase.

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

<!-- TABELAS -->
