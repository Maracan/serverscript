# Server Setup Script

Dieses Repository enthält ein interaktives Bash-Skript zur Einrichtung und Härtung eines Linux-Servers (Ubuntu/Debian). Das Skript automatisiert viele sicherheitsrelevante Konfigurationen und hilft dabei, deinen Server schnell und zuverlässig einzurichten.

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Features](#features)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [Rollback & Logging](#rollback--logging)
- [Beitragende](#beitragende)
- [Lizenz](#lizenz)

## Überblick

Das Skript führt unter anderem folgende Aufgaben durch:
- **Automatische Systemaktualisierung:** Aktualisiert und upgraded das System, um sicherzustellen, dass alle Sicherheitsupdates vorliegen.
- **Backup kritischer Konfigurationsdateien:** Erstellt Backups von Dateien wie `/etc/ssh/sshd_config` und `/etc/fail2ban/jail.local`, bevor Änderungen vorgenommen werden.
- **Erweiterte Logging- und Benachrichtigungsfunktionen:** Protokolliert alle Schritte in einem zentralen Logfile und kann optional Benachrichtigungen per E-Mail verschicken.
- **Interaktive Konfiguration über Whiptail:** Ermöglicht über ein benutzerfreundliches Menü unter anderem:
  - Deaktivierung des SSH Root Logins und Erstellung eines neuen Benutzers mit sudo-Rechten
  - Änderung des SSH-Ports
  - Einrichtung von SSH Key Login
  - Konfiguration der Firewall (ufw) inklusive optionaler erweiterter Regeln (IP-Blockierung, detailliertes Logging)
  - Installation und Konfiguration von Fail2Ban
  - Deaktivierung von IPv6
  - Installation von Systemmonitoring-Tools (z. B. Netdata oder htop)
  - Optionale Sicherheits-Hardening-Maßnahmen (z. B. Einrichtung eines SSH-Banners)

## Features

- **Automatische Systemaktualisierung:**  
  Das Skript führt `apt-get update` und `apt-get upgrade -y` aus, um sicherzustellen, dass dein System auf dem neuesten Stand ist.

- **Backup und Rollback:**  
  Vor kritischen Änderungen werden Backups der Konfigurationsdateien erstellt. Bei Fehlern oder Abbrüchen wird ein automatisiertes Rollback durchgeführt.

- **Erweitertes Logging & E-Mail Benachrichtigung:**  
  Alle Aktionen werden in einem Logfile (`wlog.txt`) dokumentiert. Optional kann das Logfile per E-Mail an den Administrator gesendet werden (Voraussetzung: installiertes Mail-Tool wie *mailutils*).

- **Interaktive Menüführung:**  
  Das Skript nutzt Whiptail, um dich durch die Konfigurationsschritte zu führen und dir die Wahl zwischen verschiedenen Optionen zu geben.

- **Sicherheits-Hardening:**  
  Neben den Basismaßnahmen (wie Deaktivierung des Root Logins) können zusätzliche Sicherheitsmaßnahmen wie ein SSH-Banner eingerichtet werden.

## Voraussetzungen

- Ein frischer Linux-Server (Ubuntu, Debian oder ähnliche Distributionen).
- Root- oder sudo-Rechte.
- Internetzugang, um Updates und benötigte Pakete herunterzuladen.
- Whiptail (in der Regel in den Standard-Repositories enthalten).

## Installation

1. **Repository klonen oder Skript herunterladen:**

   Klone das Repository:
   ```bash
   git clone https://github.com/deinBenutzername/deinRepo.git
   cd deinRepo
