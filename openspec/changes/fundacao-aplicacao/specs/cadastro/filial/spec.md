## Purpose

Estabelece a filial como entidade global do cadastro e como unidade de recorte
usada pelos demais modulos, que a referenciam apenas por identificacao e nunca por
copia dos seus dados.

## ADDED Requirements

### Requirement: Filial e entidade global do cadastro

A filial SHALL ser cadastrada de forma global, sem recorte por outra filial. Seu
codigo MUST ser unico em todo o cadastro.

#### Scenario: Filial e cadastrada com codigo unico

- **WHEN** uma filial e cadastrada com codigo ainda nao utilizado
- **THEN** ela passa a existir e fica disponivel para consulta

#### Scenario: Codigo repetido e recusado

- **WHEN** uma filial e cadastrada com codigo ja utilizado por outra
- **THEN** a operacao e recusada com erro de negocio identificavel

### Requirement: Identificacao estavel referenciada pelos demais modulos

A filial SHALL possuir identificacao estavel, e os demais modulos MUST
referencia-la apenas por essa identificacao, sem manter copia dos seus dados nem
depender da estrutura interna do cadastro.

#### Scenario: Outro modulo referencia a filial por identificacao

- **WHEN** outro modulo precisa registrar a filial de origem de um dado
- **THEN** ele armazena apenas a identificacao da filial

#### Scenario: Identificacao nao muda ao alterar a filial

- **WHEN** os dados descritivos de uma filial sao alterados
- **THEN** sua identificacao permanece a mesma, e as referencias existentes
  continuam validas

#### Scenario: Consulta de dados da filial vem do cadastro

- **WHEN** outro modulo precisa dos dados descritivos de uma filial
- **THEN** ele os obtem do cadastro pela interface publica, e nao de copia propria

### Requirement: Inativacao em lugar de remocao

A filial SHALL ser inativada em vez de removida, preservando a validade das
referencias ja registradas por outros modulos.

#### Scenario: Filial inativada preserva referencias existentes

- **WHEN** uma filial e inativada
- **THEN** ela deixa de aparecer nas consultas padrao e os dados que a referenciam
  permanecem integros e consultaveis

#### Scenario: Filial inativa nao e aceita em operacao nova

- **WHEN** uma operacao indica filial inativa
- **THEN** ela e recusada com erro de negocio identificavel

### Requirement: Consulta de filiais

As filiais SHALL estar disponiveis para consulta, individualmente pela sua
identificacao e em listagem com o envelope uniforme de paginacao.

#### Scenario: Consulta individual

- **WHEN** uma filial existente e consultada pela sua identificacao
- **THEN** seus dados sao retornados

#### Scenario: Consulta de filial inexistente

- **WHEN** uma identificacao inexistente e consultada
- **THEN** a resposta indica ausencia, sem revelar detalhe interno

#### Scenario: Listagem paginada

- **WHEN** as filiais sao listadas
- **THEN** a resposta usa o envelope uniforme de paginacao
