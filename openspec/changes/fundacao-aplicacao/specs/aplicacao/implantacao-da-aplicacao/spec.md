## Purpose

Torna a aplicacao uma carga de trabalho declarada como as demais, com estado de
saude observavel, versao em execucao identificavel ate o commit que a originou, e
o dado minimo sem o qual a primeira execucao de um ambiente novo nao autentica
nem consulta.

## ADDED Requirements

### Requirement: Estado de saude e de prontidao observaveis

A aplicacao SHALL expor separadamente o seu estado de vivacidade e o seu estado de
prontidao para receber trabalho. Instancia sem suas dependencias essenciais
disponiveis MUST NOT ser considerada pronta.

#### Scenario: Instancia pronta recebe trabalho

- **WHEN** a instancia esta em execucao com suas dependencias essenciais
  disponiveis
- **THEN** ela e reportada como pronta e passa a receber trabalho

#### Scenario: Dependencia essencial indisponivel impede prontidao

- **WHEN** uma dependencia essencial esta indisponivel
- **THEN** a instancia e reportada como nao pronta e nao recebe trabalho

#### Scenario: Vivacidade e prontidao sao distintas

- **WHEN** a instancia esta viva mas ainda inicializando
- **THEN** ela e reportada como viva e nao pronta, e nao e reiniciada por esse
  motivo

#### Scenario: Estado de saude nao exige identidade

- **WHEN** o estado de saude e consultado sem identidade
- **THEN** a consulta e respondida, sem revelar detalhe interno de configuracao

### Requirement: Versao em execucao rastreavel ate o commit

A identificacao da versao implantada SHALL derivar do conteudo do commit que a
originou e MUST ser imutavel. Identificacao mutavel, reutilizada entre versoes
diferentes, MUST NOT ser usada.

#### Scenario: Versao em execucao e rastreavel

- **WHEN** a versao em execucao e consultada
- **THEN** ela identifica o commit exato que a originou

#### Scenario: Identificacao mutavel e recusada

- **WHEN** uma identificacao reutilizavel entre versoes e declarada
- **THEN** isso e tratado como defeito, porque impede detectar diferenca e
  impossibilita retorno a versao anterior

#### Scenario: Retorno a versao anterior e possivel

- **WHEN** a versao anterior precisa voltar a atender
- **THEN** ela e identificavel e pode ser reimplantada sem reconstrucao

### Requirement: Aplicacao declarada como carga de trabalho reconciliada

A aplicacao SHALL ser declarada no repositorio como as demais cargas de trabalho,
com sua configuracao obtida por referencia a segredo do ambiente e nunca embutida
na sua definicao.

#### Scenario: Configuracao vem por referencia

- **WHEN** a definicao da carga de trabalho da aplicacao e inspecionada
- **THEN** ela obtem credencial por referencia a segredo do ambiente, sem valor
  sensivel embutido

#### Scenario: Definicao nao contem valor especifico de maquina

- **WHEN** a definicao da aplicacao e inspecionada
- **THEN** ela nao referencia caminho de sistema de arquivos do host, nome de
  maquina nem endereco de instalacao particular

### Requirement: Ausencia de instancias no ambiente de desenvolvimento

No ambiente de desenvolvimento a aplicacao SHALL ser declarada sem instancias em
execucao, porque o desenvolvimento ocorre fora do ambiente reconciliado.

#### Scenario: Desenvolvimento nao executa a aplicacao no ambiente

- **WHEN** o ambiente de desenvolvimento e reconciliado
- **THEN** a aplicacao esta declarada e sem instancias em execucao

#### Scenario: Caminho completo permanece exercitavel sob demanda

- **WHEN** a contagem de instancias e elevada deliberadamente para verificacao
- **THEN** a aplicacao inicia no ambiente com a estrutura de dados ja aplicada na
  ordem correta

### Requirement: Dado inicial suficiente para a primeira execucao

Um ambiente recem-criado SHALL conter o dado minimo necessario para que a primeira
execucao autentique e consulte, incluindo ao menos uma filial e a identidade
correspondente. Esse dado MUST ser aplicado de forma repetivel e MUST NOT
sobrescrever dado existente.

#### Scenario: Ambiente novo permite a primeira operacao

- **WHEN** um ambiente e criado do zero e a aplicacao e iniciada pela primeira vez
- **THEN** e possivel obter identidade valida e consultar dentro de uma filial
  existente

#### Scenario: Reaplicacao do dado inicial nao altera o existente

- **WHEN** o dado inicial e aplicado novamente sobre ambiente ja em uso
- **THEN** a operacao conclui sem erro e sem sobrescrever dado existente

#### Scenario: Dado inicial e distinguivel de dado de operacao

- **WHEN** o dado inicial e inspecionado
- **THEN** ele e identificavel como dado de partida do ambiente, e nao como carga
  de dados de producao
