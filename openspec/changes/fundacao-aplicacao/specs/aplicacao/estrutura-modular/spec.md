## Purpose

Mantem a separacao entre modulos verificavel automaticamente, de modo que uma
dependencia indevida entre modulos, ou uma inversao no sentido das dependencias
internas, seja recusada na construcao do artefato e nao descoberta em revisao.

## ADDED Requirements

### Requirement: Superficie publica de um modulo

Um modulo SHALL expor publicamente apenas o seu conjunto de contratos e uma unica
porta de registro destinada ao host. Qualquer outro tipo do modulo MUST ser
inacessivel a partir de outro modulo ou do host.

#### Scenario: Contrato e alcancavel por outro modulo

- **WHEN** um modulo referencia o conjunto de contratos publicado por outro
- **THEN** a referencia e valida e a construcao do artefato conclui

#### Scenario: Interior do modulo nao e alcancavel

- **WHEN** um modulo ou o host referencia um tipo do interior de outro modulo,
  fora dos contratos e fora da porta de registro
- **THEN** a construcao do artefato falha

#### Scenario: Superficie publica adicional e recusada

- **WHEN** um tipo publico e introduzido em um modulo fora do conjunto de
  contratos, alem da porta de registro
- **THEN** a verificacao automatica falha, identificando o tipo introduzido

### Requirement: Porta unica de entrada do host em um modulo

O host SHALL alcancar cada modulo exclusivamente pela porta de registro daquele
modulo, por meio da qual o modulo declara suas dependencias, seus endpoints e seu
acesso a dados. O host MUST NOT possuir conhecimento de nenhum outro elemento do
interior do modulo.

#### Scenario: Modulo e integrado pela porta

- **WHEN** o host inicia
- **THEN** cada modulo presente e integrado por meio da sua porta de registro, e
  seus endpoints ficam disponiveis

#### Scenario: Modulo nao integrado e detectavel

- **WHEN** um modulo existe no artefato e nao e integrado pelo host
- **THEN** a ausencia e detectada por verificacao automatica, e nao apenas pela
  ausencia dos seus endpoints em tempo de execucao

### Requirement: Sentido unico das dependencias internas

Dentro de um modulo, as dependencias SHALL apontar apenas na direcao do nucleo de
dominio. O nucleo de dominio e a camada de aplicacao MUST NOT depender de
infraestrutura, de detalhes de transporte nem de bibliotecas de acesso a recurso
externo.

#### Scenario: Dependencia na direcao correta

- **WHEN** a camada de infraestrutura de um modulo referencia o seu dominio
- **THEN** a verificacao automatica aprova

#### Scenario: Dependencia invertida e recusada

- **WHEN** o dominio ou a camada de aplicacao de um modulo referencia
  infraestrutura ou transporte
- **THEN** a verificacao automatica falha, identificando o tipo e a direcao
  violada

### Requirement: Nucleo compartilhado sem estado e sem infraestrutura

O nucleo compartilhado entre modulos SHALL conter apenas conceitos de dominio,
contratos de porta e tipos de valor. Ele MUST NOT conter estado, acesso a recurso
externo nem dependencia de biblioteca de infraestrutura.

#### Scenario: Nucleo compartilhado permanece puro

- **WHEN** uma dependencia de infraestrutura e introduzida no nucleo compartilhado
- **THEN** a verificacao automatica falha

#### Scenario: Nucleo compartilhado e exercitavel isoladamente

- **WHEN** os testes do nucleo compartilhado sao executados
- **THEN** eles concluem sem exigir banco de dados, rede ou qualquer recurso
  externo

### Requirement: Verificacao das regras de estrutura acompanha o codigo

As regras acima SHALL ser verificadas por testes automatizados executados junto
com a construcao do artefato, e MUST ser expressas de forma que a inclusao de um
modulo novo passe a ser coberta sem alteracao manual de lista de nomes.

#### Scenario: Modulo novo e coberto sem edicao das regras

- **WHEN** um modulo novo e acrescentado ao artefato
- **THEN** as verificacoes de fronteira e de sentido de dependencia passam a
  cobri-lo sem que suas regras precisem ser editadas

#### Scenario: Verificacao falha antes da integracao

- **WHEN** uma violacao de estrutura e introduzida
- **THEN** ela e reportada pela verificacao automatizada antes de a alteracao ser
  aceita
