#!/usr/bin/env bash
# Desfaz exatamente o que install-cluster.sh criou. Nao faz parte do
# orquestrador bootstrap.sh -- e chamado a parte, quando se quer testar a
# recriacao do ambiente do zero (ver tarefa 10.1 e D14 do design).
set -euo pipefail

log() { echo "[destroy-cluster] $*"; }
fail() { echo "[destroy-cluster] $*" >&2; exit 1; }

if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
  log "Executando o desinstalador oficial do k3s..."
  sudo /usr/local/bin/k3s-uninstall.sh
  log "k3s removido."
elif command -v k3s >/dev/null 2>&1; then
  fail "k3s presente mas sem /usr/local/bin/k3s-uninstall.sh (instalacao fora do padrao esperado por install-cluster.sh). Remocao manual necessaria."
else
  log "k3s nao esta instalado. Nada a destruir."
fi
