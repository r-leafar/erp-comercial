# Spec Delta

## Purpose

Permite que uma pessoa anonima crie, por conta propria, uma conta, uma empresa
nova e o primeiro usuario administrador dessa empresa, com um periodo de teste
iniciado automaticamente, sem intervencao manual de ninguem da operacao.

## ADDED Requirements

### Requirement: Pagina publica de apresentacao acessivel sem autenticacao

A aplicacao SHALL expor uma pagina publica que apresenta o produto e oferece o
inicio do periodo de teste, acessivel sem identidade previa.

#### Scenario: Pagina publica acessivel sem login

- **WHEN** uma pessoa anonima acessa a pagina de apresentacao
- **THEN** a pagina e exibida sem exigir identidade

#### Scenario: Chamada para acao leva ao auto-cadastro

- **WHEN** a pessoa aciona o inicio do teste gratuito na pagina publica
- **THEN** ela e conduzida ao fluxo de auto-cadastro

### Requirement: Auto-cadastro cria conta, empresa e administrador em uma unica operacao

O auto-cadastro SHALL criar, a partir dos dados minimos submetidos por uma
pessoa anonima, uma identidade, uma empresa nova e o vinculo entre elas como
administradora, como um unico efeito atomico. Falha em qualquer parte MUST NOT
deixar conta ou empresa orfa.

#### Scenario: Auto-cadastro bem-sucedido

- **WHEN** uma pessoa anonima submete os dados minimos exigidos (nome, email,
  senha e nome da empresa)
- **THEN** a conta, a empresa e o vinculo de administracao passam a existir, e
  a pessoa consegue acessar a empresa imediatamente, sem etapa manual adicional

#### Scenario: Dados obrigatorios ausentes sao recusados

- **WHEN** o auto-cadastro e submetido sem um dos dados minimos exigidos
- **THEN** a operacao e recusada por validacao, e nenhum efeito e produzido

#### Scenario: Falha no meio do processo nao deixa efeito parcial

- **WHEN** a criacao falha depois de parte do efeito ja ter sido processada
- **THEN** nenhuma conta, empresa ou vinculo de administracao orfa permanece
  visivel ao sistema

### Requirement: Email unico entre contas

O email usado no auto-cadastro SHALL ser unico entre todas as contas, sem
recorte por empresa — a conta identifica uma pessoa, nao uma empresa.

#### Scenario: Email ja utilizado e recusado

- **WHEN** o auto-cadastro e submetido com um email ja associado a uma conta
  existente
- **THEN** a operacao e recusada com erro de negocio identificavel, e nenhuma
  empresa nova e criada

### Requirement: Administrador recebe o papel AdminEmpresa da empresa criada

A pessoa que completa o auto-cadastro SHALL receber o papel `AdminEmpresa`
com escopo na empresa recem-criada, habilitando o mecanismo de resolucao
dinamica de filial ja definido em `aplicacao/autenticacao-e-autorizacao`.

#### Scenario: Administrador acessa filial cadastrada apos o auto-cadastro

- **WHEN** o administrador de uma empresa recem-criada cadastra a primeira
  filial e em seguida requisita uma operacao sobre ela
- **THEN** a operacao prossegue, sem exigir nenhuma etapa manual de concessao
  de acesso

#### Scenario: Administrador nao acessa outra empresa por padrao

- **WHEN** o administrador de uma empresa requisita operacao sobre filial de
  empresa diferente da que ele criou
- **THEN** a operacao e recusada sem produzir efeito nem revelar a existencia
  da filial

### Requirement: Periodo de teste iniciado automaticamente pelo auto-cadastro

Toda empresa criada por auto-cadastro SHALL iniciar com um periodo de teste
ativo desde a sua criacao, com estado consultavel pelo administrador a
qualquer momento.

#### Scenario: Periodo de teste comeca junto com a empresa

- **WHEN** uma empresa e criada por auto-cadastro
- **THEN** ela tem um periodo de teste ativo desde o instante da criacao,
  sem acao adicional do administrador

#### Scenario: Estado do periodo de teste e consultavel

- **WHEN** o administrador consulta os dados da propria empresa
- **THEN** o estado do periodo de teste (ativo ou expirado) esta disponivel
  na resposta

### Requirement: Escrita bloqueada apos expiracao do periodo de teste, leitura preservada

Empresa com periodo de teste expirado SHALL recusar toda operacao de escrita
em qualquer modulo. Consulta e listagem MUST continuar disponiveis, sem perda
nem ocultacao de dado ja cadastrado.

#### Scenario: Escrita recusada apos expiracao

- **WHEN** uma operacao de escrita e requisitada por usuario de empresa com
  periodo de teste expirado
- **THEN** a operacao e recusada com erro de negocio identificavel, e nenhum
  efeito e produzido

#### Scenario: Leitura preservada apos expiracao

- **WHEN** uma consulta ou listagem e requisitada por usuario de empresa com
  periodo de teste expirado
- **THEN** o dado e retornado normalmente, sem restricao adicional

#### Scenario: Reativacao remove o bloqueio de escrita

- **WHEN** o periodo de teste de uma empresa expirada e reativado
- **THEN** operacoes de escrita voltam a ser aceitas normalmente
