#!/usr/bin/env bash
# Instala o agente de reconciliacao (ArgoCD). Idempotente: kubectl apply
# so aplica diferenca; reexecutar sobre uma instalacao ja existente conclui
# sem erro e sem recriar nada. Ver D1 e D14 do design.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_VERSION="v3.5.2"
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

log() { echo "[install-argocd] $*"; }

kctl() { sudo k3s kubectl "$@"; }

log "Instalando ArgoCD ${ARGOCD_VERSION}..."
kctl create namespace argocd --dry-run=client -o yaml | kctl apply -f -

# --server-side: a CRD do ApplicationSet e grande o bastante para estourar
# o limite de 256 KiB da anotacao last-applied-configuration que o apply
# client-side (padrao) usa para calcular diff. Server-side apply nao
# depende dessa anotacao. --force-conflicts mantem a reexecucao idempotente
# mesmo que o field manager mude entre versoes do kubectl.
kctl apply -n argocd --server-side --force-conflicts -f "$MANIFEST_URL"

log "Aguardando os deployments do ArgoCD ficarem disponiveis..."
kctl -n argocd wait --for=condition=available --timeout=300s deployment --all

# GOTCHA DE WSL2: o resolvedor DNS puro do Go (usado pelo argocd-repo-server
# para clonar o repositorio) falha neste ambiente com "no such host" contra
# o CoreDNS do proprio cluster -- o MESMO problema, pela mesma causa, que
# ja apareceu com o binario do kustomize no host (ver deploy/README.md).
# GODEBUG=netdns=cgo forca o resolvedor via glibc, que funciona. Idempotente:
# `kubectl set env` com o mesmo valor e no-op.
log "Aplicando o contorno de DNS do WSL2 no argocd-repo-server..."
kctl set env deployment/argocd-repo-server -n argocd GODEBUG=netdns=cgo
kctl -n argocd rollout status deployment/argocd-repo-server --timeout=120s

# Health check customizado para o Cluster do CNPG (D3, D8, tarefa 5.5): o
# fallback generico do ArgoCD so olha a condicao Ready, mascarando archive
# continuo quebrado. Ver deploy/bootstrap/argocd-cnpg-health-patch.yaml.
log "Registrando o health check customizado do Cluster (CNPG)..."
kctl patch configmap argocd-cm -n argocd --type merge \
  --patch-file "${SCRIPT_DIR}/argocd-cnpg-health-patch.yaml"

log "ArgoCD instalado e disponivel."
