## Purpose

Garante que a estrutura de dados evolua sem interromper a versao em execucao,
tornando a compatibilidade retroativa uma exigencia verificada e nao uma
recomendacao, e impedindo que uma versao nova entre no ar sobre estrutura
incompativel.

## ADDED Requirements

### Requirement: Estrutura aplicada antes da troca da versao em execucao

A alteracao de estrutura de dados SHALL ser aplicada antes que a versao nova da
aplicacao passe a receber trabalho. A versao anterior MUST continuar em execucao
durante a aplicacao.

#### Scenario: Ordem observada em uma implantacao

- **WHEN** uma versao com alteracao de estrutura e implantada
- **THEN** a alteracao e aplicada enquanto a versao anterior ainda atende, e
  somente depois a versao nova passa a atender

#### Scenario: Versao anterior continua atendendo durante a aplicacao

- **WHEN** a alteracao de estrutura esta em andamento
- **THEN** requisicoes continuam sendo atendidas pela versao anterior

### Requirement: Aplicacao da estrutura ocorre uma unica vez por implantacao

A alteracao de estrutura SHALL ser executada uma unica vez por implantacao,
independentemente do numero de instancias da aplicacao. Instancias MUST NOT
disputar a aplicacao entre si.

#### Scenario: Multiplas instancias nao disputam a aplicacao

- **WHEN** a aplicacao e implantada com mais de uma instancia
- **THEN** a alteracao de estrutura e executada uma unica vez, e nenhuma instancia
  a executa no seu proprio inicio

#### Scenario: Reexecucao da implantacao nao repete efeito

- **WHEN** a mesma implantacao e executada novamente
- **THEN** a alteracao ja aplicada nao produz efeito adicional nem falha

### Requirement: Falha na alteracao de estrutura interrompe a implantacao

Se a alteracao de estrutura falha, a implantacao inteira SHALL falhar e a versao
anterior MUST permanecer em execucao. A versao nova MUST NOT passar a atender.

#### Scenario: Alteracao invalida impede a entrada da versao nova

- **WHEN** a alteracao de estrutura falha
- **THEN** a implantacao e reportada como falha e a versao anterior continua
  atendendo

#### Scenario: Causa da falha e identificavel

- **WHEN** a alteracao de estrutura falha
- **THEN** o registro da falha identifica a alteracao responsavel

### Requirement: Compatibilidade retroativa obrigatoria em cada release

Toda alteracao de estrutura SHALL ser compativel com a versao imediatamente
anterior da aplicacao. Em uma unica release MUST NOT ocorrer remocao de elemento
em uso, renomeacao de elemento em uso, introducao de obrigatoriedade sem valor
padrao, nem mudanca incompativel de tipo.

#### Scenario: Alteracao aditiva e aceita

- **WHEN** uma release acrescenta elemento novo sem tornar obrigatorio o que ja
  existia
- **THEN** a versao anterior continua operando corretamente sobre a estrutura nova

#### Scenario: Remocao em uso e recusada

- **WHEN** uma release remove elemento ainda utilizado pela versao anterior
- **THEN** isso e tratado como defeito e impede a aceitacao da alteracao

#### Scenario: Renomeacao ocorre em releases sucessivas

- **WHEN** um elemento precisa mudar de nome
- **THEN** a mudanca ocorre em releases sucessivas, mantendo os dois elementos
  disponiveis enquanto ambos os codigos puderem estar em execucao

#### Scenario: Janela de convivencia e exercitada

- **WHEN** a estrutura nova ja esta aplicada e a versao anterior ainda atende
- **THEN** as operacoes da versao anterior concluem sem erro

### Requirement: Isolamento da evolucao por modulo

A evolucao de estrutura SHALL ser tratada de forma independente por modulo, sem
que a alteracao de um exija a de outro.

#### Scenario: Modulo evolui isoladamente

- **WHEN** apenas um modulo possui alteracao de estrutura em uma release
- **THEN** somente ele e alterado, e os demais permanecem intactos

#### Scenario: Falha em um modulo nao aplica os demais parcialmente

- **WHEN** a alteracao de um modulo falha
- **THEN** a implantacao falha por inteiro, sem deixar a versao nova atendendo
  sobre estrutura parcialmente aplicada

### Requirement: Execucao autossuficiente da alteracao de estrutura

O mecanismo que aplica a alteracao de estrutura SHALL ser executavel sem exigir
ferramenta de desenvolvimento nem o ambiente de construcao do projeto.

#### Scenario: Alteracao executa sem ferramenta de desenvolvimento

- **WHEN** a alteracao de estrutura e executada no ambiente de implantacao
- **THEN** ela conclui sem exigir a instalacao de ferramenta de desenvolvimento
