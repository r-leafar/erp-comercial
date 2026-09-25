## Purpose

Estabelece o produto vinculado a uma empresa, com codigo unico dentro dela e
escopo obrigatorio de disponibilidade por filial (corporativo ou filiais
especificas), disponivel para consulta pelos demais modulos por interface
publica em vez de acesso direto aos seus dados.

## ADDED Requirements

### Requirement: Produto pertence a uma empresa, com codigo unico dentro dela

O produto SHALL pertencer a exatamente uma empresa desde a sua criacao. Seu
codigo MUST ser unico dentro da empresa a que pertence, e fica disponivel para
consulta nas filiais dessa empresa compativeis com o seu escopo.

#### Scenario: Produto e cadastrado com codigo unico na empresa

- **WHEN** um produto e cadastrado com codigo ainda nao utilizado na sua empresa
- **THEN** ele passa a existir e fica disponivel para consulta nas filiais da
  empresa compativeis com o seu escopo

#### Scenario: Codigo repetido na mesma empresa e recusado

- **WHEN** um produto e cadastrado com codigo ja utilizado por outro produto da
  mesma empresa
- **THEN** a operacao e recusada com erro de negocio identificavel, mesmo que a
  operacao tenha sido originada em outra filial dessa empresa

#### Scenario: Mesmo codigo em empresa diferente e aceito

- **WHEN** um produto e cadastrado com codigo ja utilizado, mas por um produto de
  outra empresa
- **THEN** o cadastro e aceito normalmente, sem conflito

#### Scenario: Entrada invalida e recusada antes de qualquer efeito

- **WHEN** um produto e submetido sem os dados obrigatorios
- **THEN** a operacao e recusada por validacao e nenhum registro e criado

### Requirement: Escopo obrigatorio do produto: corporativo ou filiais especificas

O produto SHALL possuir um escopo, escolhido de forma obrigatoria na criacao,
com exatamente dois valores possiveis: `Corporativo` ou `FiliaisEspecificas`.
Produto sem escopo definido MUST NOT existir.

#### Scenario: Escopo corporativo alcanca toda filial da empresa

- **WHEN** um produto e cadastrado com escopo `Corporativo`
- **THEN** ele fica disponivel em todas as filiais da empresa, inclusive filiais
  criadas depois do cadastro, sem nenhuma acao adicional

#### Scenario: Escopo de filiais especificas exige ao menos uma filial

- **WHEN** um produto e cadastrado com escopo `FiliaisEspecificas`
- **THEN** ele exige ao menos uma filial associada, e a operacao e recusada se
  nenhuma filial for indicada

#### Scenario: Filial associada deve pertencer a mesma empresa do produto

- **WHEN** uma filial de empresa diferente da do produto e associada a um
  produto `FiliaisEspecificas`
- **THEN** a associacao e recusada com erro de negocio identificavel

#### Scenario: Produto de filiais especificas fica disponivel so nas filiais associadas

- **WHEN** um produto com escopo `FiliaisEspecificas` e consultado quanto a
  disponibilidade
- **THEN** apenas as filiais explicitamente associadas a ele o apresentam como
  disponivel

#### Scenario: Remover a ultima filial associada e recusado

- **WHEN** a remocao da ultima filial associada a um produto `FiliaisEspecificas`
  e solicitada
- **THEN** a operacao e recusada com erro de negocio identificavel, e o produto
  nao passa a `Corporativo` por esvaziamento

#### Scenario: Troca de escopo e acao explicita

- **WHEN** o escopo de um produto e alterado para `Corporativo`
- **THEN** a alteracao ocorre como acao propria e deliberada, nunca inferida pela
  ausencia de filiais associadas

#### Scenario: Remover filial associada com saldo existente e recusado

- **WHEN** a remocao de uma filial do conjunto associado a um produto
  `FiliaisEspecificas` e solicitada e ja existe saldo de estoque registrado para
  aquele produto naquela filial
- **THEN** a operacao e recusada com erro de negocio identificavel

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
