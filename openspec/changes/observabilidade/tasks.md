# Tarefas: observabilidade

Depende de `plataforma-gitops` concluida. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

## 1. Ponto de ingestao

- [ ] 1.1 Declarar o agente de coleta (Grafana Alloy) em
      `deploy/base/observabilidade/`, na onda posterior a dos armazenamentos de
      dado da change anterior. Fixar a versao.
- [ ] 1.2 Habilitar a recepcao dos tres sinais em um unico endereco e protocolo.
- [ ] 1.3 Configurar os papeis acumulados em desenvolvimento: uma unica instancia
      atuando como agente por no e como porta de entrada. Registrar na
      sobreposicao que em producao os papeis se separam.
- [ ] 1.4 Habilitar o grafo visual de componentes do agente e confirmar que a
      contagem por aresta permite ver onde o dado para. **Falha de pipeline de
      telemetria se manifesta como ausencia, o mesmo sintoma de nao haver
      atividade.**
- [ ] 1.5 Configurar o enriquecimento com identidade de origem no cluster,
      derivada do ambiente de execucao.
- [ ] 1.6 Configurar agrupamento em lotes e limite de acumulo, com descarte
      controlado ao exceder o limite.
- [ ] 1.7 Expor a metrica de registros descartados. Verificacao: forcar descarte e
      confirmar que a contagem aparece. **Perda silenciosa faz ausencia de
      registro ser lida como ausencia de atividade.**
- [ ] 1.8 Verificar o enriquecimento: enviar registro sem atributo de origem e
      confirmar que os atributos de origem sao acrescentados.
- [ ] 1.9 Verificar precedencia: enviar registro com atributo de origem
      divergente do ambiente real e confirmar que prevalece o derivado do
      ambiente.
- [ ] 1.10 Verificar isolamento: tornar um armazenamento indisponivel e confirmar
      que o emissor continua operando normalmente e que a perda e observavel.

## 2. Coleta de metricas de infraestrutura

- [ ] 2.1 Configurar, no proprio agente, o scrape nativo das metricas expostas
      pelos componentes de infraestrutura, usando a descoberta de alvos no
      cluster em vez de lista fixa de enderecos.
- [ ] 2.2 Confirmar que essas metricas chegam ao mesmo armazenamento das metricas
      recebidas por envio, por escrita nativa e sem camada de traducao.
- [ ] 2.3 Configurar a coleta nativa de log de pod pelo agente, e confirmar que
      os logs dos componentes de infraestrutura chegam ao armazenamento de logs.
- [ ] 2.4 Verificar tolerancia: tornar um componente monitorado indisponivel e
      confirmar que a coleta dos demais prossegue e que a indisponibilidade
      aparece como metrica.
- [ ] 2.5 Confirmar que **nao existe** coletor de metricas autonomo separado nem
      camada de traducao entre o agente e cada armazenamento.

## 3. Armazenamento de rastros

- [ ] 3.1 Declarar o armazenamento de rastros em modo de processo unico, com
      credencial e repositorio de objetos vindos da change anterior.
- [ ] 3.2 Aplicar o contrato de configuracao de acesso a objetos, com atencao a
      forma de enderecamento e ao valor de regiao exigido pelo cliente.
- [ ] 3.3 Confirmar que os objetos chegam ao repositorio correspondente.
- [ ] 3.4 Declarar a janela de retencao na sobreposicao do ambiente.
- [ ] 3.5 Ativar o processo de compactacao e manutencao.

## 4. Armazenamento de metricas

- [ ] 4.1 Declarar o armazenamento de metricas em modo de processo unico, usando
      os tres repositorios de objetos previstos.
- [ ] 4.2 Aplicar o contrato de configuracao de acesso a objetos.
- [ ] 4.3 Confirmar que os objetos chegam aos repositorios correspondentes.
- [ ] 4.4 Declarar a janela de retencao na sobreposicao do ambiente.
- [ ] 4.5 Ativar o processo de compactacao e manutencao.

## 5. Armazenamento de logs

- [ ] 5.1 Declarar o armazenamento de logs em modo de processo unico, com os
      repositorios de objetos previstos.
- [ ] 5.2 Aplicar o contrato de configuracao de acesso a objetos.
- [ ] 5.3 Confirmar que os objetos chegam aos repositorios correspondentes.
- [ ] 5.4 Declarar a janela de retencao na sobreposicao do ambiente.
- [ ] 5.5 **Ativar explicitamente o processo de manutencao com remocao
      habilitada.** Declarar a janela sem esse processo nao apaga nada.

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

- [ ] 7.1 Declarar a interface de consulta com as fontes dos tres sinais
      provisionadas de forma declarativa.
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
      propagacao de contexto.
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
