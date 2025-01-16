#!/bin/bash

# ==================================================
# Xray Management Script
# Auto Installer for Xray VMess/VLESS + TLS/Non-TLS
# Supports Ubuntu 20.04/22.04 & Debian 11/12
# ==================================================

INSTALL_KEYWORD="naruto"  # Kata kunci instalasi
XRAY_DIR="/usr/local/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
DOMAIN=""
UUID=$(cat /proc/sys/kernel/random/uuid)

# Fungsi untuk menampilkan menu
show_menu() {
  echo "============================="
  echo " Xray Management Panel"
  echo "============================="
  echo "1. Tambah Akun"
  echo "2. Hapus Akun"
  echo "3. Ganti Domain"
  echo "4. Restart Service"
  echo "5. Uninstall/Rebuild"
  echo "6. Cek Penggunaan Data"
  echo "7. Cek Log IP Login"
  echo "8. Cek Status Server"
  echo "9. Hapus Akun Expired"
  echo "0. Keluar"
  echo "============================="
  echo -n "Pilih opsi [0-9]: "
  read choice
  case $choice in
    1) tambah_akun ;;
    2) hapus_akun ;;
    3) ganti_domain ;;
    4) restart_service ;;
    5) uninstall_rebuild ;;
    6) cek_penggunaan ;;
    7) cek_log ;;
    8) cek_status ;;
    9) hapus_expired ;;
    0) exit ;;
    *) echo "Opsi tidak valid!" ;;
  esac
}

# Fungsi-fungsi untuk opsi menu
tambah_akun() { echo "Menambah akun baru..."; }
hapus_akun() { echo "Menghapus akun..."; }
ganti_domain() { echo "Mengganti domain..."; }
restart_service() { systemctl restart xray; echo "Service Xray telah di-restart."; }
uninstall_rebuild() { echo "Menghapus dan menginstal ulang..."; }
cek_penggunaan() { echo "Memeriksa penggunaan data..."; }
cek_log() { echo "Memeriksa log IP login..."; }
cek_status() { echo "Memeriksa status server..."; }
hapus_expired() { echo "Menghapus akun yang expired..."; }

# Fungsi instalasi Xray
install_xray() {
  echo "Menginstal Xray..."
  mkdir -p ${XRAY_DIR}
  wget -q -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip xray.zip -d ${XRAY_DIR}
  rm -f xray.zip

  # Membuat konfigurasi
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

  # Membuat systemd service
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

  # Mengaktifkan layanan
  systemctl enable xray
  systemctl start xray
}

# Generate SSL
generate_ssl() {
  echo -n "Masukkan domain Anda: "
  read DOMAIN
  apt install -y certbot python3-certbot-nginx
  certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}
  ln -s /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/ssl/xray.crt
  ln -s /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/ssl/xray.key
}

# Pemasangan utama
main_installation() {
  echo "Memulai instalasi..."
  apt update && apt upgrade -y
  apt install -y wget curl jq tar unzip socat cron nginx
  install_xray
  generate_ssl

  echo "alias menu='show_menu'" >> ~/.bashrc
  source ~/.bashrc
}

# Konfirmasi kata kunci
echo -n "Masukkan kata kunci instalasi: "
read input_keyword
if [[ $input_keyword != $INSTALL_KEYWORD ]]; then
  echo "Kata kunci salah! Instalasi dibatalkan."
  exit 1
fi

# Menjalankan pemasangan
main_installation
echo "Instalasi selesai! Ketik 'menu' untuk membuka panel manajemen."