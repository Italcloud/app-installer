# app-installer — Documentazione di progetto

## Concetto generale

L'utente scarica un singolo `install.sh` ed lo esegue con:
```bash
bash <(wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh)
```
Lo script mostra un menu interattivo con le app disponibili, chiede le variabili necessarie, scarica i file dal repo GitHub e fa `docker compose up -d`.

> **Importante**: usare `bash <(wget -qO- URL)` e non `wget | bash`. Il pipe crea un conflitto su stdin che impedisce l'input interattivo.

## Struttura repo

```
app-installer/
├── install.sh                  # orchestratore principale
├── README.md
├── lib/
│   ├── checks.sh               # verifica prerequisiti (docker, docker compose, curl, wget, openssl)
│   ├── prompts.sh              # funzioni input utente (read con default, password nascosta, validazione)
│   └── deploy.sh               # funzioni docker compose (pull, up, health check)
├── apps/
│   ├── zoraxy/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── app.conf
│   ├── nginx-proxy-manager/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── app.conf
│   ├── outline/
│   │   ├── docker-compose.yml  # include PostgreSQL e Redis
│   │   ├── .env.example
│   │   └── app.conf
│   ├── checkmk/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── app.conf
│   ├── omada-controller/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── app.conf
│   ├── mailrise/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   ├── app.conf
│   │   └── mailrise.conf.example  # template configurazione alias notifiche
│   ├── snipe-it/
│   │   ├── docker-compose.yml  # include MariaDB
│   │   ├── .env.example
│   │   └── app.conf
│   └── unimus/
│       ├── docker-compose.yml
│       ├── .env.example
│       └── app.conf
└── .gitignore
```

## Comportamento install.sh

1. Verifica prerequisiti (docker, docker compose plugin v2, curl, wget, openssl)
2. Può ricevere il nome app come argomento (`bash install.sh checkmk`) oppure mostrare menu interattivo
3. Carica `app.conf` dell'app scelta
4. Calcola `INSTALL_DIR` automaticamente (vedi sezione directory)
5. Chiede la versione Docker (consigliata / latest / manuale)
6. Per le app che lo prevedono, chiede la modalità di esposizione (porta diretta o reverse proxy)
7. Chiede le variabili specifiche dell'app
8. Scarica `docker-compose.yml` e `.env.example` dal repo GitHub
9. Genera il file `.env` compilato
10. Esegue `docker compose up -d`
11. Verifica che i container siano running con health check post-deploy
12. Stampa riepilogo finale: URL di accesso, credenziali inserite, path di installazione

## Directory di installazione

`INSTALL_DIR` è calcolata automaticamente — non viene chiesta all'utente:
```
~/workspace/<nomeapp>/
├── docker-compose.yml
├── .env
└── data/
    ├── config/     # file di configurazione persistenti
    ├── db/         # dati database (PostgreSQL, MySQL ecc.)
    ├── redis/      # dati Redis
    ├── logs/       # log persistenti
    └── storage/    # file uploads, media, blob storage
```
Non tutte le sottocartelle sono necessarie — ogni `docker-compose.yml` monta solo quelle che servono e usa path relativi (`./data/...`).

**Eccezione — Outline**: il nome cartella è dinamico e viene chiesto durante l'installazione (es. `docs`, `wiki`). `INSTALL_DIR` diventa `~/workspace/<nome-scelto>/`.

## Selezione tag/versione Docker

Per ogni app, lo script:
1. Mostra il tag stabile consigliato (hardcoded in `app.conf` come `APP_VERSION`)
2. Chiede: versione consigliata / `latest` / tag manuale
3. Scrive la scelta nel `.env` come `APP_TAG`, usato nel `docker-compose.yml` tramite `${APP_TAG}`

## Modalità di esposizione

Alcune app hanno **porte fisse** — skip automatico della domanda su esposizione:

| App | Comportamento |
|-----|--------------|
| `omada-controller` | porte fisse, `network_mode: host` |
| `nginx-proxy-manager` | porte 80/443 fisse + management port configurabile |
| `zoraxy` | porte 80/443 fisse + management port configurabile |
| `mailrise` | porta SMTP fissa (default 8025, configurabile) |
| `unimus` | solo porta diretta (default 8085, configurabile) |
| `outline` | sempre reverse proxy — chiede solo la porta locale (per multi-istanza) |

Tutte le altre app chiedono: porta diretta (chiede numero porta) o reverse proxy (chiede hostname).

## Variabili specifiche per app

| App | Variabili chieste | Note |
|-----|-------------------|------|
| **Zoraxy** | `MANAGEMENT_PORT` | Nessuna password — configurata via web UI al primo accesso |
| **Nginx Proxy Manager** | `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `MANAGEMENT_PORT` | |
| **Outline** | Vedi sezione dedicata | Molte variabili, flusso complesso |
| **Checkmk** | `ADMIN_PASSWORD` | Sito hardcoded come `cmk` |
| **Omada Controller** | nessuna | Solo porte standard |
| **Mailrise** | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `LISTEN_PORT` | Genera `mailrise.conf` dai placeholder |
| **Snipe-IT** | `APP_PORT` (porta), SMTP opzionale | `APP_KEY` generata automaticamente; password MariaDB generate automaticamente; `APP_URL` costruita automaticamente da IP/hostname; `APP_TRUSTED_PROXIES` chiesto solo in modalità proxy |
| **Unimus** | `APP_PORT` | Solo porta; credenziali configurate via web UI al primo accesso |

### Outline — flusso dettagliato

1. **Nome cartella** (es. `docs`, `wiki`) → `INSTALL_DIR=~/workspace/<nome>`
2. **URL pubblico** e **porta locale** (default 3000, per multi-istanza)
3. **Provider autenticazione** (0=Nessuno, 1=OIDC, 2=Slack, 3=Google, 4=Azure, 5=Discord)
4. **SMTP** completo (host, porta, username, password, from email, SSL, nome servizio)
   - `SMTP_FROM_EMAIL` ha come default `<NomeCartella> <smtp_username>`
5. **IP reverse proxy** → popola sia `PROXY_IP_HEADER` che `ALLOWED_PRIVATE_IP_ADDRESSES`
6. **Webhook Telegram** (opzionale):
   - Chiede `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, porta webhook (default 5000)
   - Appende il servizio `outline-telegram-webhook` al `docker-compose.yml` scaricato
   - `OUTLINE_SIGNING_SECRET` e `OUTLINE_API_TOKEN` restano vuoti con istruzioni post-avvio nel riepilogo

## Dettagli tecnici

- **Password**: non possono essere vuote — validazione con `IFS= read -rs`, strip `\r`, controllo `${#pw} -eq 0`
- **Segreti auto-generati**: `openssl rand -hex 32`, mostrati nel riepilogo finale
- **`app.conf`**: formato `KEY=value` bash-sourceable, contiene `APP_NAME`, `APP_DESCRIPTION`, `APP_VERSION`, `REQUIRES`
- **Repo GitHub**: `https://github.com/Italcloud/app-installer` — variabile `REPO_URL` configurabile in testa a `install.sh`
- **Docker Compose**: plugin v2 (`docker compose`), non v1 (`docker-compose`)
- **Shell**: `set -euo pipefail` in testa a tutti gli script
- **Target**: Debian 13 con bash 5
- **`.gitignore`**: esclude `.env` ma non `.env.example`
- **Testo interattivo**: italiano

## Mailrise — note specifiche

- Monta `./mailrise.conf:/etc/mailrise.conf` (file generato dall'installer)
- `mailrise.conf.example` contiene alias pre-configurati con placeholder `PLACEHOLDER_BOT` e `PLACEHOLDER_CHATID`
- L'installer scarica il template, sostituisce i placeholder e salva `mailrise.conf` nella directory di installazione
- Gli alias (`unimus@mailrise.xyz`, `omada@mailrise.xyz` ecc.) sono esempi — l'utente li modifica dopo l'installazione
- Ogni alias può avere un `TELEGRAM_CHAT_ID` diverso per notifiche separate
- Rete Docker: bridge personalizzata `monitoring`
