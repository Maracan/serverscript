#!/bin/bash
# Skript: create_structure.sh
# Beschreibung: Legt die Ordnerstruktur für alle Docker-Services unter /srv an.

# Basisverzeichnis
BASE_DIR="/srv"

# Array mit den Dienstnamen (für eigene Ordner)
SERVICES=(
    "nginx"
    "portainer"
    "nextcloud"
    "mattermost"
    "it-tools"
    "paperless"
    "homarr"
    "trillium"
    "wordpress"
    "pterodactyl_panel"
    "pterodactyl_wings"
)

# Für nginx: spezielle Unterordner anlegen
NGINX_SUBDIRS=("conf.d" "certs" "logs")

echo "Erstelle Basis-Ordnerstruktur unter ${BASE_DIR}..."

# Erstelle den Basisordner, falls nicht vorhanden
sudo mkdir -p "$BASE_DIR"

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="${BASE_DIR}/${SERVICE}"
    echo "Erstelle Ordner für ${SERVICE} in ${SERVICE_DIR}..."
    sudo mkdir -p "$SERVICE_DIR"
    
    # Für die meisten Dienste legen wir Ordner für 'data' und 'logs' an
    # Ausnahme: nginx hat eigene Unterordner
    if [ "$SERVICE" == "nginx" ]; then
        for SUBDIR in "${NGINX_SUBDIRS[@]}"; do
            sudo mkdir -p "${SERVICE_DIR}/${SUBDIR}"
        done
    else
        sudo mkdir -p "${SERVICE_DIR}/data"
        sudo mkdir -p "${SERVICE_DIR}/logs"
    fi

    # Hier kannst du ggf. Platzhalter für docker-compose.yml erstellen
    if [ ! -f "${SERVICE_DIR}/docker-compose.yml" ]; then
        echo "# ${SERVICE} docker-compose configuration" | sudo tee "${SERVICE_DIR}/docker-compose.yml" > /dev/null
    fi
done

echo "Ordnerstruktur wurde unter ${BASE_DIR} erstellt."
