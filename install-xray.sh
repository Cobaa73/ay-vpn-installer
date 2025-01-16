#!/bin/bash

#==============================
# Script Xray VPN Management
#==============================

# Set warna untuk output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# URL file daftar IP yang diizinkan (ganti dengan repo Anda)
ALLOWED_IPS_URL="https://raw.githubusercontent.com//Cobaa73/main/allowed_ips.txt"

# Cek apakah IP server terdaftar
echo -e "${GREEN}Memeriksa IP server...${NC}"
SERVER_IP=$(curl -s https://ipinfo.io/ip)
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Gagal mendapatkan IP server. Pastikan koneksi internet aktif.${NC}"
    exit 1
fi

ALLOWED_IPS=$(curl -s "$ALLOWED_IPS_URL")
if echo "$ALLOWED_IPS" | grep -qw "$SERVER_IP"; then
    echo -e "${GREEN}IP server ($SERVER_IP) terdaftar. Melanjutkan instalasi...${NC}"
else
    echo -e "${RED}IP server ($SERVER_IP) tidak terdaftar! Hubungi admin untuk registrasi.${NC}"
    exit 1
fi

# Set timezone ke WIB
echo -e "${GREEN}Setting timezone to Asia/Jakarta...${NC}"
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
timedatectl set-timezone Asia/Jakarta

# Update dan install dependencies
echo -e "${GREEN}Updating system and installing dependencies...${NC}"
apt update && apt upgrade -y
apt install -y curl wget jq git unzip socat cron

# Install Xray Core
echo -e "${GREEN}Installing Xray Core...${NC}"
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /usr/local/bin/xray.zip
unzip /usr/local/bin/xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray
rm -f /usr/local/bin/xray.zip

# Membuat folder konfigurasi
mkdir -p /etc/xray
mkdir -p /var/log/xray

# Install bot Telegram
echo -e "${GREEN}Setting up Telegram bot...${NC}"
apt install -y python3 python3-pip
pip3 install python-telegram-bot

# Buat fungsi untuk mengelola akun
echo -e "${GREEN}Creating management scripts...${NC}"
cat << 'EOF' > /usr/local/bin/vpn-management
#!/bin/bash

# Fungsi untuk menambah akun
add_account() {
    echo -e "Menambahkan akun..."
    # Tambahkan logika pembuatan akun di sini
}

# Fungsi untuk menghapus akun
delete_account() {
    echo -e "Menghapus akun..."
    # Tambahkan logika penghapusan akun di sini
}

# Fungsi untuk mengganti domain
change_domain() {
    echo -e "Mengganti domain..."
    # Tambahkan logika penggantian domain di sini
}

# Fungsi untuk memeriksa IP login
check_login() {
    echo -e "Memeriksa IP login..."
    # Tambahkan logika pemeriksaan IP di sini
}

# Fungsi untuk menampilkan penggunaan data
usage_status() {
    echo -e "Menampilkan status penggunaan data..."
    # Tambahkan logika status data di sini
}

# Fungsi untuk restart layanan
restart_services() {
    echo -e "Restart semua layanan..."
    systemctl restart xray
    echo -e "Semua layanan telah di-restart."
}

# Fungsi untuk uninstall/rebuild
uninstall_rebuild() {
    echo -e "Uninstall dan rebuild script..."
    # Tambahkan logika uninstall dan rebuild di sini
}

# Menu utama
while true; do
    echo "============================"
    echo "VPN Management Panel"
    echo "============================"
    echo "1. Tambah Akun"
    echo "2. Hapus Akun"
    echo "3. Ganti Domain"
    echo "4. Cek Login IP"
    echo "5. Status Data"
    echo "6. Restart Service"
    echo "7. Uninstall/Rebuild"
    echo "8. Keluar"
    echo "============================"
    read -rp "Pilih menu: " choice

    case $choice in
    1) add_account ;;
    2) delete_account ;;
    3) change_domain ;;
    4) check_login ;;
    5) usage_status ;;
    6) restart_services ;;
    7) uninstall_rebuild ;;
    8) break ;;
    *) echo "Pilihan tidak valid!" ;;
    esac
done
EOF

chmod +x /usr/local/bin/vpn-management

# Tambahkan cron job untuk auto-clear akun
echo -e "${GREEN}Adding auto-clear accounts to cron jobs...${NC}"
cat << 'CRON' > /etc/cron.d/auto-clear
0 0 * * * root /usr/local/bin/vpn-management clear_expired_accounts
CRON

echo -e "${GREEN}Installation completed!${NC}"
echo "Run 'vpn-management' to manage your VPN server."