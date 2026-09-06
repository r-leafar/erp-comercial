## Purpose

Fornece armazenamento de objetos compativel com S3 para consumidores de
infraestrutura e de aplicacao, com provisionamento reproduzivel e um contrato de
acesso uniforme que mantem o backend substituivel entre ambientes.

## ADDED Requirements

### Requirement: Provisionamento idempotente de repositorios e credenciais

Os repositorios de objetos e as credenciais de acesso SHALL ser criados por um
procedimento idempotente executado como parte do bootstrap. Reexecutar o
procedimento MUST NOT falhar nem alterar objetos ja armazenados.

#### Scenario: Primeira execucao provisiona

- **WHEN** o procedimento roda em um armazenamento vazio
- **THEN** todos os repositorios e credenciais declarados passam a existir

#### Scenario: Reexecucao e inofensiva

- **WHEN** o procedimento roda novamente sobre armazenamento ja provisionado
- **THEN** conclui com sucesso, sem duplicar recursos e sem apagar ou alterar
  objetos existentes

#### Scenario: Consumidor nao cria seu proprio repositorio

- **WHEN** um consumidor e iniciado e o repositorio que ele usa nao existe
- **THEN** o consumidor falha de forma explicita, em vez de criar o repositorio
  por conta propria

### Requirement: Credencial com escopo minimo por consumidor

Cada consumidor SHALL possuir credencial propria, com permissao restrita apenas
aos repositorios que utiliza. Uma credencial MUST NOT conceder acesso a
repositorios de outros consumidores.

#### Scenario: Credencial acessa o proprio repositorio

- **WHEN** um consumidor usa sua credencial no repositorio a ele designado
- **THEN** as operacoes de leitura e escrita sao permitidas

#### Scenario: Credencial nao acessa repositorio alheio

- **WHEN** um consumidor tenta operar em repositorio designado a outro
  consumidor
- **THEN** a operacao e negada

### Requirement: Contrato uniforme de configuracao de acesso

Todo consumidor de armazenamento de objetos SHALL ser configurado pelo mesmo
conjunto de parametros: endereco do servico, regiao, credencial, repositorio,
forma de enderecamento e uso de canal seguro. Endereco de servico MUST NOT ser
fixado no artefato do consumidor.

#### Scenario: Mesmo conjunto de parametros para consumidores diferentes

- **WHEN** um novo consumidor de armazenamento e adicionado
- **THEN** ele e configurado pelo mesmo conjunto de parametros ja usado pelos
  demais

#### Scenario: Troca de backend entre ambientes altera apenas configuracao

- **WHEN** o ambiente usa um provedor de armazenamento diferente
- **THEN** apenas os valores de configuracao mudam, sem alteracao no artefato do
  consumidor

#### Scenario: Forma de enderecamento acompanha o provedor

- **WHEN** o provedor exige enderecamento por caminho em vez de por subdominio
- **THEN** isso e expresso como configuracao, e o consumidor opera normalmente

### Requirement: Uso restrito ao subconjunto comum da API de objetos

Os consumidores SHALL utilizar apenas operacoes basicas de objeto: escrita,
leitura, remocao, listagem, consulta de metadados, envio particionado e geracao
de acesso temporario assinado. Uso de recurso fora desse subconjunto MUST exigir
decisao registrada, por reduzir o conjunto de provedores possiveis.

#### Scenario: Backend com apenas o subconjunto comum atende todos

- **WHEN** o armazenamento oferece somente as operacoes basicas de objeto
- **THEN** todos os consumidores da plataforma funcionam sem degradacao

#### Scenario: Recurso adicional exige decisao explicita

- **WHEN** um consumidor precisa de recurso fora do subconjunto comum, como
  versionamento, retencao imutavel ou regras de expiracao
- **THEN** a dependencia e registrada como decisao, junto com o efeito sobre os
  provedores admissiveis
