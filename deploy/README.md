# Plataforma: bootstrap e requisitos

Este documento cobre dois assuntos que costumam ser confundidos e por isso
moram em secoes separadas: **o que a plataforma exige de qualquer cluster**
(igual em qualquer host) e **o que o seu sistema operacional exige para
obter esse cluster** (varia por host). Ver design da change `plataforma-gitops`
(`openspec/changes/plataforma-gitops/design.md`, decisao D10) para a
justificativa dessa separacao.

## Requisitos do cluster (comuns a qualquer host)

- Cluster k3s conforme, na versao fixada abaixo.
- Classe de armazenamento local padrao do cluster disponivel — os manifests
  desta plataforma **nao** referenciam outra nem apontam para diretorio do
  host.
- Memoria e CPU suficientes para a plataforma completa (numero registrado na
  secao "Consumo de recursos" abaixo, apos ser medido).
- Espaco em disco, com crescimento acompanhado — particularmente relevante
  em hosts com disco virtual (ver secao WSL2).
- A aplicacao roda no **mesmo host** do cluster, e alcanca banco, cache e
  armazenamento por endereco local (`localhost` + porta do servico).

Nenhum manifest desta plataforma pode codificar caminho de host, nome de
maquina, endereco de instalacao particular ou recurso exclusivo de uma forma
de obter o cluster. O overlay de desenvolvimento deve subir em qualquer
cluster k3s conforme, independentemente do sistema operacional que o
hospeda.

### Versoes fixadas

| Componente | Versao | Onde e aplicada |
|---|---|---|
| k3s | `v1.36.4+k3s1` | `deploy/bootstrap/install-cluster.sh` |
| ArgoCD | `v3.5.2` | `deploy/bootstrap/install-argocd.sh` |
| Sealed Secrets (controller) | `v0.39.1` | `deploy/base/plataforma/sealed-secrets/` |
| CloudNativePG (operator) | `v1.30.0` | `deploy/base/plataforma/postgres/` |
| Podman | a que o gerenciador de pacotes da distro oferecer (sem pin reproduzivel — ver nota em `install-podman.sh`) | `deploy/bootstrap/install-podman.sh` |

Atualizar aqui e no script/manifesto correspondente juntos quando houver
motivo para subir de versao. Nenhum componente usa tag `latest` ou
equivalente movel.

### Consumo de recursos

A ser preenchido apos a tarefa 10.5 (medir o consumo de memoria da
plataforma completa e ajustar limites). Ate la, nenhum numero deve ser
assumido pelas changes seguintes.

## Pre-requisitos por sistema operacional

Os pre-requisitos abaixo **nao** sao propriedade da plataforma — sao o que
o seu sistema operacional exige para que um cluster k3s conforme exista.
Leia primeiro os requisitos comuns acima; depois, so a secao do seu sistema.

### Linux nativo

- Instale o k3s com o script oficial, fixando a versao acima (ver
  `deploy/bootstrap/install-cluster.sh`).
- Garanta espaco em disco suficiente para os volumes persistentes da
  plataforma (Postgres, MinIO, Valkey).
- Nenhum dos itens da secao "Windows com WSL2" abaixo se aplica a voce.

### Windows com WSL2

k3s nao roda nativamente no Windows — precisa do WSL2. Quatro
pre-requisitos, cada um com um sintoma que **nao aponta para a causa** se
ficar ausente:

| Pre-requisito | Por que | Sintoma se ausente |
|---|---|---|
| `systemd=true` em `/etc/wsl.conf`, distro reiniciada apos a mudanca | k3s roda como servico systemd | Cluster nao sobe sozinho a cada nova sessao do WSL |
| Repositorio no filesystem do WSL (`~/...`), nunca em `/mnt/c/...` | Acesso ao disco do Windows via 9p e muito mais lento | Build, `dotnet watch` e deteccao de alteracao de arquivo ficam dramaticamente lentos |
| Memoria e CPU fixadas em `%UserProfile%\.wslconfig` | Por padrao o WSL2 toma ate metade da RAM do host | Maquina do desenvolvedor fica inutilizavel durante o trabalho normal |
| Compactacao periodica do VHDX conhecida (`diskpart` / `wsl --manage <distro> --shrink`, conforme a versao do WSL) | O VHDX cresce e **nao encolhe sozinho**; volumes de plataforma e telemetria escrevem sem parar | Disco do host se esgota, mesmo com espaco "liberado" dentro da distro |

Exemplo de `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Exemplo de `.wslconfig` (no perfil do usuario Windows):

```ini
[wsl2]
memory=8GB
processors=4
```

### macOS

**Nao esta coberto.** Rodar k3s em macOS exigiria uma camada de
virtualizacao (o kernel Linux do k3s nao roda nativo em macOS), com
implicacoes proprias de compartilhamento de arquivos e memoria que ainda
nao foram avaliadas. Ausencia declarada deliberadamente, para nao ser
confundida com omissao. Adicionar uma secao propria aqui, quando houver
necessidade, nao exige reorganizar o restante deste documento.

## Bootstrap

Unico procedimento imperativo, executado uma vez por cluster (ver D1, D14 e
D15 do design). Composto por scripts pequenos, um por responsabilidade,
chamados em ordem por um orquestrador:

```
deploy/bootstrap/
  bootstrap.sh              orquestrador -- so decide a ordem
    install-cluster.sh       cria o cluster k3s (por sistema operacional)
    install-podman.sh        instala o motor de container do host (D15)
    install-argocd.sh        instala o agente de reconciliacao
    restore-sealing-key.sh   restaura a chave de selagem de dev
    apply-root-app.sh        aplica a Application raiz (overlays/dev)

  destroy-cluster.sh         fora do orquestrador -- desfaz o que
                              install-cluster.sh criou
```

Para levantar o ambiente do zero:

```bash
./deploy/bootstrap/bootstrap.sh
```

Para destruir e recriar (verificacao de reprodutibilidade — tarefa 10.1):

```bash
./deploy/bootstrap/destroy-cluster.sh
./deploy/bootstrap/bootstrap.sh
```

## Ondas de sincronizacao (sync waves)

O ArgoCD aplica cada onda somente apos a anterior estar saudavel:

| Onda | Conteudo |
|---|---|
| -4 | Namespaces, definicoes de recurso customizado, controller do Sealed Secrets, operator do CloudNativePG |
| -3 | Objetos `SealedSecret` |
| -2 | Postgres (CloudNativePG), Valkey, MinIO |
| -1 | Job idempotente de provisionamento de buckets e credenciais no MinIO |
| 0 | (reservado — change `observabilidade`) |
| 1 | (reservado — aplicacao, com 0 replicas em desenvolvimento) |

**Atencao:** "saudavel" para um recurso customizado depende de o ArgoCD
saber avalia-lo. Verifique, na versao fixada do ArgoCD e do operator do
CloudNativePG, se ha health check conhecido para o `Cluster` do CNPG. Se
nao houver, declare a avaliacao explicitamente — esta e a falha mais
provavel do bootstrap, e deve ser testada recriando o cluster, nao so na
primeira execucao.

## Contrato de configuracao de acesso a objetos (S3)

Todo consumidor (Loki, Tempo, Mimir, CloudNativePG, adapter .NET futuro) e
configurado pelo mesmo conjunto de parametros — nenhum host e fixado no
artefato do consumidor:

| Parametro | Dev | Prod |
|---|---|---|
| Endereco | Servico interno do MinIO | Endpoint do provedor |
| Regiao | Valor de convencao (`us-east-1`) | Regiao real |
| Credencial | Recurso de Secret | Recurso de Secret |
| Enderecamento | Por caminho (`http://host/bucket`) | Por subdominio (virtual-hosted) |
| Canal | Sem TLS | Com TLS |

**Dois pontos de atrito conhecidos:**

- **Enderecamento por caminho precisa ser explicito em desenvolvimento.**
  Se omitido, a falha aparece como erro de resolucao de nome (o cliente
  tenta resolver `<bucket>.host` como hostname), e nao como "bucket
  inexistente" — o diagnostico aponta para o lugar errado.
- **A regiao e ignorada pelo MinIO, mas exigida pelo cliente S3.** Fixar
  `us-east-1` como valor de convencao evita falha de inicializacao com
  mensagem que nao tem relacao com a causa real.

Uso restrito ao subconjunto comum da API de objetos: escrita, leitura,
remocao, listagem, metadados, envio particionado e acesso temporario
assinado. Qualquer recurso alem disso (versionamento, retencao imutavel,
lifecycle) exige decisao registrada, por reduzir o conjunto de provedores
de producao admissiveis.

Buckets provisionados por esta change: `mimir-blocks`, `mimir-ruler`,
`mimir-alertmanager`, `loki-chunks`, `loki-ruler`, `tempo-traces`,
`postgres-backup`, `arquivos`. Uma credencial por consumidor, restrita ao
seu proprio bucket.

## Cache e canal de notificacao (Valkey)

O Valkey tem dois papeis com semantica de entrega **opostas** — trocar um
pelo outro nao falha com uma replica e falha silenciosamente com varias:

| | Consumidores concorrentes (outbox, futuro) | Canal de notificacao (pub/sub) |
|---|---|---|
| Quem recebe | Exatamente UMA replica | TODAS as replicas conectadas |
| Entrega | Duravel | Efemera |
| Uso | Efeito (dar baixa uma unica vez) | Notificacao (invalidar copia local) |
| Replica desconectada | Recebe ao reconectar | **Nao** recebe, nem ao reconectar |

Todo estado derivado que dependa do canal de notificacao precisa ter
expiracao por tempo, limitando a divergencia causada por uma notificacao
perdida a uma janela conhecida.

## Propriedades de dev que NAO valem em producao

Escritas aqui para que ninguem confunda o overlay de desenvolvimento com um
ambiente duravel (ver proposal.md, "Risco assumido e registrado", e D8/D10
do design):

- MinIO single-node, sem redundancia; canal HTTP, sem TLS.
- Credenciais de acesso e a chave de selagem do Sealed Secrets, ambas
  versionadas no repositorio em texto (a chave, cifrada; nao protegem nada
  de valor).
- **Backup do Postgres no mesmo disco do Postgres.** O MinIO (destino do
  archive e da copia base) roda no mesmo cluster single-node, tipicamente
  sobre a mesma classe de armazenamento local do host que o proprio
  Postgres. Perda do disco leva os dois juntos -- **isto nao e backup**,
  existe para exercitar o mecanismo de recuperacao a ponto no tempo (D8).
- Aplicacao roda fora do cluster (D12) -- o dia a dia nao exercita imagem
  nem manifests da aplicacao.

## Pendencias que esta change deixa em aberto

- **Provedor de object storage de producao.** O overlay `prod` expressa o
  contrato de configuracao (ver secao acima), mas nao escolhe um provedor
  real. Fica para quando producao existir.
- **Proximidade entre compute e object storage em producao.** Telemetria em
  S3 remoto degrada muito a consulta (Tempo/Mimir puxam muitos objetos por
  consulta) e pode gerar custo inesperado com provedores que cobram
  retencao minima. Backup frio (Postgres) em S3 remoto e tranquilo;
  telemetria quente nao. Revisitar quando producao existir e a change
  `observabilidade` ja estiver rodando havendo volume real de dados.
