#!/usr/bin/env bash
# Instala o motor de container do host (D15 do design): Podman nativo,
# rootless, sem Podman Desktop. Usado para construir a imagem da aplicacao
# (D12) e, pela mesma soquete compativel com a API do Docker, pelos testes
# de Application/Infrastructure com Testcontainers (change fundacao-aplicacao).
set -euo pipefail

log() { echo "[install-podman] $*"; }
fail() { echo "[install-podman] $*" >&2; exit 1; }

if command -v podman >/dev/null 2>&1; then
  log "Podman ja instalado: $(podman --version)."
else
  if ! command -v apt-get >/dev/null 2>&1; then
    fail "distro sem apt-get; instale o Podman manualmente e rode este script de novo so para ativar o soquete. Ver deploy/README.md."
  fi
  log "Instalando Podman via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y podman
  log "Instalado: $(podman --version)."
fi

# NOTA: ao contrario do k3s, o gerenciador de pacotes da distro nao permite
# fixar uma versao exata de forma portavel entre sistemas -- a versao efetiva
# e a que o repositorio da distro oferece no momento da instalacao. Nao ha
# pin reproduzivel equivalente ao do k3s; ver deploy/README.md.

log "Habilitando o soquete rootless compativel com a API do Docker..."

# GOTCHA DE WSL2: `systemctl --user` exige um gerenciador de usuario
# systemd rodando, que so nasce sozinho com "linger" habilitado para o
# usuario. Sem isso, $XDG_RUNTIME_DIR e $DBUS_SESSION_BUS_ADDRESS nunca
# existem -- mesmo com systemd=true em /etc/wsl.conf (esse resolve o k3s,
# nao o systemd de USUARIO). Sintoma: "Failed to connect to user scope bus
# via local transport", que nao aponta para a causa real.
if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "${XDG_RUNTIME_DIR:-/nonexistent}" ]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [ ! -S "${XDG_RUNTIME_DIR}/bus" ] && [ ! -S "${XDG_RUNTIME_DIR}/systemd/private" ]; then
  linger="$(loginctl show-user "$(id -un)" --property=Linger --value 2>/dev/null || echo no)"
  if [ "$linger" != "yes" ]; then
    log "Habilitando o gerenciador de usuario systemd (linger) para $(id -un)..."
    sudo loginctl enable-linger "$(id -un)"
    sleep 2
  fi
fi

if [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

if ! systemctl --user enable --now podman.socket; then
  fail "$(cat <<EOF
nao foi possivel habilitar o soquete nesta sessao de shell (gerenciador de
usuario systemd ainda nao disponivel em ${XDG_RUNTIME_DIR}). O linger foi
habilitado para $(id -un); feche este terminal, abra um novo (ou rode
'wsl --shutdown' no Windows e reabra a distro) e execute este script de
novo -- so entao a nova sessao de shell nasce com o gerenciador de usuario
ja rodando.
EOF
)"
fi

podman info >/dev/null
log "Podman pronto: 'podman info' responde sem sudo."
log "Soquete: $(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null || echo "${XDG_RUNTIME_DIR}/podman/podman.sock")"
