# Proposal

## Why

`fundacao-aplicacao` (cadastro/empresa) ja torna o cadastro multi-empresa:
codigo unico por empresa, e nao mais global. Mas nenhuma change decide **como**
uma empresa nova entra no sistema. Hoje isso so acontece se alguem com acesso
direto ao banco ou a um endpoint interno criar a empresa manualmente -- nao ha
fluxo de auto-cadastro, nem tela.

Esta change nasceu de uma sessao de prototipagem das telas de cadastro
(Empresa, Filial, Produto, Saldo por filial). Ao pedir uma pagina inicial com
"testar gratis", ficou claro que auto-cadastro de empresa com periodo de
trial e uma decisao de produto real, nao um detalhe visual -- e que ela reabre
o que `config.yaml` chamava de "multi-tenant SaaS", ate entao nao pensado
como fluxo de entrada. Vale decidir agora, antes de qualquer implementacao de
`fundacao-aplicacao` assumir uma forma de provisionamento que essa change teria
que desfazer depois.

Prototipo de referencia (Artifact do Claude, ilustra o app existente e o CTA
de entrada, sem gerar nenhum efeito real): https://claude.ai/artifact/7vb2R2rHZ3zEkBKryKRi8E

## What Changes

- **Pagina publica de apresentacao** do produto, com CTA de inicio de teste
  gratuito.
- **Auto-cadastro de conta**: uma pessoa anonima informa seus dados, cria uma
  identidade e, na mesma operacao, uma empresa nova e vinculada a ela.
- **Provisionamento automatico do primeiro usuario administrador** da empresa
  criada, sem intervencao manual.
- **Periodo de teste por tempo limitado**, contado a partir do auto-cadastro.
  Duracao exata e o que acontece na expiracao ficam como pergunta em aberto
  (ver Impact).
- Consome o papel `AdminEmpresa` e a resolucao dinamica de filial por
  interface publica de `cadastro/filial`, ja registrados em `fundacao-aplicacao`
  (D4 do design.md) -- **esta change nao re-especifica esse mecanismo**, so o
  aciona ao criar o primeiro usuario da empresa.

### Non-goals

- **Cobranca e assinatura paga.** Nao ha modelo de preco, integracao de
  pagamento, nem decisao sobre o que ocorre quando o teste expira
  (bloqueio, degradacao, exclusao). Fica registrado como pergunta aberta,
  nao como decisao adiada silenciosamente.
- **Emissor de identidade externo (Keycloak).** A troca de emissor local por
  Keycloak e a change `adotar-keycloak`, ja prevista no contexto do projeto.
  Esta change pode ou nao depender dela -- ver Impact.
- **Convite de usuario adicional para uma empresa existente.** Esta change
  cobre apenas a criacao da PRIMEIRA conta/empresa/usuario. Adicionar mais
  usuarios a uma empresa ja existente e outro fluxo, fora deste escopo.
- **Verificacao de email, captcha ou qualquer mecanismo anti-abuso do
  auto-cadastro.** Registrado como risco, nao como decisao.
- **Regra de negocio dos modulos** (Vendas, Financeiro, Estoque). Esta change
  cria a empresa e o primeiro acesso; o que a empresa faz depois e escopo de
  outras changes.

## Capabilities

### New Capabilities

- `comercial/auto-cadastro`: criacao de conta e empresa por uma pessoa
  anonima, com provisionamento do primeiro usuario administrador e inicio do
  periodo de teste, sem intervencao manual.

### Modified Capabilities

Nenhuma. O papel `AdminEmpresa` e a resolucao dinamica de filial pertencem a
`aplicacao/autenticacao-e-autorizacao` (`fundacao-aplicacao`) e nao mudam
aqui -- esta change apenas os aciona.

## Impact

**Depende de**

`fundacao-aplicacao` completa, em especial `cadastro/empresa` e o papel
`AdminEmpresa` (D4). Dependencia de `adotar-keycloak` e uma pergunta em
aberto: o auto-cadastro publico pode nao ser sustentavel sobre o emissor
local de desenvolvimento, mas isso so se confirma ao desenhar a change
(design.md), nao na proposta.

**Novo no repositorio**

- Pagina publica e fluxo de auto-cadastro (interface e endpoint).
- Campo(s) de controle de periodo de teste na entidade Empresa ou em
  entidade propria -- forma exata e decisao de design, nao de proposta.

**Perguntas em aberto, para o design.md**

- Duracao do periodo de teste e o que ocorre na expiracao.
- Se o emissor local basta para o auto-cadastro publico ou se isso forca
  antecipar `adotar-keycloak`.
- Se uma pessoa pode ter mais de uma empresa (hoje o desenho de claims em
  D4 ja suporta filiais de mais de uma empresa por outro motivo -- acesso
  pontual tipo contador -- mas nao decide se o MESMO fluxo de auto-cadastro
  permite isso).
