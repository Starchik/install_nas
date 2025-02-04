#!/bin/bash

echo "Обновление системы..."
sudo apt update && sudo apt upgrade -y

# === УСТАНОВКА SAMBA ===
echo "Установка Samba..."
sudo apt install -y samba samba-common-bin

# Создание общей папки NAS
sudo mkdir -p /srv/nas
sudo chmod 777 /srv/nas

# Настройка Samba
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = Bad User

[NAS]
   path = /srv/nas
   browseable = yes
   read only = no
   guest ok = yes
EOF

sudo systemctl restart smbd

# === УСТАНОВКА SYNCTHING ===
echo "Установка Syncthing..."
sudo apt install -y syncthing

# Создание пользователя для Syncthing
sudo useradd -m -s /bin/bash syncthing
sudo mkdir -p /home/syncthing/.config/syncthing
sudo chown -R syncthing:syncthing /home/syncthing

# Создание systemd-юнита для Syncthing
sudo tee /etc/systemd/system/syncthing.service > /dev/null <<EOF
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
After=network.target

[Service]
User=syncthing
ExecStart=/usr/bin/syncthing -no-browser -logflags=0
Restart=on-failure
SuccessExitStatus=3 4
RestartForceExitStatus=3 4

[Install]
WantedBy=default.target
EOF

sudo systemctl enable syncthing

# === УСТАНОВКА COCKPIT ===
echo "Установка Cockpit..."
sudo apt install -y cockpit cockpit-system cockpit-networkmanager
sudo systemctl enable cockpit.socket

# === УСТАНОВКА QBITTORRENT ===
echo "Установка qBittorrent..."
sudo apt install -y qbittorrent-nox

# Создание пользователя для работы qBittorrent
sudo useradd -m -s /bin/bash qbittorrent
sudo mkdir -p /home/qbittorrent/downloads
sudo chown -R qbittorrent:qbittorrent /home/qbittorrent

# Создание systemd-юнита для qBittorrent
sudo tee /etc/systemd/system/qbittorrent.service > /dev/null <<EOF
[Unit]
Description=qBittorrent Daemon
After=network.target

[Service]
User=qbittorrent
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080
Restart=on-failure
SuccessExitStatus=0

[Install]
WantedBy=default.target
EOF

sudo systemctl enable qbittorrent

# === УСТАНОВКА WIREGUARD VPN ===
echo "Установка WireGuard..."
sudo apt install -y wireguard

# Генерация ключей WireGuard
sudo mkdir -p /etc/wireguard
sudo wg genkey | sudo tee /etc/wireguard/privatekey | sudo wg pubkey > /etc/wireguard/publickey
sudo chmod 600 /etc/wireguard/privatekey

# Создание конфигурации сервера WireGuard
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(sudo cat /etc/wireguard/privatekey)
SaveConfig = true
PostUp = sudo iptables -A FORWARD -i wg0 -j ACCEPT; sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = sudo iptables -D FORWARD -i wg0 -j ACCEPT; sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Добавь сюда ключ клиента вручную после установки
PublicKey = КЛЮЧ_КЛИЕНТА
AllowedIPs = 10.0.0.2/32
EOF

# Включение WireGuard
sudo systemctl enable wg-quick@wg0

# === ОТКРЫТИЕ ПОРТОВ ДЛЯ ДОСТУПА ИЗВНЕ ===
echo "Настройка брандмауэра..."
sudo ufw allow 51820/udp   # WireGuard VPN
sudo ufw allow 445/tcp     # Samba
sudo ufw allow 22000/tcp   # Syncthing
sudo ufw allow 21027/udp   # Syncthing
sudo ufw allow 8080/tcp    # qBittorrent
sudo ufw allow 9090/tcp    # Cockpit
sudo ufw enable

# === ОЧИСТКА СИСТЕМЫ ПЕРЕД СОЗДАНИЕМ ISO ===
echo "Очистка системы..."
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*

echo "Установка завершена! NAS готов к использованию."
