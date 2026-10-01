# Design

## Context

Ver proposal.md para motivacao. Duas pecas ja existem e esta change apenas as
consome, sem re-especifica-las: `organizacao/empresa` (Empresa como topo de
Organizacao, `fundacao-aplicacao`) e o papel `AdminEmpresa` com resolucao dinamica
de filial (D4 do design.md de `fundacao-aplicacao`). Nenhuma das duas foi
implementada ainda -- esta change assume o contrato que elas descrevem, nao o
codigo.

O emissor local descrito em `aplicacao/autenticacao-e-autorizacao`
(`fundacao-aplicacao`) e um MINTER de token para claims ja decididas por quem
chama -- nao um cadastro de usuario. Auto-cadastro publico precisa de algo que
hoje nao existe em nenhuma spec: uma conta real, com senha verificada, criada
pela propria pessoa.

## Goals / Non-Goals

**Goals:**
- Decidir ONDE a conta (email + senha) e persistida, dado que o emissor local
  de `fundacao-aplicacao` nao tem esse armazenamento
- Decidir como criar Empresa (modulo Organizacao) e Conta (este modulo) sem
  transacao cruzando schemas, respeitando a fronteira ja estabelecida
- Decidir onde vive a verificacao de bloqueio por trial expirado

**Non-Goals:**
- Desenhar o mecanismo de cobranca ou de reativacao paga (a spec so exige que
  a reativacao, seja como for acionada, remova o bloqueio)
- Desenhar o emissor externo (Keycloak) -- fora do escopo por decisao already
  tomada (ver proposal.md)
- Forma exata de hashing/senha (bcrypt vs argon2 etc.) -- detalhe de
  implementacao, nao de design

## Decisions

### D1. Novo modulo `Comercial`, dono da Conta -- nem Organizacao, nem Platform

A Conta (email, hash de senha, vinculo com a Empresa que administra) vive num
modulo novo, `Comercial`, e nao em `Organizacao` nem em `Platform`.

**Consequencia que evita:** duas. Colocar Conta em Organizacao faria o modulo que
descreve a OPERACAO de uma empresa (Filial, Produto) tambem responder por como
a empresa entrou no sistema -- dois motivos de mudanca no mesmo modulo.
Colocar em Platform confundiria infraestrutura compartilhada (outbox, arquivo,
pipeline de auth generico) com uma capacidade de negocio com ciclo de vida
proprio (trial, expiracao) -- Platform hoje nao tem nenhuma entidade com
regra de negocio, so mecanismo.

**Alternativa recusada:** estender `organizacao/empresa` com os campos de conta.
Rejeitada porque acopla identidade (quem loga) a cadastro (o que a empresa
tem), e o proprio `fundacao-aplicacao` ja decidiu (D4) que autorizacao
tecnica e autorizacao de negocio sao responsabilidades separadas -- Conta e
autorizacao tecnica.

### D2. Empresa e Conta sao criadas por compensacao, nao por transacao unica

`Comercial` chama a interface publica de `Organizacao` para criar a Empresa
PRIMEIRO, numa transacao da propria Organizacao. So depois `Comercial` cria a
Conta e o vinculo de administracao, na sua propria transacao. Se o segundo
passo falhar, `Comercial` aciona a inativacao da Empresa recem-criada (mesmo
mecanismo de `organizacao/empresa`) em vez de deixa-la orfa.

```
   Comercial                          Organizacao
   ---------                          -----------
   1. cria Empresa  -------------->   grava Empresa (tx propria)
                    <--------------   EmpresaId
   2. cria Conta + vinculo
      AdminEmpresa (tx propria)
      |
      falhou? ------------------->   inativa EmpresaId (tx propria)
```

**Consequencia que evita:** uma transacao cruzando os schemas de Organizacao e
Comercial contradiz a fronteira ja estabelecida (SEM FK entre schemas, 1
DbContext por modulo) -- exatamente o tipo de acoplamento que o teste de
arquitetura de `fundacao-aplicacao` existe para pegar.

**Alternativa recusada:** criar a Conta primeiro e a Empresa depois. Rejeitada
porque uma Conta sem Empresa e um estado pior de expor (pessoa autenticada,
sem nada para administrar) do que uma Empresa inativa sem ninguem
referenciando -- o padrao de compensacao ja existe para Empresa (inativacao),
e nao existe ainda para Conta.

**Risco aceito, nao eliminado:** a janela entre os dois passos e reindicada
como consistencia eventual dentro de uma unica requisicao HTTP, nao como
transacao distribuida de verdade. Se o processo cair exatamente nessa janela,
a Empresa fica orfa ate uma rotina de limpeza rodar (mesmo padrao do
`VarredorDeOrfaos` ja usado para arquivo pendente em Platform, reaproveitado
aqui em espirito, nao em codigo).

### D3. Emissor do auto-cadastro reaproveita o formato de D4, nao o endpoint generico `/dev/token`

O auto-cadastro emite seu proprio token, no MESMO formato normalizado que
`aplicacao/autenticacao-e-autorizacao` exige (perfis aninhados, filiais
multivaloradas), assinado com a mesma chave de configuracao do emissor local
-- mas a partir de uma Conta persistida e uma senha verificada, nao de claims
arbitrarias como o `/dev/token` de teste aceita.

**Consequencia que evita:** se o auto-cadastro reaproveitasse `/dev/token`
tal como descrito (claims arbitrarias, sem verificacao de senha), qualquer
pessoa poderia se autenticar como QUALQUER `AdminEmpresa` so escolhendo o
`EmpresaId` certo no payload -- autenticacao de fachada.

**Ainda restrito a Development:** o mesmo requirement de D4 --- emissor
MUST NOT responder fora de Development, verificado por teste automatizado
-- se aplica a este emissor tambem. Isso e um risco explicito, nao resolvido
aqui: ver Risks / Trade-offs.

### D4. Bloqueio de escrita por trial expirado no pipeline de autorizacao, nao por modulo

A verificacao de trial expirado entra como uma regra a mais no MESMO ponto do
pipeline que ja resolve `AdminEmpresa` (D4/nota de `fundacao-aplicacao`):
antes de qualquer operacao de escrita, consulta se a empresa do usuario esta
com trial expirado pela interface publica deste modulo, e recusa se estiver.

**Consequencia que evita:** repetir a mesma verificacao em Organizacao, Catalogo,
Estoque, Vendas e Financeiro -- cinco copias da mesma regra, uma delas eventualmente
esquecida quando um modulo novo nascer.

**Alternativa recusada:** cada modulo verificar o estado da empresa antes de
aceitar sua propria escrita. Rejeitada pelo motivo acima, e porque contradiz
o padrao ja estabelecido de cross-cutting concerns resolvidos centralmente
(auditoria via interceptor, por exemplo), nao replicados por modulo.

## Risks / Trade-offs

- **Auto-cadastro publico sobre um emissor cujo proprio requirement diz
  "nunca responder fora de Development"** e uma contradicao de nomenclatura,
  nao so de configuracao. -> Mitigacao: nenhuma ainda. Registrado
  explicitamente para nao ser descoberto como surpresa: enquanto nao existir
  um ambiente de producao de verdade (fora do escopo desta e de
  `fundacao-aplicacao`), este e o UNICO ambiente que existe, entao a
  contradicao e adiada, nao resolvida. Revisitar junto com `adotar-keycloak`
  ou com a primeira sobreposicao de producao real.
- **Compensacao (D2) deixa uma janela onde a Empresa existe sem Conta** se o
  processo cair entre os dois passos. -> Mitigacao parcial: a Empresa nesse
  estado nao e alcancavel por ninguem (nenhuma Conta a referencia ainda);
  uma rotina de limpeza periodica fica registrada como tarefa, nao como
  decisao de design adicional.
- **Verificacao de trial a cada escrita adiciona uma consulta por
  requisicao**, no mesmo espirito do risco ja aceito para `AdminEmpresa`.
  -> Mitigacao: nenhuma agora -- cache (Valkey) e non-goal desta fase em
  `fundacao-aplicacao` tambem; mesma atencao futura se virar hot path.

## Open Questions

- Duracao exata do periodo de teste (numero de dias). Nao muda nenhum
  requirement, nenhuma decisao de design nem nenhuma task -- e um valor de
  configuracao, decidido quando houver dado real de conversao para calibrar.
