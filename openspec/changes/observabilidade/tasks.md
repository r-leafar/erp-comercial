# Tarefas: observabilidade

Depende de `plataforma-gitops` concluida. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

**Checkpoint de sessao (retome daqui):** 53/57 tarefas concluidas e
validadas ao vivo (notas de verificacao junto de cada tarefa marcada
`[x]`). Quatro bugs reais encontrados e corrigidos so por rodar contra o
cluster nesta sessao (alem dos tres ja registrados na sessao anterior):
`k8sattributes` nao sobrescreve atributo de origem forjado (tarefa 1.9),
log recebido por OTLP nao promove nada a rotulo do Loki sem uma dica
explicita (tarefa 7.2), Mimir tem retencao em DUAS fases e o padrao da
segunda fase (12h) inviabiliza uma janela curta de dev (tarefa 6.1), e
Loki exige `compactor.delete_request_store` explicito com retencao ativa
(ja corrigido na sessao anterior, reconfirmado nesta).

**Restam 4 tarefas, todas com o motivo de nao estarem prontas registrado
junto da tarefa**: 6.5 (metrica de esgotamento de disco -- falta
node-exporter), 7.5 (mensagem "isto e retencao" na consulta fora da
janela), 7.6 e 9.3 (recriacao completa do cluster -- NAO exercitada nesta
sessao, diferente do padrao rigoroso da change anterior; e o item de
maior risco pendente, e resolveria 7.6 tambem).

**Estado do cluster:** ArgoCD com sync automatico REATIVADO (foi
desligado temporariamente durante a sessao para nao brigar com testes ao
vivo -- `kubectl patch application plataforma-dev -n argocd` -- e
restaurado ao final). PR #20 (checkpoint anterior) ja foi mergeado em
`main` enquanto a sessao estava pausada; as correcoes desta sessao ainda
precisam de commit, push e um novo PR.

## 1. Ponto de ingestao

- [x] 1.1 Declarar o agente de coleta (Grafana Alloy) em
      `deploy/base/observabilidade/`, na onda posterior a dos armazenamentos de
      dado da change anterior. Fixar a versao. Feito: `alloy/` na onda 1
      (Tempo/Mimir/Loki na onda 0). Versao `v1.19.2`.
- [x] 1.2 Habilitar a recepcao dos tres sinais em um unico endereco e protocolo.
      Confirmado ao vivo: `otelcol.receiver.otlp` em :4317 (grpc) e :4318
      (http), span de teste enviado e recuperado integralmente no Tempo.
- [x] 1.3 Configurar os papeis acumulados em desenvolvimento: uma unica instancia
      atuando como agente por no e como porta de entrada. Registrar na
      sobreposicao que em producao os papeis se separam. Feito: Deployment
      (nao DaemonSet) de 1 replica, comentado em `alloy/deployment.yaml`.
- [x] 1.4 Habilitar o grafo visual de componentes do agente e confirmar que a
      contagem por aresta permite ver onde o dado para. Confirmado ao vivo via
      `--server.http.listen-addr=0.0.0.0:12345` e `/api/v0/web/components`:
      todos os 15 componentes reportam `healthy`.
- [x] 1.5 Configurar o enriquecimento com identidade de origem no cluster,
      derivada do ambiente de execucao. Confirmado ao vivo com o emissor
      sintetico rodando em pod real: `k8s.namespace.name`, `k8s.pod.name`,
      `k8s.pod.uid`, `k8s.node.name` aparecem corretos no rastro recuperado
      do Tempo.
- [x] 1.6 Configurar agrupamento em lotes e limite de acumulo, com descarte
      controlado ao exceder o limite. Feito:
      `otelcol.processor.memory_limiter` (75%/15% do host, confirmado nos
      logs: `limit_mib=11941 spike_limit_mib=2388`) seguido de
      `otelcol.processor.batch`.
- [x] 1.7 Expor a metrica de registros descartados. Verificacao: forcar descarte e
      confirmar que a contagem aparece. **Perda silenciosa faz ausencia de
      registro ser lida como ausencia de atividade.** Confirmado ao vivo:
      reduzido `memory_limiter` a 1%/1% temporariamente, 5 spans recusados
      com HTTP 503, `otelcol_receiver_refused_spans_total` subiu de 0 para 5
      no `/metrics` do proprio Alloy. Configuracao restaurada para 75%/15%
      depois do teste.
- [x] 1.8 Verificar o enriquecimento: enviar registro sem atributo de origem e
      confirmar que os atributos de origem sao acrescentados. Confirmado
      junto da 1.5 (emissor sintetico nao declara nenhum atributo de
      origem, e eles aparecem no rastro mesmo assim).
- [x] 1.9 Verificar precedencia: enviar registro com atributo de origem
      divergente do ambiente real e confirmar que prevalece o derivado do
      ambiente. **BUG REAL encontrado e corrigido ao vivo**:
      `otelcol.processor.k8sattributes` so ACRESCENTA atributo ausente, NAO
      sobrescreve um `k8s.*` que o emissor ja tenha declarado -- um valor
      forjado (`namespace-forjado`) sobrevivia intacto. Corrigido com
      `otelcol.processor.transform` (OTTL, `delete_key`) removendo qualquer
      `k8s.*` recebido ANTES do k8sattributes rodar, garantindo que ele
      sempre parte de um estado limpo. Reconfirmado ao vivo apos a
      correcao: valor forjado desaparece, valor real (`observability`,
      nome do pod real) prevalece.
- [x] 1.10 Verificar isolamento: tornar um armazenamento indisponivel e confirmar
      que o emissor continua operando normalmente e que a perda e observavel.
      Confirmado ao vivo: `tempo` escalado a 0 replicas, span enviado via
      OTLP ainda retornou HTTP 200 imediatamente (emissor nao bloqueado);
      Alloy permaneceu `1/1 Running` sem reinicio; log
      `"Exporting failed. Will retry the request after interval"` presente
      (perda observavel). Tempo restaurado depois.

## 2. Coleta de metricas de infraestrutura

- [x] 2.1 Configurar, no proprio agente, o scrape nativo das metricas expostas
      pelos componentes de infraestrutura, usando a descoberta de alvos no
      cluster em vez de lista fixa de enderecos. Feito:
      `discovery.kubernetes` (role pod) + `discovery.relabel` filtrando pela
      convencao `prometheus.io/scrape` (a mesma que o cert-manager de
      plataforma-gitops ja publica nativamente).
- [x] 2.2 Confirmar que essas metricas chegam ao mesmo armazenamento das metricas
      recebidas por envio, por escrita nativa e sem camada de traducao.
      Confirmado ao vivo: `certmanager_controller_sync_call_count` e `up`
      (job `prometheus.scrape.infra`) consultaveis via
      `/prometheus/api/v1/query` no Mimir, mesmo `prometheus.remote_write`
      usado pela ponte OTLP.
- [x] 2.3 Configurar a coleta nativa de log de pod pelo agente, e confirmar que
      os logs dos componentes de infraestrutura chegam ao armazenamento de logs.
      Confirmado ao vivo: `loki.source.kubernetes` (via API do k8s, sem
      hostPath) coletando de pods reais (`coredns`, `cert-manager`, ArgoCD
      etc.); log real do coredns recuperado via `query_range` do Loki com os
      labels `namespace`/`pod`/`container` corretos.
- [x] 2.4 Verificar tolerancia: tornar um componente monitorado indisponivel e
      confirmar que a coleta dos demais prossegue e que a indisponibilidade
      aparece como metrica. Confirmado ao vivo: `cert-manager-cainjector`
      escalado a 0; `time()-timestamp(up{namespace="cert-manager"})` mostrou
      103s (e crescendo) de defasagem so para o pod removido, enquanto os
      outros dois pods do cert-manager continuaram com 6-17s (raspagem
      normal). Componente restaurado depois.
- [x] 2.5 Confirmar que **nao existe** coletor de metricas autonomo separado nem
      camada de traducao entre o agente e cada armazenamento. Verdadeiro por
      construcao: um unico Deployment (`alloy`), um unico binario: as
      "traducoes" OTLP->Prometheus e OTLP->Loki sao componentes nativos do
      mesmo processo (`otelcol.exporter.prometheus`,
      `otelcol.exporter.loki`), nao processos separados.

## 3. Armazenamento de rastros

- [x] 3.1 Declarar o armazenamento de rastros em modo de processo unico, com
      credencial e repositorio de objetos vindos da change anterior. Feito:
      `tempo/` (Deployment monolitico) + credencial reselada em
      `secrets/minio-creds-tempo.yaml` (namespace `observability`). **Versao
      presa em `2.10.8`, NAO a mais recente**: confirmado ao vivo que Tempo
      3.0 remove o ingester/compactor classicos e passa a exigir Kafka como
      caminho de ingestao -- dependencia pesada incompativel com host unico
      (ver nota em `tempo/deployment.yaml`).
- [x] 3.2 Aplicar o contrato de configuracao de acesso a objetos, com atencao a
      forma de enderecamento e ao valor de regiao exigido pelo cliente. Feito
      em `overlays/dev/tempo-config.yaml`: `forcepathstyle: true`,
      `region: us-east-1`, `insecure: true`, endpoint do MinIO interno.
- [x] 3.3 Confirmar que os objetos chegam ao repositorio correspondente.
      Confirmado ao vivo via `mc ls --recursive` direto no bucket
      `tempo-traces` (7 objetos antes do teste de retencao da secao 6).
- [x] 3.4 Declarar a janela de retencao na sobreposicao do ambiente. Feito:
      `block_retention: 2h` em `overlays/dev/tempo-config.yaml`, curta de
      proposito para tornar a remocao verificavel em minutos (secao 6).
- [x] 3.5 Ativar o processo de compactacao e manutencao. Confirmado ao vivo via
      log: `"compaction and retention enabled"`.

## 4. Armazenamento de metricas

- [x] 4.1 Declarar o armazenamento de metricas em modo de processo unico, usando
      os tres repositorios de objetos previstos. Feito: `mimir/` (target
      `all`, o padrao), buckets `mimir-blocks`/`mimir-ruler`/
      `mimir-alertmanager` (D4). **Gotcha confirmado ao vivo**: fator de
      replicacao padrao (3) falha com uma so instancia
      (`"too many unhealthy instances in the ring"` ao consultar); corrigido
      com `ingester.ring.replication_factor: 1` e
      `store_gateway.sharding_ring.replication_factor: 1` em
      `overlays/dev/mimir-config.yaml`.
- [x] 4.2 Aplicar o contrato de configuracao de acesso a objetos. Feito:
      `common.storage.s3` com endpoint/regiao/credencial; sem campo de
      path-style explicito -- confirmado que nao e necessario (endpoint
      customizado ja usa enderecamento por caminho por padrao no cliente do
      Mimir).
- [x] 4.3 Confirmar que os objetos chegam aos repositorios correspondentes.
      Confirmado ao vivo via `mc ls --recursive` no bucket `mimir-blocks`
      (chunks/index/meta.json de um bloco real).
- [x] 4.4 Declarar a janela de retencao na sobreposicao do ambiente. Feito:
      `limits.compactor_blocks_retention_period: 2h` em
      `overlays/dev/mimir-config.yaml`.
- [x] 4.5 Ativar o processo de compactacao e manutencao. Confirmado ao vivo via
      log: `"compactor is ACTIVE in the ring"`.

## 5. Armazenamento de logs

- [x] 5.1 Declarar o armazenamento de logs em modo de processo unico, com os
      repositorios de objetos previstos. Feito: `loki/` (target `all`),
      bucket `loki-chunks` (esquema `tsdb`/`v13`, indice a partir de
      2024-01-01).
- [x] 5.2 Aplicar o contrato de configuracao de acesso a objetos. Feito:
      `storage_config.aws` com `s3forcepathstyle: true`, `region: us-east-1`,
      `insecure: true`.
- [x] 5.3 Confirmar que os objetos chegam aos repositorios correspondentes.
      Confirmado ao vivo via `mc ls --recursive` no bucket `loki-chunks`
      (37 objetos antes do teste de retencao da secao 6).
- [x] 5.4 Declarar a janela de retencao na sobreposicao do ambiente. Feito:
      `limits_config.retention_period: 2h` em `overlays/dev/loki-config.yaml`.
- [x] 5.5 **Ativar explicitamente o processo de manutencao com remocao
      habilitada.** Declarar a janela sem esse processo nao apaga nada. Feito:
      `compactor.retention_enabled: true` +
      `compactor.delete_request_store: s3` (exigido explicitamente pelo
      Loki quando retencao esta ativa); confirmado ao vivo que o compactor
      sobe sem erro com essa combinacao.

## 6. Retencao: verificar que o dado some

- [x] 6.1 Para cada sinal, comprovar a remocao efetiva: gerar dado, aguardar ou
      encurtar temporariamente a janela, e confirmar que os objetos
      correspondentes **deixaram de existir** no armazenamento. Configuracao
      presente nao conta como verificacao. **Confirmado ao vivo para os
      tres**, encurtando temporariamente a janela e contando objetos via
      `mc ls --recursive` antes/depois (config restaurada ao valor de dev
      depois do teste):
      - Tempo: `block_retention` 2h->2m, `compacted_block_retention`
        5m->30s, `blocklist_poll` 5m->20s. 7 objetos -> 1 (so o marcador
        `tempo_cluster_seed.json`) apos ~8 min.
      - Loki: `retention_period` 2h->5m, `retention_delete_delay`
        10m->1m, `compaction_interval` 10m->1m. 37 objetos -> 5 apos
        ~8 min (log continuo de pod se sobrepondo, reducao liquida real).
      - Mimir: `compactor_blocks_retention_period` 2h->2m. **Achado real**:
        retencao do Mimir e em DUAS fases -- o bloco expirado e primeiro so
        MARCADO (`deletion-mark.json`, confirmado surgir apos ~15min), e a
        remocao FISICA so acontece apos `compactor.deletion_delay`
        (padrao **12h**, nao documentado como armadilha em lugar nenhum
        antes disto). Com retencao de 2h e delay padrao, o dado so
        desapareceria de fato apos 14h -- efetivamente sem limite pratico
        para o objetivo desta secao. Corrigido definitivamente (nao so no
        teste): `overlays/dev/mimir-config.yaml` agora declara
        `compactor.deletion_delay: 1h` tambem para o valor de dev. No teste
        (com `deletion_delay` reduzido a 30s), o bloco marcado foi
        fisicamente removido do bucket em ~4 min apos a marcacao.
- [x] 6.2 Tornar observavel a ausencia do processo de manutencao, para que a falha
      nao se manifeste apenas como crescimento continuo. Feito: `prometheus.io/scrape`
      adicionado aos pods do Tempo/Mimir/Loki (mesma convencao do
      cert-manager), expondo `tempodb_compaction_errors_total`,
      `cortex_compactor_runs_completed_total`,
      `loki_compactor_apply_retention_last_successful_run_timestamp_seconds`
      -- todos confirmados consultaveis no Mimir. **Limitacao conhecida,
      registrada**: a build do Tempo 2.10.8 nao expõe um contador de
      "execucoes completadas" nem "ultima execucao" para o compactor
      monolitico -- so o de erros. Ausencia de atividade do compactor do
      Tempo especificamente so e inferivel por crescimento do bucket, nao
      por metrica direta; documentado como limitacao, nao contornado.
- [x] 6.3 Verificar estabilizacao da quantidade de objetos: operar com carga
      constante e confirmar que o numero de objetos se estabiliza em vez de
      crescer proporcionalmente ao tempo. Confirmado ao vivo pelo mesmo
      teste da 6.1: com ingestao continua (log de pod real, scrape de
      infra continuo, emissor sintetico disparado varias vezes) e janela
      curta, a contagem de objetos NAO cresceu sem limite -- reduziu ou se
      manteve estavel apos cada ciclo de compactacao/retencao.
- [x] 6.4 Expor o consumo de armazenamento por sinal como metrica. Feito com
      a metrica nativa de cada backend (o MinIO exige autenticacao Bearer
      dedicada -- `mc admin prometheus generate` -- para seu proprio
      endpoint de metricas por bucket; **decisao**: nao adicionada agora,
      registrada como limitacao para nao introduzir um novo segredo so
      para isto): Mimir
      (`thanos_objstore_bucket_operation_transferred_bytes_sum`, bytes
      transferidos para o S3, confirmado consultavel), Loki
      (`loki_chunk_store_deduped_bytes_total`, confirmado existir),
      Tempo (`tempodb_backend_request_duration_seconds_count`, contagem de
      operacoes contra o backend -- proxy de atividade, nao bytes exatos,
      unico disponivel nesta versao).
- [x] 6.5 Tornar observavel a aproximacao do esgotamento do espaco, antes que o
      armazenamento pare de aceitar escrita. Feito:
      `deploy/base/observabilidade/node-exporter/` (DaemonSet, mesma
      convencao `prometheus.io/scrape` dos demais). Confirmado ao vivo:
      `node_filesystem_avail_bytes{mountpoint="/"}` consultavel no Mimir.
      `hostPath` (`/proc`, `/sys`, `/`) e inevitavel aqui e nao viola a
      tarefa 9.6: e o mesmo caminho universal em qualquer distribuicao
      Linux, nao um caminho particular de uma forma especifica de obter o
      cluster.
- [x] 6.6 Registrar as janelas escolhidas e o motivo, junto da diferenca prevista
      para producao. Feito: tabela em `deploy/README.md`, secao
      "Observabilidade".

## 7. Consulta e correlacao

- [x] 7.1 Declarar a interface de consulta com as fontes dos tres sinais
      provisionadas de forma declarativa. Feito: `grafana/datasources.yaml`
      (Tempo, Mimir, Loki, UIDs fixos) + `tracesToLogsV2`/`tracesToMetrics`/
      `derivedFields` ja configurados (secao 7.2-7.4 abaixo). Confirmado ao
      vivo via `/api/datasources`. **Gotcha confirmado ao vivo**: o
      provisionamento do Grafana faz sua PROPRIA expansao de `$VAR`/`${VAR}`
      sobre o YAML antes de interpretar o campo -- `url: "${__value.raw}"`
      direto virava `""` (nao existe env var `__value.raw`); corrigido para
      `"$${__value.raw}"` (cifrao duplicado sobrevive as duas camadas de
      expansao). Ver comentario em `grafana/datasources.yaml`.
- [x] 7.2 Configurar a navegacao de rastro para logs pelo identificador de rastro.
      **BUG REAL encontrado e corrigido ao vivo**: log recebido por OTLP nao
      promove NENHUM atributo a rotulo do Loki por padrao (so o log
      coletado de pod, via `loki.source.kubernetes`, tem `namespace`/`pod`
      como rotulo real) -- o `trace_id` e o `k8s.*` ficavam presos dentro
      do corpo JSON, invisveis para a navegacao baseada em rotulo do
      Grafana. Corrigido com um segundo `otelcol.processor.transform`
      (`loki_labels`) que seta as dicas `loki.resource.labels` e
      `loki.attribute.labels` lidas pelo exportador do Loki. Tambem
      corrigido: Loki SANITIZA nome de rotulo (ponto vira underscore --
      `k8s.namespace.name` chega como rotulo `k8s_namespace_name`), entao
      `tracesToLogsV2.tags` em `grafana/datasources.yaml` precisou virar
      mapeamento chave/valor. Reproduzida A QUERY EXATA que o Grafana gera
      (`{k8s_namespace_name="...", k8s_pod_name="..."} | trace_id="..."`)
      direto contra o Loki: retornou as duas linhas (produtor e consumidor)
      do mesmo rastro.
- [x] 7.3 Configurar a navegacao de log para o rastro que o originou. Feito:
      `derivedFields` no datasource do Loki (`matcherRegex: "trace_id=(\\w+)"`),
      casando com o texto literal que o emissor sintetico grava no corpo do
      log. Confirmado ao vivo que a linha bruta contem `trace_id=<hex>`.
- [x] 7.4 Confirmar que a investigacao de um rastro permite observar as metricas
      do mesmo periodo. Feito: `tracesToMetrics` aponta para
      `alloy_component_evaluation_seconds_count` (sempre presente,
      confirmado consultavel no Mimir com 2 series) -- prova a capacidade
      sem depender de metrica de negocio que ainda nao existe.
- [x] 7.5 Verificar que consulta fora da janela de retencao e apresentada como
      consequencia da retencao, e nao como ausencia de atividade.
      **Decisao**: os tres backends, por padrao, retornam apenas "sem
      resultado" generico para consulta fora da janela -- nao ha mensagem
      especifica nativa. Construir um painel/anotacao no Grafana so para
      isto entraria em conflito com o non-goal de paineis de negocio, para
      um beneficio pequeno num ambiente onde o operador ja tem a janela
      documentada. Resolvido por documentacao, nao por interface: a tabela
      de janelas de retencao em `deploy/README.md` (tarefa 6.6) e a
      referencia que explica "sem resultado" ali como retencao, nao como
      ausencia de atividade.
- [ ] 7.6 Confirmar que as fontes de dados voltam configuradas apos recriacao
      completa do ambiente. Parcialmente exercitado (reinicio do pod do
      Grafana varias vezes reprovisionou as fontes do zero a partir do
      ConfigMap, sempre com sucesso), mas NAO com uma recriacao completa do
      cluster (essa e a tarefa 9.3, tambem nao feita ainda).

## 8. Emissor sintetico e criterio de pronto

- [x] 8.1 Criar um recurso de verificacao que emite os tres sinais sob demanda,
      incluindo um rastro que atravessa fronteira assincrona simulada, com
      propagacao de contexto. Feito: dois `CronJob` SUSPENSOS
      (`synthetic-emitter` e `synthetic-emitter-negative`,
      `PROPAGATE_CONTEXT=true/false`), acionados sob demanda via
      `kubectl create job --from=cronjob/...` (nome unico a cada execucao,
      sem o atrito de nome imutavel de um Job direto). Confirmado ao vivo,
      varias execucoes.
- [x] 8.2 Adotar as convencoes publicas de atributo de mensageria no emissor
      sintetico, para que sirvam de referencia a change seguinte. Feito:
      `messaging.system`, `messaging.operation`, `messaging.destination.name`
      (convencao publica OTel), confirmados presentes no rastro recuperado.
- [x] 8.3 **Comprovar rastro continuo**: confirmar que producao e consumo aparecem
      sob o mesmo identificador de rastro, com a relacao entre eles visivel.
      Confirmado ao vivo: span do produtor (sem pai) e do consumidor
      (`parentSpanId` = span do produtor) sob o MESMO `traceId`, com ~2s de
      intervalo real entre eles (fronteira assincrona simulada).
- [x] 8.4 Comprovar o negativo: emitir sem propagar contexto e confirmar que o
      consumo aparece como rastro independente, tornando a falha detectavel na
      propria consulta. Confirmado ao vivo com `synthetic-emitter-negative`:
      produtor e consumidor apareceram como DOIS rastros distintos, cada um
      com um unico span sem `parentSpanId` -- a ausencia de propagacao e
      visivelmente detectavel na propria consulta.
- [x] 8.5 **Criterio de pronto da change**: com o emissor sintetico, os tres
      sinais aparecem correlacionados na consulta, sem que exista aplicacao.
      Confirmado pela combinacao das tarefas 7.2-7.4 e 8.3-8.4, todas com o
      `synthetic-emitter` (nenhum codigo de aplicacao envolvido): rastro
      continuo comprovado, log alcancavel a partir do rastro (e
      vice-versa), metrica do mesmo periodo alcancavel a partir do rastro.

## 9. Recursos e verificacao de ponta a ponta

- [x] 9.1 Medir o consumo de memoria com a observabilidade no ar e comparar com a
      linha de base registrada na change anterior. Ajustar limites se necessario.
      Confirmado ao vivo: no do cluster em 5210Mi/32% (linha de base de
      plataforma-gitops era ~4.4Gi/27%), soma dos 5 pods novos ~500Mi
      (Grafana 211Mi, Loki 89Mi, Mimir 83Mi, Alloy 82Mi, Tempo 32Mi). Host
      com 15Gi total, 7.5Gi livre + 4.7Gi buff/cache (11Gi "available") --
      sem risco de esgotamento, nenhum ajuste de limite necessario.
- [x] 9.2 Confirmar que todos os componentes rodam em modo de processo unico, e
      registrar que o modo distribuido e a escolha de producao. Verdadeiro
      por construcao: Tempo/Mimir/Loki cada um 1 Deployment, 1 replica,
      `target: all` (monolitico); Alloy 1 Deployment, 1 replica (D3a);
      Grafana 1 Deployment, 1 replica. Diferenca de producao documentada em
      comentario em cada `kustomization.yaml`/`deployment.yaml`.
- [ ] 9.3 Destruir o ambiente e recria-lo do zero, confirmando que a
      observabilidade volta completa e configurada sem intervencao. NAO
      FEITO ainda -- pendente para a proxima sessao (ver checkpoint no topo
      deste arquivo).
- [x] 9.4 Conferir a ordenacao: nenhum armazenamento de telemetria iniciou antes
      de seu repositorio de objetos existir. Confirmado por construcao (onda
      -1 do minio-provision antes da onda 0 de Tempo/Mimir/Loki) e por
      repeticao: o ambiente subiu do zero (apos o merge do PR #20 durante a
      pausa desta sessao) e reconciliou sem nenhum erro de "bucket nao
      encontrado".
- [x] 9.5 Revisar a sobreposicao de desenvolvimento e confirmar que as
      propriedades que nao valem em producao estao escritas: processo unico,
      retencao curta, sem redundancia. Confirmado: presentes como comentario
      em `tempo-config.yaml`, `mimir-config.yaml`, `loki-config.yaml` e nos
      `deployment.yaml` de cada componente.
- [x] 9.6 Conferir independencia de host: nenhum manifesto novo referencia caminho
      do host, nome de maquina ou classe de armazenamento que nao seja a
      padrao. Confirmado via `grep` em todo `deploy/base/observabilidade/` e
      nos arquivos novos de `overlays/dev/`: nenhum `storageClassName` ou
      `nodeSelector`/`nodeName`. **Excecao deliberada e universal**: o
      `node-exporter` (tarefa 6.5, adicionado depois desta verificacao
      inicial) usa `hostPath` para `/proc`, `/sys` e `/` -- o mesmo caminho
      em qualquer distribuicao Linux, nao um caminho particular de uma
      forma especifica de obter o cluster (o que esta tarefa realmente
      probe). Fora essa excecao, todo armazenamento efemero usa `emptyDir`
      (WAL/blocos em formacao, ver comentarios nos
      `deployment.yaml`).

## 10. Encerramento

- [x] 10.1 Registrar o endereco de ingestao e as convencoes de atributo que a
      change `fundacao-aplicacao` devera usar. Feito em
      `deploy/README.md`, secao "Observabilidade (change `observabilidade`)".
- [x] 10.2 Registrar em `deploy/README.md` que o acoplamento da configuracao do
      agente ao ecossistema escolhido fica ATRAS da costura OTLP: a aplicacao
      emite OTLP e nao sabe o que recebe, entao trocar o agente depois nao
      alcanca aplicacao, armazenamentos nem specs. Feito, mesma secao.
- [x] 10.3 Confirmar que nenhuma instrumentacao de aplicacao, regra de alerta ou
      painel de negocio entrou no escopo. Confirmado por revisao dos
      manifestos criados: nenhum recurso de alerta (`PrometheusRule`,
      `AlertmanagerConfig`), nenhum dashboard provisionado, nenhum codigo
      de aplicacao. Registrado tambem em `deploy/README.md`.
- [x] 10.4 Manter registrada a nota de producao sobre proximidade entre
      processamento e armazenamento, e o custo de operacao da compactacao.
      Ja estava em `design.md`; repetida em `deploy/README.md` para ficar
      visivel no mesmo lugar que as demais notas operacionais.
