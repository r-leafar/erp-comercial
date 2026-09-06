# Observabilidade: ingestao, retencao e consulta de telemetria

## Why

A change `plataforma-gitops` criou os repositorios de objetos da telemetria, mas
nenhum consumidor deles. Sem esta change, a proxima — que introduz a aplicacao —
nasceria cega: nao haveria onde enxergar um trace, uma metrica ou um log.

A ordem importa por dois motivos concretos:

1. **Instrumentar sem ter onde olhar nao se verifica.** A change de aplicacao
   decidiu propagar contexto de rastreamento atraves da fronteira assincrona do
   outbox. Isso so pode ser comprovado observando um trace unico que atravessa a
   fronteira. Sem o destino de pe, a instrumentacao seria escrita no escuro e o
   defeito apareceria tarde.
2. **Retencao mal resolvida destroi o ambiente.** Os componentes de telemetria
   escrevem continuamente. Retencao configurada sem compactacao ativa nao apaga
   nada, o armazenamento cresce sem limite e, em host com disco virtual, isso
   esgota o disco da maquina. E o tipo de problema que aparece semanas depois,
   quando ja ha dado acumulado e o diagnostico e mais caro.

Esta change entrega o lado receptor completo e verificavel **sem depender da
aplicacao existir**.

## What Changes

- **Ponto unico de ingestao de telemetria**, recebendo os tres sinais pelo mesmo
  protocolo, enriquecendo cada registro com a identidade de origem no cluster e
  encaminhando para o armazenamento correspondente.
- **Armazenamento de rastros, metricas e logs** com os repositorios de objetos
  como destino final, em modo de processo unico no ambiente de desenvolvimento.
- **Coleta de metricas dos componentes de infraestrutura** pelo proprio ponto de
  ingestao, eliminando um componente autonomo de coleta. **BREAKING** em relacao
  ao registrado no contexto do projeto, que previa um coletor de metricas
  separado.
- **Compactacao e retencao efetivas**, tratadas como requisito e nao como
  configuracao: o criterio de aceitacao e dado antigo desaparecer, nao a opcao
  estar presente.
- **Consulta correlacionada**, permitindo navegar de um rastro para os logs
  daquela execucao e para as metricas do mesmo periodo.
- **Verificacao por emissor sintetico**, para que o criterio de pronto nao
  dependa da aplicacao, que ainda nao existe.

### Non-goals

- **Instrumentacao da aplicacao.** Emitir rastros, metricas e logs a partir do
  codigo pertence a change `fundacao-aplicacao`. Aqui existe apenas o receptor.
- **Alertas e notificacao.** Regras de alerta precisam de sinais reais para serem
  escritas com sentido; nao ha aplicacao emitindo ainda.
- **Objetivos de nivel de servico.** Mesma razao.
- **Paineis de negocio.** Somente o necessario para provar correlacao entre os
  tres sinais.
- **Dimensionamento e topologia de producao.** O ambiente de desenvolvimento usa
  processo unico por componente, sem redundancia.
- **Arquivamento bruto de longo prazo.** Enviar telemetria crua direto ao
  armazenamento de objetos, para guarda prolongada e nao consultavel, e caminho
  conhecido e fica registrado como opcao futura, nao como escopo.

## Capabilities

### New Capabilities

- `plataforma/ingestao-de-telemetria`: ponto unico de recepcao dos tres sinais,
  enriquecimento com identidade de origem, encaminhamento ao armazenamento
  correspondente, e o isolamento que impede que falha ou indisponibilidade da
  telemetria afete quem a emite.
- `plataforma/retencao-de-telemetria`: compactacao ativa, remocao efetiva de dado
  fora da janela declarada e limite real de crescimento do armazenamento.
- `plataforma/consulta-de-telemetria`: disponibilidade dos tres sinais para
  consulta dentro da janela de retencao, e a correlacao que permite navegar entre
  eles a partir de um identificador de rastro.

### Modified Capabilities

Nenhuma. As capacidades de `plataforma-gitops` continuam valendo sem alteracao;
esta change apenas as consome.

## Impact

**Depende de**

`plataforma-gitops` completa: os repositorios de objetos da telemetria, as
credenciais com escopo por consumidor, o contrato de configuracao de acesso e o
mecanismo de reconciliacao com ordenacao por ondas.

**Novo no repositorio**

- Componentes de ingestao, armazenamento e consulta declarados em
  `deploy/base/observabilidade/`, com as diferencas de ambiente nas sobreposicoes.
- Fontes de dados e configuracao de correlacao provisionadas de forma declarativa.
- Um recurso de verificacao que emite telemetria sintetica sob demanda.

**Consumidores futuros afetados por decisao tomada aqui**

- A change `fundacao-aplicacao` enviara telemetria ao endereco de ingestao
  definido aqui, e verificara a propagacao de contexto atraves do outbox usando a
  consulta correlacionada entregue aqui.
- As convencoes de nomeacao de atributos adotadas na ingestao determinam se
  paineis e consultas sobrevivem a troca de transporte de mensagens no futuro.

**Risco assumido e registrado**

O consumo de memoria da plataforma cresce de forma significativa com esta change,
no mesmo host que executa o cluster e a aplicacao. Por isso os componentes rodam
em processo unico e a retencao e curta. O numero medido ao final da change
anterior e a base de comparacao.

**Nota para producao, fora do escopo**

Processamento e armazenamento de objetos devem ficar proximos. Telemetria em
armazenamento remoto degrada a consulta, porque cada consulta recupera muitos
objetos, e pode gerar custo inesperado, porque a compactacao opera
continuamente e provedores com cobranca minima de permanencia cobram meses por
blocos que existem por horas. Backup frio tolera distancia; telemetria quente
nao.
