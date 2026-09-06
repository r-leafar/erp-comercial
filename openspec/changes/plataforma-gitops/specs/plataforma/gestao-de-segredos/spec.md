## Purpose

Permite que segredos sejam versionados junto com o restante da configuracao sem
expor material sensivel, e garante que a capacidade de decifrar sobreviva a
recriacao do ambiente, preservando a promessa de reproducao a partir do zero.

## ADDED Requirements

### Requirement: Segredo versionado apenas em forma cifrada

Material sensivel SHALL ser versionado no repositorio somente em forma cifrada.
Valor de segredo em texto claro MUST NOT ser aceito em nenhum artefato
versionado da plataforma.

#### Scenario: Material cifrado e decifrado no ambiente

- **WHEN** um segredo cifrado versionado e aplicado ao ambiente
- **THEN** ele fica disponivel as cargas de trabalho em forma utilizavel

#### Scenario: Texto claro nao passa

- **WHEN** um artefato versionado contem valor de segredo em texto claro
- **THEN** isso e tratado como defeito e impede a aceitacao da alteracao

#### Scenario: Conteudo cifrado nao revela o segredo

- **WHEN** o repositorio e lido por quem nao tem acesso ao ambiente
- **THEN** o material versionado nao permite recuperar o valor original

### Requirement: Consumo de segredo por referencia

Cargas de trabalho SHALL obter segredos por referencia a um recurso de segredo do
ambiente. Valor sensivel MUST NOT ser embutido diretamente na definicao da carga
de trabalho nem na imagem.

#### Scenario: Carga de trabalho le por referencia

- **WHEN** um componente precisa de credencial
- **THEN** ele a obtem do recurso de segredo referenciado, e nao de valor fixo
  na sua propria definicao

#### Scenario: Trocar a origem do segredo nao altera a carga de trabalho

- **WHEN** o mecanismo que produz o segredo e substituido
- **THEN** a definicao da carga de trabalho permanece inalterada

### Requirement: Capacidade de decifrar sobrevive a recriacao do ambiente

O material necessario para decifrar os segredos versionados SHALL fazer parte do
procedimento de bootstrap. Recriar o ambiente MUST NOT invalidar os segredos ja
versionados no repositorio.

#### Scenario: Ambiente recriado continua decifrando o que ja existe

- **WHEN** o ambiente e destruido e recriado pelo procedimento de bootstrap
- **THEN** os segredos cifrados ja versionados continuam sendo decifrados com
  sucesso

#### Scenario: Ausencia do material de decifragem falha de forma explicita

- **WHEN** o material de decifragem nao esta disponivel no ambiente
- **THEN** a falha e reportada de forma diagnosticavel, identificando a causa,
  em vez de deixar cargas de trabalho aguardando indefinidamente

### Requirement: Vinculo do segredo cifrado ao seu destino

O material cifrado SHALL estar vinculado ao identificador e ao espaco de nomes de
destino. Mover ou renomear o destino MUST invalidar a decifragem, em vez de
permitir que o segredo seja lido em contexto diferente do pretendido.

#### Scenario: Destino alterado invalida a decifragem

- **WHEN** um segredo cifrado e apontado para identificador ou espaco de nomes
  diferente do original
- **THEN** a decifragem falha
