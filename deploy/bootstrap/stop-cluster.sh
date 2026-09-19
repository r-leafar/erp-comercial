#!/usr/bin/env bash
# Para o cluster k3s, mantendo a instalacao intacta. Os dados persistem.
# Para destruir completamente (remover instalacao), use destroy-cluster.sh.
# Para iniciar novamente apos parar, use start-cluster.sh.
set -euo pipefail

log() { echo "[stop-cluster] $*"; }

if systemctl is-active --quiet k3s; then
  log "Parando k3s..."
  sudo systemctl stop k3s
  log "k3s parado. Os dados e configuracao persistem."
  log "Para iniciar novamente: ./deploy/bootstrap/start-cluster.sh"
else
  log "k3s nao esta rodando. Nada a fazer."
fi
