# Metodologia — impacto da FIOL e da FNS-ES sobre os municípios interceptados

Este documento descreve como a análise foi construída: as variáveis de resultado (PIB, PIB per capita e ISS), a definição do tratamento, a escolha dos controles, os modelos estimados e qual deles é o mais adequado em cada caso. Tudo o que está aqui corresponde aos scripts do repositório; os números citados vêm das tabelas de saída e estão no `RESUMO_RESULTADOS.md`.

## 1. Variáveis de resultado

### 1.1 PIB real

O ponto de partida é o PIB dos Municípios do IBGE (tabela 5938 do SIDRA), de 2002 a 2023, em mil reais correntes, para os municípios da Bahia, de Goiás, de Minas Gerais e de São Paulo. Para comparar anos diferentes, cada valor é dividido pelo deflator implícito do PIB nacional (tabela 6784 do SIDRA, variável 9811, variações anuais encadeadas e reescaladas para 2020 = 100). O resultado é o PIB real em reais de 2020. Os modelos usam o logaritmo natural, de modo que os efeitos se leem como variação percentual aproximada: 0,05 equivale a cerca de 5%.

### 1.2 PIB real per capita

É o PIB real dividido pela população. A população é interpolada geometricamente entre os censos de 2000, 2010 e 2022, com 2023 extrapolado pela taxa de 2010 a 2022. As estimativas anuais oficiais não foram usadas porque dão saltos nos anos de censo, o que criaria quebras artificiais na série per capita.

### 1.3 ISS real

É a arrecadação municipal do Imposto sobre Serviços, da série RISSM do Ipeadata, cuja origem é a Secretaria do Tesouro Nacional (FINBRA e Siconfi), de 2002 a 2023, em reais correntes. A série foi conferida contra os dados baixados diretamente do Siconfi: os valores coincidem em pelo menos 99,9% dos casos de 2014 a 2023, com exceção de 2016 (95,7%). O ISS é deflacionado pelo mesmo deflator do PIB e entra em logaritmo, total e per capita. Anos em que o município não declarou, ou declarou zero, ficam como ausentes.

### 1.4 Por que PIB e ISS medem coisas diferentes

O PIB municipal não é medido diretamente: o IBGE reparte o valor adicionado de cada atividade do estado entre os municípios por meio de indicadores. Por isso ele tende a captar mal um choque local e temporário, como um canteiro de obras. O ISS é receita que entrou no caixa da prefeitura, e o ISS da construção civil é devido no município onde a obra acontece. Essa diferença é a interpretação proposta para a divergência entre os resultados das duas variáveis; os modelos não a testam diretamente.

## 2. Tratamento

- **Municípios tratados:** os interceptados pelo traçado, conforme a lista da dissertação. São 18 na FIOL I, 11 na FIOL II e 28 na FNS-ES. Caetité aparece nas duas FIOL e foi contado na FIOL I. Os homônimos da FNS-ES foram confirmados como São Simão (GO) e Turmalina (SP).
- **Data de início:** uma data por ferrovia, porque não há cronograma por município. FIOL I e FNS-ES começam em 2011, primeiro ano com obra física, e a FIOL II em 2013, ano da licença dos lotes 5 e 5A.
- **Fases da obra:** cada ferrovia tem janelas que permitem estimar um efeito por fase. No período principal (2002 a 2019): FIOL I com obra em 2011–2015 e ritmo baixo em 2016–2019; FIOL II com início lento em 2013–2017 e retomada em 2018–2019; FNS-ES com obra da Valec em 2011–2019.
- **Período principal:** 2002 a 2019, que cobre a fase de obra e exclui a pandemia. O período 2002 a 2023 foi estimado como complemento para o PIB.

## 3. Escolha dos controles

A escolha foi feita em três camadas. As duas primeiras definem quem pode ser controle; a terceira seleciona, entre esses, os mais parecidos com os tratados.

### 3.1 Conjunto de estados

Cada ferrovia só é comparada com municípios da sua região: a Bahia para a FIOL I e a FIOL II; Goiás, Minas Gerais e São Paulo para a FNS-ES. Os municípios tratados de um trecho nunca servem de controle para outro.

### 3.2 Distância ao traçado por anéis de vizinhança

- Sobre a malha municipal de 2020 do IBGE, dois municípios são considerados vizinhos quando compartilham ao menos um ponto de fronteira.
- Os municípios interceptados formam o anel 0. Seus vizinhos formam o anel 1, os vizinhos destes o anel 2, e assim sucessivamente.
- Só é controle elegível o município que está no anel 3 ou além. Os anéis 1 e 2 são excluídos porque podem receber transbordamento da obra, por deslocamento de trabalhadores, comércio e serviços, o que contaminaria a comparação.
- Também são excluídos os municípios cortados por outro projeto ferroviário: FIOL III, Transnordestina e o trecho da Norte-Sul ao norte de Ouro Verde de Goiás.

O resultado são 271 controles elegíveis na Bahia e 1.571 no conjunto da FNS-ES. Ficaram de fora 117 vizinhos na Bahia e 132 no outro conjunto; eles não entram em nenhum modelo.

### 3.3 Pareamento por escore de propensão

As estimativas principais usam todos os controles elegíveis. Como checagem de robustez, cada tratado foi pareado com controles semelhantes:

- Um modelo logit estima a probabilidade de o município estar no traçado a partir de características medidas de 2002 a 2009, antes de qualquer obra: logaritmo da população, participação da agropecuária, da indústria e da administração pública no valor adicionado, crescimento do PIB no período e área de soja per capita.
- O nível do PIB não entra no modelo. Parear pelo nível da própria variável de resultado pode produzir regressão à média.
- Cada tratado recebe os 3 controles de escore mais próximo, sem reposição, desde que estejam a até 0,25 desvio-padrão do seu escore. Tratados sem controle dentro desse limite ficam sem par.

| Ferrovia | Tratados | Tratados com par | Controles pareados |
|---|---|---|---|
| FIOL I | 18 | 17 | 51 |
| FIOL II | 11 | 5 | 15 |
| FNS-ES | 28 | 28 | 80 |

### 3.4 Como cada estimador usa os controles

- O Callaway & Sant'Anna compara os tratados com os municípios nunca tratados do conjunto e ajusta pelas características pré-obra.
- O Synthetic DiD atribui um peso a cada controle para que a trajetória anterior à obra se pareça com a dos tratados. Nesta base os pesos ficaram muito espalhados: nenhum controle pesa mais que 2,3%.
- O controle sintético clássico foi estimado apenas com os controles pareados como doadores.

### 3.5 Limitações da escolha

- **Soja na Bahia:** nenhum dos 271 controles elegíveis tinha soja de 2002 a 2009, e 6 dos 11 tratados da FIOL II têm. Esses seis municípios do oeste baiano não têm contrafactual comparável dentro da Bahia e são exatamente os que ficaram sem par.
- **Dispersão geográfica na FNS-ES:** os controles vêm de todo o território de Minas Gerais e São Paulo, inclusive de regiões muito diferentes do sudoeste goiano. O pareamento equilibra as características medidas, não a região.
- **Equilíbrio imperfeito:** depois do pareamento, o crescimento pré-obra continuou desequilibrado na FIOL I e na FIOL II. Na FNS-ES o equilíbrio ficou bom.

## 4. Modelos estimados

| Modelo | O que faz | Do que depende |
|---|---|---|
| Diferenças-em-diferenças com efeitos fixos (TWFE) | Compara a variação dos tratados com a dos controles, antes e depois da obra, com efeitos fixos de município e de ano por conjunto de estados | Tendências paralelas sem ajuste |
| Sun & Abraham | Versão do TWFE adequada a datas de início diferentes | Tendências paralelas por coorte |
| Callaway & Sant'Anna | Estima cada ferrovia contra os nunca tratados, com ajuste duplamente robusto pelas características pré-obra; aceita painel incompleto | Tendências paralelas condicionais às características |
| Synthetic DiD | Repondera controles e anos pré-obra para alinhar as trajetórias antes de comparar | Painel completo; depende menos de tendências paralelas |
| Controle sintético com doadores pareados | Constrói um trecho sintético para o resultado somado dos tratados | Bom ajuste pré-obra; mede o agregado, não o município médio |

Em torno desses modelos foram feitas as seguintes checagens:

- **Teste de pré-tendência:** verifica se tratados e controles já divergiam antes da obra.
- **Inferência por randomização:** sorteia falsos tratados 999 vezes para obter um valor-p que não depende de aproximações assintóticas.
- **HonestDiD:** mostra quanta violação das tendências paralelas o resultado suporta.
- **Efeito mínimo detectável:** o menor efeito que o desenho conseguiria enxergar com 80% de poder.
- **Decomposição de Goodman-Bacon:** confirma que 99,8% do TWFE vem de comparações entre tratados e nunca tratados.
- **Datas alternativas e efeitos por fase:** data comum em 2010 ou 2011, FIOL II em 2014, antecipação de um ano e um efeito por janela de obra.

Os erros-padrão são agrupados por município no TWFE, obtidos por bootstrap de municípios (199 réplicas) no Callaway & Sant'Anna e por placebo (200 réplicas) no Synthetic DiD.

## 5. Qual modelo é adequado em cada caso

### 5.1 PIB e PIB per capita: Synthetic DiD como principal

O teste de pré-tendência rejeita tendências paralelas na FIOL I, na FNS-ES e na média conjunta. Isso enfraquece o TWFE e o Callaway & Sant'Anna, que dependem dessa hipótese. O Synthetic DiD corrige a divergência prévia por construção, e o painel do PIB é completo, de modo que ele usa todos os municípios. O Callaway & Sant'Anna entra como confirmação e o TWFE apenas como referência.

Resultado no período principal: o Synthetic DiD estima 0,010 na FIOL I e 0,007 na FNS-ES, ambos indistinguíveis de zero. Não há efeito robusto sobre o PIB nem sobre o PIB per capita.

### 5.2 ISS: Callaway & Sant'Anna como principal

Para o ISS a situação se inverte, por dois motivos:

- O teste de pré-tendência não rejeita tendências paralelas em nenhuma ferrovia (valor-p entre 0,23 e 0,52), de modo que a hipótese do modelo se sustenta.
- O ISS tem muitos anos sem declaração. O Callaway & Sant'Anna aceita painel incompleto e usa todos os municípios; o Synthetic DiD exige série completa e fica com 8 dos 18 tratados da FIOL I, 8 dos 11 da FIOL II e 17 dos 28 da FNS-ES.

O Synthetic DiD e o TWFE servem de confirmação, e confirmam. O Callaway & Sant'Anna estima 0,428 na FIOL I, 0,478 na FIOL II e 0,443 na FNS-ES, e 0,445 na média conjunta, o que equivale a cerca de 56% a mais de arrecadação. O efeito se concentra nas fases de obra: na FIOL I é 0,757 em 2011–2015 e 0,200 em 2016–2019. O controle sintético com doadores pareados não pôde ser estimado, porque não aceita anos faltantes.

### 5.3 FIOL II: o problema é de dados, não de modelo

Faltam controles comparáveis para os municípios de soja. Com todos os controles o PIB parece subir, principalmente depois de 2018; com controles pareados, que deixam 5 tratados, o efeito desaparece no PIB e no ISS. Qualquer resultado dessa ferrovia deve ser apresentado com essa ressalva.

### 5.4 Resumo

| Variável | Modelo principal | Confirmação | Conclusão |
|---|---|---|---|
| PIB real e PIB real per capita | Synthetic DiD | Callaway & Sant'Anna; amostra pareada | Sem efeito robusto |
| ISS real e ISS real per capita | Callaway & Sant'Anna | Synthetic DiD (série completa); TWFE | Efeito grande, concentrado na fase de obra |

## 6. Limitações gerais

- O emprego não foi analisado: a RAIS é distribuída apenas por FTP, que não pôde ser acessado no ambiente em que a análise rodou.
- O poder estatístico é baixo. Efeitos menores que cerca de 15% do PIB, ou cerca de 40% do ISS, não seriam detectados.
- O ISS é o total do município, não apenas o da construção civil.
- No Callaway & Sant'Anna da Bahia, a área de soja saiu das características de ajuste por não variar entre os controles.
- O controle sintético com todos os controles como doadores não foi executado por inviabilidade de tempo de processamento; ficou a versão com doadores pareados.
- Quatro municípios da lista da dissertação (Ilhéus, Populina, Turmalina e Cachoeira Alta) não são cruzados pelo traçado do OpenStreetMap, usado apenas para medir os quilômetros de linha.

## 7. Onde está cada etapa no repositório

| Etapa | Script |
|---|---|
| PIB, população e soja | `baixar_bases_fiol_fns.R` |
| Deflator do PIB | `montar_deflatores.R` |
| ISS municipal de 2002 a 2023 | `baixar_iss_ipeadata.R` |
| Traçado e quilômetros de linha | `tracado_osm.R` |
| Anéis de vizinhança e grupos de controle | `calcular_aneis.R` |
| Pareamento e todos os modelos do PIB | `analise_impacto_ferrovias.R`, `rodar_periodos.R` |
| Synthetic DiD por ano e por fase | `sdid_janelas.R` |
| Mesma análise com o ISS | `rodar_iss.R` |
| Descritiva e painel | `analise_descritiva.R`, `painel/` |
