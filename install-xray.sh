#!/bin/bash

# ==================================================
# Xray Management Script
# Auto Installer for Xray VMess/VLESS + TLS/Non-TLS
# Supports Ubuntu 20.04/22.04 & Debian 11/12
# GitHub: https://github.com/username/repository
# ==================================================

# Keyword for installation
INSTALL_KEYWORD="naruto"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root."
  exit 1
fi

# Prompt for installation keyword
echo -n "Enter installation keyword: "
read keyword
if [[ $keyword != $INSTALL_KEYWORD ]]; then
  echo "Invalid keyword. Exiting."
  exit 1
fi

# Update and install required packages
echo "Updating and installing dependencies..."
apt update && apt upgrade -y
apt install -y wget curl jq tar unzip socat cron ufw nginx certbot python3-certbot-nginx

# Set timezone to WIB
echo "Setting timezone to WIB (Asia/Jakarta)..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Variables
XRAY_DIR="/usr/local/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
XRAY_LOG="/var/log/xray/access.log"
DOMAIN=""
UUID=$(cat /proc/sys/kernel/random/uuid)

# Install Xray Core
install_xray() {
  echo "Installing Xray..."
  mkdir -p ${XRAY_DIR}
  wget -q -O xray.tar.gz https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  tar -xzf xray.tar.gz -C ${XRAY_DIR}
  rm -f xray.tar.gz
}

# Configure Xray
configure_xray() {
  echo "Configuring Xray..."
  cat > ${XRAY_CONFIG} <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0,
            "email": "user@domain.com"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/ssl/xray.crt",
              "keyFile": "/etc/ssl/xray.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
}

# Create systemd service for Xray
create_service() {
  echo "Creating systemd service..."
  cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=${XRAY_DIR}/xray -config ${XRAY_CONFIG}
Restart=on-failure
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable xray
}

# Generate SSL certificate
generate_ssl() {
  echo "Generating SSL certificate..."
  if [[ -z "$DOMAIN" ]]; then
    echo -n "Enter your domain: "
    read DOMAIN
  fi
  certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}
  ln -s /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/ssl/xray.crt
  ln -s /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/ssl/xray.key
}

# Main menu for management
management_menu() {
  echo "Welcome to the Xray Management Panel"
  echo "===================================="
  echo "1. Add User"
  echo "2. Delete User"
  echo "3. Change Domain"
  echo "4. Restart Service"
  echo "5. Uninstall/Rebuild"
  echo "6. Check Usage"
  echo "7. Check IP Logs"
  echo "8. Check System Status"
  echo "9. Auto-Clear Expired Users"
  echo "===================================="
  echo -n "Enter your choice [1-9]: "
  read choice
  case $choice in
    1) add_user ;;
    2) delete_user ;;
    3) change_domain ;;
    4) restart_service ;;
    5) uninstall_rebuild ;;
    6) check_usage ;;
    7) check_logs ;;
    8) check_system ;;
    9) clear_expired ;;
    *) echo "Invalid choice!" ;;
  esac
}

# Function definitions for menu actions
add_user() { echo "Adding user..."; }
delete_user() { echo "Deleting user..."; }
change_domain() { echo "Changing domain..."; }
restart_service() { systemctl restart xray; echo "Service restarted."; }
uninstall_rebuild() { echo "Uninstalling and rebuilding..."; }
check_usage() { echo "Checking usage..."; }
check_logs() { echo "Checking IP logs..."; }
check_system() { echo "Checking system status..."; }
clear_expired() { echo "Clearing expired users..."; }

# Main installation flow
install_xray
configure_xray
generate_ssl
create_service

echo "Installation complete. Run 'xray' to manage the service."