## Purpose

Estabelece o que a interface exposta promete a quem a consome: um formato unico de
erro com codigo estavel, distincao entre falha prevista de negocio e falha
inesperada, e envelopes de resposta previsiveis, para que clientes nao dependam de
texto nem de comportamento acidental.

## ADDED Requirements

### Requirement: Formato unico de resposta de erro

Toda resposta de erro SHALL usar o mesmo formato estruturado, contendo um codigo
de erro estavel e uma mensagem legivel em portugues. O codigo MUST permanecer
estavel ainda que a mensagem mude.

#### Scenario: Erro de negocio e apresentado no formato uniforme

- **WHEN** uma operacao falha por regra de negocio
- **THEN** a resposta usa o formato estruturado e apresenta codigo de erro estavel

#### Scenario: Falha inesperada e apresentada no mesmo formato

- **WHEN** uma operacao falha por condicao inesperada
- **THEN** a resposta usa o mesmo formato estruturado, com codigo estavel proprio

#### Scenario: Mensagem alterada nao quebra o consumidor

- **WHEN** a mensagem legivel de um erro e reescrita
- **THEN** o codigo de erro permanece o mesmo, e o consumidor que depende dele nao
  e afetado

### Requirement: Distincao entre falha prevista e falha inesperada

Falha prevista de negocio SHALL ser apresentada como recusa atribuivel ao pedido.
Falha inesperada MUST ser apresentada como falha do sistema e MUST NOT expor
detalhe interno de implementacao, caminho de arquivo ou rastro de execucao.

#### Scenario: Recusa de negocio e atribuivel ao pedido

- **WHEN** o pedido viola uma regra de negocio conhecida
- **THEN** a resposta indica recusa atribuivel ao pedido, com codigo que
  identifica a regra violada

#### Scenario: Falha inesperada nao vaza detalhe interno

- **WHEN** ocorre uma falha inesperada
- **THEN** a resposta indica falha do sistema sem expor detalhe interno, e o
  diagnostico permanece disponivel na telemetria

#### Scenario: Falha inesperada e correlacionavel

- **WHEN** uma falha inesperada e retornada
- **THEN** a resposta carrega identificacao que permite localizar o registro
  correspondente na telemetria

### Requirement: Recusa de escrita concorrente conflitante

Quando uma alteracao e submetida sobre um estado que ja mudou desde a leitura, a
operacao SHALL ser recusada como conflito, com codigo estavel proprio. A alteracao
MUST NOT ser aplicada parcialmente.

#### Scenario: Alteracao sobre estado desatualizado e recusada

- **WHEN** duas alteracoes concorrentes partem da mesma leitura e a segunda e
  submetida apos a primeira ter sido aplicada
- **THEN** a segunda e recusada como conflito e nenhum efeito seu e persistido

#### Scenario: Conflito e distinguivel de erro de negocio

- **WHEN** uma operacao e recusada por conflito de escrita concorrente
- **THEN** o codigo de erro a distingue de qualquer recusa por regra de negocio

### Requirement: Validacao de entrada antes de qualquer efeito

Entrada malformada ou incompleta SHALL ser recusada antes que qualquer efeito seja
produzido. A resposta MUST identificar quais campos foram recusados e por que.

#### Scenario: Entrada invalida e recusada com detalhe por campo

- **WHEN** uma requisicao apresenta campos ausentes ou fora do formato esperado
- **THEN** ela e recusada e a resposta identifica cada campo recusado e o motivo

#### Scenario: Nenhum efeito e produzido por entrada invalida

- **WHEN** uma requisicao e recusada por validacao
- **THEN** nenhuma alteracao de estado e persistida

### Requirement: Envelope previsivel de listagem

Operacao que retorna colecao SHALL usar envelope uniforme, contendo os itens da
pagina e a informacao necessaria para percorrer o restante do resultado.

#### Scenario: Listagem retorna envelope uniforme

- **WHEN** uma colecao e consultada
- **THEN** a resposta apresenta os itens da pagina junto da informacao de
  totalizacao e de posicao no resultado

#### Scenario: Pagina alem do resultado e valida

- **WHEN** uma pagina posterior ao fim do resultado e solicitada
- **THEN** a resposta e bem-sucedida com colecao vazia, e nao um erro

### Requirement: Descricao navegavel da interface exposta

A aplicacao SHALL publicar uma descricao legivel por maquina das operacoes
expostas, mantida a partir da propria definicao das operacoes.

#### Scenario: Descricao reflete as operacoes existentes

- **WHEN** uma operacao e acrescentada ou alterada
- **THEN** a descricao publicada passa a refleti-la sem edicao manual separada

#### Scenario: Operacao exige identidade de forma visivel na descricao

- **WHEN** a descricao publicada e consultada
- **THEN** ela indica quais operacoes exigem identidade
