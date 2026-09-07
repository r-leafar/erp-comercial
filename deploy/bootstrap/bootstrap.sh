#!/usr/bin/env bash
# Orquestrador do bootstrap (D14 do design). So decide a ORDEM de chamada
# dos demais scripts -- nenhuma logica de instalacao de ferramenta vive
# aqui. Cada script cobre uma unica responsabilidade e e verificavel
# isoladamente. Padrao extensivel: uma ferramenta de host nova = um script
# novo + uma linha aqui.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[bootstrap] $*"; }

log "1/5 criando o cluster k3s..."
"${SCRIPT_DIR}/install-cluster.sh"

log "2/5 instalando o Podman (motor de container do host, D15)..."
"${SCRIPT_DIR}/install-podman.sh"

log "3/5 instalando o ArgoCD..."
"${SCRIPT_DIR}/install-argocd.sh"

log "4/5 restaurando a chave de selagem de desenvolvimento..."
"${SCRIPT_DIR}/restore-sealing-key.sh"

log "5/5 aplicando a Application raiz (overlays/dev)..."
"${SCRIPT_DIR}/apply-root-app.sh"

log "Bootstrap concluido. O ArgoCD assume a reconciliacao a partir daqui."
