# 🌐 BackSat - The Backpack Satellite

BackSat is an open-source project that transforms any compatible device into an independent communication node — without SIM cards, cell towers, or internet. Think of it as a **personal terrestrial satellite** that fits in your backpack.

---

## 📡 What is BackSat?

BackSat is the first personal terrestrial satellite. It doesn’t fly — but it does the work of one:  
It creates networks, exchanges data, and communicates, all **offline**.

---

## 🚀 Main Features

- 🔁 **Decentralized Mesh Network**  
  - Creates ad-hoc mesh between nearby BackSats  
  - Works during blackouts  
  - No central server required  

- 🕵️‍♂️ **Private or Public Mode**  
  - *Private*: just you and your devices  
  - *Public*: communicate with other BackSats in range  

- 💻 **Device Compatibility**  
  - Raspberry Pi, laptop, portable router, etc.  
  - Only requirement: Wi-Fi + BackSat OS  

- 🖥 **Custom Operating System**
  - Network auto-boot  
  - Web dashboard (offline access via browser)  
  - Built-in tools:
    - P2P Chat
    - File Sharing
    - Node Discovery
    - Backup System
    - SOS Alerts
    - Node Map

---

## 🧩 Versions of BackSat

### 🖥 [BackSat OS](#-installation-backsat-os)
- For Raspberry Pi, mini PC, laptop
- Complete OS image with dashboard
- Local Wi-Fi hotspot
- Run mesh, dashboard, tools directly

### 🔌 [BackSat Lite](#-backsat-lite)
- For microcontrollers (ESP32, Arduino + LoRa, Meshtastic)
- Connect via serial or Wi-Fi to external interface
- Lightweight message + signal system

---

## ⚙️ Installation (BackSat OS)

You can install BackSat OS on any device that supports Linux.

### 🔧 Quick install using script

```bash
curl -s https://raw.githubusercontent.com/<tuo-username>/BackSat/main/backsat-install-script.sh | bash
