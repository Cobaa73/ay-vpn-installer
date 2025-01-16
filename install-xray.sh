#!/bin/bash

set -e

# Konfigurasi awal
KEYWORD="naruto"
DEFAULT_TIMEZONE="Asia/Jakarta"

# Cek kata kunci saat instalasi
read -p "Masukkan kata kunci untuk melanjutkan instalasi: " input_keyword
if [ "$input_keyword" != "naruto" ]; then
    echo "Kata kunci salah! Instalasi dibatalkan."
    exit 1
fi

# Fungsi warna teks
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

# Cek OS yang didukung
if ! grep -q -E 'Ubuntu 20\.04|Ubuntu 22\.04|Debian 11|Debian 12' /etc/os-release; then
    echo -e "${RED}OS tidak didukung. Gunakan Ubuntu 20.04/22.04 atau Debian 11/12.${NC}"
    exit 1
fi

# Perbarui sistem
echo -e "${GREEN}Memperbarui sistem...${NC}"
apt update && apt upgrade -y

# Install dependensi
echo -e "${GREEN}Menginstal dependensi...${NC}"
apt install -y curl wget unzip jq cron socat ntpdate

# Sinkronisasi waktu
echo -e "${GREEN}Menyinkronkan waktu dengan timezone ${DEFAULT_TIMEZONE}...${NC}"
timedatectl set-timezone "$DEFAULT_TIMEZONE"
ntpdate pool.ntp.org

# Instalasi XRay Core
echo -e "${GREEN}Menginstal XRay Core...${NC}"
wget -O /usr/local/bin/xray https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
chmod +x /usr/local/bin/xray

# Direktori konfigurasi
mkdir -p /etc/xray
mkdir -p /var/log/xray

# Generate konfigurasi awal
cat > /etc/xray/config.json <<-EOF
{
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "info"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": []
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/xray.crt",
                            "keyFile": "/etc/xray/xray.key"
                        }
                    ]
                }
            }
        },
        {
            "port": 80,
            "protocol": "vmess",
            "settings": {
                "clients": []
            },
            "streamSettings": {
                "network": "ws",
                "security": "none"
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

# SSL sertifikat dummy
echo -e "${GREEN}Menghasilkan sertifikat SSL dummy...${NC}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/xray/xray.key \
    -out /etc/xray/xray.crt \
    -subj "/CN=localhost"

# Buat service XRay
cat > /etc/systemd/system/xray.service <<-EOF
[Unit]
Description=XRay Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload dan aktifkan XRay
echo -e "${GREEN}Mengaktifkan layanan XRay...${NC}"
systemctl daemon-reload
systemctl enable xray
systemctl start xray

# Install bot notifikasi (opsional)
echo -e "${GREEN}Menginstal bot Telegram (opsional)...${NC}"
read -p "Masukkan token bot Telegram (kosongkan jika tidak digunakan): " BOT_TOKEN
read -p "Masukkan ID penerima notifikasi Telegram: " BOT_CHAT_ID

if [[ -n "$BOT_TOKEN" && -n "$BOT_CHAT_ID" ]]; then
    cat > /usr/local/bin/xray-bot.sh <<-EOF
#!/bin/bash

TOKEN="$BOT_TOKEN"
CHAT_ID="$BOT_CHAT_ID"
MESSAGE="\$1"

curl -s -X POST "https://api.telegram.org/bot\$TOKEN/sendMessage" -d chat_id="\$CHAT_ID" -d text="\$MESSAGE"
EOF
    chmod +x /usr/local/bin/xray-bot.sh
fi

# Pesan sukses
echo -e "${GREEN}Instalasi selesai!${NC}"
echo -e "Gunakan perintah berikut untuk mengelola VPN:"
echo -e "1. Tambah akun: bash /usr/local/bin/add-account.sh"
echo -e "2. Hapus akun: bash /usr/local/bin/remove-account.sh"
echo -e "3. Ganti domain: bash /usr/local/bin/change-domain.sh"
echo -e "4. Lihat status: bash /usr/local/bin/status.sh"