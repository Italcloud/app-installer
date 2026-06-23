#!/usr/bin/env bash
set -euo pipefail

verifica_prerequisiti() {
  echo "==> Verifica prerequisiti..."
  local ok=true

  # Docker
  if ! command -v docker &>/dev/null; then
    echo "  [ERRORE] 'docker' non trovato. Installa Docker Engine: https://docs.docker.com/engine/install/" >&2
    ok=false
  else
    echo "  [OK] docker $(docker --version | awk '{print $3}' | tr -d ',')"
  fi

  # Docker Compose plugin v2
  if ! docker compose version &>/dev/null 2>&1; then
    echo "  [ERRORE] 'docker compose' (plugin v2) non trovato." >&2
    echo "           Installa il plugin: https://docs.docker.com/compose/install/" >&2
    ok=false
  else
    echo "  [OK] docker compose $(docker compose version --short 2>/dev/null || docker compose version | awk '{print $NF}')"
  fi

  # curl
  if ! command -v curl &>/dev/null; then
    echo "  [ERRORE] 'curl' non trovato. Installa con: apt-get install -y curl" >&2
    ok=false
  else
    echo "  [OK] curl $(curl --version | head -1 | awk '{print $2}')"
  fi

  # wget
  if ! command -v wget &>/dev/null; then
    echo "  [ERRORE] 'wget' non trovato. Installa con: apt-get install -y wget" >&2
    ok=false
  else
    echo "  [OK] wget $(wget --version | head -1 | awk '{print $3}')"
  fi

  # openssl (per generare segreti)
  if ! command -v openssl &>/dev/null; then
    echo "  [ERRORE] 'openssl' non trovato. Installa con: apt-get install -y openssl" >&2
    ok=false
  else
    echo "  [OK] openssl $(openssl version | awk '{print $2}')"
  fi

  if [[ "$ok" == false ]]; then
    echo "" >&2
    echo "Prerequisiti mancanti. Installa i pacchetti indicati e riprova." >&2
    exit 1
  fi

  # Verifica permessi Docker (utente corrente nel gruppo docker o root)
  if [[ $EUID -ne 0 ]] && ! docker info &>/dev/null 2>&1; then
    echo "" >&2
    echo "  [ERRORE] L'utente corrente non ha i permessi per usare Docker." >&2
    echo "           Aggiungi l'utente al gruppo docker: sudo usermod -aG docker \$USER" >&2
    echo "           oppure esegui lo script come root." >&2
    exit 1
  fi

  echo ""
}
