## Purpose

Fornece o servico de cache compartilhado e o canal de notificacao entre replicas,
com a garantia de que ambos sao aceleradores: sua perda degrada desempenho, mas
nunca corrompe nem indisponibiliza o sistema.

## ADDED Requirements

### Requirement: Servico de cache disponivel e autenticado

O servico de cache SHALL ser provisionado pelo mesmo mecanismo declarativo dos
demais componentes e MUST exigir autenticacao, com credencial obtida por
referencia a um recurso de segredo.

#### Scenario: Cache disponivel apos o bootstrap

- **WHEN** o procedimento de bootstrap conclui
- **THEN** o servico de cache aceita conexoes autenticadas

#### Scenario: Acesso sem credencial e recusado

- **WHEN** uma conexao e tentada sem credencial valida
- **THEN** o acesso e negado

### Requirement: Perda do cache nao causa perda de dado

O conteudo do cache SHALL ser tratado como descartavel. Perda total do cache MUST
NOT causar perda de dado, inconsistencia permanente nem indisponibilidade do
sistema.

#### Scenario: Cache esvaziado mantem o sistema correto

- **WHEN** todo o conteudo do cache e perdido
- **THEN** as operacoes continuam produzindo resultados corretos, com eventual
  aumento de latencia

#### Scenario: Cache indisponivel degrada sem interromper

- **WHEN** o servico de cache fica indisponivel
- **THEN** as operacoes continuam sendo atendidas a partir da fonte de dados,
  e a indisponibilidade e observavel

#### Scenario: Cache nao e fonte da verdade

- **WHEN** o conteudo do cache diverge da fonte de dados
- **THEN** a fonte de dados prevalece

### Requirement: Canal de notificacao com entrega em broadcast

O servico SHALL oferecer um canal de publicacao e assinatura cuja entrega e em
**broadcast**: uma mensagem publicada e entregue a **todos** os assinantes
conectados, e nao a exatamente um deles. Esse canal MUST NOT ser usado para
efeitos que precisem ocorrer uma unica vez.

#### Scenario: Mensagem alcanca todas as replicas conectadas

- **WHEN** uma mensagem e publicada e existem varias replicas assinantes
  conectadas
- **THEN** todas as replicas assinantes recebem a mensagem

#### Scenario: Entrega e efemera e sem garantia para ausentes

- **WHEN** uma replica esta desconectada no momento da publicacao
- **THEN** ela nao recebe a mensagem, nem a recebe ao reconectar

#### Scenario: Efeito de ocorrencia unica nao usa este canal

- **WHEN** e preciso garantir que um efeito ocorra exatamente uma vez entre as
  replicas
- **THEN** esse efeito e conduzido por mecanismo de consumidores concorrentes com
  entrega duravel, e nao por este canal

### Requirement: Consumidores toleram a natureza efemera do canal

Consumidores do canal de notificacao SHALL ser projetados para permanecer
corretos quando uma notificacao e perdida, limitando por tempo a duracao de
qualquer estado derivado que dependa dela.

#### Scenario: Notificacao perdida se resolve por expiracao

- **WHEN** uma notificacao de invalidacao nao alcanca uma replica
- **THEN** o estado derivado nessa replica expira por tempo, e a divergencia tem
  duracao limitada e conhecida
