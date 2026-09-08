# retencao-de-telemetria Specification

## Purpose

Garante que a telemetria armazenada tenha crescimento limitado e previsivel, com
remocao efetiva do que esta fora da janela declarada, de modo que o ambiente nao
se degrade pelo proprio acumulo de observacao.

## Requirements

### Requirement: Janela de retencao declarada por sinal

Cada sinal SHALL ter uma janela de retencao declarada explicitamente e
versionada. A janela MUST poder diferir entre ambientes.

#### Scenario: Janela e conhecida sem inspecionar o ambiente

- **WHEN** se deseja saber por quanto tempo um sinal e mantido
- **THEN** a resposta esta na configuracao versionada, sem necessidade de
  consultar o ambiente em execucao

#### Scenario: Ambientes podem ter janelas diferentes

- **WHEN** o ambiente de desenvolvimento precisa de janela mais curta que outro
- **THEN** a diferenca e expressa na sobreposicao daquele ambiente

### Requirement: Remocao efetiva de dado fora da janela

Dado mais antigo que a janela declarada SHALL ser efetivamente removido do
armazenamento. Configurar a janela sem que a remocao ocorra MUST ser tratado como
defeito, e nao como configuracao concluida.

#### Scenario: Dado antigo desaparece do armazenamento

- **WHEN** o tempo transcorrido excede a janela declarada para um sinal
- **THEN** os objetos correspondentes deixam de existir no armazenamento

#### Scenario: Ausencia do processo de manutencao e detectada

- **WHEN** o processo responsavel por remover dado antigo nao esta em execucao
- **THEN** isso e observavel, em vez de se manifestar apenas como crescimento
  continuo do armazenamento

#### Scenario: Criterio de aceitacao e o dado sumir

- **WHEN** se verifica a capacidade de retencao
- **THEN** a verificacao observa a ausencia do dado antigo, e nao a presenca da
  opcao de configuracao

### Requirement: Compactacao ativa

O processo de compactacao SHALL estar em execucao para cada sinal que dele
dependa, consolidando objetos pequenos e removendo os que se tornaram obsoletos.

#### Scenario: Quantidade de objetos nao cresce indefinidamente

- **WHEN** a ingestao opera continuamente por periodo prolongado
- **THEN** a quantidade de objetos no armazenamento se estabiliza, em vez de
  crescer proporcionalmente ao tempo

#### Scenario: Falha de compactacao e observavel

- **WHEN** a compactacao falha de forma persistente
- **THEN** a condicao e reportada, permitindo intervencao antes do esgotamento do
  armazenamento

### Requirement: Crescimento do armazenamento limitado e conhecido

O consumo de armazenamento pela telemetria SHALL ser observavel e permanecer
limitado em regime permanente. O ambiente MUST NOT ser levado a esgotamento de
disco pelo acumulo de telemetria.

#### Scenario: Consumo estabiliza em regime permanente

- **WHEN** a plataforma opera com carga constante por periodo superior a maior
  janela de retencao declarada
- **THEN** o espaco ocupado pela telemetria se mantem aproximadamente constante

#### Scenario: Consumo por sinal e observavel

- **WHEN** se deseja saber qual sinal ocupa mais espaco
- **THEN** a informacao esta disponivel como metrica, por sinal

#### Scenario: Aproximacao do limite e sinalizada

- **WHEN** o espaco disponivel para telemetria se aproxima do esgotamento
- **THEN** a condicao e observavel antes que o armazenamento pare de aceitar
  escrita
