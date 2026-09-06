## Purpose

Fornece o banco de dados relacional da plataforma com archive continuo e
recuperacao a ponto no tempo, de modo que a capacidade de restaurar seja
exercitada e nao apenas configurada.

## ADDED Requirements

### Requirement: Banco relacional disponivel e configurado por credencial versionada

O banco de dados SHALL ser provisionado pelo mesmo mecanismo declarativo dos
demais componentes, e suas credenciais MUST ser obtidas por referencia a um
recurso de segredo, nunca embutidas na definicao do componente.

#### Scenario: Banco disponivel apos o bootstrap

- **WHEN** o procedimento de bootstrap conclui
- **THEN** o banco aceita conexoes autenticadas com a credencial provisionada

#### Scenario: Rotacao de credencial nao altera a definicao do componente

- **WHEN** a credencial do banco e substituida
- **THEN** apenas o recurso de segredo muda, e a definicao do componente
  permanece inalterada

### Requirement: Archive continuo do registro de transacoes

O banco SHALL enviar continuamente seu registro de transacoes para o
armazenamento de objetos. Falha no envio MUST ser observavel, e nao silenciosa.

#### Scenario: Transacao confirmada gera archive

- **WHEN** uma transacao e confirmada no banco
- **THEN** o segmento correspondente do registro de transacoes e enviado ao
  armazenamento de objetos

#### Scenario: Falha de archive e detectavel

- **WHEN** o envio do registro de transacoes falha de forma persistente
- **THEN** a condicao e reportada, permitindo intervencao antes que a janela de
  recuperacao seja perdida

### Requirement: Copia base periodica

O banco SHALL produzir copias base periodicas no armazenamento de objetos, em
frequencia declarada, de modo que a recuperacao nao dependa de reprocessar o
registro de transacoes desde a criacao do banco.

#### Scenario: Copia base e produzida conforme a frequencia declarada

- **WHEN** o intervalo declarado transcorre
- **THEN** uma nova copia base fica disponivel no armazenamento de objetos

### Requirement: Recuperacao a ponto no tempo

A plataforma SHALL permitir restaurar o banco para um instante escolhido dentro
da janela coberta pela copia base mais recente e pelo registro de transacoes
arquivado.

#### Scenario: Estado anterior a um erro e recuperado

- **WHEN** um dado existente em um instante T e removido em um instante
  posterior, e solicita-se restauracao para T
- **THEN** o banco restaurado contem o dado como estava em T

#### Scenario: Instante fora da janela e recusado

- **WHEN** solicita-se restauracao para um instante anterior a janela coberta
- **THEN** a operacao e recusada de forma explicita, informando a janela
  disponivel

### Requirement: Procedimento de restauracao verificado

O procedimento de restauracao SHALL ser executado e validado, e nao apenas
configurado. Backup cujo caminho de restauracao nunca foi exercitado MUST NOT
ser considerado concluido.

#### Scenario: Restauracao exercitada com resultado conferido

- **WHEN** o procedimento de restauracao e executado sobre uma instancia de
  verificacao
- **THEN** o banco restaurado e comparado ao estado esperado, e a divergencia,
  se houver, e reportada

#### Scenario: Configuracao sem verificacao nao encerra a entrega

- **WHEN** o archive e a copia base estao configurados mas nenhuma restauracao
  foi realizada
- **THEN** a capacidade e considerada incompleta
