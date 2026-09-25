## Purpose

Estabelece que o saldo de estoque existe sempre com recorte obrigatorio por
filial, respeitando o escopo de disponibilidade do produto entre filiais, e o
disponibiliza para consulta, deixando toda movimentacao e todo tratamento de
custo para as changes seguintes do modulo.

## ADDED Requirements

### Requirement: Saldo identificado por produto e filial

O saldo SHALL ser identificado pela combinacao de produto e filial. Saldo sem
filial associada MUST NOT existir.

#### Scenario: Saldo existe por filial

- **WHEN** o saldo de um produto e consultado em duas filiais diferentes
- **THEN** cada filial apresenta o seu proprio saldo, de forma independente

#### Scenario: Saldo sem filial e recusado

- **WHEN** um saldo e submetido sem filial associada
- **THEN** a operacao e recusada

#### Scenario: Combinacao repetida e recusada

- **WHEN** um saldo e criado para uma combinacao de produto e filial ja existente
- **THEN** a operacao e recusada, preservando o registro existente

### Requirement: Saldo respeita o escopo do produto entre filiais

O saldo SHALL ser criado apenas em filial compativel com o escopo do produto: se
o produto e `Corporativo`, qualquer filial da mesma empresa do produto e
compativel; se e `FiliaisEspecificas`, apenas as filiais explicitamente
associadas a ele o sao.

#### Scenario: Saldo aceito em filial compativel com produto corporativo

- **WHEN** um saldo e criado para um produto `Corporativo` em uma filial da
  mesma empresa do produto
- **THEN** a operacao e aceita

#### Scenario: Saldo aceito em filial associada a produto de filiais especificas

- **WHEN** um saldo e criado para um produto `FiliaisEspecificas` em uma filial
  explicitamente associada a ele
- **THEN** a operacao e aceita

#### Scenario: Saldo recusado em filial fora do escopo do produto

- **WHEN** um saldo e criado para um produto `FiliaisEspecificas` em uma filial
  nao associada a ele
- **THEN** a operacao e recusada com erro de negocio identificavel

### Requirement: Referencia a produto e a filial apenas por identificacao

O saldo SHALL referenciar produto e filial apenas pelas suas identificacoes, sem
copia dos seus dados e sem vinculo de integridade entre as estruturas dos modulos.

#### Scenario: Referencias sao apenas identificacoes

- **WHEN** o registro de saldo e inspecionado
- **THEN** ele contem apenas as identificacoes de produto e de filial

#### Scenario: Dado descritivo vem do modulo dono

- **WHEN** a consulta de saldo precisa apresentar dado descritivo do produto
- **THEN** ele e obtido pela interface publica do cadastro, e nao de copia local

### Requirement: Consulta de saldo restrita a filial da identidade

A consulta de saldo SHALL retornar apenas dados de filiais pertencentes a
identidade que a solicita.

#### Scenario: Consulta em filial pertencente a identidade

- **WHEN** o saldo e consultado em filial presente no conjunto de filiais da
  identidade
- **THEN** o resultado e retornado

#### Scenario: Consulta em filial nao pertencente a identidade

- **WHEN** o saldo e consultado em filial ausente do conjunto de filiais da
  identidade
- **THEN** a consulta e recusada, sem revelar a existencia do dado

### Requirement: Ausencia de movimentacao nesta capacidade

Esta capacidade SHALL abranger apenas a existencia e a consulta do saldo. Operacao
de movimentacao, reserva, transferencia entre filiais ou apuracao de custo MUST
NOT ser oferecida aqui.

#### Scenario: Nenhuma operacao de movimentacao e exposta

- **WHEN** as operacoes disponiveis do modulo de estoque sao inspecionadas
- **THEN** nenhuma delas altera saldo por movimentacao, reserva ou transferencia

#### Scenario: Consulta de saldo inexistente

- **WHEN** o saldo de uma combinacao de produto e filial ainda nao registrada e
  consultado
- **THEN** a resposta indica ausencia de registro, de forma distinguivel de saldo
  igual a zero
