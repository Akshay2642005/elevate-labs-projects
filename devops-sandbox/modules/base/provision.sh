#!/usr/bin/env bash
set -e

echo "[BASE] Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "[BASE] Installing essentials..."
sudo apt-get install -y \
  git curl wget vim net-tools htop unzip \
  software-properties-common apt-transport-https ca-certificates lsb-release

echo "[BASE] Done"
