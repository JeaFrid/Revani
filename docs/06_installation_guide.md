# 🛠️ Installation and Server Setup Guide

Revani is designed to be deployed with zero friction. This guide utilizes an automated installer to configure the environment, security, and dependencies on a clean Ubuntu/Debian server.

## 🚀 One-Step Automated Installation

The most reliable way to install Revani is via the official installation script. This script automatically handles:
* System package updates.
* **Dart SDK** and **Git** installation.
* Cloning the Revani repository.
* Configuring **SSL Certificates**.
* Setting up your `.env` storage password.

Run the following command on your server:

```bash
wget -qO install.sh [https://raw.githubusercontent.com/JeaFrid/Revani/main/server/install.sh](https://raw.githubusercontent.com/JeaFrid/Revani/main/server/install.sh) && bash install.sh
```

---

## 👨‍🍳 Managing the Bakery (Control Panel)

Once the installation is complete, you don't need to run manual `dart` commands for every task. We have provided a management suite to handle the server lifecycle.

### Entering the Management Console
Navigate to the project folder and start the runner:

```bash
cd Revani
dart run server/run.dart
```

### Console Options:
| Option | Action | Description |
| :--- | :--- | :--- |
| **1** | **Test Mode** | Starts the server in the current terminal (live output). |
| **2** | **Live Mode** | Runs the server in the background using `nohup`. |
| **3** | **Watch Logs** | Streams live server logs to your terminal. |
| **4** | **Stop Server** | Safely terminates the background server process. |
| **6** | **Update System** | Pulls the latest code from GitHub while **preserving** your `config.dart` and `.env`. |
| **7** | **Clean Database** | Deletes `.db` files and resets the engine to factory state. |

---

## 📡 Auxiliary Services (Livekit) (Optional)

Revani integrates with **Livekit** for real-time communication. If you plan to use these features, ensure a Livekit instance is reachable.

**Quick Livekit Setup (via Docker):**
```bash
docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit server --dev
```

---

## 🔒 Production SSL (Important)

The automated script generates **Self-Signed Certificates** for immediate use. For production environments with a domain name, you should replace them with **Let's Encrypt**:

1.  **Install Certbot:** `sudo apt install certbot -y`
2.  **Generate Certs:** `sudo certbot certonly --standalone -d yourdomain.com`
3.  **Link to Revani:**
    ```bash
    ln -sf /etc/letsencrypt/live/[yourdomain.com/fullchain.pem](https://yourdomain.com/fullchain.pem) server.crt
    ln -sf /etc/letsencrypt/live/[yourdomain.com/privkey.pem](https://yourdomain.com/privkey.pem) server.key
    ```

---

## 💡 Technical Tips

* **Firewall:** Revani listens on port `16897` by default. Open it using: `sudo ufw allow 16897`.
* **Process Persistence:** While `run.dart` Option 2 uses `nohup`, for enterprise-grade uptime, we recommend wrapping the execution in a **Systemd** service.
* **Performance:** During startup, Revani spawns "Pastry Chefs" (Isolates) equal to your CPU thread count. For high-load environments, ensure your VPS has at least 2 vCPUs for optimal actor-model performance.

---
**Next Step:** Learn how to interact with your new server in [SDK Usage & API Reference](./07_sdk_and_api_reference.md).