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
| CloudNativePG (operator) | `v1.30.0` | `deploy/base/plataforma/cnpg-operator/` |
| cert-manager | `v1.21.1` | `deploy/base/plataforma/cert-manager/` |
| Barman Cloud Plugin | `v0.15.0` | `deploy/base/plataforma/barman-cloud-plugin/` |
| MinIO | `RELEASE.2025-09-07T16-13-09Z` | `deploy/base/plataforma/minio/deployment.yaml` |
| MinIO Client (`mc`, job de buckets) | `RELEASE.2025-08-13T08-35-41Z` | `deploy/base/plataforma/minio-provision/buckets-job.yaml` |
| Valkey | `8.1-alpine` | `deploy/base/plataforma/valkey/deployment.yaml` |
| Podman | a que o gerenciador de pacotes da distro oferecer (sem pin reproduzivel — ver nota em `install-podman.sh`) | `deploy/bootstrap/install-podman.sh` |
| Grafana Alloy | `v1.19.2` | `deploy/base/observabilidade/alloy/deployment.yaml` |
| Grafana Tempo | `2.10.8` (presa na serie 2.x — 3.0 exige Kafka, ver nota no manifesto) | `deploy/base/observabilidade/tempo/deployment.yaml` |
| Grafana Mimir | `3.2.0` | `deploy/base/observabilidade/mimir/deployment.yaml` |
| Grafana Loki | `3.7.7` | `deploy/base/observabilidade/loki/deployment.yaml` |
| Grafana | `13.2.1` | `deploy/base/observabilidade/grafana/deployment.yaml` |

Atualizar aqui e no script/manifesto correspondente juntos quando houver
motivo para subir de versao. Nenhum componente usa tag `latest` ou
equivalente movel.

### Consumo de recursos

Medido ao vivo (tarefas 2.3/10.5), plataforma completa e saudavel, sem a
aplicacao rodando:

```
   CPU do no:      ~580m (7% de um host com 8 vCPU)
   Memoria do no:  ~4.4Gi (27% do alocavel)
   Host (free -h): 6.4Gi livre + 5.8Gi buff/cache, 11Gi "available"
```

MinIO e o maior consumidor de memoria isolado (~430Mi); o restante fica
abaixo de 200Mi por componente. Numero de referencia para as changes
seguintes dimensionarem o que vao somar (particularmente `observabilidade`,
que grava volume continuamente). Medido num host com 15Gi de RAM total —
recalcular se o seu diferir muito disso.

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

k3s nao roda nativamente no Windows — precisa do WSL2. Sete
pre-requisitos, cada um com um sintoma que **nao aponta para a causa** se
ficar ausente:

| Pre-requisito | Por que | Sintoma se ausente |
|---|---|---|
| `systemd=true` em `/etc/wsl.conf`, distro reiniciada apos a mudanca | k3s roda como servico systemd | Cluster nao sobe sozinho a cada nova sessao do WSL |
| Repositorio no filesystem do WSL (`~/...`), nunca em `/mnt/c/...` | Acesso ao disco do Windows via 9p e muito mais lento | Build, `dotnet watch` e deteccao de alteracao de arquivo ficam dramaticamente lentos |
| Memoria e CPU fixadas em `%UserProfile%\.wslconfig` | Por padrao o WSL2 toma ate metade da RAM do host | Maquina do desenvolvedor fica inutilizavel durante o trabalho normal |
| Compactacao periodica do VHDX conhecida (`diskpart` / `wsl --manage <distro> --shrink`, conforme a versao do WSL) | O VHDX cresce e **nao encolhe sozinho**; volumes de plataforma e telemetria escrevem sem parar | Disco do host se esgota, mesmo com espaco "liberado" dentro da distro |
| `loginctl enable-linger` para o seu usuario | `systemd=true` liga o systemd de SISTEMA (o que o k3s usa); o gerenciador de usuario (o que `systemctl --user` usa, exigido pelo soquete rootless do Podman) so nasce sozinho com o lingering habilitado | `Failed to connect to user scope bus via local transport: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined` -- nao menciona linger nem systemd de usuario em lugar nenhum |
| Binarios em Go precisam do resolvedor DNS via `cgo` (`GODEBUG=netdns=cgo`), nao do resolvedor puro do Go | O `/etc/resolv.conf` gerado pelo WSL2 aponta para o gateway virtual da distro; o resolvedor puro do Go nao consegue usa-lo (mesmo endereco sendo alcancavel por `curl`/glibc) | `lookup <host> on <ip>:53: no such host`, tanto em ferramentas rodadas no host (`kustomize build` contra recurso remoto) quanto em pods (`argocd-repo-server` ao clonar o repositorio) -- a mensagem no aponta para WSL2 nem para Go |
| `kubectl port-forward` para acessar paineis (ArgoCD, MinIO) do navegador do Windows -- `Ingress`/`NodePort` NAO chegam sozinhos | O encaminhamento automatico de `localhost` do WSL2 so detecta porta com socket de verdade em escuta; exposicao via `iptables`/NAT (o klipper-lb do Traefik, `kube-proxy` de qualquer `NodePort`) nao cria esse socket | `curl` de dentro do WSL2 funciona perfeitamente; o mesmo endereco simplesmente nao conecta do navegador do Windows, sem erro que aponte para a causa |

`install-podman.sh` detecta a ausencia de lingering e o habilita sozinho,
mas a sessao de shell **atual** ja nasceu sem os `$XDG_RUNTIME_DIR`/
`$DBUS_SESSION_BUS_ADDRESS` corretos -- feche o terminal e abra um novo (ou
`wsl --shutdown` no Windows) antes de rodar o script de novo.
`install-argocd.sh` ja aplica o contorno de DNS no `argocd-repo-server`;
se outro componente futuro tambem precisar sair para a internet (não
apenas para o cluster), o mesmo `GODEBUG=netdns=cgo` resolve.

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
| -5 | cert-manager (pre-requisito do Barman Cloud Plugin) |
| -4 | Namespaces, definicoes de recurso customizado, controller do Sealed Secrets, operator do CloudNativePG, Barman Cloud Plugin |
| -3 | Objetos `SealedSecret` |
| -2 | Valkey, MinIO |
| -1 | Job idempotente de provisionamento de buckets e credenciais no MinIO |
| 0 | Postgres (CloudNativePG) — depois do bucket existir; reservado tambem para a change `observabilidade`, pela mesma razao (ver gotcha abaixo) |
| 1 | (reservado — aplicacao, com 0 replicas em desenvolvimento) |

**GOTCHA (encontrado destruindo e recriando o cluster): Postgres precisa
estar numa onda DEPOIS do bucket, nao junto com o MinIO.** O health check
customizado do `Cluster` (ver acima) exige `ContinuousArchiving: True`, que
depende do bucket `postgres-backup` e da credencial de IAM ja existirem —
criados pelo job da onda -1. Compartilhar onda com o MinIO cria um impasse
circular: o ArgoCD espera o Cluster ficar saudavel para avancar de onda, e
o Cluster nunca fica saudavel sem o bucket da onda seguinte. Um health
check "raso" mascarava esse problema por acidente; corrigi-lo o tornou
visivel.

**Atencao:** "saudavel" para um recurso customizado depende de o ArgoCD
saber avalia-lo. Verifique, na versao fixada do ArgoCD e do operator do
CloudNativePG, se ha health check conhecido para o `Cluster` do CNPG. Se
nao houver, declare a avaliacao explicitamente — esta e a falha mais
provavel do bootstrap, e deve ser testada recriando o cluster, nao so na
primeira execucao.

**Confirmado ao vivo: nao havia.** O fallback generico do ArgoCD para o
`Cluster` do CNPG so olha a condicao `Ready` — um cluster fica `Ready` mesmo
com o archive continuo quebrado (`ContinuousArchiving: False`), e a
Application inteira aparecia "Healthy" apesar do backup estar parado.
Corrigido com um health check customizado
(`deploy/bootstrap/argocd-cnpg-health-patch.yaml`, registrado por
`install-argocd.sh` em `resource.customizations.health.postgresql.cnpg.io_Cluster`)
que confere `ContinuousArchiving` alem de `Ready`. Testado quebrando a
credencial do backup de proposito: a Application vai para `Degraded`; ao
restaurar, volta a `Healthy` assim que o archive volta a funcionar.

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

## Recuperacao a ponto no tempo (PITR) do Postgres

Exercitada de ponta a ponta (tarefas 8.8/8.9): gravar um dado, remove-lo,
restaurar para o instante anterior a remocao, conferir que o dado volta. O
procedimento cria um `Cluster` **novo** (nao mexe no original) que faz o
papel de instancia de verificacao:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: <nome-do-cluster-restaurado>
  namespace: data
spec:
  instances: 1
  storage:
    size: 10Gi
  bootstrap:
    recovery:
      source: erp-postgres          # nome do Cluster de origem
      recoveryTarget:
        targetTime: "<timestamp UTC>"
  externalClusters:
    - name: erp-postgres            # precisa bater com o `source` acima
      barmanObjectStore:
        serverName: erp-postgres    # GOTCHA abaixo -- nao pode faltar
        destinationPath: s3://postgres-backup/
        endpointURL: http://minio.storage.svc.cluster.local:9000
        s3Credentials:
          accessKeyId:
            name: minio-creds-postgres
            key: POSTGRES_BACKUP_ACCESS_KEY
          secretAccessKey:
            name: minio-creds-postgres
            key: POSTGRES_BACKUP_SECRET_KEY
        wal:
          compression: gzip
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: erp-postgres-backup
```

**GOTCHA (encontrado ao vivo): sem `serverName` explicito, a recuperacao
falha com `"no target backup found"`, mesmo com o backup existindo.** O
plugin usa o **proprio nome do cluster novo** como prefixo de busca no
catalogo de backups por padrao -- nao o nome declarado em
`bootstrap.recovery.source`. `externalClusters[].barmanObjectStore.serverName`
corrige isso, apontando explicitamente para o prefixo do cluster de origem.
Usa-se `barmanObjectStore` classico aqui (nao `plugin`) porque so ele aceita
`serverName`; o aviso de depreciacao que aparece ao aplicar e esperado e
inofensivo -- e so para a LEITURA do backup de origem, nao para o
arquivamento continuo do cluster restaurado (que usa `spec.plugins`
normalmente).

**Pre-requisito facil de esquecer:** a recuperacao busca uma copia base
(`Backup`) existente, nao so os segmentos de WAL. Sem nenhuma copia base
ainda tirada (a `ScheduledBackup` diaria pode nao ter rodado ainda num
cluster novo), tambem falha com `"no target backup found"` -- tirar uma
copia sob demanda antes de testar:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: <nome>
  namespace: data
spec:
  cluster:
    name: erp-postgres
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
```

**Instante fora da janela disponivel (antes da copia base mais antiga) e
recusado**, nunca aplicado silenciosamente: o job de recuperacao falha com
`"no target backup found"` e o Cluster nunca fica `Ready`.

## Acessando os paineis (ArgoCD, MinIO)

**Se voce esta no Windows com WSL2, o navegador so funciona com
`kubectl port-forward`. O `Ingress`/`nip.io` desta secao NAO abre no seu
navegador — nao pule esta frase.**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/minio -n storage 9001:9001
```

Depois, abra `http://localhost:8080` (ArgoCD) e `http://localhost:9001`
(MinIO) no navegador do Windows normalmente.

**Credenciais de login:**

```bash
# ArgoCD -- usuario "admin"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo

# MinIO -- usuario e senha
kubectl get secret minio-credentials -n storage -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d; echo
kubectl get secret minio-credentials -n storage -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d; echo
```

### Por que existe um Ingress, se o navegador do Windows nao usa

O k3s ja traz um Ingress controller (Traefik, escutando nas portas 80/443
do proprio host). `deploy/overlays/dev/ingress-argocd.yaml` e
`ingress-minio.yaml` expoem os dois paineis por ele, de forma generica --
API padrao `networking.k8s.io/v1`, sem CRD nem anotacao especifica de
controller, sem `ingressClassName` fixado (usa o default do cluster). Troque
o Traefik por outro Ingress e o mesmo manifesto continua funcionando.

**GOTCHA DE WSL2 (encontrado ao vivo, testado): o Ingress so responde a
chamadas feitas de DENTRO do proprio WSL2 (`curl`, scripts, health check
automatizado) — nunca ao navegador do Windows.** Nao existe cenario
pratico de "abrir num navegador dentro do WSL2" aqui: seria preciso um
navegador grafico rodando dentro da distro, o que este ambiente nao tem e
nao faz sentido montar so para isso. Trate este Ingress como utilidade de
linha de comando/automacao, nao como substituto do `port-forward` para
navegacao.

```bash
curl http://argocd.127.0.0.1.nip.io/   # responde de dentro do WSL2
curl http://minio.127.0.0.1.nip.io/    # responde de dentro do WSL2
```

Causa raiz: o encaminhamento automatico de `localhost` do WSL2 para o
Windows so detecta portas com um socket de verdade em escuta (`ss -tln`
mostra a porta; `kubectl port-forward` cria um, confirmado). O klipper-lb
do k3s (o que expoe a porta 80/443 do Traefik) e o `kube-proxy` (usado por
qualquer `NodePort`, testado e confirmado a mesma limitacao) expoem porta
por regra de `iptables`/NAT, sem socket literal -- por isso o `curl`
funciona de dentro do WSL2 (o NAT se aplica a qualquer trafego dentro do
mesmo namespace de rede) mas o encaminhamento automatico para o Windows
nunca detecta a porta para encaminhar.

Em Linux nativo (sem WSL2 no meio), este mesmo Ingress abriria normalmente
no navegador, sem nenhum ajuste — a limitacao e so do encaminhamento
automatico do WSL2, nao do manifesto.

**Por que o TLS do ArgoCD fica desligado
(`deploy/bootstrap/argocd-insecure-patch.yaml`, aplicado por
`install-argocd.sh`).** Sem isso, o backend fala HTTPS com certificado
autoassinado, e cada Ingress controller exigiria uma anotacao DIFERENTE
para saber terminar TLS e reencaminhar em HTTPS para o backend (uma
anotacao so do Traefik, outra so do nginx-ingress, etc.) -- quebrando a
genericidade. Com o backend em texto claro, qualquer Ingress padrao
funciona sem anotacao nenhuma. So vale para dev; em producao a exposicao
externa e outra decisao, fora do escopo desta change.

## Observabilidade (change `observabilidade`)

**Endereco de ingestao**, para a change `fundacao-aplicacao` (e para
qualquer emissor) enviar rastros, metricas e logs:

```
http://alloy.observability.svc.cluster.local:4317   # OTLP gRPC
http://alloy.observability.svc.cluster.local:4318   # OTLP HTTP
```

Quem emite nao precisa saber qual armazenamento recebe cada sinal (D1 do
design) -- so o endereco acima e o protocolo OTLP.

**Convencoes de atributo** que a aplicacao deve seguir, para que consultas e
paineis sobrevivam a troca futura do sistema de mensageria (D9): use os
nomes publicos e estaveis do OpenTelemetry para mensageria --
`messaging.system`, `messaging.operation` (`publish`/`process`/`receive`),
`messaging.destination.name` -- nunca um nome proprio da tecnologia de
transporte atual. Referencia executavel:
`deploy/base/observabilidade/synthetic-emitter/script.yaml`.

**A configuracao do agente fica ATRAS da costura OTLP.** A aplicacao emite
OTLP e nao sabe (nem precisa saber) o que recebe do outro lado. Isso
significa que trocar o Grafana Alloy por outra distribuicao do
OpenTelemetry Collector no futuro é uma mudanca confinada a
`deploy/base/observabilidade/alloy/` -- nao alcanca a aplicacao, os
armazenamentos (Tempo/Mimir/Loki so recebem OTLP/remote-write/push, sem
saber quem os alimenta) nem as specs desta change (escritas em termos de
comportamento observavel, sem nomear produto). O acoplamento real desta
change ao ecossistema Grafana fica inteiramente do lado RECEPTOR da
costura.

**Fora do escopo, de proposito**: nenhuma instrumentacao de codigo de
aplicacao, regra de alerta ou painel de negocio faz parte desta change --
so o receptor. Ver `openspec/changes/observabilidade/proposal.md`,
"Non-goals".

**Janelas de retencao de dev** (tarefa 6.6), curtas de proposito para que a
remocao efetiva seja verificavel em minutos, nao em dias -- propriedade de
dev que NAO vale em producao (retencao real depende de volume e custo de
armazenamento remoto, decisao adiada):

| Sinal | Janela | Onde |
|---|---|---|
| Rastros (Tempo) | `block_retention: 2h` | `overlays/dev/tempo-config.yaml` |
| Metricas (Mimir) | `compactor_blocks_retention_period: 2h` + `compactor.deletion_delay: 1h` | `overlays/dev/mimir-config.yaml` |
| Logs (Loki) | `limits_config.retention_period: 2h` | `overlays/dev/loki-config.yaml` |

**Nota de producao** (repetida do design, D8 do design de `observabilidade`
e do proposal): processamento e armazenamento de objetos devem ficar
proximos. Telemetria em armazenamento remoto degrada a consulta (cada
consulta recupera muitos objetos) e pode gerar custo inesperado (a
compactacao opera continuamente; provedores com cobranca minima de
permanencia cobram meses por blocos que existem por horas). Decisao
adiada para quando producao existir.

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
- **Metrica de esgotamento de disco do host (tarefa 6.5 de
  `observabilidade`).** Nao ha exportador de metricas de host (tipo
  node-exporter) nesta change; sem ele, a aproximacao do esgotamento de
  espaco em disco nao e observavel como metrica, so inferivel por
  `df`/`free` manual. Decidir se entra no escopo desta change ou fica para
  uma futura.
- **Metrica de consumo por bucket do MinIO (tarefa 6.4 de
  `observabilidade`).** O endpoint de metricas do MinIO
  (`/minio/v2/metrics/cluster`) exige um token Bearer dedicado
  (`mc admin prometheus generate`), diferente das credenciais por
  consumidor ja usadas. Nao implementado para nao introduzir mais um
  segredo so para isto -- cada backend (Tempo/Mimir/Loki) expoe sua PROPRIA
  metrica de consumo nativa em vez disso (ver tarefa 6.4 em
  `openspec/changes/observabilidade/tasks.md`).
- **Destruir e recriar o ambiente do zero com a observabilidade no ar**
  (tarefa 9.3 de `observabilidade`). Ainda nao exercitado nesta change --
  todo o resto foi validado ao vivo contra um cluster ja existente.
