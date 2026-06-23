Crea la struttura completa di un repo GitHub per uno script di installazione automatica di container Docker. Il progetto si chiama app-installer.
Concetto generale:

L'utente scarica un singolo install.sh con wget e lo esegue. Lo script mostra un menu interattivo con le app disponibili, chiede le variabili necessarie, scarica i file dal repo GitHub e fa docker compose up -d.
Struttura repo da creare:
docker-installer/
├── install.sh                  # orchestratore principale
├── README.md
├── lib/
│   ├── checks.sh               # verifica prerequisiti (docker, docker compose, curl, wget)
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
│   ├── netbird/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── app.conf
│   └── authentik/
│       ├── docker-compose.yml  # include PostgreSQL e Redis
│       ├── .env.example
│       └── app.conf
└── .gitignore
Comportamento install.sh:

Verifica prerequisiti (docker, docker compose plugin, curl, wget) — esce con errore chiaro se mancano
Può ricevere il nome app come argomento (bash install.sh checkmk) oppure mostrare menu interattivo
Legge app.conf dell'app scelta per sapere quali variabili chiedere
Scarica docker-compose.yml e .env.example dal repo GitHub (raw.githubusercontent.com)
Chiede all'utente le variabili, genera il file .env compilato
Per ogni app chiede: vuoi esporre su porta diretta (chiede numero porta) o tramite reverse proxy (chiede hostname/dominio)?
Esegue docker compose up -d
Verifica che i container siano running con health check post-deploy
Stampa riepilogo finale: URL di accesso, credenziali inserite, path di installazione

Variabili comuni a tutte le app (gestite da prompts.sh):

INSTALL_DIR — directory di installazione (default: /opt/docker/<nomeapp>)
Modalità esposizione: porta diretta o hostname proxy

Variabili specifiche per app:
AppVariabili specificheZoraxyADMIN_PASSWORDNginx Proxy ManagerADMIN_EMAIL, ADMIN_PASSWORDOutlineSECRET_KEY (generata auto), UTILS_SECRET (generata auto), SLACK_KEY o altro provider OAuth, URLCheckmkSITE_NAME, ADMIN_PASSWORDOmada Controllernessuna variabile critica, solo porta/hostnameNetBirdNETBIRD_DOMAIN, TURN_PASSWORD (generata auto), COTURN_PASSWORD (generata auto) — con opzione per aggiungere Authentik come OIDCAuthentikPG_PASSWORD (generata auto), AUTHENTIK_SECRET_KEY (generata auto), ADMIN_EMAIL, DOMAIN

Struttura directory di installazione:
Ogni app viene installata sotto la home dell'utente corrente:
~/workspace/<nomeapp>/
├── docker-compose.yml
└── .env
I volumi Docker devono risiedere tutti sotto:
~/workspace/<nomeapp>/data/
├── config/        # file di configurazione persistenti
├── db/            # dati database (PostgreSQL, MySQL ecc.)
├── redis/         # dati Redis
├── logs/          # log persistenti (se necessario)
└── storage/       # file uploads, media, blob storage
Non tutte le cartelle sono necessarie per ogni app — ogni docker-compose.yml monta solo quelle che servono. La variabile INSTALL_DIR non viene più chiesta all'utente ma calcolata automaticamente come $HOME/workspace/<nomeapp>.
Selezione tag/versione Docker:
Per ogni app, lo script deve:

Mostrare il tag stabile più recente consigliato (hardcoded in app.conf come APP_VERSION)
Chiedere all'utente: vuoi usare la versione consigliata (APP_VERSION), latest, oppure inserire un tag manuale?
La scelta dell'utente viene scritta nel .env come APP_TAG e usata nel docker-compose.yml tramite la variabile ${APP_TAG}

Dettagli tecnici importanti:

Le password/secret con "(generata auto)" devono essere generate con openssl rand -hex 32 e mostrate all'utente nel riepilogo finale
Il file app.conf è in formato KEY=value bash-sourceable e contiene: APP_NAME, APP_DESCRIPTION, APP_VERSION (tag Docker da usare), REQUIRES (dipendenze opzionali, es. authentik per netbird)
Il repo GitHub è https://github.com/Italcloud/app-installer — usa un placeholder REPO_URL configurabile in testa a install.sh
Usa docker compose (plugin v2), non docker-compose (v1)
I compose devono usare immagini stabili con tag specifico, non latest
Tutto il testo interattivo in italiano
Lo script deve funzionare su Debian 13 con bash
Aggiungi set -euo pipefail in testa agli script per sicurezza
Il .gitignore deve escludere file .env ma non .env.example