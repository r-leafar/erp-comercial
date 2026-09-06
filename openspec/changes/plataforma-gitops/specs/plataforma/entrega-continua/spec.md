## Purpose

Garante que o estado do ambiente seja derivado exclusivamente do repositorio
versionado, de forma reproduzivel e ordenada, para que qualquer ambiente possa
ser recriado do zero sem conhecimento tacito nem passos manuais.

## ADDED Requirements

### Requirement: Estado do ambiente derivado do repositorio

O estado dos componentes de plataforma SHALL ser derivado continuamente do
conteudo versionado no repositorio. Alteracoes aplicadas diretamente no ambiente,
sem passar pelo repositorio, MUST ser revertidas automaticamente.

#### Scenario: Alteracao versionada e aplicada sem intervencao

- **WHEN** uma alteracao de configuracao de plataforma e registrada no
  repositorio
- **THEN** o ambiente converge para o estado declarado sem qualquer comando
  manual

#### Scenario: Alteracao manual no ambiente e revertida

- **WHEN** um recurso da plataforma e modificado diretamente no ambiente, fora
  do repositorio
- **THEN** o estado declarado no repositorio e restaurado automaticamente

#### Scenario: Estado declarado invalido nao e aplicado parcialmente sem sinal

- **WHEN** o conteudo versionado descreve um estado que nao pode ser realizado
- **THEN** a reconciliacao e reportada como falha, identificando o recurso
  responsavel

### Requirement: Ambiente reproduzivel a partir de ambiente vazio

A plataforma SHALL poder ser levantada por completo a partir de um cluster vazio,
usando apenas o repositorio e um procedimento de bootstrap documentado e
finito. Nenhum componente da plataforma MUST depender de estado criado
manualmente por um operador.

#### Scenario: Ambiente novo converge para plataforma completa

- **WHEN** o procedimento de bootstrap e executado sobre um cluster vazio
- **THEN** banco de dados, cache e object storage ficam disponiveis e
  configurados, sem passos adicionais fora do que esta versionado

#### Scenario: Ambiente recriado produz o mesmo resultado

- **WHEN** o ambiente e destruido e o procedimento de bootstrap e executado
  novamente
- **THEN** o resultado e equivalente ao anterior, incluindo credenciais e
  recursos de armazenamento

#### Scenario: Reexecucao do bootstrap nao causa dano

- **WHEN** o procedimento de bootstrap e executado sobre um ambiente ja
  provisionado
- **THEN** a operacao conclui sem erro e sem alterar dados existentes

### Requirement: Ordenacao declarada das dependencias de bootstrap

Componentes que dependem de recursos criados por outros SHALL declarar essa
dependencia, e a plataforma MUST aplicar os componentes em ordem que respeite as
dependencias declaradas.

#### Scenario: Consumidor nao e iniciado antes do pre-requisito

- **WHEN** um componente depende de um recurso de armazenamento que ainda nao
  foi criado
- **THEN** esse componente so e iniciado apos o recurso existir

#### Scenario: Falha de pre-requisito impede os dependentes

- **WHEN** a criacao de um pre-requisito falha
- **THEN** os componentes dependentes nao sao iniciados, e a falha e atribuida
  ao pre-requisito

#### Scenario: Pre-requisito considerado pronto apenas quando utilizavel

- **WHEN** um pre-requisito e reportado como criado mas ainda nao esta apto a
  atender requisicoes
- **THEN** os dependentes permanecem aguardando, em vez de falharem por corrida

### Requirement: Diferencas entre ambientes expressas apenas em sobreposicao

A definicao comum dos componentes SHALL ser unica e compartilhada entre
ambientes. Toda diferenca entre ambientes MUST estar expressa em uma
sobreposicao de configuracao versionada, identificavel por ambiente.

#### Scenario: Ambientes compartilham a mesma definicao base

- **WHEN** um componente e alterado de forma aplicavel a todos os ambientes
- **THEN** a alteracao e feita em um unico lugar e vale para todos

#### Scenario: Diferenca de ambiente e localizavel

- **WHEN** e preciso saber o que difere entre desenvolvimento e producao
- **THEN** a resposta esta inteiramente contida nas sobreposicoes, sem exigir
  leitura da definicao base

#### Scenario: Componente nao decide comportamento por ambiente em tempo de execucao

- **WHEN** um componente precisa de valor diferente por ambiente
- **THEN** o valor chega por configuracao externa, e nao por ramificacao interna
  baseada no nome do ambiente

### Requirement: Definicoes independentes do host de desenvolvimento

As definicoes versionadas SHALL depender apenas de capacidades padrao do cluster.
Elas MUST NOT codificar caminho de sistema de arquivos do host, nome de maquina,
endereco especifico de uma instalacao, nem recurso particular de uma forma de
obter o cluster. O sistema operacional do desenvolvedor MUST ser irrelevante para
o conteudo aplicado.

#### Scenario: Mesma sobreposicao funciona em clusters obtidos de formas diferentes

- **WHEN** a sobreposicao de desenvolvimento e aplicada a um cluster conforme,
  independentemente de como esse cluster foi provisionado ou de qual sistema
  operacional o hospeda
- **THEN** a plataforma converge para o mesmo estado, sem ajuste local

#### Scenario: Valor especifico de host e tratado como defeito

- **WHEN** uma definicao versionada referencia caminho do host, nome de maquina
  ou recurso exclusivo de uma instalacao particular
- **THEN** isso e tratado como defeito e impede a aceitacao da alteracao

#### Scenario: Armazenamento local usa a capacidade padrao do cluster

- **WHEN** um componente precisa de volume persistente em desenvolvimento
- **THEN** ele solicita a classe de armazenamento padrao do cluster, sem apontar
  para diretorio do host

### Requirement: Pre-requisitos de host documentados por sistema operacional

A documentacao de preparo do ambiente SHALL separar os requisitos comuns a
qualquer host dos pre-requisitos especificos de cada sistema operacional
suportado, e MUST declarar explicitamente quais sistemas nao estao cobertos.

#### Scenario: Requisitos comuns identificaveis isoladamente

- **WHEN** um desenvolvedor consulta o que precisa preparar
- **THEN** encontra primeiro os requisitos validos para qualquer host, sem
  precisar filtrar instrucoes que nao se aplicam ao seu sistema

#### Scenario: Pre-requisito especifico esta associado ao seu sistema

- **WHEN** um pre-requisito so se aplica a determinado sistema operacional
- **THEN** ele aparece somente na secao daquele sistema, junto do sintoma que
  produz quando ausente

#### Scenario: Sistema nao suportado e declarado

- **WHEN** um desenvolvedor usa sistema operacional fora dos cobertos
- **THEN** a documentacao afirma explicitamente que aquele sistema nao esta
  coberto, em vez de omitir
