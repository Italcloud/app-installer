# App Installer

Installazione automatica di container Docker tramite menu interattivo.  
Un singolo comando installa, configura e avvia qualsiasi app con `docker compose`.

---

## Installazione rapida

### Menu interattivo

Scarica ed esegui lo script: ti guida passo per passo.

```bash
wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh | bash
```

### App specifica (no menu)

Passa il nome dell'app come argomento per saltare il menu di selezione:

```bash
wget -qO- https://raw.githubusercontent.com/Italcloud/app-installer/master/install.sh | bash -s -- checkmk
```

App disponibili: `zoraxy`, `nginx-proxy-manager`, `outline`, `checkmk`, `omada-controller`, `netbird`, `authentik`

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
3. **Scelta versione Docker** — propone il tag stabile consigliato, con opzione `latest` o tag manuale
4. **Modalità di esposizione** — porta diretta (`IP:porta`) o reverse proxy (hostname/dominio)
5. **Variabili specifiche** — chiede le credenziali necessarie; le password e i segreti vengono generati automaticamente con `openssl rand -hex 32`
6. **Download file** — scarica `docker-compose.yml` e `.env.example` dal repository
7. **Generazione `.env`** — compila il file con tutti i valori inseriti
8. **Deploy** — esegue `docker compose pull` e `docker compose up -d`
9. **Health check** — verifica che tutti i container siano in stato `running`
10. **Riepilogo** — mostra URL di accesso, credenziali generate e percorso di installazione

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

| App | Descrizione | Versione stabile | Dipendenze |
|-----|-------------|-----------------|------------|
| `zoraxy` | Reverse proxy con UI web | 3.2.5r2 | — |
| `nginx-proxy-manager` | Gestione reverse proxy Nginx con UI | 2.15.1 | — |
| `outline` | Wiki e knowledge base collaborativa | 1.8.1 | — |
| `checkmk` | Piattaforma di monitoraggio IT | 2.4.0p32 | — |
| `omada-controller` | Controller per access point TP-Link Omada | 6.2.10.17 | — |
| `netbird` | VPN mesh peer-to-peer | 0.73.2 | Authentik (opzionale, OIDC) |
| `authentik` | Piattaforma di identity e SSO self-hosted | 2026.5.3 | — |

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
    └── <nome-app>/
        ├── app.conf        # Metadati app (nome, versione, dipendenze)
        ├── docker-compose.yml
        └── .env.example    # Variabili d'ambiente con valori di esempio
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
