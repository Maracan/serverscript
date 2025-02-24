#!/bin/bash
set -e

##############################
# Globale Variablen und Funktionen
##############################
LOG_FILE="wlog.txt"
BACKUP_DIR="/root/server_setup_backups"
mkdir -p "$BACKUP_DIR"
ADMIN_EMAIL=""    # Wird gesetzt, falls erweiterte Logging/Benachrichtigung aktiviert werden
ROLLBACK_ENABLED=true

# Logging-Funktion: Schreibt in Logdatei und gibt in der Konsole aus
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Backup-Funktion für kritische Dateien
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak_$(date +%Y%m%d_%H%M%S)"
        log_info "Backup von $file erstellt."
    fi
}

# Rollback-Funktion: Stellt gesicherte Konfigurationsdateien wieder her
rollback_changes() {
    log_info "Rollback wird gestartet..."
    # /etc/ssh/sshd_config wiederherstellen
    SSH_BACKUP=$(ls -t "$BACKUP_DIR/sshd_config.bak_"* 2>/dev/null | head -n 1 || true)
    if [ -n "$SSH_BACKUP" ]; then
        cp "$SSH_BACKUP" /etc/ssh/sshd_config
        log_info "Rollback: /etc/ssh/sshd_config wiederhergestellt."
    fi
    # /etc/fail2ban/jail.local wiederherstellen
    FAIL2BAN_BACKUP=$(ls -t "$BACKUP_DIR/jail.local.bak_"* 2>/dev/null | head -n 1 || true)
    if [ -n "$FAIL2BAN_BACKUP" ]; then
        cp "$FAIL2BAN_BACKUP" /etc/fail2ban/jail.local
        log_info "Rollback: /etc/fail2ban/jail.local wiederhergestellt."
    fi
    systemctl restart ssh || true
    systemctl restart fail2ban || true
    log_info "Rollback abgeschlossen."
    if [ -n "$ADMIN_EMAIL" ]; then
        echo "Rollback wurde durchgeführt. Siehe Logfile unter $LOG_FILE" | mail -s "Server Setup Rollback" "$ADMIN_EMAIL"
    fi
}

# Fehlerbehandlung: Bei jedem Fehler wird das Rollback ausgeführt
trap 'log_info "Fehler im Skript. Rollback wird ausgeführt."; rollback_changes; exit 1' ERR

# Funktion für einen simplen Ladebalken
show_gauge() {
    (
        echo "0"; sleep 0.5
        echo "25"; echo "# Starte..."; sleep 0.5
        echo "50"; echo "# Arbeite..."; sleep 0.5
        echo "75"; echo "# Fast fertig..."; sleep 0.5
        echo "100"; echo "# Fertig."
    ) | whiptail --title "Fortschritt" --gauge "Bitte warten..." 8 60 0
}

##############################
# Systemvoraussetzungen prüfen
##############################
if ! command -v apt-get &> /dev/null; then
    echo "Abbruch: Dieses Script unterstützt nur Systeme mit apt-get (Ubuntu, Debian und ähnliche)."
    exit 1
fi

##############################
# Automatische Systemaktualisierung (nicht optional)
##############################
log_info "Starte Systemaktualisierung..."
apt-get update && apt-get upgrade -y
log_info "Systemaktualisierung abgeschlossen."

##############################
# Erweiterte Logging & E-Mail Benachrichtigung (optional)
##############################
if whiptail --title "Erweitertes Logging & Benachrichtigung" --yesno "Möchtest du erweiterte Logging-Funktionen mit E-Mail-Benachrichtigung aktivieren?" 10 60; then
    ADMIN_EMAIL=$(whiptail --title "Admin E-Mail" --inputbox "Bitte gib die E-Mail-Adresse für Benachrichtigungen ein:" 10 60 3>&1 1>&2 2>&3)
    if [ -z "$ADMIN_EMAIL" ]; then
        whiptail --title "Fehler" --msgbox "Keine E-Mail-Adresse eingegeben. Erweiterte Benachrichtigung wird deaktiviert." 10 60
    else
        log_info "Erweitertes Logging und E-Mail Benachrichtigung aktiviert. Admin: $ADMIN_EMAIL"
        # Installiere Mailutils, damit der 'mail'-Befehl verfügbar ist
        apt-get update && apt-get install -y mailutils
    fi
fi

##############################
# Schritt 1: SSH Root Login deaktivieren & neuen Benutzer anlegen
##############################
if whiptail --title "SSH Root Login & Benutzererstellung" --yesno "Möchtest du den SSH Root Login deaktivieren und einen neuen Benutzer erstellen?" 10 60; then
    # Benutzername abfragen
    USERNAME=$(whiptail --title "Neuen Benutzer erstellen" --inputbox "Bitte gib den gewünschten Benutzernamen ein:" 10 60 3>&1 1>&2 2>&3)
    if [ -z "$USERNAME" ]; then
        whiptail --title "Fehler" --msgbox "Kein Benutzername eingegeben. Skript wird abgebrochen." 10 60
        exit 1
    fi

    # Starkes Passwort generieren
    PASSWORD=$(openssl rand -base64 12)
    
    # Benutzer anlegen, Passwort setzen und zur sudo-Gruppe hinzufügen
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME"
    log_info "Benutzer $USERNAME angelegt und zu sudo hinzugefügt."
    
    show_gauge

    # Bestätigung der Benutzerdaten
    if whiptail --title "Benutzer erstellt" --yesno "Benutzer: $USERNAME\nPasswort: $PASSWORD\n\nHast du diese Daten sicher notiert?" 12 60; then
        # Backup und Deaktivierung des Root Logins in SSH
        backup_file /etc/ssh/sshd_config
        if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
            sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        else
            echo "PermitRootLogin no" >> /etc/ssh/sshd_config
        fi
        systemctl restart ssh
        log_info "SSH Root Login deaktiviert."
        whiptail --title "Erfolg" --msgbox "SSH Root Login wurde deaktiviert." 10 60
    else
        userdel -r "$USERNAME"
        log_info "Benutzer $USERNAME gelöscht, da keine Bestätigung erfolgte."
        whiptail --title "Abbruch" --msgbox "Benutzer wurde gelöscht. Bitte starte das Skript neu, wenn du fortfahren möchtest." 10 60
        exit 1
    fi
fi

##############################
# Schritt 2: SSH Port ändern
##############################
if whiptail --title "SSH Port ändern" --yesno "Möchtest du den SSH Port ändern?" 10 60; then
    PORT=$(whiptail --title "SSH Port ändern" --inputbox "Bitte gib den neuen SSH Port ein:" 10 60 3>&1 1>&2 2>&3)
    if [ -z "$PORT" ]; then
        whiptail --title "Fehler" --msgbox "Kein Port eingegeben. Dieser Schritt wird übersprungen." 10 60
    else
        backup_file /etc/ssh/sshd_config
        if grep -q "^Port" /etc/ssh/sshd_config; then
            sed -i "s/^Port.*/Port $PORT/" /etc/ssh/sshd_config
        else
            echo "Port $PORT" >> /etc/ssh/sshd_config
        fi
        show_gauge
        service ssh restart
        log_info "SSH Port auf $PORT geändert."
        whiptail --title "Erfolg" --msgbox "SSH Port wurde auf $PORT geändert und der SSH-Dienst neu gestartet." 10 60
    fi
fi

##############################
# Schritt 3: SSH Key Login einrichten
##############################
if whiptail --title "SSH Key Login" --yesno "Möchtest du SSH Key Login einrichten?" 10 60; then
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        whiptail --title "SSH Key vorhanden" --msgbox "Ein SSH Key existiert bereits unter $HOME/.ssh/id_rsa" 10 60
    else
        ssh-keygen -t rsa -b 2048 -N "" -f "$HOME/.ssh/id_rsa"
        show_gauge
        log_info "Neuer SSH Key generiert."
    fi
    PUBKEY=$(cat "$HOME/.ssh/id_rsa.pub")
    whiptail --title "SSH Key Login" --msgbox "Kopiere den folgenden öffentlichen Schlüssel und füge ihn in die Datei ~/.ssh/authorized_keys auf deinem Remote-Server ein:\n\n$PUBKEY" 15 70
fi

##############################
# Schritt 4: Interne Firewall (ufw) konfigurieren
##############################
if whiptail --title "Firewall konfigurieren" --yesno "Möchtest du die interne Firewall (ufw) konfigurieren?" 10 60; then
    apt-get update
    apt-get install -y ufw
    show_gauge
    ufw default deny incoming
    ufw allow 1055/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    log_info "Basis-Firewall-Regeln gesetzt und ufw aktiviert."
    STATUS=$(ufw status verbose)
    whiptail --title "Firewall Status" --msgbox "Firewall wurde konfiguriert.\n\nStatus:\n$STATUS" 15 70

    # Erweiterte Firewall-Konfiguration (optional)
    if whiptail --title "Erweiterte Firewall" --yesno "Möchtest du zusätzliche Firewall-Regeln hinzufügen (z. B. IP-Adressen blockieren oder detailliertes Logging aktivieren)?" 10 60; then
        IP_LIST=$(whiptail --title "IP-Adressen blockieren" --inputbox "Gib die zu blockierenden IP-Adressen (getrennt durch Leerzeichen) ein:" 10 60 3>&1 1>&2 2>&3)
        if [ -n "$IP_LIST" ]; then
            for ip in $IP_LIST; do
                ufw deny from "$ip"
                log_info "Firewall: IP $ip blockiert."
            done
        fi
        if whiptail --title "Firewall Logging" --yesno "Möchtest du eine detailliertere Protokollierung für die Firewall aktivieren?" 10 60; then
            ufw logging high
            log_info "Firewall: Detailliertes Logging aktiviert."
        fi
    fi
fi

##############################
# Schritt 5: Fail2Ban installieren & konfigurieren
##############################
if whiptail --title "Fail2Ban konfigurieren" --yesno "Möchtest du Fail2Ban installieren und konfigurieren?" 10 60; then
    apt-get update
    apt-get install -y fail2ban
    systemctl enable fail2ban
    backup_file /etc/fail2ban/jail.conf
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    backup_file /etc/fail2ban/jail.local
    # [sshd]-Bereich in jail.local anpassen
    if grep -q "^\[sshd\]" /etc/fail2ban/jail.local; then
        sed -i '/^\[sshd\]/,/^\[/{/maxretry/d; /findtime/d; /bantime/d; /port/d; /logpath/d; /backend/d}' /etc/fail2ban/jail.local
        sed -i "/^\[sshd\]/a maxretry  = 3\nfindtime  = 1d\nbantime   = 1w\nport      = ssh\nlogpath   = %(sshd_log)s\nbackend   = %(sshd_backend)s" /etc/fail2ban/jail.local
    else
        echo -e "\n[sshd]\nmaxretry  = 3\nfindtime  = 1d\nbantime   = 1w\nport      = ssh\nlogpath   = %(sshd_log)s\nbackend   = %(sshd_backend)s" >> /etc/fail2ban/jail.local
    fi
    show_gauge
    systemctl restart fail2ban
    # Fail2Ban-Status abfragen, Fehler abfangen ohne Skriptabbruch
    set +e
    FAIL2BAN_STATUS=$(fail2ban-client status sshd 2>&1)
    RETVAL=$?
    set -e
    if [ $RETVAL -ne 0 ]; then
         log_info "Warnung: Fail2Ban Status konnte nicht abgefragt werden. Details: $FAIL2BAN_STATUS"
         FAIL2BAN_STATUS="Fail2Ban Status nicht verfügbar."
    fi
    log_info "Fail2Ban konfiguriert."
    whiptail --title "Fail2Ban Status" --msgbox "Fail2Ban wurde konfiguriert.\n\nStatus:\n$FAIL2BAN_STATUS" 15 70
fi

##############################
# Schritt 6: IPv6 deaktivieren
##############################
if whiptail --title "IPv6 deaktivieren" --yesno "Möchtest du IPv6 deaktivieren?" 10 60; then
    CONFIG_FILE="/etc/sysctl.d/99-sysctl.conf"
    {
      echo ""
      echo "# IPv6 deaktivieren"
      echo "net.ipv6.conf.all.disable_ipv6 = 1"
      echo "net.ipv6.conf.default.disable_ipv6 = 1"
      echo "net.ipv6.conf.lo.disable_ipv6 = 1"
    } >> "$CONFIG_FILE"
    sysctl -p "$CONFIG_FILE"
    STATUS_IPV6=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
    log_info "IPv6 wurde deaktiviert."
    whiptail --title "IPv6 deaktiviert" --msgbox "IPv6 wurde deaktiviert.\n\nStatus (/proc/sys/net/ipv6/conf/all/disable_ipv6): $STATUS_IPV6" 12 70
fi

##############################
# Systemmonitoring installieren (optional)
##############################
if whiptail --title "Systemmonitoring" --yesno "Möchtest du ein Systemmonitoring-Tool installieren?" 10 60; then
    CHOICE=$(whiptail --title "Monitoring-Tool auswählen" --menu "Wähle ein Monitoring-Tool:" 15 60 2 \
        "1" "Netdata (Webinterface)" \
        "2" "htop (Kommandozeile)" 3>&1 1>&2 2>&3)
    if [ "$CHOICE" == "1" ]; then
        apt-get install -y netdata
        log_info "Netdata installiert."
        whiptail --title "Netdata installiert" --msgbox "Netdata wurde installiert. Du kannst es über den Browser unter http://<Server-IP>:19999 aufrufen." 10 60
    elif [ "$CHOICE" == "2" ]; then
        apt-get install -y htop
        log_info "htop installiert."
        HTOP_VER=$(htop --version | head -n1)
        whiptail --title "htop installiert" --msgbox "htop wurde installiert.\n\n$HTOP_VER" 10 60
    fi
fi

##############################
# Zusätzliche Sicherheits-Hardening-Maßnahmen
##############################
HARDENING_INFO="Optionale Sicherheits-Hardening-Maßnahmen:
- SSH-Banner: Zeigt beim Login einen Warnhinweis an.
- Strengere PAM-Konfiguration: Zusätzliche Sicherheitsprüfungen.
- IDS (z.B. OSSEC): Überwacht das System auf verdächtige Aktivitäten.
\nMöchtest du zumindest ein SSH-Banner einrichten?"
if whiptail --title "Sicherheits-Hardening" --yesno "$HARDENING_INFO" 15 70; then
    BANNER_TEXT=$(whiptail --title "SSH-Banner konfigurieren" --inputbox "Gib den Text für das SSH-Banner ein:" 15 60 3>&1 1>&2 2>&3)
    if [ -n "$BANNER_TEXT" ]; then
        echo "$BANNER_TEXT" > /etc/issue.net
        backup_file /etc/ssh/sshd_config
        if grep -q "^Banner" /etc/ssh/sshd_config; then
            sed -i "s|^Banner.*|Banner /etc/issue.net|" /etc/ssh/sshd_config
        else
            echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
        fi
        systemctl restart ssh
        log_info "SSH-Banner eingerichtet."
        whiptail --title "SSH-Banner" --msgbox "SSH-Banner wurde eingerichtet." 10 60
    else
        whiptail --title "SSH-Banner" --msgbox "Kein Banner-Text eingegeben. SSH-Banner wird nicht eingerichtet." 10 60
    fi
else
    log_info "Keine zusätzlichen Hardening-Maßnahmen ausgewählt."
fi

##############################
# Abschließende Zusammenfassung & Benachrichtigung
##############################
whiptail --title "Fertig" --msgbox "Alle gewählten Konfigurationen wurden durchgeführt." 10 60
log_info "Server Setup erfolgreich abgeschlossen."

# Bei aktiviertem erweitertem Logging: Sende Logfile per E-Mail an den Administrator
if [ -n "$ADMIN_EMAIL" ]; then
    mail -s "Server Setup abgeschlossen" "$ADMIN_EMAIL" < "$LOG_FILE"
fi
