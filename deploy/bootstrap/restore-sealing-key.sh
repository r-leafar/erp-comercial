#!/usr/bin/env bash
# Restaura a chave de selagem de desenvolvimento (D4 do design), ANTES de
# qualquer SealedSecret ser aplicado. Sem isto, todo SealedSecret ja
# versionado fica indecifravel apos recriar o cluster -- o gotcha mais
# facil de diagnosticar errado (parece defeito de configuracao).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="${SCRIPT_DIR}/chave-selagem-dev.yaml"

log() { echo "[restore-sealing-key] $*"; }
kctl() { sudo k3s kubectl "$@"; }

# O namespace sealed-secrets ainda nao existe via GitOps neste ponto do
# bootstrap (a Application raiz so e aplicada depois de restore-sealing-key.sh
# -- ver bootstrap.sh e D14). Criar aqui e idempotente; o ArgoCD "adota" o
# mesmo recurso quando aplicar namespaces.yaml na onda -4.
kctl create namespace sealed-secrets --dry-run=client -o yaml | kctl apply -f -

log "Restaurando a chave de selagem de desenvolvimento..."
kctl apply -f "$KEY_FILE"

log "Chave restaurada em sealed-secrets/sealed-secrets-key-dev."
