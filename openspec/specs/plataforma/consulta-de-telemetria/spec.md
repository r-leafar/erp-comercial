# consulta-de-telemetria Specification

## Purpose

Torna os tres sinais consultaveis em um unico lugar e correlacionados entre si,
para que uma investigacao possa partir de um rastro e alcancar os logs e as
metricas daquela mesma execucao sem reconstrucao manual.

## Requirements

### Requirement: Os tres sinais consultaveis em um unico lugar

Rastros, metricas e logs SHALL estar disponiveis para consulta por uma interface
unica, com as fontes de dados provisionadas de forma declarativa e versionada.

#### Scenario: Consulta aos tres sinais sem configuracao manual

- **WHEN** a interface de consulta e acessada apos o bootstrap
- **THEN** as fontes dos tres sinais ja estao configuradas e respondem

#### Scenario: Configuracao de consulta sobrevive a recriacao

- **WHEN** o ambiente e recriado do zero
- **THEN** as fontes de dados voltam configuradas, sem intervencao

### Requirement: Correlacao a partir do identificador de rastro

A partir de um rastro exibido, SHALL ser possivel alcancar os logs emitidos
durante aquela execucao, sem que o operador precise construir a consulta
manualmente.

#### Scenario: De um rastro para os logs correspondentes

- **WHEN** um rastro e aberto na interface de consulta
- **THEN** existe navegacao direta para os logs que carregam o mesmo
  identificador de rastro

#### Scenario: De um log para o rastro que o originou

- **WHEN** um log que carrega identificador de rastro e exibido
- **THEN** existe navegacao direta para o rastro correspondente

#### Scenario: Correlacao temporal com metricas

- **WHEN** se investiga um rastro ocorrido em determinado instante
- **THEN** e possivel observar as metricas do mesmo periodo sem sair da
  investigacao

### Requirement: Rastro continuo atraves de fronteira assincrona

Quando o contexto de rastreamento e propagado atraves de uma fronteira
assincrona, a consulta SHALL apresentar produtor e consumidor como parte de um
unico rastro, e nao como rastros independentes.

#### Scenario: Producao e consumo aparecem no mesmo rastro

- **WHEN** uma operacao publica uma mensagem e outra a consome posteriormente,
  com o contexto propagado
- **THEN** ambas aparecem sob o mesmo identificador de rastro, com a relacao
  entre elas visivel

#### Scenario: Ausencia de propagacao e identificavel

- **WHEN** o contexto nao e propagado atraves da fronteira
- **THEN** o consumo aparece como rastro independente, tornando a falha de
  propagacao detectavel na propria consulta

### Requirement: Janela de consulta corresponde a janela de retencao

A interface SHALL permitir consultar qualquer instante dentro da janela de
retencao declarada, e MUST informar de forma compreensivel quando o periodo
solicitado esta fora dela.

#### Scenario: Consulta dentro da janela retorna dado

- **WHEN** se consulta um periodo contido na janela de retencao
- **THEN** o dado correspondente e retornado

#### Scenario: Consulta fora da janela e explicada

- **WHEN** se consulta um periodo anterior a janela de retencao
- **THEN** a ausencia de resultado e apresentada como consequencia da retencao, e
  nao como ausencia de atividade

### Requirement: Verificacao independente da aplicacao

A capacidade de consulta SHALL ser verificavel por meio de telemetria sintetica,
sem depender da existencia de uma aplicacao instrumentada.

#### Scenario: Telemetria sintetica comprova o caminho completo

- **WHEN** um emissor sintetico envia os tres sinais, incluindo um rastro que
  atravessa fronteira assincrona simulada
- **THEN** todos aparecem na consulta, correlacionados, comprovando ingestao,
  armazenamento e consulta sem que exista aplicacao
