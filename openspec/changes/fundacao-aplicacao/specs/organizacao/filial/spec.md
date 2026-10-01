## Purpose

Estabelece a filial vinculada a uma empresa e como unidade de recorte usada
pelos demais modulos, que a referenciam apenas por identificacao e nunca por
copia dos seus dados.

## ADDED Requirements

### Requirement: Filial pertence a uma empresa, com codigo unico dentro dela

A filial SHALL pertencer a exatamente uma empresa desde a sua criacao. Seu
codigo MUST ser unico dentro da empresa a que pertence, sem recorte por outra
filial da mesma empresa.

#### Scenario: Filial e cadastrada com codigo unico na empresa

- **WHEN** uma filial e cadastrada com codigo ainda nao utilizado na sua empresa
- **THEN** ela passa a existir e fica disponivel para consulta

#### Scenario: Codigo repetido na mesma empresa e recusado

- **WHEN** uma filial e cadastrada com codigo ja utilizado por outra filial da
  mesma empresa
- **THEN** a operacao e recusada com erro de negocio identificavel

#### Scenario: Mesmo codigo em empresa diferente e aceito

- **WHEN** uma filial e cadastrada com codigo ja utilizado, mas por uma filial de
  outra empresa
- **THEN** o cadastro e aceito normalmente, sem conflito

### Requirement: Identificacao estavel referenciada pelos demais modulos

A filial SHALL possuir identificacao estavel, e os demais modulos MUST
referencia-la apenas por essa identificacao, sem manter copia dos seus dados nem
depender da estrutura interna de Organizacao.

#### Scenario: Outro modulo referencia a filial por identificacao

- **WHEN** outro modulo precisa registrar a filial de origem de um dado
- **THEN** ele armazena apenas a identificacao da filial

#### Scenario: Identificacao nao muda ao alterar a filial

- **WHEN** os dados descritivos de uma filial sao alterados
- **THEN** sua identificacao permanece a mesma, e as referencias existentes
  continuam validas

#### Scenario: Consulta de dados da filial vem de Organizacao

- **WHEN** outro modulo precisa dos dados descritivos de uma filial
- **THEN** ele os obtem de `Organizacao.Contracts`, e nao de copia propria

### Requirement: Consulta de empresa e situacao da filial por interface publica

`Organizacao.Contracts` SHALL expor consulta que, dada uma filial, informe a
empresa a que pertence e se ela esta ativa, para que outros modulos verifiquem
suas regras sem depender da estrutura interna.

#### Scenario: Modulo consulta a empresa de uma filial

- **WHEN** outro modulo consulta uma filial existente pela interface publica
- **THEN** recebe o identificador da empresa e a situacao ativa ou inativa

#### Scenario: Filial inexistente e distinguida de filial inativa

- **WHEN** outro modulo consulta uma filial que nao existe
- **THEN** a resposta a distingue de uma filial inativa

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
