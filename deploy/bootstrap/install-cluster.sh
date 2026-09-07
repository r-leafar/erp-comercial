#!/usr/bin/env bash
# Cria o cluster k3s local de desenvolvimento (Linux nativo ou WSL2).
# Ver deploy/README.md para a versao fixada e os pre-requisitos por SO.
set -euo pipefail

K3S_VERSION="v1.36.4+k3s1"

log() { echo "[install-cluster] $*"; }
fail() { echo "[install-cluster] $*" >&2; exit 1; }

if [ "$(uname -s)" != "Linux" ]; then
  fail "suportado apenas em Linux (nativo ou WSL2). Ver deploy/README.md."
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
  log "Host detectado: WSL2."
  if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    fail "$(cat <<'EOF'
systemd nao esta ativo como PID 1 nesta distro WSL2. k3s roda como servico
systemd e nao sobe sozinho sem ele. Habilite em /etc/wsl.conf:

    [boot]
    systemd=true

Reinicie a distro (`wsl --shutdown` no Windows) e rode este script de novo.
Ver deploy/README.md, secao "Windows com WSL2".
EOF
)"
  fi
else
  log "Host detectado: Linux nativo."
fi

if command -v k3s >/dev/null 2>&1; then
  current_version="$(k3s --version | head -n1 | awk '{print $3}')"
  if [ "$current_version" = "$K3S_VERSION" ]; then
    log "k3s ${K3S_VERSION} ja instalado. Nada a fazer."
    exit 0
  fi
  log "k3s instalado em versao diferente (${current_version}). Reinstalando na versao fixada ${K3S_VERSION}."
fi

log "Instalando k3s ${K3S_VERSION}..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -

log "Aguardando o no ficar Ready..."
for _ in $(seq 1 30); do
  if sudo k3s kubectl get nodes 2>/dev/null | grep -qw Ready; then
    log "Cluster pronto."
    exit 0
  fi
  sleep 2
done

fail "cluster nao ficou Ready a tempo. Verifique 'sudo systemctl status k3s'."
