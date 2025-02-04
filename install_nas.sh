#!/bin/bash

# Обновление системы
echo "Обновление системы..."
apt update && apt upgrade -y

# Установка Xfce (графический интерфейс)
echo "Установка Xfce..."
apt install -y xfce4 xfce4-goodies lightdm

# Установка Samba для сетевого доступа
echo "Установка Samba..."
apt install -y samba samba-common-bin

# Создание общей папки NAS
mkdir -p /srv/nas
chmod 777 /srv/nas

# Настройка Samba
cat <<EOF > /etc/samba/smb.conf
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

# Перезапуск Samba
systemctl restart smbd

# Установка Syncthing
echo "Установка Syncthing..."
apt install -y syncthing

# Добавление Syncthing в автозапуск
useradd -m -s /bin/bash syncthing
mkdir -p /home/syncthing/.config/syncthing
chown -R syncthing:syncthing /home/syncthing

cat <<EOF > /etc/systemd/system/syncthing.service
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

# Запуск Syncthing
systemctl daemon-reload
systemctl enable syncthing
systemctl start syncthing

# Установка Cockpit
echo "Установка Cockpit..."
apt install -y cockpit cockpit-system cockpit-networkmanager

# Запуск Cockpit
systemctl enable --now cockpit.socket

# Вывод информации
echo "=========================="
echo "Установка завершена!"
echo "Админ-панель Cockpit: http://$(hostname -I | awk '{print $1}'):9090"
echo "Настроенный общий доступ к папке /srv/nas через Samba."
echo "Syncthing запущен для синхронизации файлов."
echo "=========================="
