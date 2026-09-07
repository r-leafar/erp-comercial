#!/usr/bin/env bash
# Instala o agente de reconciliacao (ArgoCD). Idempotente: kubectl apply
# so aplica diferenca; reexecutar sobre uma instalacao ja existente conclui
# sem erro e sem recriar nada. Ver D1 e D14 do design.
set -euo pipefail

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

log "ArgoCD instalado e disponivel."
