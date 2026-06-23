#!/usr/bin/env bash
set -euo pipefail

# ─── Configurazione ────────────────────────────────────────────────────────────
REPO_URL="https://raw.githubusercontent.com/Italcloud/app-installer/master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ─── Librerie ──────────────────────────────────────────────────────────────────
# Se lo script viene eseguito da remoto (wget | bash), scarica le lib al volo
if [[ -f "$SCRIPT_DIR/lib/checks.sh" ]]; then
  source "$SCRIPT_DIR/lib/checks.sh"
  source "$SCRIPT_DIR/lib/prompts.sh"
  source "$SCRIPT_DIR/lib/deploy.sh"
else
  TMPLIB=$(mktemp -d)
  trap 'rm -rf "$TMPLIB"' EXIT
  for lib in checks prompts deploy; do
    curl -fsSL "$REPO_URL/lib/${lib}.sh" -o "$TMPLIB/${lib}.sh"
  done
  source "$TMPLIB/checks.sh"
  source "$TMPLIB/prompts.sh"
  source "$TMPLIB/deploy.sh"
fi

# ─── App disponibili ───────────────────────────────────────────────────────────
APPS=(
  zoraxy
  nginx-proxy-manager
  outline
  checkmk
  omada-controller
  netbird
  authentik
)

# ─── Funzioni ──────────────────────────────────────────────────────────────────
mostra_banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║          App Installer — Italcloud                       ║"
  echo "║     Installazione automatica container Docker            ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
}

mostra_menu() {
  echo "App disponibili:"
  echo ""
  local i=1
  for app in "${APPS[@]}"; do
    local conf_url="$REPO_URL/apps/$app/app.conf"
    local desc=""
    # Prova a leggere la descrizione dal conf locale prima
    if [[ -f "$SCRIPT_DIR/apps/$app/app.conf" ]]; then
      desc=$(grep '^APP_DESCRIPTION=' "$SCRIPT_DIR/apps/$app/app.conf" | cut -d= -f2- | tr -d '"')
    fi
    if [[ -z "$desc" ]]; then
      printf "  %d) %s\n" "$i" "$app"
    else
      printf "  %d) %-25s %s\n" "$i" "$app" "$desc"
    fi
    ((i++))
  done
  echo ""
}

scegli_app() {
  mostra_menu
  local scelta
  while true; do
    leggi_input "Scegli un numero (1-${#APPS[@]})" "" scelta
    if [[ "$scelta" =~ ^[0-9]+$ ]] && (( scelta >= 1 && scelta <= ${#APPS[@]} )); then
      APP_NAME="${APPS[$((scelta-1))]}"
      break
    fi
    echo "Scelta non valida. Inserisci un numero tra 1 e ${#APPS[@]}."
  done
}

carica_app_conf() {
  local app="$1"
  local conf_file

  if [[ -f "$SCRIPT_DIR/apps/$app/app.conf" ]]; then
    conf_file="$SCRIPT_DIR/apps/$app/app.conf"
  else
    conf_file="$TMPLIB/${app}_app.conf"
    curl -fsSL "$REPO_URL/apps/$app/app.conf" -o "$conf_file"
  fi

  source "$conf_file"
}

scarica_file_app() {
  local app="$1"
  local dest="$2"

  echo ""
  echo "→ Download docker-compose.yml ..."
  if [[ -f "$SCRIPT_DIR/apps/$app/docker-compose.yml" ]]; then
    cp "$SCRIPT_DIR/apps/$app/docker-compose.yml" "$dest/docker-compose.yml"
  else
    curl -fsSL "$REPO_URL/apps/$app/docker-compose.yml" -o "$dest/docker-compose.yml"
  fi

  echo "→ Download .env.example ..."
  if [[ -f "$SCRIPT_DIR/apps/$app/.env.example" ]]; then
    cp "$SCRIPT_DIR/apps/$app/.env.example" "$dest/.env.example"
  else
    curl -fsSL "$REPO_URL/apps/$app/.env.example" -o "$dest/.env.example"
  fi
}

chiedi_variabili_app() {
  local app="$1"

  case "$app" in
    zoraxy)
      leggi_input "Porta management UI" "8000" MANAGEMENT_PORT
      ;;
    nginx-proxy-manager)
      leggi_input "Email amministratore" "admin@example.com" ADMIN_EMAIL
      chiedi_password "Password amministratore" ADMIN_PASSWORD
      leggi_input "Porta management UI" "81" MANAGEMENT_PORT
      ;;
    outline)
      echo "→ Generazione chiavi segrete automatica..."
      SECRET_KEY=$(genera_secret)
      UTILS_SECRET=$(genera_secret)
      echo "   SECRET_KEY    : $SECRET_KEY"
      echo "   UTILS_SECRET  : $UTILS_SECRET"
      leggi_input "URL pubblico di Outline (es. https://docs.example.com)" "" OUTLINE_URL
      echo ""
      echo "Provider OAuth — scegli uno tra: slack, google, azure, oidc"
      leggi_input "Provider OAuth" "slack" OAUTH_PROVIDER
      case "$OAUTH_PROVIDER" in
        slack)
          leggi_input "Slack Client ID" "" SLACK_CLIENT_ID
          chiedi_password "Slack Client Secret" SLACK_CLIENT_SECRET
          ;;
        google)
          leggi_input "Google Client ID" "" GOOGLE_CLIENT_ID
          chiedi_password "Google Client Secret" GOOGLE_CLIENT_SECRET
          ;;
        *)
          leggi_input "OAuth Client ID" "" OAUTH_CLIENT_ID
          chiedi_password "OAuth Client Secret" OAUTH_CLIENT_SECRET
          ;;
      esac
      ;;
    checkmk)
      chiedi_password "Password amministratore (utente: cmkadmin)" ADMIN_PASSWORD
      ;;
    omada-controller)
      echo "→ Nessuna variabile critica richiesta per Omada Controller."
      ;;
    netbird)
      leggi_input "Dominio pubblico NetBird (es. nb.example.com)" "" NETBIRD_DOMAIN
      echo "→ Generazione password TURN/COTURN automatica..."
      TURN_PASSWORD=$(genera_secret)
      COTURN_PASSWORD=$(genera_secret)
      echo "   TURN_PASSWORD   : $TURN_PASSWORD"
      echo "   COTURN_PASSWORD : $COTURN_PASSWORD"
      echo ""
      leggi_si_no "Vuoi configurare Authentik come provider OIDC?" "n" USE_AUTHENTIK
      if [[ "$USE_AUTHENTIK" == "s" ]]; then
        leggi_input "URL Authentik (es. https://auth.example.com)" "" AUTHENTIK_URL
        leggi_input "OIDC Client ID" "" OIDC_CLIENT_ID
        chiedi_password "OIDC Client Secret" OIDC_CLIENT_SECRET
      fi
      ;;
    authentik)
      echo "→ Generazione segreti automatica..."
      PG_PASSWORD=$(genera_secret)
      AUTHENTIK_SECRET_KEY=$(genera_secret)
      echo "   PG_PASSWORD           : $PG_PASSWORD"
      echo "   AUTHENTIK_SECRET_KEY  : $AUTHENTIK_SECRET_KEY"
      leggi_input "Email amministratore Authentik" "admin@example.com" ADMIN_EMAIL
      leggi_input "Dominio pubblico Authentik (es. auth.example.com)" "" DOMAIN
      ;;
  esac
}

genera_env() {
  local app="$1"
  local dest="$2"
  local env_file="$dest/.env"

  cp "$dest/.env.example" "$env_file"

  # Sostituisce le variabili nel .env
  sed_inplace() {
    local key="$1" val="$2"
    # Escape caratteri speciali per sed
    local escaped_val
    escaped_val=$(printf '%s\n' "$val" | sed 's/[[\.*^$()+?{|]/\\&/g; s/]/\\]/g')
    sed -i "s|^${key}=.*|${key}=${escaped_val}|" "$env_file"
  }

  sed_inplace "INSTALL_DIR" "$INSTALL_DIR"
  sed_inplace "APP_TAG" "$APP_TAG"

  case "$app" in
    zoraxy)
      sed_inplace "MANAGEMENT_PORT" "$MANAGEMENT_PORT"
      ;;
    nginx-proxy-manager)
      sed_inplace "ADMIN_EMAIL" "$ADMIN_EMAIL"
      sed_inplace "ADMIN_PASSWORD" "$ADMIN_PASSWORD"
      sed_inplace "MANAGEMENT_PORT" "$MANAGEMENT_PORT"
      ;;
    outline)
      sed_inplace "SECRET_KEY" "$SECRET_KEY"
      sed_inplace "UTILS_SECRET" "$UTILS_SECRET"
      sed_inplace "URL" "$OUTLINE_URL"
      case "$OAUTH_PROVIDER" in
        slack)
          sed_inplace "SLACK_CLIENT_ID" "${SLACK_CLIENT_ID:-}"
          sed_inplace "SLACK_CLIENT_SECRET" "${SLACK_CLIENT_SECRET:-}"
          ;;
        google)
          sed_inplace "GOOGLE_CLIENT_ID" "${GOOGLE_CLIENT_ID:-}"
          sed_inplace "GOOGLE_CLIENT_SECRET" "${GOOGLE_CLIENT_SECRET:-}"
          ;;
        *)
          sed_inplace "OAUTH_CLIENT_ID" "${OAUTH_CLIENT_ID:-}"
          sed_inplace "OAUTH_CLIENT_SECRET" "${OAUTH_CLIENT_SECRET:-}"
          ;;
      esac
      ;;
    checkmk)
      sed_inplace "ADMIN_PASSWORD" "$ADMIN_PASSWORD"
      ;;
    netbird)
      sed_inplace "NETBIRD_DOMAIN" "$NETBIRD_DOMAIN"
      sed_inplace "TURN_PASSWORD" "$TURN_PASSWORD"
      sed_inplace "COTURN_PASSWORD" "$COTURN_PASSWORD"
      if [[ "${USE_AUTHENTIK:-n}" == "s" ]]; then
        sed_inplace "AUTHENTIK_URL" "${AUTHENTIK_URL:-}"
        sed_inplace "OIDC_CLIENT_ID" "${OIDC_CLIENT_ID:-}"
        sed_inplace "OIDC_CLIENT_SECRET" "${OIDC_CLIENT_SECRET:-}"
      fi
      ;;
    authentik)
      sed_inplace "PG_PASSWORD" "$PG_PASSWORD"
      sed_inplace "AUTHENTIK_SECRET_KEY" "$AUTHENTIK_SECRET_KEY"
      sed_inplace "ADMIN_EMAIL" "$ADMIN_EMAIL"
      sed_inplace "DOMAIN" "$DOMAIN"
      ;;
  esac

  # Variabili esposizione (non applicabile per app con porte fisse)
  if [[ "$EXPOSE_MODE" == "porta" ]]; then
    sed_inplace "EXPOSE_PORT" "$EXPOSE_PORT"
  elif [[ "$EXPOSE_MODE" == "proxy" ]]; then
    sed_inplace "HOSTNAME" "$EXPOSE_HOSTNAME"
  fi
}

riepilogo_finale() {
  local app="$1"
  local dest="$2"

  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║                  INSTALLAZIONE COMPLETATA                ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  App             : $app"
  echo "  Versione        : $APP_TAG"
  echo "  Directory       : $dest"
  echo ""

  if [[ "$app" == "omada-controller" ]]; then
    echo "  URL di accesso  : http://$(hostname -I | awk '{print $1}'):8088"
    echo "  URL HTTPS       : https://$(hostname -I | awk '{print $1}'):8043"
  elif [[ "$app" == "nginx-proxy-manager" ]]; then
    echo "  UI management   : http://$(hostname -I | awk '{print $1}'):${MANAGEMENT_PORT}"
    echo "  Proxy HTTP/S    : porte 80 e 443 (configurabili dall'UI)"
  elif [[ "$app" == "zoraxy" ]]; then
    echo "  UI management   : http://$(hostname -I | awk '{print $1}'):${MANAGEMENT_PORT}"
    echo "  Proxy HTTP/S    : porte 80 e 443 (configurabili dall'UI)"
  elif [[ "$EXPOSE_MODE" == "porta" ]]; then
    echo "  URL di accesso  : http://$(hostname -I | awk '{print $1}'):${EXPOSE_PORT}"
  else
    echo "  URL di accesso  : https://${EXPOSE_HOSTNAME}"
  fi

  echo ""
  echo "  Credenziali e segreti generati:"

  case "$app" in
    zoraxy)
      echo "    MANAGEMENT_PORT  : $MANAGEMENT_PORT"
      ;;
    nginx-proxy-manager)
      echo "    ADMIN_EMAIL      : $ADMIN_EMAIL"
      echo "    ADMIN_PASSWORD   : $ADMIN_PASSWORD"
      echo "    MANAGEMENT_PORT  : $MANAGEMENT_PORT"
      ;;
    outline)
      echo "    SECRET_KEY      : $SECRET_KEY"
      echo "    UTILS_SECRET    : $UTILS_SECRET"
      echo "    URL             : $OUTLINE_URL"
      ;;
    checkmk)
      echo "    ADMIN_PASSWORD  : $ADMIN_PASSWORD"
      ;;
    netbird)
      echo "    NETBIRD_DOMAIN  : $NETBIRD_DOMAIN"
      echo "    TURN_PASSWORD   : $TURN_PASSWORD"
      echo "    COTURN_PASSWORD : $COTURN_PASSWORD"
      if [[ "${USE_AUTHENTIK:-n}" == "s" ]]; then
        echo "    AUTHENTIK_URL   : $AUTHENTIK_URL"
        echo "    OIDC_CLIENT_ID  : $OIDC_CLIENT_ID"
      fi
      ;;
    authentik)
      echo "    PG_PASSWORD          : $PG_PASSWORD"
      echo "    AUTHENTIK_SECRET_KEY : $AUTHENTIK_SECRET_KEY"
      echo "    ADMIN_EMAIL          : $ADMIN_EMAIL"
      echo "    DOMAIN               : $DOMAIN"
      ;;
  esac

  echo ""
  echo "  File .env       : $dest/.env"
  echo ""
  echo "  Per gestire i container:"
  echo "    cd $dest"
  echo "    docker compose ps"
  echo "    docker compose logs -f"
  echo ""
}

# ─── Main ──────────────────────────────────────────────────────────────────────
main() {
  mostra_banner
  verifica_prerequisiti

  # Scelta app da argomento o menu
  if [[ $# -ge 1 ]]; then
    local arg="$1"
    local trovato=false
    for a in "${APPS[@]}"; do
      if [[ "$a" == "$arg" ]]; then
        APP_NAME="$arg"
        trovato=true
        break
      fi
    done
    if [[ "$trovato" == false ]]; then
      echo "Errore: app '$arg' non trovata. App disponibili: ${APPS[*]}" >&2
      exit 1
    fi
  else
    scegli_app
  fi

  echo ""
  echo "==> Installazione: $APP_NAME"

  # Carica configurazione app
  carica_app_conf "$APP_NAME"

  # Directory calcolata automaticamente
  INSTALL_DIR="$HOME/workspace/$APP_NAME"
  mkdir -p "$INSTALL_DIR"
  echo "  Directory: $INSTALL_DIR"

  # Scelta versione Docker
  chiedi_versione "$APP_VERSION" APP_TAG

  # Modalità esposizione (omada e npm usano porte fisse, non viene chiesta)
  if [[ "$APP_NAME" == "omada-controller" || "$APP_NAME" == "nginx-proxy-manager" || "$APP_NAME" == "zoraxy" ]]; then
    EXPOSE_MODE="fixed"
    EXPOSE_PORT=""
    EXPOSE_HOSTNAME=""
  else
    chiedi_esposizione EXPOSE_MODE EXPOSE_PORT EXPOSE_HOSTNAME
  fi

  # Variabili specifiche app
  echo ""
  echo "==> Configurazione $APP_NAME"
  chiedi_variabili_app "$APP_NAME"

  # Download file
  echo ""
  echo "==> Download file dal repository..."
  scarica_file_app "$APP_NAME" "$INSTALL_DIR"

  # Genera .env
  echo ""
  echo "==> Generazione file .env..."
  genera_env "$APP_NAME" "$INSTALL_DIR"

  # Deploy
  echo ""
  echo "==> Avvio container..."
  deploy_app "$INSTALL_DIR"

  # Health check
  echo ""
  echo "==> Verifica stato container..."
  verifica_container "$INSTALL_DIR"

  # Riepilogo
  riepilogo_finale "$APP_NAME" "$INSTALL_DIR"
}

main "$@"
