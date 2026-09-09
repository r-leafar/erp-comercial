# Tarefas: paineis-operacionais

Depende de `observabilidade` concluida. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

## 1. kube-state-metrics

- [ ] 1.1 Declarar `kube-state-metrics` em `deploy/base/observabilidade/`,
      com RBAC de leitura cluster-wide (list/watch, sem escrita). Fixar a
      versao.
- [ ] 1.2 Adicionar a anotacao `prometheus.io/scrape` no pod, mesma
      convencao ja usada por cert-manager/Tempo/Mimir/Loki/node-exporter.
- [ ] 1.3 Confirmar ao vivo que as metricas `kube_pod_status_phase` e
      `kube_pod_container_status_restarts_total` chegam ao Mimir via
      consulta direta.

## 2. cAdvisor (consumo real por contêiner)

- [ ] 2.1 Configurar `discovery.kubernetes` com `role: node` no Alloy
      (mecanismo diferente do scrape por anotacao ja usado pelas demais
      fontes -- D5 do design).
- [ ] 2.2 Configurar `prometheus.scrape` apontando para
      `https://<endereco-do-no>:10250/metrics/cadvisor`, com
      `bearer_token_file` (token do ServiceAccount do Alloy) e
      `tls_config.insecure_skip_verify: true`.
- [ ] 2.3 Adicionar ao ClusterRole do Alloy as permissoes `get` em
      `nodes/metrics` e `nodes/proxy` (unico RBAC desta change que nao e
      list/watch de objeto -- D5 do design).
- [ ] 2.4 Confirmar ao vivo que `container_cpu_usage_seconds_total` e
      `container_memory_working_set_bytes` chegam ao Mimir, com valor
      real (nao zero) para um contêiner conhecido.

## 3. Raspagem do exporter do Postgres

- [ ] 3.1 Adicionar `prometheus.io/scrape` e `prometheus.io/port: "9187"`
      via `spec.inheritedMetadata.annotations` no `Cluster` do CNPG
      (`deploy/base/plataforma/postgres/cluster.yaml`).
- [ ] 3.2 Confirmar ao vivo que o pod do Postgres recebeu a anotacao
      (`kubectl get pod -o jsonpath`) sem reinicio do banco.
- [ ] 3.3 Confirmar ao vivo que uma metrica do exporter do CNPG (ex.
      `cnpg_pg_stat_database_numbackends`) chega ao Mimir.

## 4. Painel de saude do host

- [ ] 4.1 Provisionar o dashboard oficial do node-exporter (ID 1860,
      grafana.com) como ConfigMap montado em
      `/etc/grafana/provisioning/dashboards/`.
- [ ] 4.2 Confirmar ao vivo, abrindo o painel, que CPU/memoria/disco do no
      aparecem com valor real (nao vazio).
- [ ] 4.3 Registrar qualquer painel individual que ficar vazio (metrica
      opcional nao coletada) como limitacao conhecida, sem tentar
      preencher todos a forca.

## 5. Painel de saude do Postgres

- [ ] 5.1 Provisionar o dashboard oficial do CNPG (`grafana-dashboards`,
      `charts/cluster/grafana-dashboard.json`) como ConfigMap.
- [ ] 5.2 Confirmar ao vivo que conexoes ativas e estado de replicacao
      aparecem com valor real.
- [ ] 5.3 Registrar qualquer painel individual vazio como limitacao
      conhecida (mesma tarefa 4.3).

## 6. Painel de saude de pod/workload (construido sob medida)

- [ ] 6.1 Construir um dashboard proprio, combinando estado declarado
      (kube-state-metrics: reinicios por pod, replicas esperadas vs.
      prontas por Deployment, contagem de pods fora de `Running`) e
      consumo real (cAdvisor: CPU e memoria por contêiner) lado a lado.
      Provisionar como ConfigMap, mesmo mecanismo.
- [ ] 6.2 Verificar cada painel de estado individualmente: forcar um
      reinicio de pod de teste e confirmar que a contagem sobe no painel.
- [ ] 6.3 Verificar que um Deployment com replicas incompletas aparece
      como tal (escalar um componente de teste e observar).
- [ ] 6.4 Verificar o painel de consumo real: comparar o valor exibido com
      `kubectl top pod` para o mesmo contêiner, confirmando que sao
      consistentes.

## 7. Recursos e verificacao de ponta a ponta

- [ ] 7.1 Medir o consumo de memoria com os paineis, o kube-state-metrics
      e o cAdvisor no ar, comparar com a linha de base de
      `observabilidade`.
- [ ] 7.2 Destruir o ambiente e recria-lo do zero, confirmando que os
      quatro paineis (host, Postgres, pod/workload, e a raspagem do
      cAdvisor que os alimenta) voltam presentes e com dado real, sem
      intervencao manual.
- [ ] 7.3 Confirmar que nenhum manifesto novo referencia caminho de host,
      nome de maquina ou classe de armazenamento que nao seja a padrao
      (a excecao do `bearer_token_file` do proprio ServiceAccount, que nao
      e um caminho de host).

## 8. Encerramento

- [ ] 8.1 Registrar em `deploy/README.md` os paineis disponiveis, o
      endereco de acesso e a origem de cada um (importado vs. construido).
- [ ] 8.2 Confirmar que nenhum alerta, SLO ou painel de negocio entrou no
      escopo.
- [ ] 8.3 Registrar em `deploy/README.md` que o RBAC do Alloy contra a API
      do kubelet (`nodes/metrics`, `nodes/proxy`) e a unica excecao ao
      padrao "so scrape por anotacao" desta plataforma, e por que (D5 do
      design).
