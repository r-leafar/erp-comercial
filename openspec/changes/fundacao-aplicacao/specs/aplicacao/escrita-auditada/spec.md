## Purpose

Garante que toda alteracao de dado persistido carregue quem a originou e quando
ocorreu, sem depender de o codigo de negocio lembrar de registrar isso, e que o
cadastro preserve historico em vez de remover registros.

## ADDED Requirements

### Requirement: Autoria e instante registrados automaticamente

Toda entidade persistida SHALL registrar quem a criou e quando, e quem a alterou
por ultimo e quando. Esses valores MUST ser preenchidos pelo mecanismo de
persistencia, sem participacao do codigo de negocio.

#### Scenario: Criacao registra autoria e instante

- **WHEN** uma entidade e criada e persistida
- **THEN** o identificador do usuario que originou a acao e o instante da criacao
  ficam registrados

#### Scenario: Alteracao registra autoria e instante

- **WHEN** uma entidade existente e alterada e persistida
- **THEN** o identificador do usuario que originou a acao e o instante da
  alteracao ficam registrados, preservando os dados de criacao

#### Scenario: Codigo de negocio nao preenche autoria

- **WHEN** um caso de uso persiste uma entidade sem tratar autoria
- **THEN** os valores de autoria e instante ainda assim ficam registrados

### Requirement: Autoria sempre atribuida a um usuario

O registro de autoria SHALL conter o identificador do usuario que originou a
acao. Valor generico que represente o proprio sistema MUST NOT ser usado quando
existe um usuario originador.

#### Scenario: Origem e uma operacao exposta

- **WHEN** a alteracao decorre de uma requisicao com identidade
- **THEN** a autoria registrada e a do usuario dessa identidade

#### Scenario: Contexto de execucao ausente impede a escrita

- **WHEN** uma escrita e tentada sem contexto de usuario disponivel
- **THEN** a escrita e recusada, em vez de registrar autoria generica

### Requirement: Instante registrado em referencia unica de tempo

Todo instante persistido SHALL ser registrado com referencia de tempo unica e
independente do fuso do emissor.

#### Scenario: Instantes sao comparaveis entre origens

- **WHEN** alteracoes originadas em contextos com fusos diferentes sao
  persistidas
- **THEN** seus instantes sao diretamente comparaveis e ordenaveis

### Requirement: Cadastro sem remocao fisica

Registro de cadastro SHALL ser inativado em vez de removido. Consulta padrao MUST
retornar apenas registros ativos, e a inclusao dos inativos MUST ser explicita.

#### Scenario: Inativacao preserva o registro

- **WHEN** um registro de cadastro e inativado
- **THEN** ele deixa de aparecer nas consultas padrao e permanece armazenado

#### Scenario: Consulta padrao omite inativos

- **WHEN** uma consulta de cadastro e realizada sem pedido explicito de inativos
- **THEN** apenas registros ativos sao retornados

#### Scenario: Inativos podem ser consultados explicitamente

- **WHEN** uma consulta pede explicitamente a inclusao de inativos
- **THEN** os registros inativos sao retornados e identificados como tal

### Requirement: Contexto de execucao uniforme entre origens

O contexto que fornece usuario e filial as operacoes SHALL ser o mesmo qualquer
que seja a origem da execucao. O codigo de negocio MUST NOT distinguir origem para
obte-lo.

#### Scenario: Caso de uso nao distingue origem

- **WHEN** um caso de uso obtem usuario e filial do contexto de execucao
- **THEN** ele obtem os mesmos valores independentemente de como a execucao foi
  iniciada
