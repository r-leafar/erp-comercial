#!/usr/bin/env bash
# Aplica a Application raiz do ArgoCD, apontando para deploy/overlays/dev.
# A partir daqui, o proprio ArgoCD reconcilia tudo (D1): nenhum kubectl
# apply imperativo alem deste.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[apply-root-app] $*"; }

log "Aplicando a Application raiz (deploy/overlays/dev)..."
sudo k3s kubectl apply -f "${SCRIPT_DIR}/root-app.yaml"

log "Application raiz aplicada. O ArgoCD assume a reconciliacao a partir daqui."
