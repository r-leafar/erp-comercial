## Purpose

Estabelece a empresa como topo da hierarquia do cadastro — a unidade que
possui filiais e da qual filial e produto herdam o escopo de unicidade de
codigo — e como identificacao estavel referenciada por filial e produto.

## ADDED Requirements

### Requirement: Empresa e entidade global do cadastro, com codigo unico

A empresa SHALL ser cadastrada de forma global. Seu codigo MUST ser unico em
todo o cadastro, sem recorte por nenhuma outra entidade — nao ha nada acima
dela na hierarquia.

#### Scenario: Empresa e cadastrada com codigo unico

- **WHEN** uma empresa e cadastrada com codigo ainda nao utilizado
- **THEN** ela passa a existir e fica disponivel para consulta

#### Scenario: Codigo repetido e recusado

- **WHEN** uma empresa e cadastrada com codigo ja utilizado por outra
- **THEN** a operacao e recusada com erro de negocio identificavel

### Requirement: Identificacao estavel referenciada por filial e produto

A empresa SHALL possuir identificacao estavel. Filial e produto MUST
referencia-la apenas por essa identificacao (`EmpresaId`), sem copia dos seus
dados e sem que o vinculo seja codificado dentro de outro identificador.

#### Scenario: Filial e produto referenciam a empresa por identificacao

- **WHEN** uma filial ou um produto e cadastrado
- **THEN** ele armazena apenas a identificacao da empresa a que pertence

#### Scenario: Identificacao nao muda ao alterar a empresa

- **WHEN** os dados descritivos de uma empresa sao alterados
- **THEN** sua identificacao permanece a mesma, e as filiais e produtos que a
  referenciam continuam validos

### Requirement: Inativacao em lugar de remocao

A empresa SHALL ser inativada em vez de removida, preservando a validade das
filiais e produtos ja registrados sob ela.

#### Scenario: Empresa inativada preserva filiais e produtos existentes

- **WHEN** uma empresa e inativada
- **THEN** ela deixa de aparecer nas consultas padrao e as filiais e produtos
  que a referenciam permanecem integros e consultaveis

#### Scenario: Empresa inativa nao e aceita em operacao nova

- **WHEN** uma operacao indica empresa inativa
- **THEN** ela e recusada com erro de negocio identificavel

### Requirement: Consulta de empresas

As empresas SHALL estar disponiveis para consulta, individualmente pela sua
identificacao e em listagem com o envelope uniforme de paginacao.

#### Scenario: Consulta individual

- **WHEN** uma empresa existente e consultada pela sua identificacao
- **THEN** seus dados sao retornados

#### Scenario: Consulta de empresa inexistente

- **WHEN** uma identificacao inexistente e consultada
- **THEN** a resposta indica ausencia, sem revelar detalhe interno

#### Scenario: Listagem paginada

- **WHEN** as empresas sao listadas
- **THEN** a resposta usa o envelope uniforme de paginacao
