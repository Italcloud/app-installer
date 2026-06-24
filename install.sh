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
  checkmk
  mailrise
  nginx-proxy-manager
  omada-controller
  outline
  snipe-it
  unimus
  zoraxy
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
      echo "   SECRET_KEY   : $SECRET_KEY"
      echo "   UTILS_SECRET : $UTILS_SECRET"
      echo ""
      leggi_input "URL pubblico di Outline (es. https://docs.example.com)" "" OUTLINE_URL
      leggi_input "Porta locale esposta sul proxy (es. 3000, 3001, 3002...)" "3000" EXPOSE_PORT
      echo ""
      echo "Provider di autenticazione:"
      echo "  0) Nessuno (configura manualmente in seguito)"
      echo "  1) OIDC generico (es. Authentik)"
      echo "  2) Slack"
      echo "  3) Google"
      echo "  4) Microsoft Azure AD"
      echo "  5) Discord"
      echo ""
      local _auth_choice
      OAUTH_PROVIDER=""
      while true; do
        leggi_input "Scegli provider (0-5)" "1" _auth_choice
        case "$_auth_choice" in
          0)
            OAUTH_PROVIDER=""
            break ;;
          1)
            OAUTH_PROVIDER="oidc"
            leggi_input "OIDC Client ID" "" OIDC_CLIENT_ID
            chiedi_password "OIDC Client Secret" OIDC_CLIENT_SECRET
            leggi_input "OIDC Auth URI (es. https://auth.example.com/application/o/authorize/)" "" OIDC_AUTH_URI
            leggi_input "OIDC Token URI (es. https://auth.example.com/application/o/token/)" "" OIDC_TOKEN_URI
            leggi_input "OIDC Userinfo URI (es. https://auth.example.com/application/o/userinfo/)" "" OIDC_USERINFO_URI
            leggi_input "OIDC Logout URI (lascia vuoto se non necessario)" "" OIDC_LOGOUT_URI
            leggi_input "Nome visualizzato provider (es. Authentik)" "Authentik" OIDC_DISPLAY_NAME
            break ;;
          2)
            OAUTH_PROVIDER="slack"
            leggi_input "Slack Client ID" "" SLACK_CLIENT_ID
            chiedi_password "Slack Client Secret" SLACK_CLIENT_SECRET
            break ;;
          3)
            OAUTH_PROVIDER="google"
            leggi_input "Google Client ID" "" GOOGLE_CLIENT_ID
            chiedi_password "Google Client Secret" GOOGLE_CLIENT_SECRET
            break ;;
          4)
            OAUTH_PROVIDER="azure"
            leggi_input "Azure Client ID" "" AZURE_CLIENT_ID
            chiedi_password "Azure Client Secret" AZURE_CLIENT_SECRET
            leggi_input "Azure Resource App ID" "" AZURE_RESOURCE_APP_ID
            break ;;
          5)
            OAUTH_PROVIDER="discord"
            leggi_input "Discord Client ID" "" DISCORD_CLIENT_ID
            chiedi_password "Discord Client Secret" DISCORD_CLIENT_SECRET
            leggi_input "Discord Server ID" "" DISCORD_SERVER_ID
            break ;;
          *) echo "Scelta non valida. Inserisci un numero tra 0 e 5." ;;
        esac
      done
      echo ""
      echo "Configurazione SMTP:"
      leggi_input "SMTP Host" "smtp.maileroo.com" SMTP_HOST
      leggi_input "SMTP Port" "465" SMTP_PORT
      leggi_input "SMTP Username (indirizzo mittente)" "" SMTP_USERNAME
      chiedi_password "SMTP Password" SMTP_PASSWORD
      local _smtp_from_default="${OUTLINE_FOLDER_NAME^} <${SMTP_USERNAME}>"
      leggi_input "SMTP From Email" "$_smtp_from_default" SMTP_FROM_EMAIL
      local _smtp_secure_yn
      leggi_si_no "SMTP usa SSL/TLS?" "s" _smtp_secure_yn
      SMTP_SECURE="$([[ "$_smtp_secure_yn" == "s" ]] && echo true || echo false)"
      leggi_input "SMTP Name (nome servizio)" "Maileroo" SMTP_NAME
      echo ""
      local _proxy_ip
      leggi_input "IP del reverse proxy" "" _proxy_ip
      PROXY_IP_HEADER="$_proxy_ip"
      ALLOWED_PRIVATE_IP_ADDRESSES="$_proxy_ip"
      echo ""
      leggi_si_no "Vuoi aggiungere il webhook Telegram?" "n" USE_TELEGRAM
      if [[ "$USE_TELEGRAM" == "s" ]]; then
        leggi_input "Telegram Bot Token" "" TELEGRAM_BOT_TOKEN
        leggi_input "Telegram Chat ID" "" TELEGRAM_CHAT_ID
        leggi_input "Porta locale webhook (default 5000, cambia per evitare conflitti)" "5000" TELEGRAM_WEBHOOK_PORT
        echo "  → OUTLINE_SIGNING_SECRET e OUTLINE_API_TOKEN vanno compilati dopo il primo avvio."
      fi
      ;;
    checkmk)
      chiedi_password "Password amministratore (utente: cmkadmin)" ADMIN_PASSWORD
      ;;
    omada-controller)
      echo "→ Nessuna variabile critica richiesta per Omada Controller."
      ;;
    mailrise)
      leggi_input "Telegram Bot Token" "" TELEGRAM_BOT_TOKEN
      leggi_input "Telegram Chat ID" "" TELEGRAM_CHAT_ID
      leggi_input "Porta SMTP locale" "8025" LISTEN_PORT
      ;;
    unimus)
      leggi_input "Porta web UI" "8085" UNIMUS_PORT
      ;;
    snipe-it)
      echo "→ Generazione APP_KEY automatica..."
      SNIPEIT_APP_KEY="base64:$(openssl rand -base64 32)"

      echo "→ Generazione password DB automatica..."
      SNIPEIT_DB_PASSWORD=$(openssl rand -hex 16)
      SNIPEIT_DB_ROOT_PASSWORD=$(openssl rand -hex 16)

      if [[ "$EXPOSE_MODE" == "proxy" ]]; then
        SNIPEIT_APP_URL="https://$EXPOSE_HOSTNAME"
        leggi_input "IP del reverse proxy (per APP_TRUSTED_PROXIES)" "" SNIPEIT_TRUSTED_PROXIES
      else
        local _snipeit_ip
        _snipeit_ip=$(hostname -I | awk '{print $1}')
        SNIPEIT_APP_URL="http://${_snipeit_ip}:${EXPOSE_PORT}"
        SNIPEIT_TRUSTED_PROXIES=""
      fi
      echo "  APP_URL: $SNIPEIT_APP_URL"

      echo ""
      local _configure_mail
      leggi_si_no "Vuoi configurare l'SMTP?" "n" _configure_mail
      SNIPEIT_CONFIGURE_MAIL="$_configure_mail"
      if [[ "$SNIPEIT_CONFIGURE_MAIL" == "s" ]]; then
        leggi_input "SMTP Host" "" SNIPEIT_MAIL_HOST
        leggi_input "SMTP Port" "587" SNIPEIT_MAIL_PORT
        leggi_input "SMTP Username" "" SNIPEIT_MAIL_USERNAME
        chiedi_password "SMTP Password" SNIPEIT_MAIL_PASSWORD
        leggi_input "SMTP From Address" "$SNIPEIT_MAIL_USERNAME" SNIPEIT_MAIL_FROM_ADDR
        leggi_input "SMTP From Name" "Snipe-IT" SNIPEIT_MAIL_FROM_NAME
        leggi_input "SMTP Reply-To Address" "$SNIPEIT_MAIL_FROM_ADDR" SNIPEIT_MAIL_REPLYTO_ADDR
        leggi_input "SMTP Reply-To Name" "Snipe-IT" SNIPEIT_MAIL_REPLYTO_NAME
        local _tls_yn
        leggi_si_no "Verifica certificato TLS?" "s" _tls_yn
        SNIPEIT_MAIL_TLS_VERIFY_PEER="$([[ "$_tls_yn" == "s" ]] && echo true || echo false)"
      fi
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
      sed_inplace "URL" "$OUTLINE_URL"
      sed_inplace "EXPOSE_PORT" "$EXPOSE_PORT"
      sed_inplace "SECRET_KEY" "$SECRET_KEY"
      sed_inplace "UTILS_SECRET" "$UTILS_SECRET"
      sed_inplace "SMTP_HOST" "$SMTP_HOST"
      sed_inplace "SMTP_PORT" "$SMTP_PORT"
      sed_inplace "SMTP_USERNAME" "$SMTP_USERNAME"
      sed_inplace "SMTP_PASSWORD" "$SMTP_PASSWORD"
      sed_inplace "SMTP_FROM_EMAIL" "$SMTP_FROM_EMAIL"
      sed_inplace "SMTP_SECURE" "$SMTP_SECURE"
      sed_inplace "SMTP_NAME" "$SMTP_NAME"
      sed_inplace "PROXY_IP_HEADER" "${PROXY_IP_HEADER:-}"
      sed_inplace "ALLOWED_PRIVATE_IP_ADDRESSES" "${ALLOWED_PRIVATE_IP_ADDRESSES:-}"
      if [[ "${USE_TELEGRAM:-n}" == "s" ]]; then
        sed_inplace "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN"
        sed_inplace "TELEGRAM_CHAT_ID" "$TELEGRAM_CHAT_ID"
        sed_inplace "TELEGRAM_WEBHOOK_PORT" "$TELEGRAM_WEBHOOK_PORT"
      fi
      case "${OAUTH_PROVIDER:-}" in
        oidc)
          sed_inplace "OIDC_CLIENT_ID" "$OIDC_CLIENT_ID"
          sed_inplace "OIDC_CLIENT_SECRET" "$OIDC_CLIENT_SECRET"
          sed_inplace "OIDC_AUTH_URI" "$OIDC_AUTH_URI"
          sed_inplace "OIDC_TOKEN_URI" "$OIDC_TOKEN_URI"
          sed_inplace "OIDC_USERINFO_URI" "$OIDC_USERINFO_URI"
          sed_inplace "OIDC_LOGOUT_URI" "${OIDC_LOGOUT_URI:-}"
          sed_inplace "OIDC_DISPLAY_NAME" "$OIDC_DISPLAY_NAME"
          ;;
        slack)
          sed_inplace "SLACK_CLIENT_ID" "$SLACK_CLIENT_ID"
          sed_inplace "SLACK_CLIENT_SECRET" "$SLACK_CLIENT_SECRET"
          ;;
        google)
          sed_inplace "GOOGLE_CLIENT_ID" "$GOOGLE_CLIENT_ID"
          sed_inplace "GOOGLE_CLIENT_SECRET" "$GOOGLE_CLIENT_SECRET"
          ;;
        azure)
          sed_inplace "AZURE_CLIENT_ID" "$AZURE_CLIENT_ID"
          sed_inplace "AZURE_CLIENT_SECRET" "$AZURE_CLIENT_SECRET"
          sed_inplace "AZURE_RESOURCE_APP_ID" "$AZURE_RESOURCE_APP_ID"
          ;;
        discord)
          sed_inplace "DISCORD_CLIENT_ID" "$DISCORD_CLIENT_ID"
          sed_inplace "DISCORD_CLIENT_SECRET" "$DISCORD_CLIENT_SECRET"
          sed_inplace "DISCORD_SERVER_ID" "$DISCORD_SERVER_ID"
          ;;
      esac
      ;;
    checkmk)
      sed_inplace "ADMIN_PASSWORD" "$ADMIN_PASSWORD"
      ;;
    unimus)
      sed_inplace "APP_PORT" "$UNIMUS_PORT"
      ;;
    snipe-it)
      if [[ "$EXPOSE_MODE" == "porta" ]]; then
        sed_inplace "APP_PORT" "$EXPOSE_PORT"
      fi
      sed_inplace "APP_KEY" "$SNIPEIT_APP_KEY"
      sed_inplace "APP_URL" "$SNIPEIT_APP_URL"
      sed_inplace "DB_PASSWORD" "$SNIPEIT_DB_PASSWORD"
      sed_inplace "MYSQL_ROOT_PASSWORD" "$SNIPEIT_DB_ROOT_PASSWORD"
      sed_inplace "APP_TRUSTED_PROXIES" "$SNIPEIT_TRUSTED_PROXIES"
      if [[ "${SNIPEIT_CONFIGURE_MAIL:-n}" == "s" ]]; then
        sed_inplace "MAIL_HOST" "$SNIPEIT_MAIL_HOST"
        sed_inplace "MAIL_PORT" "$SNIPEIT_MAIL_PORT"
        sed_inplace "MAIL_USERNAME" "$SNIPEIT_MAIL_USERNAME"
        sed_inplace "MAIL_PASSWORD" "$SNIPEIT_MAIL_PASSWORD"
        sed_inplace "MAIL_FROM_ADDR" "$SNIPEIT_MAIL_FROM_ADDR"
        sed_inplace "MAIL_FROM_NAME" "$SNIPEIT_MAIL_FROM_NAME"
        sed_inplace "MAIL_REPLYTO_ADDR" "$SNIPEIT_MAIL_REPLYTO_ADDR"
        sed_inplace "MAIL_REPLYTO_NAME" "$SNIPEIT_MAIL_REPLYTO_NAME"
        sed_inplace "MAIL_TLS_VERIFY_PEER" "$SNIPEIT_MAIL_TLS_VERIFY_PEER"
      fi
      ;;
    mailrise)
      sed_inplace "LISTEN_PORT" "$LISTEN_PORT"
      sed_inplace "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN"
      sed_inplace "TELEGRAM_CHAT_ID" "$TELEGRAM_CHAT_ID"
      # Genera mailrise.conf dai placeholder
      local _mrc_src
      if [[ -f "$SCRIPT_DIR/apps/mailrise/mailrise.conf.example" ]]; then
        _mrc_src="$SCRIPT_DIR/apps/mailrise/mailrise.conf.example"
      else
        _mrc_src="$(mktemp)"
        curl -fsSL "$REPO_URL/apps/mailrise/mailrise.conf.example" -o "$_mrc_src"
      fi
      cp "$_mrc_src" "$dest/mailrise.conf"
      local _escaped_bot _escaped_chat
      _escaped_bot=$(printf '%s\n' "$TELEGRAM_BOT_TOKEN" | sed 's/[&/\\]/\\&/g')
      _escaped_chat=$(printf '%s\n' "$TELEGRAM_CHAT_ID" | sed 's/[&/\\]/\\&/g')
      sed -i "s|PLACEHOLDER_BOT|${_escaped_bot}|g" "$dest/mailrise.conf"
      sed -i "s|PLACEHOLDER_CHATID|${_escaped_chat}|g" "$dest/mailrise.conf"
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
  elif [[ "$app" == "outline" ]]; then
    echo "  URL di accesso  : ${OUTLINE_URL}"
  elif [[ "$app" == "mailrise" ]]; then
    echo "  SMTP endpoint   : $(hostname -I | awk '{print $1}'):${LISTEN_PORT}"
  elif [[ "$app" == "unimus" ]]; then
    echo "  URL di accesso  : http://$(hostname -I | awk '{print $1}'):${UNIMUS_PORT}"
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
      echo "    URL              : $OUTLINE_URL"
      echo "    SECRET_KEY       : $SECRET_KEY"
      echo "    UTILS_SECRET     : $UTILS_SECRET"
      echo "    Auth provider    : ${OAUTH_PROVIDER:-nessuno}"
      echo "    SMTP             : $SMTP_HOST:$SMTP_PORT (${SMTP_USERNAME})"
      if [[ "${USE_TELEGRAM:-n}" == "s" ]]; then
        echo ""
        echo "    Webhook Telegram (porta ${TELEGRAM_WEBHOOK_PORT}):"
        echo "    TELEGRAM_BOT_TOKEN  : $TELEGRAM_BOT_TOKEN"
        echo "    TELEGRAM_CHAT_ID    : $TELEGRAM_CHAT_ID"
        echo ""
        echo "    Passi da completare dopo il primo avvio di Outline:"
        echo "    1) Settings → Workspace → Webhooks → New webhook"
        echo "       URL: https://<dominio-webhook>/webhook"
        echo "       Copia 'Signing secret' → OUTLINE_SIGNING_SECRET nel .env"
        echo "    2) (opzionale) Settings → Account → API → New token"
        echo "       Copia il token → OUTLINE_API_TOKEN nel .env"
        echo "    3) Riavvia: cd $dest && docker compose up -d"
      fi
      ;;
    checkmk)
      echo "    ADMIN_PASSWORD  : $ADMIN_PASSWORD"
      ;;
    unimus)
      echo "    Porta web UI    : $UNIMUS_PORT"
      echo "    (credenziali configurate via web UI al primo accesso)"
      ;;
    snipe-it)
      echo "    APP_KEY         : $SNIPEIT_APP_KEY"
      echo "    APP_URL         : $SNIPEIT_APP_URL"
      echo "    DB_PASSWORD     : $SNIPEIT_DB_PASSWORD"
      echo "    DB_ROOT_PW      : $SNIPEIT_DB_ROOT_PASSWORD"
      if [[ "${SNIPEIT_CONFIGURE_MAIL:-n}" == "s" ]]; then
        echo "    SMTP            : $SNIPEIT_MAIL_HOST:$SNIPEIT_MAIL_PORT ($SNIPEIT_MAIL_FROM_ADDR)"
      fi
      ;;
    mailrise)
      echo "    TELEGRAM_BOT_TOKEN : $TELEGRAM_BOT_TOKEN"
      echo "    TELEGRAM_CHAT_ID   : $TELEGRAM_CHAT_ID"
      echo "    Porta SMTP         : $LISTEN_PORT"
      echo ""
      echo "    Configura le app per inviare notifiche via SMTP:"
      echo "    Server : $(hostname -I | awk '{print $1}')"
      echo "    Porta  : $LISTEN_PORT"
      echo "    Email  : <alias>@mailrise.xyz  (es. omada@mailrise.xyz)"
      echo ""
      echo "    NOTA: il file $dest/mailrise.conf contiene alias di esempio."
      echo "    Modificalo per adattarlo alle tue esigenze: puoi aggiungere,"
      echo "    rimuovere o rinominare gli alias. Ogni alias può avere un"
      echo "    TELEGRAM_CHAT_ID diverso se vuoi notifiche separate per gruppo."
      echo "    Dopo ogni modifica: docker compose restart mailrise"
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

  # Directory di installazione
  if [[ "$APP_NAME" == "outline" ]]; then
    echo ""
    leggi_input "Nome cartella installazione in ~/workspace (es. docs, wiki)" "outline" OUTLINE_FOLDER_NAME
    INSTALL_DIR="$HOME/workspace/$OUTLINE_FOLDER_NAME"
  else
    INSTALL_DIR="$HOME/workspace/$APP_NAME"
  fi
  mkdir -p "$INSTALL_DIR"
  echo "  Directory: $INSTALL_DIR"
  if [[ "$APP_NAME" == "outline" ]]; then
    mkdir -p "$INSTALL_DIR/data/storage"
    chmod 777 "$INSTALL_DIR/data/storage"
  fi

  # Scelta versione Docker
  chiedi_versione "$APP_VERSION" APP_TAG

  # Modalità esposizione (omada e npm usano porte fisse, non viene chiesta)
  if [[ "$APP_NAME" == "omada-controller" || "$APP_NAME" == "nginx-proxy-manager" || "$APP_NAME" == "zoraxy" || "$APP_NAME" == "mailrise" || "$APP_NAME" == "unimus" ]]; then
    EXPOSE_MODE="fixed"
    EXPOSE_PORT=""
    EXPOSE_HOSTNAME=""
  elif [[ "$APP_NAME" == "outline" ]]; then
    EXPOSE_MODE="proxy"
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

  # Per outline: aggiungi servizio telegram webhook se richiesto
  if [[ "$APP_NAME" == "outline" && "${USE_TELEGRAM:-n}" == "s" ]]; then
    cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOFYAML'

  outline-telegram-webhook:
    image: wtrucci/outline-telegram:latest
    container_name: outline-telegram-webhook
    restart: unless-stopped
    ports:
      - "${TELEGRAM_WEBHOOK_PORT:-5000}:3000"
    env_file:
      - .env
    environment:
      OUTLINE_SIGNING_SECRET: ${OUTLINE_SIGNING_SECRET}
      OUTLINE_API_TOKEN: ${OUTLINE_API_TOKEN}
      OUTLINE_URL: ${URL}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
      TELEGRAM_CHAT_ID: ${TELEGRAM_CHAT_ID}
EOFYAML
    echo "  → Servizio outline-telegram-webhook aggiunto al compose"
  fi

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
