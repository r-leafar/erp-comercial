## Purpose

Garante que toda operacao exposta pela aplicacao seja atribuivel a um usuario
identificado e restrita as filiais que ele possui, e que a substituicao futura do
emissor de identidade nao alcance nenhuma regra de autorizacao ja escrita.

## ADDED Requirements

### Requirement: Identidade exigida nas operacoes expostas

Toda operacao exposta SHALL exigir identidade valida, salvo operacoes
explicitamente declaradas como publicas. Requisicao sem identidade valida MUST ser
recusada sem executar efeito algum.

#### Scenario: Requisicao sem identidade e recusada

- **WHEN** uma operacao protegida e requisitada sem identidade
- **THEN** a requisicao e recusada e nenhum efeito e produzido

#### Scenario: Identidade invalida ou expirada e recusada

- **WHEN** a identidade apresentada esta expirada, adulterada ou foi emitida por
  origem nao reconhecida
- **THEN** a requisicao e recusada

#### Scenario: Validacao nao depende de consulta externa por requisicao

- **WHEN** uma requisicao com identidade valida e processada
- **THEN** a validacao ocorre localmente, sem chamada ao emissor a cada
  requisicao

### Requirement: Contrato interno de identidade estavel

A aplicacao SHALL converter a identidade apresentada, qualquer que seja o formato
do emissor, para um contrato interno estavel contendo o identificador do usuario,
o conjunto de filiais que ele possui e o conjunto de perfis. As regras de
autorizacao MUST consumir apenas esse contrato interno.

#### Scenario: Formato aninhado do emissor e normalizado

- **WHEN** a identidade apresenta perfis em estrutura aninhada e filiais em
  atributo multivalorado
- **THEN** eles ficam disponiveis no contrato interno de forma uniforme

#### Scenario: Troca de emissor nao altera regras de autorizacao

- **WHEN** o emissor de identidade e substituido por outro que produz formato
  diferente
- **THEN** as regras de autorizacao permanecem inalteradas, e apenas a conversao
  para o contrato interno e ajustada

#### Scenario: Identidade sem os atributos exigidos e recusada

- **WHEN** a identidade nao contem identificador de usuario ou nao contem filial
  alguma
- **THEN** a requisicao e recusada, em vez de prosseguir com contexto vazio

### Requirement: Restricao de acesso a filial do usuario

Operacao que atue sobre uma filial SHALL ser permitida apenas quando a filial
indicada pertencer ao conjunto de filiais da identidade. Filial MUST ser tratada
como atributo do usuario, e nao como perfil.

#### Scenario: Filial pertencente ao usuario e aceita

- **WHEN** a operacao indica filial presente no conjunto de filiais da identidade
- **THEN** a operacao prossegue

#### Scenario: Filial nao pertencente ao usuario e recusada

- **WHEN** a operacao indica filial ausente do conjunto de filiais da identidade
- **THEN** a operacao e recusada sem produzir efeito nem revelar a existencia da
  filial

#### Scenario: Ausencia de filial indicada e recusada

- **WHEN** uma operacao que exige recorte por filial nao indica filial alguma
- **THEN** a requisicao e recusada por entrada invalida

### Requirement: Acesso do administrador de empresa resolvido dinamicamente por filial

O usuario com o papel `AdminEmpresa` de uma empresa SHALL ter acesso a toda
filial que pertenca a essa empresa, resolvido no momento da autorizacao a
partir da interface publica de `organizacao/filial`, e nao a partir da lista fixa
de filiais do contrato interno. Este mecanismo convive com a lista fixa sem
substitui-la: um usuario pode ter as duas formas de acesso ao mesmo tempo.

#### Scenario: AdminEmpresa acessa filial cadastrada apos a emissao do token

- **WHEN** um usuario com papel `AdminEmpresa` da empresa X requisita operacao
  sobre uma filial pertencente a empresa X, criada depois da emissao do seu
  token
- **THEN** a operacao prossegue, sem exigir reemissao do token

#### Scenario: AdminEmpresa nao acessa filial de outra empresa

- **WHEN** um usuario com papel `AdminEmpresa` da empresa X requisita operacao
  sobre filial pertencente a empresa diferente de X, e essa filial nao esta na
  sua lista fixa de filiais
- **THEN** a operacao e recusada sem produzir efeito nem revelar a existencia
  da filial

#### Scenario: Lista fixa de filiais continua valendo para acesso pontual

- **WHEN** um usuario sem o papel `AdminEmpresa`, mas com filiais explicitas no
  contrato interno, requisita operacao sobre uma dessas filiais
- **THEN** a operacao prossegue pelo mecanismo original, sem nenhuma consulta a
  `organizacao/filial`

### Requirement: Autorizacao tecnica separada da autorizacao de negocio

Perfis SHALL responder apenas por autorizacao tecnica e grosseira sobre operacoes.
Regra de negocio que dependa de perfil MUST ser avaliada como invariante do
dominio e resultar em erro de negocio, e nao em recusa de acesso.

#### Scenario: Perfil insuficiente para a operacao

- **WHEN** a identidade nao possui perfil exigido pela operacao
- **THEN** o acesso e recusado antes de o caso de uso ser executado

#### Scenario: Regra de negocio dependente de perfil

- **WHEN** uma regra de negocio exige perfil especifico para permitir determinado
  resultado
- **THEN** a avaliacao ocorre no dominio e produz erro de negocio identificavel,
  e nao recusa de acesso

### Requirement: Emissor local restrito ao ambiente de desenvolvimento

O emissor local de identidade SHALL estar disponivel exclusivamente no ambiente de
desenvolvimento. Em qualquer outro ambiente ele MUST NOT responder, e essa
restricao MUST ser verificada por teste automatizado.

#### Scenario: Emissor local responde em desenvolvimento

- **WHEN** uma identidade e solicitada ao emissor local no ambiente de
  desenvolvimento
- **THEN** ela e emitida e e aceita pelas operacoes protegidas

#### Scenario: Emissor local nao responde fora de desenvolvimento

- **WHEN** o emissor local e requisitado em ambiente diferente de desenvolvimento
- **THEN** ele nao responde, e a verificacao automatizada falha caso responda

#### Scenario: Identidade local tem o mesmo formato do emissor futuro

- **WHEN** a identidade emitida localmente e processada
- **THEN** ela exercita a mesma conversao para o contrato interno que um emissor
  externo exercitaria

### Requirement: Recusa de acesso e apresentada no formato uniforme de erro

Recusa por ausencia de identidade e recusa por autorizacao insuficiente SHALL ser
apresentadas no mesmo formato de erro adotado pela aplicacao, com codigo estavel
que as distinga entre si.

#### Scenario: Recusas sao distinguiveis

- **WHEN** uma requisicao e recusada por falta de identidade e outra por
  autorizacao insuficiente
- **THEN** ambas usam o formato uniforme de erro e apresentam codigos estaveis
  diferentes
