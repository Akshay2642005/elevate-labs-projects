#!/usr/bin/env bash
set -e

echo "[MINIO] Installing MinIO..."

# MinIO server
wget -q https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# MinIO client (mc)
wget -q https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Systemd service
sudo bash -c 'cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO
After=network.target

[Service]
ExecStart=/usr/local/bin/minio server /data --console-address ":9001"
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl enable minio --now

echo "[MINIO] MinIO server running on :9000, console :9001 "
