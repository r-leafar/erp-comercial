## Why

A change `observabilidade` entregou o receptor completo de telemetria (Tempo,
Mimir, Loki, Alloy) e o Grafana com as fontes de dados provisionadas, mas
deliberadamente sem nenhum painel -- o non-goal daquela change era "painéis
de negócio", justificado por não existir aplicação ainda para ter métrica de
negócio. Isso deixou uma lacuna diferente, que não depende da aplicação
existir: hoje não há como olhar a saúde operacional da própria plataforma
(cluster, pods, Postgres) sem escrever consulta PromQL/LogQL manual a cada
vez. As métricas em boa parte já existem (node-exporter, scrape de infra);
falta o painel que as torna consultáveis de relance, e faltam duas fontes
específicas (estado de objeto do Kubernetes, e o exporter que o Postgres já
expõe mas não é raspado).

## What Changes

- **Métrica de estado de objeto do Kubernetes** (`kube-state-metrics`):
  hoje não há como ver, como métrica, se um pod está reiniciando em loop, um
  Deployment está com réplicas incompletas, etc. -- só é possível inspecionar
  via `kubectl describe`.
- **Raspagem do exporter do Postgres**: o CNPG já expõe um exporter
  Prometheus embutido (porta 9187) em cada pod do Cluster, mas ele não tem a
  anotação `prometheus.io/scrape` que o Alloy usa para descoberta -- o dado
  já existe, só não é coletado.
- **Painéis provisionados declarativamente no Grafana**, mesma forma como as
  fontes de dados já são (arquivo versionado, sem clique manual):
  - Saúde do host (CPU, memória, disco) -- reaproveita o `node-exporter` já
    existente.
  - Saúde do Postgres -- painel oficial do próprio projeto CNPG, mantido
    para o exato conjunto de métricas que ele expõe.
  - Saúde de pod/workload (reinícios, réplicas, pods presos) -- construído
    sob medida para este ambiente (D1 do design explica por quê, não um
    painel comunitário genérico).

### Non-goals

- **Painéis de negócio ou de aplicação.** Mesmo non-goal de `observabilidade`,
  inalterado -- ainda não existe aplicação.
- **Alertas e notificação.** Mesmo non-goal de `observabilidade`. Um painel
  mostra estado; uma regra de alerta decide quando isso vira ação -- decisão
  adiada para quando houver sinal real de produção.
- **Objetivos de nível de serviço.** Mesma razão.
- **cAdvisor / métrica de uso real por contêiner.** Complementaria o
  `kube-state-metrics` (que só dá o estado declarado, não o consumo real),
  mas exige raspagem via API do kubelet, um mecanismo diferente do usado
  hoje. Registrado como opção futura, não como escopo.

## Capabilities

### New Capabilities

- `plataforma/paineis-operacionais`: painéis provisionados declarativamente
  no Grafana para a saúde operacional da plataforma (host, Kubernetes,
  Postgres), e as duas fontes de métrica que faltavam para torná-los
  possíveis.

### Modified Capabilities

Nenhuma. As capacidades de `observabilidade` (ingestão, retenção, consulta)
continuam valendo sem alteração; esta change apenas adiciona um consumidor
(painéis) e duas fontes de métrica sobre a infraestrutura já existente.

## Impact

**Depende de**

`observabilidade` completa: o Grafana com fonte de dados do Mimir já
provisionada, e o Alloy com o mecanismo de descoberta por anotação
`prometheus.io/scrape` já estabelecido.

**Novo no repositório**

- `deploy/base/observabilidade/kube-state-metrics/` (componente novo).
- Anotação `prometheus.io/scrape` no Postgres via
  `spec.inheritedMetadata.annotations` do `Cluster` do CNPG (mecanismo
  documentado do próprio CNPG para propagar anotação a todos os pods
  gerados) -- edição pequena em `deploy/base/plataforma/postgres/cluster.yaml`,
  de um repositório que pertence à change `plataforma-gitops`, já concluída
  e arquivada.
- Painéis do Grafana provisionados via ConfigMap (mesmo mecanismo de
  `grafana/datasources.yaml`).

**Risco assumido e registrado**

Painel comunitário importado (host, Postgres) pode ter campo vazio se este
ambiente não expuser alguma métrica que o painel espera -- ruído visual, não
falha funcional. Documentado por painel na tarefa de importação.
