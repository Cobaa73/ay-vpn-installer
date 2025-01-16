#!/bin/bash

# Xray Core Installer Script
# For Ubuntu 20.04
# Supports VMess, VLESS, TLS, and Non-TLS

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function install_dependencies() {
    echo -e "${GREEN}Installing dependencies...${NC}"
    apt update -y && apt upgrade -y
    apt install -y curl socat xz-utils wget apt-transport-https gnupg lsb-release jq
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt install -y nodejs
    apt install -y certbot
}

function install_xray() {
    echo -e "${GREEN}Installing Xray Core...${NC}"
    bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install
}

function setup_tls_certificates() {
    echo -e "${GREEN}Setting up TLS certificates...${NC}"
    read -p "Enter your domain name: " domain
    systemctl stop nginx
    certbot certonly --standalone -d "$domain"
    mkdir -p /etc/xray
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/fullchain.pem
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/privkey.pem
}

function configure_xray() {
    echo -e "${GREEN}Configuring Xray Core...${NC}"
    cat <<EOF > /etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/fullchain.pem",
              "keyFile": "/etc/xray/privkey.pem"
            }
          ]
        }
      }
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    systemctl restart xray
}

function menu() {
    echo -e "${GREEN}Xray Management Menu${NC}"
    echo "1. Add VLESS Client"
    echo "2. Remove Client"
    echo "3. View Clients"
    echo "4. Exit"
    read -p "Choose an option: " opt
    case $opt in
    1)
        add_client
        ;;
    2)
        remove_client
        ;;
    3)
        view_clients
        ;;
    4)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option!${NC}"
        ;;
    esac
}

function add_client() {
    read -p "Enter client name: " name
    uuid=$(cat /proc/sys/kernel/random/uuid)
    jq --arg name "$name" --arg uuid "$uuid" '.inbounds[0].settings.clients += [{"id": $uuid, "email": $name}]' /etc/xray/config.json > /etc/xray/config.json.tmp && mv /etc/xray/config.json.tmp /etc/xray/config.json
    systemctl restart xray
    echo -e "${GREEN}Client added:${NC}"
    echo -e "Name: $name"
    echo -e "UUID: $uuid"
}

function remove_client() {
    read -p "Enter client name to remove: " name
    jq --arg name "$name" 'del(.inbounds[0].settings.clients[] | select(.email == $name))' /etc/xray/config.json > /etc/xray/config.json.tmp && mv /etc/xray/config.json.tmp /etc/xray/config.json
    systemctl restart xray
    echo -e "${GREEN}Client removed.${NC}"
}

function view_clients() {
    echo -e "${GREEN}Current clients:${NC}"
    jq '.inbounds[0].settings.clients' /etc/xray/config.json
}

# Main script execution
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root.${NC}"
    exit 1
fi

install_dependencies
install_xray
setup_tls_certificates
configure_xray
while true; do
    menu
done