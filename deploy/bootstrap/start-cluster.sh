#!/usr/bin/env bash
# Inicia o cluster k3s apos ter sido parado com stop-cluster.sh.
# Nao reinstala nada — usa a instalacao ja existente.
# Para instalacao completa do zero, use bootstrap.sh.
set -euo pipefail

log() { echo "[start-cluster] $*"; }

if ! command -v k3s >/dev/null 2>&1; then
  log "k3s nao esta instalado. Para instalar, execute: ./deploy/bootstrap/bootstrap.sh"
  exit 1
fi

if systemctl is-active --quiet k3s; then
  log "k3s ja esta rodando. Nada a fazer."
  exit 0
fi

log "Iniciando k3s..."
sudo systemctl start k3s

log "Aguardando o no ficar Ready..."
for _ in $(seq 1 30); do
  if sudo k3s kubectl get nodes 2>/dev/null | grep -qw Ready; then
    log "Cluster pronto."
    exit 0
  fi
  sleep 1
done

log "Timeout esperando cluster ficar Ready."
exit 1
