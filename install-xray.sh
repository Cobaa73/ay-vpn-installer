#!/bin/bash

# Warna teks
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Fungsi deteksi OS
deteksi_os() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  else
    echo -e "${RED}Tidak dapat mendeteksi sistem operasi!${NC}"
    exit 1
  fi
}

# Fungsi instalasi dependensi
install_dependencies() {
  echo -e "${GREEN}Memeriksa dan menginstal dependensi...${NC}"
  
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt update -y
    apt install -y curl jq socat
  else
    echo -e "${RED}OS tidak didukung! Script ini hanya untuk Ubuntu/Debian.${NC}"
    exit 1
  fi
}

# Fungsi instalasi Xray
install_xray() {
  if ! [ -x "$(command -v xray)" ]; then
    echo -e "${GREEN}Menginstal Xray...${NC}"
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install
    mkdir -p /etc/xray
    touch /etc/xray/config.json
    echo '{}' > /etc/xray/config.json
  fi
}

# Fungsi menampilkan menu
menu() {
  clear
  echo -e "${GREEN}Xray Tunneling Manager${NC}"
  echo "=========================="
  echo "1. Tambah akun"
  echo "2. Hapus akun"
  echo "3. Cek akun aktif"
  echo "4. Cek login pengguna"
  echo "5. Ganti domain"
  echo "6. Restart layanan"
  echo "7. Uninstall sistem"
  echo "8. Keluar"
  echo "=========================="
  read -p "Pilih opsi [1-8]: " option

  case $option in
    1) tambah_akun ;;
    2) hapus_akun ;;
    3) cek_akun_aktif ;;
    4) cek_login_pengguna ;;
    5) ganti_domain ;;
    6) restart_layanan ;;
    7) uninstall_sistem ;;
    8) exit 0 ;;
    *) echo -e "${RED}Opsi tidak valid!${NC}" && sleep 2 && menu ;;
  esac
}

# Fungsi tambah akun
tambah_akun() {
  read -p "Masukkan nama pengguna: " username
  uuid=$(cat /proc/sys/kernel/random/uuid)
  read -p "Masukkan masa berlaku (hari): " expired_days
  expired_date=$(date -d "+$expired_days days" +%Y-%m-%d)
  
  jq --arg user "$username" --arg uuid "$uuid" --arg exp "$expired_date" \
    '.inbounds[0].settings.clients += [{"id": $uuid, "email": $user, "expire": $exp}]' /etc/xray/config.json > temp.json && mv temp.json /etc/xray/config.json
  
  echo -e "${GREEN}Akun berhasil ditambahkan!${NC}"
  echo "Username: $username"
  echo "UUID: $uuid"
  echo "Expired: $expired_date"
  systemctl restart xray
  sleep 2
  menu
}

# Fungsi hapus akun
hapus_akun() {
  read -p "Masukkan nama pengguna yang ingin dihapus: " username
  jq 'del(.inbounds[0].settings.clients[] | select(.email == "'"$username"'"))' /etc/xray/config.json > temp.json && mv temp.json /etc/xray/config.json
  echo -e "${GREEN}Akun $username berhasil dihapus!${NC}"
  systemctl restart xray
  sleep 2
  menu
}

# Fungsi cek akun aktif
cek_akun_aktif() {
  echo -e "${GREEN}Daftar akun aktif:${NC}"
  jq -r '.inbounds[0].settings.clients[] | "