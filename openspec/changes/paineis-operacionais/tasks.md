# Tarefas: paineis-operacionais

Depende de `observabilidade` concluida. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

## 1. kube-state-metrics

- [x] 1.1 Declarar `kube-state-metrics` em `deploy/base/observabilidade/`,
      com RBAC de leitura cluster-wide (list/watch, sem escrita). Fixar a
      versao. Feito: `kube-state-metrics/` (v2.20.0). **Achado real**: sem
      restringir, o binario tenta observar por padrao um conjunto maior de
      tipos (secrets, endpointslices, CSRs, webhook/admission configs,
      volumeattachments) do que o RBAC concedido cobre -- processo
      continua saudavel (erro por coletor, isolado), mas decidido
      deliberadamente NAO conceder `list` de secrets cluster-wide so para
      uma metrica de contagem nao usada. Corrigido com `--resources=...`
      explicito, restringindo aos mesmos tipos do RBAC.
- [x] 1.2 Adicionar a anotacao `prometheus.io/scrape` no pod, mesma
      convencao ja usada por cert-manager/Tempo/Mimir/Loki/node-exporter.
      Feito, porta 8080.
- [x] 1.3 Confirmar ao vivo que as metricas `kube_pod_status_phase` e
      `kube_pod_container_status_restarts_total` chegam ao Mimir via
      consulta direta. Confirmado: 155 e 32 series respectivamente.

## 2. cAdvisor (consumo real por contêiner)

- [x] 2.1 Configurar `discovery.kubernetes` com `role: node` no Alloy
      (mecanismo diferente do scrape por anotacao ja usado pelas demais
      fontes -- D5 do design). Feito, `discovery.kubernetes "nodes"`.
- [x] 2.2 Configurar `prometheus.scrape` apontando para
      `https://<endereco-do-no>:10250/metrics/cadvisor`, com
      `bearer_token_file` (token do ServiceAccount do Alloy) e
      `tls_config.insecure_skip_verify: true`. Feito: endereco default do
      role node ja e `<ip-do-no>:10250`; so o `__metrics_path__` precisou
      de override via `discovery.relabel`.
- [x] 2.3 Adicionar ao ClusterRole do Alloy as permissoes `get` em
      `nodes/metrics` e `nodes/proxy` (unico RBAC desta change que nao e
      list/watch de objeto -- D5 do design). Feito.
- [x] 2.4 Confirmar ao vivo que `container_cpu_usage_seconds_total` e
      `container_memory_working_set_bytes` chegam ao Mimir, com valor
      real (nao zero) para um contêiner conhecido. Confirmado: 90 series
      cada, valores reais (ex. `alloy`=69398528 bytes,
      `argocd-application-controller`=227659776 bytes).

## 3. Raspagem do exporter do Postgres

- [x] 3.1 Adicionar `prometheus.io/scrape` e `prometheus.io/port: "9187"`
      via `spec.inheritedMetadata.annotations` no `Cluster` do CNPG
      (`deploy/base/plataforma/postgres/cluster.yaml`). Feito.
- [x] 3.2 Confirmar ao vivo que o pod do Postgres recebeu a anotacao
      (`kubectl get pod -o jsonpath`) sem reinicio do banco. Confirmado:
      anotacao presente, pod com a mesma idade/contagem de reinicio de
      antes (anotacao e patch em objeto vivo, nao dispara rollout).
- [x] 3.3 Confirmar ao vivo que uma metrica do exporter do CNPG chega ao
      Mimir. **Correcao**: o nome usado no rascunho da tarefa
      (`cnpg_pg_stat_database_numbackends`) nao existe nesta versao do
      exporter -- o real e `cnpg_backends_total`. Confirmado consultavel
      no Mimir com valor real (1 conexao ativa de
      `cnpg_metrics_exporter`).

## 4. Painel de saude do host

- [x] 4.1 Provisionar o dashboard oficial do node-exporter (ID 1860,
      grafana.com) como ConfigMap montado em
      `/etc/grafana/provisioning/dashboards/`. Feito: revisao 45,
      vendorizado em `grafana/dashboards/node-exporter-full.json`, via
      `configMapGenerator` (nao literal a mao -- arquivo grande, de fonte
      externa). Provider em `dashboards-provider.yaml`, mesmo mecanismo
      de `datasources.yaml`.
- [x] 4.2 Confirmar ao vivo, abrindo o painel, que CPU/memoria/disco do no
      aparecem com valor real (nao vazio). Confirmado: dashboard "Node
      Exporter Full" aparece via `/api/search`; `node_load1` (metrica
      central do painel) consultavel com valor real no Mimir. Variavel de
      datasource (`${ds_prometheus}`, tipo datasource/query=prometheus)
      resolve sozinha para o Mimir -- unico datasource `prometheus` do
      ambiente.
- [x] 4.3 Registrar qualquer painel individual que ficar vazio (metrica
      opcional nao coletada) como limitacao conhecida, sem tentar
      preencher todos a forca. Nenhum vazio identificado nas metricas
      centrais verificadas.

## 5. Painel de saude do Postgres

- [x] 5.1 Provisionar o dashboard oficial do CNPG (`grafana-dashboards`,
      `charts/cluster/grafana-dashboard.json`) como ConfigMap. Feito,
      mesmo mecanismo da 4.1 (`grafana/dashboards/cnpg-cluster.json`).
- [x] 5.2 Confirmar ao vivo que conexoes ativas e estado de replicacao
      aparecem com valor real. Confirmado: dashboard "CloudNativePG"
      aparece via `/api/search`; `cnpg_collector_up`=1 e
      `cnpg_backends_total` (conexoes ativas) com valor real. Variaveis
      `namespace`/`cluster`/`instances` (baseadas em `cnpg_collector_up`)
      resolvem para `data`/`erp-postgres`/`erp-postgres-1` sem intervencao.
- [x] 5.3 Registrar qualquer painel individual vazio como limitacao
      conhecida (mesma tarefa 4.3). **Surpresa positiva**: a variavel
      `operatorNamespace` (usada por paineis do proprio operador CNPG, nao
      so da instancia) depende de `controller_runtime_webhook_requests_total`
      -- confirmado que o pod do operador (`cnpg-controller-manager`) JA
      estava anotado para scrape (de plataforma-gitops), sem trabalho
      adicional. Nenhum painel vazio identificado.

## 6. Painel de saude de pod/workload (construido sob medida)

- [x] 6.1 Construir um dashboard proprio, combinando estado declarado
      (kube-state-metrics: reinicios por pod, replicas esperadas vs.
      prontas por Deployment, contagem de pods fora de `Running`) e
      consumo real (cAdvisor: CPU e memoria por contêiner) lado a lado.
      Provisionar como ConfigMap, mesmo mecanismo. Feito:
      `grafana/dashboards/pod-workload-health.json`, uid
      `pod-workload-health`, 5 paineis.
- [x] 6.2 Verificar cada painel de estado individualmente: forcar um
      reinicio de pod de teste e confirmar que a contagem sobe no painel.
      **BUG REAL encontrado e corrigido ao vivo**: o job de scrape
      compartilhado ("infra") sobrescrevia (`honor_labels` padrao =
      false) os rotulos `pod`/`namespace` que o proprio
      kube-state-metrics ja expunha DESCREVENDO O OBJETO OBSERVADO, com a
      identidade do EXPORTER -- toda serie aparecia com
      `pod="kube-state-metrics-..."`, nunca o pod real. Corrigido
      excluindo kube-state-metrics do job "infra" (`action: drop` no
      `discovery.relabel`) e dando a ele um `prometheus.scrape` proprio
      com `honor_labels = true`. Reconfirmado ao vivo: pod de teste
      forcado a reiniciar (`restartPolicy: Always`, saida com erro),
      `kube_pod_container_status_restarts_total{pod="restart-test"}`
      subiu corretamente (0->6) sob o rotulo certo.
- [x] 6.3 Verificar que um Deployment com replicas incompletas aparece
      como tal (escalar um componente de teste e observar). Confirmado
      ao vivo: Tempo escalado a 2 replicas, `kube_deployment_spec_replicas`=2
      e `kube_deployment_status_replicas_ready`=1 visiveis simultaneamente
      (sob o job `prometheus.scrape.kube_state_metrics` corrigido).
      Escalado de volta a 1 depois.
- [x] 6.4 Verificar o painel de consumo real: comparar o valor exibido com
      `kubectl top pod` para o mesmo contêiner, confirmando que sao
      consistentes. Confirmado: `container_memory_working_set_bytes` do
      Grafana = 234.7 MiB, `kubectl top pod` reportou 234Mi para o mesmo
      pod -- consistente (mesma fonte de dado, cAdvisor via kubelet).

## 7. Recursos e verificacao de ponta a ponta

- [x] 7.1 Medir o consumo de memoria com os paineis, o kube-state-metrics
      e o cAdvisor no ar, comparar com a linha de base de
      `observabilidade`. Confirmado ao vivo: no do cluster em 5226Mi/32%
      (linha de base era 5210Mi/32% -- variacao desprezivel).
      kube-state-metrics usa ~16Mi. cAdvisor nao adiciona pod novo (embutido
      no kubelet). Host com 15Gi total, 7.5Gi livre + 4.5Gi buff/cache
      (11Gi "available") -- sem risco de esgotamento, nenhum ajuste de
      limite necessario.
- [ ] 7.2 Destruir o ambiente e recria-lo do zero, confirmando que os
      quatro paineis (host, Postgres, pod/workload, e a raspagem do
      cAdvisor que os alimenta) voltam presentes e com dado real, sem
      intervencao manual.
- [x] 7.3 Confirmar que nenhum manifesto novo referencia caminho de host,
      nome de maquina ou classe de armazenamento que nao seja a padrao
      (a excecao do `bearer_token_file` do proprio ServiceAccount, que nao
      e um caminho de host). Confirmado via `grep`: nenhum `hostPath`,
      `storageClassName`, `nodeSelector`/`nodeName` em nenhum manifesto
      novo desta change.

## 8. Encerramento

- [x] 8.1 Registrar em `deploy/README.md` os paineis disponiveis, o
      endereco de acesso e a origem de cada um (importado vs. construido).
      Feito: secao "Paineis operacionais". Tambem corrigido um gap
      pre-existente (nao desta change): Grafana nunca tinha sido
      adicionado a secao "Acessando os paineis" apesar de ja ter Ingress e
      credencial proprios desde `observabilidade` -- agora tem
      port-forward e comando de credencial, confirmados ao vivo.
- [x] 8.2 Confirmar que nenhum alerta, SLO ou painel de negocio entrou no
      escopo. Confirmado por revisao dos manifestos criados: nenhum
      `PrometheusRule`/`AlertmanagerConfig`, nenhum painel fora dos tres
      de saude operacional (host, Kubernetes, Postgres).
- [x] 8.3 Registrar em `deploy/README.md` que o RBAC do Alloy contra a API
      do kubelet (`nodes/metrics`, `nodes/proxy`) e a unica excecao ao
      padrao "so scrape por anotacao" desta plataforma, e por que (D5 do
      design). Feito, mesma secao -- tambem documentado o gotcha de
      `honor_labels` com kube-state-metrics (tarefa 6.2).
