# Tarefas: observabilidade

Depende de `plataforma-gitops` concluida. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

**Checkpoint de sessao (retome daqui):** Tempo/Mimir/Loki/Alloy/Grafana
implantados e validados ao vivo (secoes 1-5 e 7.1 em boa parte concluidas,
notas de verificacao junto de cada tarefa marcada `[x]`). O script do
emissor sintetico (secao 8) esta ESCRITO mas NAO implantado -- proximo passo
e criar o Job/CronJob, aplicar, e usa-lo para fechar as tarefas 1.5, 1.7-1.10,
2.4, 3.3/4.3/5.3 (inspecao de bucket), 6.x (retencao), 7.2-7.6 e 8.x
inteira. Nada commitado ainda em `deploy/` alem deste checkpoint -- branch
`change/observabilidade`, ainda sem PR aberto.

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
- [ ] 1.5 Configurar o enriquecimento com identidade de origem no cluster,
      derivada do ambiente de execucao. Configurado
      (`otelcol.processor.k8sattributes`), mas NAO verificado ainda: o teste
      de fumaca via `kubectl port-forward` chega com IP de origem que nao e
      de um pod real, entao o processor nao encontrou correspondencia (correto
      para essa forma de teste, mas nao prova enriquecimento). Precisa do
      emissor sintetico (secao 8, script ja escrito em
      `synthetic-emitter/script.yaml`, ainda nao implantado) rodando DENTRO do
      cluster para provar.
- [x] 1.6 Configurar agrupamento em lotes e limite de acumulo, com descarte
      controlado ao exceder o limite. Feito:
      `otelcol.processor.memory_limiter` (75%/15% do host, confirmado nos
      logs: `limit_mib=11941 spike_limit_mib=2388`) seguido de
      `otelcol.processor.batch`.
- [ ] 1.7 Expor a metrica de registros descartados. Verificacao: forcar descarte e
      confirmar que a contagem aparece. **Perda silenciosa faz ausencia de
      registro ser lida como ausencia de atividade.** Mecanismo pronto
      (`prometheus.scrape.self` raspa o proprio Alloy, `alloy_build_info` ja
      confirmado consultavel no Mimir), mas o descarte em si (contagem de
      `otelcol_processor_refused_*` subindo) ainda NAO foi forcado nem
      verificado.
- [ ] 1.8 Verificar o enriquecimento: enviar registro sem atributo de origem e
      confirmar que os atributos de origem sao acrescentados. Depende do
      emissor sintetico rodando em pod real (ver nota da 1.5).
- [ ] 1.9 Verificar precedencia: enviar registro com atributo de origem
      divergente do ambiente real e confirmar que prevalece o derivado do
      ambiente. Mesma dependencia da 1.8.
- [ ] 1.10 Verificar isolamento: tornar um armazenamento indisponivel e confirmar
      que o emissor continua operando normalmente e que a perda e observavel.

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
- [ ] 2.4 Verificar tolerancia: tornar um componente monitorado indisponivel e
      confirmar que a coleta dos demais prossegue e que a indisponibilidade
      aparece como metrica. Ainda nao testado.
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
- [ ] 3.3 Confirmar que os objetos chegam ao repositorio correspondente. Ainda
      nao verificado por inspecao direta do bucket (so o smoke test via
      consulta `/api/traces/<id>`, que prova o caminho completo mas nao foi
      cruzado com o conteudo do bucket `tempo-traces`).
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
- [ ] 4.3 Confirmar que os objetos chegam aos repositorios correspondentes.
      Mesma pendencia da 3.3: metricas confirmadas consultaveis (ver 2.2),
      mas conteudo do bucket `mimir-blocks` ainda nao inspecionado
      diretamente.
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
- [ ] 5.3 Confirmar que os objetos chegam aos repositorios correspondentes.
      Mesma pendencia da 3.3/4.3: logs confirmados consultaveis (ver 2.3),
      bucket `loki-chunks` ainda nao inspecionado diretamente.
- [x] 5.4 Declarar a janela de retencao na sobreposicao do ambiente. Feito:
      `limits_config.retention_period: 2h` em `overlays/dev/loki-config.yaml`.
- [x] 5.5 **Ativar explicitamente o processo de manutencao com remocao
      habilitada.** Declarar a janela sem esse processo nao apaga nada. Feito:
      `compactor.retention_enabled: true` +
      `compactor.delete_request_store: s3` (exigido explicitamente pelo
      Loki quando retencao esta ativa); confirmado ao vivo que o compactor
      sobe sem erro com essa combinacao.

## 6. Retencao: verificar que o dado some

- [ ] 6.1 Para cada sinal, comprovar a remocao efetiva: gerar dado, aguardar ou
      encurtar temporariamente a janela, e confirmar que os objetos
      correspondentes **deixaram de existir** no armazenamento. Configuracao
      presente nao conta como verificacao.
- [ ] 6.2 Tornar observavel a ausencia do processo de manutencao, para que a falha
      nao se manifeste apenas como crescimento continuo.
- [ ] 6.3 Verificar estabilizacao da quantidade de objetos: operar com carga
      constante e confirmar que o numero de objetos se estabiliza em vez de
      crescer proporcionalmente ao tempo.
- [ ] 6.4 Expor o consumo de armazenamento por sinal como metrica.
- [ ] 6.5 Tornar observavel a aproximacao do esgotamento do espaco, antes que o
      armazenamento pare de aceitar escrita.
- [ ] 6.6 Registrar as janelas escolhidas e o motivo, junto da diferenca prevista
      para producao.

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
- [ ] 7.2 Configurar a navegacao de rastro para logs pelo identificador de rastro.
- [ ] 7.3 Configurar a navegacao de log para o rastro que o originou.
- [ ] 7.4 Confirmar que a investigacao de um rastro permite observar as metricas
      do mesmo periodo.
- [ ] 7.5 Verificar que consulta fora da janela de retencao e apresentada como
      consequencia da retencao, e nao como ausencia de atividade.
- [ ] 7.6 Confirmar que as fontes de dados voltam configuradas apos recriacao
      completa do ambiente.

## 8. Emissor sintetico e criterio de pronto

- [ ] 8.1 Criar um recurso de verificacao que emite os tres sinais sob demanda,
      incluindo um rastro que atravessa fronteira assincrona simulada, com
      propagacao de contexto. EM ANDAMENTO: script Python (so biblioteca
      padrao) escrito em `synthetic-emitter/script.yaml` -- produtor e
      consumidor com pausa real de 2s entre eles, mesmo trace_id +
      parentSpanId quando `PROPAGATE_CONTEXT=true` (padrao), trace_id novo e
      sem relacao quando `false` (variante negativa da tarefa 8.4). FALTA:
      Job/CronJob (suspenso, disparado sob demanda) para rodar o script no
      cluster, wire-up no kustomization do overlay, e a implantacao/teste ao
      vivo em si -- nada disso foi feito ainda.
- [ ] 8.2 Adotar as convencoes publicas de atributo de mensageria no emissor
      sintetico, para que sirvam de referencia a change seguinte.
- [ ] 8.3 **Comprovar rastro continuo**: confirmar que producao e consumo aparecem
      sob o mesmo identificador de rastro, com a relacao entre eles visivel.
- [ ] 8.4 Comprovar o negativo: emitir sem propagar contexto e confirmar que o
      consumo aparece como rastro independente, tornando a falha detectavel na
      propria consulta.
- [ ] 8.5 **Criterio de pronto da change**: com o emissor sintetico, os tres
      sinais aparecem correlacionados na consulta, sem que exista aplicacao.

## 9. Recursos e verificacao de ponta a ponta

- [ ] 9.1 Medir o consumo de memoria com a observabilidade no ar e comparar com a
      linha de base registrada na change anterior. Ajustar limites se necessario.
- [ ] 9.2 Confirmar que todos os componentes rodam em modo de processo unico, e
      registrar que o modo distribuido e a escolha de producao.
- [ ] 9.3 Destruir o ambiente e recria-lo do zero, confirmando que a
      observabilidade volta completa e configurada sem intervencao.
- [ ] 9.4 Conferir a ordenacao: nenhum armazenamento de telemetria iniciou antes
      de seu repositorio de objetos existir.
- [ ] 9.5 Revisar a sobreposicao de desenvolvimento e confirmar que as
      propriedades que nao valem em producao estao escritas: processo unico,
      retencao curta, sem redundancia.
- [ ] 9.6 Conferir independencia de host: nenhum manifesto novo referencia caminho
      do host, nome de maquina ou classe de armazenamento que nao seja a padrao.

## 10. Encerramento

- [ ] 10.1 Registrar o endereco de ingestao e as convencoes de atributo que a
      change `fundacao-aplicacao` devera usar.
- [ ] 10.2 Registrar em `deploy/README.md` que o acoplamento da configuracao do
      agente ao ecossistema escolhido fica ATRAS da costura OTLP: a aplicacao
      emite OTLP e nao sabe o que recebe, entao trocar o agente depois nao
      alcanca aplicacao, armazenamentos nem specs.
- [ ] 10.3 Confirmar que nenhuma instrumentacao de aplicacao, regra de alerta ou
      painel de negocio entrou no escopo.
- [ ] 10.4 Manter registrada a nota de producao sobre proximidade entre
      processamento e armazenamento, e o custo de operacao da compactacao.
