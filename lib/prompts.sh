#!/usr/bin/env bash
set -euo pipefail

# Legge un valore con default opzionale
# Uso: leggi_input "Etichetta" "default" VARIABILE
leggi_input() {
  local label="$1"
  local default="$2"
  local -n _var="$3"

  if [[ -n "$default" ]]; then
    printf "%s [%s]: " "$label" "$default"
  else
    printf "%s: " "$label"
  fi

  local input
  read -r input
  if [[ -z "$input" && -n "$default" ]]; then
    _var="$default"
  else
    _var="$input"
  fi
}

# Legge una password (input nascosto) con conferma
# Uso: chiedi_password "Etichetta" VARIABILE
chiedi_password() {
  local label="$1"
  local -n _pw="$2"

  while true; do
    printf "%s: " "$label"
    read -rs pw1
    echo ""
    if [[ -z "$pw1" ]]; then
      echo "La password non può essere vuota. Riprova."
      continue
    fi
    printf "Conferma %s: " "$label"
    read -rs pw2
    echo ""
    if [[ "$pw1" == "$pw2" ]]; then
      _pw="$pw1"
      break
    fi
    echo "Le password non coincidono. Riprova."
  done
}

# Legge una risposta sì/no
# Uso: leggi_si_no "Domanda?" "n" VARIABILE
leggi_si_no() {
  local label="$1"
  local default="${2:-n}"
  local -n _yn="$3"

  local hint
  if [[ "$default" == "s" ]]; then
    hint="[S/n]"
  else
    hint="[s/N]"
  fi

  while true; do
    printf "%s %s: " "$label" "$hint"
    read -r risposta
    risposta="${risposta,,}"  # lowercase
    if [[ -z "$risposta" ]]; then
      risposta="$default"
    fi
    case "$risposta" in
      s|si|sì|y|yes) _yn="s"; break ;;
      n|no)           _yn="n"; break ;;
      *) echo "Risposta non valida. Inserisci 's' o 'n'." ;;
    esac
  done
}

# Genera un segreto casuale con openssl
genera_secret() {
  openssl rand -hex 32
}

# Chiede la versione/tag Docker da usare
# Uso: chiedi_versione "1.2.3" APP_TAG
chiedi_versione() {
  local consigliata="$1"
  local -n _tag="$2"

  echo ""
  echo "Versione Docker da installare:"
  echo "  1) Consigliata  ($consigliata)"
  echo "  2) latest"
  echo "  3) Inserisci tag manuale"
  echo ""

  local scelta
  while true; do
    leggi_input "Scegli versione (1/2/3)" "1" scelta
    case "$scelta" in
      1) _tag="$consigliata"; break ;;
      2) _tag="latest";       break ;;
      3)
        leggi_input "Tag Docker (es. 2.0.1)" "" _tag
        if [[ -z "$_tag" ]]; then
          echo "Il tag non può essere vuoto."
          continue
        fi
        break
        ;;
      *) echo "Scelta non valida." ;;
    esac
  done

  echo "  → Versione selezionata: $_tag"
}

# Chiede la modalità di esposizione (porta diretta o reverse proxy)
# Uso: chiedi_esposizione MODE_VAR PORT_VAR HOSTNAME_VAR
chiedi_esposizione() {
  local -n _mode="$1"
  local -n _port="$2"
  local -n _hostname="$3"

  echo ""
  echo "Modalità di esposizione:"
  echo "  1) Porta diretta  (accesso tramite IP:porta)"
  echo "  2) Reverse proxy  (accesso tramite hostname/dominio)"
  echo ""

  local scelta
  while true; do
    leggi_input "Scegli modalità (1/2)" "1" scelta
    case "$scelta" in
      1)
        _mode="porta"
        leggi_input "Numero porta" "80" _port
        # Valida che sia un numero tra 1 e 65535
        if ! [[ "$_port" =~ ^[0-9]+$ ]] || (( _port < 1 || _port > 65535 )); then
          echo "Porta non valida. Inserisci un numero tra 1 e 65535."
          continue
        fi
        break
        ;;
      2)
        _mode="proxy"
        leggi_input "Hostname/dominio (es. app.example.com)" "" _hostname
        if [[ -z "$_hostname" ]]; then
          echo "Il hostname non può essere vuoto."
          continue
        fi
        break
        ;;
      *)
        echo "Scelta non valida."
        ;;
    esac
  done
}
