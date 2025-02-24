#!/bin/bash
# Erweiterte Master-Docker-Compose-Orchestrierung
# Dieses Skript steuert alle modularen docker-compose Dateien und unterstützt erweiterte Funktionen:
# - Fehlerüberprüfung von Docker und docker-compose
# - Logging (LOGFILE: /srv/master.log)
# - Farbige Ausgaben für Statusmeldungen
# - Service-spezifische Befehle (z.B. start portainer)
# - Interaktives Shell-Exec (shell)
# - Health Check (health)
#
# Usage:
#   ./master.sh {start|stop|restart|update|status|logs|shell|health|help} [service]
#
# Falls kein Service angegeben wird, werden alle Dienste bearbeitet.
#

# Farben definieren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logfile definieren
LOGFILE="/srv/master.log"

# Log-Funktion
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Prüfe, ob docker und docker-compose verfügbar sind
command -v docker &>/dev/null || { echo -e "${RED}Fehler: Docker ist nicht installiert oder nicht im PATH.${NC}"; exit 1; }
command -v docker-compose &>/dev/null || { echo -e "${RED}Fehler: docker-compose ist nicht installiert oder nicht im PATH.${NC}"; exit 1; }

# Definiere die Services und deren Verzeichnisse (passe die Pfade an deine Struktur an)
declare -A SERVICES=(
    ["nginx"]="/srv/nginx"
    ["portainer"]="/srv/portainer"
    ["nextcloud"]="/srv/nextcloud"
    ["mattermost"]="/srv/mattermost"
    ["it-tools"]="/srv/it-tools"
    ["paperless"]="/srv/paperless"
    ["homarr"]="/srv/homarr"
    ["trillium"]="/srv/trillium"
    ["wordpress"]="/srv/wordpress"
    ["pterodactyl_panel"]="/srv/pterodactyl_panel"
    ["pterodactyl_wings"]="/srv/pterodactyl_wings"
)

# Hilfe-Funktion
usage() {
    echo -e "Usage: $0 {start|stop|restart|update|status|logs|shell|health|help} [service]"
    echo -e "  service: Optional, Name eines einzelnen Dienstes (z.B. portainer)."
    exit 1
}

# Prüfe Parameteranzahl
if [ $# -lt 1 ]; then
    usage
fi

ACTION=$1
SERVICE_FILTER=$2

# Funktion, um einen Befehl in einem Service-Verzeichnis auszuführen
run_service() {
    local service="$1"
    local dir="$2"
    log "Bearbeite Service: $service (Verzeichnis: $dir)"

    if [ ! -d "$dir" ]; then
        log "${YELLOW}Warnung: Verzeichnis $dir existiert nicht. Service $service wird übersprungen.${NC}"
        return
    fi

    pushd "$dir" > /dev/null || { log "${RED}Fehler: Konnte in $dir nicht wechseln.${NC}"; return; }

    case "$ACTION" in
        start)
            log "Starte $service..."
            docker-compose up -d && log "${GREEN}$service gestartet.${NC}" || log "${RED}Fehler beim Start von $service.${NC}"
            ;;
        stop)
            log "Stoppe $service..."
            docker-compose down && log "${GREEN}$service gestoppt.${NC}" || log "${RED}Fehler beim Stoppen von $service.${NC}"
            ;;
        restart)
            log "Starte $service neu..."
            docker-compose down && docker-compose up -d && log "${GREEN}$service neu gestartet.${NC}" || log "${RED}Fehler beim Neustart von $service.${NC}"
            ;;
        update)
            log "Aktualisiere $service..."
            docker-compose pull && docker-compose up -d && log "${GREEN}$service aktualisiert.${NC}" || log "${RED}Fehler beim Update von $service.${NC}"
            ;;
        status)
            log "Status von $service:"
            docker-compose ps || log "${RED}Fehler beim Abrufen des Status von $service.${NC}"
            ;;
        logs)
            log "Zeige Logs von $service (letzte 50 Zeilen):"
            docker-compose logs --tail=50 || log "${RED}Fehler beim Abrufen der Logs von $service.${NC}"
            ;;
        shell)
            # Öffnet interaktiv eine Shell im ersten Container des Dienstes
            CONTAINER=$(docker-compose ps -q | head -n1)
            if [ -z "$CONTAINER" ]; then
                log "${RED}Kein laufender Container für $service gefunden.${NC}"
            else
                log "Öffne Shell in Container $CONTAINER von $service..."
                docker-compose exec "$(docker-compose ps --services | head -n1)" bash || log "${RED}Fehler beim Öffnen der Shell in $service.${NC}"
            fi
            ;;
        health)
            log "Überprüfe Health-Status von $service:"
            docker-compose ps || log "${RED}Fehler beim Überprüfen des Health-Status von $service.${NC}"
            ;;
        *)
            usage
            ;;
    esac

    popd > /dev/null
}

# Hauptschleife: Wenn SERVICE_FILTER gesetzt, wird nur dieser Service bearbeitet.
if [ -n "$SERVICE_FILTER" ]; then
    if [[ -n "${SERVICES[$SERVICE_FILTER]}" ]]; then
        run_service "$SERVICE_FILTER" "${SERVICES[$SERVICE_FILTER]}"
    else
        log "${RED}Fehler: Service '$SERVICE_FILTER' ist nicht definiert.${NC}"
        exit 1
    fi
else
    # Andernfalls alle Services
    for service in "${!SERVICES[@]}"; do
        run_service "$service" "${SERVICES[$service]}"
    done
fi

log "Aktion '$ACTION' abgeschlossen."
