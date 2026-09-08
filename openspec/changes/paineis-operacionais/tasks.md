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

## 2. Raspagem do exporter do Postgres

- [ ] 2.1 Adicionar `prometheus.io/scrape` e `prometheus.io/port: "9187"`
      via `spec.inheritedMetadata.annotations` no `Cluster` do CNPG
      (`deploy/base/plataforma/postgres/cluster.yaml`).
- [ ] 2.2 Confirmar ao vivo que o pod do Postgres recebeu a anotacao
      (`kubectl get pod -o jsonpath`) sem reinicio do banco.
- [ ] 2.3 Confirmar ao vivo que uma metrica do exporter do CNPG (ex.
      `cnpg_pg_stat_database_numbackends`) chega ao Mimir.

## 3. Painel de saude do host

- [ ] 3.1 Provisionar o dashboard oficial do node-exporter (ID 1860,
      grafana.com) como ConfigMap montado em
      `/etc/grafana/provisioning/dashboards/`.
- [ ] 3.2 Confirmar ao vivo, abrindo o painel, que CPU/memoria/disco do no
      aparecem com valor real (nao vazio).
- [ ] 3.3 Registrar qualquer painel individual que ficar vazio (metrica
      opcional nao coletada) como limitacao conhecida, sem tentar
      preencher todos a forca.

## 4. Painel de saude do Postgres

- [ ] 4.1 Provisionar o dashboard oficial do CNPG (`grafana-dashboards`,
      `charts/cluster/grafana-dashboard.json`) como ConfigMap.
- [ ] 4.2 Confirmar ao vivo que conexoes ativas e estado de replicacao
      aparecem com valor real.
- [ ] 4.3 Registrar qualquer painel individual vazio como limitacao
      conhecida (mesma tarefa 3.3).

## 5. Painel de saude de pod/workload (construido sob medida)

- [ ] 5.1 Construir um dashboard proprio, pequeno, com: reinicios por pod,
      replicas esperadas vs. prontas por Deployment, contagem de pods fora
      de `Running`. Provisionar como ConfigMap, mesmo mecanismo.
- [ ] 5.2 Verificar cada painel individualmente: forcar um reinicio de pod
      de teste e confirmar que a contagem sobe no painel.
- [ ] 5.3 Verificar que um Deployment com replicas incompletas aparece
      como tal (escalar um componente de teste e observar).

## 6. Recursos e verificacao de ponta a ponta

- [ ] 6.1 Medir o consumo de memoria com os paineis e o kube-state-metrics
      no ar, comparar com a linha de base de `observabilidade`.
- [ ] 6.2 Destruir o ambiente e recria-lo do zero, confirmando que os tres
      paineis voltam presentes e com dado real, sem intervencao manual.
- [ ] 6.3 Confirmar que nenhum manifesto novo referencia caminho de host,
      nome de maquina ou classe de armazenamento que nao seja a padrao.

## 7. Encerramento

- [ ] 7.1 Registrar em `deploy/README.md` os tres paineis disponiveis, o
      endereco de acesso e a origem de cada um (importado vs. construido).
- [ ] 7.2 Confirmar que nenhum alerta, SLO ou painel de negocio entrou no
      escopo.
- [ ] 7.3 Registrar como opcao futura, nao como escopo, a adicao de
      cAdvisor para metrica de uso real por container (D1 do design).
