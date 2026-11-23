# Dissertação — impacto da FIOL e da FNS-ES nos municípios

Avaliação de impacto da implantação da FIOL I, FIOL II e Ferrovia Norte-Sul Extensão Sul
sobre PIB, PIB per capita e emprego dos municípios interceptados (BA, GO, MG, SP).
Métodos: controle sintético, Synthetic DiD, Callaway & Sant'Anna, TWFE/Sun & Abraham,
escore de propensão. Datas de tratamento por ferrovia: FIOL I e FNS-ES em 2011, FIOL II em 2013.

## Ambiente

- R e pacotes de sistema: rode `bash setup_ambiente.sh` se o R não estiver instalado.
- Pacotes R: os scripts instalam o que falta; `synthdid` e `HonestDiD` vêm do GitHub
  (`remotes::install_github("synth-inference/synthdid")`,
  `remotes::install_github("asheshrambachan/HonestDiD")`).
- O ambiente precisa de acesso à internet completo (Network access = Full): IBGE
  (apisidra.ibge.gov.br, servicodados.ibge.gov.br), Tesouro (apidatalake.tesouro.gov.br),
  MTE (ftp.mtps.gov.br), CRAN e GitHub.

## Ordem de execução

1. `Rscript baixar_bases_fiol_fns.R` — PIB, população, soja, ISS e RAIS 2002–2023 → `painel_municipal.csv`
2. `Rscript tracado_osm.R` — traçado da FIOL e da FNS-ES do OpenStreetMap (ou `tracado_oficial.gpkg`, se existir)
   → `tracado_ferrovias.gpkg`, `municipios_tratados_proposta.csv` e `mapa_tracado.png`. Se houver
   `municipios_fernando.csv` (lista oficial da dissertação), gera `comparacao_lista_fernando.csv`.
   PARE e mostre a contagem por ferrovia (esperado: FIOL I 18, FIOL II 12, FNS-ES 28), os alertas e as
   diferenças em relação à lista do Fernando antes de seguir. A lista do Fernando prevalece.
3. `Rscript calcular_aneis.R` → `municipios_grupos.csv` e `km_por_municipio.csv`
4. `deflator_pib.csv` (ano, deflator, 2020 = 100) e `ipca.csv` (ano, ipca_indice): montar a partir do
   SIDRA/IPEA se não existirem e registrar a fonte.
5. `Rscript rodar_periodos.R` — roda `analise_impacto_ferrovias.R` para 2002–2019 e 2002–2023 e compara.
5b. `Rscript sdid_janelas.R` — Synthetic DiD ano a ano e por janela (mesmas janelas do TWFE), depois do passo 5.
5c. ISS como variável dependente: `Rscript baixar_iss_ipeadata.R` (ISS municipal 2002–2023, Ipeadata/STN) e
   `Rscript rodar_iss.R` (mesma análise, saídas em `resultados_iss_*`); `DESFECHO=iss Rscript sdid_janelas.R`.
6. `Rscript rais_longa_scm.R` — série longa da RAIS (1995–) e controle sintético longo. É o mais pesado.

## Regras de trabalho

- Corrija erros de execução (nomes de colunas, arquivos do FTP, pacotes) sem mudar a metodologia.
  Mudanças de método (datas, covariáveis, janelas, regras de controle) devem ser perguntadas antes.
- Não mude as datas em `DATA_TRAT` nem as janelas sem pedir.
- Na primeira execução da RAIS, confira e relate quais arquivos do FTP foram selecionados por ano e
  os códigos do Subsetor IBGE (`00_checagem_subsetores.csv`) antes de seguir.
- Se o FTP do MTE não responder (protocolo FTP pode ser bloqueado), relate e siga com as demais bases.
- Não versione dados: `dados_brutos/`, `resultados*/` e CSVs grandes ficam no `.gitignore`.
- Ao terminar, escreva `RESUMO_RESULTADOS.md` com: amostra (tratados e controles por ferrovia,
  tratados sem par no escore de propensão), tabelas principais (efeito, IC 95%, p, pré-tendência,
  efeito mínimo detectável) para os dois períodos, comparação pareados x todos os controles, e
  avisos de qualquer etapa que falhou. Números sempre copiados dos CSVs de saída, nunca estimados.
