## Purpose

Torna a saúde operacional da própria plataforma (host, objetos do
Kubernetes, Postgres) visível de relance, sem exigir consulta manual em
PromQL ou LogQL a cada vez que se quer saber se algo está saudável.

## ADDED Requirements

### Requirement: Painéis provisionados de forma declarativa

Os painéis operacionais SHALL estar disponíveis na interface de consulta
imediatamente após o bootstrap, sem passo manual de importação ou clique.

#### Scenario: Painéis presentes sem intervenção manual

- **WHEN** a interface de consulta é acessada após o bootstrap
- **THEN** os painéis de saúde de host, Kubernetes e Postgres já estão
  presentes e respondem

#### Scenario: Painéis sobrevivem a recriação do ambiente

- **WHEN** o ambiente é recriado do zero
- **THEN** os painéis voltam presentes, sem reimportação manual

### Requirement: Saúde do host visível

Um painel SHALL exibir o consumo de CPU, memória e espaço em disco de cada
nó do cluster.

#### Scenario: Consumo do host visível

- **WHEN** o painel de saúde do host é aberto
- **THEN** CPU, memória e espaço em disco disponível do nó aparecem
  atualizados

### Requirement: Saúde de objetos do Kubernetes visível

Um painel SHALL exibir o estado de pods e workloads (reinícios, réplicas
esperadas vs. prontas, pods fora de `Running`), derivado de métrica de
estado de objeto do Kubernetes, não de inspeção manual.

#### Scenario: Reinício em loop é visível

- **WHEN** um pod reinicia repetidamente
- **THEN** a contagem de reinícios aparece no painel, sem precisar
  inspecionar o pod individualmente

#### Scenario: Réplicas incompletas são visíveis

- **WHEN** um workload tem menos réplicas prontas do que declaradas
- **THEN** essa divergência aparece no painel

### Requirement: Consumo real por contêiner visível

Um painel SHALL exibir o consumo real de CPU e memória de cada contêiner,
derivado de métrica de uso efetivo (não de valor pedido ou limitado),
lado a lado com o estado declarado do mesmo pod.

#### Scenario: Consumo real distinto do valor pedido

- **WHEN** um contêiner consome CPU ou memória de forma diferente do que
  foi pedido/limitado em seu manifesto
- **THEN** o painel mostra o valor real consumido, não o valor declarado

#### Scenario: Consumo real e estado declarado no mesmo painel

- **WHEN** o painel de saúde de pod/workload é aberto
- **THEN** o consumo real por contêiner aparece ao lado do estado
  declarado do mesmo pod (reinícios, fase), sem precisar trocar de painel

### Requirement: Saúde do Postgres visível

Um painel SHALL exibir o estado operacional do cluster Postgres (conexões,
replicação, taxa de transação), a partir do exporter que o próprio CNPG já
expõe.

#### Scenario: Estado do Postgres visível sem consulta manual

- **WHEN** o painel de saúde do Postgres é aberto
- **THEN** conexões ativas, estado de replicação e taxa de transação
  aparecem sem necessidade de consulta SQL ou PromQL manual
