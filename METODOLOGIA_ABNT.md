# METODOLOGIA: IMPACTO DA FIOL E DA FNS-ES SOBRE OS MUNICÍPIOS INTERCEPTADOS

## 1 VARIÁVEIS DE RESULTADO

A avaliação utiliza três variáveis de resultado, todas observadas por município e por ano entre 2002 e 2023: o Produto Interno Bruto (PIB) real, o PIB real per capita e a arrecadação real do Imposto sobre Serviços de Qualquer Natureza (ISS). As três entram nos modelos em logaritmo natural, de modo que os efeitos estimados se leem como variação percentual aproximada: um coeficiente de 0,05 corresponde a cerca de 5%.

### 1.1 PIB real

O ponto de partida é o PIB dos Municípios, em valores correntes, para os municípios da Bahia, de Goiás, de Minas Gerais e de São Paulo (IBGE, 2026a). Para tornar comparáveis os valores de anos diferentes, cada observação é dividida pelo deflator implícito do PIB nacional, obtido pelo encadeamento das variações anuais das Contas Nacionais e reescalado para 2020 = 100 (IBGE, 2026b). O resultado é o PIB real, em reais de 2020.

### 1.2 PIB real per capita

O PIB real per capita é o PIB real dividido pela população residente. A população anual foi obtida por interpolação geométrica entre os censos demográficos de 2000, 2010 e 2022, com o ano de 2023 extrapolado pela taxa observada entre 2010 e 2022 (IBGE, 2026c). As estimativas populacionais anuais não foram utilizadas porque apresentam descontinuidades nos anos de censo, o que introduziria quebras artificiais na série per capita.

### 1.3 ISS real

A arrecadação municipal do ISS provém da série de receita corrente bruta do imposto, de origem na Secretaria do Tesouro Nacional e disponibilizada pelo Ipeadata (IPEA, 2026). A série foi conferida com os dados das Declarações de Contas Anuais obtidos diretamente no sistema do Tesouro: os valores coincidem em pelo menos 99,9% das observações de 2014 a 2023, com exceção de 2016, em que a coincidência é de 95,7%. O ISS é deflacionado pelo mesmo deflator aplicado ao PIB e analisado em valor total e per capita. Os anos em que o município não apresentou declaração, ou declarou valor nulo, são tratados como observações ausentes.

### 1.4 Diferença entre as medidas

O PIB municipal não resulta de mensuração direta: o valor adicionado de cada atividade econômica do estado é repartido entre os municípios por meio de indicadores. Por essa razão, a medida tende a captar de forma atenuada um choque local e temporário, como a instalação de um canteiro de obras. O ISS, em contraste, é receita efetivamente arrecadada pela prefeitura, e o imposto incidente sobre a construção civil é devido ao município em que a obra é executada. Essa diferença é a interpretação aqui proposta para a divergência entre os resultados obtidos com as duas variáveis; os modelos não a testam diretamente.

## 2 DEFINIÇÃO DO TRATAMENTO

São considerados tratados os municípios interceptados pelo traçado de cada ferrovia: 18 na Ferrovia de Integração Oeste-Leste, trecho I (FIOL I), 11 no trecho II (FIOL II) e 28 na Extensão Sul da Ferrovia Norte-Sul (FNS-ES). O município de Caetité, situado na junção dos dois trechos da FIOL, foi atribuído à FIOL I.

Na ausência de cronograma de execução por município, adotou-se uma data de início por ferrovia: 2011 para a FIOL I e para a FNS-ES, primeiro ano com obra física, e 2013 para a FIOL II, ano do licenciamento dos lotes 5 e 5A. O período principal de análise vai de 2002 a 2019, o que cobre a fase de obra e exclui os anos da pandemia; o período de 2002 a 2023 foi estimado de forma complementar para o PIB. Para examinar a evolução do efeito, cada ferrovia foi dividida em fases de obra, apresentadas no Quadro 1.

Quadro 1 – Fases da obra por ferrovia no período de 2002 a 2019

| Ferrovia | Início do tratamento | Fases |
|---|---|---|
| FIOL I | 2011 | Obra (2011–2015); ritmo baixo (2016–2019) |
| FIOL II | 2013 | Início lento (2013–2017); retomada (2018–2019) |
| FNS-ES | 2011 | Obra sob a Valec (2011–2019) |

Fonte: Elaboração própria.

## 3 ESCOLHA DOS CONTROLES

A definição do grupo de controle foi feita em três etapas. As duas primeiras delimitam os municípios elegíveis; a terceira seleciona, entre eles, os mais semelhantes aos tratados.

### 3.1 Conjunto de estados

Cada ferrovia é comparada apenas com municípios da própria região: a Bahia, no caso da FIOL I e da FIOL II, e o conjunto formado por Goiás, Minas Gerais e São Paulo, no caso da FNS-ES. Os municípios tratados de um trecho não são utilizados como controle de outro.

### 3.2 Distância ao traçado por anéis de vizinhança

A distância ao traçado foi medida em anéis de vizinhança sobre a malha municipal de 2020, obtida por meio do pacote geobr (Pereira; Gonçalves, 2019). Consideram-se vizinhos dois municípios que compartilham ao menos um ponto de fronteira. Os municípios interceptados formam o anel zero; seus vizinhos, o primeiro anel; os vizinhos destes, o segundo anel; e assim sucessivamente.

São elegíveis como controle apenas os municípios situados no terceiro anel ou além. Os dois primeiros anéis são excluídos porque podem receber transbordamento dos efeitos da obra, por deslocamento de trabalhadores e por demanda de comércio e serviços, o que contaminaria a comparação. São excluídos, ainda, os municípios atravessados por outros projetos ferroviários: o trecho III da FIOL, a Transnordestina e o trecho da Ferrovia Norte-Sul ao norte de Ouro Verde de Goiás.

Dessa delimitação resultam 271 controles elegíveis na Bahia e 1.571 no conjunto da FNS-ES. Foram excluídos, por vizinhança, 117 municípios na Bahia e 132 no outro conjunto.

### 3.3 Pareamento por escore de propensão

As estimativas principais empregam todos os controles elegíveis. Como verificação de robustez, cada município tratado foi pareado com controles semelhantes por meio do escore de propensão (Rosenbaum; Rubin, 1983), com o pacote MatchIt (Ho et al., 2011). A probabilidade de pertencer ao traçado foi estimada por um modelo logit com características medidas entre 2002 e 2009, antes de qualquer obra: logaritmo da população, participação da agropecuária, da indústria e da administração pública no valor adicionado, taxa de crescimento do PIB no período e área plantada de soja per capita.

O nível do PIB não foi incluído entre as características, uma vez que parear pelo nível da própria variável de resultado pode produzir regressão à média em estimativas de diferenças em diferenças (Daw; Hatfield, 2018). Cada tratado recebeu os três controles de escore mais próximo, sem reposição, desde que situados a até 0,25 desvio-padrão do logit do seu escore; os tratados sem controle dentro desse limite permaneceram sem par. O resultado do pareamento está na Tabela 1.

Tabela 1 – Resultado do pareamento por escore de propensão

| Ferrovia | Tratados | Tratados com par | Controles pareados |
|---|---|---|---|
| FIOL I | 18 | 17 | 51 |
| FIOL II | 11 | 5 | 15 |
| FNS-ES | 28 | 28 | 80 |

Fonte: Elaboração própria.

### 3.4 Limitações da escolha dos controles

A escolha dos controles apresenta três limitações:

a) nenhum dos 271 controles elegíveis da Bahia cultivava soja entre 2002 e 2009, ao passo que 6 dos 11 municípios tratados da FIOL II cultivavam, de modo que esses seis municípios do oeste baiano não dispõem de contrafactual comparável e são exatamente os que permaneceram sem par;
b) os controles da FNS-ES distribuem-se por todo o território de Minas Gerais e de São Paulo, inclusive por regiões de estrutura produtiva distinta da do sudoeste goiano, e o pareamento equilibra as características medidas, mas não a localização;
c) após o pareamento, a taxa de crescimento anterior à obra permaneceu desequilibrada na FIOL I e na FIOL II, enquanto na FNS-ES o equilíbrio das características foi satisfatório.

## 4 MODELOS ESTIMADOS

A estratégia de identificação baseia-se em diferenças em diferenças, cujos desenvolvimentos recentes são sintetizados por Roth et al. (2023). Foram estimados cinco modelos, descritos a seguir e resumidos no Quadro 2.

### 4.1 Diferenças em diferenças com efeitos fixos

O modelo de efeitos fixos de dois sentidos, conhecido pela sigla TWFE, compara a variação da variável de resultado nos municípios tratados com a variação nos controles, antes e depois do início da obra. A especificação inclui efeitos fixos de município e de ano por conjunto de estados, com erros-padrão agrupados por município, e foi estimada com o pacote fixest (Bergé, 2018). Como as ferrovias têm datas de início diferentes, estimou-se também a versão de Sun e Abraham (2021), adequada a esse caso, e aplicou-se a decomposição de Goodman-Bacon (2021), segundo a qual 99,8% do coeficiente do TWFE provém de comparações entre municípios tratados e nunca tratados.

### 4.2 Callaway e Sant'Anna

O estimador de Callaway e Sant'Anna (2021) calcula o efeito de cada grupo de tratamento em cada ano em relação aos municípios nunca tratados e agrega esses efeitos em uma média posterior ao início da obra e em um estudo de eventos. O ajuste pelas características anteriores à obra é feito pelo método duplamente robusto de Sant'Anna e Zhao (2020). O estimador admite painel incompleto, e os erros-padrão foram obtidos por reamostragem de municípios, com 199 réplicas.

### 4.3 Diferenças em diferenças sintético

O estimador de diferenças em diferenças sintético, ou Synthetic DiD, de Arkhangelsky et al. (2021), atribui pesos aos municípios de controle e aos anos anteriores à obra de modo a aproximar a trajetória dos controles da trajetória dos tratados antes da intervenção. O efeito é obtido por diferenças em diferenças com esses pesos. O método exige painel completo, e os erros-padrão foram calculados por placebo, com 200 réplicas. Além do efeito médio, foram calculados os efeitos de cada ano e de cada fase da obra.

### 4.4 Controle sintético

O método de controle sintético (Abadie; Gardeazabal, 2003; Abadie; Diamond; Hainmueller, 2010) foi aplicado ao resultado somado dos municípios de cada ferrovia, tendo como doadores os controles pareados. A inferência baseia-se na posição da razão entre os erros quadráticos médios posterior e anterior à intervenção da unidade tratada em relação aos placebos. A versão com todos os controles elegíveis como doadores não foi executada por inviabilidade de tempo de processamento.

Quadro 2 – Modelos estimados e hipóteses de identificação

| Modelo | O que faz | Do que depende |
|---|---|---|
| TWFE e Sun e Abraham | Compara a variação de tratados e controles, antes e depois da obra | Tendências paralelas sem ajuste |
| Callaway e Sant'Anna | Estima cada ferrovia contra os nunca tratados, com ajuste por características anteriores à obra; aceita painel incompleto | Tendências paralelas condicionais às características |
| Synthetic DiD | Repondera controles e anos anteriores à obra para alinhar as trajetórias | Painel completo; menor dependência de tendências paralelas |
| Controle sintético | Constrói uma unidade sintética para o resultado somado dos tratados | Bom ajuste anterior à obra; mede o agregado |

Fonte: Elaboração própria.

### 4.5 Verificações de robustez

Os modelos foram acompanhados das seguintes verificações:

a) teste de pré-tendência, que avalia se tratados e controles já divergiam antes da obra;
b) inferência por randomização, com 999 sorteios de municípios falsamente tratados, que fornece um valor-p independente de aproximações assintóticas (Imbens; Rubin, 2015);
c) análise de sensibilidade de Rambachan e Roth (2023), que indica o grau de violação das tendências paralelas que o resultado suporta;
d) efeito mínimo detectável, calculado por placebo entre os controles, que corresponde ao menor efeito identificável com poder de 80%;
e) datas alternativas de início do tratamento e antecipação de um ano;
f) reestimação de todos os modelos na amostra de controles pareados.

## 5 ADEQUAÇÃO DOS MODELOS A CADA VARIÁVEL

### 5.1 PIB e PIB per capita

Para o PIB, o teste de pré-tendência rejeita a hipótese de tendências paralelas na FIOL I, na FNS-ES e na média das três ferrovias. Esse resultado enfraquece o TWFE e o estimador de Callaway e Sant'Anna (2021), que dependem dessa hipótese. O Synthetic DiD corrige a divergência anterior à obra por construção, e o painel do PIB é completo, de modo que o método utiliza todos os municípios. Por essas razões, o Synthetic DiD é adotado como modelo principal para o PIB, com o estimador de Callaway e Sant'Anna como confirmação e o TWFE apenas como referência.

No período principal, o Synthetic DiD estima efeitos de 0,010 na FIOL I e de 0,007 na FNS-ES, ambos estatisticamente indistinguíveis de zero. Não se identifica efeito robusto da obra sobre o PIB ou sobre o PIB per capita.

### 5.2 ISS

Para o ISS, a situação se inverte, por duas razões. Em primeiro lugar, o teste de pré-tendência não rejeita a hipótese de tendências paralelas em nenhuma ferrovia, com valores-p entre 0,23 e 0,52, de modo que a hipótese do estimador de Callaway e Sant'Anna (2021) se sustenta. Em segundo lugar, a série do ISS apresenta muitos anos sem declaração: esse estimador admite painel incompleto e utiliza todos os municípios, ao passo que o Synthetic DiD exige série completa e se restringe a 8 dos 18 tratados da FIOL I, a 8 dos 11 da FIOL II e a 17 dos 28 da FNS-ES.

O estimador de Callaway e Sant'Anna é, portanto, adotado como modelo principal para o ISS, com o Synthetic DiD e o TWFE como confirmação. O efeito estimado é de 0,428 na FIOL I, de 0,478 na FIOL II e de 0,443 na FNS-ES, com média de 0,445, o que corresponde a um acréscimo de cerca de 56% na arrecadação. O efeito concentra-se nas fases de obra: na FIOL I, é de 0,757 entre 2011 e 2015 e de 0,200 entre 2016 e 2019. O controle sintético com doadores pareados não pôde ser estimado para o ISS, por não admitir anos faltantes.

### 5.3 FIOL II

Na FIOL II, a dificuldade decorre dos dados, e não do modelo: faltam controles comparáveis para os municípios produtores de soja. Com todos os controles elegíveis, o PIB parece crescer, sobretudo a partir de 2018; com os controles pareados, que preservam cinco municípios tratados, o efeito desaparece tanto no PIB quanto no ISS. Os resultados dessa ferrovia devem ser apresentados com essa ressalva. A síntese da adequação dos modelos encontra-se no Quadro 3.

Quadro 3 – Modelo principal e conclusão por variável de resultado

| Variável | Modelo principal | Confirmação | Conclusão |
|---|---|---|---|
| PIB real e PIB real per capita | Synthetic DiD | Callaway e Sant'Anna; amostra pareada | Sem efeito robusto |
| ISS real e ISS real per capita | Callaway e Sant'Anna | Synthetic DiD; TWFE | Efeito elevado, concentrado na fase de obra |

Fonte: Elaboração própria.

## 6 LIMITAÇÕES

A análise apresenta as seguintes limitações gerais:

a) o emprego não foi analisado, porque os microdados da Relação Anual de Informações Sociais não puderam ser obtidos no ambiente em que a análise foi executada;
b) o poder estatístico é reduzido, de modo que efeitos inferiores a cerca de 15% do PIB ou a cerca de 40% do ISS não seriam detectados;
c) o ISS corresponde à arrecadação total do município, e não apenas à parcela da construção civil;
d) no estimador de Callaway e Sant'Anna aplicado à Bahia, a área de soja foi retirada das características de ajuste por não variar entre os controles;
e) quatro municípios da lista de tratados (Ilhéus, Populina, Turmalina e Cachoeira Alta) não são atravessados pelo traçado disponível no OpenStreetMap, utilizado apenas para medir a extensão de linha em cada município (OpenStreetMap, 2026).

## REFERÊNCIAS

ABADIE, Alberto; DIAMOND, Alexis; HAINMUELLER, Jens. Synthetic control methods for comparative case studies: estimating the effect of California's tobacco control program. **Journal of the American Statistical Association**, v. 105, n. 490, p. 493-505, 2010.

ABADIE, Alberto; GARDEAZABAL, Javier. The economic costs of conflict: a case study of the Basque Country. **American Economic Review**, v. 93, n. 1, p. 113-132, 2003.

ARKHANGELSKY, Dmitry; ATHEY, Susan; HIRSHBERG, David A.; IMBENS, Guido W.; WAGER, Stefan. Synthetic difference-in-differences. **American Economic Review**, v. 111, n. 12, p. 4088-4118, 2021.

BERGÉ, Laurent. Efficient estimation of maximum likelihood models with multiple fixed-effects: the R package FENmlm. **CREA Discussion Papers**, Luxembourg, n. 13, 2018.

CALLAWAY, Brantly; SANT'ANNA, Pedro H. C. Difference-in-differences with multiple time periods. **Journal of Econometrics**, v. 225, n. 2, p. 200-230, 2021.

DAW, Jamie R.; HATFIELD, Laura A. Matching and regression to the mean in difference-in-differences analysis. **Health Services Research**, v. 53, n. 6, p. 4138-4156, 2018.

GOODMAN-BACON, Andrew. Difference-in-differences with variation in treatment timing. **Journal of Econometrics**, v. 225, n. 2, p. 254-277, 2021.

HO, Daniel E.; IMAI, Kosuke; KING, Gary; STUART, Elizabeth A. MatchIt: nonparametric preprocessing for parametric causal inference. **Journal of Statistical Software**, v. 42, n. 8, p. 1-28, 2011.

IBGE. **Produto Interno Bruto dos Municípios**: tabela 5938. Rio de Janeiro: IBGE, 2026a. Disponível em: https://sidra.ibge.gov.br/tabela/5938. Acesso em: 22 nov. 2026.

IBGE. **Sistema de Contas Nacionais**: tabela 6784. Rio de Janeiro: IBGE, 2026b. Disponível em: https://sidra.ibge.gov.br/tabela/6784. Acesso em: 22 nov. 2026.

IBGE. **Censo Demográfico**: tabelas 202 e 9514. Rio de Janeiro: IBGE, 2026c. Disponível em: https://sidra.ibge.gov.br. Acesso em: 22 nov. 2026.

IMBENS, Guido W.; RUBIN, Donald B. **Causal inference for statistics, social, and biomedical sciences**: an introduction. New York: Cambridge University Press, 2015.

IPEA. **Ipeadata**: receita corrente, receita bruta, impostos, taxas e contribuições de melhoria, ISS municipal (série RISSM). Brasília, DF: Ipea, 2026. Disponível em: http://www.ipeadata.gov.br. Acesso em: 23 nov. 2026.

OPENSTREETMAP. **OpenStreetMap**: dados geográficos abertos. [*S. l.*]: OpenStreetMap Foundation, 2026. Disponível em: https://www.openstreetmap.org. Acesso em: 22 nov. 2026.

PEREIRA, Rafael H. M.; GONÇALVES, Caio Nogueira. **geobr**: download official spatial data sets of Brazil. Brasília, DF: Ipea, 2019. Disponível em: https://github.com/ipeaGIT/geobr. Acesso em: 22 nov. 2026.

RAMBACHAN, Ashesh; ROTH, Jonathan. A more credible approach to parallel trends. **Review of Economic Studies**, v. 90, n. 5, p. 2555-2591, 2023.

ROSENBAUM, Paul R.; RUBIN, Donald B. The central role of the propensity score in observational studies for causal effects. **Biometrika**, v. 70, n. 1, p. 41-55, 1983.

ROTH, Jonathan; SANT'ANNA, Pedro H. C.; BILINSKI, Alyssa; POE, John. What's trending in difference-in-differences? A synthesis of the recent econometrics literature. **Journal of Econometrics**, v. 235, n. 2, p. 2218-2244, 2023.

SANT'ANNA, Pedro H. C.; ZHAO, Jun. Doubly robust difference-in-differences estimators. **Journal of Econometrics**, v. 219, n. 1, p. 101-122, 2020.

SUN, Liyang; ABRAHAM, Sarah. Estimating dynamic treatment effects in event studies with heterogeneous treatment effects. **Journal of Econometrics**, v. 225, n. 2, p. 175-199, 2021.
