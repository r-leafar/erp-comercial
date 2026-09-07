# Plataforma base gerenciada por GitOps

## Why

O ERP de gestao de vendas ainda nao tem onde rodar. Antes de escrever qualquer
linha de C#, o projeto precisa de um ambiente que suba **do zero, sozinho e de
forma identica** a partir do repositorio: banco, cache, object storage e o
mecanismo de entrega que reconcilia tudo isso.

Fazer isso primeiro, e nesta ordem, evita dois problemas caros de corrigir
depois:

1. **Ambiente irreprodutivel.** Se a infraestrutura nascer de comandos manuais,
   ninguem consegue recriar o ambiente, e "funciona na minha maquina" vira
   permanente. Retrofitar GitOps depois exige reescrever tudo que ja foi
   aplicado a mao.
2. **Segredo em texto no repositorio.** A decisao de como versionar segredo
   precisa vir junto com a decisao de versionar manifesto. Invertida, a ordem
   produz credencial commitada em texto claro e historico de Git que nao se
   limpa.

Esta change entrega a base fisica e o mecanismo de entrega. Ela nao entrega
observabilidade (change seguinte) nem aplicacao (a terceira).

## What Changes

- **Entrega continua declarativa com ArgoCD.** Git passa a ser a unica fonte da
  verdade do estado do cluster. Nenhum `kubectl apply` imperativo. Drift e
  revertido pelo proprio agente.
- **Bootstrap por scripts especializados.** A fatia imperativa que antecede o
  GitOps (criar o cluster, instalar o Podman, instalar o ArgoCD, restaurar a
  chave de selagem, apontar a aplicacao raiz) e dividida em um script por
  responsabilidade, chamados em ordem por um unico orquestrador
  (`deploy/bootstrap/bootstrap.sh`). Nenhuma ferramenta externa de
  infraestrutura como codigo entra nesta change.
- **Estrutura de deploy versionada** em `deploy/base` + `deploy/overlays/{dev,prod}`
  (Kustomize). A diferenca entre ambientes deixa de ser conhecimento tacito e
  vira estrutura de diretorio.
- **Ordenacao explicita de bootstrap** por sync waves, para que dependencias
  como "bucket precisa existir antes do consumidor subir" sejam declaradas e
  nao descobertas em runtime.
- **Gestao de segredos com Sealed Secrets.** Segredos cifrados versionados no
  repositorio, com a chave de selagem tratada como parte do bootstrap de dev
  para que o ambiente continue recriavel apos recriar o cluster.
- **Object storage S3** provisionado com MinIO em dev, com buckets e credenciais
  criados por Job idempotente. Contrato de configuracao uniforme
  (endpoint, region, credenciais, bucket, path-style, tls) para todo consumidor,
  presente e futuro.
- **PostgreSQL via CloudNativePG**, com archive continuo de WAL e base backup
  para o object storage, habilitando recuperacao a ponto no tempo.
- **Valkey** provisionado como cache distribuido e canal de pub/sub, para uso
  pelas changes seguintes.
- **Cluster k3s local para desenvolvimento**, criado por script de
  inicializacao versionado (nao apenas documentado), com os pre-requisitos de
  host documentados por sistema operacional. A plataforma nao presume um
  sistema operacional especifico na maquina do desenvolvedor.

### Non-goals

Declarados explicitamente porque o escopo de plataforma tende a vazar:

- **Observabilidade.** Agente de coleta, Loki, Tempo, Mimir e Grafana ficam
  para a change `observabilidade`. Esta change apenas cria os buckets que eles
  consumirao.
- **Qualquer codigo .NET.** Solution, projetos, outbox, autenticacao e cache de
  aplicacao ficam para a change `fundacao-aplicacao`.
- **Migrations e sua ordenacao.** O mecanismo de PreSync hook pertence a change
  que introduz schema.
- **Keycloak**, refresh token e gestao de usuarios.
- **Ambiente de producao operante.** O overlay `prod` nasce como estrutura e
  contrato de configuracao, nao como ambiente provisionado. Escolha de provedor
  de S3, dimensionamento e topologia de producao ficam para quando producao
  existir.
- **Alta disponibilidade e durabilidade real.** Dev e single-node por decisao.
- **Automacao de build e de publicacao de imagem (CI).** Implantar a aplicacao no
  cluster continua sendo possivel e suportado: constroi-se a imagem, injeta-se no
  runtime de containers do cluster local e altera-se o numero de replicas na
  sobreposicao. O que fica de fora e **automatizar** isso. O gatilho para
  introduzir a automacao e o destino da implantacao deixar de ser o cluster da
  propria maquina, porque ai a injecao direta de imagem deixa de funcionar e
  passa a ser necessario um repositorio de imagens.
- **Ambiente de teste dedicado.** Uma sobreposicao propria, que permaneca de pe
  para uso de terceiros, fica para quando houver necessidade. Testes
  automatizados nao dependem dela: usam dependencias reais em containers
  efemeros, sem cluster.
- **Tilt** no loop de desenvolvimento.

## Capabilities

### New Capabilities

- `plataforma/entrega-continua`: reconciliacao declarativa do estado do cluster a
  partir do Git, ordenacao de bootstrap, separacao entre ambientes por overlay e
  a garantia de que o ambiente e reproduzivel a partir do repositorio.
- `plataforma/gestao-de-segredos`: versionamento de segredos em forma cifrada,
  ciclo de vida da chave de selagem, e o consumo de segredo pelas cargas de
  trabalho sempre por referencia a Secret.
- `plataforma/armazenamento-de-objetos`: provisionamento de buckets e
  credenciais, contrato uniforme de configuracao de acesso, e a restricao de uso
  ao subconjunto comum da API S3 que mantem o backend substituivel entre
  ambientes.
- `plataforma/persistencia-relacional`: disponibilidade do banco, archive
  continuo de WAL, base backup e recuperacao a ponto no tempo.
- `plataforma/cache-distribuido`: disponibilidade do cache e do canal de
  publicacao/assinatura, e a exigencia de que a perda total do cache nao cause
  perda de dado nem indisponibilidade.

### Modified Capabilities

Nenhuma. O repositorio nao possui specs anteriores.

## Impact

**Novo no repositorio**

- **O proprio repositorio.** Ele ainda nao existe: esta change o inicializa como
  monorepo `erp-comercial`, com a estrutura de primeiro nivel (`src/`, `tests/`,
  `deploy/`, `docs/`, alem do `openspec/` ja presente) e as convencoes de
  nomenclatura, branch e mensagem de commit.
- `deploy/base/` e `deploy/overlays/{dev,prod}`: manifests Kustomize da
  plataforma.
- `deploy/bootstrap/`: unico ponto de partida imperativo, executado uma vez por
  cluster — um script por responsabilidade (criacao do cluster, instalacao do
  Podman, instalacao do ArgoCD, restauracao da chave de selagem de dev,
  aplicacao da Application raiz), chamados em ordem por um orquestrador
  unico. Um script simetrico desfaz a criacao do cluster, para que a
  recriacao do zero seja verificavel sem passo manual.
- Documentacao de requisitos do cluster local, comum a qualquer host, mais uma
  secao de pre-requisitos por sistema operacional do desenvolvedor.
- `docs/convencoes.md`: monorepo e sua justificativa, prefixo de assembly,
  criterio de idioma, nomes de schema e namespace, branches e commits.

**Componentes introduzidos no cluster**

ArgoCD, controller do Sealed Secrets, operator do CloudNativePG mais o cluster
Postgres, MinIO, Valkey, e um Job de provisionamento de buckets e credenciais.

**Consumidores futuros afetados por decisao tomada aqui**

- Loki, Tempo, Mimir e CloudNativePG dependerao dos buckets e do contrato de
  configuracao de S3 definidos nesta change.
- A aplicacao .NET consumira o mesmo contrato de configuracao de S3, o Valkey e
  o Postgres, sempre lendo credencial de Secret.
- A restricao ao subconjunto comum da API S3 limita, por desenho, o que as
  changes seguintes podem assumir do object storage.

**Risco assumido e registrado**

O ambiente de dev nao tem redundancia: MinIO single-node, backup do Postgres no
mesmo disco do Postgres, sem TLS, com credenciais e chave de selagem versionadas.
Isso e deliberado e serve para exercitar os mecanismos, nao para prover
durabilidade. A change deve deixar essa fronteira escrita para que dev nunca seja
confundido com producao.
