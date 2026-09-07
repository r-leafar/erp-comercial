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
systemctl --user enable --now podman.socket

podman info >/dev/null
log "Podman pronto: 'podman info' responde sem sudo."
log "Soquete: $(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null || echo '$XDG_RUNTIME_DIR/podman/podman.sock')"
