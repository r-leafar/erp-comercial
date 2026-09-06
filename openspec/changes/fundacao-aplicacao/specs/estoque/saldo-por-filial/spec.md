## Purpose

Estabelece que o saldo de estoque existe sempre com recorte obrigatorio por
filial, e o disponibiliza para consulta, deixando toda movimentacao e todo
tratamento de custo para as changes seguintes do modulo.

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
