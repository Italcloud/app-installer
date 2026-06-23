# App Installer

Installazione automatica di container Docker tramite menu interattivo.

## Utilizzo rapido

```bash
wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh | bash
```

Oppure, per installare un'app specifica senza menu:

```bash
wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh | bash -s -- checkmk
```

## Prerequisiti

- Docker Engine (con plugin Compose v2)
- `curl`, `wget`, `openssl`
- Debian 13 / Ubuntu 22.04+ (o distribuzione compatibile)

Verifica rapida:

```bash
docker compose version
```

## App disponibili

| App | Descrizione | Dipendenze |
|-----|-------------|------------|
| `zoraxy` | Reverse proxy con UI web | — |
| `nginx-proxy-manager` | Gestione reverse proxy Nginx con UI | — |
| `outline` | Wiki e knowledge base collaborativa | — |
| `checkmk` | Piattaforma di monitoraggio IT | — |
| `omada-controller` | Controller per access point TP-Link Omada | — |
| `netbird` | VPN mesh peer-to-peer | Authentik (opzionale, per OIDC) |
| `authentik` | Piattaforma di identity e SSO self-hosted | — |

## Struttura repository

```
app-installer/
├── install.sh              # Script principale
├── lib/
│   ├── checks.sh           # Verifica prerequisiti
│   ├── prompts.sh          # Input utente interattivo
│   └── deploy.sh           # Docker Compose deploy + health check
└── apps/
    └── <nome-app>/
        ├── app.conf        # Metadati app (nome, versione, dipendenze)
        ├── docker-compose.yml
        └── .env.example    # Variabili d'ambiente con valori di esempio
```

## Come aggiungere una nuova app

1. Crea la directory `apps/<nome-app>/`
2. Aggiungi `app.conf`, `docker-compose.yml`, `.env.example`
3. Aggiungi il nome app all'array `APPS` in `install.sh`
4. Aggiungi la sezione `chiedi_variabili_app` e `genera_env` in `install.sh`

## Sicurezza

- I file `.env` non vengono mai committati (`.gitignore`)
- Le password generate automaticamente usano `openssl rand -hex 32`
- Gli script usano `set -euo pipefail` per fail-fast sicuro
