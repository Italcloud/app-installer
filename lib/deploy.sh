#!/usr/bin/env bash
set -euo pipefail

# Esegue docker compose up nella directory indicata
deploy_app() {
  local dir="$1"

  cd "$dir"

  echo "→ Pull immagini Docker..."
  docker compose pull

  echo "→ Avvio container in background..."
  docker compose up -d

  cd - >/dev/null
}

# Verifica che i container siano Running dopo il deploy
verifica_container() {
  local dir="$1"
  local tentativi=12
  local attesa=5

  cd "$dir"

  echo "→ Attendo l'avvio dei container (max $((tentativi * attesa))s)..."

  local i
  for ((i = 1; i <= tentativi; i++)); do
    local totale running
    totale=$(docker compose ps --quiet 2>/dev/null | wc -l)
    running=$(docker compose ps --status=running --quiet 2>/dev/null | wc -l)

    if (( totale > 0 && running == totale )); then
      echo ""
      echo "  Tutti i container sono in esecuzione ($running/$totale)."
      docker compose ps
      cd - >/dev/null
      return 0
    fi

    local failed
    failed=$(docker compose ps --status=exited --quiet 2>/dev/null | wc -l)
    if (( failed > 0 )); then
      echo "" >&2
      echo "  [ERRORE] $failed container in stato 'exited'. Log di errore:" >&2
      docker compose logs --tail=30 >&2
      cd - >/dev/null
      return 1
    fi

    printf "  Tentativo %d/%d — Running: %d/%d. Attendo %ds...\r" \
      "$i" "$tentativi" "$running" "$totale" "$attesa"
    sleep "$attesa"
  done

  echo "" >&2
  echo "  [ATTENZIONE] Timeout: non tutti i container sono Running dopo $((tentativi * attesa))s." >&2
  echo "  Stato attuale:" >&2
  docker compose ps >&2
  cd - >/dev/null
  return 1
}
