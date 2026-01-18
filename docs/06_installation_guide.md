# 🛠️ Installation and Server Setup Guide

This guide contains all the necessary steps to launch Revani from scratch on a clean Ubuntu server.

## 1. System Requirements and Updates
First, let's update the core operating system tools and package repositories:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git curl unzip build-essential python3 python3-pip -y
```

## 2. Dart SDK Installation
Revani's engine is written in Dart. Let's perform the installation using the official Google repositories:

```bash
# Add the necessary keys and repositories
wget -qO- [https://dl-ssl.google.com/linux/linux_signing_key.pub](https://dl-ssl.google.com/linux/linux_signing_key.pub) | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] [https://storage.googleapis.com/download.dartlang.org/linux/debian](https://storage.googleapis.com/download.dartlang.org/linux/debian) stable main' | sudo tee /etc/apt/sources.list.d/dart.list

# Perform the installation
sudo apt update
sudo apt install dart
```
*You can verify the installation by running the `dart --version` command.*

## 3. Preparing Auxiliary Services (Livekit)
Revani works integrated with **Livekit** for real-time audio/video communication management.

- **Quick development setup via Docker:**
```bash
docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit server --dev
```

## 4. Cloning Revani and Dependencies
Pull the project source code from GitHub and install all required libraries:

```bash
# Clone the project
git clone [https://github.com/JeaFrid/Revani.git](https://github.com/JeaFrid/Revani.git)
cd Revani

# Install Dart dependencies
dart pub get
```

## 5. Generating Security Certificates
Revani mandates the use of **SSL/TLS** as part of its Zero-Trust architecture. You can follow two different methods depending on your needs:

### Method A: Local Development and Testing (Self-Signed)
You can quickly use the script within the project for development environments:

```bash
# Install Python dependency
pip3 install cryptography

# Run the certificate generation script
python3 cert_gen.py
```
This process will create `server.crt` and `server.key` files in the directory.

### Method B: Production Environment (Let's Encrypt)
If you are working on a live server (with a domain), it is recommended to use **Certbot** to obtain a free and valid certificate:

```bash
# Install Certbot
sudo apt install certbot -y

# Obtain your certificate (Ensure port 80 is empty on the server)
sudo certbot certonly --standalone -d yourdomain.com

# Link the generated certificates to the names Revani recognizes (Symbolic Link)
ln -s /etc/letsencrypt/live/[yourdomain.com/fullchain.pem](https://yourdomain.com/fullchain.pem) server.crt
ln -s /etc/letsencrypt/live/[yourdomain.com/privkey.pem](https://yourdomain.com/privkey.pem) server.key
```
> 🛡️ **Security Note:** Ensure that Revani has the correct permissions to read the `server.key` file in production. Revani looks for these certificate paths based on the configuration in `lib/config.dart`.

## 6. Environment Variables (.env) Configuration
You need a secret key to lock/unlock the RevaniEngine storage motor.

```bash
nano .env
```
Add the following line and save (CTRL+O, Enter, CTRL+X):
```text
PASSWORD=Your_Very_Strong_Storage_Password
```

## 7. Firing Up the Oven: Starting the Server
Everything is ready! Use the following command to start the Revani server:

```bash
dart bin/server.dart
```



### 🐳 Quick Setup Using Docker (Alternative)
If Docker is installed on your system, you can run Revani in an isolated container without dealing with dependencies:

```bash
# Build the image
docker build -t revani-bakery .

# Start the container
docker run -p 16897:16897 revani-bakery
```

---

## 💡 Technical Tips
* **Network Settings:** Revani listens on port `16897` by default. If a firewall (UFW) is active on your server, don't forget to allow it: `sudo ufw allow 16897`.
* **Performance:** In the logs, you will see a message like "Recruiting 11 pastry chefs." This number is automatically determined based on your server's CPU core count, and each core serves as an **Isolate (Chef)**.

---
The continuation of this documentation can be found in the *07_sdk_and_api_reference.md* file.