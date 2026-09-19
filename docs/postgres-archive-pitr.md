# Archive Contínuo e Recuperação a Ponto no Tempo (PITR) do PostgreSQL

## Visão Geral

Este projeto implementa um mecanismo robusto de **backup e recuperação** para o PostgreSQL usando:

- **WAL Archiving Contínuo** (via Barman Cloud Plugin): captura cada transação confirmada
- **Base Backups Periódicos** (diários às 03h UTC): snapshots do banco para ponto de partida
- **Recuperação a Ponto no Tempo (PITR)**: restaura o banco para qualquer instante dentro da janela

O arquivo deste projeto é **ejercitado na prática**, não apenas configurado. A change `plataforma-gitops` (tarefa 8.8/8.9) valida PITR completo: grava dado → remove → restaura para o instante anterior → confirma que o dado volta.

---

## Arquitetura: Fluxo de Dados

```
+-----------------------------------------------+
|         POSTGRESQL (CloudNativePG)            |
|                                               |
|  Cluster: erp-postgres (1 instância em dev)  |
|  Database: erp                                |
|  Storage: 10Gi local (classe de               |
|           armazenamento padrão do k3s)       |
|                                               |
|  Gera continuamente:                          |
|  - Transações confirmadas                     |
|  - WAL files (Write-Ahead Logs) com as       |
|    mudanças de cada transação                |
+----------|-----------------------------------+
           |
           | Barman Cloud Plugin
           | (especificado em spec.plugins)
           | isWALArchiver: true
           |
           | Comprime cada segmento de WAL
           | com gzip antes de enviar
           |
           v
+-----------------------------------------------+
|  MINIO (Object Storage S3-compatible)        |
|                                               |
|  Bucket: postgres-backup/                    |
|                                               |
|  Armazena dois tipos de objeto:              |
|                                               |
|  1. WAL Archive (contínuo)                   |
|     - Cada WAL comprimido                    |
|     - Enviado assim que o segmento fecha     |
|     - Permite recuperar até o último         |
|       segundo antes do erro                  |
|                                               |
|  2. Base Backups (periódico - diário 03h)   |
|     - Snapshot completo do banco             |
|     - Ponto de partida para PITR             |
|     - Sem base backup, não há PITR           |
|                                               |
|  Compressão: gzip (reduz espaço em disco)   |
|  Credenciais: minio-creds-postgres           |
|              (Secret versionado em Git)      |
+-----------------------------------------------+
```

---

## Componentes: O que Faz O Quê

### 1. **PostgreSQL + CloudNativePG**

O CloudNativePG é um operador Kubernetes que gerencia PostgreSQL como recurso declarativo.

**Arquivo:** `deploy/base/plataforma/postgres/cluster.yaml`

```yaml
spec:
  instances: 1              # Uma instância em dev (single-node)
  storage:
    size: 10Gi             # Espaço para dados + WAL
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true   # Ativa archivamento contínuo
      parameters:
        barmanObjectName: erp-postgres-backup  # Refere ao ObjectStore
```

**O que acontece:**
- PostgreSQL gera WAL files à medida que transações são confirmadas
- O plugin Barman "observa" esses WALs
- Assim que um WAL segmento fecha (geralmente a cada 16MB), é enviado para MinIO

### 2. **Barman Cloud Plugin**

Plugin que implementa o archivamento de WAL no PostgreSQL, enviando-os para S3/MinIO.

**Como funciona:**
1. PostgreSQL notifica o plugin quando um WAL está pronto para archive
2. Plugin comprime o WAL com gzip
3. Envia via HTTP para MinIO (ou S3 em prod)
4. PostgreSQL marca o WAL como arquivado

**Importante:** Falha no envio do WAL **bloqueia o cluster** para evitar perda de transações. Se MinIO cair, o Postgres fica preso esperando conseguir enviar.

### 3. **ObjectStore (Barman Configuration)**

Define **onde** e **como** os backups são armazenados.

**Arquivo:** `deploy/base/plataforma/postgres/objectstore.yaml`

```yaml
spec:
  configuration:
    destinationPath: s3://postgres-backup/      # Bucket no MinIO
    endpointURL: http://minio.storage.svc...    # Endpoint interno
    s3Credentials:
      accessKeyId:
        name: minio-creds-postgres              # Secret versionado
```

**Não é o Barman clássico** (que é servidor standalone). É uma versão "cloud" que:
- Roda como plugin dentro do PostgreSQL
- Envia WALs diretamente para S3/MinIO
- Não precisa de server Barman separado

### 4. **ScheduledBackup (Cópia Base Periódica)**

Tira snapshots do banco periodicamente.

**Arquivo:** `deploy/base/plataforma/postgres/scheduled-backup.yaml`

```yaml
spec:
  schedule: "0 0 3 * * *"      # Diário às 03h UTC
  method: plugin                # Via Barman Cloud Plugin
  cluster:
    name: erp-postgres
```

**Por que precisa:**

A recuperação a ponto no tempo precisa de um **ponto de partida**:

```
Timeline:
|----[Base Backup 03h]----[WAL 1]----[WAL 2]----[WAL 3]----[ERRO]
                                               ^
                                    Você quer restaurar para aqui
                                    CloudNativePG faz:
                                    1. Restaura Base Backup
                                    2. Reproduz WAL 1, 2
                                    3. Para (ponto no tempo atingido)
```

Sem base backup, PITR falha com `"no target backup found"`.

---

## Recuperação a Ponto no Tempo (PITR)

### O Que É

Restaurar o PostgreSQL para um instante específico no passado, reproduzindo:

1. O estado de um snapshot anterior (base backup)
2. Todas as transações confirmadas após aquele snapshot, até o instante escolhido

### Como Funciona (Passo-a-Passo)

```
USER
  |
  | "Preciso restaurar para 14:30 UTC"
  v
┌─────────────────────────────────────────────────┐
│ 1. CloudNativePG procura no MinIO:              │
│    - Base backups anterior a 14:30 UTC          │
│    - WALs de 14:30 para frente                  │
└────────────|─────────────────────────────────────┘
             |
             v
┌─────────────────────────────────────────────────┐
│ 2. Cria um CLUSTER NOVO (não mexe no original)  │
│    bootstrap:                                    │
│      recovery:                                   │
│        source: erp-postgres (cluster original)  │
│        recoveryTarget:                           │
│          targetTime: "2026-09-19T14:30:00Z"     │
└────────────|─────────────────────────────────────┘
             |
             v
┌─────────────────────────────────────────────────┐
│ 3. CloudNativePG no novo cluster:               │
│    a) Restaura o base backup                    │
│    b) Reproduz cada WAL em sequência            │
│    c) Para quando atinge targetTime             │
│    d) Novo cluster pronto em estado consistente │
└────────────|─────────────────────────────────────┘
             |
             v
┌─────────────────────────────────────────────────┐
│ 4. Novo cluster pronto para uso!                │
│    - Pode conectar e consultar dados            │
│    - Pode promover a principal se necessário    │
│    - Original continua rodando normalmente      │
└─────────────────────────────────────────────────┘
```

### Janela de Recuperação

Você pode restaurar para qualquer ponto **entre**:

- **Início:** data do base backup periódico mais recente
- **Fim:** últimas transações arquivadas

Em dev: base backup diário = janela mínima é ~1 dia (se backup de ontem existe)

Em prod: com mais base backups, a janela seria maior ou mais flexível conforme política.

---

## Como Usar: Exemplo Prático

### Cenário: Removeu um registro por acidente

```bash
# 1. Identifique o timestamp aproximado
   "Removi o registro às 2026-09-19 14:35 UTC"

# 2. Crie um manifest de recuperação (novo arquivo YAML)
cat > /tmp/recovery-cluster.yaml <<'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: erp-postgres-recovery-test
  namespace: data
spec:
  instances: 1
  storage:
    size: 10Gi
  bootstrap:
    recovery:
      source: erp-postgres                      # cluster original
      recoveryTarget:
        targetTime: "2026-09-19T14:34:00Z"      # 1 min antes da remoção
  externalClusters:
    - name: erp-postgres                        # DEVE bater com 'source'
      barmanObjectStore:
        serverName: erp-postgres                # GOTCHA: obrigatório
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
EOF

# 3. Aplique o manifest
kubectl apply -f /tmp/recovery-cluster.yaml

# 4. Aguarde o cluster restaurado ficar ready
kubectl get cluster -n data erp-postgres-recovery-test -w

# 5. Conecte e verifique que o registro está lá
kubectl port-forward -n data svc/erp-postgres-recovery-test 5432:5432
psql -U erp -d erp -h localhost -c "SELECT * FROM tabela_em_questao;"

# 6. Confirme que está restaurado corretamente
#    Se sim: pode usar os dados daqui
#    Se não: delete este cluster e tente outro timestamp

# 7. Limpe (delete o cluster de teste)
kubectl delete cluster -n data erp-postgres-recovery-test
```

---

## Gotchas (Problemas Reais Encontrados)

### Gotcha 1: `"no target backup found"` sem `serverName`

**Sintoma:**
```
Cluster recoverto fica em estado `invalid` ou loop de erro
Logs: "no target backup found"
Backup existe no MinIO, mas não é encontrado
```

**Causa:**
O plugin procura por backup usando o **nome do cluster novo** como prefixo de busca, não o nome do cluster original.

**Solução:**
```yaml
externalClusters:
  - name: erp-postgres
    barmanObjectStore:
      serverName: erp-postgres  # <- OBRIGATÓRIO
                                # Aponta para prefixo do cluster original
```

### Gotcha 2: Nenhum base backup tirado ainda

**Sintoma:**
```
"no target backup found" mesmo que você tenha WALs arquivados
```

**Causa:**
PITR precisa de um base backup como ponto de partida. A `ScheduledBackup` diária pode não ter rodado em um cluster novo.

**Solução:**
Tire uma base backup sob demanda antes de testar PITR:

```bash
# Criar uma cópia base on-demand
kubectl apply -f - <<'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: erp-postgres-manual-backup
  namespace: data
spec:
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
  cluster:
    name: erp-postgres
EOF

# Aguardar conclusão
kubectl get backup -n data -w
```

### Gotcha 3: Recuperação busca `externalClusters` clássico, não `spec.plugins`

**Entender:**

Para **archivamento contínuo** (cluster normal):
```yaml
spec:
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true          # <- usa plugin moderno
```

Para **recuperação** (leitura do arquivo):
```yaml
externalClusters:
  - barmanObjectStore:              # <- usa config clássica
      serverName: ...               # mas isso é só para LER backup
```

Por quê? Porque o plugin de recuperação do CloudNativePG ainda usa a config clássica. Sim, é confuso. Sim, é um gotcha.

---

## Monitoramento: Como Saber se Está Funcionando

### Observar o Estado

```bash
# Ver status do cluster
kubectl get cluster -n data erp-postgres -o wide

# Ver backups existentes
kubectl get backups -n data

# Ver WALs arquivados (via MinIO)
kubectl port-forward -n storage svc/minio 9001:9001
# Abrir http://localhost:9001
# Navegar para bucket postgres-backup/
# Esperar arquivos WAL (10000000001.gz, etc)
```

### Alertas Importantes

**⚠️ Se MinIO cair:** PostgreSQL fica bloqueado esperando enviar WAL
```bash
kubectl logs -n data erp-postgres-0 | grep -i "archive"
```

**⚠️ Se archivamento travar:** Postgres fica sem espaço em disco eventualmente
```bash
# Verificar métricas no Grafana
# Dashboard: CloudNativePG health
# Métrica: cnpg_continuous_archiving_status
```

---

## Referências

- **CloudNativePG:** https://cloudnative-pg.io/documentation/current/recovery/
- **Barman Cloud:** https://www.pgbarman.org/doc/
- **PostgreSQL WAL:** https://www.postgresql.org/docs/current/wal-intro.html
- **PITR Concept:** https://en.wikipedia.org/wiki/Point-in-time_recovery

---

## Validação da Change

Esta funcionalidade foi **completamente testada** na change `plataforma-gitops`, tarefa 8.8/8.9:

✅ Grava dado no banco  
✅ Remove o dado  
✅ Recupera o banco para o instante anterior  
✅ Confirma que o dado volta (comparação explícita)  
✅ Cluster restaurado está em estado consistente  
✅ Procedimento é **reproducível** (testado em destroy/recreate)

---

## Para Aprofundar

Leia os specs e tasks originais em:
- `openspec/changes/plataforma-gitops/specs/plataforma/persistencia-relacional/spec.md`
- `openspec/changes/plataforma-gitops/design.md` (decisão D8: Archive Strategy)
- `openspec/changes/plataforma-gitops/tasks.md` (tarefas 8.1 a 8.9)
