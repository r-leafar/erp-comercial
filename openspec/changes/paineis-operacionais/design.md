# Design: paineis-operacionais

## Context

`observabilidade` deixou pronto o Grafana com as três fontes de dados
(Tempo/Mimir/Loki) e o Alloy com o mecanismo de descoberta de métrica de
infraestrutura por anotação `prometheus.io/scrape` (ver proposal.md). Nada
aqui muda esse receptor; esta change só adiciona consumidores (painéis) e
duas fontes de métrica que faltavam.

Restrição que molda o desenho: o ambiente de desenvolvimento é
deliberadamente enxuto (1 réplica por componente, sem HA, sem múltiplos
nós) -- um painel comunitário genérico, pensado para um cluster de produção
com várias réplicas, mostra painéis vazios ou enganosos aqui (ex.: gráfico
de "réplicas do Postgres" quando só existe uma instância).

## Goals / Non-Goals

**Goals**

- Painel utilizável no dia a dia sem consulta manual, para host, Kubernetes
  e Postgres.
- Provisionamento declarativo, sobrevivendo a recriação do ambiente (mesmo
  padrão de `datasources.yaml`).
- Nenhum painel vazio por métrica ausente -- toda métrica que um painel
  espera precisa estar de fato sendo coletada.

**Non-Goals**

- Alertas, SLOs, painel de negócio -- ver proposal.md.
- Editor de painel dentro do Grafana (persistência de edição feita pelo
  operador) -- os painéis são só lidos, a fonte de verdade é o arquivo
  versionado.

## Decisions

### D1. Painéis comunitários para host e Postgres; painel próprio para Kubernetes

**Decisão.** Importar o painel oficial do node-exporter (ID 1860,
grafana.com) para saúde de host, e o painel oficial do CNPG (ID 20417,
`github.com/cloudnative-pg/grafana-dashboards`) para saúde do Postgres.
Construir um painel próprio para saúde de pod/workload, combinando estado
declarado (`kube-state-metrics`) e consumo real (`cAdvisor`, D5) no mesmo
painel.

**Por que os dois primeiros são seguros para importar.** Ambos são mantidos
pelo mesmo projeto que produz o exporter que os alimenta (node-exporter e
CNPG, respectivamente) -- os nomes de métrica são garantidos bater, e o
escopo de cada painel (um host, um cluster Postgres) não pressupõe
múltiplas réplicas de outra coisa. Risco residual: algum painel individual
dentro do dashboard pode ficar vazio se uma métrica opcional não estiver
habilitada; aceitável, não é falha, é ruído visual (ver "Risco assumido e
registrado" na proposta).

**Por que o terceiro não é importado, mesmo com cAdvisor agora no escopo.**
Painéis comunitários de "Kubernetes cluster health" (os populares do
ecossistema kube-prometheus-stack) assumem convenções de rótulo (`cluster`,
`node` multi-valor, `namespace` como filtro de topo) pensadas para um
cluster de produção com vários nós -- aqui teriam variáveis de filtro com
um único valor sempre repetido, e painéis pensados para comparar N nós
mostrando sempre o mesmo no. Ter cAdvisor disponível resolve a fonte de
dado que faltava, não o descompasso de forma -- um painel pequeno, com as
variáveis certas para um cluster de um nó, continua mais direto de manter.

**Alternativa recusada.** Importar um dashboard grande de
kube-prometheus-stack e aceitar os painéis com variável de filtro
redundante. Rejeitada: o objetivo declarado ("ver rápido se algo está
ruim") piora com ruído, não melhora.

### D2. `kube-state-metrics` como componente novo, mesmo padrão de scrape já estabelecido

**Decisão.** Adicionar `kube-state-metrics` como mais um Deployment com a
mesma anotação `prometheus.io/scrape` que cert-manager/Tempo/Mimir/Loki/
node-exporter já usam -- nenhum mecanismo de coleta novo, só mais um alvo
descoberto pelo `discovery.kubernetes` que o Alloy já roda.

**RBAC.** `kube-state-metrics` precisa de leitura cluster-wide (list/watch)
de praticamente todo tipo de objeto do Kubernetes para expor seu estado --
igual a qualquer instalação padrão dele; nenhuma permissão de escrita.

### D3. Anotação de scrape do Postgres via `inheritedMetadata` do CNPG

**Decisão.** Usar `spec.inheritedMetadata.annotations` no `Cluster` do
CNPG (mecanismo documentado do próprio operador para propagar anotação a
todo pod gerado) para adicionar `prometheus.io/scrape: "true"` e
`prometheus.io/port: "9187"`, em vez de qualquer configuração no lado do
Alloy.

**Consequência que evita.** Um exporter que já existe (porta 9187, embutido
em todo pod do Cluster desde a versão do CNPG já em uso) permanecendo
invisível para sempre por falta de uma anotação -- não é um componente
novo, é uma linha em um recurso já existente.

**Nota de escopo.** `cluster.yaml` pertence ao repositório da change
`plataforma-gitops`, já concluída e arquivada. A edição é mínima (duas
linhas de metadata) e não muda nenhum requisito daquela change -- mesmo
espírito de "esta change apenas consome" já usado por `observabilidade`
em relação a `plataforma-gitops`.

### D4. Provisionamento de painel por arquivo, sem sidecar

**Decisão.** Cada dashboard (JSON) vira uma chave de um ConfigMap montado
em `/etc/grafana/provisioning/dashboards/`, com um arquivo de configuração
do provedor (`dashboards.yaml`) apontando para essa pasta -- mesmo
mecanismo já usado por `grafana/datasources.yaml`, sem container adicional.

**Alternativa recusada.** O padrão de sidecar do kube-prometheus-stack (um
container que observa ConfigMaps com um rótulo e busca o dashboard
dinamicamente via API do Grafana). Rejeitada: adiciona um processo e uma
superfície de RBAC novos só para reproduzir o que o mecanismo de
provisionamento por arquivo, já em uso, já faz.

### D5. cAdvisor raspado via descoberta de nó, nao pela convencao de anotacao

**Decisao.** Diferente de todo alvo de scrape ja existente
(cert-manager/Tempo/Mimir/Loki/node-exporter/kube-state-metrics, todos via
`discovery.kubernetes` com `role: pod` + filtro por anotacao
`prometheus.io/scrape`), o cAdvisor exige um mecanismo proprio: ele nao e
um pod que se descobre normalmente, e sim um endpoint embutido no proprio
kubelet, exposto em `https://<endereco-do-no>:10250/metrics/cadvisor`.
Usar `discovery.kubernetes` com `role: node` (um alvo por NO, nao por pod)
e um `prometheus.scrape` apontando para esse caminho, com
`bearer_token_file` (o token do proprio ServiceAccount do Alloy, montado
por padrao em todo pod) e `tls_config.insecure_skip_verify: true` (o
certificado do kubelet nao e assinado por uma CA que o Alloy reconheca por
padrao).

**RBAC adicional, o unico desta change que nao e so leitura de objeto.**
O ClusterRole do Alloy (ja existente, de `observabilidade`) precisa de mais
duas entradas: `resources: ["nodes/metrics", "nodes/proxy"]`, `verbs:
["get"]` -- autorizacao para o token do Alloy chamar a API do kubelet, nao
so listar objetos do apiserver. Mesma superficie que qualquer instalacao
padrao de kube-prometheus-stack pede para o mesmo fim.

**Por que nao e so mais uma anotacao.** As outras fontes desta change
(kube-state-metrics, exporter do Postgres) reaproveitam 100% o mecanismo
que `observabilidade` ja construiu -- descoberta por pod, filtro por
anotacao, sem RBAC novo. O cAdvisor e o unico caso desta change com um
caminho de coleta genuinamente novo (por no, autenticado contra o
kubelet), e fica registrado como tal para nao passar a impressao de que
"e so mais um scrape igual aos outros".

## Risks / Trade-offs

| Risco | Impacto | Mitigação |
|---|---|---|
| Painel importado com campo vazio por métrica opcional ausente | Ruído visual, não falha funcional | Documentado por painel na tarefa de importação; confirmado ao vivo antes de fechar a tarefa |
| `kube-state-metrics` some do escopo de RBAC em uma versão futura do Kubernetes | Painel de saúde de pod para de atualizar | Mesmo risco de qualquer instalação padrão; não específico desta change |
| Editar `cluster.yaml` de uma change já arquivada | Acoplamento entre changes | Edição mínima (metadata), sem mudança de requisito; mesmo padrão já aceito em `observabilidade` (anotações no MinIO de `plataforma-gitops`) |
| Certificado do kubelet não confiável por padrão, exigindo `insecure_skip_verify` | Canal de scrape sem verificação de identidade do servidor | Mesmo risco aceito por qualquer instalação padrão de kube-prometheus-stack contra o kubelet; tráfego interno ao cluster, não exposto externamente |
| RBAC do Alloy ganha permissão de leitura contra a API do kubelet (`nodes/metrics`, `nodes/proxy`), não só contra o apiserver | Superfície de permissão maior que a de qualquer alvo anterior desta plataforma | Somente leitura (`get`), sem escrita; registrado explicitamente em D5 para não passar despercebido |

## Migration Plan

Aditivo, sem remoção: `kube-state-metrics` e os painéis são recursos novos;
a única edição em recurso existente é a anotação no `Cluster` do CNPG
(`kubectl apply`/reconciliação do ArgoCD, sem reinício disruptivo do
Postgres -- anotação de pod não dispara rollout do CNPG). Reversível
removendo os recursos novos e a anotação.
