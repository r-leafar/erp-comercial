## Purpose

Estabelece o produto como cadastro global da empresa, com codigo unico e sem
recorte por filial, disponivel para consulta pelos demais modulos por interface
publica em vez de acesso direto aos seus dados.

## ADDED Requirements

### Requirement: Cadastro global de produto

O produto SHALL ser cadastrado de forma global, valido para toda a empresa. Seu
codigo MUST ser unico em todo o cadastro, sem recorte por filial.

#### Scenario: Produto e cadastrado com codigo unico

- **WHEN** um produto e cadastrado com codigo ainda nao utilizado
- **THEN** ele passa a existir e fica disponivel para consulta em qualquer filial

#### Scenario: Codigo repetido e recusado

- **WHEN** um produto e cadastrado com codigo ja utilizado
- **THEN** a operacao e recusada com erro de negocio identificavel, mesmo que a
  operacao tenha sido originada em outra filial

#### Scenario: Entrada invalida e recusada antes de qualquer efeito

- **WHEN** um produto e submetido sem os dados obrigatorios
- **THEN** a operacao e recusada por validacao e nenhum registro e criado

### Requirement: Alteracao de produto com concorrencia controlada

O produto SHALL poder ser alterado, e alteracao submetida sobre estado ja
modificado desde a leitura MUST ser recusada como conflito.

#### Scenario: Alteracao aplicada

- **WHEN** um produto existente e alterado a partir do seu estado atual
- **THEN** a alteracao e persistida e a autoria e o instante ficam registrados

#### Scenario: Alteracao concorrente e recusada

- **WHEN** duas alteracoes partem da mesma leitura e a segunda e submetida depois
  de a primeira ter sido aplicada
- **THEN** a segunda e recusada como conflito, sem efeito parcial

### Requirement: Inativacao em lugar de remocao

O produto SHALL ser inativado em vez de removido, preservando os registros
historicos que o referenciam.

#### Scenario: Produto inativado sai das consultas padrao

- **WHEN** um produto e inativado
- **THEN** ele deixa de aparecer nas consultas padrao e permanece armazenado

#### Scenario: Produto inativo nao e aceito em operacao nova

- **WHEN** uma operacao nova indica produto inativo
- **THEN** ela e recusada com erro de negocio identificavel

### Requirement: Consulta de produtos

Os produtos SHALL estar disponiveis para consulta individual pela sua
identificacao e em listagem com o envelope uniforme de paginacao.

#### Scenario: Consulta individual

- **WHEN** um produto existente e consultado
- **THEN** seus dados sao retornados

#### Scenario: Listagem paginada

- **WHEN** os produtos sao listados
- **THEN** a resposta usa o envelope uniforme de paginacao e contem apenas ativos,
  salvo pedido explicito em contrario

### Requirement: Acesso de outros modulos por interface publica

Outro modulo que precise de dado de produto SHALL obte-lo pela interface publica
do cadastro. Acesso direto a estrutura de dados do cadastro MUST NOT ocorrer, e
nao MUST existir vinculo de integridade entre as estruturas dos modulos.

#### Scenario: Modulo consulta produto pela interface publica

- **WHEN** outro modulo precisa verificar a existencia de um produto
- **THEN** ele consulta a interface publica do cadastro

#### Scenario: Ausencia de vinculo entre estruturas de modulos

- **WHEN** as estruturas de dados dos modulos sao inspecionadas
- **THEN** nenhum vinculo de integridade atravessa a fronteira entre elas; apenas
  a identificacao e armazenada
