## Purpose

Oferece um ponto unico de recepcao para rastros, metricas e logs, enriquecendo
cada registro com a identidade de sua origem no cluster e isolando quem emite de
qualquer falha do caminho de telemetria.

## ADDED Requirements

### Requirement: Ponto unico de recepcao para os tres sinais

A plataforma SHALL oferecer um unico endereco de ingestao que aceite rastros,
metricas e logs pelo mesmo protocolo. Quem emite MUST NOT precisar conhecer o
armazenamento de destino de cada sinal.

#### Scenario: Os tres sinais sao aceitos no mesmo endereco

- **WHEN** um emissor envia rastros, metricas e logs ao endereco de ingestao
- **THEN** os tres sao aceitos e encaminhados ao armazenamento correspondente

#### Scenario: Emissor desconhece o destino

- **WHEN** o armazenamento de um sinal e substituido ou reconfigurado
- **THEN** nenhuma alteracao e necessaria em quem emite

### Requirement: Enriquecimento com identidade de origem

Todo registro recebido SHALL ser enriquecido, no momento da ingestao, com
atributos que identifiquem sua origem no cluster. Esses atributos MUST ser
derivados do ambiente de execucao, e nao informados por quem emite.

#### Scenario: Origem identificavel sem cooperacao do emissor

- **WHEN** um registro chega sem qualquer atributo de identificacao de origem
- **THEN** os atributos de origem sao acrescentados antes do encaminhamento

#### Scenario: Atributo informado pelo emissor nao substitui o derivado

- **WHEN** um emissor declara atributos de origem divergentes do ambiente real
- **THEN** prevalece a identificacao derivada do ambiente

### Requirement: Isolamento entre telemetria e quem a emite

Falha, lentidao ou indisponibilidade do caminho de telemetria MUST NOT causar
falha, bloqueio ou degradacao funcional em quem emite. Perder telemetria SHALL
ser sempre preferivel a afetar a operacao observada.

#### Scenario: Destino indisponivel nao interrompe o emissor

- **WHEN** o armazenamento de destino fica indisponivel
- **THEN** as operacoes de quem emite continuam normalmente, e a perda de
  telemetria e observavel

#### Scenario: Acumulo nao cresce sem limite

- **WHEN** a ingestao recebe mais registros do que consegue encaminhar por um
  periodo prolongado
- **THEN** o acumulo e limitado e o excedente e descartado de forma controlada e
  contabilizada, em vez de consumir memoria indefinidamente

#### Scenario: Descarte e contabilizado

- **WHEN** registros sao descartados por qualquer motivo
- **THEN** a quantidade descartada fica disponivel como metrica, para que a perda
  nunca seja silenciosa

### Requirement: Coleta de metricas dos componentes de infraestrutura

O ponto de ingestao SHALL tambem coletar metricas expostas pelos componentes de
infraestrutura da plataforma, encaminhando-as ao mesmo armazenamento das metricas
recebidas por envio.

#### Scenario: Metricas de infraestrutura chegam ao mesmo armazenamento

- **WHEN** um componente de infraestrutura expoe suas metricas
- **THEN** elas sao coletadas e ficam disponiveis para consulta junto das demais

#### Scenario: Componente indisponivel nao interrompe a coleta dos outros

- **WHEN** um componente monitorado fica indisponivel
- **THEN** a coleta dos demais prossegue, e a indisponibilidade e observavel como
  metrica

### Requirement: Convencoes estaveis de nomeacao de atributos

Os atributos que descrevem operacoes de mensageria SHALL seguir convencao
publica e estavel, independente da tecnologia de transporte utilizada.

#### Scenario: Troca de transporte nao invalida consultas

- **WHEN** o mecanismo de transporte de mensagens e substituido por outro
- **THEN** apenas o valor que identifica o sistema de mensageria muda, e as
  consultas e paineis existentes continuam validos
