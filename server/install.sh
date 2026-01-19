#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

set -e

clear
echo -e "${CYAN}"
echo "    ____                        _   "
echo "   / __ \___ _   ______ _____  (_)  "
echo "  / /_/ / _ \ | / / __ \`/ __ \/ /   "
echo " / _, _/  __/ |/ / /_/ / / / / /    "
echo "/_/ |_|\___/|___/\__,_/_/ /_/_/     "
echo -e "${NC}"
echo -e "${YELLOW}>>> Welcome to Revani Installer${NC}"
echo "---------------------------------------------"

echo -e "\n${CYAN}[1/6] Updating system and installing base tools...${NC}"
if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get update -y
    sudo apt-get install -y git curl unzip apt-transport-https wget openssl
else
    echo -e "${RED}[ERROR] This script currently supports Debian/Ubuntu based systems only.${NC}"
    exit 1
fi

echo -e "\n${CYAN}[2/6] Checking Dart SDK...${NC}"
if ! command -v dart &> /dev/null; then
    echo -e "${YELLOW}Dart not found. Installing...${NC}"
    wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
    echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart.list
    sudo apt-get update -y
    sudo apt-get install -y dart
else
    echo -e "${GREEN}Dart is already installed.$(dart --version)${NC}"
fi

echo -e "\n${CYAN}[3/6] Cloning Revani repository...${NC}"
if [ -d "Revani" ]; then
    echo -e "${YELLOW}Directory 'Revani' exists. Backing up...${NC}"
    mv Revani "Revani_Backup_$(date +%s)"
fi

git clone https://github.com/JeaFrid/Revani.git
cd Revani

echo -e "\n${CYAN}[4/6] Installing Dart dependencies...${NC}"
dart pub get

echo -e "\n${CYAN}[5/6] Configuring security...${NC}"

echo -e "${YELLOW}>>> Please set a strong password for Revani Storage:${NC}"
read -s -p "Storage Password: " STORAGE_PASS
echo ""
echo "PASSWORD=$STORAGE_PASS" > .env
echo -e "${GREEN}.env file created.${NC}"

echo -e "${YELLOW}>>> Generating Self-Signed SSL Certificates...${NC}"
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -sha256 -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Revani/CN=localhost" > /dev/null 2>&1

if [ -f "server.key" ]; then
    echo -e "${GREEN}SSL Certificates (server.crt, server.key) are ready.${NC}"
else
    echo -e "${RED}Failed to generate certificates.${NC}"
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}   INSTALLATION SUCCESSFUL! 🍰           ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nTo manage your server, run:"
echo -e "${CYAN}cd Revani && dart run server/run.dart${NC}"
echo -e "\n"