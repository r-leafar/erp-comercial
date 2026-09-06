## Purpose

Garante que cada credencial usada pela aplicacao tenha uma unica origem, para que
nao exista copia divergente do mesmo segredo, e que a aplicacao executada fora do
ambiente reconciliado obtenha suas credenciais a partir dessa origem em vez de
mante-las por conta propria.

## ADDED Requirements

### Requirement: Origem unica de cada credencial

Cada credencial usada pela aplicacao SHALL ter uma unica origem versionada. O
mesmo valor sensivel MUST NOT existir em mais de uma forma no repositorio.

#### Scenario: Credencial possui origem unica

- **WHEN** uma credencial da aplicacao e localizada no repositorio
- **THEN** ela existe em uma unica forma versionada

#### Scenario: Copia adicional e tratada como defeito

- **WHEN** o mesmo valor sensivel passa a existir em outra forma versionada
- **THEN** isso e tratado como defeito e impede a aceitacao da alteracao

### Requirement: Obtencao de credencial pela aplicacao executada fora do ambiente

A aplicacao executada fora do ambiente reconciliado SHALL obter suas credenciais
derivando-as da origem unica ja disponivel nesse ambiente. O procedimento MUST ser
repetivel e MUST produzir o mesmo resultado a cada execucao enquanto a origem nao
mudar.

#### Scenario: Configuracao local e obtida a partir do ambiente

- **WHEN** o procedimento de obtencao e executado com o ambiente disponivel
- **THEN** a aplicacao passa a alcancar banco, cache e armazenamento de objetos

#### Scenario: Reexecucao produz o mesmo resultado

- **WHEN** o procedimento e executado novamente sem alteracao na origem
- **THEN** o resultado e identico e a aplicacao continua operando

#### Scenario: Ambiente recriado nao invalida a configuracao obtida

- **WHEN** o ambiente e destruido e recriado pelo seu procedimento de bootstrap
- **THEN** a configuracao obtida anteriormente continua valida, porque a origem
  permanece a mesma

#### Scenario: Ambiente indisponivel falha de forma diagnosticavel

- **WHEN** o procedimento de obtencao e executado sem o ambiente disponivel
- **THEN** a falha e reportada identificando a causa, em vez de produzir
  configuracao incompleta

### Requirement: Configuracao derivada nao e versionada

O resultado local do procedimento de obtencao SHALL ser excluido do controle de
versao. Valor sensivel em texto claro MUST NOT ser aceito em artefato versionado.

#### Scenario: Resultado local permanece fora do controle de versao

- **WHEN** o procedimento de obtencao produz configuracao local
- **THEN** esse resultado nao e incluido no controle de versao

#### Scenario: Texto claro versionado e recusado

- **WHEN** um artefato versionado passa a conter credencial em texto claro
- **THEN** isso e tratado como defeito e impede a aceitacao da alteracao

### Requirement: Ausencia de decisao de comportamento por ambiente no codigo

O comportamento da aplicacao SHALL ser determinado por configuracao, e nao por
verificacao de nome de ambiente espalhada no codigo, exceto no confinamento
explicito de recursos restritos a desenvolvimento.

#### Scenario: Variacao entre ambientes vem de configuracao

- **WHEN** o comportamento precisa diferir entre ambientes
- **THEN** a diferenca e expressa em configuracao, e nao em ramificacao condicional
  por nome de ambiente no codigo de negocio

### Requirement: Verificacao automatizada independente do ambiente reconciliado

Os testes automatizados SHALL executar sem depender do ambiente reconciliado,
usando dependencias reais efemeras criadas e descartadas pela propria execucao.

#### Scenario: Testes executam sem o ambiente

- **WHEN** a suite de testes e executada em uma maquina sem o ambiente disponivel
- **THEN** ela conclui normalmente

#### Scenario: Dependencias sao reais e nao substitutas em memoria

- **WHEN** um teste exercita persistencia ou armazenamento de objetos
- **THEN** ele usa a dependencia real em instancia efemera, e nao uma
  implementacao substituta em memoria
