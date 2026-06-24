# App Installer

Installazione automatica di container Docker tramite menu interattivo.  
Un singolo comando installa, configura e avvia qualsiasi app con `docker compose`.

---

## Installazione rapida

### Menu interattivo

Scarica ed esegui lo script: ti guida passo per passo.

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh)
```

### App specifica (no menu)

Passa il nome dell'app come argomento per saltare il menu di selezione:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh) checkmk
```

App disponibili: `authentik`, `checkmk`, `mailrise`, `netbird`, `nginx-proxy-manager`, `omada-controller`, `outline`, `zoraxy`

### Se hai già clonato il repo

```bash
git clone https://github.com/Italcloud/app-installer.git
cd app-installer
bash install.sh
```

---

## Cosa succede durante l'installazione

Lo script esegue in sequenza:

1. **Verifica prerequisiti** — controlla che `docker`, `docker compose` (plugin v2), `curl`, `wget` e `openssl` siano presenti
2. **Scelta app** — menu numerato oppure argomento da riga di comando
3. **Directory di installazione** — calcolata automaticamente come `~/workspace/<nomeapp>/`; per Outline il nome cartella è scelto dall'utente (es. `docs`, `wiki`)
4. **Scelta versione Docker** — propone il tag stabile consigliato, con opzione `latest` o tag manuale
5. **Modalità di esposizione** — porta diretta (`IP:porta`) o reverse proxy (hostname/dominio); le app con porte fisse saltano questo passaggio
6. **Variabili specifiche** — chiede le credenziali necessarie; le password e i segreti vengono generati automaticamente con `openssl rand -hex 32`
7. **Download file** — scarica `docker-compose.yml` e `.env.example` dal repository
8. **Generazione `.env`** — compila il file con tutti i valori inseriti
9. **Deploy** — esegue `docker compose pull` e `docker compose up -d`
10. **Health check** — verifica che tutti i container siano in stato `running`
11. **Riepilogo** — mostra URL di accesso, credenziali generate e percorso di installazione

I file vengono installati in:

```
~/workspace/<nomeapp>/
├── docker-compose.yml
├── .env
└── data/
    ├── config/     # configurazione persistente
    ├── db/         # dati database
    ├── redis/      # dati Redis
    ├── logs/       # log persistenti
    └── storage/    # upload e media
```

### Modalità di esposizione

| App | Comportamento |
|-----|--------------|
| `omada-controller` | Porte fisse — `network_mode: host` |
| `nginx-proxy-manager` | Porte 80/443 fisse + management port configurabile |
| `zoraxy` | Porte 80/443 fisse + management port configurabile |
| `mailrise` | Porta SMTP fissa (default 8025, configurabile) |
| `outline` | Sempre reverse proxy — chiede solo la porta locale (per multi-istanza) |
| Altre app | Chiede: porta diretta o reverse proxy |

---

## Prerequisiti

| Strumento | Versione minima | Installazione |
|-----------|----------------|---------------|
| Docker Engine | 24.x | [docs.docker.com](https://docs.docker.com/engine/install/) |
| Docker Compose plugin v2 | 2.20 | incluso con Docker Engine |
| curl | qualsiasi | `apt-get install -y curl` |
| wget | qualsiasi | `apt-get install -y wget` |
| openssl | qualsiasi | `apt-get install -y openssl` |

Verifica rapida:

```bash
docker compose version
```

Sistema operativo supportato: Debian 12/13, Ubuntu 22.04+

---

## App disponibili

| App | Descrizione | Versione stabile | Note |
|-----|-------------|-----------------|------|
| `authentik` | Piattaforma di identity e SSO self-hosted | 2026.5.3 | Include PostgreSQL e Redis |
| `checkmk` | Piattaforma di monitoraggio IT | 2.4.0p32 | — |
| `mailrise` | Gateway SMTP → notifiche Telegram/Apprise | latest | Rete Docker `monitoring` |
| `netbird` | VPN mesh peer-to-peer con gestione centralizzata | 0.73.2 | Authentik opzionale (OIDC) |
| `nginx-proxy-manager` | Gestione reverse proxy Nginx con UI web | 2.15.1 | Porte 80/443 fisse |
| `omada-controller` | Controller per access point TP-Link Omada | 6.2 | `network_mode: host` |
| `outline` | Wiki e knowledge base collaborativa | 1.8.1 | Include PostgreSQL e Redis; webhook Telegram opzionale |
| `zoraxy` | Reverse proxy con UI web semplificata | 3.2.5r2 | Porte 80/443 fisse |

---

## Struttura repository

```
app-installer/
├── install.sh              # Orchestratore principale
├── lib/
│   ├── checks.sh           # Verifica prerequisiti
│   ├── prompts.sh          # Input utente interattivo
│   └── deploy.sh           # Docker Compose deploy + health check
└── apps/
    ├── authentik/
    ├── checkmk/
    ├── mailrise/
    │   ├── app.conf
    │   ├── docker-compose.yml
    │   ├── .env.example
    │   └── mailrise.conf.example   # Template alias notifiche (modificabile post-installazione)
    ├── netbird/
    ├── nginx-proxy-manager/
    ├── omada-controller/
    ├── outline/
    └── zoraxy/
        (ogni app contiene: app.conf, docker-compose.yml, .env.example)
```

---

## Come aggiungere una nuova app

1. Crea la directory `apps/<nome-app>/`
2. Aggiungi `app.conf`, `docker-compose.yml`, `.env.example`
3. Aggiungi il nome nell'array `APPS` in `install.sh`
4. Aggiungi il case in `chiedi_variabili_app` e `genera_env` in `install.sh`

---

## Sicurezza

- I file `.env` non vengono mai committati (esclusi da `.gitignore`)
- Le password e i segreti generati automaticamente usano `openssl rand -hex 32`
- Tutti gli script usano `set -euo pipefail` per uscire immediatamente in caso di errore
