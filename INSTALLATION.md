# ⚙️ Installation Guide – BackSat OS

This guide helps you install **BackSat OS** on a Raspberry Pi or other Linux-compatible devices.

---

## ✅ Quick Install (Recommended – Raspberry Pi OS Lite)

### 🧰 Requirements

- Raspberry Pi OS Lite (headless or full)
- Wi-Fi or Ethernet
- Access via SSH or terminal

### 🧪 Steps

```bash
curl -s https://raw.githubusercontent.com/RudyDeana/BackSat/refs/heads/main/install.sh | bash

```

This will:
	•	Install mesh tools and dashboard
	•	Set up Wi-Fi AP and DNS
	•	Enable autostart and services

You can then access the dashboard at:
http://backsat.local or http://"device-ip"

---

### 🧪 BackSat Lite (Coming Soon)

BackSat Lite is the minimal firmware-based version for:

	•	ESP32
 
	•	Arduino with Wi-Fi conection
 
	•	Meshtastic boards

It will support:

	•	Serial communication
 
	•	Beaconing
 
	•	Low-power messaging

Stay tuned!
