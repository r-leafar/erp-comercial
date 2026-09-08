# Design: observabilidade

## Context

A change `plataforma-gitops` deixou pronto o que esta change consome: os
repositorios de objetos da telemetria, as credenciais com escopo por consumidor,
o contrato uniforme de configuracao de acesso e a ordenacao por ondas. Nada aqui
provisiona armazenamento; tudo aqui e consumidor dele.

Restricoes que moldam o desenho:

- **A aplicacao nao existe.** O criterio de pronto precisa ser verificavel sem
  ela, senao esta change fica bloqueada pela seguinte.
- **Mesmo host, memoria compartilhada.** A plataforma ja consome recursos do
  host que tambem roda o cluster e, futuramente, a aplicacao. Cada componente
  adicionado disputa a mesma memoria.
- **Escrita continua sobre disco local.** Diferente dos componentes da change
  anterior, estes escrevem sem parar. Em host com disco virtual que nao encolhe,
  isso e o principal risco ao ambiente.
- **Uma decisao da change seguinte depende desta.** A propagacao de contexto
  atraves do outbox so se comprova observando um rastro continuo. Esta change
  precisa entregar essa capacidade de observacao pronta.

```
   +==================================================================+
   |  emissores                                                       |
   |    aplicacao (change seguinte)  |  emissor sintetico (aqui)      |
   +---------------------------+--------------------------------------+
                               |  um endereco, um protocolo
                               v
   +------------------------------------------------------------------+
   |  INGESTAO                                                        |
   |    recebe os tres sinais                                         |
   |    coleta metricas dos componentes de infraestrutura             |
   |    enriquece com identidade de origem no cluster                 |
   |    agrupa em lotes, limita acumulo, contabiliza descarte         |
   +------+---------------------+---------------------+---------------+
          | rastros             | metricas            | logs
          v                     v                     v
   +-------------+       +-------------+       +-------------+
   | armaz. de   |       | armaz. de   |       | armaz. de   |
   | rastros     |       | metricas    |       | logs        |
   +------+------+       +------+------+       +------+------+
          |                     |                     |
          +---------------------+---------------------+
                                | objetos
                                v
              +--------------------------------------+
              |  repositorios criados na change 1    |
              +--------------------------------------+
                                ^
                                | consulta
              +--------------------------------------+
              |  INTERFACE DE CONSULTA               |
              |  fontes provisionadas declarativamente|
              |  correlacao rastro <-> log <-> metrica|
              +--------------------------------------+
```

## Goals / Non-Goals

**Goals**

- Um unico endereco de ingestao, com quem emite ignorando o destino de cada sinal.
- Crescimento de armazenamento limitado e comprovado, nao apenas configurado.
- Correlacao entre os tres sinais, incluindo rastro continuo atraves de fronteira
  assincrona.
- Criterio de pronto verificavel sem a aplicacao.

**Non-Goals**

- Instrumentacao da aplicacao.
- Alertas, notificacao e objetivos de nivel de servico.
- Paineis de negocio.
- Dimensionamento de producao.
- Arquivamento bruto de longo prazo.

## Decisions

### D1. Um ponto de ingestao, e quem emite nao conhece o destino

**Decisao.** Todos os sinais entram por um unico endereco e um unico protocolo. O
componente de ingestao decide o destino de cada um.

**Consequencia que evita.** Emissor acoplado a topologia de armazenamento. Sem
essa camada, trocar o armazenamento de um sinal exigiria alterar e reimplantar
todos os emissores. Com ela, e alteracao de configuracao em um lugar.

**Beneficio adicional.** O enriquecimento com identidade de origem acontece aqui,
o que significa que nenhum emissor precisa saber onde esta rodando.

### D2. Enriquecimento derivado do ambiente, nao declarado pelo emissor

**Decisao.** Os atributos que identificam origem no cluster sao derivados do
ambiente de execucao no momento da ingestao, e prevalecem sobre qualquer valor
declarado por quem emite.

**Consequencia que evita.** Telemetria que afirma vir de um lugar e vem de outro.
Atributo de origem informado pelo emissor e configuracao, e configuracao erra:
copia-se um valor de outro ambiente e a investigacao aponta para o lugar errado
exatamente quando mais importa.

**Implementacao real, confirmada ao vivo.** O processor
`otelcol.processor.k8sattributes` do Alloy, na pratica, so ACRESCENTA um
atributo `k8s.*` ausente -- ele NAO sobrescreve um valor que o emissor ja
tenha declarado com o mesmo nome. Testado deliberadamente: um span com
`k8s.namespace.name="namespace-forjado"` manteve o valor forjado intacto
apos passar pelo processor. Isso violava a decisao D2 na pratica, nao so na
teoria. Corrigido inserindo um processor de transformacao (OTTL,
`otelcol.processor.transform`) que remove qualquer atributo `k8s.*` recebido
ANTES do enriquecimento rodar -- garantindo que o k8sattributes sempre
enriquece a partir de um estado limpo, e o valor derivado do ambiente
sempre prevalece. Ver `deploy/base/observabilidade/alloy/config.yaml`,
componente `strip_forged_origin`.

### D3. Grafana Alloy como agente unico de coleta; sem coletor de metricas autonomo

**Decisao.** Um unico agente — Grafana Alloy — recebe os tres sinais por OTLP,
faz o scrape das metricas dos componentes de infraestrutura, coleta log de pod e
encaminha tudo aos armazenamentos correspondentes. **Nao existe um coletor de
metricas autonomo separado.**

**Esclarecimento necessario.** Alloy **e uma distribuicao do OpenTelemetry
Collector**, nao uma alternativa a ele: embute os componentes do Collector
(receptor OTLP, processador de atributos de cluster, agrupamento em lotes,
exportadores) e acrescenta os nativos de metricas e logs no mesmo binario. A
escolha e de distribuicao, nao de tecnologia.

**Justificativa.** O que esta decisao pede coincide com a premissa do agente:

```
   O QUE A DECISAO EXIGE          O QUE O AGENTE OFERECE NATIVAMENTE
   ---------------------------    ----------------------------------
   receber OTLP dos 3 sinais      receptor OTLP embutido
   scrape de metricas de infra    scrape com descoberta no cluster
   enriquecer com origem          processador de atributos de cluster
   escrever no armaz. metricas    escrita nativa, sem tradutor
   escrever no armaz. logs        escrita nativa
   escrever no armaz. rastros     exportador OTLP
   coletar log de pod             coleta nativa
                                  ^ no Collector puro exigiria
                                    receptor de arquivo e mais config
```

**Consequencia que evita.** Duas, e a primeira e a que mais pesa aqui:

1. Consumo de memoria e superficie de configuracao duplicados, num ambiente onde
   memoria e o recurso mais disputado. O armazenamento de metricas escolhido ja
   oferece a interface de consulta compativel que um coletor autonomo ofereceria;
   manter os dois seria dois componentes, dois volumes e duas retencoes para o
   **mesmo** sinal, com um deles sendo so intermediario.
2. Camadas de traducao entre o agente e cada armazenamento, cada uma com formato,
   configuracao e modo de falha proprios.

**O que se perde, declarado.** A configuracao do agente usa a linguagem de
componentes dele, e nao o formato do Collector puro. Voltar ao Collector padrao
exigiria reescrever essa configuracao.

**Por que o risco disso e baixo.** A costura do projeto e o OTLP:

```
   aplicacao emite OTLP        <- A COSTURA
                                  nao sabe o que recebe
             |
             v
   agente de coleta            <- ATRAS da costura
                                  trocar depois nao toca a aplicacao,
                                  os armazenamentos nem as specs;
                                  so a configuracao do agente
```

As especificacoes desta change foram escritas em termos de comportamento
observavel, sem nomear produto, e continuam valendo sem alteracao para qualquer
distribuicao que as satisfaca.

**Acoplamento assumido.** A configuracao passa a ser especifica do ecossistema
de observabilidade ja escolhido para todo o resto. E coerente com a decisao de
adotar essa pilha inteira, mas e acoplamento, e fica registrado como tal.

**Beneficio de diagnostico.** O agente expoe um grafo visual de seus componentes
com contagem por aresta, o que mostra onde o dado para. Pipeline de telemetria e
especialmente dificil de depurar as cegas, porque a falha se manifesta como
ausencia — o mesmo sintoma de nao haver atividade. E o mesmo argumento que
justificou a escolha do agente de reconciliacao na change anterior.

**Alternativas recusadas.**

- *Collector puro mais um coletor de metricas autonomo.* E a topologia usual em
  producao, onde o coletor fica proximo do alvo e o armazenamento e remoto. Em um
  host unico essa separacao nao compra nada e custa memoria.
- *Collector puro sozinho.* Chegaria ao mesmo resultado, com mais camadas de
  traducao e configuracao mais extensa para coleta de log de pod. A portabilidade
  de configuracao que se ganharia esta atras da costura, entao vale pouco.

**Opcao que fica disponivel sem custo agora.** O agente tambem fala com o
componente de perfis continuos da mesma pilha. Nao e escopo desta change, mas
deixa de exigir pecas novas se um dia for desejado.

### D3a. Papeis do agente acumulados em desenvolvimento

**Decisao.** Em desenvolvimento, uma unica instancia do agente acumula os dois
papeis; em producao eles se separam.

```
   PAPEIS
     agente por no       coleta log de pod e metricas do no
     porta de entrada    recebe OTLP e faz o scrape

   dev, no unico      1 instancia, ambos os papeis
   prod, varios nos   papeis separados, com enderecamento estavel
                      para a porta de entrada
```

**Consequencia que evita.** Duas cargas de trabalho do mesmo agente disputando
memoria num host unico, sem nenhum ganho: com um no, o papel por no tem
exatamente uma instancia de qualquer forma.

**Fronteira dev/prod.** Mais uma diferenca a declarar na sobreposicao, junto das
demais.

### D4. Processo unico por componente em desenvolvimento

**Decisao.** Os tres armazenamentos rodam em modo de processo unico, e nao no modo
distribuido em que cada funcao interna vira um componente separado.

**Justificativa.** O comportamento funcional observavel e o mesmo: mesma ingestao,
mesma consulta, mesma retencao. O que muda e a capacidade de escalar cada funcao
isoladamente, irrelevante em um host unico.

**Consequencia que evita.** Dezenas de processos disputando a memoria da maquina
de desenvolvimento, com a maior parte deles ociosa.

**Fronteira dev/prod.** O modo distribuido e a escolha correta em producao, e a
troca e de configuracao, nao de arquitetura. Fica declarado como diferenca de
ambiente.

### D5. Retencao e o dado sumir, nao a opcao existir

**Decisao.** O criterio de aceitacao da retencao e a **ausencia** do dado antigo
no armazenamento, verificada, e nao a presenca da configuracao.

**Consequencia que evita.** O modo de falha mais comum desta pilha: janela de
retencao configurada enquanto o processo que efetivamente remove o dado nao esta
em execucao. Nesse estado tudo parece correto, nada e apagado, e o problema so
aparece quando o disco esgota — semanas depois, com muito dado acumulado e o
diagnostico mais caro.

```
   O QUE PARECE                       O QUE E
   ------------------------------     ------------------------------
   janela declarada: 7 dias           processo de remocao ausente
   configuracao presente              nada e apagado
   ambiente aparentemente sadio       crescimento linear e continuo
                                      ate esgotar o disco do host
```

**Obrigacao derivada.** A ausencia do processo de manutencao precisa ser
observavel por si mesma, e nao apenas inferida do crescimento do armazenamento.

**Achado real, confirmado ao vivo: retencao em duas fases esconde uma
segunda janela.** No Mimir, um bloco expirado (fora de
`compactor_blocks_retention_period`) e primeiro so MARCADO para remocao
(`deletion-mark.json` no bucket); a remocao FISICA dos arquivos so ocorre
depois de `compactor.deletion_delay`, cujo padrao e **12 horas**. Com uma
janela de retencao curta de dev (2h) e o padrao de 12h intocado, o dado so
desapareceria de fato apos 14h -- exatamente o modo de falha que esta
decisao pretende evitar, so que uma camada mais abaixo do que o texto
original previa (aqui nao e o processo de manutencao que esta AUSENTE, e
uma segunda janela, silenciosa, empilhada sobre a primeira). Corrigido
declarando `compactor.deletion_delay: 1h` tambem no ambiente de dev (ver
`deploy/overlays/dev/mimir-config.yaml`). Verificado ao vivo com um valor
ainda mais curto (30s): o bloco marcado foi fisicamente removido do bucket
poucos minutos depois. Confirmado o mesmo criterio (objeto some de fato,
nao so marcado) para Tempo e Loki no mesmo teste, sem essa segunda janela
escondida.

### D6. Compactacao e um custo de escrita, nao apenas de limpeza

**Decisao.** A compactacao esta ativa para todo sinal que dela dependa, e seu
custo e reconhecido no dimensionamento.

**Observacao que costuma surpreender.** A compactacao nao apenas apaga: ela
**le, consolida, escreve e remove** objetos continuamente. A quantidade de
operacoes sobre o armazenamento e substancialmente maior do que a taxa de
ingestao sugere.

**Por que importa aqui.** Em desenvolvimento, sobre disco local, isso e apenas
consumo. Em producao com armazenamento remoto cobrado por operacao, e a principal
fonte de custo — e a razao da nota de producao adiante.

### D7. Correlacao e requisito, nao configuracao de conveniencia

**Decisao.** A navegacao entre rastro, log e metrica e provisionada de forma
declarativa e verificada.

**Consequencia que evita.** Tres armazenamentos que funcionam isoladamente e uma
investigacao que exige copiar identificadores entre abas. Sem correlacao, o valor
da telemetria cai a uma fracao: o custo foi pago e o beneficio, nao.

**Dependencia para a change seguinte.** A verificacao de que o contexto atravessa
a fronteira assincrona do outbox se faz aqui, olhando um rastro. Sem esta
capacidade pronta, aquela decisao seria implementada sem forma de comprovacao.

**Achado real, confirmado ao vivo: log recebido por OTLP nao carrega rotulo
nenhum por padrao.** A navegacao "rastro -> logs" do Grafana filtra por
ROTULO do Loki, nao por conteudo do corpo do log. O log de pod coletado
via `loki.source.kubernetes` ja tem `namespace`/`pod` como rotulo real
(promovido pelo `discovery.relabel`), mas o log recebido por OTLP (emissor
sintetico hoje, aplicacao amanha) NAO promove nenhum atributo a rotulo --
`trace_id` e `k8s.*` ficam presos dentro do corpo JSON, invisiveis para
essa navegacao. Corrigido com um segundo processor de transformacao que
seta as dicas `loki.resource.labels`/`loki.attribute.labels` lidas pelo
exportador Loki do Alloy antes de exportar (ver componente `loki_labels`
em `deploy/base/observabilidade/alloy/config.yaml`). Achado relacionado:
o Loki sanitiza nome de rotulo (ponto vira underscore), entao
`tracesToLogsV2.tags` no datasource do Tempo precisou de um mapeamento
chave/valor explicito (`k8s.namespace.name` -> `k8s_namespace_name`), nao
uma lista simples de nomes iguais.

### D8. Verificacao por emissor sintetico

**Decisao.** O criterio de pronto e comprovado por um emissor sintetico que envia
os tres sinais, incluindo um rastro que atravessa fronteira assincrona simulada.

**Consequencia que evita.** Dependencia circular entre changes: esta precisaria da
aplicacao para ser verificada, e a aplicacao precisa desta para ser verificada. O
emissor sintetico corta o ciclo.

**Beneficio permanente.** Ele continua util depois, para distinguir "a aplicacao
nao esta emitindo" de "a telemetria nao esta recebendo" — duas causas com o mesmo
sintoma.

### D9. Convencoes de atributo escolhidas para sobreviver a troca de transporte

**Decisao.** Os atributos que descrevem operacoes de mensageria seguem convencao
publica e estavel, independente da tecnologia de transporte.

**Consequencia que evita.** Consultas e paineis escritos sobre nomes proprios de
uma tecnologia. Ha uma troca de transporte de mensagens ja prevista no projeto;
com convencao propria, ela invalidaria todo o material de investigacao construido
ate la. Com convencao publica, muda apenas o valor que identifica o sistema de
mensageria.

### D10. Perder telemetria e sempre preferivel a afetar o observado

**Decisao.** O caminho de telemetria e isolado de quem o alimenta: acumulo
limitado, descarte controlado e contabilizado, e nenhuma propagacao de falha para
o emissor.

**Consequencia que evita.** O modo de falha mais perverso da observabilidade: o
mecanismo criado para diagnosticar problemas passa a causa-los. Acumulo sem
limite consome a memoria do processo observado; escrita sincrona propaga latencia
do armazenamento para a operacao de negocio.

**Obrigacao derivada.** O descarte precisa ser contabilizado. Telemetria perdida
em silencio produz conclusoes erradas: ausencia de registro passa a ser lida como
ausencia de atividade.

## Risks / Trade-offs

| Risco | Impacto | Mitigacao |
|---|---|---|
| Processo de remocao inativo com retencao aparentemente configurada | Crescimento continuo ate esgotar o disco do host | Criterio de aceitacao e o dado sumir; ausencia do processo e observavel por si |
| Consumo de memoria somado ao que a change anterior ja usa | Maquina de desenvolvimento inviabilizada | Processo unico por componente; retencao curta; medicao comparada a linha de base da change anterior |
| Volume de rastros maior que o esperado | Armazenamento e memoria consumidos rapidamente | Amostragem revista se necessario; consumo por sinal observavel desde o inicio |
| Correlacao configurada mas nunca exercitada | Descoberta de que nao funciona durante uma investigacao real | Verificacao por emissor sintetico faz parte do criterio de pronto |
| Acoplamento da configuracao de coleta ao ecossistema de observabilidade escolhido | Voltar a uma distribuicao neutra exigiria reescrever a configuracao do agente | O acoplamento fica atras da costura OTLP: aplicacao, armazenamentos e specs nao mudam. Custo confinado a um componente |
| Papeis acumulados em uma instancia mascararem problema que so aparece com papeis separados | Comportamento divergente entre dev e producao | Diferenca declarada na sobreposicao; separacao e a configuracao de producao, nao alteracao de arquitetura |
| Custo de operacao da compactacao subestimado | Em producao, custo desproporcional ao volume armazenado | Nota de producao registrada; decisao de provedor ainda em aberto |

**Trade-off central.** Esta change adiciona consumo significativo de recursos ao
ambiente sem entregar nenhuma funcionalidade de negocio. O retorno aparece na
change seguinte, onde cada decisao dificil — propagacao de contexto atraves do
outbox, atraso de consistencia eventual, comportamento do cache — passa a ser
observavel em vez de suposta. Instrumentar antes de ter onde olhar seria escrever
codigo sem forma de verifica-lo.

**Nota para producao, fora do escopo.** Processamento e armazenamento devem ficar
proximos. Consulta de rastros e metricas recupera muitos objetos, entao distancia
vira latencia percebida; e a compactacao opera continuamente, entao provedores que
cobram por operacao ou impoem permanencia minima cobram meses por blocos que
existem por horas. Backup frio tolera distancia; telemetria quente nao. A decisao
depende de onde producao rodara, o que ainda nao esta definido.
